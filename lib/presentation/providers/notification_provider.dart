import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/entities/notification.dart';
import '../../domain/services/notification_manager.dart';
import '../../domain/services/notification_service.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/notification_preferences_repository.dart';
import '../../data/datasources/local/database_helper.dart';

// Provider for database instance
final databaseProvider = FutureProvider<Database>((ref) async {
  final databaseHelper = DatabaseHelper();
  return await databaseHelper.database;
});

// Provider for the notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  return NotificationService(flutterLocalNotificationsPlugin);
});

// Provider for notification repository
final notificationRepositoryProvider = FutureProvider<NotificationRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return NotificationRepository(database);
});

// Provider for notification preferences repository
final notificationPreferencesRepositoryProvider = FutureProvider<NotificationPreferencesRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return NotificationPreferencesRepository(database);
});

// Provider for notification manager
final notificationManagerProvider = FutureProvider<NotificationManager>((ref) async {
  final notificationService = ref.watch(notificationServiceProvider);
  final notificationRepository = await ref.watch(notificationRepositoryProvider.future);
  final preferencesRepository = await ref.watch(notificationPreferencesRepositoryProvider.future);
  
  return NotificationManager(
    notificationService,
    notificationRepository,
    preferencesRepository,
  );
});

// State notifier for notification preferences
class NotificationNotifier extends StateNotifier<AsyncValue<NotificationPreferences>> {
  NotificationManager? _notificationManager;
  final String _userId;
  final Ref _ref;

  NotificationNotifier._placeholder(NotificationService notificationService, this._userId, this._ref) 
      : super(const AsyncValue.loading()) {
    _initializeManager();
  }

  Future<void> _initializeManager() async {
    try {
      final database = await _ref.read(databaseProvider.future);
      // TODO: Fix repository initialization
      final notificationRepository = null; // NotificationRepositoryImpl(database);
      final preferencesRepository = null; // NotificationPreferencesRepositoryImpl(database);
      final notificationService = _ref.read(notificationServiceProvider);
      
      _notificationManager = NotificationManager(
        notificationService,
        notificationRepository,
        preferencesRepository,
      );
      
      await _loadPreferences();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _loadPreferences() async {
    if (_notificationManager == null) return;
    
    try {
      final preferences = await _notificationManager!.getPreferences(_userId);
      state = AsyncValue.data(preferences);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updatePreferences(NotificationPreferences preferences) async {
    if (_notificationManager == null) return;
    
    try {
      await _notificationManager!.updatePreferences(preferences);
      state = AsyncValue.data(preferences);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> testNotification() async {
    if (_notificationManager == null) return;
    
    try {
      await _notificationManager!.showPRNotification(
        userId: _userId,
        exerciseName: 'Test Exercise',
        weight: 100.0,
        reps: 10,
        locale: 'en',
      );
    } catch (error) {
      rethrow;
    }
  }

  Future<bool> requestPermissions() async {
    if (_notificationManager == null) return false;
    return await _notificationManager!.requestPermissions();
  }

  Future<bool> areNotificationsEnabled() async {
    if (_notificationManager == null) return false;
    return await _notificationManager!.areNotificationsEnabled();
  }

  Future<void> cancelAllNotifications() async {
    if (_notificationManager == null) return;
    await _notificationManager!.cancelAllNotificationsForUser(_userId);
  }

  Future<int> getUserEngagementScore() async {
    if (_notificationManager == null) return 50;
    return await _notificationManager!.getUserEngagementScore(_userId);
  }
}

// Provider for notification preferences state
final notificationProvider = StateNotifierProvider<NotificationNotifier, AsyncValue<NotificationPreferences>>((ref) {
  // In a real app, you'd get the current user ID from a user provider
  const userId = 'current_user_id'; // This should come from user state
  
  // We'll handle the async initialization in the notifier itself
  final notificationService = ref.watch(notificationServiceProvider);
  
  // Create a placeholder notifier that will initialize properly
  return NotificationNotifier._placeholder(notificationService, userId, ref);
});

// Provider for user notifications list
final userNotificationsProvider = FutureProvider<List<Notification>>((ref) async {
  final notificationManager = await ref.watch(notificationManagerProvider.future);
  const userId = 'current_user_id'; // This should come from user state
  
  return await notificationManager.getNotifications(userId);
});

// Provider for unread notifications count
final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final notificationManager = await ref.watch(notificationManagerProvider.future);
  const userId = 'current_user_id'; // This should come from user state
  
  final unreadNotifications = await notificationManager.getUnreadNotifications(userId);
  return unreadNotifications.length;
});

// Provider for notification permission status
final notificationPermissionProvider = FutureProvider<bool>((ref) async {
  final notificationManager = await ref.watch(notificationManagerProvider.future);
  return await notificationManager.areNotificationsEnabled();
});

// Provider for user engagement score
final userEngagementScoreProvider = FutureProvider<int>((ref) async {
  final notificationManager = await ref.watch(notificationManagerProvider.future);
  const userId = 'current_user_id'; // This should come from user state
  
  return await notificationManager.getUserEngagementScore(userId);
});

// Notification actions provider
final notificationActionsProvider = FutureProvider<NotificationActions>((ref) async {
  final notificationManager = await ref.watch(notificationManagerProvider.future);
  const userId = 'current_user_id'; // This should come from user state
  
  return NotificationActions(notificationManager, userId);
});

class NotificationActions {
  final NotificationManager _notificationManager;
  final String _userId;

  NotificationActions(this._notificationManager, this._userId);

  Future<void> markAsRead(String notificationId) async {
    await _notificationManager.markNotificationAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    await _notificationManager.markAllNotificationsAsRead(_userId);
  }

  Future<void> cancelNotification(String notificationId) async {
    await _notificationManager.cancelNotification(notificationId);
  }

  Future<void> scheduleRecoveryNotification({
    required String muscleGroupId,
    required String muscleGroupName,
    required Duration estimatedRecoveryTime,
    required String locale,
  }) async {
    // This would need to be integrated with the muscle group and recovery system
    // For now, it's a placeholder
  }

  Future<void> showPRNotification({
    required String exerciseName,
    required double weight,
    required int reps,
    required String locale,
  }) async {
    await _notificationManager.showPRNotification(
      userId: _userId,
      exerciseName: exerciseName,
      weight: weight,
      reps: reps,
      locale: locale,
    );
  }

  Future<void> showDeloadNotification({
    required String locale,
  }) async {
    await _notificationManager.showDeloadNotification(
      userId: _userId,
      locale: locale,
    );
  }

  Future<void> showAvatarLevelUpNotification({
    required String muscleGroupName,
    required int newLevel,
    required String locale,
  }) async {
    await _notificationManager.showAvatarLevelUpNotification(
      userId: _userId,
      muscleGroupName: muscleGroupName,
      newLevel: newLevel,
      locale: locale,
    );
  }

  Future<void> showStreakMilestoneNotification({
    required int streakDays,
    required String locale,
  }) async {
    await _notificationManager.showStreakMilestoneNotification(
      userId: _userId,
      streakDays: streakDays,
      locale: locale,
    );
  }

  Future<void> showWeeklyHighlightNotification({
    required Map<String, dynamic> weeklyStats,
    required String locale,
  }) async {
    await _notificationManager.showWeeklyHighlightNotification(
      userId: _userId,
      weeklyStats: weeklyStats,
      locale: locale,
    );
  }
}