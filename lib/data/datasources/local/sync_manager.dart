import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';
import '../../../domain/entities/sync_entity.dart';
import 'database_helper.dart';

/// Mock connectivity result for testing
enum MockConnectivityResult { none, wifi, mobile, ethernet }

/// Mock connectivity class for testing
class MockConnectivity {
  static final MockConnectivity _instance = MockConnectivity._internal();
  factory MockConnectivity() => _instance;
  MockConnectivity._internal();

  final StreamController<MockConnectivityResult> _controller = 
      StreamController<MockConnectivityResult>.broadcast();

  Stream<MockConnectivityResult> get onConnectivityChanged => _controller.stream;

  Future<MockConnectivityResult> checkConnectivity() async {
    // Simulate network check
    return MockConnectivityResult.wifi;
  }

  void simulateConnectivityChange(MockConnectivityResult result) {
    _controller.add(result);
  }
}

/// Manages offline synchronization queue and operations
/// Implements Requirements 6.1, 6.2 - Offline priority sync with queueing
class SyncManager {
  static final Logger _logger = Logger();
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final MockConnectivity _connectivity = MockConnectivity();
  
  Timer? _syncTimer;
  bool _isSyncing = false;
  final StreamController<SyncResult> _syncResultController = 
      StreamController<SyncResult>.broadcast();
  final StreamController<SyncStatus> _syncStatusController = 
      StreamController<SyncStatus>.broadcast();

  /// Stream of sync results
  Stream<SyncResult> get syncResults => _syncResultController.stream;
  
  /// Stream of sync status changes
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  /// Current sync status
  SyncStatus _currentStatus = SyncStatus.pending;
  SyncStatus get currentStatus => _currentStatus;

  /// Initialize the sync manager
  Future<void> initialize() async {
    _logger.i('Initializing SyncManager');
    
    // Start periodic sync check
    _startPeriodicSync();
    
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    
    _logger.i('SyncManager initialized');
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _syncResultController.close();
    _syncStatusController.close();
  }

  /// Queue an entity for synchronization
  /// Implements Requirements 6.1 - Offline operations queueing
  Future<void> queueForSync(SyncEntity syncEntity) async {
    try {
      _logger.d('Queueing entity for sync: ${syncEntity.entityType.name}:${syncEntity.entityId}');
      
      final db = await _databaseHelper.database;
      
      // Check if a similar sync operation already exists
      final existing = await _findExistingSyncEntity(
        syncEntity.entityType,
        syncEntity.entityId,
        syncEntity.operation,
      );
      
      if (existing != null) {
        // Update existing sync entity with new data
        await _updateSyncEntity(existing.copyWith(
          data: syncEntity.data,
          createdAt: DateTime.now(),
          retryCount: 0,
          errorMessage: null,
          status: SyncStatus.pending,
        ));
        _logger.d('Updated existing sync entity: ${existing.id}');
      } else {
        // Insert new sync entity
        await _insertSyncEntity(syncEntity);
        _logger.d('Inserted new sync entity: ${syncEntity.id}');
      }
      
      // Trigger immediate sync if online
      if (await _isOnline()) {
        _triggerSync();
      }
      
    } catch (e) {
      _logger.e('Failed to queue entity for sync: $e');
      rethrow;
    }
  }

  /// Queue multiple entities for synchronization in batch
  Future<void> queueBatchForSync(List<SyncEntity> syncEntities) async {
    if (syncEntities.isEmpty) return;
    
    try {
      _logger.d('Queueing ${syncEntities.length} entities for batch sync');
      
      final db = await _databaseHelper.database;
      final batch = db.batch();
      
      for (final syncEntity in syncEntities) {
        // Check for existing sync operations
        final existing = await _findExistingSyncEntity(
          syncEntity.entityType,
          syncEntity.entityId,
          syncEntity.operation,
        );
        
        if (existing != null) {
          // Update existing
          batch.update(
            'sync_queue',
            _syncEntityToMap(existing.copyWith(
              data: syncEntity.data,
              createdAt: DateTime.now(),
              retryCount: 0,
              errorMessage: null,
              status: SyncStatus.pending,
            )),
            where: 'id = ?',
            whereArgs: [existing.id],
          );
        } else {
          // Insert new
          batch.insert('sync_queue', _syncEntityToMap(syncEntity));
        }
      }
      
      await batch.commit(noResult: true);
      _logger.d('Batch queued successfully');
      
      // Trigger sync if online
      if (await _isOnline()) {
        _triggerSync();
      }
      
    } catch (e) {
      _logger.e('Failed to queue batch for sync: $e');
      rethrow;
    }
  }

  /// Perform synchronization of queued entities
  /// Implements Requirements 6.2 - Batch processing with priority
  Future<SyncResult> performSync({bool forceSync = false}) async {
    if (_isSyncing && !forceSync) {
      _logger.d('Sync already in progress, skipping');
      return SyncResult.success(processedCount: 0, duration: Duration.zero);
    }

    _isSyncing = true;
    _updateSyncStatus(SyncStatus.inProgress);
    
    final stopwatch = Stopwatch()..start();
    int processedCount = 0;
    int failedCount = 0;
    final List<String> failedEntityIds = [];
    String? errorMessage;

    try {
      _logger.i('Starting sync operation');
      
      // Check network connectivity
      if (!await _isOnline()) {
        _logger.w('No network connectivity, skipping sync');
        return SyncResult.success(processedCount: 0, duration: stopwatch.elapsed);
      }

      // Get pending sync entities ordered by priority and creation time
      final pendingSyncEntities = await _getPendingSyncEntities();
      
      if (pendingSyncEntities.isEmpty) {
        _logger.d('No pending sync entities found');
        return SyncResult.success(processedCount: 0, duration: stopwatch.elapsed);
      }

      _logger.i('Found ${pendingSyncEntities.length} entities to sync');

      // Process entities in batches based on priority
      final batches = _groupEntitiesByPriority(pendingSyncEntities);
      
      for (final batch in batches) {
        final batchResult = await _processSyncBatch(batch);
        processedCount += batchResult.processedCount;
        failedCount += batchResult.failedCount;
        failedEntityIds.addAll(batchResult.failedEntityIds);
        
        if (batchResult.errorMessage != null) {
          errorMessage = batchResult.errorMessage;
        }
      }

      stopwatch.stop();
      
      final result = failedCount == 0
          ? SyncResult.success(
              processedCount: processedCount,
              duration: stopwatch.elapsed,
              metadata: {'total_entities': pendingSyncEntities.length},
            )
          : SyncResult.failure(
              processedCount: processedCount,
              failedCount: failedCount,
              failedEntityIds: failedEntityIds,
              duration: stopwatch.elapsed,
              errorMessage: errorMessage,
              metadata: {'total_entities': pendingSyncEntities.length},
            );

      _logger.i('Sync completed: ${result.successRate.toStringAsFixed(1)}% success rate');
      _syncResultController.add(result);
      
      return result;

    } catch (e) {
      stopwatch.stop();
      _logger.e('Sync operation failed: $e');
      
      final result = SyncResult.failure(
        processedCount: processedCount,
        failedCount: failedCount + 1,
        failedEntityIds: failedEntityIds,
        duration: stopwatch.elapsed,
        errorMessage: e.toString(),
      );
      
      _syncResultController.add(result);
      return result;
      
    } finally {
      _isSyncing = false;
      _updateSyncStatus(SyncStatus.pending);
    }
  }

  /// Get pending sync entities count
  Future<int> getPendingSyncCount() async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue WHERE status = ?',
        [SyncStatus.pending.name],
      );
      return result.first['count'] as int;
    } catch (e) {
      _logger.e('Failed to get pending sync count: $e');
      return 0;
    }
  }

  /// Get failed sync entities count
  Future<int> getFailedSyncCount() async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue WHERE status = ?',
        [SyncStatus.failed.name],
      );
      return result.first['count'] as int;
    } catch (e) {
      _logger.e('Failed to get failed sync count: $e');
      return 0;
    }
  }

  /// Clear completed sync entities from queue
  Future<void> clearCompletedSyncEntities() async {
    try {
      final db = await _databaseHelper.database;
      final deletedCount = await db.delete(
        'sync_queue',
        where: 'status = ?',
        whereArgs: [SyncStatus.completed.name],
      );
      _logger.d('Cleared $deletedCount completed sync entities');
    } catch (e) {
      _logger.e('Failed to clear completed sync entities: $e');
    }
  }

  /// Clear all sync entities (use with caution)
  Future<void> clearAllSyncEntities() async {
    try {
      final db = await _databaseHelper.database;
      final deletedCount = await db.delete('sync_queue');
      _logger.w('Cleared all $deletedCount sync entities');
    } catch (e) {
      _logger.e('Failed to clear all sync entities: $e');
    }
  }

  /// Get sync queue statistics
  Future<Map<String, dynamic>> getSyncStatistics() async {
    try {
      final db = await _databaseHelper.database;
      
      final statusCounts = await db.rawQuery('''
        SELECT status, COUNT(*) as count 
        FROM sync_queue 
        GROUP BY status
      ''');
      
      final priorityCounts = await db.rawQuery('''
        SELECT priority, COUNT(*) as count 
        FROM sync_queue 
        WHERE status != ?
        GROUP BY priority
      ''', [SyncStatus.completed.name]);
      
      final entityTypeCounts = await db.rawQuery('''
        SELECT entity_type, COUNT(*) as count 
        FROM sync_queue 
        WHERE status != ?
        GROUP BY entity_type
      ''', [SyncStatus.completed.name]);
      
      final oldestPending = await db.rawQuery('''
        SELECT MIN(created_at) as oldest_timestamp
        FROM sync_queue 
        WHERE status = ?
      ''', [SyncStatus.pending.name]);
      
      return {
        'status_counts': {
          for (final row in statusCounts)
            row['status']: row['count']
        },
        'priority_counts': {
          for (final row in priorityCounts)
            row['priority']: row['count']
        },
        'entity_type_counts': {
          for (final row in entityTypeCounts)
            row['entity_type']: row['count']
        },
        'oldest_pending_timestamp': oldestPending.first['oldest_timestamp'],
        'is_syncing': _isSyncing,
        'current_status': _currentStatus.name,
      };
    } catch (e) {
      _logger.e('Failed to get sync statistics: $e');
      return {};
    }
  }

  // Private methods

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!_isSyncing) {
        _triggerSync();
      }
    });
  }

  void _triggerSync() {
    // Use a microtask to avoid blocking the current execution
    scheduleMicrotask(() async {
      try {
        await performSync();
      } catch (e) {
        _logger.e('Triggered sync failed: $e');
      }
    });
  }

  void _onConnectivityChanged(MockConnectivityResult result) {
    _logger.d('Connectivity changed: $result');
    if (result != MockConnectivityResult.none) {
      // Network is available, trigger sync
      _triggerSync();
    }
  }

  Future<bool> _isOnline() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult != MockConnectivityResult.none;
    } catch (e) {
      _logger.w('Failed to check connectivity: $e');
      return false;
    }
  }

  void _updateSyncStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }

  Future<SyncEntity?> _findExistingSyncEntity(
    SyncEntityType entityType,
    String entityId,
    SyncOperation operation,
  ) async {
    try {
      final db = await _databaseHelper.database;
      final results = await db.query(
        'sync_queue',
        where: 'entity_type = ? AND entity_id = ? AND operation = ? AND status != ?',
        whereArgs: [entityType.name, entityId, operation.name, SyncStatus.completed.name],
        limit: 1,
      );
      
      if (results.isNotEmpty) {
        return _syncEntityFromMap(results.first);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to find existing sync entity: $e');
      return null;
    }
  }

  Future<void> _insertSyncEntity(SyncEntity syncEntity) async {
    final db = await _databaseHelper.database;
    await db.insert('sync_queue', _syncEntityToMap(syncEntity));
  }

  Future<void> _updateSyncEntity(SyncEntity syncEntity) async {
    final db = await _databaseHelper.database;
    await db.update(
      'sync_queue',
      _syncEntityToMap(syncEntity),
      where: 'id = ?',
      whereArgs: [syncEntity.id],
    );
  }

  Future<List<SyncEntity>> _getPendingSyncEntities() async {
    final db = await _databaseHelper.database;
    final results = await db.query(
      'sync_queue',
      where: 'status = ? OR (status = ? AND retry_count < 5)',
      whereArgs: [SyncStatus.pending.name, SyncStatus.failed.name],
      orderBy: 'priority DESC, created_at ASC',
      limit: 100, // Process in batches of 100
    );
    
    return results
        .map((map) => _syncEntityFromMap(map))
        .where((entity) => entity.shouldRetry)
        .toList();
  }

  List<List<SyncEntity>> _groupEntitiesByPriority(List<SyncEntity> entities) {
    final Map<SyncPriority, List<SyncEntity>> grouped = {};
    
    for (final entity in entities) {
      grouped.putIfAbsent(entity.priority, () => []).add(entity);
    }
    
    // Return batches ordered by priority (critical first)
    final priorities = [
      SyncPriority.critical,
      SyncPriority.high,
      SyncPriority.normal,
      SyncPriority.low,
    ];
    
    return priorities
        .where((priority) => grouped.containsKey(priority))
        .map((priority) => grouped[priority]!)
        .toList();
  }

  Future<SyncResult> _processSyncBatch(List<SyncEntity> batch) async {
    if (batch.isEmpty) {
      return SyncResult.success(processedCount: 0, duration: Duration.zero);
    }

    final stopwatch = Stopwatch()..start();
    int processedCount = 0;
    int failedCount = 0;
    final List<String> failedEntityIds = [];
    String? errorMessage;

    _logger.d('Processing sync batch of ${batch.length} entities with priority ${batch.first.priority.name}');

    for (final syncEntity in batch) {
      try {
        // Mark as in progress
        await _updateSyncEntity(syncEntity.markAsInProgress());
        
        // Simulate API call (replace with actual API implementation)
        final success = await _syncEntityToServer(syncEntity);
        
        if (success) {
          // Mark as completed
          await _updateSyncEntity(syncEntity.markAsCompleted());
          processedCount++;
          _logger.d('Successfully synced: ${syncEntity.entityType.name}:${syncEntity.entityId}');
        } else {
          // Mark as failed and increment retry count
          final failedEntity = syncEntity.incrementRetry('Server rejected the request');
          await _updateSyncEntity(failedEntity);
          failedCount++;
          failedEntityIds.add(syncEntity.entityId);
          errorMessage = 'Server rejected the request';
          _logger.w('Failed to sync: ${syncEntity.entityType.name}:${syncEntity.entityId}');
        }
        
      } catch (e) {
        // Mark as failed with error message
        final failedEntity = syncEntity.markAsFailed(e.toString());
        await _updateSyncEntity(failedEntity);
        failedCount++;
        failedEntityIds.add(syncEntity.entityId);
        errorMessage = e.toString();
        _logger.e('Error syncing ${syncEntity.entityType.name}:${syncEntity.entityId}: $e');
      }
    }

    stopwatch.stop();
    
    return failedCount == 0
        ? SyncResult.success(
            processedCount: processedCount,
            duration: stopwatch.elapsed,
          )
        : SyncResult.failure(
            processedCount: processedCount,
            failedCount: failedCount,
            failedEntityIds: failedEntityIds,
            duration: stopwatch.elapsed,
            errorMessage: errorMessage,
          );
  }

  /// Simulate syncing entity to server (replace with actual API implementation)
  Future<bool> _syncEntityToServer(SyncEntity syncEntity) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Simulate 90% success rate for testing
    // In real implementation, this would make HTTP requests to the API
    return DateTime.now().millisecond % 10 != 0;
  }

  Map<String, dynamic> _syncEntityToMap(SyncEntity syncEntity) {
    return {
      'id': syncEntity.id,
      'entity_type': syncEntity.entityType.name,
      'entity_id': syncEntity.entityId,
      'operation': syncEntity.operation.name,
      'data': jsonEncode(syncEntity.data),
      'created_at': syncEntity.createdAt.millisecondsSinceEpoch,
      'retry_count': syncEntity.retryCount,
      'last_retry_at': syncEntity.lastRetryAt?.millisecondsSinceEpoch,
      'error_message': syncEntity.errorMessage,
      'priority': syncEntity.priority.name,
      'status': syncEntity.status.name,
    };
  }

  SyncEntity _syncEntityFromMap(Map<String, dynamic> map) {
    return SyncEntity(
      id: map['id'] as String,
      entityType: SyncEntityType.values.firstWhere(
        (e) => e.name == map['entity_type'],
      ),
      entityId: map['entity_id'] as String,
      operation: SyncOperation.values.firstWhere(
        (e) => e.name == map['operation'],
      ),
      data: jsonDecode(map['data'] as String) as Map<String, dynamic>,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      retryCount: map['retry_count'] as int,
      lastRetryAt: map['last_retry_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_retry_at'] as int)
          : null,
      errorMessage: map['error_message'] as String?,
      priority: SyncPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => SyncPriority.normal,
      ),
      status: SyncStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }
}