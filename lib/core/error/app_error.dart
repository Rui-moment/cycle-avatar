import 'package:flutter/foundation.dart';

/// Base class for all application errors
abstract class AppError implements Exception {
  final String message;
  final String code;
  final DateTime timestamp;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? context;

  const AppError({
    required this.message,
    required this.code,
    DateTime? timestamp,
    this.stackTrace,
    this.context,
  }) : timestamp = timestamp ?? const Duration().inMilliseconds != 0 
         ? DateTime.now() 
         : DateTime.fromMillisecondsSinceEpoch(0);

  @override
  String toString() {
    return 'AppError(code: $code, message: $message, timestamp: $timestamp)';
  }

  /// Convert error to user-friendly message
  String toUserMessage();

  /// Whether this error should be reported to crash analytics
  bool get shouldReport => true;

  /// Whether this error can be automatically recovered from
  bool get canAutoRecover => false;

  /// Recovery action if auto-recovery is possible
  Future<void> recover() async {
    throw UnimplementedError('Recovery not implemented for ${runtimeType}');
  }
}

/// Network-related errors
class NetworkError extends AppError {
  final int? statusCode;
  final bool isTimeout;
  final bool isConnectionError;

  const NetworkError({
    required super.message,
    required super.code,
    super.timestamp,
    super.stackTrace,
    super.context,
    this.statusCode,
    this.isTimeout = false,
    this.isConnectionError = false,
  });

  factory NetworkError.timeout() {
    return const NetworkError(
      message: 'Request timed out',
      code: 'NETWORK_TIMEOUT',
      isTimeout: true,
    );
  }

  factory NetworkError.connectionFailed() {
    return const NetworkError(
      message: 'Connection failed',
      code: 'CONNECTION_FAILED',
      isConnectionError: true,
    );
  }

  factory NetworkError.serverError(int statusCode, String message) {
    return NetworkError(
      message: message,
      code: 'SERVER_ERROR_$statusCode',
      statusCode: statusCode,
    );
  }

  @override
  String toUserMessage() {
    if (isTimeout) {
      return 'Connection timed out. Please check your internet connection and try again.';
    }
    if (isConnectionError) {
      return 'Unable to connect to server. Please check your internet connection.';
    }
    if (statusCode != null && statusCode! >= 500) {
      return 'Server is temporarily unavailable. Please try again later.';
    }
    return 'Network error occurred. Please try again.';
  }

  @override
  bool get canAutoRecover => isTimeout || isConnectionError;

  @override
  Future<void> recover() async {
    // Implement retry logic
    await Future.delayed(const Duration(seconds: 2));
  }
}

/// Database-related errors
class DatabaseError extends AppError {
  final String? tableName;
  final String? operation;

  const DatabaseError({
    required super.message,
    required super.code,
    super.timestamp,
    super.stackTrace,
    super.context,
    this.tableName,
    this.operation,
  });

  factory DatabaseError.corruption(String tableName) {
    return DatabaseError(
      message: 'Database corruption detected in table: $tableName',
      code: 'DB_CORRUPTION',
      tableName: tableName,
    );
  }

  factory DatabaseError.migrationFailed(String version) {
    return DatabaseError(
      message: 'Database migration to version $version failed',
      code: 'MIGRATION_FAILED',
      context: {'version': version},
    );
  }

  factory DatabaseError.operationFailed(String operation, String table) {
    return DatabaseError(
      message: 'Database operation $operation failed on table $table',
      code: 'OPERATION_FAILED',
      tableName: table,
      operation: operation,
    );
  }

  @override
  String toUserMessage() {
    if (code == 'DB_CORRUPTION') {
      return 'Data corruption detected. The app will attempt to recover your data.';
    }
    if (code == 'MIGRATION_FAILED') {
      return 'App update failed. Please restart the app.';
    }
    return 'Data storage error occurred. Your data is safe and will be recovered.';
  }

  @override
  bool get canAutoRecover => code == 'OPERATION_FAILED';

  @override
  Future<void> recover() async {
    // Implement database recovery logic
    if (code == 'DB_CORRUPTION') {
      // Trigger database repair
      await _repairDatabase();
    }
  }

  Future<void> _repairDatabase() async {
    // Database repair implementation would go here
    await Future.delayed(const Duration(seconds: 1));
  }
}

/// Validation errors
class ValidationError extends AppError {
  final String field;
  final dynamic value;
  final List<String> violations;

  const ValidationError({
    required super.message,
    required super.code,
    required this.field,
    required this.value,
    required this.violations,
    super.timestamp,
    super.stackTrace,
    super.context,
  });

  factory ValidationError.required(String field) {
    return ValidationError(
      message: '$field is required',
      code: 'VALIDATION_REQUIRED',
      field: field,
      value: null,
      violations: ['required'],
    );
  }

  factory ValidationError.range(String field, dynamic value, num min, num max) {
    return ValidationError(
      message: '$field must be between $min and $max',
      code: 'VALIDATION_RANGE',
      field: field,
      value: value,
      violations: ['range'],
      context: {'min': min, 'max': max},
    );
  }

  factory ValidationError.format(String field, dynamic value, String format) {
    return ValidationError(
      message: '$field has invalid format',
      code: 'VALIDATION_FORMAT',
      field: field,
      value: value,
      violations: ['format'],
      context: {'expectedFormat': format},
    );
  }

  @override
  String toUserMessage() {
    switch (code) {
      case 'VALIDATION_REQUIRED':
        return '${_fieldDisplayName(field)} is required';
      case 'VALIDATION_RANGE':
        final min = context?['min'];
        final max = context?['max'];
        return '${_fieldDisplayName(field)} must be between $min and $max';
      case 'VALIDATION_FORMAT':
        return '${_fieldDisplayName(field)} format is invalid';
      default:
        return 'Invalid input for ${_fieldDisplayName(field)}';
    }
  }

  String _fieldDisplayName(String field) {
    switch (field) {
      case 'weight':
        return 'Weight';
      case 'reps':
        return 'Repetitions';
      case 'rpe':
        return 'RPE';
      case 'email':
        return 'Email';
      default:
        return field.replaceAll('_', ' ').split(' ')
            .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  @override
  bool get shouldReport => false; // Validation errors are user errors, not bugs

  @override
  bool get canAutoRecover => false; // User must fix the input
}

/// Business logic errors
class BusinessLogicError extends AppError {
  final String domain;
  final String operation;

  const BusinessLogicError({
    required super.message,
    required super.code,
    required this.domain,
    required this.operation,
    super.timestamp,
    super.stackTrace,
    super.context,
  });

  factory BusinessLogicError.fatigueCalculation(String muscleGroup) {
    return BusinessLogicError(
      message: 'Fatigue calculation failed for $muscleGroup',
      code: 'FATIGUE_CALC_ERROR',
      domain: 'recovery',
      operation: 'calculateFatigue',
      context: {'muscleGroup': muscleGroup},
    );
  }

  factory BusinessLogicError.avatarProgression(String reason) {
    return BusinessLogicError(
      message: 'Avatar progression failed: $reason',
      code: 'AVATAR_PROGRESSION_ERROR',
      domain: 'avatar',
      operation: 'updateLevel',
      context: {'reason': reason},
    );
  }

  factory BusinessLogicError.planGeneration(String goal) {
    return BusinessLogicError(
      message: 'Plan generation failed for goal: $goal',
      code: 'PLAN_GENERATION_ERROR',
      domain: 'planning',
      operation: 'generatePlan',
      context: {'goal': goal},
    );
  }

  @override
  String toUserMessage() {
    switch (domain) {
      case 'recovery':
        return 'Unable to calculate recovery status. Using default values.';
      case 'avatar':
        return 'Avatar update temporarily unavailable. Progress is still being tracked.';
      case 'planning':
        return 'Unable to generate workout plan. You can create a custom workout.';
      default:
        return 'A temporary issue occurred. The app will continue to work normally.';
    }
  }

  @override
  bool get canAutoRecover => true;

  @override
  Future<void> recover() async {
    switch (domain) {
      case 'recovery':
        await _recoverRecoveryCalculation();
        break;
      case 'avatar':
        await _recoverAvatarProgression();
        break;
      case 'planning':
        await _recoverPlanGeneration();
        break;
    }
  }

  Future<void> _recoverRecoveryCalculation() async {
    // Use fallback recovery calculation
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _recoverAvatarProgression() async {
    // Queue avatar update for later processing
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _recoverPlanGeneration() async {
    // Use default plan template
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

/// Sync-related errors
class SyncError extends AppError {
  final String entityType;
  final String entityId;
  final String operation;
  final int retryCount;

  const SyncError({
    required super.message,
    required super.code,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.retryCount = 0,
    super.timestamp,
    super.stackTrace,
    super.context,
  });

  factory SyncError.conflict(String entityType, String entityId) {
    return SyncError(
      message: 'Sync conflict for $entityType:$entityId',
      code: 'SYNC_CONFLICT',
      entityType: entityType,
      entityId: entityId,
      operation: 'sync',
    );
  }

  factory SyncError.uploadFailed(String entityType, String entityId, int retryCount) {
    return SyncError(
      message: 'Upload failed for $entityType:$entityId',
      code: 'SYNC_UPLOAD_FAILED',
      entityType: entityType,
      entityId: entityId,
      operation: 'upload',
      retryCount: retryCount,
    );
  }

  @override
  String toUserMessage() {
    if (code == 'SYNC_CONFLICT') {
      return 'Data conflict resolved automatically. Your local changes were preserved.';
    }
    if (retryCount > 3) {
      return 'Sync is temporarily unavailable. Your data is saved locally and will sync when connection improves.';
    }
    return 'Syncing data... This may take a moment.';
  }

  @override
  bool get canAutoRecover => retryCount < 5;

  @override
  Future<void> recover() async {
    // Implement retry with exponential backoff
    final delay = Duration(seconds: (retryCount + 1) * 2);
    await Future.delayed(delay);
  }
}

/// Authentication errors
class AuthError extends AppError {
  final String authType;

  const AuthError({
    required super.message,
    required super.code,
    required this.authType,
    super.timestamp,
    super.stackTrace,
    super.context,
  });

  factory AuthError.tokenExpired() {
    return const AuthError(
      message: 'Authentication token expired',
      code: 'TOKEN_EXPIRED',
      authType: 'jwt',
    );
  }

  factory AuthError.invalidCredentials() {
    return const AuthError(
      message: 'Invalid credentials',
      code: 'INVALID_CREDENTIALS',
      authType: 'login',
    );
  }

  factory AuthError.unauthorized() {
    return const AuthError(
      message: 'Unauthorized access',
      code: 'UNAUTHORIZED',
      authType: 'access',
    );
  }

  @override
  String toUserMessage() {
    switch (code) {
      case 'TOKEN_EXPIRED':
        return 'Your session has expired. Please log in again.';
      case 'INVALID_CREDENTIALS':
        return 'Invalid email or password. Please try again.';
      case 'UNAUTHORIZED':
        return 'You don\'t have permission to access this feature.';
      default:
        return 'Authentication error. Please log in again.';
    }
  }

  @override
  bool get canAutoRecover => code == 'TOKEN_EXPIRED';

  @override
  Future<void> recover() async {
    if (code == 'TOKEN_EXPIRED') {
      // Attempt to refresh token
      await _refreshToken();
    }
  }

  Future<void> _refreshToken() async {
    // Token refresh implementation would go here
    await Future.delayed(const Duration(seconds: 1));
  }
}

/// Unknown/unexpected errors
class UnknownError extends AppError {
  final Exception originalException;

  const UnknownError({
    required this.originalException,
    super.timestamp,
    super.stackTrace,
    super.context,
  }) : super(
          message: 'An unexpected error occurred',
          code: 'UNKNOWN_ERROR',
        );

  @override
  String toUserMessage() {
    return 'An unexpected error occurred. The app will continue to work normally.';
  }

  @override
  bool get shouldReport => true; // Always report unknown errors

  @override
  String toString() {
    return 'UnknownError(originalException: $originalException, message: $message)';
  }
}