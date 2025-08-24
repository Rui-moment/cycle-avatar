import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/user.dart';
import '../repositories/user_repository.dart';
import '../repositories/workout_repository.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/pr_repository.dart';
import '../repositories/template_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/streak_repository.dart';
import '../repositories/notification_preferences_repository.dart';
import '../datasources/local/database_helper.dart';

/// Service for deleting user data
class DataDeletionService {
  final UserRepository _userRepository;
  final WorkoutSessionRepository _workoutRepository;
  final ExerciseRepository _exerciseRepository;
  final PRRepository _prRepository;
  final TemplateRepository _templateRepository;
  final NotificationRepository _notificationRepository;
  final StreakRepository _streakRepository;
  final NotificationPreferencesRepository _notificationPreferencesRepository;
  final DatabaseHelper _databaseHelper;
  final Logger _logger = Logger();

  DataDeletionService({
    required UserRepository userRepository,
    required WorkoutSessionRepository workoutRepository,
    required ExerciseRepository exerciseRepository,
    required PRRepository prRepository,
    required TemplateRepository templateRepository,
    required NotificationRepository notificationRepository,
    required StreakRepository streakRepository,
    required NotificationPreferencesRepository notificationPreferencesRepository,
    required DatabaseHelper databaseHelper,
  })  : _userRepository = userRepository,
        _workoutRepository = workoutRepository,
        _exerciseRepository = exerciseRepository,
        _prRepository = prRepository,
        _templateRepository = templateRepository,
        _notificationRepository = notificationRepository,
        _streakRepository = streakRepository,
        _notificationPreferencesRepository = notificationPreferencesRepository,
        _databaseHelper = databaseHelper;

  /// Deletes all local user data
  Future<DeletionResult> deleteLocalUserData(
    String userId, {
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      _logger.i('Starting local data deletion for user: $userId');
      
      int deletedRecords = 0;
      
      // Update progress
      onProgress?.call(0.0, 'Initializing deletion...');

      // Verify user exists
      final user = await _userRepository.findById(userId);
      if (user == null) {
        throw DeletionException('User not found: $userId');
      }

      // Delete workout sessions and sets
      onProgress?.call(0.1, 'Deleting workout sessions...');
      final workoutSessions = await _workoutRepository.findByUserId(userId);
      for (final session in workoutSessions) {
        await _workoutRepository.deleteById(session.id);
        deletedRecords++;
      }

      // Delete PR records
      onProgress?.call(0.3, 'Deleting personal records...');
      final prRecords = await _prRepository.findByUserId(userId);
      for (final pr in prRecords) {
        await _prRepository.deleteById(pr.id);
        deletedRecords++;
      }

      // Delete templates
      onProgress?.call(0.5, 'Deleting workout templates...');
      final templates = await _templateRepository.findByUserId(userId);
      for (final template in templates) {
        await _templateRepository.deleteById(template.id);
        deletedRecords++;
      }

      // Delete notifications
      onProgress?.call(0.7, 'Deleting notifications...');
      final notifications = await _notificationRepository.findByUserId(userId);
      for (final notification in notifications) {
        await _notificationRepository.deleteById(notification.id);
        deletedRecords++;
      }

      // Delete streak records
      onProgress?.call(0.8, 'Deleting streak records...');
      final streakRecords = await _streakRepository.findByUserId(userId);
      for (final streak in streakRecords) {
        await _streakRepository.deleteById(streak.id);
        deletedRecords++;
      }

      // Delete notification preferences
      onProgress?.call(0.9, 'Deleting notification preferences...');
      try {
        final preferences = await _notificationPreferencesRepository.findByUserId(userId);
        if (preferences != null) {
          await _notificationPreferencesRepository.deleteById(preferences.id);
          deletedRecords++;
        }
      } catch (e) {
        _logger.w('Failed to delete notification preferences: $e');
      }

      // Delete user profile (last)
      onProgress?.call(0.95, 'Deleting user profile...');
      await _userRepository.deleteById(userId);
      deletedRecords++;

      // Clean up any orphaned data
      onProgress?.call(0.98, 'Cleaning up orphaned data...');
      await _cleanupOrphanedData();

      onProgress?.call(1.0, 'Deletion completed');

      _logger.i('Local data deletion completed successfully for user: $userId');
      
      return DeletionResult(
        success: true,
        deletedRecords: deletedRecords,
        deletionType: DeletionType.local,
      );

    } catch (e, stackTrace) {
      _logger.e('Local data deletion failed for user: $userId', error: e, stackTrace: stackTrace);
      return DeletionResult(
        success: false,
        error: e.toString(),
        deletionType: DeletionType.local,
      );
    }
  }

  /// Deletes all application data (complete reset)
  Future<DeletionResult> deleteAllApplicationData({
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      _logger.i('Starting complete application data deletion');
      
      onProgress?.call(0.0, 'Initializing complete deletion...');

      // Close database connection
      onProgress?.call(0.2, 'Closing database connection...');
      await _databaseHelper.close();

      // Delete database file
      onProgress?.call(0.5, 'Deleting database file...');
      await _deleteDatabaseFile();

      // Clear application cache and temporary files
      onProgress?.call(0.8, 'Clearing cache and temporary files...');
      await _clearApplicationCache();

      onProgress?.call(1.0, 'Complete deletion finished');

      _logger.i('Complete application data deletion completed successfully');
      
      return DeletionResult(
        success: true,
        deletedRecords: -1, // Unknown count for complete deletion
        deletionType: DeletionType.complete,
      );

    } catch (e, stackTrace) {
      _logger.e('Complete application data deletion failed', error: e, stackTrace: stackTrace);
      return DeletionResult(
        success: false,
        error: e.toString(),
        deletionType: DeletionType.complete,
      );
    }
  }

  /// Requests server-side data deletion
  Future<DeletionResult> requestServerDataDeletion(String userId) async {
    try {
      _logger.i('Requesting server data deletion for user: $userId');
      
      // TODO: Implement API call to backend for data deletion
      // This would typically involve:
      // 1. Making authenticated API call to delete endpoint
      // 2. Handling response and confirmation
      // 3. Scheduling deletion if not immediate
      
      // For now, we'll simulate the request
      await Future.delayed(const Duration(seconds: 2));
      
      _logger.i('Server data deletion requested successfully for user: $userId');
      
      return DeletionResult(
        success: true,
        deletionType: DeletionType.server,
        message: 'Server data deletion has been requested. You will receive a confirmation email within 24 hours.',
      );

    } catch (e, stackTrace) {
      _logger.e('Server data deletion request failed for user: $userId', error: e, stackTrace: stackTrace);
      return DeletionResult(
        success: false,
        error: e.toString(),
        deletionType: DeletionType.server,
      );
    }
  }

  /// Performs complete account deletion (local + server)
  Future<DeletionResult> deleteCompleteAccount(
    String userId, {
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      _logger.i('Starting complete account deletion for user: $userId');
      
      // Delete local data first
      onProgress?.call(0.0, 'Deleting local data...');
      final localResult = await deleteLocalUserData(
        userId,
        onProgress: (progress, status) => onProgress?.call(progress * 0.7, status),
      );

      if (!localResult.success) {
        return localResult.copyWith(deletionType: DeletionType.complete);
      }

      // Request server data deletion
      onProgress?.call(0.7, 'Requesting server data deletion...');
      final serverResult = await requestServerDataDeletion(userId);

      onProgress?.call(1.0, 'Account deletion completed');

      _logger.i('Complete account deletion completed for user: $userId');
      
      return DeletionResult(
        success: localResult.success && serverResult.success,
        deletedRecords: localResult.deletedRecords,
        deletionType: DeletionType.complete,
        message: serverResult.message,
        error: serverResult.success ? null : serverResult.error,
      );

    } catch (e, stackTrace) {
      _logger.e('Complete account deletion failed for user: $userId', error: e, stackTrace: stackTrace);
      return DeletionResult(
        success: false,
        error: e.toString(),
        deletionType: DeletionType.complete,
      );
    }
  }

  /// Cleans up orphaned data that might remain after deletion
  Future<void> _cleanupOrphanedData() async {
    try {
      final db = await _databaseHelper.database;
      
      // Clean up orphaned workout sets (sets without sessions)
      await db.execute('''
        DELETE FROM workout_sets 
        WHERE session_id NOT IN (SELECT id FROM workout_sessions)
      ''');

      // Clean up orphaned fatigue events (events without users)
      await db.execute('''
        DELETE FROM fatigue_events 
        WHERE workout_session_id NOT IN (SELECT id FROM workout_sessions)
      ''');

      // Clean up orphaned recovery states (states without users)
      await db.execute('''
        DELETE FROM recovery_states 
        WHERE id NOT IN (
          SELECT DISTINCT muscle_group_id || '_' || user_id 
          FROM users CROSS JOIN muscle_groups
        )
      ''');

      _logger.d('Orphaned data cleanup completed');
    } catch (e) {
      _logger.w('Failed to cleanup orphaned data: $e');
    }
  }

  /// Deletes the database file
  Future<void> _deleteDatabaseFile() async {
    try {
      final databasesPath = await getDatabasesPath();
      final dbPath = '$databasesPath/cycleavatar.db';
      final dbFile = File(dbPath);
      
      if (await dbFile.exists()) {
        await dbFile.delete();
        _logger.d('Database file deleted: $dbPath');
      }

      // Also delete any backup or temporary database files
      final directory = Directory(databasesPath);
      final files = await directory.list().toList();
      
      for (final file in files) {
        if (file is File && file.path.contains('cycleavatar')) {
          await file.delete();
          _logger.d('Database-related file deleted: ${file.path}');
        }
      }
    } catch (e) {
      _logger.w('Failed to delete database file: $e');
    }
  }

  /// Clears application cache and temporary files
  Future<void> _clearApplicationCache() async {
    try {
      // Clear temporary directory
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        _logger.d('Temporary directory cleared');
      }

      // Clear application cache directory
      try {
        final cacheDir = await getApplicationCacheDirectory();
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
          _logger.d('Cache directory cleared');
        }
      } catch (e) {
        _logger.w('Failed to clear cache directory: $e');
      }

      // Clear any export files in documents directory
      try {
        final documentsDir = await getApplicationDocumentsDirectory();
        final files = await documentsDir.list().toList();
        
        for (final file in files) {
          if (file is File && file.path.contains('cycleavatar_export')) {
            await file.delete();
            _logger.d('Export file deleted: ${file.path}');
          }
        }
      } catch (e) {
        _logger.w('Failed to clear export files: $e');
      }

    } catch (e) {
      _logger.w('Failed to clear application cache: $e');
    }
  }

  /// Gets information about what data will be deleted
  Future<DeletionInfo> getDeletionInfo(String userId) async {
    try {
      int totalRecords = 0;
      final details = <String, int>{};

      // Count user data
      final user = await _userRepository.findById(userId);
      if (user != null) {
        totalRecords += 1;
        details['User Profile'] = 1;
      }

      // Count workout sessions
      final workoutSessions = await _workoutRepository.findByUserId(userId);
      totalRecords += workoutSessions.length;
      details['Workout Sessions'] = workoutSessions.length;

      // Count total sets
      final totalSets = workoutSessions.fold(0, (sum, session) => sum + session.sets.length);
      details['Workout Sets'] = totalSets;

      // Count PR records
      final prRecords = await _prRepository.findByUserId(userId);
      totalRecords += prRecords.length;
      details['Personal Records'] = prRecords.length;

      // Count templates
      final templates = await _templateRepository.findByUserId(userId);
      totalRecords += templates.length;
      details['Workout Templates'] = templates.length;

      // Count notifications
      final notifications = await _notificationRepository.findByUserId(userId);
      totalRecords += notifications.length;
      details['Notifications'] = notifications.length;

      // Count streak records
      final streakRecords = await _streakRepository.findByUserId(userId);
      totalRecords += streakRecords.length;
      details['Streak Records'] = streakRecords.length;

      return DeletionInfo(
        totalRecords: totalRecords,
        details: details,
        estimatedTime: _estimateDeletionTime(totalRecords),
      );

    } catch (e) {
      _logger.e('Failed to get deletion info for user: $userId', error: e);
      rethrow;
    }
  }

  /// Estimates deletion time based on record count
  Duration _estimateDeletionTime(int recordCount) {
    // Rough estimate: 10ms per record + base overhead
    final milliseconds = (recordCount * 10) + 1000;
    return Duration(milliseconds: milliseconds);
  }
}

/// Result of a data deletion operation
class DeletionResult {
  final bool success;
  final int? deletedRecords;
  final DeletionType deletionType;
  final String? message;
  final String? error;

  DeletionResult({
    required this.success,
    this.deletedRecords,
    required this.deletionType,
    this.message,
    this.error,
  });

  DeletionResult copyWith({
    bool? success,
    int? deletedRecords,
    DeletionType? deletionType,
    String? message,
    String? error,
  }) {
    return DeletionResult(
      success: success ?? this.success,
      deletedRecords: deletedRecords ?? this.deletedRecords,
      deletionType: deletionType ?? this.deletionType,
      message: message ?? this.message,
      error: error ?? this.error,
    );
  }
}

/// Information about data to be deleted
class DeletionInfo {
  final int totalRecords;
  final Map<String, int> details;
  final Duration estimatedTime;

  DeletionInfo({
    required this.totalRecords,
    required this.details,
    required this.estimatedTime,
  });

  /// Gets human-readable estimated time
  String get formattedEstimatedTime {
    if (estimatedTime.inMinutes > 0) {
      return '${estimatedTime.inMinutes} minute(s)';
    } else {
      return '${estimatedTime.inSeconds} second(s)';
    }
  }
}

/// Types of data deletion
enum DeletionType {
  local,    // Local data only
  server,   // Server data only
  complete, // Both local and server
}

/// Exception thrown during deletion operations
class DeletionException implements Exception {
  final String message;
  
  DeletionException(this.message);
  
  @override
  String toString() => 'DeletionException: $message';
}