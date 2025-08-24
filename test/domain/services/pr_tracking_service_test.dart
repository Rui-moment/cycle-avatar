import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:cycle_avatar/domain/entities/pr_record.dart';
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/exercise.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';
import 'package:cycle_avatar/domain/services/pr_tracking_service.dart';
import 'package:cycle_avatar/data/repositories/pr_repository.dart';
import 'package:cycle_avatar/data/repositories/exercise_repository.dart';

import 'pr_tracking_service_test.mocks.dart';

@GenerateMocks([PRRepository, ExerciseRepository])
void main() {
  late PRTrackingService prTrackingService;
  late MockPRRepository mockPRRepository;
  late MockExerciseRepository mockExerciseRepository;

  setUp(() {
    mockPRRepository = MockPRRepository();
    mockExerciseRepository = MockExerciseRepository();
    prTrackingService = PRTrackingService(mockPRRepository, mockExerciseRepository);
  });

  group('PRTrackingService', () {
    group('checkAndCreatePR', () {
      test('should create PR when set is a new personal record', () async {
        // Arrange
        const userId = 'user123';
        final workoutSet = WorkoutSet(
          id: 'set1',
          sessionId: 'session1',
          exerciseId: 'squat',
          weight: 100.0,
          reps: 5,
          rpe: 8,
          setOrder: 1,
          createdAt: DateTime.now(),
        );

        final expectedPR = PRRecord(
          id: 'pr1',
          userId: userId,
          exerciseId: 'squat',
          weight: 100.0,
          reps: 5,
          estimatedMax: 116.7, // 100 * (1 + 5/30)
          achievedAt: workoutSet.createdAt,
          workoutSessionId: 'session1',
        );

        when(mockPRRepository.isNewPR(userId, 'squat', 100.0, 5))
            .thenAnswer((_) async => true);
        when(mockPRRepository.createFromWorkoutSet(
          userId: userId,
          exerciseId: 'squat',
          weight: 100.0,
          reps: 5,
          achievedAt: workoutSet.createdAt,
          workoutSessionId: 'session1',
          notes: anyNamed('notes'),
        )).thenAnswer((_) async => expectedPR);

        // Act
        final result = await prTrackingService.checkAndCreatePR(
          userId: userId,
          workoutSet: workoutSet,
        );

        // Assert
        expect(result, equals(expectedPR));
        verify(mockPRRepository.isNewPR(userId, 'squat', 100.0, 5)).called(1);
        verify(mockPRRepository.createFromWorkoutSet(
          userId: userId,
          exerciseId: 'squat',
          weight: 100.0,
          reps: 5,
          achievedAt: workoutSet.createdAt,
          workoutSessionId: 'session1',
          notes: anyNamed('notes'),
        )).called(1);
      });

      test('should return null when set is not a new PR', () async {
        // Arrange
        const userId = 'user123';
        final workoutSet = WorkoutSet(
          id: 'set1',
          sessionId: 'session1',
          exerciseId: 'squat',
          weight: 90.0,
          reps: 5,
          rpe: 7,
          setOrder: 1,
          createdAt: DateTime.now(),
        );

        when(mockPRRepository.isNewPR(userId, 'squat', 90.0, 5))
            .thenAnswer((_) async => false);

        // Act
        final result = await prTrackingService.checkAndCreatePR(
          userId: userId,
          workoutSet: workoutSet,
        );

        // Assert
        expect(result, isNull);
        verify(mockPRRepository.isNewPR(userId, 'squat', 90.0, 5)).called(1);
        verifyNever(mockPRRepository.createFromWorkoutSet(
          userId: anyNamed('userId'),
          exerciseId: anyNamed('exerciseId'),
          weight: anyNamed('weight'),
          reps: anyNamed('reps'),
          achievedAt: anyNamed('achievedAt'),
          workoutSessionId: anyNamed('workoutSessionId'),
          notes: anyNamed('notes'),
        ));
      });
    });

    group('processWorkoutSessionForPRs', () {
      test('should process session and find PRs for multiple exercises', () async {
        // Arrange
        const userId = 'user123';
        final session = WorkoutSession(
          id: 'session1',
          userId: userId,
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          sets: [
            WorkoutSet(
              id: 'set1',
              sessionId: 'session1',
              exerciseId: 'squat',
              weight: 100.0,
              reps: 5,
              rpe: 8,
              setOrder: 1,
              createdAt: DateTime.now(),
            ),
            WorkoutSet(
              id: 'set2',
              sessionId: 'session1',
              exerciseId: 'squat',
              weight: 95.0,
              reps: 6,
              rpe: 7,
              setOrder: 2,
              createdAt: DateTime.now(),
            ),
            WorkoutSet(
              id: 'set3',
              sessionId: 'session1',
              exerciseId: 'bench',
              weight: 80.0,
              reps: 8,
              rpe: 9,
              setOrder: 3,
              createdAt: DateTime.now(),
            ),
          ],
        );

        final squatPR = PRRecord(
          id: 'pr1',
          userId: userId,
          exerciseId: 'squat',
          weight: 100.0,
          reps: 5,
          estimatedMax: 116.7,
          achievedAt: DateTime.now(),
        );

        // Mock PR checks - squat is PR, bench is not
        when(mockPRRepository.isNewPR(userId, 'squat', 100.0, 5))
            .thenAnswer((_) async => true);
        when(mockPRRepository.isNewPR(userId, 'bench', 80.0, 8))
            .thenAnswer((_) async => false);

        when(mockPRRepository.createFromWorkoutSet(
          userId: userId,
          exerciseId: 'squat',
          weight: 100.0,
          reps: 5,
          achievedAt: anyNamed('achievedAt'),
          workoutSessionId: 'session1',
          notes: anyNamed('notes'),
        )).thenAnswer((_) async => squatPR);

        // Act
        final result = await prTrackingService.processWorkoutSessionForPRs(
          userId: userId,
          session: session,
        );

        // Assert
        expect(result, hasLength(1));
        expect(result.first.exerciseId, equals('squat'));
        expect(result.first.weight, equals(100.0));
        expect(result.first.reps, equals(5));
      });

      test('should find best set for each exercise when multiple sets exist', () async {
        // Arrange
        const userId = 'user123';
        final session = WorkoutSession(
          id: 'session1',
          userId: userId,
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          sets: [
            WorkoutSet(
              id: 'set1',
              sessionId: 'session1',
              exerciseId: 'squat',
              weight: 95.0,
              reps: 6,
              rpe: 7,
              setOrder: 1,
              createdAt: DateTime.now(),
            ),
            WorkoutSet(
              id: 'set2',
              sessionId: 'session1',
              exerciseId: 'squat',
              weight: 100.0, // Best set (highest estimated 1RM)
              reps: 5,
              rpe: 8,
              setOrder: 2,
              createdAt: DateTime.now(),
            ),
            WorkoutSet(
              id: 'set3',
              sessionId: 'session1',
              exerciseId: 'squat',
              weight: 90.0,
              reps: 8,
              rpe: 6,
              setOrder: 3,
              createdAt: DateTime.now(),
            ),
          ],
        );

        when(mockPRRepository.isNewPR(userId, 'squat', 100.0, 5))
            .thenAnswer((_) async => true);

        final expectedPR = PRRecord(
          id: 'pr1',
          userId: userId,
          exerciseId: 'squat',
          weight: 100.0,
          reps: 5,
          estimatedMax: 116.7,
          achievedAt: DateTime.now(),
        );

        when(mockPRRepository.createFromWorkoutSet(
          userId: userId,
          exerciseId: 'squat',
          weight: 100.0,
          reps: 5,
          achievedAt: anyNamed('achievedAt'),
          workoutSessionId: 'session1',
          notes: anyNamed('notes'),
        )).thenAnswer((_) async => expectedPR);

        // Act
        final result = await prTrackingService.processWorkoutSessionForPRs(
          userId: userId,
          session: session,
        );

        // Assert
        expect(result, hasLength(1));
        expect(result.first.weight, equals(100.0)); // Should use the best set
        expect(result.first.reps, equals(5));
        
        // Verify it checked the best set, not the others
        verify(mockPRRepository.isNewPR(userId, 'squat', 100.0, 5)).called(1);
        verifyNever(mockPRRepository.isNewPR(userId, 'squat', 95.0, 6));
        verifyNever(mockPRRepository.isNewPR(userId, 'squat', 90.0, 8));
      });
    });

    group('getCurrentPRs', () {
      test('should return current best PR for each exercise', () async {
        // Arrange
        const userId = 'user123';
        final allPRs = [
          PRRecord(
            id: 'pr1',
            userId: userId,
            exerciseId: 'squat',
            weight: 100.0,
            reps: 5,
            estimatedMax: 116.7,
            achievedAt: DateTime.now().subtract(const Duration(days: 10)),
          ),
          PRRecord(
            id: 'pr2',
            userId: userId,
            exerciseId: 'squat',
            weight: 105.0, // Better PR for squat
            reps: 4,
            estimatedMax: 119.0,
            achievedAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
          PRRecord(
            id: 'pr3',
            userId: userId,
            exerciseId: 'bench',
            weight: 80.0,
            reps: 6,
            estimatedMax: 96.0,
            achievedAt: DateTime.now().subtract(const Duration(days: 7)),
          ),
        ];

        when(mockPRRepository.findByUserId(userId))
            .thenAnswer((_) async => allPRs);

        // Act
        final result = await prTrackingService.getCurrentPRs(userId);

        // Assert
        expect(result, hasLength(2)); // One for squat, one for bench
        
        // Should have the better squat PR
        final squatPR = result.firstWhere((pr) => pr.exerciseId == 'squat');
        expect(squatPR.weight, equals(105.0));
        expect(squatPR.estimatedMax, equals(119.0));
        
        // Should have the bench PR
        final benchPR = result.firstWhere((pr) => pr.exerciseId == 'bench');
        expect(benchPR.weight, equals(80.0));
        expect(benchPR.estimatedMax, equals(96.0));
        
        // Should be sorted by estimated max (descending)
        expect(result.first.estimatedMax, greaterThanOrEqualTo(result.last.estimatedMax));
      });
    });

    group('calculatePRImprovement', () {
      test('should calculate improvement percentage over timeframe', () async {
        // Arrange
        const userId = 'user123';
        const exerciseId = 'squat';
        final timeframe = const Duration(days: 30);
        
        final now = DateTime.now();
        final prs = [
          PRRecord(
            id: 'pr1',
            userId: userId,
            exerciseId: exerciseId,
            weight: 100.0,
            reps: 5,
            estimatedMax: 116.7,
            achievedAt: now.subtract(const Duration(days: 35)), // Outside timeframe
          ),
          PRRecord(
            id: 'pr2',
            userId: userId,
            exerciseId: exerciseId,
            weight: 105.0,
            reps: 5,
            estimatedMax: 122.5,
            achievedAt: now.subtract(const Duration(days: 25)), // Start of timeframe
          ),
          PRRecord(
            id: 'pr3',
            userId: userId,
            exerciseId: exerciseId,
            weight: 110.0,
            reps: 5,
            estimatedMax: 128.3,
            achievedAt: now.subtract(const Duration(days: 5)), // End of timeframe
          ),
        ];

        when(mockPRRepository.findByUserAndExercise(userId, exerciseId))
            .thenAnswer((_) async => prs);

        // Act
        final result = await prTrackingService.calculatePRImprovement(
          userId,
          exerciseId,
          timeframe,
        );

        // Assert
        // Improvement from 122.5 to 128.3 = (128.3 - 122.5) / 122.5 * 100 ≈ 4.73%
        expect(result, closeTo(4.73, 0.1));
      });

      test('should return 0 when insufficient PRs in timeframe', () async {
        // Arrange
        const userId = 'user123';
        const exerciseId = 'squat';
        final timeframe = const Duration(days: 30);
        
        when(mockPRRepository.findByUserAndExercise(userId, exerciseId))
            .thenAnswer((_) async => []);

        // Act
        final result = await prTrackingService.calculatePRImprovement(
          userId,
          exerciseId,
          timeframe,
        );

        // Assert
        expect(result, equals(0.0));
      });
    });

    group('getPRCelebrationData', () {
      test('should return complete celebration data with improvement', () async {
        // Arrange
        final pr = PRRecord(
          id: 'pr1',
          userId: 'user123',
          exerciseId: 'squat',
          weight: 110.0,
          reps: 5,
          estimatedMax: 128.3,
          achievedAt: DateTime.now(),
        );

        final exercise = Exercise(
          id: 'squat',
          names: {'en': 'Squat', 'ja': 'スクワット'},
          category: 'compound',
          equipment: EquipmentType.barbell,
          instructions: {'en': 'Squat down and up'},
          primaryMuscleGroups: ['quadriceps'],
          secondaryMuscleGroups: ['glutes'],
          isCompound: true,
          createdAt: DateTime.now(),
        );

        final previousPR = PRRecord(
          id: 'pr0',
          userId: 'user123',
          exerciseId: 'squat',
          weight: 105.0,
          reps: 5,
          estimatedMax: 122.5,
          achievedAt: DateTime.now().subtract(const Duration(days: 10)),
        );

        final allPRs = [pr, previousPR];

        when(mockExerciseRepository.findById('squat'))
            .thenAnswer((_) async => exercise);
        when(mockPRRepository.findByUserAndExercise('user123', 'squat'))
            .thenAnswer((_) async => allPRs);

        // Act
        final result = await prTrackingService.getPRCelebrationData(pr);

        // Assert
        expect(result['pr'], equals(pr));
        expect(result['exercise'], equals(exercise));
        expect(result['previous_best'], equals(previousPR));
        expect(result['improvement_percentage'], closeTo(4.73, 0.1));
        expect(result['is_significant'], isTrue); // > 2.5%
        expect(result['pr_type'], equals('Strength')); // 5 reps
        expect(result['strength_level'], isA<String>());
      });
    });
  });
}