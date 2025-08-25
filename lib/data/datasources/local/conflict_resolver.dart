import 'dart:async';
import 'dart:convert';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:logger/logger.dart';
import '../../../domain/entities/sync_entity.dart';
import 'database_helper.dart';

/// Handles conflict resolution for sync operations
/// Implements Requirements 6.3, 6.4 - Client priority conflict resolution with data integrity
class ConflictResolver {
  static final Logger _logger = Logger();
  static final ConflictResolver _instance = ConflictResolver._internal();
  factory ConflictResolver() => _instance;
  ConflictResolver._internal();

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  final StreamController<SyncConflict> _conflictController = 
      StreamController<SyncConflict>.broadcast();

  /// Stream of detected conflicts
  Stream<SyncConflict> get conflicts => _conflictController.stream;

  /// Resolve conflicts for a sync entity using client-priority strategy
  /// Implements Requirement 6.3 - Client priority conflict resolution
  Future<ConflictResolutionResult> resolveConflicts({
    required SyncEntity syncEntity,
    required Map<String, dynamic> serverData,
    ConflictResolution strategy = ConflictResolution.clientWins,
  }) async {
    try {
      _logger.d('Resolving conflicts for ${syncEntity.entityType.name}:${syncEntity.entityId}');
      
      // Get local data from the sync entity
      final localData = syncEntity.data;
      
      // Detect conflicts by comparing local and server data
      final conflicts = await _detectConflicts(
        syncEntity.entityType,
        syncEntity.entityId,
        localData,
        serverData,
      );
      
      if (conflicts.isEmpty) {
        _logger.d('No conflicts detected for ${syncEntity.entityId}');
        return ConflictResolutionResult.noConflict();
      }
      
      _logger.i('Detected ${conflicts.length} conflicts for ${syncEntity.entityId}');
      
      // Resolve each conflict based on strategy
      final resolvedConflicts = <SyncConflict>[];
      Map<String, dynamic> resolvedData = Map.from(localData);
      
      for (final conflict in conflicts) {
        final resolvedConflict = await _resolveConflict(conflict, strategy);
        resolvedConflicts.add(resolvedConflict);
        
        // Apply resolved data
        if (resolvedConflict.isResolved && resolvedConflict.resolvedData != null) {
          resolvedData = _mergeResolvedData(resolvedData, resolvedConflict.resolvedData!);
        }
        
        // Emit conflict for UI handling if needed
        _conflictController.add(resolvedConflict);
      }
      
      // Validate data integrity after resolution
      final integrityCheck = await _validateDataIntegrity(
        syncEntity.entityType,
        resolvedData,
      );
      
      if (!integrityCheck.isValid) {
        _logger.e('Data integrity check failed: ${integrityCheck.errorMessage}');
        return ConflictResolutionResult.integrityError(
          conflicts: resolvedConflicts,
          errorMessage: integrityCheck.errorMessage!,
        );
      }
      
      return ConflictResolutionResult.resolved(
        conflicts: resolvedConflicts,
        resolvedData: resolvedData,
      );
      
    } catch (e) {
      _logger.e('Failed to resolve conflicts: $e');
      return ConflictResolutionResult.error(
        errorMessage: e.toString(),
      );
    }
  }

  /// Detect conflicts between local and server data
  Future<List<SyncConflict>> _detectConflicts(
    SyncEntityType entityType,
    String entityId,
    Map<String, dynamic> localData,
    Map<String, dynamic> serverData,
  ) async {
    final conflicts = <SyncConflict>[];
    
    // Get conflict detection rules for the entity type
    final conflictFields = _getConflictFields(entityType);
    
    for (final field in conflictFields) {
      final localValue = localData[field];
      final serverValue = serverData[field];
      
      // Check if values are different
      if (!_areValuesEqual(localValue, serverValue)) {
        // Check if this is a meaningful conflict (not just timestamp differences)
        if (_isMeaningfulConflict(field, localValue, serverValue)) {
          final conflict = SyncConflict(
            entityId: entityId,
            entityType: entityType,
            localData: {field: localValue},
            serverData: {field: serverValue},
            detectedAt: DateTime.now(),
          );
          
          conflicts.add(conflict);
          _logger.d('Conflict detected in field "$field": local=$localValue, server=$serverValue');
        }
      }
    }
    
    return conflicts;
  }

  /// Resolve a single conflict based on the specified strategy
  Future<SyncConflict> _resolveConflict(
    SyncConflict conflict,
    ConflictResolution strategy,
  ) async {
    switch (strategy) {
      case ConflictResolution.clientWins:
        return conflict.resolveWithClient();
        
      case ConflictResolution.serverWins:
        return conflict.resolveWithServer();
        
      case ConflictResolution.merge:
        final mergedData = await _mergeConflictData(conflict);
        return conflict.resolveWithMerge(mergedData);
        
      case ConflictResolution.manual:
        // For manual resolution, return unresolved conflict
        // UI should handle this case
        return conflict;
    }
  }

  /// Merge conflict data using smart merge strategies
  Future<Map<String, dynamic>> _mergeConflictData(SyncConflict conflict) async {
    final mergedData = <String, dynamic>{};
    
    // Iterate through all fields in both local and server data
    final allFields = <String>{
      ...conflict.localData.keys,
      ...conflict.serverData.keys,
    };
    
    for (final field in allFields) {
      final localValue = conflict.localData[field];
      final serverValue = conflict.serverData[field];
      
      // Apply field-specific merge logic
      mergedData[field] = _mergeFieldValues(
        conflict.entityType,
        field,
        localValue,
        serverValue,
      );
    }
    
    return mergedData;
  }

  /// Merge field values using entity-specific logic
  dynamic _mergeFieldValues(
    SyncEntityType entityType,
    String field,
    dynamic localValue,
    dynamic serverValue,
  ) {
    // Handle null values
    if (localValue == null) return serverValue;
    if (serverValue == null) return localValue;
    
    switch (entityType) {
      case SyncEntityType.workoutSession:
        return _mergeWorkoutSessionField(field, localValue, serverValue);
        
      case SyncEntityType.workoutSet:
        return _mergeWorkoutSetField(field, localValue, serverValue);
        
      case SyncEntityType.user:
        return _mergeUserField(field, localValue, serverValue);
        
      default:
        // Default: prefer local value (client wins)
        return localValue;
    }
  }

  /// Merge workout session specific fields
  dynamic _mergeWorkoutSessionField(String field, dynamic localValue, dynamic serverValue) {
    switch (field) {
      case 'notes':
        // Merge notes by combining both
        if (localValue is String && serverValue is String) {
          if (localValue.isEmpty) return serverValue;
          if (serverValue.isEmpty) return localValue;
          return '$localValue\n---\n$serverValue';
        }
        return localValue;
        
      case 'endTime':
        // Use the later end time
        if (localValue is int && serverValue is int) {
          return localValue > serverValue ? localValue : serverValue;
        }
        return localValue;
        
      default:
        return localValue; // Client wins by default
    }
  }

  /// Merge workout set specific fields
  dynamic _mergeWorkoutSetField(String field, dynamic localValue, dynamic serverValue) {
    switch (field) {
      case 'weight':
      case 'reps':
      case 'rpe':
        // For performance metrics, prefer the higher value (assuming progression)
        if (localValue is num && serverValue is num) {
          return localValue > serverValue ? localValue : serverValue;
        }
        return localValue;
        
      case 'notes':
        // Merge notes
        if (localValue is String && serverValue is String) {
          if (localValue.isEmpty) return serverValue;
          if (serverValue.isEmpty) return localValue;
          return '$localValue; $serverValue';
        }
        return localValue;
        
      default:
        return localValue; // Client wins by default
    }
  }

  /// Merge user specific fields
  dynamic _mergeUserField(String field, dynamic localValue, dynamic serverValue) {
    switch (field) {
      case 'displayName':
      case 'preferredLanguage':
        // User preferences: client wins
        return localValue;
        
      case 'lastSyncAt':
        // Use the more recent sync time
        if (localValue is int && serverValue is int) {
          return localValue > serverValue ? localValue : serverValue;
        }
        return localValue;
        
      default:
        return localValue; // Client wins by default
    }
  }

  /// Validate data integrity after conflict resolution
  Future<DataIntegrityResult> _validateDataIntegrity(
    SyncEntityType entityType,
    Map<String, dynamic> data,
  ) async {
    try {
      switch (entityType) {
        case SyncEntityType.workoutSession:
          return _validateWorkoutSessionIntegrity(data);
          
        case SyncEntityType.workoutSet:
          return _validateWorkoutSetIntegrity(data);
          
        case SyncEntityType.user:
          return _validateUserIntegrity(data);
          
        default:
          return DataIntegrityResult.valid();
      }
    } catch (e) {
      return DataIntegrityResult.invalid('Validation error: $e');
    }
  }

  /// Validate workout session data integrity
  DataIntegrityResult _validateWorkoutSessionIntegrity(Map<String, dynamic> data) {
    // Check required fields
    if (!data.containsKey('id') || data['id'] == null || data['id'].toString().isEmpty) {
      return DataIntegrityResult.invalid('Missing or empty session ID');
    }
    
    if (!data.containsKey('userId') || data['userId'] == null || data['userId'].toString().isEmpty) {
      return DataIntegrityResult.invalid('Missing or empty user ID');
    }
    
    if (!data.containsKey('startTime') || data['startTime'] == null) {
      return DataIntegrityResult.invalid('Missing start time');
    }
    
    // Validate time consistency
    final startTime = data['startTime'] as int?;
    final endTime = data['endTime'] as int?;
    
    if (startTime != null && endTime != null && endTime < startTime) {
      return DataIntegrityResult.invalid('End time cannot be before start time');
    }
    
    return DataIntegrityResult.valid();
  }

  /// Validate workout set data integrity
  DataIntegrityResult _validateWorkoutSetIntegrity(Map<String, dynamic> data) {
    // Check required fields
    final requiredFields = ['id', 'sessionId', 'exerciseId', 'weight', 'reps', 'rpe'];
    
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        return DataIntegrityResult.invalid('Missing required field: $field');
      }
    }
    
    // Validate numeric ranges
    final weight = data['weight'];
    if (weight is num && (weight < 0 || weight > 1000)) {
      return DataIntegrityResult.invalid('Weight out of valid range: $weight');
    }
    
    final reps = data['reps'];
    if (reps is num && (reps < 1 || reps > 100)) {
      return DataIntegrityResult.invalid('Reps out of valid range: $reps');
    }
    
    final rpe = data['rpe'];
    if (rpe is num && (rpe < 1 || rpe > 10)) {
      return DataIntegrityResult.invalid('RPE out of valid range: $rpe');
    }
    
    return DataIntegrityResult.valid();
  }

  /// Validate user data integrity
  DataIntegrityResult _validateUserIntegrity(Map<String, dynamic> data) {
    // Check required fields
    if (!data.containsKey('id') || data['id'] == null || data['id'].toString().isEmpty) {
      return DataIntegrityResult.invalid('Missing or empty user ID');
    }
    
    if (!data.containsKey('email') || data['email'] == null || data['email'].toString().isEmpty) {
      return DataIntegrityResult.invalid('Missing or empty email');
    }
    
    // Validate email format
    final email = data['email'].toString();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      return DataIntegrityResult.invalid('Invalid email format: $email');
    }
    
    return DataIntegrityResult.valid();
  }

  /// Get fields that should be checked for conflicts for each entity type
  List<String> _getConflictFields(SyncEntityType entityType) {
    switch (entityType) {
      case SyncEntityType.workoutSession:
        return ['notes', 'endTime', 'sessionType'];
        
      case SyncEntityType.workoutSet:
        return ['weight', 'reps', 'rpe', 'restSeconds', 'notes'];
        
      case SyncEntityType.user:
        return ['displayName', 'preferredLanguage'];
        
      case SyncEntityType.template:
        return ['name', 'description'];
        
      case SyncEntityType.prRecord:
        return ['weight', 'reps', 'estimatedMax'];
        
      default:
        return []; // No conflict detection for other types
    }
  }

  /// Check if two values are equal (handles different data types)
  bool _areValuesEqual(dynamic value1, dynamic value2) {
    if (value1 == null && value2 == null) return true;
    if (value1 == null || value2 == null) return false;
    
    // Handle different numeric types
    if (value1 is num && value2 is num) {
      return value1.toDouble() == value2.toDouble();
    }
    
    // Handle strings
    if (value1 is String && value2 is String) {
      return value1.trim() == value2.trim();
    }
    
    // Handle lists
    if (value1 is List && value2 is List) {
      if (value1.length != value2.length) return false;
      for (int i = 0; i < value1.length; i++) {
        if (!_areValuesEqual(value1[i], value2[i])) return false;
      }
      return true;
    }
    
    // Handle maps
    if (value1 is Map && value2 is Map) {
      if (value1.length != value2.length) return false;
      for (final key in value1.keys) {
        if (!value2.containsKey(key)) return false;
        if (!_areValuesEqual(value1[key], value2[key])) return false;
      }
      return true;
    }
    
    return value1 == value2;
  }

  /// Check if a conflict is meaningful (not just timestamp or metadata differences)
  bool _isMeaningfulConflict(String field, dynamic localValue, dynamic serverValue) {
    // Ignore timestamp fields that are close (within 1 second)
    if (field.contains('Time') || field.contains('At')) {
      if (localValue is int && serverValue is int) {
        final diff = (localValue - serverValue).abs();
        return diff > 1000; // More than 1 second difference
      }
    }
    
    // Ignore empty vs null differences
    if ((localValue == null || localValue == '') && 
        (serverValue == null || serverValue == '')) {
      return false;
    }
    
    return true;
  }

  /// Merge resolved data into the main data map
  Map<String, dynamic> _mergeResolvedData(
    Map<String, dynamic> mainData,
    Map<String, dynamic> resolvedData,
  ) {
    final merged = Map<String, dynamic>.from(mainData);
    
    for (final entry in resolvedData.entries) {
      merged[entry.key] = entry.value;
    }
    
    return merged;
  }

  /// Dispose resources
  void dispose() {
    _conflictController.close();
  }
}

/// Result of conflict resolution operation
class ConflictResolutionResult {
  final bool success;
  final List<SyncConflict> conflicts;
  final Map<String, dynamic>? resolvedData;
  final String? errorMessage;

  const ConflictResolutionResult._({
    required this.success,
    required this.conflicts,
    this.resolvedData,
    this.errorMessage,
  });

  /// No conflicts detected
  factory ConflictResolutionResult.noConflict() {
    return const ConflictResolutionResult._(
      success: true,
      conflicts: [],
    );
  }

  /// Conflicts resolved successfully
  factory ConflictResolutionResult.resolved({
    required List<SyncConflict> conflicts,
    required Map<String, dynamic> resolvedData,
  }) {
    return ConflictResolutionResult._(
      success: true,
      conflicts: conflicts,
      resolvedData: resolvedData,
    );
  }

  /// Data integrity error
  factory ConflictResolutionResult.integrityError({
    required List<SyncConflict> conflicts,
    required String errorMessage,
  }) {
    return ConflictResolutionResult._(
      success: false,
      conflicts: conflicts,
      errorMessage: errorMessage,
    );
  }

  /// General error
  factory ConflictResolutionResult.error({
    required String errorMessage,
  }) {
    return ConflictResolutionResult._(
      success: false,
      conflicts: [],
      errorMessage: errorMessage,
    );
  }

  bool get hasConflicts => conflicts.isNotEmpty;
  bool get hasResolvedData => resolvedData != null;
}

/// Result of data integrity validation
class DataIntegrityResult {
  final bool isValid;
  final String? errorMessage;

  const DataIntegrityResult._(this.isValid, this.errorMessage);

  factory DataIntegrityResult.valid() {
    return const DataIntegrityResult._(true, null);
  }

  factory DataIntegrityResult.invalid(String errorMessage) {
    return DataIntegrityResult._(false, errorMessage);
  }
}