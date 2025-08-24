import 'dart:async';
import 'dart:math';
import 'package:logger/logger.dart';
import '../../../domain/entities/sync_entity.dart';
import 'database_helper.dart';

/// Manages retry logic for failed sync operations
/// Implements Requirement 6.4 - Sync failure retry functionality
class SyncRetryManager {
  static final Logger _logger = Logger();
  static final SyncRetryManager _instance = SyncRetryManager._internal();
  factory SyncRetryManager() => _instance;
  SyncRetryManager._internal();

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  Timer? _retryTimer;
  bool _isRetrying = false;

  /// Maximum number of retry attempts
  static const int maxRetryAttempts = 5;

  /// Base delay for exponential backoff (in minutes)
  static const List<int> retryDelayMinutes = [1, 2, 5, 15, 60];

  /// Initialize the retry manager
  void initialize() {
    _logger.i('Initializing SyncRetryManager');
    _startRetryTimer();
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
  }

  /// Check and process entities that are ready for retry
  Future<List<SyncEntity>> processRetryQueue() async {
    if (_isRetrying) {
      _logger.d('Retry process already running, skipping');
      return [];
    }

    _isRetrying = true;
    
    try {
      _logger.d('Processing retry queue');
      
      // Get entities that are ready for retry
      final retryableEntities = await _getRetryableEntities();
      
      if (retryableEntities.isEmpty) {
        _logger.d('No entities ready for retry');
        return [];
      }

      _logger.i('Found ${retryableEntities.length} entities ready for retry');

      // Update retry timestamps and reset status to pending
      final updatedEntities = <SyncEntity>[];
      
      for (final entity in retryableEntities) {
        final updatedEntity = entity.copyWith(
          status: SyncStatus.pending,
          lastRetryAt: DateTime.now(),
        );
        
        await _updateSyncEntity(updatedEntity);
        updatedEntities.add(updatedEntity);
        
        _logger.d('Prepared entity for retry: ${entity.entityType.name}:${entity.entityId} (attempt ${entity.retryCount + 1})');
      }

      return updatedEntities;
      
    } catch (e) {
      _logger.e('Failed to process retry queue: $e');
      return [];
    } finally {
      _isRetrying = false;
    }
  }

  /// Mark entities as permanently failed if they exceed max retry attempts
  Future<void> markPermanentlyFailed() async {
    try {
      final db = await _databaseHelper.database;
      
      // Find entities that have exceeded max retry attempts
      final results = await db.query(
        'sync_queue',
        where: 'retry_count >= ? AND status = ?',
        whereArgs: [maxRetryAttempts, SyncStatus.failed.name],
      );

      if (results.isEmpty) {
        return;
      }

      _logger.i('Marking ${results.length} entities as permanently failed');

      // Update their status and add error message
      final batch = db.batch();
      
      for (final row in results) {
        final entity = _syncEntityFromMap(row);
        final updatedEntity = entity.copyWith(
          status: SyncStatus.failed,
          errorMessage: 'Permanently failed after $maxRetryAttempts retry attempts',
        );
        
        batch.update(
          'sync_queue',
          _syncEntityToMap(updatedEntity),
          where: 'id = ?',
          whereArgs: [entity.id],
        );
      }

      await batch.commit(noResult: true);
      
    } catch (e) {
      _logger.e('Failed to mark entities as permanently failed: $e');
    }
  }

  /// Get retry statistics
  Future<RetryStatistics> getRetryStatistics() async {
    try {
      final db = await _databaseHelper.database;
      
      // Count entities by retry count
      final retryCountResults = await db.rawQuery('''
        SELECT retry_count, COUNT(*) as count 
        FROM sync_queue 
        WHERE status = ? 
        GROUP BY retry_count
      ''', [SyncStatus.failed.name]);

      // Count entities ready for retry
      final readyForRetryResult = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM sync_queue 
        WHERE status = ? AND retry_count < ? AND (
          last_retry_at IS NULL OR 
          last_retry_at <= ?
        )
      ''', [
        SyncStatus.failed.name,
        maxRetryAttempts,
        _getRetryThresholdTimestamp(),
      ]);

      // Count permanently failed entities
      final permanentlyFailedResult = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM sync_queue 
        WHERE retry_count >= ? AND status = ?
      ''', [maxRetryAttempts, SyncStatus.failed.name]);

      // Get next retry time
      final nextRetryResult = await db.rawQuery('''
        SELECT MIN(last_retry_at) as next_retry_timestamp
        FROM sync_queue 
        WHERE status = ? AND retry_count < ? AND last_retry_at IS NOT NULL
      ''', [SyncStatus.failed.name, maxRetryAttempts]);

      final retryCountMap = <int, int>{};
      for (final row in retryCountResults) {
        retryCountMap[row['retry_count'] as int] = row['count'] as int;
      }

      final readyForRetryCount = readyForRetryResult.first['count'] as int;
      final permanentlyFailedCount = permanentlyFailedResult.first['count'] as int;
      
      final nextRetryTimestamp = nextRetryResult.first['next_retry_timestamp'] as int?;
      final nextRetryTime = nextRetryTimestamp != null 
          ? DateTime.fromMillisecondsSinceEpoch(nextRetryTimestamp)
          : null;

      return RetryStatistics(
        retryCountDistribution: retryCountMap,
        readyForRetryCount: readyForRetryCount,
        permanentlyFailedCount: permanentlyFailedCount,
        nextRetryTime: nextRetryTime,
      );
      
    } catch (e) {
      _logger.e('Failed to get retry statistics: $e');
      return RetryStatistics.empty();
    }
  }

  /// Calculate the next retry time for an entity based on exponential backoff
  DateTime calculateNextRetryTime(SyncEntity entity) {
    final baseTime = entity.lastRetryAt ?? entity.createdAt;
    final retryIndex = entity.retryCount.clamp(0, retryDelayMinutes.length - 1);
    final delayMinutes = retryDelayMinutes[retryIndex];
    
    // Add some jitter to prevent thundering herd
    final jitterMinutes = Random().nextInt(delayMinutes ~/ 4 + 1);
    
    return baseTime.add(Duration(minutes: delayMinutes + jitterMinutes));
  }

  /// Check if an entity should be retried based on exponential backoff
  bool shouldRetryEntity(SyncEntity entity) {
    // Don't retry if max attempts reached
    if (entity.retryCount >= maxRetryAttempts) {
      return false;
    }

    // Don't retry if already completed or in progress
    if (entity.status == SyncStatus.completed || entity.status == SyncStatus.inProgress) {
      return false;
    }

    // If never retried, it's ready
    if (entity.lastRetryAt == null) {
      return true;
    }

    // Check if enough time has passed based on exponential backoff
    final nextRetryTime = calculateNextRetryTime(entity);
    return DateTime.now().isAfter(nextRetryTime);
  }

  /// Get entities that are ready for retry
  Future<List<SyncEntity>> _getRetryableEntities() async {
    final db = await _databaseHelper.database;
    
    // Get failed entities that haven't exceeded max retry attempts
    final results = await db.query(
      'sync_queue',
      where: 'status = ? AND retry_count < ? AND (last_retry_at IS NULL OR last_retry_at <= ?)',
      whereArgs: [
        SyncStatus.failed.name,
        maxRetryAttempts,
        _getRetryThresholdTimestamp(),
      ],
      orderBy: 'priority DESC, created_at ASC',
      limit: 50, // Process in batches
    );

    final entities = results.map((map) => _syncEntityFromMap(map)).toList();
    
    // Filter entities that are actually ready for retry (considering exponential backoff)
    return entities.where((entity) => shouldRetryEntity(entity)).toList();
  }

  /// Get timestamp threshold for retry eligibility
  int _getRetryThresholdTimestamp() {
    // Calculate threshold based on minimum retry delay
    final thresholdTime = DateTime.now().subtract(
      Duration(minutes: retryDelayMinutes.first),
    );
    return thresholdTime.millisecondsSinceEpoch;
  }

  /// Start the retry timer
  void _startRetryTimer() {
    // Check for retryable entities every minute
    _retryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _processRetryQueuePeriodically();
    });
  }

  /// Periodically process retry queue
  void _processRetryQueuePeriodically() {
    scheduleMicrotask(() async {
      try {
        await processRetryQueue();
        await markPermanentlyFailed();
      } catch (e) {
        _logger.e('Periodic retry processing failed: $e');
      }
    });
  }

  /// Update sync entity in database
  Future<void> _updateSyncEntity(SyncEntity syncEntity) async {
    final db = await _databaseHelper.database;
    await db.update(
      'sync_queue',
      _syncEntityToMap(syncEntity),
      where: 'id = ?',
      whereArgs: [syncEntity.id],
    );
  }

  /// Convert sync entity to database map
  Map<String, dynamic> _syncEntityToMap(SyncEntity syncEntity) {
    return {
      'id': syncEntity.id,
      'entity_type': syncEntity.entityType.name,
      'entity_id': syncEntity.entityId,
      'operation': syncEntity.operation.name,
      'data': syncEntity.data.toString(), // Convert to JSON string in real implementation
      'created_at': syncEntity.createdAt.millisecondsSinceEpoch,
      'retry_count': syncEntity.retryCount,
      'last_retry_at': syncEntity.lastRetryAt?.millisecondsSinceEpoch,
      'error_message': syncEntity.errorMessage,
      'priority': syncEntity.priority.name,
      'status': syncEntity.status.name,
    };
  }

  /// Convert database map to sync entity
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
      data: {}, // Parse JSON in real implementation
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

/// Statistics about retry operations
class RetryStatistics {
  final Map<int, int> retryCountDistribution;
  final int readyForRetryCount;
  final int permanentlyFailedCount;
  final DateTime? nextRetryTime;

  const RetryStatistics({
    required this.retryCountDistribution,
    required this.readyForRetryCount,
    required this.permanentlyFailedCount,
    this.nextRetryTime,
  });

  factory RetryStatistics.empty() {
    return const RetryStatistics(
      retryCountDistribution: {},
      readyForRetryCount: 0,
      permanentlyFailedCount: 0,
    );
  }

  /// Get total number of failed entities
  int get totalFailedCount {
    return retryCountDistribution.values.fold(0, (sum, count) => sum + count);
  }

  /// Get average retry count
  double get averageRetryCount {
    if (retryCountDistribution.isEmpty) return 0.0;
    
    int totalRetries = 0;
    int totalEntities = 0;
    
    retryCountDistribution.forEach((retryCount, entityCount) {
      totalRetries += retryCount * entityCount;
      totalEntities += entityCount;
    });
    
    return totalEntities > 0 ? totalRetries / totalEntities : 0.0;
  }

  /// Check if there are entities ready for retry
  bool get hasEntitiesReadyForRetry => readyForRetryCount > 0;

  /// Get time until next retry (if any)
  Duration? get timeUntilNextRetry {
    if (nextRetryTime == null) return null;
    
    final now = DateTime.now();
    if (nextRetryTime!.isBefore(now)) return Duration.zero;
    
    return nextRetryTime!.difference(now);
  }
}