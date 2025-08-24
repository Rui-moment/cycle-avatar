import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:cycle_avatar/data/services/data_export_service.dart';
import 'package:cycle_avatar/data/services/data_deletion_service.dart';
import 'package:cycle_avatar/data/repositories/user_repository.dart';
import 'package:cycle_avatar/data/repositories/workout_repository.dart';
import 'package:cycle_avatar/data/repositories/exercise_repository.dart';
import 'package:cycle_avatar/data/repositories/pr_repository.dart';
import 'package:cycle_avatar/data/repositories/template_repository.dart';
import 'package:cycle_avatar/data/repositories/notification_repository.dart';
import 'package:cycle_avatar/data/repositories/streak_repository.dart';
import 'package:cycle_avatar/data/repositories/notification_preferences_repository.dart';
import 'package:cycle_avatar/data/datasources/local/database_helper.dart';
import 'package:cycle_avatar/domain/entities/user.dart';
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/pr_record.dart';

import 'data_export_deletion_test.mocks.dart';

@GenerateMocks([
  UserRepository,
  WorkoutSessionRepository,
  ExerciseRepository,
  PRRepository,
  TemplateRepository,
  NotificationRepository,
  StreakRepository,
  NotificationPreferencesRepository,
  DatabaseHelper,
])
void main() {
  group('DataExportService', () {
    late DataExportService exportService;
    late MockUserRepository mockUserRepository;
    late MockWorkoutSessionRepository mockWorkoutRepository;
    late MockExerciseRepository mockExerciseRepository;
    late MockPRRepository mockPRRepository;
    late MockTemplateRepository mockTemplateRepository;
    late MockNotificationRepository mockNotificationRepository;
    late MockStreakRepository mockStreakRepository;

    setUp(() {
      mockUserRepository = MockUserRepository();
      mockWorkoutRepository = MockWorkoutSessionRepository();
      mockExerciseRepository = MockExerciseRepository();
      mockPRRepository = MockPRRepository();
      mockTemplateRepository = MockTemplateRepository();
      mockNotificationRepository = MockNotificationRepository();
      mockStreakRepository = MockStreakRepository();

      exportService = DataExportService(
        userRepository: mockUserRepository,
        workoutRepository: mockWorkoutRepository,
        exerciseRepository: mockExerciseRepository,
        prRepository: mockPRRepository,
        templateRepository: mockTemplateRepository,
        notificationRepository: mockNotificationRepository,
        streakRepository: mockStreakRepository,
      );
    });

    test('should export user data successfully', () async {
      // Arrange
      const userId = 'test_user_123';
      final testUser = User(
        id: userId,
        email: 'test@example.com',
        displayName: 'Test User',
        createdAt: DateTime.now(),
      );

      when(mockUserRepository.findById(userId))
          .thenAnswer((_) async => testUser);
      when(mockWorkoutRepository.findByUserId(userId))
          .thenAnswer((_) async => <WorkoutSession>[]);
      when(mockPRRepository.findByUserId(userId))
          .thenAnswer((_) async => <PRRecord>[]);
      when(mockTemplateRepository.findByUserId(userId))
          .thenAnswer((_) async => []);
      when(mockNotificationRepository.findByUserId(userId))
          .thenAnswer((_) async => []);
      when(mockStreakRepository.findByUserId(userId))
          .thenAnswer((_) async => []);

      // Act
      final result = await exportService.exportUserData(userId);

      // Assert
      expect(result.success, isTrue);
      expect(result.filePath, isNotNull);
      expect(result.recordCount, equals(1)); // Just the user record
      
      verify(mockUserRepository.findById(userId)).called(1);
      verify(mockWorkoutRepository.findByUserId(userId)).called(1);
    });

    test('should handle user not found error', () async {
      // Arrange
      const userId = 'nonexistent_user';
      
      when(mockUserRepository.findById(userId))
          .thenAnswer((_) async => null);

      // Act
      final result = await exportService.exportUserData(userId);

      // Assert
      expect(result.success, isFalse);
      expect(result.error, contains('User not found'));
    });

    test('should calculate data size info correctly', () async {
      // Arrange
      const userId = 'test_user_123';
      final testUser = User(
        id: userId,
        email: 'test@example.com',
        displayName: 'Test User',
        createdAt: DateTime.now(),
      );

      when(mockUserRepository.findById(userId))
          .thenAnswer((_) async => testUser);
      when(mockWorkoutRepository.findByUserId(userId))
          .thenAnswer((_) async => <WorkoutSession>[]);
      when(mockPRRepository.findByUserId(userId))
          .thenAnswer((_) async => <PRRecord>[]);
      when(mockTemplateRepository.findByUserId(userId))
          .thenAnswer((_) async => []);
      when(mockNotificationRepository.findByUserId(userId))
          .thenAnswer((_) async => []);
      when(mockStreakRepository.findByUserId(userId))
          .thenAnswer((_) async => []);

      // Act
      final sizeInfo = await exportService.getUserDataSize(userId);

      // Assert
      expect(sizeInfo.totalRecords, equals(1));
      expect(sizeInfo.workoutSessions, equals(0));
      expect(sizeInfo.prRecords, equals(0));
      expect(sizeInfo.approximateSize, greaterThan(0));
    });
  });

  group('DataDeletionService', () {
    late DataDeletionService deletionService;
    late MockUserRepository mockUserRepository;
    late MockWorkoutSessionRepository mockWorkoutRepository;
    late MockExerciseRepository mockExerciseRepository;
    late MockPRRepository mockPRRepository;
    late MockTemplateRepository mockTemplateRepository;
    late MockNotificationRepository mockNotificationRepository;
    late MockStreakRepository mockStreakRepository;
    late MockNotificationPreferencesRepository mockNotificationPreferencesRepository;
    late MockDatabaseHelper mockDatabaseHelper;

    setUp(() {
      mockUserRepository = MockUserRepository();
      mockWorkoutRepository = MockWorkoutSessionRepository();
      mockExerciseRepository = MockExerciseRepository();
      mockPRRepository = MockPRRepository();
      mockTemplateRepository = MockTemplateRepository();
      mockNotificationRepository = MockNotificationRepository();
      mockStreakRepository = MockStreakRepository();
      mockNotificationPreferencesRepository = MockNotificationPreferencesRepository();
      mockDatabaseHelper = MockDatabaseHelper();

      deletionService = DataDeletionService(
        userRepository: mockUserRepository,
        workoutRepository: mockWorkoutRepository,
        exerciseRepository: mockExerciseRepository,
        prRepository: mockPRRepository,
        templateRepository: mockTemplateRepository,
        notificationRepository: mockNotificationRepository,
        streakRepository: mockStreakRepository,
        notificationPreferencesRepository: mockNotificationPreferencesRepository,
        databaseHelper: mockDatabaseHelper,
      );
    });

    test('should delete local user data successfully', () async {
      // Arrange
      const userId = 'test_user_123';
      final testUser = User(
        id: userId,
        email: 'test@example.com',
        displayName: 'Test User',
        createdAt: DateTime.now(),
      );

      when(mockUserRepository.findById(userId))
          .thenAnswer((_) async => testUser);
      when(mockWorkoutRepository.findByUserId(userId))
          .thenAnswer((_) async => <WorkoutSession>[]);
      when(mockPRRepository.findByUserId(userId))
          .thenAnswer((_) async => <PRRecord>[]);
      when(mockTemplateRepository.findByUserId(userId))
          .thenAnswer((_) async => []);
      when(mockNotificationRepository.findByUserId(userId))
          .thenAnswer((_) async => []);
      when(mockStreakRepository.findByUserId(userId))
          .thenAnswer((_) async => []);
      when(mockNotificationPreferencesRepository.findByUserId(userId))
          .thenAnswer((_) async => null);
      when(mockUserRepository.deleteById(userId))
          .thenAnswer((_) async => true);

      // Act
      final result = await deletionService.deleteLocalUserData(userId);

      // Assert
      expect(result.success, isTrue);
      expect(result.deletedRecords, equals(1)); // Just the user record
      expect(result.deletionType, equals(DeletionType.local));
      
      verify(mockUserRepository.findById(userId)).called(1);
      verify(mockUserRepository.deleteById(userId)).called(1);
    });

    test('should handle user not found error during deletion', () async {
      // Arrange
      const userId = 'nonexistent_user';
      
      when(mockUserRepository.findById(userId))
          .thenAnswer((_) async => null);

      // Act
      final result = await deletionService.deleteLocalUserData(userId);

      // Assert
      expect(result.success, isFalse);
      expect(result.error, contains('User not found'));
    });

    test('should get deletion info correctly', () async {
      // Arrange
      const userId = 'test_user_123';
      final testUser = User(
        id: userId,
        email: 'test@example.com',
        displayName: 'Test User',
        createdAt: DateTime.now(),
      );

      when(mockUserRepository.findById(userId))
          .thenAnswer((_) async => testUser);
      when(mockWorkoutRepository.findByUserId(userId))
          .thenAnswer((_) async => <WorkoutSession>[]);
      when(mockPRRepository.findByUserId(userId))
          .thenAnswer((_) async => <PRRecord>[]);
      when(mockTemplateRepository.findByUserId(userId))
          .thenAnswer((_) async => []);
      when(mockNotificationRepository.findByUserId(userId))
          .thenAnswer((_) async => []);
      when(mockStreakRepository.findByUserId(userId))
          .thenAnswer((_) async => []);

      // Act
      final deletionInfo = await deletionService.getDeletionInfo(userId);

      // Assert
      expect(deletionInfo.totalRecords, equals(1));
      expect(deletionInfo.details['User Profile'], equals(1));
      expect(deletionInfo.estimatedTime, isA<Duration>());
    });

    test('should request server data deletion', () async {
      // Arrange
      const userId = 'test_user_123';

      // Act
      final result = await deletionService.requestServerDataDeletion(userId);

      // Assert
      expect(result.success, isTrue);
      expect(result.deletionType, equals(DeletionType.server));
      expect(result.message, isNotNull);
      expect(result.message, contains('confirmation email'));
    });
  });
}