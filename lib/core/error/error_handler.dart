import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_error.dart';
import '../utils/performance_utils.dart';

/// Global error handler for the application
class ErrorHandler {
  static const String _tag = 'ErrorHandler';
  static final List<AppError> _errorHistory = [];
  static final Map<String, int> _errorCounts = {};
  static final Map<String, DateTime> _lastErrorTimes = {};
  
  /// Initialize global error handling
  static void initialize() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // Handle async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleAsyncError(error, stack);
      return true;
    };

    developer.log('Error handler initialized', name: _tag);
  }

  /// Handle a specific app error
  static Future<void> handleError(
    AppError error, {
    bool showToUser = true,
    bool attemptRecovery = true,
  }) async {
    return PerformanceUtils.measureAsync('Error handling', () async {
      // Log the error
      _logError(error);
      
      // Track error frequency
      _trackErrorFrequency(error);
      
      // Add to history
      _addToHistory(error);
      
      // Report if necessary
      if (error.shouldReport && !kDebugMode) {
        await _reportError(error);
      }
      
      // Attempt recovery if possible
      if (attemptRecovery && error.canAutoRecover) {
        try {
          await error.recover();
          developer.log('Error recovery successful for ${error.code}', name: _tag);
        } catch (recoveryError) {
          developer.log(
            'Error recovery failed for ${error.code}: $recoveryError',
            name: _tag,
          );
        }
      }
      
      // Show user-friendly message if requested
      if (showToUser) {
        _showErrorToUser(error);
      }
    });
  }

  /// Handle exceptions and convert them to AppErrors
  static Future<void> handleException(
    Exception exception, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    bool showToUser = true,
  }) async {
    final appError = _convertExceptionToAppError(exception, stackTrace, context);
    await handleError(appError, showToUser: showToUser);
  }

  /// Handle errors in async operations with automatic retry
  static Future<T> handleAsyncOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
    bool showErrorToUser = true,
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e, stackTrace) {
        attempts++;
        
        final appError = e is AppError 
            ? e 
            : _convertExceptionToAppError(
                e is Exception ? e : Exception(e.toString()),
                stackTrace,
                {'operation': operationName, 'attempt': attempts},
              );
        
        if (attempts >= maxRetries) {
          await handleError(appError, showToUser: showErrorToUser);
          rethrow;
        }
        
        // Log retry attempt
        developer.log(
          'Retrying $operationName (attempt $attempts/$maxRetries) after error: ${appError.message}',
          name: _tag,
        );
        
        // Wait before retry with exponential backoff
        final delay = Duration(
          milliseconds: retryDelay.inMilliseconds * attempts,
        );
        await Future.delayed(delay);
      }
    }
    
    throw StateError('This should never be reached');
  }

  /// Wrap a function with error handling
  static Future<T?> safeExecute<T>(
    Future<T> Function() operation, {
    String? operationName,
    T? fallbackValue,
    bool showErrorToUser = false,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      final appError = e is AppError 
          ? e 
          : _convertExceptionToAppError(
              e is Exception ? e : Exception(e.toString()),
              stackTrace,
              {'operation': operationName ?? 'unknown'},
            );
      
      await handleError(appError, showToUser: showErrorToUser);
      return fallbackValue;
    }
  }

  /// Get error statistics
  static Map<String, dynamic> getErrorStatistics() {
    return {
      'totalErrors': _errorHistory.length,
      'errorCounts': Map.from(_errorCounts),
      'recentErrors': _errorHistory
          .where((e) => DateTime.now().difference(e.timestamp).inHours < 24)
          .length,
      'topErrors': _getTopErrors(),
    };
  }

  /// Clear error history (useful for testing)
  static void clearHistory() {
    _errorHistory.clear();
    _errorCounts.clear();
    _lastErrorTimes.clear();
  }

  // Private methods

  static void _handleFlutterError(FlutterErrorDetails details) {
    final error = UnknownError(
      originalException: Exception(details.exception.toString()),
      stackTrace: details.stack,
      context: {
        'library': details.library,
        'context': details.context?.toString(),
      },
    );
    
    handleError(error, showToUser: !kDebugMode);
  }

  static bool _handleAsyncError(Object error, StackTrace stackTrace) {
    final appError = error is AppError 
        ? error 
        : _convertExceptionToAppError(
            error is Exception ? error : Exception(error.toString()),
            stackTrace,
          );
    
    handleError(appError, showToUser: !kDebugMode);
    return true;
  }

  static AppError _convertExceptionToAppError(
    Exception exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ) {
    // Convert common exceptions to specific AppErrors
    if (exception.toString().contains('SocketException') ||
        exception.toString().contains('TimeoutException')) {
      return NetworkError.connectionFailed();
    }
    
    if (exception.toString().contains('FormatException')) {
      return ValidationError.format('input', null, 'valid format');
    }
    
    if (exception.toString().contains('DatabaseException') ||
        exception.toString().contains('SQLiteException')) {
      return DatabaseError.operationFailed('unknown', 'unknown');
    }
    
    // Default to unknown error
    return UnknownError(
      originalException: exception,
      stackTrace: stackTrace,
      context: context,
    );
  }

  static void _logError(AppError error) {
    final logLevel = error.shouldReport ? 'ERROR' : 'WARNING';
    
    developer.log(
      '[$logLevel] ${error.code}: ${error.message}',
      name: _tag,
      error: error,
      stackTrace: error.stackTrace,
    );
    
    if (kDebugMode) {
      debugPrint('AppError: ${error.toString()}');
      if (error.context != null) {
        debugPrint('Context: ${error.context}');
      }
    }
  }

  static void _trackErrorFrequency(AppError error) {
    final key = error.code;
    _errorCounts[key] = (_errorCounts[key] ?? 0) + 1;
    _lastErrorTimes[key] = error.timestamp;
    
    // Check for error spam (same error multiple times in short period)
    if (_errorCounts[key]! > 5) {
      final firstOccurrence = _errorHistory
          .where((e) => e.code == key)
          .first
          .timestamp;
      
      if (error.timestamp.difference(firstOccurrence).inMinutes < 5) {
        developer.log(
          'Error spam detected for ${error.code}: ${_errorCounts[key]} occurrences',
          name: _tag,
        );
      }
    }
  }

  static void _addToHistory(AppError error) {
    _errorHistory.add(error);
    
    // Keep only last 100 errors to prevent memory issues
    if (_errorHistory.length > 100) {
      _errorHistory.removeAt(0);
    }
  }

  static Future<void> _reportError(AppError error) async {
    // In a real app, this would send to crash reporting service
    // like Firebase Crashlytics, Sentry, etc.
    
    try {
      developer.log(
        'Reporting error to analytics: ${error.code}',
        name: _tag,
      );
      
      // Simulate reporting delay
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Here you would integrate with your crash reporting service:
      // await FirebaseCrashlytics.instance.recordError(
      //   error,
      //   error.stackTrace,
      //   fatal: false,
      // );
      
    } catch (reportingError) {
      developer.log(
        'Failed to report error: $reportingError',
        name: _tag,
      );
    }
  }

  static void _showErrorToUser(AppError error) {
    // This would typically show a snackbar or dialog
    // For now, we'll just log the user message
    developer.log(
      'User message: ${error.toUserMessage()}',
      name: _tag,
    );
    
    // In a real implementation, you might use a global navigator key
    // or a notification service to show the error to the user
  }

  static List<Map<String, dynamic>> _getTopErrors() {
    final sortedErrors = _errorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedErrors.take(5).map((entry) => {
      'code': entry.key,
      'count': entry.value,
      'lastOccurrence': _lastErrorTimes[entry.key]?.toIso8601String(),
    }).toList();
  }
}

/// Widget that provides error boundary functionality
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(AppError error)? errorBuilder;
  final void Function(AppError error)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  AppError? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(_error!) ?? _buildDefaultErrorWidget();
    }
    
    return widget.child;
  }

  Widget _buildDefaultErrorWidget() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error?.toUserMessage() ?? 'An unexpected error occurred',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                  });
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleError(AppError error) {
    setState(() {
      _error = error;
    });
    
    widget.onError?.call(error);
    ErrorHandler.handleError(error, showToUser: false);
  }
}

/// Mixin for widgets that need error handling
mixin ErrorHandlingMixin<T extends StatefulWidget> on State<T> {
  void handleError(AppError error) {
    ErrorHandler.handleError(error);
  }

  Future<R?> safeExecute<R>(
    Future<R> Function() operation, {
    String? operationName,
    R? fallbackValue,
  }) {
    return ErrorHandler.safeExecute(
      operation,
      operationName: operationName ?? T.toString(),
      fallbackValue: fallbackValue,
    );
  }

  Future<R> executeWithRetry<R>(
    String operationName,
    Future<R> Function() operation, {
    int maxRetries = 3,
  }) {
    return ErrorHandler.handleAsyncOperation(
      operationName,
      operation,
      maxRetries: maxRetries,
    );
  }
}