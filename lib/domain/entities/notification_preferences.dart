import 'package:freezed_annotation/freezed_annotation.dart';
import 'notification.dart';

part 'notification_preferences.freezed.dart';
part 'notification_preferences.g.dart';

@freezed
class NotificationPreferences with _$NotificationPreferences {
  const factory NotificationPreferences({
    required String id,
    required String userId,
    @Default(true) bool recoveryNotifications,
    @Default(true) bool prNotifications,
    @Default(true) bool streakNotifications,
    @Default(true) bool weeklyHighlights,
    @Default(true) bool avatarLevelUpNotifications,
    @Default(true) bool deloadNotifications,
    @Default(true) bool badgeNotifications,
    @Default(false) bool workoutReminders,
    
    // Quiet hours (24-hour format)
    @Default(22) int quietHoursStart, // 22:00
    @Default(7) int quietHoursEnd,    // 07:00
    
    // Days of week (0 = Sunday, 6 = Saturday)
    @Default([1, 2, 3, 4, 5, 6, 7]) List<int> enabledDays,
    
    // Muscle group specific settings
    @Default({}) Map<String, bool> muscleGroupNotifications,
    
    // Notification frequency limits
    @Default(3) int maxNotificationsPerDay,
    @Default(Duration(hours: 2)) Duration minimumInterval,
    
    // Advanced settings
    @Default(true) bool enableVibration,
    @Default(true) bool enableSound,
    @Default(true) bool enableBadge,
    
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _NotificationPreferences;

  const NotificationPreferences._();

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferencesFromJson(json);

  /// Creates default notification preferences for a user
  factory NotificationPreferences.defaultForUser(String userId) {
    return NotificationPreferences(
      id: 'notif_pref_$userId',
      userId: userId,
      createdAt: DateTime.now(),
    );
  }

  /// Validates notification preferences
  String? validate() {
    if (id.isEmpty) return 'Notification preferences ID cannot be empty';
    if (userId.isEmpty) return 'User ID cannot be empty';
    if (quietHoursStart < 0 || quietHoursStart > 23) {
      return 'Quiet hours start must be between 0 and 23';
    }
    if (quietHoursEnd < 0 || quietHoursEnd > 23) {
      return 'Quiet hours end must be between 0 and 23';
    }
    if (maxNotificationsPerDay < 0 || maxNotificationsPerDay > 50) {
      return 'Max notifications per day must be between 0 and 50';
    }
    if (minimumInterval.inMinutes < 1) {
      return 'Minimum interval must be at least 1 minute';
    }
    if (enabledDays.any((day) => day < 1 || day > 7)) {
      return 'Enabled days must be between 1 and 7';
    }
    return null;
  }

  /// Checks if the preferences are valid
  bool get isValid => validate() == null;

  /// Checks if notifications are enabled for a specific type
  bool isNotificationTypeEnabled(NotificationType type) {
    switch (type) {
      case NotificationType.recoveryComplete:
        return recoveryNotifications;
      case NotificationType.prAchieved:
        return prNotifications;
      case NotificationType.streakMilestone:
        return streakNotifications;
      case NotificationType.weeklyHighlight:
        return weeklyHighlights;
      case NotificationType.avatarLevelUp:
        return avatarLevelUpNotifications;
      case NotificationType.deloadRecommended:
        return deloadNotifications;
      case NotificationType.badgeUnlocked:
        return badgeNotifications;
      case NotificationType.workoutReminder:
        return workoutReminders;
      case NotificationType.custom:
        return true; // Custom notifications are always enabled if created
    }
  }

  /// Checks if notifications are enabled for a specific muscle group
  bool isMuscleGroupNotificationEnabled(String muscleGroupId) {
    return muscleGroupNotifications[muscleGroupId] ?? true;
  }

  /// Checks if the current time is within quiet hours
  bool get isInQuietHours {
    final now = DateTime.now();
    final currentHour = now.hour;
    
    if (quietHoursStart <= quietHoursEnd) {
      // Same day quiet hours (e.g., 22:00 to 07:00 next day)
      return currentHour >= quietHoursStart || currentHour < quietHoursEnd;
    } else {
      // Cross-midnight quiet hours (e.g., 10:00 to 14:00)
      return currentHour >= quietHoursStart && currentHour < quietHoursEnd;
    }
  }

  /// Checks if notifications are enabled for the current day
  bool get isEnabledForToday {
    final today = DateTime.now().weekday; // 1 = Monday, 7 = Sunday
    return enabledDays.contains(today);
  }

  /// Checks if a notification should be sent based on all preferences
  bool shouldSendNotification(NotificationType type, {String? muscleGroupId}) {
    // Check if notification type is enabled
    if (!isNotificationTypeEnabled(type)) return false;
    
    // Check if muscle group notifications are enabled (if applicable)
    if (muscleGroupId != null && !isMuscleGroupNotificationEnabled(muscleGroupId)) {
      return false;
    }
    
    // Check if today is enabled
    if (!isEnabledForToday) return false;
    
    // Check quiet hours
    if (isInQuietHours) return false;
    
    return true;
  }

  /// Gets the next available time to send a notification (after quiet hours)
  DateTime getNextAvailableTime() {
    final now = DateTime.now();
    
    if (!isInQuietHours && isEnabledForToday) {
      return now; // Can send immediately
    }
    
    // Calculate next available time
    DateTime nextTime = now;
    
    // If in quiet hours, move to end of quiet hours
    if (isInQuietHours) {
      if (quietHoursStart > quietHoursEnd) {
        // Cross-midnight quiet hours
        nextTime = DateTime(now.year, now.month, now.day, quietHoursEnd);
      } else {
        // Same day quiet hours
        if (now.hour >= quietHoursStart) {
          // Move to next day
          nextTime = DateTime(now.year, now.month, now.day + 1, quietHoursEnd);
        } else {
          // Later today
          nextTime = DateTime(now.year, now.month, now.day, quietHoursEnd);
        }
      }
    }
    
    // Find next enabled day
    while (!enabledDays.contains(nextTime.weekday)) {
      nextTime = nextTime.add(const Duration(days: 1));
      nextTime = DateTime(nextTime.year, nextTime.month, nextTime.day, quietHoursEnd);
    }
    
    return nextTime;
  }

  /// Updates muscle group notification setting
  NotificationPreferences updateMuscleGroupSetting(String muscleGroupId, bool enabled) {
    final updatedSettings = Map<String, bool>.from(muscleGroupNotifications);
    updatedSettings[muscleGroupId] = enabled;
    
    return copyWith(
      muscleGroupNotifications: updatedSettings,
      updatedAt: DateTime.now(),
    );
  }

  /// Enables all notification types
  NotificationPreferences enableAll() {
    return copyWith(
      recoveryNotifications: true,
      prNotifications: true,
      streakNotifications: true,
      weeklyHighlights: true,
      avatarLevelUpNotifications: true,
      deloadNotifications: true,
      badgeNotifications: true,
      workoutReminders: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Disables all notification types
  NotificationPreferences disableAll() {
    return copyWith(
      recoveryNotifications: false,
      prNotifications: false,
      streakNotifications: false,
      weeklyHighlights: false,
      avatarLevelUpNotifications: false,
      deloadNotifications: false,
      badgeNotifications: false,
      workoutReminders: false,
      updatedAt: DateTime.now(),
    );
  }

  /// Updates quiet hours
  NotificationPreferences updateQuietHours(int start, int end) {
    return copyWith(
      quietHoursStart: start,
      quietHoursEnd: end,
      updatedAt: DateTime.now(),
    );
  }

  /// Updates enabled days
  NotificationPreferences updateEnabledDays(List<int> days) {
    return copyWith(
      enabledDays: days,
      updatedAt: DateTime.now(),
    );
  }

  /// Gets a summary of current settings for display
  Map<String, dynamic> getSummary() {
    final enabledTypes = <String>[];
    
    if (recoveryNotifications) enabledTypes.add('Recovery');
    if (prNotifications) enabledTypes.add('PRs');
    if (streakNotifications) enabledTypes.add('Streaks');
    if (weeklyHighlights) enabledTypes.add('Weekly');
    if (avatarLevelUpNotifications) enabledTypes.add('Avatar');
    if (deloadNotifications) enabledTypes.add('Deload');
    if (badgeNotifications) enabledTypes.add('Badges');
    if (workoutReminders) enabledTypes.add('Reminders');
    
    return {
      'enabledTypes': enabledTypes,
      'quietHours': '${quietHoursStart.toString().padLeft(2, '0')}:00 - ${quietHoursEnd.toString().padLeft(2, '0')}:00',
      'enabledDaysCount': enabledDays.length,
      'maxPerDay': maxNotificationsPerDay,
      'hasCustomMuscleGroups': muscleGroupNotifications.isNotEmpty,
    };
  }
}