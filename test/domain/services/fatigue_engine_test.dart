import 'package:flutter_test/flutter_test.dart';
import 'package:cycle_avatar/domain/services/fatigue_engine.dart';
import 'package:cycle_avatar/domain/entities/exercise.dart';
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';
import 'package:cycle_avatar/domain/entities/constants.dart';

void main() {
  group('FatigueEngine', () {
    late FatigueEngine fatigueEngine;
    late Exercise squatExercise;
    late Exercise benchPressExercise;
    late WorkoutSet testSet;
    late WorkoutSession testSession;

    setUp(() {
      fatigueEngine = FatigueEngine();
      
      // Create test exercise (Squat - compound movement)
      squatExercise = Exercise(
        id: 'squat',
        names: {'en': 'Squat', 'ja': 'スクワット'},
        category: 'legs',
        equipment: EquipmentType.barbell,
        instructions: {'en': 'Squat down and up', 'ja': 'しゃがんで立つ'},
        primaryMuscleGroups: ['quadriceps', 'glutes'],
        secondaryMuscleGroups: ['hamstrings', 'calves'],
        isCompound: true,
        createdAt: DateTime.now(),
      );
      
      // Create test exercise (Bench Press)
      benchPressExercise = Exercise(
        id: 'bench_press',
        names: {'en': 'Bench Press', 'ja': 'ベンチプレス'},
        category: 'chest',
        equipment: EquipmentType.barbell,
        instructions: {'en': 'Press the bar up', 'ja': 'バーを押し上げる'},
        primaryMuscleGroups: ['chest'],
        secondaryMuscleGroups: ['triceps', 'shoulders'],
        isCompound: true,
        createdAt: DateTime.now(),
      );
      
      // Create test set
      testSet = WorkoutSet(
        id: 'set1',
        sessionId: 'session1',
        exerciseId: 'squat',
        weight: 100.0,
        reps: 8,
        rpe: 8,
        restSeconds: 180,
        setOrder: 1,
        createdAt: DateTime.now(),
      );
      
      // Create test session
      testSession = WorkoutSession(
        id: 'session1',
        userId: 'user1',
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now(),
        sessionType: SessionType.hypertrophy,
        createdAt: DateTime.now(),
        sets: [testSet],
      );
    });

    group('calculateSetFatigueScore', () {
      test('should calculate correct fatigue score for valid inputs', () {
        final fatigueScore = fatigueEngine.calculateSetFatigueScore(
          set: testSet,
          exercise: squatExercise,
          muscleGroupId: 'quadriceps',
        );
        
        // Expected calculation:
        // Volume = 100 * 8 = 800
        // IntensityFactor = (8 - 5) / 5 = 0.6
        // RPEFactor = 8 / 10 = 0.8
        // MuscleMultiplier = 1.3 (quadriceps)
        // InvolvementWeight = 1.0 (primary muscle)
        // Expected = 800 * 0.6 * 0.8 * 1.3 * 1.0 = 499.2
        
        expect(fatigueScore, closeTo(499.2, 0.1));
      });

      test('should apply secondary muscle weight correctly', () {
        final primaryFatigue = fatigueEngine.calculateSetFatigueScore(
          set: testSet,
          exercise: squatExercise,
          muscleGroupId: 'quadriceps', // Primary
        );
        
        final secondaryFatigue = fatigueEngine.calculateSetFatigueScore(
          set: testSet,
          exercise: squatExercise,
          muscleGroupId: 'hamstrings', // Secondary
        );
        
        // Secondary muscle should have 0.5x involvement weight
        expect(secondaryFatigue, lessThan(primaryFatigue));
        expect(secondaryFatigue / primaryFatigue, closeTo(0.5, 0.1));
      });

      test('should return 0 for invalid inputs', () {
        final invalidSet = testSet.copyWith(weight: 0);
        
        final fatigueScore = fatigueEngine.calculateSetFatigueScore(
          set: invalidSet,
          exercise: squatExercise,
          muscleGroupId: 'quadriceps',
        );
        
        expect(fatigueScore, equals(0.0));
      });

      test('should handle RPE boundary values correctly', () {
        // Test minimum RPE (should result in 0 intensity factor)
        final lowRPESet = testSet.copyWith(rpe: 5);
        final lowRPEFatigue = fatigueEngine.calculateSetFatigueScore(
          set: lowRPESet,
          exercise: squatExercise,
          muscleGroupId: 'quadriceps',
        );
        
        // Test maximum RPE
        final highRPESet = testSet.copyWith(rpe: 10);
        final highRPEFatigue = fatigueEngine.calculateSetFatigueScore(
          set: highRPESet,
          exercise: squatExercise,
          muscleGroupId: 'quadriceps',
        );
        
        expect(lowRPEFatigue, equals(0.0)); // RPE 5 should give 0 intensity factor
        expect(highRPEFatigue, greaterThan(lowRPEFatigue));
      });

      test('should handle muscle group not in exercise', () {
        final fatigueScore = fatigueEngine.calculateSetFatigueScore(
          set: testSet,
          exercise: squatExercise,
          muscleGroupId: 'biceps', // Not involved in squat
        );
        
        expect(fatigueScore, equals(0.0));
      });
    });

    group('calculateExerciseFatigueScore', () {
      test('should sum fatigue from multiple sets', () {
        final sets = [
          testSet,
          testSet.copyWith(id: 'set2', setOrder: 2),
          testSet.copyWith(id: 'set3', setOrder: 3),
        ];
        
        final totalFatigue = fatigueEngine.calculateExerciseFatigueScore(
          sets: sets,
          exercise: squatExercise,
          muscleGroupId: 'quadriceps',
        );
        
        final singleSetFatigue = fatigueEngine.calculateSetFatigueScore(
          set: testSet,
          exercise: squatExercise,
          muscleGroupId: 'quadriceps',
        );
        
        expect(totalFatigue, closeTo(singleSetFatigue * 3, 0.1));
      });

      test('should return 0 for empty sets list', () {
        final totalFatigue = fatigueEngine.calculateExerciseFatigueScore(
          sets: [],
          exercise: squatExercise,
          muscleGroupId: 'quadriceps',
        );
        
        expect(totalFatigue, equals(0.0));
      });
    });

    group('distributeFatigueAcrossSession', () {
      test('should distribute fatigue to all involved muscle groups', () {
        final exercises = {
          'squat': squatExercise,
          'bench_press': benchPressExercise,
        };
        
        final benchSet = WorkoutSet(
          id: 'set2',
          sessionId: 'session1',
          exerciseId: 'bench_press',
          weight: 80.0,
          reps: 10,
          rpe: 7,
          restSeconds: 120,
          setOrder: 2,
          createdAt: DateTime.now(),
        );
        
        final sessionWithMultipleExercises = testSession.copyWith(
          sets: [testSet, benchSet],
        );
        
        final distribution = fatigueEngine.distributeFatigueAcrossSession(
          session: sessionWithMultipleExercises,
          exercises: exercises,
        );
        
        // Should have fatigue for squat muscle groups
        expect(distribution.containsKey('quadriceps'), isTrue);
        expect(distribution.containsKey('glutes'), isTrue);
        expect(distribution.containsKey('hamstrings'), isTrue);
        
        // Should have fatigue for bench press muscle groups
        expect(distribution.containsKey('chest'), isTrue);
        expect(distribution.containsKey('triceps'), isTrue);
        expect(distribution.containsKey('shoulders'), isTrue);
        
        // All fatigue values should be positive
        for (final fatigue in distribution.values) {
          expect(fatigue, greaterThan(0.0));
        }
      });

      test('should handle session with unknown exercises', () {
        final exercises = <String, Exercise>{}; // Empty exercises map
        
        final distribution = fatigueEngine.distributeFatigueAcrossSession(
          session: testSession,
          exercises: exercises,
        );
        
        expect(distribution, isEmpty);
      });
    });

    group('calculateWeightedFatigueDistribution', () {
      test('should apply correct weights to primary and secondary muscles', () {
        final distribution = fatigueEngine.calculateWeightedFatigueDistribution(
          set: testSet,
          exercise: squatExercise,
        );
        
        // Primary muscles should have higher fatigue than secondary
        final quadricepsFatigue = distribution['quadriceps']!;
        final hamstringsFatigue = distribution['hamstrings']!;
        
        expect(quadricepsFatigue, greaterThan(hamstringsFatigue));
        
        // Check that all involved muscle groups are present
        expect(distribution.containsKey('quadriceps'), isTrue);
        expect(distribution.containsKey('glutes'), isTrue);
        expect(distribution.containsKey('hamstrings'), isTrue);
        expect(distribution.containsKey('calves'), isTrue);
      });
    });

    group('calculateSessionMetrics', () {
      test('should calculate comprehensive session metrics', () {
        final exercises = {'squat': squatExercise};
        
        final metrics = fatigueEngine.calculateSessionMetrics(
          session: testSession,
          exercises: exercises,
        );
        
        expect(metrics.totalFatigue, greaterThan(0.0));
        expect(metrics.averageRPE, equals(8.0));
        expect(metrics.totalVolume, equals(800.0)); // 100 * 8
        expect(metrics.muscleGroupsTargeted, isNotEmpty);
        expect(metrics.sessionDuration, isNotNull);
      });

      test('should identify most fatigued muscle group', () {
        final exercises = {'squat': squatExercise};
        
        final metrics = fatigueEngine.calculateSessionMetrics(
          session: testSession,
          exercises: exercises,
        );
        
        final mostFatigued = metrics.mostFatiguedMuscleGroup;
        expect(mostFatigued, isNotNull);
        expect(squatExercise.allMuscleGroups.contains(mostFatigued), isTrue);
      });
    });

    group('validateFatigueInputs', () {
      test('should validate correct inputs', () {
        final isValid = fatigueEngine.validateFatigueInputs(
          set: testSet,
          exercise: squatExercise,
        );
        
        expect(isValid, isTrue);
      });

      test('should reject invalid set data', () {
        final invalidSet = testSet.copyWith(weight: 0);
        
        final isValid = fatigueEngine.validateFatigueInputs(
          set: invalidSet,
          exercise: squatExercise,
        );
        
        expect(isValid, isFalse);
      });

      test('should reject exercise without primary muscle groups', () {
        final invalidExercise = squatExercise.copyWith(primaryMuscleGroups: []);
        
        final isValid = fatigueEngine.validateFatigueInputs(
          set: testSet,
          exercise: invalidExercise,
        );
        
        expect(isValid, isFalse);
      });

      test('should reject invalid RPE values', () {
        final lowRPESet = testSet.copyWith(rpe: 0);
        final highRPESet = testSet.copyWith(rpe: 11);
        
        expect(fatigueEngine.validateFatigueInputs(
          set: lowRPESet,
          exercise: squatExercise,
        ), isFalse);
        
        expect(fatigueEngine.validateFatigueInputs(
          set: highRPESet,
          exercise: squatExercise,
        ), isFalse);
      });
    });

    group('Edge Cases and Boundary Values', () {
      test('should handle extreme fatigue values', () {
        final extremeSet = testSet.copyWith(
          weight: 500.0, // Very heavy
          reps: 1,
          rpe: 10,
        );
        
        final fatigueScore = fatigueEngine.calculateSetFatigueScore(
          set: extremeSet,
          exercise: squatExercise,
          muscleGroupId: 'quadriceps',
        );
        
        expect(fatigueScore, greaterThan(0.0));
        expect(fatigueScore, lessThan(10000.0)); // Reasonable upper bound
      });

      test('should handle minimal fatigue values', () {
        final minimalSet = testSet.copyWith(
          weight: 1.0,
          reps: 1,
          rpe: 6, // Minimum effective RPE
        );
        
        final fatigueScore = fatigueEngine.calculateSetFatigueScore(
          set: minimalSet,
          exercise: squatExercise,
          muscleGroupId: 'quadriceps',
        );
        
        expect(fatigueScore, greaterThan(0.0));
        expect(fatigueScore, lessThan(10.0)); // Should be small
      });

      test('should handle unknown muscle groups gracefully', () {
        final fatigueScore = fatigueEngine.calculateSetFatigueScore(
          set: testSet,
          exercise: squatExercise,
          muscleGroupId: 'unknown_muscle',
        );
        
        expect(fatigueScore, equals(0.0));
      });
    });
  });

  group('SessionFatigueMetrics', () {
    test('should provide correct muscle group fatigue lookup', () {
      final distribution = {
        'quadriceps': 100.0,
        'chest': 50.0,
        'biceps': 25.0,
      };
      
      final metrics = SessionFatigueMetrics(
        totalFatigue: 175.0,
        fatigueDistribution: distribution,
        averageRPE: 8.0,
        totalVolume: 1000.0,
        muscleGroupsTargeted: distribution.keys.toList(),
      );
      
      expect(metrics.getFatigueForMuscleGroup('quadriceps'), equals(100.0));
      expect(metrics.getFatigueForMuscleGroup('chest'), equals(50.0));
      expect(metrics.getFatigueForMuscleGroup('unknown'), equals(0.0));
    });

    test('should correctly identify targeted muscle groups', () {
      final distribution = {
        'quadriceps': 100.0,
        'chest': 50.0,
      };
      
      final metrics = SessionFatigueMetrics(
        totalFatigue: 150.0,
        fatigueDistribution: distribution,
        averageRPE: 8.0,
        totalVolume: 1000.0,
        muscleGroupsTargeted: distribution.keys.toList(),
      );
      
      expect(metrics.targetedMuscleGroup('quadriceps'), isTrue);
      expect(metrics.targetedMuscleGroup('chest'), isTrue);
      expect(metrics.targetedMuscleGroup('biceps'), isFalse);
    });

    test('should identify most fatigued muscle group', () {
      final distribution = {
        'quadriceps': 100.0,
        'chest': 150.0, // Highest
        'biceps': 25.0,
      };
      
      final metrics = SessionFatigueMetrics(
        totalFatigue: 275.0,
        fatigueDistribution: distribution,
        averageRPE: 8.0,
        totalVolume: 1000.0,
        muscleGroupsTargeted: distribution.keys.toList(),
      );
      
      expect(metrics.mostFatiguedMuscleGroup, equals('chest'));
    });
  });
}