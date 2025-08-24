import 'package:flutter_test/flutter_test.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';
import 'package:cycle_avatar/domain/entities/constants.dart';
import 'package:cycle_avatar/domain/entities/avatar_state.dart';
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/exercise.dart';
import 'package:cycle_avatar/domain/entities/recovery_state.dart';
import 'package:cycle_avatar/domain/entities/pr_record.dart';
import 'package:cycle_avatar/domain/services/avatar_system.dart';

void main() {
  group('AvatarSystem', () {
    late AvatarSystem avatarSystem;
    late AvatarState testAvatarState;
    late Exercise testExercise;
    late WorkoutSession testSession;
    late Map<String, Exercise> exercises;

    setUp(() {
      avatarSystem = AvatarSystem();
      
      // Create test avatar state
      testAvatarState = AvatarState(
        id: 'test_avatar',
        userId: 'test_user',
        muscleGroupLevels: {
          'chest': 5,
          'triceps': 3,
          'shoulders': 4,
        },
        growthPoints: {
          'chest': 2500.0, // Level 5 = sqrt(2500/100) = 5
          'triceps': 900.0, // Level 3 = sqrt(900/100) = 3
          'shoulders': 1600.0, // Level 4 = sqrt(1600/100) = 4
        },
        totalGrowthPoints: 5000.0,
      );

      // Create test exercise
      testExercise = Exercise(
        id: 'bench_press',
        names: {'en': 'Bench Press', 'ja': 'ベンチプレス'},
        category: 'chest',
        equipment: EquipmentType.barbell,
        primaryMuscleGroups: ['chest'],
        secondaryMuscleGroups: ['triceps', 'shoulders'],
        instructions: {'en': 'Bench press instructions', 'ja': 'ベンチプレスの説明'},
        isCompound: true,
        createdAt: DateTime.now(),
      );

      exercises = {'bench_press': testExercise};

      // Create test workout session
      testSession = WorkoutSession(
        id: 'test_session',
        userId: 'test_user',
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now(),
        sessionType: SessionType.strength,
        createdAt: DateTime.now(),
        sets: [
          WorkoutSet(
            id: 'set_1',
            sessionId: 'test_session',
            exerciseId: 'bench_press',
            weight: 100.0,
            reps: 8,
            rpe: 8,
            setOrder: 1,
            createdAt: DateTime.now(),
          ),
          WorkoutSet(
            id: 'set_2',
            sessionId: 'test_session',
            exerciseId: 'bench_press',
            weight: 100.0,
            reps: 8,
            rpe: 8,
            setOrder: 2,
            createdAt: DateTime.now(),
          ),
        ],
      );
    });

    group('hasAchievedProgression', () {
      test('should return true for weight progression', () {
        // Create previous session with lower weight
        final previousSession = WorkoutSession(
          id: 'prev_session',
          userId: 'test_user',
          startTime: DateTime.now().subtract(const Duration(days: 2)),
          endTime: DateTime.now().subtract(const Duration(days: 2, hours: -1)),
          sessionType: SessionType.strength,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          sets: [
            WorkoutSet(
              id: 'prev_set_1',
              sessionId: 'prev_session',
              exerciseId: 'bench_press',
              weight: 97.5, // 2.5kg less than current
              reps: 8,
              rpe: 8,
              setOrder: 1,
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          ],
        );

        final result = avatarSystem.hasAchievedProgression(
          currentSession: testSession,
          previousSessions: [previousSession],
          exercises: exercises,
        );

        expect(result, isTrue);
      });

      test('should return true for rep progression at same weight', () {
        // Create previous session with same weight but fewer reps
        final previousSession = WorkoutSession(
          id: 'prev_session',
          userId: 'test_user',
          startTime: DateTime.now().subtract(const Duration(days: 2)),
          endTime: DateTime.now().subtract(const Duration(days: 2, hours: -1)),
          sessionType: SessionType.strength,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          sets: [
            WorkoutSet(
              id: 'prev_set_1',
              sessionId: 'prev_session',
              exerciseId: 'bench_press',
              weight: 100.0, // Same weight
              reps: 7, // 1 rep less than current
              rpe: 8,
              setOrder: 1,
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          ],
        );

        final result = avatarSystem.hasAchievedProgression(
          currentSession: testSession,
          previousSessions: [previousSession],
          exercises: exercises,
        );

        expect(result, isTrue);
      });

      test('should return false for no progression', () {
        // Create previous session with same or better performance
        final previousSession = WorkoutSession(
          id: 'prev_session',
          userId: 'test_user',
          startTime: DateTime.now().subtract(const Duration(days: 2)),
          endTime: DateTime.now().subtract(const Duration(days: 2, hours: -1)),
          sessionType: SessionType.strength,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          sets: [
            WorkoutSet(
              id: 'prev_set_1',
              sessionId: 'prev_session',
              exerciseId: 'bench_press',
              weight: 102.5, // Higher weight
              reps: 8,
              rpe: 8,
              setOrder: 1,
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          ],
        );

        final result = avatarSystem.hasAchievedProgression(
          currentSession: testSession,
          previousSessions: [previousSession],
          exercises: exercises,
        );

        expect(result, isFalse);
      });

      test('should return true for first time doing exercise', () {
        final result = avatarSystem.hasAchievedProgression(
          currentSession: testSession,
          previousSessions: [], // No previous sessions
          exercises: exercises,
        );

        expect(result, isTrue);
      });
    });

    group('shouldLevelUp', () {
      test('should return true when progression achieved with ready muscle group', () {
        final preWorkoutReadiness = {
          'chest': ReadinessLevel.ready,
          'triceps': ReadinessLevel.warm,
          'shoulders': ReadinessLevel.fatigued,
        };

        final result = avatarSystem.shouldLevelUp(
          session: testSession,
          preWorkoutReadiness: preWorkoutReadiness,
          achievedProgression: true,
          exercises: exercises,
        );

        expect(result, isTrue);
      });

      test('should return false when no progression achieved', () {
        final preWorkoutReadiness = {
          'chest': ReadinessLevel.ready,
          'triceps': ReadinessLevel.ready,
          'shoulders': ReadinessLevel.ready,
        };

        final result = avatarSystem.shouldLevelUp(
          session: testSession,
          preWorkoutReadiness: preWorkoutReadiness,
          achievedProgression: false,
          exercises: exercises,
        );

        expect(result, isFalse);
      });

      test('should return false when all targeted muscle groups are fatigued', () {
        final preWorkoutReadiness = {
          'chest': ReadinessLevel.fatigued,
          'triceps': ReadinessLevel.fatigued,
          'shoulders': ReadinessLevel.fatigued,
        };

        final result = avatarSystem.shouldLevelUp(
          session: testSession,
          preWorkoutReadiness: preWorkoutReadiness,
          achievedProgression: true,
          exercises: exercises,
        );

        expect(result, isFalse);
      });
    });

    group('calculateGrowthPoints', () {
      test('should award full points for ready muscle groups with progression', () {
        final preWorkoutReadiness = {
          'chest': ReadinessLevel.ready,
          'triceps': ReadinessLevel.warm,
          'shoulders': ReadinessLevel.fatigued,
        };

        final result = avatarSystem.calculateGrowthPoints(
          session: testSession,
          preWorkoutReadiness: preWorkoutReadiness,
          achievedProgression: true,
          exercises: exercises,
        );

        // Chest should get bonus points (ready state)
        expect(result['chest'], greaterThan(GROWTH_POINTS_BASE));
        // Triceps should get base points (warm state)
        expect(result['triceps'], equals(GROWTH_POINTS_BASE * SECONDARY_MUSCLE_WEIGHT));
        // Shoulders should get reduced points (fatigued state)
        expect(result['shoulders'], lessThan(GROWTH_POINTS_BASE * SECONDARY_MUSCLE_WEIGHT));
      });

      test('should return empty map when no progression achieved', () {
        final preWorkoutReadiness = {
          'chest': ReadinessLevel.ready,
          'triceps': ReadinessLevel.ready,
          'shoulders': ReadinessLevel.ready,
        };

        final result = avatarSystem.calculateGrowthPoints(
          session: testSession,
          preWorkoutReadiness: preWorkoutReadiness,
          achievedProgression: false,
          exercises: exercises,
        );

        expect(result, isEmpty);
      });
    });

    group('calculateNewLevel', () {
      test('should calculate correct level from growth points', () {
        // Level 6 requires 3600 points (6^2 * 100)
        final result = avatarSystem.calculateNewLevel(
          muscleGroupId: 'chest',
          currentLevel: 5,
          totalGrowthPoints: 3600.0,
        );

        expect(result, equals(6));
      });

      test('should return current level for insufficient points', () {
        final result = avatarSystem.calculateNewLevel(
          muscleGroupId: 'chest',
          currentLevel: 5,
          totalGrowthPoints: 2500.0, // Still level 5
        );

        expect(result, equals(5));
      });

      test('should handle zero points', () {
        final result = avatarSystem.calculateNewLevel(
          muscleGroupId: 'chest',
          currentLevel: 5,
          totalGrowthPoints: 0.0,
        );

        expect(result, equals(5)); // Should return current level when points are zero
      });
    });

    group('calculateCooldownDuration', () {
      test('should return zero duration for non-fatigued state', () {
        final result = avatarSystem.calculateCooldownDuration(
          muscleGroupId: 'chest',
          preWorkoutReadiness: ReadinessLevel.ready,
          consecutiveOvertrainingDays: 0,
        );

        expect(result, equals(Duration.zero));
      });

      test('should return base cooldown for fatigued state', () {
        final result = avatarSystem.calculateCooldownDuration(
          muscleGroupId: 'chest',
          preWorkoutReadiness: ReadinessLevel.fatigued,
          consecutiveOvertrainingDays: 0,
        );

        final expectedHours = RECOVERY_TAU['chest']!;
        final expectedDuration = Duration(milliseconds: (expectedHours * 60 * 60 * 1000).round());
        
        expect(result, equals(expectedDuration));
      });

      test('should increase cooldown for consecutive overtraining', () {
        final baseCooldown = avatarSystem.calculateCooldownDuration(
          muscleGroupId: 'chest',
          preWorkoutReadiness: ReadinessLevel.fatigued,
          consecutiveOvertrainingDays: 0,
        );

        final increasedCooldown = avatarSystem.calculateCooldownDuration(
          muscleGroupId: 'chest',
          preWorkoutReadiness: ReadinessLevel.fatigued,
          consecutiveOvertrainingDays: 2,
        );

        expect(increasedCooldown, greaterThan(baseCooldown));
      });
    });

    group('updateAvatarAfterWorkout', () {
      test('should update avatar state with growth points and level-ups', () {
        final preWorkoutReadiness = {
          'chest': ReadinessLevel.ready,
          'triceps': ReadinessLevel.warm,
          'shoulders': ReadinessLevel.ready,
        };

        // Create previous session for progression comparison
        final previousSession = WorkoutSession(
          id: 'prev_session',
          userId: 'test_user',
          startTime: DateTime.now().subtract(const Duration(days: 2)),
          endTime: DateTime.now().subtract(const Duration(days: 2, hours: -1)),
          sessionType: SessionType.strength,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          sets: [
            WorkoutSet(
              id: 'prev_set_1',
              sessionId: 'prev_session',
              exerciseId: 'bench_press',
              weight: 97.5, // Lower weight for progression
              reps: 8,
              rpe: 8,
              setOrder: 1,
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          ],
        );

        final result = avatarSystem.updateAvatarAfterWorkout(
          currentState: testAvatarState,
          session: testSession,
          preWorkoutReadiness: preWorkoutReadiness,
          exercises: exercises,
          previousSessions: [previousSession],
        );

        // Should have more total growth points
        expect(result.totalGrowthPoints, greaterThan(testAvatarState.totalGrowthPoints));
        
        // Chest should have gained growth points
        expect(result.getGrowthPointsForMuscleGroup('chest'), 
               greaterThan(testAvatarState.getGrowthPointsForMuscleGroup('chest')));
      });

      test('should apply cooldown for overtraining', () {
        final preWorkoutReadiness = {
          'chest': ReadinessLevel.fatigued, // Overtraining
          'triceps': ReadinessLevel.fatigued,
          'shoulders': ReadinessLevel.fatigued,
        };

        final result = avatarSystem.updateAvatarAfterWorkout(
          currentState: testAvatarState,
          session: testSession,
          preWorkoutReadiness: preWorkoutReadiness,
          exercises: exercises,
          previousSessions: [],
        );

        // Should have cooldowns applied
        expect(result.isMuscleGroupInCooldown('chest'), isTrue);
      });
    });

    group('processLevelUps', () {
      test('should detect level-ups correctly', () {
        final previousState = testAvatarState;
        final newState = testAvatarState.copyWith(
          muscleGroupLevels: {
            'chest': 6, // Level up from 5 to 6
            'triceps': 3, // No change
            'shoulders': 5, // Level up from 4 to 5
          },
        );

        final result = avatarSystem.processLevelUps(
          previousState: previousState,
          newState: newState,
        );

        expect(result, hasLength(2));
        expect(result['chest']?.newLevel, equals(6));
        expect(result['chest']?.previousLevel, equals(5));
        expect(result['shoulders']?.newLevel, equals(5));
        expect(result['shoulders']?.previousLevel, equals(4));
      });

      test('should return empty map when no level-ups occur', () {
        final result = avatarSystem.processLevelUps(
          previousState: testAvatarState,
          newState: testAvatarState,
        );

        expect(result, isEmpty);
      });
    });

    group('updateCooldowns', () {
      test('should remove expired cooldowns', () {
        final stateWithCooldowns = testAvatarState.copyWith(
          cooldownUntil: {
            'chest': DateTime.now().subtract(const Duration(hours: 1)), // Expired
            'triceps': DateTime.now().add(const Duration(hours: 1)), // Active
          },
        );

        final result = avatarSystem.updateCooldowns(currentState: stateWithCooldowns);

        expect(result.isMuscleGroupInCooldown('chest'), isFalse);
        expect(result.isMuscleGroupInCooldown('triceps'), isTrue);
      });

      test('should keep active cooldowns', () {
        final futureTime = DateTime.now().add(const Duration(hours: 24));
        final stateWithCooldowns = testAvatarState.copyWith(
          cooldownUntil: {
            'chest': futureTime,
            'triceps': futureTime,
          },
        );

        final result = avatarSystem.updateCooldowns(currentState: stateWithCooldowns);

        expect(result.isMuscleGroupInCooldown('chest'), isTrue);
        expect(result.isMuscleGroupInCooldown('triceps'), isTrue);
      });
    });

    group('isInOptimalRecoveryWindow', () {
      test('should return true when muscle group is in optimal recovery window', () {
        final recoveryStates = {
          'chest': RecoveryState(
            id: 'recovery_chest',
            muscleGroupId: 'chest',
            currentFatigue: 20.0, // 80% recovered from initial 100
            initialFatigue: 100.0,
            lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 48)),
            lastUpdated: DateTime.now(),
            readinessLevel: ReadinessLevel.ready,
          ),
        };

        final result = avatarSystem.isInOptimalRecoveryWindow(
          recoveryStates: recoveryStates,
          exercises: exercises,
          session: testSession,
        );

        expect(result, isTrue);
      });

      test('should return false when muscle group is not in optimal window', () {
        final recoveryStates = {
          'chest': RecoveryState(
            id: 'recovery_chest',
            muscleGroupId: 'chest',
            currentFatigue: 50.0, // Only 50% recovered
            initialFatigue: 100.0,
            lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 24)),
            lastUpdated: DateTime.now(),
            readinessLevel: ReadinessLevel.warm,
          ),
        };

        final result = avatarSystem.isInOptimalRecoveryWindow(
          recoveryStates: recoveryStates,
          exercises: exercises,
          session: testSession,
        );

        expect(result, isFalse);
      });
    });
  });
}