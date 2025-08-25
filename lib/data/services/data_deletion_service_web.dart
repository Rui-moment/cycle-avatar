import 'package:logger/logger.dart';
import 'package:universal_html/html.dart' as html;

import '../repositories/user_repository.dart';
import '../repositories/workout_repository.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/pr_repository.dart';
import '../repositories/template_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/streak_repository.dart';
import '../repositories/notification_preferences_repository.dart';

/// Web implementation of [DataDeletionService]
class DataDeletionService {
  final UserRepository _userRepository;
  final WorkoutSessionRepository _workoutRepository;
  final ExerciseRepository _exerciseRepository;
  final PRRepository _prRepository;
  final TemplateRepository _templateRepository;
  final NotificationRepository _notificationRepository;
  final StreakRepository _streakRepository;
  final NotificationPreferencesRepository _notificationPreferencesRepository;
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
  })  : _userRepository = userRepository,
        _workoutRepository = workoutRepository,
        _exerciseRepository = exerciseRepository,
        _prRepository = prRepository,
        _templateRepository = templateRepository,
        _notificationRepository = notificationRepository,
        _streakRepository = streakRepository,
        _notificationPreferencesRepository = notificationPreferencesRepository;

  /// Deletes all local user data (web version)
  Future<DeletionResult> deleteLocalUserData(
    String userId, {
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      _logger.i('Starting local data deletion for user: $userId');
      int deletedRecords = 0;
      onProgress?.call(0.0, 'Initializing deletion...');

      final user = await _userRepository.findById(userId);
      if (user == null) {
        throw DeletionException('User not found: $userId');
      }

      onProgress?.call(0.1, 'Deleting workout sessions...');
      final workoutSessions = await _workoutRepository.findByUserId(userId);
      for (final session in workoutSessions) {
        await _workoutRepository.deleteById(session.id);
        deletedRecords++;
      }

      onProgress?.call(0.3, 'Deleting personal records...');
      final prRecords = await _prRepository.findByUserId(userId);
      for (final pr in prRecords) {
        await _prRepository.deleteById(pr.id);
        deletedRecords++;
      }

      onProgress?.call(0.5, 'Deleting workout templates...');
      final templates = await _templateRepository.findByUserId(userId);
      for (final template in templates) {
        await _templateRepository.deleteById(template.id);
        deletedRecords++;
      }

      onProgress?.call(0.7, 'Deleting notifications...');
      final notifications = await _notificationRepository.findByUserId(userId);
      for (final notification in notifications) {
        await _notificationRepository.deleteById(notification.id);
        deletedRecords++;
      }

      onProgress?.call(0.8, 'Deleting streak records...');
      final streakRecords = await _streakRepository.findByUserId(userId);
      for (final streak in streakRecords) {
        await _streakRepository.deleteById(streak.id);
        deletedRecords++;
      }

      onProgress?.call(0.9, 'Deleting notification preferences...');
      try {
        final preferences =
            await _notificationPreferencesRepository.findByUserId(userId);
        if (preferences != null) {
          await _notificationPreferencesRepository.deleteById(preferences.id);
          deletedRecords++;
        }
      } catch (e) {
        _logger.w('Failed to delete notification preferences: $e');
      }

      onProgress?.call(0.95, 'Deleting user profile...');
      await _userRepository.deleteById(userId);
      deletedRecords++;

      onProgress?.call(1.0, 'Deletion completed');
      _logger.i('Local data deletion completed successfully for user: $userId');

      return DeletionResult(
        success: true,
        deletedRecords: deletedRecords,
        deletionType: DeletionType.local,
      );
    } catch (e, stackTrace) {
      _logger.e('Local data deletion failed for user: $userId',
          error: e, stackTrace: stackTrace);
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

      onProgress?.call(0.5, 'Clearing storage...');
      await _clearApplicationCache();

      onProgress?.call(1.0, 'Complete deletion finished');
      _logger.i('Complete application data deletion completed successfully');

      return DeletionResult(
        success: true,
        deletedRecords: -1,
        deletionType: DeletionType.complete,
      );
    } catch (e, stackTrace) {
      _logger.e('Complete application data deletion failed',
          error: e, stackTrace: stackTrace);
      return DeletionResult(
        success: false,
        error: e.toString(),
        deletionType: DeletionType.complete,
      );
    }
  }

  /// Requests server-side data deletion (simulated)
  Future<DeletionResult> requestServerDataDeletion(String userId) async {
    try {
      _logger.i('Requesting server data deletion for user: $userId');
      await Future.delayed(const Duration(seconds: 2));
      _logger.i('Server data deletion requested successfully for user: $userId');
      return DeletionResult(
        success: true,
        deletionType: DeletionType.server,
        message:
            'Server data deletion has been requested. You will receive a confirmation email within 24 hours.',
      );
    } catch (e, stackTrace) {
      _logger.e('Server data deletion request failed for user: $userId',
          error: e, stackTrace: stackTrace);
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
      onProgress?.call(0.0, 'Deleting local data...');
      final localResult = await deleteLocalUserData(
        userId,
        onProgress: (progress, status) => onProgress?.call(progress * 0.7, status),
      );

      if (!localResult.success) {
        return localResult.copyWith(deletionType: DeletionType.complete);
      }

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
      _logger.e('Complete account deletion failed for user: $userId',
          error: e, stackTrace: stackTrace);
      return DeletionResult(
        success: false,
        error: e.toString(),
        deletionType: DeletionType.complete,
      );
    }
  }

  Future<void> _clearApplicationCache() async {
    try {
      html.window.localStorage.clear();
    } catch (e) {
      _logger.w('Failed to clear application cache: $e');
    }
  }

  Future<void> _cleanupOrphanedData() async {
    // No-op for web implementation
  }

  Future<void> _deleteDatabaseFile() async {
    // No-op for web implementation
  }

  Future<DeletionInfo> getDeletionInfo(String userId) async {
    try {
      int totalRecords = 0;
      final details = <String, int>{};

      final user = await _userRepository.findById(userId);
      if (user != null) {
        totalRecords += 1;
        details['User Profile'] = 1;
      }

      final workoutSessions = await _workoutRepository.findByUserId(userId);
      totalRecords += workoutSessions.length;
      details['Workout Sessions'] = workoutSessions.length;

      final totalSets =
          workoutSessions.fold(0, (sum, session) => sum + session.sets.length);
      details['Workout Sets'] = totalSets;

      final prRecords = await _prRepository.findByUserId(userId);
      totalRecords += prRecords.length;
      details['Personal Records'] = prRecords.length;

      final templates = await _templateRepository.findByUserId(userId);
      totalRecords += templates.length;
      details['Workout Templates'] = templates.length;

      final notifications = await _notificationRepository.findByUserId(userId);
      totalRecords += notifications.length;
      details['Notifications'] = notifications.length;

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

  Duration _estimateDeletionTime(int recordCount) {
    final milliseconds = (recordCount * 10) + 1000;
    return Duration(milliseconds: milliseconds);
  }
}

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

class DeletionInfo {
  final int totalRecords;
  final Map<String, int> details;
  final Duration estimatedTime;

  DeletionInfo({
    required this.totalRecords,
    required this.details,
    required this.estimatedTime,
  });

  String get formattedEstimatedTime {
    if (estimatedTime.inMinutes > 0) {
      return '${estimatedTime.inMinutes} minute(s)';
    } else {
      return '${estimatedTime.inSeconds} second(s)';
    }
  }
}

enum DeletionType {
  local,
  server,
  complete,
}

class DeletionException implements Exception {
  final String message;
  DeletionException(this.message);
  @override
  String toString() => 'DeletionException: $message';
}
