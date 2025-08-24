import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:cycle_avatar/domain/entities/weekly_highlight.dart';
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/pr_record.dart';
import 'package:cycle_avatar/domain/entities/streak_record.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';
import 'package:cycle_avatar/domain/services/weekly_highlight_service.dart';
import 'package:cycle_avatar/domain/services/pr_tracking_service.dart';
import 'package:cycle_avatar/domain/services/streak_tracking_service.dart';
import 'package:cycle_avatar/data/repositories/workout_repository.dart';

import 'weekly_highlight_service_test.mocks.dart';

@GenerateMocks([WorkoutSessionRepository, PRTrackingService, StreakTrackingService])
void main() {
  late WeeklyHighlightService weeklyHighlightService;
  late MockWorkoutSessionRepository mockWorkoutRepository;
  late MockPRTrackingService mockPRTrackingService;
  late MockStreakTrackingService mockStreakTrackingService;

  setUp(() {
    mockWorkoutRepository = MockWorkoutSessionRepository();
    mockPRTrackingService = MockPRTrackingService();
    mockStreakTrackingService = MockStreakTrackingService();
    weeklyHighlightService = WeeklyHighlightService(
      mockWorkoutRepository,
      mockPRTrackingService,
      mockStreakTrackingService,
    );
  });

  group('WeeklyHighlightService', () {
    group('generateWeeklyHighlight', () {
      test('should generate complete weekly highlight with all data', () async {
        // Arrange
        const userId = 'user123';
        final weekStartDate = DateTime(2024, 1, 1); // Monday
        final weekEndDate = weekStartDate.add(const Duration(days: 6));
        
        final sessions = [
          WorkoutSession(
            id: 'session1',
            userId: userId,
            startTime: weekStartDate.add(const Duration(days: 1)),
            endTime: weekStartDate.add(const Duration(days: 1, hours: 1)),
            sessionType: SessionType.strength,
            createdAt: weekStartDate.add(const Duration(days: 1)),
            sets: [
              WorkoutSet(
                id: 'set1',
                sessionId: 'session1',
                exerciseId: 'squat',
                weight: 100.0,
                reps: 8,
                rpe: 8,
                setOrder: 1,
                createdAt: weekStartDate.add(const Duration(days: 1)),
              ),
              WorkoutSet(
                id: 'set2',
                sessionId: 'session1',
                exerciseId: 'bench',
                weight: 80.0,
                reps: 10,
                rpe: 7,
                setOrder: 2,
                createdAt: weekStartDate.add(const Duration(days: 1)),
              ),
            ],
          ),
          WorkoutSession(
            id: 'session2',
            userId: userId,
            startTime: weekStartDate.add(const Duration(days: 3)),
            endTime: weekStartDate.add(const Duration(days: 3, hours: 1, minutes: 15)),
            sessionType: SessionType.strength,
            createdAt: weekStartDate.add(const Duration(days: 3)),
            sets: [
              WorkoutSet(
                id: 'set3',
                sessionId: 'session2',
                exerciseId: 'squat',
                weight: 105.0,
                reps: 8,
                rpe: 9,
                setOrder: 1,
                createdAt: weekStartDate.add(const Duration(days: 3)),
              ),
            ],
          ),
        ];

        final newPRs = [
          PRRecord(
            id: 'pr1',
            userId: userId,
            exerciseId: 'squat',
            weight: 105.0,
            reps: 8,
            estimatedMax: 133.0,
            achievedAt: weekStartDate.add(const Duration(days: 3)),
          ),
        ];

        final milestones = [
          StreakMilestone(
            id: 'milestone1',
            streakCount: 7,
            achievedAt: weekStartDate.add(const Duration(days: 2)),
            milestoneType: MilestoneType.weekly,
          ),
        ];

        // Mock repository calls
        when(mockWorkoutRepository.findByUserIdAndDateRange(
          userId,
          weekStartDate,
          weekEndDate.add(const Duration(days: 1)),
        )).thenAnswer((_) async => sessions);

        when(mockPRTrackingService.getPRsInDateRange(
          userId,
          weekStartDate,
          weekEndDate.add(const Duration(days: 1)),
        )).thenAnswer((_) async => newPRs);

        when(mockStreakTrackingService.getAllMilestones(userId))
            .thenAnswer((_) async => milestones);

        // Mock previous week data for trend calculation
        when(mockWorkoutRepository.findByUserIdAndDateRange(
          userId,
          weekStartDate.subtract(const Duration(days: 7)),
          weekStartDate,
        )).thenAnswer((_) async => [
          WorkoutSession(
            id: 'prev_session1',
            userId: userId,
            startTime: weekStartDate.subtract(const Duration(days: 5)),
            endTime: weekStartDate.subtract(const Duration(days: 5)).add(const Duration(hours: 1)),
            sessionType: SessionType.strength,
            createdAt: weekStartDate.subtract(const Duration(days: 5)),
            sets: [
              WorkoutSet(
                id: 'prev_set1',
                sessionId: 'prev_session1',
                exerciseId: 'squat',
                weight: 95.0,
                reps: 8,
                rpe: 7,
                setOrder: 1,
                createdAt: weekStartDate.subtract(const Duration(days: 5)),
              ),
            ],
          ),
        ]);

        // Act
        final result = await weeklyHighlightService.generateWeeklyHighlight(
          userId: userId,
          weekStartDate: weekStartDate,
        );

        // Assert
        expect(result.userId, equals(userId));
        expect(result.weekStartDate, equals(weekStartDate));
        expect(result.weekEndDate, equals(weekEndDate));
        expect(result.stats.totalSessions, equals(2));
        expect(result.stats.totalSets, equals(3));
        expect(result.stats.totalVolume, equals(1645.0)); // 100*8 + 80*10 + 105*8
        expect(result.stats.uniqueExercises, equals(2)); // squat, bench
        expect(result.newPRs, hasLength(1));
        expect(result.milestones, hasLength(1));
        expect(result.motivationalMessage, isNotNull);
        expect(result.keyHighlights, isNotEmpty);
        
        // Verify repository calls
        verify(mockWorkoutRepository.findByUserIdAndDateRange(
          userId,
          weekStartDate,
          weekEndDate.add(const Duration(days: 1)),
        )).called(1);
        
        verify(mockPRTrackingService.getPRsInDateRange(
          userId,
          weekStartDate,
          weekEndDate.add(const Duration(days: 1)),
        )).called(1);
      });

      test('should handle empty week with no sessions', () async {
        // Arrange
        const userId = 'user123';
        final weekStartDate = DateTime(2024, 1, 1);
        final weekEndDate = weekStartDate.add(const Duration(days: 6));

        when(mockWorkoutRepository.findByUserIdAndDateRange(
          userId,
          weekStartDate,
          weekEndDate.add(const Duration(days: 1)),
        )).thenAnswer((_) async => []);

        when(mockPRTrackingService.getPRsInDateRange(
          userId,
          weekStartDate,
          weekEndDate.add(const Duration(days: 1)),
        )).thenAnswer((_) async => []);

        when(mockStreakTrackingService.getAllMilestones(userId))
            .thenAnswer((_) async => []);

        when(mockWorkoutRepository.findByUserIdAndDateRange(
          userId,
          weekStartDate.subtract(const Duration(days: 7)),
          weekStartDate,
        )).thenAnswer((_) async => []);

        // Act
        final result = await weeklyHighlightService.generateWeeklyHighlight(
          userId: userId,
          weekStartDate: weekStartDate,
        );

        // Assert
        expect(result.stats.totalSessions, equals(0));
        expect(result.stats.totalSets, equals(0));
        expect(result.stats.totalVolume, equals(0.0));
        expect(result.stats.uniqueExercises, equals(0));
        expect(result.newPRs, isEmpty);
        expect(result.milestones, isEmpty);
        expect(result.achievements, isEmpty);
        expect(result.performanceRating, equals(PerformanceRating.needsImprovement));
      });
    });

    group('generateCurrentWeekHighlight', () {
      test('should generate highlight for current week', () async {
        // Arrange
        const userId = 'user123';
        
        // Mock empty data for simplicity
        when(mockWorkoutRepository.findByUserIdAndDateRange(
          userId,
          any,
          any,
        )).thenAnswer((_) async => []);

        when(mockPRTrackingService.getPRsInDateRange(
          userId,
          any,
          any,
        )).thenAnswer((_) async => []);

        when(mockStreakTrackingService.getAllMilestones(userId))
            .thenAnswer((_) async => []);

        // Act
        final result = await weeklyHighlightService.generateCurrentWeekHighlight(userId);

        // Assert
        expect(result.userId, equals(userId));
        expect(result.weekStartDate.weekday, equals(1)); // Monday
        
        // Should be current week
        final now = DateTime.now();
        final expectedWeekStart = now.subtract(Duration(days: (now.weekday - 1) % 7));
        expect(result.weekStartDate.day, equals(expectedWeekStart.day));
      });
    });

    group('getWeeklyProgressSummary', () {
      test('should return comprehensive progress summary', () async {
        // Arrange
        const userId = 'user123';
        const weeks = 4;
        
        // Mock data for multiple weeks
        when(mockWorkoutRepository.findByUserIdAndDateRange(
          userId,
          any,
          any,
        )).thenAnswer((_) async => [
          WorkoutSession(
            id: 'session1',
            userId: userId,
            startTime: DateTime.now().subtract(const Duration(days: 1)),
            endTime: DateTime.now().subtract(const Duration(days: 1)).add(const Duration(hours: 1)),
            sessionType: SessionType.strength,
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            sets: [
              WorkoutSet(
                id: 'set1',
                sessionId: 'session1',
                exerciseId: 'squat',
                weight: 100.0,
                reps: 8,
                rpe: 8,
                setOrder: 1,
                createdAt: DateTime.now().subtract(const Duration(days: 1)),
              ),
            ],
          ),
        ]);

        when(mockPRTrackingService.getPRsInDateRange(
          userId,
          any,
          any,
        )).thenAnswer((_) async => []);

        when(mockStreakTrackingService.getAllMilestones(userId))
            .thenAnswer((_) async => []);

        // Act
        final result = await weeklyHighlightService.getWeeklyProgressSummary(
          userId: userId,
          weeks: weeks,
        );

        // Assert
        expect(result['period_weeks'], equals(weeks));
        expect(result['total_sessions'], isA<int>());
        expect(result['total_volume'], isA<double>());
        expect(result['avg_sessions_per_week'], isA<double>());
        expect(result['avg_volume_per_week'], isA<double>());
        expect(result['consistency_score'], isA<double>());
        expect(result['weekly_data'], isA<List>());
      });
    });

    group('WeeklyStats calculations', () {
      test('should calculate correct weekly stats from sessions', () async {
        // Arrange
        const userId = 'user123';
        final weekStartDate = DateTime(2024, 1, 1);
        
        final sessions = [
          WorkoutSession(
            id: 'session1',
            userId: userId,
            startTime: weekStartDate.add(const Duration(days: 1)),
            endTime: weekStartDate.add(const Duration(days: 1, hours: 1)),
            sessionType: SessionType.strength,
            createdAt: weekStartDate.add(const Duration(days: 1)),
            sets: [
              WorkoutSet(
                id: 'set1',
                sessionId: 'session1',
                exerciseId: 'squat',
                weight: 100.0,
                reps: 8,
                rpe: 8,
                restSeconds: 120,
                setOrder: 1,
                createdAt: weekStartDate.add(const Duration(days: 1)),
              ),
              WorkoutSet(
                id: 'set2',
                sessionId: 'session1',
                exerciseId: 'bench',
                weight: 80.0,
                reps: 10,
                rpe: 7,
                restSeconds: 90,
                setOrder: 2,
                createdAt: weekStartDate.add(const Duration(days: 1)),
              ),
            ],
          ),
        ];

        when(mockWorkoutRepository.findByUserIdAndDateRange(
          userId,
          any,
          any,
        )).thenAnswer((_) async => sessions);

        when(mockPRTrackingService.getPRsInDateRange(
          userId,
          any,
          any,
        )).thenAnswer((_) async => []);

        when(mockStreakTrackingService.getAllMilestones(userId))
            .thenAnswer((_) async => []);

        when(mockWorkoutRepository.findByUserIdAndDateRange(
          userId,
          weekStartDate.subtract(const Duration(days: 7)),
          weekStartDate,
        )).thenAnswer((_) async => []);

        // Act
        final result = await weeklyHighlightService.generateWeeklyHighlight(
          userId: userId,
          weekStartDate: weekStartDate,
        );

        // Assert
        expect(result.stats.totalSessions, equals(1));
        expect(result.stats.totalSets, equals(2));
        expect(result.stats.totalVolume, equals(1600.0)); // 100*8 + 80*10
        expect(result.stats.averageRPE, equals(7.5)); // (8+7)/2
        expect(result.stats.averageSessionDuration, equals(60.0)); // 1 hour
        expect(result.stats.uniqueExercises, equals(2)); // squat, bench
        expect(result.stats.totalRestTime, equals(3.5)); // (120+90)/60 minutes
        expect(result.stats.exerciseFrequency['squat'], equals(1));
        expect(result.stats.exerciseFrequency['bench'], equals(1));
      });
    });

    group('Performance rating', () {
      test('should assign correct performance ratings', () async {
        // Test excellent performance (6+ sessions, high volume, PRs)
        const userId = 'user123';
        final weekStartDate = DateTime(2024, 1, 1);
        
        final excellentSessions = List.generate(6, (i) => WorkoutSession(
          id: 'session$i',
          userId: userId,
          startTime: weekStartDate.add(Duration(days: i)),
          endTime: weekStartDate.add(Duration(days: i, hours: 1)),
          sessionType: SessionType.strength,
          createdAt: weekStartDate.add(Duration(days: i)),
          sets: [
            WorkoutSet(
              id: 'set$i',
              sessionId: 'session$i',
              exerciseId: 'squat',
              weight: 100.0,
              reps: 8,
              rpe: 8,
              setOrder: 1,
              createdAt: weekStartDate.add(Duration(days: i)),
            ),
          ],
        ));

        when(mockWorkoutRepository.findByUserIdAndDateRange(
          userId,
          any,
          any,
        )).thenAnswer((_) async => excellentSessions);

        when(mockPRTrackingService.getPRsInDateRange(
          userId,
          any,
          any,
        )).thenAnswer((_) async => [
          PRRecord(
            id: 'pr1',
            userId: userId,
            exerciseId: 'squat',
            weight: 105.0,
            reps: 8,
            estimatedMax: 133.0,
            achievedAt: weekStartDate.add(const Duration(days: 2)),
          ),
          PRRecord(
            id: 'pr2',
            userId: userId,
            exerciseId: 'bench',
            weight: 85.0,
            reps: 10,
            estimatedMax: 113.3,
            achievedAt: weekStartDate.add(const Duration(days: 4)),
          ),
        ]);

        when(mockStreakTrackingService.getAllMilestones(userId))
            .thenAnswer((_) async => []);

        when(mockWorkoutRepository.findByUserIdAndDateRange(
          userId,
          weekStartDate.subtract(const Duration(days: 7)),
          weekStartDate,
        )).thenAnswer((_) async => []);

        // Act
        final result = await weeklyHighlightService.generateWeeklyHighlight(
          userId: userId,
          weekStartDate: weekStartDate,
        );

        // Assert
        expect(result.performanceRating, equals(PerformanceRating.excellent));
        expect(result.achievements, isNotEmpty);
        expect(result.achievements.any((a) => a.type == AchievementType.sessionRecord), isTrue);
      });
    });
  });
}