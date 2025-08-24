import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_entity.freezed.dart';
part 'sync_entity.g.dart';

/// Represents an entity that can be synchronized with the server
@freezed
class SyncEntity with _$SyncEntity {
  const factory SyncEntity({
    required String id,
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> data,
    required DateTime createdAt,
    @Default(0) int retryCount,
    DateTime? lastRetryAt,
    String? errorMessage,
    @Default(SyncPriority.normal) SyncPriority priority,
    @Default(SyncStatus.pending) SyncStatus status,
  }) = _SyncEntity;

  const SyncEntity._();

  factory SyncEntity.fromJson(Map<String, dynamic> json) => 
      _$SyncEntityFromJson(json);

  /// Creates a sync entity for creating a new record
  factory SyncEntity.create({
    required SyncEntityType entityType,
    required String entityId,
    required Map<String, dynamic> data,
    SyncPriority priority = SyncPriority.normal,
  }) {
    return SyncEntity(
      id: '${entityType.name}_${entityId}_create_${DateTime.now().millisecondsSinceEpoch}',
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperation.create,
      data: data,
      createdAt: DateTime.now(),
      priority: priority,
    );
  }

  /// Creates a sync entity for updating an existing record
  factory SyncEntity.update({
    required SyncEntityType entityType,
    required String entityId,
    required Map<String, dynamic> data,
    SyncPriority priority = SyncPriority.normal,
  }) {
    return SyncEntity(
      id: '${entityType.name}_${entityId}_update_${DateTime.now().millisecondsSinceEpoch}',
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperation.update,
      data: data,
      createdAt: DateTime.now(),
      priority: priority,
    );
  }

  /// Creates a sync entity for deleting a record
  factory SyncEntity.delete({
    required SyncEntityType entityType,
    required String entityId,
    SyncPriority priority = SyncPriority.normal,
  }) {
    return SyncEntity(
      id: '${entityType.name}_${entityId}_delete_${DateTime.now().millisecondsSinceEpoch}',
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperation.delete,
      data: {'id': entityId}, // Minimal data for delete operations
      createdAt: DateTime.now(),
      priority: priority,
    );
  }

  /// Validates sync entity data
  String? validate() {
    if (id.isEmpty) return 'Sync entity ID cannot be empty';
    if (entityId.isEmpty) return 'Entity ID cannot be empty';
    if (data.isEmpty && operation != SyncOperation.delete) {
      return 'Data cannot be empty for ${operation.name} operations';
    }
    if (retryCount < 0) return 'Retry count cannot be negative';
    
    return null;
  }

  /// Checks if the sync entity data is valid
  bool get isValid => validate() == null;

  /// Checks if this sync entity should be retried
  bool get shouldRetry {
    const maxRetries = 5;
    const retryDelayMinutes = [1, 2, 5, 15, 60]; // Exponential backoff
    
    if (retryCount >= maxRetries) return false;
    if (status == SyncStatus.completed || status == SyncStatus.failed) return false;
    
    if (lastRetryAt == null) return true;
    
    final delayMinutes = retryDelayMinutes[retryCount.clamp(0, retryDelayMinutes.length - 1)];
    final nextRetryTime = lastRetryAt!.add(Duration(minutes: delayMinutes));
    
    return DateTime.now().isAfter(nextRetryTime);
  }

  /// Gets the next retry time based on exponential backoff
  DateTime? get nextRetryTime {
    if (!shouldRetry) return null;
    if (lastRetryAt == null) return DateTime.now();
    
    const retryDelayMinutes = [1, 2, 5, 15, 60];
    final delayMinutes = retryDelayMinutes[retryCount.clamp(0, retryDelayMinutes.length - 1)];
    
    return lastRetryAt!.add(Duration(minutes: delayMinutes));
  }

  /// Marks the sync entity as failed with an error message
  SyncEntity markAsFailed(String errorMessage) {
    return copyWith(
      status: SyncStatus.failed,
      errorMessage: errorMessage,
      lastRetryAt: DateTime.now(),
      retryCount: retryCount + 1,
    );
  }

  /// Marks the sync entity as completed
  SyncEntity markAsCompleted() {
    return copyWith(
      status: SyncStatus.completed,
      errorMessage: null,
    );
  }

  /// Marks the sync entity as in progress
  SyncEntity markAsInProgress() {
    return copyWith(
      status: SyncStatus.inProgress,
      lastRetryAt: DateTime.now(),
    );
  }

  /// Increments retry count for failed attempts
  SyncEntity incrementRetry(String? errorMessage) {
    return copyWith(
      retryCount: retryCount + 1,
      lastRetryAt: DateTime.now(),
      errorMessage: errorMessage,
      status: SyncStatus.pending,
    );
  }
}

/// Types of entities that can be synchronized
enum SyncEntityType {
  workoutSession,
  workoutSet,
  user,
  template,
  prRecord,
  avatarState,
  recoveryState,
  fatigueEvent,
  notification;

  String get tableName {
    switch (this) {
      case SyncEntityType.workoutSession:
        return 'workout_sessions';
      case SyncEntityType.workoutSet:
        return 'workout_sets';
      case SyncEntityType.user:
        return 'users';
      case SyncEntityType.template:
        return 'templates';
      case SyncEntityType.prRecord:
        return 'pr_records';
      case SyncEntityType.avatarState:
        return 'avatar_states';
      case SyncEntityType.recoveryState:
        return 'recovery_states';
      case SyncEntityType.fatigueEvent:
        return 'fatigue_events';
      case SyncEntityType.notification:
        return 'notifications';
    }
  }
}

/// Operations that can be performed on synchronized entities
enum SyncOperation {
  create,
  update,
  delete;

  String get httpMethod {
    switch (this) {
      case SyncOperation.create:
        return 'POST';
      case SyncOperation.update:
        return 'PUT';
      case SyncOperation.delete:
        return 'DELETE';
    }
  }
}

/// Priority levels for sync operations
enum SyncPriority {
  low,
  normal,
  high,
  critical;

  int get value {
    switch (this) {
      case SyncPriority.low:
        return 1;
      case SyncPriority.normal:
        return 2;
      case SyncPriority.high:
        return 3;
      case SyncPriority.critical:
        return 4;
    }
  }
}

/// Status of sync operations
enum SyncStatus {
  pending,
  inProgress,
  completed,
  failed;

  bool get isCompleted => this == SyncStatus.completed;
  bool get isFailed => this == SyncStatus.failed;
  bool get isPending => this == SyncStatus.pending;
  bool get isInProgress => this == SyncStatus.inProgress;
}

/// Result of a sync operation
@freezed
class SyncResult with _$SyncResult {
  const factory SyncResult({
    required bool success,
    required int processedCount,
    required int failedCount,
    required List<String> failedEntityIds,
    required Duration duration,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) = _SyncResult;

  const SyncResult._();

  factory SyncResult.fromJson(Map<String, dynamic> json) => 
      _$SyncResultFromJson(json);

  /// Creates a successful sync result
  factory SyncResult.success({
    required int processedCount,
    required Duration duration,
    Map<String, dynamic>? metadata,
  }) {
    return SyncResult(
      success: true,
      processedCount: processedCount,
      failedCount: 0,
      failedEntityIds: [],
      duration: duration,
      metadata: metadata,
    );
  }

  /// Creates a failed sync result
  factory SyncResult.failure({
    required int processedCount,
    required int failedCount,
    required List<String> failedEntityIds,
    required Duration duration,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) {
    return SyncResult(
      success: false,
      processedCount: processedCount,
      failedCount: failedCount,
      failedEntityIds: failedEntityIds,
      duration: duration,
      errorMessage: errorMessage,
      metadata: metadata,
    );
  }

  /// Gets the total number of entities processed
  int get totalCount => processedCount + failedCount;

  /// Gets the success rate as a percentage
  double get successRate {
    if (totalCount == 0) return 0.0;
    return (processedCount / totalCount) * 100;
  }
}

/// Conflict resolution strategy for sync operations
enum ConflictResolution {
  clientWins,
  serverWins,
  merge,
  manual;
}

/// Represents a conflict between local and server data
@freezed
class SyncConflict with _$SyncConflict {
  const factory SyncConflict({
    required String entityId,
    required SyncEntityType entityType,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> serverData,
    required DateTime detectedAt,
    @Default(ConflictResolution.clientWins) ConflictResolution resolution,
    Map<String, dynamic>? resolvedData,
    DateTime? resolvedAt,
  }) = _SyncConflict;

  const SyncConflict._();

  factory SyncConflict.fromJson(Map<String, dynamic> json) => 
      _$SyncConflictFromJson(json);

  /// Checks if the conflict has been resolved
  bool get isResolved => resolvedData != null && resolvedAt != null;

  /// Resolves the conflict using client data
  SyncConflict resolveWithClient() {
    return copyWith(
      resolution: ConflictResolution.clientWins,
      resolvedData: localData,
      resolvedAt: DateTime.now(),
    );
  }

  /// Resolves the conflict using server data
  SyncConflict resolveWithServer() {
    return copyWith(
      resolution: ConflictResolution.serverWins,
      resolvedData: serverData,
      resolvedAt: DateTime.now(),
    );
  }

  /// Resolves the conflict with custom merged data
  SyncConflict resolveWithMerge(Map<String, dynamic> mergedData) {
    return copyWith(
      resolution: ConflictResolution.merge,
      resolvedData: mergedData,
      resolvedAt: DateTime.now(),
    );
  }
}