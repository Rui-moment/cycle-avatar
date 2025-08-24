import 'dart:async';
import 'package:logger/logger.dart';
import '../../domain/entities/sync_entity.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/entities/user.dart';
import '../datasources/local/sync_manager.dart';
import '../datasources/local/conflict_resolver.dart';
import '../datasources/local/background_sync_service.dart';
import '../datasources/local/sync_retry_manager.dart';

/// Main sync service that coordinates all sync operations
/// Provides a unified interface for the application to interact with sync functionality
class SyncService {
  static final Logger _logger = Logger();
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final SyncManager _syncManager = SyncManager();
  final ConflictResolver _conflictResolver = ConflictResolver();
  final BackgroundSyncService _backgroundSyncService = BackgroundSyncService();
  final SyncRetryManager _retryManager = SyncRetryManager();

  bool _isInitialized = false;

  /// Initialize the sync service
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.w('SyncService already initialized');
      return;
    }

    try {
      _logger.i('Initializing SyncService');
      
      // Initialize background sync service (which initializes other components)
      await _backgroundSyncService.initialize();
      
      _isInitialized = true;
      _logger.i('SyncService initialized successfully');
      
    } catch (e) {
      _logger.e('Failed to initialize SyncService: $e');
      rethrow;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _backgroundSyncService.dispose();
    _isInitialized = false;
  }

  // Public API methods for queuing sync operations

  /// Queue a workout session for sync
  Future<void> syncWorkoutSession(WorkoutSession session) async {
    _ensureInitialized();
    
    final syncEntity = SyncEntity.create(
      entityType: SyncEntityType.workoutSession,
      entityId: session.id,
      data: session.toJson(),
      priority: SyncPriority.high, // Workout data is high priority
    );
    
    await _syncManager.queueForSync(syncEntity);
    _logger.d('Queued workout session for sync: ${session.id}');
  }

  /// Queue workout sets for sync
  Future<void> syncWorkoutSets(List<WorkoutSet> sets) async {
    _ensureInitialized();
    
    final syncEntities = sets.map((set) => SyncEntity.create(
      entityType: SyncEntityType.workoutSet,
      entityId: set.id,
      data: set.toJson(),
      priority: SyncPriority.high,
    )).toList();
    
    await _syncManager.queueBatchForSync(syncEntities);
    _logger.d('Queued ${sets.length} workout sets for sync');
  }

  /// Queue user data for sync
  Future<void> syncUser(User user) async {
    _ensureInitialized();
    
    final syncEntity = SyncEntity.update(
      entityType: SyncEntityType.user,
      entityId: user.id,
      data: user.toJson(),
      priority: SyncPriority.normal,
    );
    
    await _syncManager.queueForSync(syncEntity);
    _logger.d('Queued user data for sync: ${user.id}');
  }

  /// Queue entity deletion for sync
  Future<void> syncDeletion({
    required SyncEntityType entityType,
    required String entityId,
  }) async {
    _ensureInitialized();
    
    final syncEntity = SyncEntity.delete(
      entityType: entityType,
      entityId: entityId,
      priority: SyncPriority.normal,
    );
    
    await _syncManager.queueForSync(syncEntity);
    _logger.d('Queued deletion for sync: ${entityType.name}:$entityId');
  }

  // Sync control methods

  /// Trigger immediate sync
  Future<void> triggerSync() async {
    _ensureInitialized();
    await _backgroundSyncService.triggerImmediateSync();
  }

  /// Enable or disable background sync
  void setBackgroundSyncEnabled(bool enabled) {
    _ensureInitialized();
    _backgroundSyncService.setBackgroundSyncEnabled(enabled);
  }

  /// Get current sync progress
  Future<SyncProgress> getSyncProgress() async {
    _ensureInitialized();
    return await _backgroundSyncService.getSyncProgress();
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStatistics() async {
    _ensureInitialized();
    return await _syncManager.getSyncStatistics();
  }

  /// Clear completed sync entities
  Future<void> clearCompletedSyncEntities() async {
    _ensureInitialized();
    await _syncManager.clearCompletedSyncEntities();
  }

  /// Clear all sync entities (use with caution)
  Future<void> clearAllSyncEntities() async {
    _ensureInitialized();
    await _syncManager.clearAllSyncEntities();
  }

  // Stream subscriptions

  /// Stream of sync results
  Stream<SyncResult> get syncResults => _syncManager.syncResults;

  /// Stream of sync status changes
  Stream<SyncStatus> get syncStatus => _syncManager.syncStatus;

  /// Stream of background sync status updates
  Stream<BackgroundSyncStatus> get backgroundSyncStatus => 
      _backgroundSyncService.statusUpdates;

  /// Stream of network status updates
  Stream<NetworkStatus> get networkStatus => 
      _backgroundSyncService.networkStatusUpdates;

  /// Stream of detected conflicts
  Stream<SyncConflict> get conflicts => _conflictResolver.conflicts;

  // Status getters

  /// Current sync status
  SyncStatus get currentSyncStatus => _syncManager.currentStatus;

  /// Current network status
  NetworkStatus get currentNetworkStatus => 
      _backgroundSyncService.currentNetworkStatus;

  /// Whether background sync is enabled
  bool get isBackgroundSyncEnabled => 
      _backgroundSyncService.isBackgroundSyncEnabled;

  // Helper methods for specific entity types

  /// Sync a complete workout session with all its sets
  Future<void> syncCompleteWorkout({
    required WorkoutSession session,
    required List<WorkoutSet> sets,
  }) async {
    _ensureInitialized();
    
    try {
      // Queue session first
      await syncWorkoutSession(session);
      
      // Then queue all sets
      await syncWorkoutSets(sets);
      
      _logger.i('Queued complete workout for sync: ${session.id} with ${sets.length} sets');
      
    } catch (e) {
      _logger.e('Failed to sync complete workout: $e');
      rethrow;
    }
  }

  /// Sync user profile updates
  Future<void> syncUserProfile(User user) async {
    await syncUser(user);
  }

  /// Sync template data
  Future<void> syncTemplate(Map<String, dynamic> templateData) async {
    _ensureInitialized();
    
    final syncEntity = SyncEntity.create(
      entityType: SyncEntityType.template,
      entityId: templateData['id'] as String,
      data: templateData,
      priority: SyncPriority.normal,
    );
    
    await _syncManager.queueForSync(syncEntity);
    _logger.d('Queued template for sync: ${templateData['id']}');
  }

  /// Sync PR record
  Future<void> syncPRRecord(Map<String, dynamic> prData) async {
    _ensureInitialized();
    
    final syncEntity = SyncEntity.create(
      entityType: SyncEntityType.prRecord,
      entityId: prData['id'] as String,
      data: prData,
      priority: SyncPriority.high, // PR records are important
    );
    
    await _syncManager.queueForSync(syncEntity);
    _logger.d('Queued PR record for sync: ${prData['id']}');
  }

  /// Sync avatar state
  Future<void> syncAvatarState(Map<String, dynamic> avatarData) async {
    _ensureInitialized();
    
    final syncEntity = SyncEntity.update(
      entityType: SyncEntityType.avatarState,
      entityId: avatarData['id'] as String,
      data: avatarData,
      priority: SyncPriority.normal,
    );
    
    await _syncManager.queueForSync(syncEntity);
    _logger.d('Queued avatar state for sync: ${avatarData['id']}');
  }

  /// Sync recovery state
  Future<void> syncRecoveryState(Map<String, dynamic> recoveryData) async {
    _ensureInitialized();
    
    final syncEntity = SyncEntity.update(
      entityType: SyncEntityType.recoveryState,
      entityId: recoveryData['id'] as String,
      data: recoveryData,
      priority: SyncPriority.normal,
    );
    
    await _syncManager.queueForSync(syncEntity);
    _logger.d('Queued recovery state for sync: ${recoveryData['id']}');
  }

  /// Sync fatigue event
  Future<void> syncFatigueEvent(Map<String, dynamic> fatigueData) async {
    _ensureInitialized();
    
    final syncEntity = SyncEntity.create(
      entityType: SyncEntityType.fatigueEvent,
      entityId: fatigueData['id'] as String,
      data: fatigueData,
      priority: SyncPriority.normal,
    );
    
    await _syncManager.queueForSync(syncEntity);
    _logger.d('Queued fatigue event for sync: ${fatigueData['id']}');
  }

  // Utility methods

  /// Check if device is online
  bool get isOnline => currentNetworkStatus.isOnline;

  /// Check if sync is currently in progress
  bool get isSyncing => currentSyncStatus == SyncStatus.inProgress;

  /// Get pending sync count
  Future<int> getPendingSyncCount() async {
    _ensureInitialized();
    return await _syncManager.getPendingSyncCount();
  }

  /// Get failed sync count
  Future<int> getFailedSyncCount() async {
    _ensureInitialized();
    return await _syncManager.getFailedSyncCount();
  }

  /// Force sync for testing purposes
  Future<SyncResult> forceSyncForTesting() async {
    _ensureInitialized();
    return await _backgroundSyncService.forceSyncForTesting();
  }

  /// Ensure the service is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('SyncService not initialized. Call initialize() first.');
    }
  }
}

/// Extension methods for easier sync operations
extension SyncServiceExtensions on SyncService {
  /// Sync multiple entities of the same type
  Future<void> syncBatch<T>({
    required SyncEntityType entityType,
    required List<T> entities,
    required String Function(T) getId,
    required Map<String, dynamic> Function(T) toJson,
    SyncPriority priority = SyncPriority.normal,
  }) async {
    _ensureInitialized();
    
    final syncEntities = entities.map((entity) => SyncEntity.create(
      entityType: entityType,
      entityId: getId(entity),
      data: toJson(entity),
      priority: priority,
    )).toList();
    
    await _syncManager.queueBatchForSync(syncEntities);
    SyncService._logger.d('Queued ${entities.length} ${entityType.name} entities for sync');
  }

  /// Sync entity update
  Future<void> syncUpdate<T>({
    required SyncEntityType entityType,
    required T entity,
    required String Function(T) getId,
    required Map<String, dynamic> Function(T) toJson,
    SyncPriority priority = SyncPriority.normal,
  }) async {
    _ensureInitialized();
    
    final syncEntity = SyncEntity.update(
      entityType: entityType,
      entityId: getId(entity),
      data: toJson(entity),
      priority: priority,
    );
    
    await _syncManager.queueForSync(syncEntity);
    SyncService._logger.d('Queued ${entityType.name} update for sync: ${getId(entity)}');
  }
}