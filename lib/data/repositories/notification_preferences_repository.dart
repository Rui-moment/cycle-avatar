import 'dart:async';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:logger/logger.dart';

import '../../domain/entities/notification_preferences.dart';
import '../datasources/local/database_helper.dart';
import 'base_repository.dart';

/// Repository interface for NotificationPreferences operations
abstract class NotificationPreferencesRepository extends BaseRepository<NotificationPreferences, String> {
  /// Find notification preferences by user ID
  Future<NotificationPreferences?> findByUserId(String userId);
  
  /// Create default preferences for a user
  Future<NotificationPreferences> createDefaultForUser(String userId);
  
  /// Update specific notification type setting
  Future<void> updateNotificationTypeSetting(
    String userId,
    String notificationType,
    bool enabled,
  );
  
  /// Update quiet hours
  Future<void> updateQuietHours(
    String userId,
    int startHour,
    int startMinute,
    int endHour,
    int endMinute,
  );
  
  /// Update enabled days
  Future<void> updateEnabledDays(String userId, List<int> enabledDays);
}

/// Implementation of NotificationPreferencesRepository using SQLite
class NotificationPreferencesRepositoryImpl extends BaseRepositoryImpl<NotificationPreferences, String> 
    with RepositoryErrorHandling 
    implements NotificationPreferencesRepository {
  
  final DatabaseHelper _databaseHelper;
  final Logger _logger = Logger();
  
  NotificationPreferencesRepositoryImpl(this._databaseHelper);
  
  @override
  String get tableName => 'notification_preferences';
  
  @override
  Future<Database> get database => _databaseHelper.database;
  
  @override
  Map<String, dynamic> toMap(NotificationPreferences preferences) {
    return {
      'id': preferences.id,
      'user_id': preferences.userId,
      'recovery_notifications': preferences.recoveryNotifications ? 1 : 0,
      'pr_notifications': preferences.prNotifications ? 1 : 0,
      'streak_notifications': preferences.streakNotifications ? 1 : 0,
      'weekly_highlights': preferences.weeklyHighlights ? 1 : 0,
      'avatar_level_up': preferences.avatarLevelUpNotifications ? 1 : 0,
      'deload_recommendations': preferences.deloadNotifications ? 1 : 0,
      'badge_notifications': preferences.badgeNotifications ? 1 : 0,
      'workout_reminders': preferences.workoutReminders ? 1 : 0,
      'quiet_hours_start_hour': preferences.quietHoursStart,
      'quiet_hours_start_minute': 0,
      'quiet_hours_end_hour': preferences.quietHoursEnd,
      'quiet_hours_end_minute': 0,
      'enabled_days': preferences.enabledDays.join(','),
      'max_notifications_per_day': preferences.maxNotificationsPerDay,
      'minimum_interval_minutes': preferences.minimumInterval.inMinutes,
      'enable_vibration': preferences.enableVibration ? 1 : 0,
      'enable_sound': preferences.enableSound ? 1 : 0,
      'enable_badge': preferences.enableBadge ? 1 : 0,
      'created_at': preferences.createdAt.millisecondsSinceEpoch,
      'updated_at': preferences.updatedAt?.millisecondsSinceEpoch,
    };
  }
  
  @override
  NotificationPreferences fromMap(Map<String, dynamic> map) {
    final enabledDaysString = map['enabled_days'] as String? ?? '1,2,3,4,5,6,7';
    final enabledDays = enabledDaysString.split(',').map((s) => int.parse(s)).toList();
    
    return NotificationPreferences(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      recoveryNotifications: (map['recovery_notifications'] as int) == 1,
      prNotifications: (map['pr_notifications'] as int) == 1,
      streakNotifications: (map['streak_notifications'] as int) == 1,
      weeklyHighlights: (map['weekly_highlights'] as int) == 1,
      avatarLevelUpNotifications: (map['avatar_level_up'] as int) == 1,
      deloadRecommendations: (map['deload_recommendations'] as int) == 1,
      badgeNotifications: (map['badge_notifications'] as int) == 1,
      workoutReminders: (map['workout_reminders'] as int) == 1,
      quietHoursStartHour: map['quiet_hours_start_hour'] as int,
      quietHoursStartMinute: map['quiet_hours_start_minute'] as int,
      quietHoursEndHour: map['quiet_hours_end_hour'] as int,
      quietHoursEndMinute: map['quiet_hours_end_minute'] as int,
      enabledDays: enabledDays,
      maxNotificationsPerDay: map['max_notifications_per_day'] as int,
      minimumIntervalMinutes: map['minimum_interval_minutes'] as int,
      enableVibration: (map['enable_vibration'] as int) == 1,
      enableSound: (map['enable_sound'] as int) == 1,
      enableBadge: (map['enable_badge'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
  
  @override
  String getId(NotificationPreferences preferences) => preferences.id;
  
  @override
  Future<NotificationPreferences> create(NotificationPreferences preferences) async {
    return executeWithErrorHandling(() async {
      // Validate preferences data
      final validation = preferences.validate();
      if (validation != null) {
        throw RepositoryException('Invalid notification preferences data: $validation');
      }
      
      final db = await database;
      await db.insert(tableName, toMap(preferences));
      
      _logger.d('Created notification preferences: ${preferences.id}');
      return preferences;
    }, 'create notification preferences');
  }
  
  @override
  Future<NotificationPreferences?> findById(String id) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      if (maps.isEmpty) return null;
      return fromMap(maps.first);
    }, 'find notification preferences by id');
  }
  
  @override
  Future<List<NotificationPreferences>> findAll() async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(tableName, orderBy: 'updated_at DESC');
      return maps.map((map) => fromMap(map)).toList();
    }, 'find all notification preferences');
  }
  
  @override
  Future<NotificationPreferences> update(NotificationPreferences preferences) async {
    return executeWithErrorHandling(() async {
      // Validate preferences data
      final validation = preferences.validate();
      if (validation != null) {
        throw RepositoryException('Invalid notification preferences data: $validation');
      }
      
      final db = await database;
      final rowsAffected = await db.update(
        tableName,
        toMap(preferences),
        where: 'id = ?',
        whereArgs: [preferences.id],
      );
      
      if (rowsAffected == 0) {
        throw RepositoryException('Notification preferences not found: ${preferences.id}');
      }
      
      _logger.d('Updated notification preferences: ${preferences.id}');
      return preferences;
    }, 'update notification preferences');
  }
  
  @override
  Future<bool> deleteById(String id) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final rowsAffected = await db.delete(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      final deleted = rowsAffected > 0;
      if (deleted) {
        _logger.d('Deleted notification preferences: $id');
      }
      return deleted;
    }, 'delete notification preferences');
  }
  
  @override
  Future<NotificationPreferences?> findByUserId(String userId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      
      if (maps.isEmpty) return null;
      return fromMap(maps.first);
    }, 'find notification preferences by user id');
  }
  
  @override
  Future<NotificationPreferences> createDefaultForUser(String userId) async {
    return executeWithErrorHandling(() async {
      final id = 'notif_pref_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();
      
      final defaultPreferences = NotificationPreferences(
        id: id,
        userId: userId,
        recoveryNotifications: true,
        prNotifications: true,
        streakNotifications: true,
        weeklyHighlights: true,
        avatarLevelUpNotifications: true,
        deloadRecommendations: true,
        badgeNotifications: true,
        workoutReminders: false, // Default to off to avoid spam
        quietHoursStartHour: 22,
        quietHoursStartMinute: 0,
        quietHoursEndHour: 7,
        quietHoursEndMinute: 0,
        enabledDays: [1, 2, 3, 4, 5, 6, 7], // All days
        maxNotificationsPerDay: 5,
        minimumIntervalMinutes: 60,
        enableVibration: true,
        enableSound: true,
        enableBadge: true,
        createdAt: now,
        updatedAt: now,
      );
      
      return await create(defaultPreferences);
    }, 'create default notification preferences');
  }
  
  @override
  Future<void> updateNotificationTypeSetting(
    String userId,
    String notificationType,
    bool enabled,
  ) async {
    return executeWithErrorHandling(() async {
      final preferences = await findByUserId(userId);
      if (preferences == null) {
        throw RepositoryException('Notification preferences not found for user: $userId');
      }
      
      NotificationPreferences updatedPreferences;
      
      switch (notificationType) {
        case 'recovery':
          updatedPreferences = preferences.copyWith(recoveryNotifications: enabled);
          break;
        case 'pr':
          updatedPreferences = preferences.copyWith(prNotifications: enabled);
          break;
        case 'streak':
          updatedPreferences = preferences.copyWith(streakNotifications: enabled);
          break;
        case 'weekly':
          updatedPreferences = preferences.copyWith(weeklyHighlights: enabled);
          break;
        case 'avatar':
          updatedPreferences = preferences.copyWith(avatarLevelUpNotifications: enabled);
          break;
        case 'deload':
          updatedPreferences = preferences.copyWith(deloadNotifications: enabled);
          break;
        case 'badge':
          updatedPreferences = preferences.copyWith(badgeNotifications: enabled);
          break;
        case 'reminder':
          updatedPreferences = preferences.copyWith(workoutReminders: enabled);
          break;
        default:
          throw RepositoryException('Unknown notification type: $notificationType');
      }
      
      await update(updatedPreferences.copyWith(updatedAt: DateTime.now()));
      _logger.d('Updated notification type $notificationType to $enabled for user: $userId');
    }, 'update notification type setting');
  }
  
  @override
  Future<void> updateQuietHours(
    String userId,
    int startHour,
    int startMinute,
    int endHour,
    int endMinute,
  ) async {
    return executeWithErrorHandling(() async {
      final preferences = await findByUserId(userId);
      if (preferences == null) {
        throw RepositoryException('Notification preferences not found for user: $userId');
      }
      
      final updatedPreferences = preferences.copyWith(
        quietHoursStart: startHour,
        quietHoursStartMinute: startMinute,
        quietHoursEndHour: endHour,
        quietHoursEndMinute: endMinute,
        updatedAt: DateTime.now(),
      );
      
      await update(updatedPreferences);
      _logger.d('Updated quiet hours for user: $userId');
    }, 'update quiet hours');
  }
  
  @override
  Future<void> updateEnabledDays(String userId, List<int> enabledDays) async {
    return executeWithErrorHandling(() async {
      final preferences = await findByUserId(userId);
      if (preferences == null) {
        throw RepositoryException('Notification preferences not found for user: $userId');
      }
      
      final updatedPreferences = preferences.copyWith(
        enabledDays: enabledDays,
        updatedAt: DateTime.now(),
      );
      
      await update(updatedPreferences);
      _logger.d('Updated enabled days for user: $userId');
    }, 'update enabled days');
  }
}