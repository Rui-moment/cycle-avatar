import 'package:flutter_test/flutter_test.dart';
import 'package:cycle_avatar/domain/services/fatigue_engine.dart';
import 'package:cycle_avatar/domain/services/recovery_engine.dart';
import 'package:cycle_avatar/domain/entities/exercise.dart';
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/recovery_state.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';
import 'package:cycle_avatar/domain/entities/constants.dart';

void main() {
  group('Fatigue and Recovery Engine Integration', () {
    late FatigueEngine fatigueEngine;
    late RecoveryEngine recoveryEngine;
    late Map<String, Exercise> exercises;
    late WorkoutSession testSession;

    setUp(() {
      fatigueEngine = FatigueEngine();
      recoveryEngine = RecoveryEngine();
      
      // Create test exercises
      exercises = {
        'squat': Exercise(
          id: 'squat',
          names: {'en': 'Squat', 'ja': 'スクワット'},
          category: 'legs',
          equipment: EquipmentType.barbell,
          instructions: {'en': 'Squat down and up', 'ja': 'しゃがんで立つ'},
          primaryMuscleGroups: ['quadriceps', 'glutes'],
          secondaryMuscleGroups: ['hamstrings', 'calves'],
          isCompound: true,
          createdAt: DateTime.now(),
        ),
        'bench_press': Exercise(
          id: 'bench_press',
          names: {'en': 'Bench Press', 'ja': 'ベンチプレス'},
          category: 'chest',
          equipment: EquipmentType.barbell,
          instructions: {'en': 'Press the bar up', 'ja': 'バーを押し上げる'},
          primaryMuscleGroups: ['chest'],
          secondaryMuscleGroups: ['triceps', 'shoulders'],
          isCompound: true,
          createdAt: DateTime.now(),
        ),
      };
      
      // Create test session with multiple exercises
      final now = DateTime.now();
      testSession = WorkoutSession(
        id: 'session1',
        userId: 'user1',
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now,
        sessionType: SessionType.hypertrophy,
        createdAt: now,
        sets: [
          // Squat sets
          WorkoutSet(
            id: 'set1',
            sessionId: 'session1',
            exerciseId: 'squat',
            weight: 100.0,
            reps: 8,
            rpe: 8,
            restSeconds: 180,
            setOrder: 1,
            createdAt: now,
          ),
          WorkoutSet(
            id: 'set2',
            sessionId: 'session1',
            exerciseId: 'squat',
            weight: 100.0,
            reps: 8,
            rpe: 8,
            restSeconds: 180,
            setOrder: 2,
            createdAt: now,
          ),
          WorkoutSet(
            id: 'set3',
            sessionId: 'session1',
            exerciseId: 'squat',
            weight: 100.0,
            reps: 8,
            rpe: 9,
            restSeconds: 180,
            setOrder: 3,
            createdAt: now,
          ),
          // Bench press sets
          WorkoutSet(
            id: 'set4',
            sessionId: 'session1',
            exerciseId: 'bench_press',
            weight: 80.0,
            reps: 10,
            rpe: 7,
            restSeconds: 120,
            setOrder: 4,
            createdAt: now,
          ),
          WorkoutSet(
            id: 'set5',
            sessionId: 'session1',
            exerciseId: 'bench_press',
            weight: 80.0,
            reps: 10,
            rpe: 8,
            restSeconds: 120,
            setOrder: 5,
            createdAt: now,
          ),
        ],
      );
    });

    group('Complete Workout Cycle', () {
      test('should calculate fatigue and create recovery states for full workout', () {
        // Step 1: Calculate fatigue distribution from workout
        final fatigueDistribution = fatigueEngine.distributeFatigueAcrossSession(
          session: testSession,
          exercises: exercises,
        );
        
        // Verify fatigue was distributed to all involved muscle groups
        expect(fatigueDistribution.containsKey('quadriceps'), isTrue);
        expect(fatigueDistribution.containsKey('glutes'), isTrue);
        expect(fatigueDistribution.containsKey('hamstrings'), isTrue);
        expect(fatigueDistribution.containsKey('chest'), isTrue);
        expect(fatigueDistribution.containsKey('triceps'), isTrue);
        expect(fatigueDistribution.containsKey('shoulders'), isTrue);
        
        // Step 2: Create recovery states from fatigue
        final recoveryStates = <String, RecoveryState>{};
        final workoutTime = testSession.endTime ?? DateTime.now();
        
        for (final entry in fatigueDistribution.entries) {
          final muscleGroupId = entry.key;
          final fatigueScore = entry.value;
          
          recoveryStates[muscleGroupId] = RecoveryState(
            id: 'recovery_$muscleGroupId',
            muscleGroupId: muscleGroupId,
            currentFatigue: fatigueScore,
            lastUpdated: workoutTime,
            readinessLevel: recoveryEngine.determineReadinessLevel(fatigueScore),
            lastWorkoutTime: workoutTime,
            initialFatigue: fatigueScore,
          );
        }
        
        // Verify recovery states were created correctly
        expect(recoveryStates.length, equals(fatigueDistribution.length));
        
        for (final state in recoveryStates.values) {
          expect(state.currentFatigue, greaterThan(0.0));
          expect(state.lastWorkoutTime, equals(workoutTime));
          expect(state.initialFatigue, equals(state.currentFatigue));
        }
      });

      test('should simulate recovery over time', () {
        // Calculate initial fatigue
        final fatigueDistribution = fatigueEngine.distributeFatigueAcrossSession(
          session: testSession,
          exercises: exercises,
        );
        
        // Create initial recovery states
        final workoutTime = testSession.endTime ?? DateTime.now();
        var recoveryStates = <String, RecoveryState>{};
        
        for (final entry in fatigueDistribution.entries) {
          final muscleGroupId = entry.key;
          final fatigueScore = entry.value;
          
          recoveryStates[muscleGroupId] = RecoveryState(
            id: 'recovery_$muscleGroupId',
            muscleGroupId: muscleGroupId,
            currentFatigue: fatigueScore,
            lastUpdated: workoutTime,
            readinessLevel: recoveryEngine.determineReadinessLevel(fatigueScore),
            lastWorkoutTime: workoutTime,
            initialFatigue: fatigueScore,
          );
        }
        
        // Simulate recovery after 24 hours
        final after24Hours = workoutTime.add(const Duration(hours: 24));
        recoveryStates = recoveryEngine.updateMultipleRecoveryStates(
          currentStates: recoveryStates,
          currentTime: after24Hours,
        );
        
        // Verify fatigue decreased for all muscle groups
        for (final state in recoveryStates.values) {
          expect(state.currentFatigue, lessThan(state.initialFatigue!));
          expect(state.lastUpdated, equals(after24Hours));
        }
        
        // Simulate recovery after 48 hours
        final after48Hours = workoutTime.add(const Duration(hours: 48));
        recoveryStates = recoveryEngine.updateMultipleRecoveryStates(
          currentStates: recoveryStates,
          currentTime: after48Hours,
        );
        
        // Verify further fatigue decrease
        for (final state in recoveryStates.values) {
          expect(state.currentFatigue, lessThan(fatigueDistribution[state.muscleGroupId]! * 0.8));
        }
      });

      test('should track readiness level changes over recovery period', () {
        // Start with high fatigue workout
        final highFatigueSession = testSession.copyWith(
          sets: testSession.sets.map((set) => set.copyWith(rpe: 10)).toList(),
        );
        
        final fatigueDistribution = fatigueEngine.distributeFatigueAcrossSession(
          session: highFatigueSession,
          exercises: exercises,
        );
        
        final workoutTime = highFatigueSession.endTime ?? DateTime.now();
        var recoveryStates = <String, RecoveryState>{};
        
        for (final entry in fatigueDistribution.entries) {
          final muscleGroupId = entry.key;
          final fatigueScore = entry.value;
          
          recoveryStates[muscleGroupId] = RecoveryState(
            id: 'recovery_$muscleGroupId',
            muscleGroupId: muscleGroupId,
            currentFatigue: fatigueScore,
            lastUpdated: workoutTime,
            readinessLevel: recoveryEngine.determineReadinessLevel(fatigueScore),
            lastWorkoutTime: workoutTime,
            initialFatigue: fatigueScore,
          );
        }
        
        // Track readiness changes over time
        final readinessHistory = <Duration, Map<String, ReadinessLevel>>{};
        
        for (final hours in [0, 12, 24, 48, 72, 96]) {
          final timePoint = workoutTime.add(Duration(hours: hours));
          final updatedStates = recoveryEngine.updateMultipleRecoveryStates(
            currentStates: recoveryStates,
            currentTime: timePoint,
          );
          
          readinessHistory[Duration(hours: hours)] = Map.fromEntries(
            updatedStates.entries.map((e) => MapEntry(e.key, e.value.readinessLevel)),
          );
          
          recoveryStates = updatedStates;
        }
        
        // Verify progression from fatigued to ready
        for (final muscleGroupId in fatigueDistribution.keys) {
          final initialReadiness = readinessHistory[Duration.zero]![muscleGroupId]!;
          final finalReadiness = readinessHistory[const Duration(hours: 96)]![muscleGroupId]!;
          
          // Should start fatigued or warm and end up ready or warm
          expect([ReadinessLevel.fatigued, ReadinessLevel.warm].contains(initialReadiness), isTrue);
          expect([ReadinessLevel.ready, ReadinessLevel.warm].contains(finalReadiness), isTrue);
          
          // Final readiness should be better than or equal to initial
          expect(finalReadiness.index, lessThanOrEqualTo(initialReadiness.index));
        }
      });
    });

    group('Realistic Training Scenarios', () {
      test('should handle progressive overload scenario', () {
        // Week 1: Baseline workout
        final week1Session = testSession;
        final week1Fatigue = fatigueEngine.distributeFatigueAcrossSession(
          session: week1Session,
          exercises: exercises,
        );
        
        // Week 2: Increased weight (progressive overload)
        final week2Session = testSession.copyWith(
          id: 'session2',
          startTime: DateTime.now().add(const Duration(days: 7)),
          endTime: DateTime.now().add(const Duration(days: 7, hours: 1)),
          sets: testSession.sets.map((set) => 
            set.copyWith(
              id: '${set.id}_week2',
              weight: set.weight + 2.5, // Progressive overload
            )
          ).toList(),
        );
        
        final week2Fatigue = fatigueEngine.distributeFatigueAcrossSession(
          session: week2Session,
          exercises: exercises,
        );
        
        // Week 2 should generate more fatigue due to increased weight
        for (final muscleGroupId in week1Fatigue.keys) {
          if (week2Fatigue.containsKey(muscleGroupId)) {
            expect(week2Fatigue[muscleGroupId]!, greaterThan(week1Fatigue[muscleGroupId]!));
          }
        }
      });

      test('should handle deload week scenario', () {
        // Regular training week
        final regularSession = testSession;
        final regularFatigue = fatigueEngine.distributeFatigueAcrossSession(
          session: regularSession,
          exercises: exercises,
        );
        
        // Deload week (reduced intensity and volume)
        final deloadSession = testSession.copyWith(
          id: 'deload_session',
          sessionType: SessionType.deload,
          sets: testSession.sets.take(3).map((set) => // Fewer sets
            set.copyWith(
              id: '${set.id}_deload',
              weight: set.weight * 0.7, // Reduced weight
              rpe: (set.rpe * 0.7).round(), // Reduced intensity
            )
          ).toList(),
        );
        
        final deloadFatigue = fatigueEngine.distributeFatigueAcrossSession(
          session: deloadSession,
          exercises: exercises,
        );
        
        // Deload should generate significantly less fatigue
        for (final muscleGroupId in regularFatigue.keys) {
          if (deloadFatigue.containsKey(muscleGroupId)) {
            expect(deloadFatigue[muscleGroupId]!, lessThan(regularFatigue[muscleGroupId]! * 0.8));
          }
        }
      });

      test('should handle different muscle group recovery rates', () {
        // Create workout targeting both fast and slow recovering muscles
        final mixedSession = WorkoutSession(
          id: 'mixed_session',
          userId: 'user1',
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now(),
          sessionType: SessionType.hypertrophy,
          createdAt: DateTime.now(),
          sets: [
            // Abs exercise (fast recovery - 24h tau)
            WorkoutSet(
              id: 'abs_set',
              sessionId: 'mixed_session',
              exerciseId: 'squat', // Using squat but will manually set muscle group
              weight: 50.0,
              reps: 15,
              rpe: 8,
              restSeconds: 60,
              setOrder: 1,
              createdAt: DateTime.now(),
            ),
            // Back exercise (slow recovery - 72h tau)
            WorkoutSet(
              id: 'back_set',
              sessionId: 'mixed_session',
              exerciseId: 'squat', // Using squat but will manually set muscle group
              weight: 100.0,
              reps: 8,
              rpe: 8,
              restSeconds: 180,
              setOrder: 2,
              createdAt: DateTime.now(),
            ),
          ],
        );
        
        // Manually calculate fatigue for different muscle groups
        const absFatigue = 100.0;
        const backFatigue = 100.0;
        
        // Simulate recovery after 24 hours
        final absRecovery = recoveryEngine.calculateMuscleGroupFatigue(
          initialFatigue: absFatigue,
          timeSinceWorkout: const Duration(hours: 24),
          muscleGroupId: 'abs',
        );
        
        final backRecovery = recoveryEngine.calculateMuscleGroupFatigue(
          initialFatigue: backFatigue,
          timeSinceWorkout: const Duration(hours: 24),
          muscleGroupId: 'back',
        );
        
        // Abs should recover much faster than back
        expect(absRecovery, lessThan(backRecovery));
        expect(absRecovery / absFatigue, lessThan(backRecovery / backFatigue));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle empty workout session', () {
        final emptySession = testSession.copyWith(sets: []);
        
        final fatigueDistribution = fatigueEngine.distributeFatigueAcrossSession(
          session: emptySession,
          exercises: exercises,
        );
        
        expect(fatigueDistribution, isEmpty);
      });

      test('should handle workout with unknown exercises', () {
        final unknownExerciseSession = testSession.copyWith(
          sets: [
            testSession.sets.first.copyWith(exerciseId: 'unknown_exercise'),
          ],
        );
        
        final fatigueDistribution = fatigueEngine.distributeFatigueAcrossSession(
          session: unknownExerciseSession,
          exercises: exercises,
        );
        
        expect(fatigueDistribution, isEmpty);
      });

      test('should handle recovery state with missing workout time', () {
        final stateWithoutWorkout = RecoveryState(
          id: 'recovery1',
          muscleGroupId: 'quadriceps',
          currentFatigue: 50.0,
          lastUpdated: DateTime.now(),
          readinessLevel: ReadinessLevel.warm,
        );
        
        final updatedState = recoveryEngine.updateRecoveryState(
          currentState: stateWithoutWorkout,
          muscleGroupId: 'quadriceps',
        );
        
        expect(updatedState.currentFatigue, equals(0.0));
        expect(updatedState.readinessLevel, equals(ReadinessLevel.ready));
      });
    });

    group('Performance and Consistency', () {
      test('should maintain mathematical consistency across calculations', () {
        // Test that fatigue calculation is deterministic
        final set = testSession.sets.first;
        final exercise = exercises['squat']!;
        
        final fatigue1 = fatigueEngine.calculateSetFatigueScore(
          set: set,
          exercise: exercise,
          muscleGroupId: 'quadriceps',
        );
        
        final fatigue2 = fatigueEngine.calculateSetFatigueScore(
          set: set,
          exercise: exercise,
          muscleGroupId: 'quadriceps',
        );
        
        expect(fatigue1, equals(fatigue2));
      });

      test('should maintain recovery calculation consistency', () {
        const initialFatigue = 100.0;
        const timeSinceWorkout = Duration(hours: 48);
        const muscleGroupId = 'quadriceps';
        
        final recovery1 = recoveryEngine.calculateMuscleGroupFatigue(
          initialFatigue: initialFatigue,
          timeSinceWorkout: timeSinceWorkout,
          muscleGroupId: muscleGroupId,
        );
        
        final recovery2 = recoveryEngine.calculateMuscleGroupFatigue(
          initialFatigue: initialFatigue,
          timeSinceWorkout: timeSinceWorkout,
          muscleGroupId: muscleGroupId,
        );
        
        expect(recovery1, equals(recovery2));
      });

      test('should handle large datasets efficiently', () {
        // Create a large workout session
        final largeSets = List.generate(100, (index) => 
          WorkoutSet(
            id: 'set_$index',
            sessionId: 'large_session',
            exerciseId: index % 2 == 0 ? 'squat' : 'bench_press',
            weight: 100.0,
            reps: 8,
            rpe: 8,
            restSeconds: 180,
            setOrder: index + 1,
            createdAt: DateTime.now(),
          ),
        );
        
        final largeSession = testSession.copyWith(
          id: 'large_session',
          sets: largeSets,
        );
        
        // Should complete without performance issues
        final stopwatch = Stopwatch()..start();
        
        final fatigueDistribution = fatigueEngine.distributeFatigueAcrossSession(
          session: largeSession,
          exercises: exercises,
        );
        
        stopwatch.stop();
        
        expect(fatigueDistribution, isNotEmpty);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should complete in under 1 second
      });
    });
  });
}