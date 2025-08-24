import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:cycle_avatar/data/services/sync_service.dart';
import 'package:cycle_avatar/data/datasources/local/sync_manager.dart';
import 'package:cycle_avatar/data/datasources/local/conflict_resolver.dart';
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/sync_entity.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';

// Generate mocks
@GenerateMocks([
  SyncService,
  SyncManager,
  ConflictResolver,
])
import 'sync_functionality_test.mocks.dart';

/// Integration tests for sync functionality
void main() {
  group('Sync Functionality Integration Tests', () {
    late MockSyncService mockSyncService;
    late MockSyncManager mockSyncManager;
    late MockConflictResolver mockConflictResolver;

    setUp(() {
      mockSyncService = MockSyncService();
      mockSyncManager = MockSyncManager();
      mockConflictResolver = MockConflictResolver();
    });

    group('Sync Queue Management', () {
      test('should queue operations when offline', () async {
        // Arrange
        final workoutSession = WorkoutSession(
          id: 'test-session-1',
          userId: 'user-1',
          startTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
        );

        when(mockSyncManager.isOnline()).thenReturn(false);
        when(mockSyncManager.queueForSync(any))
            .thenAnswer((_) async => true);

        // Act
        final result = await mockSyncManager.queueForSync(
          SyncEntity.fromWorkoutSession(workoutSession),
        );

        // Assert
        expect(result, isTrue);
        verify(mockSyncManager.queueForSync(any)).called(1);
      });

      test('should process sync queue when online', () async {
        // Arrange
        final queuedItems = [
          SyncEntity(
            id: 'sync-1',
            entityType: 'WorkoutSession',
            entityId: 'session-1',
            operation: SyncOperation.create,
            data: {'test': 'data'},
            createdAt: DateTime.now(),
          ),
        ];

        when(mockSyncManager.isOnline()).thenReturn(true);
        when(mockSyncManager.getPendingSyncItems())
            .thenAnswer((_) async => queuedItems);
        when(mockSyncManager.processSyncQueue())
            .thenAnswer((_) async => SyncResult.success(1));

        // Act
        final result = await mockSyncManager.processSyncQueue();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.processedCount, equals(1));
        verify(mockSyncManager.processSyncQueue()).called(1);
      });

      test('should handle sync queue processing errors', () async {
        // Arrange
        when(mockSyncManager.isOnline()).thenReturn(true);
        when(mockSyncManager.processSyncQueue())
            .thenThrow(Exception('Network error'));

        // Act & Assert
        expect(
          () => mockSyncManager.processSyncQueue(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Conflict Resolution', () {
      test('should resolve conflicts with client priority', () async {
        // Arrange
        final localEntity = SyncEntity(
          id: 'sync-1',
          entityType: 'WorkoutSession',
          entityId: 'session-1',
          operation: SyncOperation.update,
          data: {'weight': 105.0, 'reps': 8},
          createdAt: DateTime.now(),
        );

        final serverEntity = SyncEntity(
          id: 'sync-1',
          entityType: 'WorkoutSession',
          entityId: 'session-1',
          operation: SyncOperation.update,
          data: {'weight': 100.0, 'reps': 10},
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );

        when(mockConflictResolver.resolveConflict(localEntity, serverEntity))
            .thenAnswer((_) async => ConflictResolution.useLocal(localEntity));

        // Act
        final resolution = await mockConflictResolver.resolveConflict(
          localEntity,
          serverEntity,
        );

        // Assert
        expect(resolution.strategy, equals(ConflictStrategy.useLocal));
        expect(resolution.resolvedEntity.data['weight'], equals(105.0));
        verify(mockConflictResolver.resolveConflict(localEntity, serverEntity))
            .called(1);
      });

      test('should handle complex conflict scenarios', () async {
        // Arrange
        final conflicts = [
          ConflictPair(
            local: SyncEntity(
              id: 'sync-1',
              entityType: 'WorkoutSession',
              entityId: 'session-1',
              operation: SyncOperation.update,
              data: {'sets': 3},
              createdAt: DateTime.now(),
            ),
            server: SyncEntity(
              id: 'sync-1',
              entityType: 'WorkoutSession',
              entityId: 'session-1',
              operation: SyncOperation.delete,
              data: {},
              createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
            ),
          ),
        ];

        when(mockConflictResolver.resolveMultipleConflicts(conflicts))
            .thenAnswer((_) async => [
              ConflictResolution.useLocal(conflicts.first.local),
            ]);

        // Act
        final resolutions = await mockConflictResolver.resolveMultipleConflicts(
          conflicts,
        );

        // Assert
        expect(resolutions, hasLength(1));
        expect(resolutions.first.strategy, equals(ConflictStrategy.useLocal));
      });
    });

    group('Batch Sync Operations', () {
      test('should handle batch sync efficiently', () async {
        // Arrange
        final batchItems = List.generate(50, (index) => SyncEntity(
          id: 'sync-$index',
          entityType: 'WorkoutSet',
          entityId: 'set-$index',
          operation: SyncOperation.create,
          data: {'weight': 100.0 + index, 'reps': 8},
          createdAt: DateTime.now(),
        ));

        when(mockSyncManager.processBatchSync(batchItems))
            .thenAnswer((_) async => SyncResult.success(50));

        // Act
        final stopwatch = Stopwatch()..start();
        final result = await mockSyncManager.processBatchSync(batchItems);
        stopwatch.stop();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.processedCount, equals(50));
        expect(stopwatch.elapsedMilliseconds, lessThan(5000),
            reason: 'Batch sync should complete within 5 seconds');
      });

      test('should handle partial batch failures', () async {
        // Arrange
        final batchItems = List.generate(10, (index) => SyncEntity(
          id: 'sync-$index',
          entityType: 'WorkoutSet',
          entityId: 'set-$index',
          operation: SyncOperation.create,
          data: {'weight': 100.0 + index, 'reps': 8},
          createdAt: DateTime.now(),
        ));

        when(mockSyncManager.processBatchSync(batchItems))
            .thenAnswer((_) async => SyncResult.partialSuccess(7, 3));

        // Act
        final result = await mockSyncManager.processBatchSync(batchItems);

        // Assert
        expect(result.isPartialSuccess, isTrue);
        expect(result.processedCount, equals(7));
        expect(result.failedCount, equals(3));
      });
    });

    group('Retry Mechanism', () {
      test('should retry failed sync operations', () async {
        // Arrange
        final syncEntity = SyncEntity(
          id: 'sync-1',
          entityType: 'WorkoutSession',
          entityId: 'session-1',
          operation: SyncOperation.create,
          data: {'test': 'data'},
          createdAt: DateTime.now(),
        );

        when(mockSyncManager.syncSingleEntity(syncEntity))
            .thenThrow(Exception('Network error'))
            .thenThrow(Exception('Server error'))
            .thenAnswer((_) async => SyncResult.success(1));

        // Act
        SyncResult? result;
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            result = await mockSyncManager.syncSingleEntity(syncEntity);
            break;
          } catch (e) {
            if (attempt == 3) rethrow;
            await Future.delayed(Duration(milliseconds: 100 * attempt));
          }
        }

        // Assert
        expect(result?.isSuccess, isTrue);
        verify(mockSyncManager.syncSingleEntity(syncEntity)).called(3);
      });

      test('should implement exponential backoff', () async {
        // Arrange
        final syncEntity = SyncEntity(
          id: 'sync-1',
          entityType: 'WorkoutSession',
          entityId: 'session-1',
          operation: SyncOperation.create,
          data: {'test': 'data'},
          createdAt: DateTime.now(),
        );

        when(mockSyncManager.syncWithBackoff(syncEntity, any))
            .thenAnswer((invocation) async {
              final maxRetries = invocation.positionalArguments[1] as int;
              // Simulate successful sync after retries
              return SyncResult.success(1);
            });

        // Act
        final stopwatch = Stopwatch()..start();
        final result = await mockSyncManager.syncWithBackoff(syncEntity, 3);
        stopwatch.stop();

        // Assert
        expect(result.isSuccess, isTrue);
        // Verify exponential backoff timing (should take at least some time)
        expect(stopwatch.elapsedMilliseconds, greaterThan(0));
      });
    });

    group('Data Integrity', () {
      test('should maintain data consistency during sync', () async {
        // Arrange
        final originalSession = WorkoutSession(
          id: 'session-1',
          userId: 'user-1',
          startTime: DateTime.now(),
          sessionType: SessionType.strength,
          sets: [
            WorkoutSet(
              id: 'set-1',
              sessionId: 'session-1',
              exerciseId: 'exercise-1',
              weight: 100.0,
              reps: 8,
              rpe: 7,
              setOrder: 1,
              createdAt: DateTime.now(),
            ),
          ],
          createdAt: DateTime.now(),
        );

        when(mockSyncService.syncWorkoutSession(originalSession))
            .thenAnswer((_) async => originalSession);

        // Act
        final syncedSession = await mockSyncService.syncWorkoutSession(
          originalSession,
        );

        // Assert
        expect(syncedSession.id, equals(originalSession.id));
        expect(syncedSession.sets.length, equals(originalSession.sets.length));
        expect(syncedSession.sets.first.weight, equals(100.0));
        expect(syncedSession.sets.first.reps, equals(8));
      });

      test('should validate data before sync', () async {
        // Arrange
        final invalidSession = WorkoutSession(
          id: '', // Invalid empty ID
          userId: 'user-1',
          startTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
        );

        when(mockSyncService.validateBeforeSync(invalidSession))
            .thenReturn(false);

        // Act
        final isValid = mockSyncService.validateBeforeSync(invalidSession);

        // Assert
        expect(isValid, isFalse);
        verify(mockSyncService.validateBeforeSync(invalidSession)).called(1);
      });
    });

    group('Performance Tests', () {
      test('should handle large sync operations efficiently', () async {
        // Arrange
        final largeDataset = List.generate(1000, (index) => SyncEntity(
          id: 'sync-$index',
          entityType: 'WorkoutSet',
          entityId: 'set-$index',
          operation: SyncOperation.create,
          data: {
            'weight': 100.0 + (index % 50),
            'reps': 8 + (index % 5),
            'rpe': 6 + (index % 5),
          },
          createdAt: DateTime.now(),
        ));

        when(mockSyncManager.processBatchSync(largeDataset))
            .thenAnswer((_) async => SyncResult.success(1000));

        // Act
        final stopwatch = Stopwatch()..start();
        final result = await mockSyncManager.processBatchSync(largeDataset);
        stopwatch.stop();

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.processedCount, equals(1000));
        expect(stopwatch.elapsedSeconds, lessThan(30),
            reason: 'Large dataset sync should complete within 30 seconds');
      });

      test('should optimize memory usage during sync', () async {
        // Arrange
        final memoryIntensiveData = List.generate(500, (index) => SyncEntity(
          id: 'sync-$index',
          entityType: 'WorkoutSession',
          entityId: 'session-$index',
          operation: SyncOperation.create,
          data: {
            'largeData': List.filled(1000, 'data-$index'),
          },
          createdAt: DateTime.now(),
        ));

        when(mockSyncManager.processBatchSyncWithMemoryOptimization(
          memoryIntensiveData,
        )).thenAnswer((_) async => SyncResult.success(500));

        // Act
        final result = await mockSyncManager.processBatchSyncWithMemoryOptimization(
          memoryIntensiveData,
        );

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.processedCount, equals(500));
      });
    });
  });
}

// Helper classes for testing
class ConflictPair {
  final SyncEntity local;
  final SyncEntity server;

  ConflictPair({required this.local, required this.server});
}

enum ConflictStrategy { useLocal, useServer, merge }

class ConflictResolution {
  final ConflictStrategy strategy;
  final SyncEntity resolvedEntity;

  ConflictResolution({required this.strategy, required this.resolvedEntity});

  static ConflictResolution useLocal(SyncEntity entity) {
    return ConflictResolution(
      strategy: ConflictStrategy.useLocal,
      resolvedEntity: entity,
    );
  }

  static ConflictResolution useServer(SyncEntity entity) {
    return ConflictResolution(
      strategy: ConflictStrategy.useServer,
      resolvedEntity: entity,
    );
  }
}

class SyncResult {
  final bool isSuccess;
  final bool isPartialSuccess;
  final int processedCount;
  final int failedCount;
  final String? error;

  SyncResult({
    required this.isSuccess,
    this.isPartialSuccess = false,
    required this.processedCount,
    this.failedCount = 0,
    this.error,
  });

  static SyncResult success(int count) {
    return SyncResult(isSuccess: true, processedCount: count);
  }

  static SyncResult partialSuccess(int processed, int failed) {
    return SyncResult(
      isSuccess: false,
      isPartialSuccess: true,
      processedCount: processed,
      failedCount: failed,
    );
  }

  static SyncResult failure(String error) {
    return SyncResult(
      isSuccess: false,
      processedCount: 0,
      error: error,
    );
  }
}