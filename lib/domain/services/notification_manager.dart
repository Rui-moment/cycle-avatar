import 'dart:async';
import 'package:uuid/uuid.dart';
import '../entities/notification.dart';
import '../entities/notification_preferences.dart';
import '../entities/muscle_group.dart';
import '../entities/user.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/notification_preferences_repository.dart';
import 'notification_service.dart';

/// High-level manager for coordinating notification operations
class NotificationManager {
  final NotificationService _notificationService;
  final NotificationRepository _notificationRepository;
  final NotificationPreferencesRepository _preferencesRepository;
  final Uuid _uuid = const Uuid();
  
  Timer? _scheduledNotificationTimer;
  
  NotificationManager(
    this._notificationService,
    this._notificationRepository,
    this._preferencesRepository,
  );

  /// Initialize the notification manager
  Future<bool> initialize() async {
    final initialized = await _notificationService.initialize();
    if (initialized) {
      await _startScheduledNotificationProcessor();
    }
    return initialized;
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    return await _notificationService.requestPermissions();
  }

  /// Schedule a recovery complete notification
  Future<void> scheduleRecoveryNotification({
    required String userId,
    required MuscleGroup muscleGroup,
    required Duration estimatedRecoveryTime,
    required String locale,
  }) async {
    // Check user preferences
    final preferences = await _preferencesRepository.getOrCreateForUser(userId);
    if (!preferences.shouldSendNotification(
      NotificationType.recoveryComplete,
      muscleGroupId: muscleGroup.id,
    )) {
      return;
    }

    // Check if similar notification was sent recently
    final hasSimilar = await _notificationRepository.hasSimilarRecentNotification(
      userId,
      NotificationType.recoveryComplete,
      preferences.minimumInterval,
    );
    if (hasSimilar) return;

    // Calculate scheduled time considering user preferences
    final baseScheduledTime = DateTime.now().add(estimatedRecoveryTime);
    final scheduledTime = _adjustTimeForPreferences(baseScheduledTime, preferences);

    // Create and store notification
    final notificationId = _uuid.v4();
    final notification = Notification.recoveryComplete(
      id: notificationId,
      userId: userId,
      muscleGroupName: muscleGroup.getLocalizedName(locale),
      scheduledFor: scheduledTime,
      locale: locale,
    );

    await _notificationRepository.create(notification);

    // Schedule with the notification service
    await _notificationService.scheduleRecoveryNotification(
      notificationId: notificationId,
      userId: userId,
      muscleGroup: muscleGroup,
      estimatedRecoveryTime: scheduledTime.difference(DateTime.now()),
      locale: locale,
    );
  }

  /// Show PR achievement notification immediately
  Future<void> showPRNotification({
    required String userId,
    required String exerciseName,
    required double weight,
    required int reps,
    required String locale,
  }) async {
    // Check user preferences
    final preferences = await _preferencesRepository.getOrCreateForUser(userId);
    if (!preferences.shouldSendNotification(NotificationType.prAchieved)) {
      return;
    }

    // Check daily notification limit
    if (await _hasReachedDailyLimit(userId, preferences)) {
      return;
    }

    // Create and store notification
    final notificationId = _uuid.v4();
    final notification = Notification.prAchieved(
      id: notificationId,
      userId: userId,
      exerciseName: exerciseName,
      weight: weight,
      reps: reps,
      locale: locale,
    );

    await _notificationRepository.create(notification);

    // Show immediately
    await _notificationService.showPRNotification(
      notificationId: notificationId,
      userId: userId,
      exerciseName: exerciseName,
      weight: weight,
      reps: reps,
      locale: locale,
    );

    // Mark as sent
    await _notificationRepository.markAsSent(notificationId);
  }

  /// Show deload recommendation notification
  Future<void> showDeloadNotification({
    required String userId,
    required String locale,
  }) async {
    // Check user preferences
    final preferences = await _preferencesRepository.getOrCreateForUser(userId);
    if (!preferences.shouldSendNotification(NotificationType.deloadRecommended)) {
      return;
    }

    // Check if similar notification was sent recently (within 7 days)
    final hasSimilar = await _notificationRepository.hasSimilarRecentNotification(
      userId,
      NotificationType.deloadRecommended,
      const Duration(days: 7),
    );
    if (hasSimilar) return;

    // Create and store notification
    final notificationId = _uuid.v4();
    final notification = Notification.deloadRecommended(
      id: notificationId,
      userId: userId,
      locale: locale,
    );

    await _notificationRepository.create(notification);

    // Show immediately or schedule for next available time
    if (preferences.isInQuietHours || !preferences.isEnabledForToday) {
      final scheduledTime = preferences.getNextAvailableTime();
      final updatedNotification = notification.copyWith(scheduledFor: scheduledTime);
      await _notificationRepository.update(updatedNotification);
    } else {
      await _notificationService.showDeloadNotification(
        notificationId: notificationId,
        userId: userId,
        locale: locale,
      );
      await _notificationRepository.markAsSent(notificationId);
    }
  }

  /// Show avatar level up notification
  Future<void> showAvatarLevelUpNotification({
    required String userId,
    required String muscleGroupName,
    required int newLevel,
    required String locale,
  }) async {
    // Check user preferences
    final preferences = await _preferencesRepository.getOrCreateForUser(userId);
    if (!preferences.shouldSendNotification(NotificationType.avatarLevelUp)) {
      return;
    }

    // Create and store notification
    final notificationId = _uuid.v4();
    final notification = Notification.avatarLevelUp(
      id: notificationId,
      userId: userId,
      muscleGroupName: muscleGroupName,
      newLevel: newLevel,
      locale: locale,
    );

    await _notificationRepository.create(notification);

    // Show immediately (level ups are important)
    await _notificationService.showAvatarLevelUpNotification(
      notificationId: notificationId,
      userId: userId,
      muscleGroupName: muscleGroupName,
      newLevel: newLevel,
      locale: locale,
    );

    await _notificationRepository.markAsSent(notificationId);
  }

  /// Show streak milestone notification
  Future<void> showStreakMilestoneNotification({
    required String userId,
    required int streakDays,
    required String locale,
  }) async {
    // Check user preferences
    final preferences = await _preferencesRepository.getOrCreateForUser(userId);
    if (!preferences.shouldSendNotification(NotificationType.streakMilestone)) {
      return;
    }

    // Create and store notification
    final notificationId = _uuid.v4();
    final notification = Notification.streakMilestone(
      id: notificationId,
      userId: userId,
      streakDays: streakDays,
      locale: locale,
    );

    await _notificationRepository.create(notification);

    // Show immediately (milestones are important)
    await _notificationService.showStreakMilestoneNotification(
      notificationId: notificationId,
      userId: userId,
      streakDays: streakDays,
      locale: locale,
    );

    await _notificationRepository.markAsSent(notificationId);
  }

  /// Show weekly highlight notification
  Future<void> showWeeklyHighlightNotification({
    required String userId,
    required Map<String, dynamic> weeklyStats,
    required String locale,
  }) async {
    // Check user preferences
    final preferences = await _preferencesRepository.getOrCreateForUser(userId);
    if (!preferences.shouldSendNotification(NotificationType.weeklyHighlight)) {
      return;
    }

    // Create and store notification
    final notificationId = _uuid.v4();
    final notification = Notification.weeklyHighlight(
      id: notificationId,
      userId: userId,
      weeklyStats: weeklyStats,
      locale: locale,
    );

    await _notificationRepository.create(notification);

    // Schedule for next available time (weekly highlights can wait)
    final scheduledTime = preferences.getNextAvailableTime();
    if (scheduledTime.isAfter(DateTime.now())) {
      final updatedNotification = notification.copyWith(scheduledFor: scheduledTime);
      await _notificationRepository.update(updatedNotification);
    } else {
      await _notificationService.showWeeklyHighlightNotification(
        notificationId: notificationId,
        userId: userId,
        weeklyStats: weeklyStats,
        locale: locale,
      );
      await _notificationRepository.markAsSent(notificationId);
    }
  }

  /// Get notification preferences for a user
  Future<NotificationPreferences> getPreferences(String userId) async {
    return await _preferencesRepository.getOrCreateForUser(userId);
  }

  /// Update notification preferences
  Future<void> updatePreferences(NotificationPreferences preferences) async {
    await _preferencesRepository.update(preferences);
  }

  /// Get notifications for a user
  Future<List<Notification>> getNotifications(String userId) async {
    return await _notificationRepository.getByUserId(userId);
  }

  /// Get unread notifications for a user
  Future<List<Notification>> getUnreadNotifications(String userId) async {
    return await _notificationRepository.getUnreadByUserId(userId);
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await _notificationRepository.markAsRead(notificationId);
  }

  /// Mark all notifications as read for a user
  Future<void> markAllNotificationsAsRead(String userId) async {
    await _notificationRepository.markAllAsReadForUser(userId);
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(String notificationId) async {
    await _notificationService.cancelNotification(notificationId);
    await _notificationRepository.delete(notificationId);
  }

  /// Cancel all notifications for a user
  Future<void> cancelAllNotificationsForUser(String userId) async {
    final notifications = await _notificationRepository.getByUserId(userId);
    for (final notification in notifications) {
      await _notificationService.cancelNotification(notification.id);
    }
    // Delete from database
    final db = await _notificationRepository.database;
    await db.delete(
      'notifications',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Get user engagement score
  Future<int> getUserEngagementScore(String userId) async {
    return await _notificationRepository.getUserEngagementScore(userId);
  }

  /// Clean up old notifications
  Future<void> cleanupOldNotifications({int daysOld = 30}) async {
    await _notificationRepository.deleteOldNotifications(daysOld);
  }

  /// Check if notifications are enabled on the device
  Future<bool> areNotificationsEnabled() async {
    return await _notificationService.areNotificationsEnabled();
  }

  /// Start the scheduled notification processor
  Future<void> _startScheduledNotificationProcessor() async {
    _scheduledNotificationTimer?.cancel();
    _scheduledNotificationTimer = Timer.periodic(
      const Duration(minutes: 5), // Check every 5 minutes
      (_) => _processScheduledNotifications(),
    );
    
    // Process immediately on start
    await _processScheduledNotifications();
  }

  /// Process scheduled notifications that are ready to be sent
  Future<void> _processScheduledNotifications() async {
    try {
      final readyNotifications = await _notificationRepository.getReadyToSend();
      
      for (final notification in readyNotifications) {
        // Double-check user preferences before sending
        final preferences = await _preferencesRepository.getOrCreateForUser(notification.userId);
        
        if (!preferences.shouldSendNotification(notification.type)) {
          // User has disabled this type, mark as sent to avoid reprocessing
          await _notificationRepository.markAsSent(notification.id);
          continue;
        }
        
        // Check daily limit
        if (await _hasReachedDailyLimit(notification.userId, preferences)) {
          // Reschedule for tomorrow
          final tomorrow = DateTime.now().add(const Duration(days: 1));
          final nextAvailable = preferences.getNextAvailableTime();
          final rescheduledTime = nextAvailable.isAfter(tomorrow) ? nextAvailable : tomorrow;
          
          final rescheduled = notification.copyWith(scheduledFor: rescheduledTime);
          await _notificationRepository.update(rescheduled);
          continue;
        }
        
        // Send the notification
        await _notificationService.showNotification(notification);
        await _notificationRepository.markAsSent(notification.id);
      }
    } catch (e) {
      print('Error processing scheduled notifications: $e');
    }
  }

  /// Check if user has reached daily notification limit
  Future<bool> _hasReachedDailyLimit(
    String userId,
    NotificationPreferences preferences,
  ) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final db = await _notificationRepository.database;
    final todayNotifications = await db.query(
      'notifications',
      where: 'user_id = ? AND is_sent = 1 AND created_at >= ?',
      whereArgs: [userId, startOfDay.millisecondsSinceEpoch],
    );
    
    return todayNotifications.length >= preferences.maxNotificationsPerDay;
  }

  /// Adjust notification time based on user preferences
  DateTime _adjustTimeForPreferences(
    DateTime baseTime,
    NotificationPreferences preferences,
  ) {
    // If the base time is in quiet hours or on a disabled day, adjust it
    final testPrefs = preferences.copyWith(); // Create a copy to test with the base time
    
    if (preferences.isInQuietHours || !preferences.isEnabledForToday) {
      return preferences.getNextAvailableTime();
    }
    
    return baseTime;
  }

  /// Dispose resources
  void dispose() {
    _scheduledNotificationTimer?.cancel();
    _notificationService.dispose();
  }
}