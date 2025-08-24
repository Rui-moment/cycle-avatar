import 'dart:async';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../entities/notification.dart';
import '../entities/muscle_group.dart';
import '../entities/user.dart';
import '../entities/enums.dart';

/// Service for managing local notifications
class NotificationService {
  static const String _channelId = 'cycle_avatar_notifications';
  static const String _channelName = 'CycleAvatar Notifications';
  static const String _channelDescription = 'Notifications for recovery, PRs, and milestones';
  
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  final StreamController<String> _notificationTapController = StreamController<String>.broadcast();
  
  NotificationService(this._flutterLocalNotificationsPlugin);

  /// Stream of notification tap events
  Stream<String> get onNotificationTap => _notificationTapController.stream;

  /// Initialize the notification service
  Future<bool> initialize() async {
    try {
      // Android initialization
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      final bool? initialized = await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      if (initialized == true) {
        await _createNotificationChannel();
        return true;
      }
      return false;
    } catch (e) {
      print('Error initializing notifications: $e');
      return false;
    }
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      _notificationTapController.add(payload);
    }
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // TODO: Fix iOS notification implementation
    // final DarwinFlutterLocalNotificationsPlugin? iosImplementation =
    //     _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
    //         DarwinFlutterLocalNotificationsPlugin>();

    bool androidPermission = true;
    bool iosPermission = true;

    if (androidImplementation != null) {
      androidPermission = await androidImplementation.requestNotificationsPermission() ?? false;
    }

    if (iosImplementation != null) {
      iosPermission = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ?? false;
    }

    return androidPermission && iosPermission;
  }

  /// Show immediate notification
  Future<void> showNotification(Notification notification) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: _getAndroidImportance(notification.priority),
        priority: _getAndroidPriority(notification.priority),
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        notification.id.hashCode,
        notification.title,
        notification.body,
        platformDetails,
        payload: notification.id,
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  /// Schedule notification for future delivery
  Future<void> scheduleNotification(Notification notification) async {
    if (notification.scheduledFor == null) {
      await showNotification(notification);
      return;
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: _getAndroidImportance(notification.priority),
        priority: _getAndroidPriority(notification.priority),
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notification.id.hashCode,
        notification.title,
        notification.body,
        _convertToTZDateTime(notification.scheduledFor!),
        platformDetails,
        payload: notification.id,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  /// Schedule recovery complete notification
  Future<void> scheduleRecoveryNotification({
    required String notificationId,
    required String userId,
    required MuscleGroup muscleGroup,
    required Duration estimatedRecoveryTime,
    required String locale,
  }) async {
    final scheduledTime = DateTime.now().add(estimatedRecoveryTime);
    
    final notification = Notification.recoveryComplete(
      id: notificationId,
      userId: userId,
      muscleGroupName: muscleGroup.getLocalizedName(locale),
      scheduledFor: scheduledTime,
      locale: locale,
    );

    await scheduleNotification(notification);
  }

  /// Show PR achievement notification immediately
  Future<void> showPRNotification({
    required String notificationId,
    required String userId,
    required String exerciseName,
    required double weight,
    required int reps,
    required String locale,
  }) async {
    final notification = Notification.prAchieved(
      id: notificationId,
      userId: userId,
      exerciseName: exerciseName,
      weight: weight,
      reps: reps,
      locale: locale,
    );

    await showNotification(notification);
  }

  /// Show deload recommendation notification
  Future<void> showDeloadNotification({
    required String notificationId,
    required String userId,
    required String locale,
  }) async {
    final notification = Notification.deloadRecommended(
      id: notificationId,
      userId: userId,
      locale: locale,
    );

    await showNotification(notification);
  }

  /// Show avatar level up notification
  Future<void> showAvatarLevelUpNotification({
    required String notificationId,
    required String userId,
    required String muscleGroupName,
    required int newLevel,
    required String locale,
  }) async {
    final notification = Notification.avatarLevelUp(
      id: notificationId,
      userId: userId,
      muscleGroupName: muscleGroupName,
      newLevel: newLevel,
      locale: locale,
    );

    await showNotification(notification);
  }

  /// Show streak milestone notification
  Future<void> showStreakMilestoneNotification({
    required String notificationId,
    required String userId,
    required int streakDays,
    required String locale,
  }) async {
    final notification = Notification.streakMilestone(
      id: notificationId,
      userId: userId,
      streakDays: streakDays,
      locale: locale,
    );

    await showNotification(notification);
  }

  /// Show weekly highlight notification
  Future<void> showWeeklyHighlightNotification({
    required String notificationId,
    required String userId,
    required Map<String, dynamic> weeklyStats,
    required String locale,
  }) async {
    final notification = Notification.weeklyHighlight(
      id: notificationId,
      userId: userId,
      weeklyStats: weeklyStats,
      locale: locale,
    );

    await showNotification(notification);
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(String notificationId) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(notificationId.hashCode);
    } catch (e) {
      print('Error canceling notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      print('Error canceling all notifications: $e');
    }
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      print('Error getting pending notifications: $e');
      return [];
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        return await androidImplementation.areNotificationsEnabled() ?? false;
      }
      
      // For iOS, assume enabled if we got this far
      return true;
    } catch (e) {
      print('Error checking notification status: $e');
      return false;
    }
  }

  /// Convert DateTime to TZDateTime for scheduling
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    // Use local timezone
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// Convert notification priority to Android importance
  Importance _getAndroidImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.normal:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.urgent:
        return Importance.max;
    }
  }

  /// Convert notification priority to Android priority
  Priority _getAndroidPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.normal:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.urgent:
        return Priority.max;
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationTapController.close();
  }
}