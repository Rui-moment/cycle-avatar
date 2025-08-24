import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:cycle_avatar/domain/entities/streak_record.dart';
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';
import 'package:cycle_avatar/domain/services/streak_tracking_service.dart';
import 'package:cycle_avatar/data/repositories/streak_repository.dart';

import 'streak_tracking_service_test.mocks.dart';

@GenerateMocks([StreakRepository])
void main() {
  late StreakTrackingService streakTrackingService;
  late MockStreakRepository mockStreakRepository;

  setUp(() {
    mockStreakRepository = MockStreakRepository();
    streakTrackingService = StreakTrackingService(mockStreakRepository);
  });

  group('StreakTrackingService', () {
    group('updateStreaksWithWorkout', () {
      test('should update workout streak and specific streak type', () async {
        // Arrange
        const userId = 'user123';
        final session = WorkoutSession(
          id: 'session1',
          userId: userId,
          startTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
          sets: [],
        );

        final workoutStreak = StreakRecord(
          id: 'streak1',
          userId: userId,
          streakType: StreakType.workout,
          currentStreak: 5,
          longestStreak: 10,
          lastWorkoutDate: session.startTime,
          streakStartDate: session.startTime.subtract(const Duration(days: 4)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final strengthStreak = StreakRecord(
          id: 'streak2',
          userId: userId,
          streakType: StreakType.strength,
          currentStreak: 3,
          longestStreak: 8,
          lastWorkoutDate: session.startTime,
          streakStartDate: session.startTime.subtract(const Duration(days: 2)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockStreakRepository.updateStreakWithWorkout(
          userId,
          StreakType.workout,
          session.startTime,
        )).thenAnswer((_) async => workoutStreak);

        when(mockStreakRepository.updateStreakWithWorkout(
          userId,
          StreakType.strength,
          session.startTime,
        )).thenAnswer((_) async => strengthStreak);

        // Act
        final result = await streakTrackingService.updateStreaksWithWorkout(
          userId: userId,
          session: session,
        );

        // Assert
        expect(result, hasLength(2));
        expect(result[0].streakType, equals(StreakType.workout));
        expect(result[1].streakType, equals(StreakType.strength));
        
        verify(mockStreakRepository.updateStreakWithWorkout(
          userId,
          StreakType.workout,
          session.startTime,
        )).called(1);
        
        verify(mockStreakRepository.updateStreakWithWorkout(
          userId,
          StreakType.strength,
          session.startTime,
        )).called(1);
      });

      test('should only update workout streak for custom session type', () async {
        // Arrange
        const userId = 'user123';
        final session = WorkoutSession(
          id: 'session1',
          userId: userId,
          startTime: DateTime.now(),
          sessionType: SessionType.custom,
          createdAt: DateTime.now(),
          sets: [],
        );

        final workoutStreak = StreakRecord(
          id: 'streak1',
          userId: userId,
          streakType: StreakType.workout,
          currentStreak: 5,
          longestStreak: 10,
          lastWorkoutDate: session.startTime,
          streakStartDate: session.startTime.subtract(const Duration(days: 4)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockStreakRepository.updateStreakWithWorkout(
          userId,
          StreakType.workout,
          session.startTime,
        )).thenAnswer((_) async => workoutStreak);

        // Act
        final result = await streakTrackingService.updateStreaksWithWorkout(
          userId: userId,
          session: session,
        );

        // Assert
        expect(result, hasLength(1));
        expect(result[0].streakType, equals(StreakType.workout));
        
        verify(mockStreakRepository.updateStreakWithWorkout(
          userId,
          StreakType.workout,
          session.startTime,
        )).called(1);
        
        // Should not update any specific streak type
        verifyNever(mockStreakRepository.updateStreakWithWorkout(
          userId,
          StreakType.strength,
          session.startTime,
        ));
        verifyNever(mockStreakRepository.updateStreakWithWorkout(
          userId,
          StreakType.cardio,
          session.startTime,
        ));
      });

      test('should update cardio streak for cardio session', () async {
        // Arrange
        const userId = 'user123';
        final session = WorkoutSession(
          id: 'session1',
          userId: userId,
          startTime: DateTime.now(),
          sessionType: SessionType.cardio,
          createdAt: DateTime.now(),
          sets: [],
        );

        final workoutStreak = StreakRecord(
          id: 'streak1',
          userId: userId,
          streakType: StreakType.workout,
          currentStreak: 5,
          longestStreak: 10,
          lastWorkoutDate: session.startTime,
          streakStartDate: session.startTime.subtract(const Duration(days: 4)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final cardioStreak = StreakRecord(
          id: 'streak2',
          userId: userId,
          streakType: StreakType.cardio,
          currentStreak: 2,
          longestStreak: 5,
          lastWorkoutDate: session.startTime,
          streakStartDate: session.startTime.subtract(const Duration(days: 1)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockStreakRepository.updateStreakWithWorkout(
          userId,
          StreakType.workout,
          session.startTime,
        )).thenAnswer((_) async => workoutStreak);

        when(mockStreakRepository.updateStreakWithWorkout(
          userId,
          StreakType.cardio,
          session.startTime,
        )).thenAnswer((_) async => cardioStreak);

        // Act
        final result = await streakTrackingService.updateStreaksWithWorkout(
          userId: userId,
          session: session,
        );

        // Assert
        expect(result, hasLength(2));
        expect(result[0].streakType, equals(StreakType.workout));
        expect(result[1].streakType, equals(StreakType.cardio));
      });
    });

    group('getActiveStreaks', () {
      test('should check for broken streaks and return active ones', () async {
        // Arrange
        const userId = 'user123';
        final activeStreaks = [
          StreakRecord(
            id: 'streak1',
            userId: userId,
            streakType: StreakType.workout,
            currentStreak: 5,
            longestStreak: 10,
            lastWorkoutDate: DateTime.now().subtract(const Duration(hours: 12)),
            streakStartDate: DateTime.now().subtract(const Duration(days: 4)),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          StreakRecord(
            id: 'streak2',
            userId: userId,
            streakType: StreakType.strength,
            currentStreak: 3,
            longestStreak: 8,
            lastWorkoutDate: DateTime.now().subtract(const Duration(hours: 6)),
            streakStartDate: DateTime.now().subtract(const Duration(days: 2)),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(mockStreakRepository.checkAndUpdateBrokenStreaks(userId))
            .thenAnswer((_) async => []);
        when(mockStreakRepository.getActiveStreaks(userId))
            .thenAnswer((_) async => activeStreaks);

        // Act
        final result = await streakTrackingService.getActiveStreaks(userId);

        // Assert
        expect(result, equals(activeStreaks));
        verify(mockStreakRepository.checkAndUpdateBrokenStreaks(userId)).called(1);
        verify(mockStreakRepository.getActiveStreaks(userId)).called(1);
      });
    });

    group('getStreakStats', () {
      test('should return comprehensive streak statistics', () async {
        // Arrange
        const userId = 'user123';
        final basicStats = {
          'total_streaks': 3,
          'active_streaks': 2,
          'max_longest_streak': 15,
          'avg_longest_streak': 8.5,
          'total_current_streak_days': 8,
          'total_milestones': 5,
        };

        final activeStreaks = [
          StreakRecord(
            id: 'streak1',
            userId: userId,
            streakType: StreakType.workout,
            currentStreak: 5,
            longestStreak: 10,
            lastWorkoutDate: DateTime.now().subtract(const Duration(hours: 12)),
            streakStartDate: DateTime.now().subtract(const Duration(days: 4)),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final recentMilestones = [
          StreakMilestone(
            id: 'milestone1',
            streakCount: 7,
            achievedAt: DateTime.now().subtract(const Duration(days: 2)),
            milestoneType: MilestoneType.weekly,
          ),
        ];

        when(mockStreakRepository.getStreakStats(userId))
            .thenAnswer((_) async => basicStats);
        when(mockStreakRepository.checkAndUpdateBrokenStreaks(userId))
            .thenAnswer((_) async => []);
        when(mockStreakRepository.getActiveStreaks(userId))
            .thenAnswer((_) async => activeStreaks);
        when(mockStreakRepository.getRecentMilestones(userId, limit: 5))
            .thenAnswer((_) async => recentMilestones);

        // Act
        final result = await streakTrackingService.getStreakStats(userId);

        // Assert
        expect(result['total_streaks'], equals(3));
        expect(result['active_streaks'], equals(2));
        expect(result['active_streak_details'], isA<List>());
        expect(result['recent_milestones'], isA<List>());
        
        final activeStreakDetails = result['active_streak_details'] as List;
        expect(activeStreakDetails, hasLength(1));
        expect(activeStreakDetails[0]['type'], equals('workout'));
        expect(activeStreakDetails[0]['current_streak'], equals(5));
      });
    });

    group('checkForNewMilestones', () {
      test('should return recent milestones from active streaks', () async {
        // Arrange
        const userId = 'user123';
        final recentMilestone = StreakMilestone(
          id: 'milestone1',
          streakCount: 7,
          achievedAt: DateTime.now().subtract(const Duration(hours: 12)),
          milestoneType: MilestoneType.weekly,
        );

        final activeStreaks = [
          StreakRecord(
            id: 'streak1',
            userId: userId,
            streakType: StreakType.workout,
            currentStreak: 7,
            longestStreak: 10,
            lastWorkoutDate: DateTime.now().subtract(const Duration(hours: 12)),
            streakStartDate: DateTime.now().subtract(const Duration(days: 6)),
            milestones: [recentMilestone],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(mockStreakRepository.checkAndUpdateBrokenStreaks(userId))
            .thenAnswer((_) async => []);
        when(mockStreakRepository.getActiveStreaks(userId))
            .thenAnswer((_) async => activeStreaks);

        // Act
        final result = await streakTrackingService.checkForNewMilestones(userId);

        // Assert
        expect(result, hasLength(1));
        expect(result[0].streakCount, equals(7));
        expect(result[0].milestoneType, equals(MilestoneType.weekly));
      });

      test('should return empty list when no recent milestones', () async {
        // Arrange
        const userId = 'user123';
        final oldMilestone = StreakMilestone(
          id: 'milestone1',
          streakCount: 7,
          achievedAt: DateTime.now().subtract(const Duration(days: 2)),
          milestoneType: MilestoneType.weekly,
        );

        final activeStreaks = [
          StreakRecord(
            id: 'streak1',
            userId: userId,
            streakType: StreakType.workout,
            currentStreak: 7,
            longestStreak: 10,
            lastWorkoutDate: DateTime.now().subtract(const Duration(hours: 12)),
            streakStartDate: DateTime.now().subtract(const Duration(days: 6)),
            milestones: [oldMilestone],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(mockStreakRepository.checkAndUpdateBrokenStreaks(userId))
            .thenAnswer((_) async => []);
        when(mockStreakRepository.getActiveStreaks(userId))
            .thenAnswer((_) async => activeStreaks);

        // Act
        final result = await streakTrackingService.checkForNewMilestones(userId);

        // Assert
        expect(result, isEmpty);
      });
    });

    group('getStreakMotivationData', () {
      test('should return comprehensive motivation data', () async {
        // Arrange
        const userId = 'user123';
        final activeStreaks = [
          StreakRecord(
            id: 'streak1',
            userId: userId,
            streakType: StreakType.workout,
            currentStreak: 15,
            longestStreak: 20,
            lastWorkoutDate: DateTime.now().subtract(const Duration(hours: 12)),
            streakStartDate: DateTime.now().subtract(const Duration(days: 14)),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          StreakRecord(
            id: 'streak2',
            userId: userId,
            streakType: StreakType.strength,
            currentStreak: 8,
            longestStreak: 12,
            lastWorkoutDate: DateTime.now().subtract(const Duration(hours: 6)),
            streakStartDate: DateTime.now().subtract(const Duration(days: 7)),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final recentMilestones = [
          StreakMilestone(
            id: 'milestone1',
            streakCount: 14,
            achievedAt: DateTime.now().subtract(const Duration(days: 1)),
            milestoneType: MilestoneType.monthly,
          ),
        ];

        when(mockStreakRepository.checkAndUpdateBrokenStreaks(userId))
            .thenAnswer((_) async => []);
        when(mockStreakRepository.getActiveStreaks(userId))
            .thenAnswer((_) async => activeStreaks);
        when(mockStreakRepository.getRecentMilestones(userId, limit: 3))
            .thenAnswer((_) async => recentMilestones);

        // Act
        final result = await streakTrackingService.getStreakMotivationData(userId);

        // Assert
        expect(result['best_streak'], isNotNull);
        expect(result['best_streak']['current_streak'], equals(15));
        expect(result['best_streak']['type'], equals('workout'));
        expect(result['streak_health'], greaterThan(0));
        expect(result['recent_milestones'], hasLength(1));
        expect(result['total_active_streaks'], equals(2));
        expect(result['motivation_level'], equals('Strong')); // 15 days
      });
    });

    group('getStreakVisualizationData', () {
      test('should return visualization data for existing streak', () async {
        // Arrange
        const userId = 'user123';
        const streakType = StreakType.workout;
        final now = DateTime.now();
        
        final milestone = StreakMilestone(
          id: 'milestone1',
          streakCount: 7,
          achievedAt: now.subtract(const Duration(days: 3)),
          milestoneType: MilestoneType.weekly,
        );

        final streak = StreakRecord(
          id: 'streak1',
          userId: userId,
          streakType: streakType,
          currentStreak: 10,
          longestStreak: 15,
          lastWorkoutDate: now.subtract(const Duration(hours: 12)),
          streakStartDate: now.subtract(const Duration(days: 9)),
          milestones: [milestone],
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: now,
        );

        when(mockStreakRepository.findByUserAndType(userId, streakType))
            .thenAnswer((_) async => streak);

        // Act
        final result = await streakTrackingService.getStreakVisualizationData(
          userId,
          streakType,
          days: 30,
        );

        // Assert
        expect(result['streak_data'], isA<List>());
        expect(result['milestones'], isA<List>());
        expect(result['current_streak'], equals(10));
        expect(result['longest_streak'], equals(15));
        expect(result['streak_type'], equals('workout'));
        
        final streakData = result['streak_data'] as List;
        expect(streakData, hasLength(30));
        
        final milestones = result['milestones'] as List;
        expect(milestones, hasLength(1));
        expect(milestones[0]['streak_count'], equals(7));
      });

      test('should return empty data for non-existent streak', () async {
        // Arrange
        const userId = 'user123';
        const streakType = StreakType.workout;

        when(mockStreakRepository.findByUserAndType(userId, streakType))
            .thenAnswer((_) async => null);

        // Act
        final result = await streakTrackingService.getStreakVisualizationData(
          userId,
          streakType,
        );

        // Assert
        expect(result['streak_data'], isEmpty);
        expect(result['milestones'], isEmpty);
        expect(result['current_streak'], equals(0));
        expect(result['longest_streak'], equals(0));
      });
    });
  });
}