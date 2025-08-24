import 'package:flutter_test/flutter_test.dart';
import '../../../lib/domain/entities/sync_entity.dart';

void main() {
  group('SyncEntity', () {
    group('Creation', () {
      test('should create sync entity for create operation', () {
        final syncEntity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          data: {'id': 'session_1', 'userId': 'user_1'},
          priority: SyncPriority.high,
        );

        expect(syncEntity.entityType, SyncEntityType.workoutSession);
        expect(syncEntity.entityId, 'session_1');
        expect(syncEntity.operation, SyncOperation.create);
        expect(syncEntity.priority, SyncPriority.high);
        expect(syncEntity.status, SyncStatus.pending);
        expect(syncEntity.retryCount, 0);
        expect(syncEntity.data['id'], 'session_1');
      });

      test('should create sync entity for update operation', () {
        final syncEntity = SyncEntity.update(
          entityType: SyncEntityType.user,
          entityId: 'user_1',
          data: {'id': 'user_1', 'name': 'Test User'},
        );

        expect(syncEntity.entityType, SyncEntityType.user);
        expect(syncEntity.entityId, 'user_1');
        expect(syncEntity.operation, SyncOperation.update);
        expect(syncEntity.priority, SyncPriority.normal);
        expect(syncEntity.status, SyncStatus.pending);
      });

      test('should create sync entity for delete operation', () {
        final syncEntity = SyncEntity.delete(
          entityType: SyncEntityType.template,
          entityId: 'template_1',
        );

        expect(syncEntity.entityType, SyncEntityType.template);
        expect(syncEntity.entityId, 'template_1');
        expect(syncEntity.operation, SyncOperation.delete);
        expect(syncEntity.data, {'id': 'template_1'});
      });
    });

    group('Validation', () {
      test('should validate valid sync entity', () {
        final validEntity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          data: {'id': 'session_1', 'userId': 'user_1'},
        );

        expect(validEntity.isValid, isTrue);
        expect(validEntity.validate(), isNull);
      });

      test('should detect invalid sync entity with empty ID', () {
        final invalidEntity = SyncEntity(
          id: '', // Empty ID
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          operation: SyncOperation.create,
          data: {'test': 'data'},
          createdAt: DateTime.now(),
        );

        expect(invalidEntity.isValid, isFalse);
        expect(invalidEntity.validate(), contains('ID cannot be empty'));
      });

      test('should detect invalid sync entity with empty entity ID', () {
        final invalidEntity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: '', // Empty entity ID
          data: {'test': 'data'},
        );

        expect(invalidEntity.isValid, isFalse);
        expect(invalidEntity.validate(), contains('Entity ID cannot be empty'));
      });

      test('should detect invalid sync entity with empty data for create operation', () {
        final invalidEntity = SyncEntity(
          id: 'sync_1',
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          operation: SyncOperation.create,
          data: {}, // Empty data
          createdAt: DateTime.now(),
        );

        expect(invalidEntity.isValid, isFalse);
        expect(invalidEntity.validate(), contains('Data cannot be empty'));
      });

      test('should allow empty data for delete operation', () {
        final validEntity = SyncEntity(
          id: 'sync_1',
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          operation: SyncOperation.delete,
          data: {}, // Empty data is OK for delete
          createdAt: DateTime.now(),
        );

        expect(validEntity.isValid, isTrue);
      });
    });

    group('Retry Logic', () {
      test('should determine retry eligibility for new entity', () {
        final newEntity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          data: {'test': 'data'},
        );

        expect(newEntity.shouldRetry, isTrue);
        expect(newEntity.nextRetryTime, isNotNull);
      });

      test('should not retry entity that exceeded max attempts', () {
        final maxRetriedEntity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          data: {'test': 'data'},
        ).copyWith(retryCount: 5);

        expect(maxRetriedEntity.shouldRetry, isFalse);
      });

      test('should not retry completed entity', () {
        final completedEntity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          data: {'test': 'data'},
        ).copyWith(status: SyncStatus.completed);

        expect(completedEntity.shouldRetry, isFalse);
      });

      test('should not retry failed entity', () {
        final failedEntity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          data: {'test': 'data'},
        ).copyWith(status: SyncStatus.failed);

        expect(failedEntity.shouldRetry, isFalse);
      });

      test('should calculate next retry time with exponential backoff', () {
        final baseTime = DateTime.now().subtract(const Duration(minutes: 10));
        final entity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          data: {'test': 'data'},
        ).copyWith(
          retryCount: 2,
          lastRetryAt: baseTime,
        );

        final nextRetryTime = entity.nextRetryTime;
        expect(nextRetryTime, isNotNull);
        expect(nextRetryTime!.isAfter(baseTime), isTrue);
        
        // Should be at least 5 minutes after last retry (retry delay for count 2)
        // But accounting for jitter, it might be a bit more
        final expectedMinTime = baseTime.add(const Duration(minutes: 5));
        final expectedMaxTime = baseTime.add(const Duration(minutes: 7)); // 5 + jitter
        expect(nextRetryTime.isAfter(expectedMinTime.subtract(const Duration(seconds: 30))), isTrue);
        expect(nextRetryTime.isBefore(expectedMaxTime), isTrue);
      });
    });

    group('Status Management', () {
      test('should mark entity as failed', () {
        final entity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          data: {'test': 'data'},
        );

        final failedEntity = entity.markAsFailed('Network error');

        expect(failedEntity.status, SyncStatus.failed);
        expect(failedEntity.errorMessage, 'Network error');
        expect(failedEntity.retryCount, entity.retryCount + 1);
        expect(failedEntity.lastRetryAt, isNotNull);
      });

      test('should mark entity as completed', () {
        final entity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          data: {'test': 'data'},
        );

        final completedEntity = entity.markAsCompleted();

        expect(completedEntity.status, SyncStatus.completed);
        expect(completedEntity.errorMessage, isNull);
      });

      test('should mark entity as in progress', () {
        final entity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          data: {'test': 'data'},
        );

        final inProgressEntity = entity.markAsInProgress();

        expect(inProgressEntity.status, SyncStatus.inProgress);
        expect(inProgressEntity.lastRetryAt, isNotNull);
      });

      test('should increment retry count', () {
        final entity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          data: {'test': 'data'},
        );

        final retriedEntity = entity.incrementRetry('Temporary error');

        expect(retriedEntity.retryCount, entity.retryCount + 1);
        expect(retriedEntity.errorMessage, 'Temporary error');
        expect(retriedEntity.status, SyncStatus.pending);
        expect(retriedEntity.lastRetryAt, isNotNull);
      });
    });

    group('Entity Type Mapping', () {
      test('should map entity types to table names correctly', () {
        expect(SyncEntityType.workoutSession.tableName, 'workout_sessions');
        expect(SyncEntityType.workoutSet.tableName, 'workout_sets');
        expect(SyncEntityType.user.tableName, 'users');
        expect(SyncEntityType.template.tableName, 'templates');
        expect(SyncEntityType.prRecord.tableName, 'pr_records');
        expect(SyncEntityType.avatarState.tableName, 'avatar_states');
        expect(SyncEntityType.recoveryState.tableName, 'recovery_states');
        expect(SyncEntityType.fatigueEvent.tableName, 'fatigue_events');
        expect(SyncEntityType.notification.tableName, 'notifications');
      });

      test('should map operations to HTTP methods correctly', () {
        expect(SyncOperation.create.httpMethod, 'POST');
        expect(SyncOperation.update.httpMethod, 'PUT');
        expect(SyncOperation.delete.httpMethod, 'DELETE');
      });
    });

    group('Priority System', () {
      test('should order priorities correctly', () {
        expect(SyncPriority.critical.value, 4);
        expect(SyncPriority.high.value, 3);
        expect(SyncPriority.normal.value, 2);
        expect(SyncPriority.low.value, 1);
        
        expect(SyncPriority.critical.value > SyncPriority.high.value, isTrue);
        expect(SyncPriority.high.value > SyncPriority.normal.value, isTrue);
        expect(SyncPriority.normal.value > SyncPriority.low.value, isTrue);
      });
    });

    group('Status Tracking', () {
      test('should track sync status correctly', () {
        expect(SyncStatus.pending.isPending, isTrue);
        expect(SyncStatus.inProgress.isInProgress, isTrue);
        expect(SyncStatus.completed.isCompleted, isTrue);
        expect(SyncStatus.failed.isFailed, isTrue);
        
        expect(SyncStatus.pending.isCompleted, isFalse);
        expect(SyncStatus.completed.isFailed, isFalse);
      });
    });
  });

  group('SyncResult', () {
    test('should create successful sync result', () {
      final result = SyncResult.success(
        processedCount: 10,
        duration: const Duration(seconds: 5),
      );

      expect(result.success, isTrue);
      expect(result.processedCount, 10);
      expect(result.failedCount, 0);
      expect(result.totalCount, 10);
      expect(result.successRate, 100.0);
      expect(result.failedEntityIds, isEmpty);
    });

    test('should create failed sync result', () {
      final result = SyncResult.failure(
        processedCount: 8,
        failedCount: 2,
        failedEntityIds: ['entity_1', 'entity_2'],
        duration: const Duration(seconds: 5),
        errorMessage: 'Network error',
      );

      expect(result.success, isFalse);
      expect(result.processedCount, 8);
      expect(result.failedCount, 2);
      expect(result.totalCount, 10);
      expect(result.successRate, 80.0);
      expect(result.failedEntityIds, ['entity_1', 'entity_2']);
      expect(result.errorMessage, 'Network error');
    });

    test('should calculate success rate correctly', () {
      final result = SyncResult.failure(
        processedCount: 7,
        failedCount: 3,
        failedEntityIds: ['1', '2', '3'],
        duration: const Duration(seconds: 1),
      );

      expect(result.successRate, 70.0);
    });

    test('should handle zero total count', () {
      final result = SyncResult.success(
        processedCount: 0,
        duration: const Duration(seconds: 1),
      );

      expect(result.successRate, 0.0);
    });
  });

  group('SyncConflict', () {
    test('should create conflict', () {
      final conflict = SyncConflict(
        entityId: 'entity_1',
        entityType: SyncEntityType.workoutSession,
        localData: {'weight': 100.0},
        serverData: {'weight': 95.0},
        detectedAt: DateTime.now(),
      );

      expect(conflict.entityId, 'entity_1');
      expect(conflict.entityType, SyncEntityType.workoutSession);
      expect(conflict.localData['weight'], 100.0);
      expect(conflict.serverData['weight'], 95.0);
      expect(conflict.isResolved, isFalse);
    });

    test('should resolve conflict with client wins', () {
      final conflict = SyncConflict(
        entityId: 'entity_1',
        entityType: SyncEntityType.workoutSession,
        localData: {'weight': 100.0},
        serverData: {'weight': 95.0},
        detectedAt: DateTime.now(),
      );

      final resolvedConflict = conflict.resolveWithClient();
      
      expect(resolvedConflict.isResolved, isTrue);
      expect(resolvedConflict.resolution, ConflictResolution.clientWins);
      expect(resolvedConflict.resolvedData, {'weight': 100.0});
      expect(resolvedConflict.resolvedAt, isNotNull);
    });

    test('should resolve conflict with server wins', () {
      final conflict = SyncConflict(
        entityId: 'entity_1',
        entityType: SyncEntityType.workoutSession,
        localData: {'weight': 100.0},
        serverData: {'weight': 95.0},
        detectedAt: DateTime.now(),
      );

      final resolvedConflict = conflict.resolveWithServer();
      
      expect(resolvedConflict.isResolved, isTrue);
      expect(resolvedConflict.resolution, ConflictResolution.serverWins);
      expect(resolvedConflict.resolvedData, {'weight': 95.0});
      expect(resolvedConflict.resolvedAt, isNotNull);
    });

    test('should resolve conflict with merge', () {
      final conflict = SyncConflict(
        entityId: 'entity_1',
        entityType: SyncEntityType.workoutSession,
        localData: {'weight': 100.0},
        serverData: {'weight': 95.0},
        detectedAt: DateTime.now(),
      );

      final mergedData = {'weight': 97.5}; // Average
      final resolvedConflict = conflict.resolveWithMerge(mergedData);
      
      expect(resolvedConflict.isResolved, isTrue);
      expect(resolvedConflict.resolution, ConflictResolution.merge);
      expect(resolvedConflict.resolvedData, mergedData);
      expect(resolvedConflict.resolvedAt, isNotNull);
    });
  });
}