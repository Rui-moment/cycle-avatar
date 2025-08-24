import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Performance monitoring utilities
class PerformanceUtils {
  static const String _tag = 'PerformanceUtils';
  
  /// Measure execution time of a function
  static Future<T> measureAsync<T>(
    String operationName,
    Future<T> Function() operation, {
    bool logResults = kDebugMode,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await operation();
      stopwatch.stop();
      
      if (logResults) {
        developer.log(
          '$operationName completed in ${stopwatch.elapsedMilliseconds}ms',
          name: _tag,
        );
      }
      
      return result;
    } catch (e) {
      stopwatch.stop();
      if (logResults) {
        developer.log(
          '$operationName failed after ${stopwatch.elapsedMilliseconds}ms: $e',
          name: _tag,
          error: e,
        );
      }
      rethrow;
    }
  }
  
  /// Measure execution time of a synchronous function
  static T measureSync<T>(
    String operationName,
    T Function() operation, {
    bool logResults = kDebugMode,
  }) {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = operation();
      stopwatch.stop();
      
      if (logResults) {
        developer.log(
          '$operationName completed in ${stopwatch.elapsedMilliseconds}ms',
          name: _tag,
        );
      }
      
      return result;
    } catch (e) {
      stopwatch.stop();
      if (logResults) {
        developer.log(
          '$operationName failed after ${stopwatch.elapsedMilliseconds}ms: $e',
          name: _tag,
          error: e,
        );
      }
      rethrow;
    }
  }
  
  /// Debounce function calls
  static Timer? _debounceTimer;
  
  static void debounce(
    Duration delay,
    VoidCallback callback,
  ) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, callback);
  }
  
  /// Throttle function calls
  static DateTime? _lastThrottleTime;
  
  static void throttle(
    Duration interval,
    VoidCallback callback,
  ) {
    final now = DateTime.now();
    if (_lastThrottleTime == null || 
        now.difference(_lastThrottleTime!) >= interval) {
      _lastThrottleTime = now;
      callback();
    }
  }
  
  /// Memory usage monitoring
  static void logMemoryUsage(String context) {
    if (kDebugMode) {
      developer.log(
        'Memory usage at $context',
        name: _tag,
      );
    }
  }
  
  /// Batch operations to reduce UI rebuilds
  static Future<List<T>> batchOperations<T>(
    List<Future<T> Function()> operations, {
    int batchSize = 5,
  }) async {
    final results = <T>[];
    
    for (int i = 0; i < operations.length; i += batchSize) {
      final batch = operations.skip(i).take(batchSize);
      final batchResults = await Future.wait(
        batch.map((op) => op()),
      );
      results.addAll(batchResults);
      
      // Allow UI to update between batches
      await Future.delayed(const Duration(milliseconds: 1));
    }
    
    return results;
  }
}

/// Mixin for performance monitoring in widgets
mixin PerformanceMonitorMixin {
  void measureWidgetBuild(String widgetName, VoidCallback buildFunction) {
    PerformanceUtils.measureSync('$widgetName build', buildFunction);
  }
  
  Future<T> measureAsyncOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) {
    return PerformanceUtils.measureAsync(operationName, operation);
  }
}

/// Performance-optimized state management
class OptimizedStateNotifier<T> extends StateNotifier<T> {
  OptimizedStateNotifier(super.state);
  
  /// Update state only if it actually changed
  @override
  set state(T newState) {
    if (state != newState) {
      super.state = newState;
    }
  }
  
  /// Batch multiple state updates
  void batchUpdate(List<T Function(T)> updates) {
    T newState = state;
    for (final update in updates) {
      newState = update(newState);
    }
    state = newState;
  }
}

/// Cache for expensive computations
class ComputationCache<K, V> {
  final Map<K, V> _cache = {};
  final Map<K, DateTime> _timestamps = {};
  final Duration _ttl;
  final int _maxSize;
  
  ComputationCache({
    Duration ttl = const Duration(minutes: 5),
    int maxSize = 100,
  }) : _ttl = ttl, _maxSize = maxSize;
  
  V? get(K key) {
    final timestamp = _timestamps[key];
    if (timestamp == null) return null;
    
    if (DateTime.now().difference(timestamp) > _ttl) {
      _cache.remove(key);
      _timestamps.remove(key);
      return null;
    }
    
    return _cache[key];
  }
  
  void put(K key, V value) {
    if (_cache.length >= _maxSize) {
      _evictOldest();
    }
    
    _cache[key] = value;
    _timestamps[key] = DateTime.now();
  }
  
  void _evictOldest() {
    if (_timestamps.isEmpty) return;
    
    final oldestKey = _timestamps.entries
        .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
        .key;
    
    _cache.remove(oldestKey);
    _timestamps.remove(oldestKey);
  }
  
  void clear() {
    _cache.clear();
    _timestamps.clear();
  }
}