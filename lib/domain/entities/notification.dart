import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification.freezed.dart';
part 'notification.g.dart';

enum NotificationType {
  recoveryComplete,
  deloadRecommended,
  prAchieved,
  streakMilestone,
  weeklyHighlight,
  avatarLevelUp,
  badgeUnlocked,
  workoutReminder,
  custom;

  String getLocalizedName(String locale) {
    switch (this) {
      case NotificationType.recoveryComplete:
        return locale == 'ja' ? '回復完了' : 'Recovery Complete';
      case NotificationType.deloadRecommended:
        return locale == 'ja' ? 'デロード推奨' : 'Deload Recommended';
      case NotificationType.prAchieved:
        return locale == 'ja' ? 'PR達成' : 'PR Achieved';
      case NotificationType.streakMilestone:
        return locale == 'ja' ? '連続記録' : 'Streak Milestone';
      case NotificationType.weeklyHighlight:
        return locale == 'ja' ? '週次ハイライト' : 'Weekly Highlight';
      case NotificationType.avatarLevelUp:
        return locale == 'ja' ? 'アバターレベルアップ' : 'Avatar Level Up';
      case NotificationType.badgeUnlocked:
        return locale == 'ja' ? 'バッジ獲得' : 'Badge Unlocked';
      case NotificationType.workoutReminder:
        return locale == 'ja' ? 'ワークアウトリマインダー' : 'Workout Reminder';
      case NotificationType.custom:
        return locale == 'ja' ? 'カスタム' : 'Custom';
    }
  }
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent;

  String getLocalizedName(String locale) {
    switch (this) {
      case NotificationPriority.low:
        return locale == 'ja' ? '低' : 'Low';
      case NotificationPriority.normal:
        return locale == 'ja' ? '通常' : 'Normal';
      case NotificationPriority.high:
        return locale == 'ja' ? '高' : 'High';
      case NotificationPriority.urgent:
        return locale == 'ja' ? '緊急' : 'Urgent';
    }
  }
}

@freezed
class Notification with _$Notification {
  const factory Notification({
    required String id,
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    required DateTime createdAt,
    DateTime? scheduledFor, // When to show the notification
    DateTime? readAt, // When the user read the notification
    @Default(NotificationPriority.normal) NotificationPriority priority,
    @Default({}) Map<String, dynamic> data, // Additional data for the notification
    @Default(false) bool isRead,
    @Default(false) bool isSent, // Whether the notification has been sent to the device
    String? actionUrl, // Deep link or action to perform when tapped
    String? imageUrl, // Optional image for rich notifications
  }) = _Notification;

  const Notification._();

  factory Notification.fromJson(Map<String, dynamic> json) => 
      _$NotificationFromJson(json);

  /// Validates notification data
  String? validate() {
    if (id.isEmpty) return 'Notification ID cannot be empty';
    if (userId.isEmpty) return 'User ID cannot be empty';
    if (title.isEmpty) return 'Title cannot be empty';
    if (title.length > 100) return 'Title too long (max 100 characters)';
    if (body.isEmpty) return 'Body cannot be empty';
    if (body.length > 500) return 'Body too long (max 500 characters)';
    if (scheduledFor != null && scheduledFor!.isBefore(createdAt)) {
      return 'Scheduled time cannot be before creation time';
    }
    if (readAt != null && readAt!.isBefore(createdAt)) {
      return 'Read time cannot be before creation time';
    }
    return null;
  }

  /// Checks if the notification data is valid
  bool get isValid => validate() == null;

  /// Checks if the notification is scheduled for the future
  bool get isScheduled => scheduledFor != null && scheduledFor!.isAfter(DateTime.now());

  /// Checks if the notification is ready to be sent
  bool get isReadyToSend {
    if (isSent) return false;
    if (scheduledFor == null) return true;
    return scheduledFor!.isBefore(DateTime.now()) || scheduledFor!.isAtSameMomentAs(DateTime.now());
  }

  /// Gets the age of the notification
  Duration get age => DateTime.now().difference(createdAt);

  /// Checks if the notification is recent (within last 24 hours)
  bool get isRecent => age.inHours <= 24;

  /// Marks the notification as read
  Notification markAsRead() {
    return copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
  }

  /// Marks the notification as sent
  Notification markAsSent() {
    return copyWith(isSent: true);
  }

  /// Gets the time until the notification should be sent
  Duration? get timeUntilScheduled {
    if (scheduledFor == null) return null;
    final remaining = scheduledFor!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Creates a recovery complete notification
  factory Notification.recoveryComplete({
    required String id,
    required String userId,
    required String muscleGroupName,
    required DateTime scheduledFor,
    String locale = 'en',
  }) {
    final title = locale == 'ja' ? '回復完了！' : 'Recovery Complete!';
    final body = locale == 'ja' 
        ? '$muscleGroupNameが回復しました。トレーニングの準備ができています！'
        : '$muscleGroupName has recovered. Ready for training!';
    
    return Notification(
      id: id,
      userId: userId,
      type: NotificationType.recoveryComplete,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      scheduledFor: scheduledFor,
      priority: NotificationPriority.normal,
      data: {'muscleGroup': muscleGroupName},
    );
  }

  /// Creates a PR achieved notification
  factory Notification.prAchieved({
    required String id,
    required String userId,
    required String exerciseName,
    required double weight,
    required int reps,
    String locale = 'en',
  }) {
    final title = locale == 'ja' ? 'PR達成！🎉' : 'PR Achieved! 🎉';
    final body = locale == 'ja'
        ? '$exerciseName ${weight}kg × ${reps}回の新記録を達成しました！'
        : 'New PR in $exerciseName: ${weight}kg × ${reps} reps!';
    
    return Notification(
      id: id,
      userId: userId,
      type: NotificationType.prAchieved,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      priority: NotificationPriority.high,
      data: {
        'exercise': exerciseName,
        'weight': weight,
        'reps': reps,
      },
    );
  }

  /// Creates a deload recommended notification
  factory Notification.deloadRecommended({
    required String id,
    required String userId,
    String locale = 'en',
  }) {
    final title = locale == 'ja' ? 'デロード推奨' : 'Deload Recommended';
    final body = locale == 'ja'
        ? '今週はデロード週をお勧めします。軽い重量でフォームを確認しましょう。'
        : 'Consider a deload week. Focus on lighter weights and perfect form.';
    
    return Notification(
      id: id,
      userId: userId,
      type: NotificationType.deloadRecommended,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      priority: NotificationPriority.normal,
    );
  }

  /// Creates an avatar level up notification
  factory Notification.avatarLevelUp({
    required String id,
    required String userId,
    required String muscleGroupName,
    required int newLevel,
    String locale = 'en',
  }) {
    final title = locale == 'ja' ? 'レベルアップ！⬆️' : 'Level Up! ⬆️';
    final body = locale == 'ja'
        ? '$muscleGroupNameがレベル$newLevelに成長しました！'
        : '$muscleGroupName has grown to level $newLevel!';
    
    return Notification(
      id: id,
      userId: userId,
      type: NotificationType.avatarLevelUp,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      priority: NotificationPriority.high,
      data: {
        'muscleGroup': muscleGroupName,
        'level': newLevel,
      },
    );
  }

  /// Creates a streak milestone notification
  factory Notification.streakMilestone({
    required String id,
    required String userId,
    required int streakDays,
    String locale = 'en',
  }) {
    final title = locale == 'ja' ? '連続記録達成！🔥' : 'Streak Milestone! 🔥';
    final body = locale == 'ja'
        ? '${streakDays}日連続でトレーニングを継続中です！'
        : '${streakDays} days training streak achieved!';
    
    return Notification(
      id: id,
      userId: userId,
      type: NotificationType.streakMilestone,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      priority: NotificationPriority.high,
      data: {'streakDays': streakDays},
    );
  }

  /// Creates a weekly highlight notification
  factory Notification.weeklyHighlight({
    required String id,
    required String userId,
    required Map<String, dynamic> weeklyStats,
    String locale = 'en',
  }) {
    final title = locale == 'ja' ? '週次ハイライト📊' : 'Weekly Highlight 📊';
    final totalVolume = weeklyStats['totalVolume'] ?? 0;
    final sessionsCount = weeklyStats['sessionsCount'] ?? 0;
    
    final body = locale == 'ja'
        ? '今週は${sessionsCount}回のセッションで総ボリューム${totalVolume}kgを達成しました！'
        : 'This week: $sessionsCount sessions with ${totalVolume}kg total volume!';
    
    return Notification(
      id: id,
      userId: userId,
      type: NotificationType.weeklyHighlight,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      priority: NotificationPriority.normal,
      data: weeklyStats,
    );
  }

  /// Checks if this notification should be shown based on user engagement
  bool shouldShow({
    required int userEngagementScore, // 0-100
    required DateTime lastSimilarNotification,
  }) {
    // Don't show if user engagement is very low and it's been less than a week
    if (userEngagementScore < 20 && 
        DateTime.now().difference(lastSimilarNotification).inDays < 7) {
      return false;
    }
    
    // High priority notifications should always be shown
    if (priority == NotificationPriority.high || priority == NotificationPriority.urgent) {
      return true;
    }
    
    // For normal/low priority, consider user engagement
    return userEngagementScore >= 30;
  }
}