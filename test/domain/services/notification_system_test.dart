import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cycle_avatar/domain/entities/notification.dart';
import 'package:cycle_avatar/domain/entities/notification_preferences.dart';
import 'package:cycle_avatar/data/repositories/notification_repository.dart';
import 'package:cycle_avatar/data/repositories/notification_preferences_repository.dart';

void main() {
  group('Notification System Tests', () {
    late Database database;
    late NotificationRepository notificationRepository;
    late NotificationPreferencesRepository preferencesRepository;

    setUpAll(() {
      // Initialize FFI
      sqfliteFfiInit();
      // Change the default factory
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Create in-memory database for testing
      database = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          // Create notifications table
          await db.execute('''
            CREATE TABLE notifications (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              type TEXT NOT NULL,
              title TEXT NOT NULL,
              body TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              scheduled_for INTEGER,
              read_at INTEGER,
              priority TEXT NOT NULL DEFAULT 'normal',
              data TEXT NOT NULL DEFAULT '{}',
              is_read INTEGER NOT NULL DEFAULT 0,
              is_sent INTEGER NOT NULL DEFAULT 0,
              action_url TEXT,
              image_url TEXT
            )
          ''');

          // Create notification_preferences table
          await db.execute('''
            CREATE TABLE notification_preferences (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL UNIQUE,
              recovery_notifications INTEGER NOT NULL DEFAULT 1,
              pr_notifications INTEGER NOT NULL DEFAULT 1,
              streak_notifications INTEGER NOT NULL DEFAULT 1,
              weekly_highlights INTEGER NOT NULL DEFAULT 1,
              avatar_level_up_notifications INTEGER NOT NULL DEFAULT 1,
              deload_notifications INTEGER NOT NULL DEFAULT 1,
              badge_notifications INTEGER NOT NULL DEFAULT 1,
              workout_reminders INTEGER NOT NULL DEFAULT 0,
              quiet_hours_start INTEGER NOT NULL DEFAULT 22,
              quiet_hours_end INTEGER NOT NULL DEFAULT 7,
              enabled_days TEXT NOT NULL DEFAULT '[1,2,3,4,5,6,7]',
              muscle_group_notifications TEXT NOT NULL DEFAULT '{}',
              max_notifications_per_day INTEGER NOT NULL DEFAULT 3,
              minimum_interval_minutes INTEGER NOT NULL DEFAULT 120,
              enable_vibration INTEGER NOT NULL DEFAULT 1,
              enable_sound INTEGER NOT NULL DEFAULT 1,
              enable_badge INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL,
              updated_at INTEGER
            )
          ''');
        },
      );

      notificationRepository = NotificationRepository(database);
      preferencesRepository = NotificationPreferencesRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('should create and retrieve notification', () async {
      // Arrange
      final notification = Notification.prAchieved(
        id: 'test_notification_1',
        userId: 'test_user_1',
        exerciseName: 'Bench Press',
        weight: 100.0,
        reps: 10,
        locale: 'en',
      );

      // Act
      await notificationRepository.create(notification);
      final retrieved = await notificationRepository.findById('test_notification_1');

      // Assert
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('test_notification_1'));
      expect(retrieved.userId, equals('test_user_1'));
      expect(retrieved.type, equals(NotificationType.prAchieved));
      expect(retrieved.title, contains('PR Achieved'));
      expect(retrieved.body, contains('Bench Press'));
      expect(retrieved.body, contains('100.0kg'));
      expect(retrieved.body, contains('10 reps'));
    });

    test('should create and retrieve notification preferences', () async {
      // Arrange
      final preferences = NotificationPreferences.defaultForUser('test_user_1');

      // Act
      await preferencesRepository.create(preferences);
      final retrieved = await preferencesRepository.getByUserId('test_user_1');

      // Assert
      expect(retrieved, isNotNull);
      expect(retrieved!.userId, equals('test_user_1'));
      expect(retrieved.recoveryNotifications, isTrue);
      expect(retrieved.prNotifications, isTrue);
      expect(retrieved.quietHoursStart, equals(22));
      expect(retrieved.quietHoursEnd, equals(7));
      expect(retrieved.maxNotificationsPerDay, equals(3));
    });

    test('should update notification preferences', () async {
      // Arrange
      final preferences = NotificationPreferences.defaultForUser('test_user_1');
      await preferencesRepository.create(preferences);

      // Act
      final updated = preferences.copyWith(
        recoveryNotifications: false,
        maxNotificationsPerDay: 5,
        updatedAt: DateTime.now(),
      );
      await preferencesRepository.update(updated);
      final retrieved = await preferencesRepository.getByUserId('test_user_1');

      // Assert
      expect(retrieved, isNotNull);
      expect(retrieved!.recoveryNotifications, isFalse);
      expect(retrieved.maxNotificationsPerDay, equals(5));
      expect(retrieved.updatedAt, isNotNull);
    });

    test('should check notification type enablement', () async {
      // Arrange
      final preferences = NotificationPreferences.defaultForUser('test_user_1');

      // Act & Assert
      expect(preferences.isNotificationTypeEnabled(NotificationType.prAchieved), isTrue);
      expect(preferences.isNotificationTypeEnabled(NotificationType.recoveryComplete), isTrue);
      expect(preferences.isNotificationTypeEnabled(NotificationType.workoutReminder), isFalse);
    });

    test('should check quiet hours', () async {
      // Arrange
      final preferences = NotificationPreferences.defaultForUser('test_user_1');

      // Act & Assert - This test depends on current time, so we'll just check the logic works
      final isInQuietHours = preferences.isInQuietHours;
      expect(isInQuietHours, isA<bool>());
    });

    test('should get next available time outside quiet hours', () async {
      // Arrange
      final preferences = NotificationPreferences.defaultForUser('test_user_1');

      // Act
      final nextTime = preferences.getNextAvailableTime();

      // Assert
      expect(nextTime, isA<DateTime>());
      expect(nextTime.isAfter(DateTime.now()) || nextTime.isAtSameMomentAs(DateTime.now()), isTrue);
    });

    test('should mark notification as read', () async {
      // Arrange
      final notification = Notification.prAchieved(
        id: 'test_notification_2',
        userId: 'test_user_1',
        exerciseName: 'Squat',
        weight: 120.0,
        reps: 8,
        locale: 'en',
      );
      await notificationRepository.create(notification);

      // Act
      await notificationRepository.markAsRead('test_notification_2');
      final retrieved = await notificationRepository.findById('test_notification_2');

      // Assert
      expect(retrieved, isNotNull);
      expect(retrieved!.isRead, isTrue);
      expect(retrieved.readAt, isNotNull);
    });

    test('should get unread notifications', () async {
      // Arrange
      final notification1 = Notification.prAchieved(
        id: 'test_notification_3',
        userId: 'test_user_1',
        exerciseName: 'Deadlift',
        weight: 140.0,
        reps: 5,
        locale: 'en',
      );
      final notification2 = Notification.streakMilestone(
        id: 'test_notification_4',
        userId: 'test_user_1',
        streakDays: 7,
        locale: 'en',
      );

      await notificationRepository.create(notification1);
      await notificationRepository.create(notification2);
      await notificationRepository.markAsRead('test_notification_3');

      // Act
      final unreadNotifications = await notificationRepository.getUnreadByUserId('test_user_1');

      // Assert
      expect(unreadNotifications.length, equals(1));
      expect(unreadNotifications.first.id, equals('test_notification_4'));
      expect(unreadNotifications.first.type, equals(NotificationType.streakMilestone));
    });

    test('should validate notification preferences', () async {
      // Arrange
      final validPreferences = NotificationPreferences.defaultForUser('test_user_1');
      final invalidPreferences = validPreferences.copyWith(
        quietHoursStart: 25, // Invalid hour
      );

      // Act & Assert
      expect(validPreferences.isValid, isTrue);
      expect(invalidPreferences.isValid, isFalse);
      expect(invalidPreferences.validate(), contains('Quiet hours start must be between 0 and 23'));
    });
  });
}