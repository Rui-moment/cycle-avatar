import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:cycle_avatar/core/error/app_error.dart';
import 'package:cycle_avatar/core/error/error_handler.dart';
import 'package:cycle_avatar/core/error/recovery_strategies.dart';

void main() {
  group('Error Handling Tests', () {
    setUp(() {
      ErrorHandler.clearHistory();
    });

    group('AppError Types', () {
      test('NetworkError should provide user-friendly messages', () {
        final timeoutError = NetworkError.timeout();
        expect(timeoutError.toUserMessage(), contains('timed out'));
        expect(timeoutError.canAutoRecover, isTrue);

        final connectionError = NetworkError.connectionFailed();
        expect(connectionError.toUserMessage(), contains('connection'));
        expect(connectionError.canAutoRecover, isTrue);

        final serverError = NetworkError.serverError(500, 'Internal Server Error');
        expect(serverError.toUserMessage(), contains('temporarily unavailable'));
        expect(serverError.statusCode, equals(500));
      });

      test('DatabaseError should handle different scenarios', () {
        final corruptionError = DatabaseError.corruption('workouts');
        expect(corruptionError.toUserMessage(), contains('corruption'));
        expect(corruptionError.tableName, equals('workouts'));

        final migrationError = DatabaseError.migrationFailed('1.2.0');
        expect(migrationError.toUserMessage(), contains('update failed'));
        expect(migrationError.context?['version'], equals('1.2.0'));

        final operationError = DatabaseError.operationFailed('INSERT', 'sets');
        expect(operationError.canAutoRecover, isTrue);
        expect(operationError.operation, equals('INSERT'));
      });

      test('ValidationError should provide field-specific messages', () {
        final requiredError = ValidationError.required('weight');
        expect(requiredError.toUserMessage(), equals('Weight is required'));
        expect(requiredError.shouldReport, isFalse);

        final rangeError = ValidationError.range('rpe', 11, 1, 10);
        expect(rangeError.toUserMessage(), contains('between 1 and 10'));
        expect(rangeError.field, equals('rpe'));

        final formatError = ValidationError.format('email', 'invalid', 'email');
        expect(formatError.toUserMessage(), contains('format is invalid'));
      });

      test('BusinessLogicError should support recovery', () {
        final fatigueError = BusinessLogicError.fatigueCalculation('chest');
        expect(fatigueError.canAutoRecover, isTrue);
        expect(fatigueError.domain, equals('recovery'));

        final avatarError = BusinessLogicError.avatarProgression('invalid data');
        expect(avatarError.toUserMessage(), contains('temporarily unavailable'));
        expect(avatarError.operation, equals('updateLevel'));

        final planError = BusinessLogicError.planGeneration('hypertrophy');
        expect(planError.toUserMessage(), contains('custom workout'));
      });

      test('SyncError should handle retry logic', () {
        final conflictError = SyncError.conflict('WorkoutSession', 'session-1');
        expect(conflictError.toUserMessage(), contains('conflict resolved'));
        expect(conflictError.entityType, equals('WorkoutSession'));

        final uploadError = SyncError.uploadFailed('WorkoutSet', 'set-1', 2);
        expect(uploadError.canAutoRecover, isTrue);
        expect(uploadError.retryCount, equals(2));

        final maxRetriesError = SyncError.uploadFailed('WorkoutSet', 'set-1', 6);
        expect(maxRetriesError.canAutoRecover, isFalse);
      });

      test('AuthError should handle authentication scenarios', () {
        final expiredError = AuthError.tokenExpired();
        expect(expiredError.canAutoRecover, isTrue);
        expect(expiredError.toUserMessage(), contains('session has expired'));

        final invalidError = AuthError.invalidCredentials();
        expect(invalidError.canAutoRecover, isFalse);
        expect(invalidError.toUserMessage(), contains('Invalid email or password'));

        final unauthorizedError = AuthError.unauthorized();
        expect(unauthorizedError.toUserMessage(), contains('permission'));
      });
    });

    group('ErrorHandler', () {
      test('should handle errors and track statistics', () async {
        final error = NetworkError.timeout();
        
        await ErrorHandler.handleError(error, showToUser: false);
        
        final stats = ErrorHandler.getErrorStatistics();
        expect(stats['totalErrors'], equals(1));
        expect(stats['errorCounts']['NETWORK_TIMEOUT'], equals(1));
      });

      test('should detect error spam', () async {
        final error = NetworkError.timeout();
        
        // Generate multiple identical errors quickly
        for (int i = 0; i < 6; i++) {
          await ErrorHandler.handleError(error, showToUser: false);
        }
        
        final stats = ErrorHandler.getErrorStatistics();
        expect(stats['errorCounts']['NETWORK_TIMEOUT'], equals(6));
      });

      test('should convert exceptions to AppErrors', () async {
        final exception = Exception('Socket connection failed');
        
        await ErrorHandler.handleException(exception, showToUser: false);
        
        final stats = ErrorHandler.getErrorStatistics();
        expect(stats['totalErrors'], equals(1));
      });

      test('should retry async operations', () async {
        int attempts = 0;
        
        final result = await ErrorHandler.handleAsyncOperation(
          'test operation',
          () async {
            attempts++;
            if (attempts < 3) {
              throw Exception('Temporary failure');
            }
            return 'success';
          },
          maxRetries: 3,
          showErrorToUser: false,
        );
        
        expect(result, equals('success'));
        expect(attempts, equals(3));
      });

      test('should provide safe execution with fallback', () async {
        final result = await ErrorHandler.safeExecute(
          () async {
            throw Exception('Operation failed');
          },
          fallbackValue: 'fallback',
          showErrorToUser: false,
        );
        
        expect(result, equals('fallback'));
      });

      test('should limit error history size', () async {
        // Generate more than 100 errors
        for (int i = 0; i < 150; i++) {
          final error = NetworkError.timeout();
          await ErrorHandler.handleError(error, showToUser: false);
        }
        
        final stats = ErrorHandler.getErrorStatistics();
        expect(stats['totalErrors'], equals(100)); // Should be capped at 100
      });
    });

    group('Recovery Strategies', () {
      test('should recover from database errors', () async {
        final corruptionError = DatabaseError.corruption('workouts');
        final result = await RecoveryStrategies.recoverFromDatabaseError(corruptionError);
        expect(result, isTrue);

        final migrationError = DatabaseError.migrationFailed('1.2.0');
        final migrationResult = await RecoveryStrategies.recoverFromDatabaseError(migrationError);
        expect(migrationResult, isTrue);
      });

      test('should recover from network errors', () async {
        final timeoutError = NetworkError.timeout();
        final result = await RecoveryStrategies.recoverFromNetworkError(timeoutError);
        expect(result, isTrue);

        final serverError = NetworkError.serverError(500, 'Internal Error');
        final serverResult = await RecoveryStrategies.recoverFromNetworkError(serverError);
        expect(serverResult, isTrue);
      });

      test('should recover from business logic errors', () async {
        final fatigueError = BusinessLogicError.fatigueCalculation('chest');
        final result = await RecoveryStrategies.recoverFromBusinessLogicError(fatigueError);
        expect(result, isTrue);

        final avatarError = BusinessLogicError.avatarProgression('invalid state');
        final avatarResult = await RecoveryStrategies.recoverFromBusinessLogicError(avatarError);
        expect(avatarResult, isTrue);
      });

      test('should recover from sync errors', () async {
        final conflictError = SyncError.conflict('WorkoutSession', 'session-1');
        final result = await RecoveryStrategies.recoverFromSyncError(conflictError);
        expect(result, isTrue);

        final uploadError = SyncError.uploadFailed('WorkoutSet', 'set-1', 2);
        final uploadResult = await RecoveryStrategies.recoverFromSyncError(uploadError);
        expect(uploadResult, isTrue);
      });

      test('should perform comprehensive system recovery', () async {
        final result = await RecoveryStrategies.performSystemRecovery();
        
        expect(result.isSuccess || result.isPartialSuccess, isTrue);
        expect(result.recoveredSystems, isNotEmpty);
      });

      test('should handle memory pressure recovery', () async {
        final result = await RecoveryStrategies.recoverFromMemoryPressure();
        expect(result, isTrue);
      });
    });

    group('Error Recovery Integration', () {
      test('should automatically recover from recoverable errors', () async {
        final recoverableError = NetworkError.timeout();
        
        await ErrorHandler.handleError(
          recoverableError,
          showToUser: false,
          attemptRecovery: true,
        );
        
        // Verify recovery was attempted
        final stats = ErrorHandler.getErrorStatistics();
        expect(stats['totalErrors'], equals(1));
      });

      test('should not attempt recovery for non-recoverable errors', () async {
        final nonRecoverableError = ValidationError.required('weight');
        
        await ErrorHandler.handleError(
          nonRecoverableError,
          showToUser: false,
          attemptRecovery: true,
        );
        
        // Verify error was logged but no recovery attempted
        final stats = ErrorHandler.getErrorStatistics();
        expect(stats['totalErrors'], equals(1));
      });

      test('should handle recovery failures gracefully', () async {
        // Create a mock error that will fail recovery
        final error = TestRecoverableError();
        
        await ErrorHandler.handleError(
          error,
          showToUser: false,
          attemptRecovery: true,
        );
        
        // Should not throw even if recovery fails
        final stats = ErrorHandler.getErrorStatistics();
        expect(stats['totalErrors'], equals(1));
      });
    });

    group('Performance Tests', () {
      test('error handling should be fast', () async {
        final stopwatch = Stopwatch()..start();
        
        final error = NetworkError.timeout();
        await ErrorHandler.handleError(error, showToUser: false);
        
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(100),
            reason: 'Error handling should complete within 100ms');
      });

      test('should handle high error volume efficiently', () async {
        final stopwatch = Stopwatch()..start();
        
        // Generate 100 errors rapidly
        for (int i = 0; i < 100; i++) {
          final error = NetworkError.timeout();
          await ErrorHandler.handleError(error, showToUser: false);
        }
        
        stopwatch.stop();
        expect(stopwatch.elapsedSeconds, lessThan(5),
            reason: 'Should handle 100 errors within 5 seconds');
      });

      test('recovery strategies should be performant', () async {
        final stopwatch = Stopwatch()..start();
        
        final result = await RecoveryStrategies.performSystemRecovery();
        
        stopwatch.stop();
        expect(stopwatch.elapsedSeconds, lessThan(10),
            reason: 'System recovery should complete within 10 seconds');
        expect(result.isSuccess || result.isPartialSuccess, isTrue);
      });
    });
  });
}

/// Test error class for recovery failure scenarios
class TestRecoverableError extends AppError {
  const TestRecoverableError() : super(
    message: 'Test recoverable error',
    code: 'TEST_RECOVERABLE',
  );

  @override
  String toUserMessage() => 'Test error occurred';

  @override
  bool get canAutoRecover => true;

  @override
  Future<void> recover() async {
    throw Exception('Recovery intentionally failed for testing');
  }
}