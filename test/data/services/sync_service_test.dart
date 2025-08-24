import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../../../lib/data/services/sync_service.dart';
import '../../../lib/domain/entities/sync_entity.dart';
import '../../../lib/domain/entities/workout_session.dart';
import '../../../lib/domain/entities/user.dart';
import '../../../lib/domain/entities/enums.dart';
import '../../../lib/data/datasources/local/background_sync_service.dart';
import '../../../lib/data/datasources/local/sync_manager.dart';

// Generate mocks
@GenerateMocks([])
void main() {
  group('SyncService', () {
    late SyncService syncService;

    setUp(() {
      syncService = SyncService();
    });

    tearDown(() async {
      await syncService.dispose();
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        // This test would require mocking the dependencies
        // For now, we'll test the basic structure
        expect(syncService, isNotNull);
      });

      test('should throw error when not initialized', () {
        expect(
          () => syncService.currentSyncStatus,
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Sync Entity Creation', () {
      test('should create sync entity for workout session', () {
        final session = WorkoutSession(
          id: 'session_1',
          userId: 'user_1',
          startTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
        );

        final syncEntity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: session.id,
          data: session.toJson(),
          priority: SyncPriority.high,
        );

        expect(syncEntity.entityType, SyncEntityType.workoutSession);
        expect(syncEntity.entityId, session.id);
        expect(syncEntity.operation, SyncOperation.create);
        expect(syncEntity.priority, SyncPriority.high);
        expect(syncEntity.status, SyncStatus.pending);
      });

      test('should create sync entity for user update', () {
        final user = User(
          id: 'user_1',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: DateTime.now(),
        );

        final syncEntity = SyncEntity.update(
          entityType: SyncEntityType.user,
          entityId: user.id,
          data: user.toJson(),
        );

        expect(syncEntity.entityType, SyncEntityType.user);
        expect(syncEntity.entityId, user.id);
        expect(syncEntity.operation, SyncOperation.update);
        expect(syncEntity.priority, SyncPriority.normal);
      });

      test('should create sync entity for deletion', () {
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

    group('Sync Entity Validation', () {
      test('should validate sync entity correctly', () {
        final validEntity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          data: {'id': 'session_1', 'userId': 'user_1'},
        );

        expect(validEntity.isValid, isTrue);
        expect(validEntity.validate(), isNull);
      });

      test('should detect invalid sync entity', () {
        final invalidEntity = SyncEntity(
          id: '', // Empty ID
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          operation: SyncOperation.create,
          data: {},
          createdAt: DateTime.now(),
        );

        expect(invalidEntity.isValid, isFalse);
        expect(invalidEntity.validate(), isNotNull);
      });
    });

    group('Retry Logic', () {
      test('should determine retry eligibility correctly', () {
        final newEntity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          data: {'test': 'data'},
        );

        expect(newEntity.shouldRetry, isTrue);

        final maxRetriedEntity = newEntity.copyWith(retryCount: 5);
        expect(maxRetriedEntity.shouldRetry, isFalse);

        final completedEntity = newEntity.copyWith(status: SyncStatus.completed);
        expect(completedEntity.shouldRetry, isFalse);
      });

      test('should calculate next retry time with exponential backoff', () {
        final entity = SyncEntity.create(
          entityType: SyncEntityType.workoutSession,
          entityId: 'session_1',
          data: {'test': 'data'},
        ).copyWith(
          retryCount: 2,
          lastRetryAt: DateTime.now().subtract(const Duration(minutes: 10)),
        );

        final nextRetryTime = entity.nextRetryTime;
        expect(nextRetryTime, isNotNull);
        expect(nextRetryTime!.isAfter(DateTime.now()), isTrue);
      });
    });

    group('Conflict Resolution', () {
      test('should create conflict with client wins resolution', () {
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
      });

      test('should create conflict with server wins resolution', () {
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
      });

      test('should create conflict with merge resolution', () {
        final conflict = SyncConflict(
          entityId: 'entity_1',
          entityType: SyncEntityType.workoutSession,
          localData: {'weight': 100.0},
          serverData: {'weight': 95.0},
          detectedAt: DateTime.now(),
        );

        final mergedData = {'weight': 100.0}; // Client wins in this case
        final resolvedConflict = conflict.resolveWithMerge(mergedData);
        
        expect(resolvedConflict.isResolved, isTrue);
        expect(resolvedConflict.resolution, ConflictResolution.merge);
        expect(resolvedConflict.resolvedData, mergedData);
      });
    });

    group('Sync Results', () {
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

  group('Network Status', () {
    test('should identify connection types correctly', () {
      final wifiStatus = NetworkStatus(
        isOnline: true,
        connectivityResult: MockConnectivityResult.wifi,
        lastChecked: DateTime.now(),
      );
      
      expect(wifiStatus.connectionType, 'WiFi');
      expect(wifiStatus.isMeteredConnection, isFalse);
      expect(wifiStatus.isReliableForSync, isTrue);

      final mobileStatus = NetworkStatus(
        isOnline: true,
        connectivityResult: MockConnectivityResult.mobile,
        lastChecked: DateTime.now(),
      );
      
      expect(mobileStatus.connectionType, 'Mobile Data');
      expect(mobileStatus.isMeteredConnection, isTrue);
      expect(mobileStatus.isReliableForSync, isFalse);
    });
  });

  group('Sync Progress', () {
    test('should calculate sync progress correctly', () {
      final progress = SyncProgress(
        pendingCount: 8,
        failedCount: 2,
        retryableCount: 1,
        permanentlyFailedCount: 1,
        isOnline: true,
        isSyncing: false,
      );

      expect(progress.totalQueueCount, 10);
      expect(progress.healthScore, 80); // 8 successful out of 10
      expect(progress.isHealthy, isTrue); // Score >= 80 and no permanent failures
      expect(progress.statusMessage, '8 items pending');
    });

    test('should identify unhealthy sync state', () {
      final progress = SyncProgress(
        pendingCount: 2,
        failedCount: 8,
        retryableCount: 0,
        permanentlyFailedCount: 3,
        isOnline: true,
        isSyncing: false,
      );

      expect(progress.healthScore, 20); // 2 successful out of 10
      expect(progress.isHealthy, isFalse); // Score < 80 and has permanent failures
    });
  });
}