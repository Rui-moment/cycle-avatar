import 'package:flutter_test/flutter_test.dart';
import 'package:cycle_avatar/domain/services/recovery_engine.dart';
import 'package:cycle_avatar/domain/entities/recovery_state.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';
import 'package:cycle_avatar/domain/entities/constants.dart';
import 'dart:math' as math;

void main() {
  group('RecoveryEngine', () {
    late RecoveryEngine recoveryEngine;
    late RecoveryState testRecoveryState;

    setUp(() {
      recoveryEngine = RecoveryEngine();
      
      testRecoveryState = RecoveryState(
        id: 'recovery1',
        muscleGroupId: 'quadriceps',
        currentFatigue: 100.0,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 24)),
        readinessLevel: ReadinessLevel.fatigued,
        lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 24)),
        initialFatigue: 100.0,
      );
    });

    group('calculateCurrentFatigue', () {
      test('should calculate correct fatigue using exponential decay', () {
        const initialFatigue = 100.0;
        const timeSinceWorkout = Duration(hours: 48);
        const recoveryTau = 72.0; // Quadriceps recovery tau
        
        final currentFatigue = recoveryEngine.calculateCurrentFatigue(
          initialFatigue: initialFatigue,
          timeSinceWorkout: timeSinceWorkout,
          recoveryTau: recoveryTau,
        );
        
        // Expected: 100 * e^(-48/72) = 100 * e^(-2/3) ≈ 51.34
        final expected = initialFatigue * math.exp(-48 / 72);
        expect(currentFatigue, closeTo(expected, 0.1));
      });

      test('should return 0 for zero initial fatigue', () {
        final currentFatigue = recoveryEngine.calculateCurrentFatigue(
          initialFatigue: 0.0,
          timeSinceWorkout: const Duration(hours: 24),
          recoveryTau: 48.0,
        );
        
        expect(currentFatigue, equals(0.0));
      });

      test('should return initial fatigue for zero time elapsed', () {
        const initialFatigue = 100.0;
        
        final currentFatigue = recoveryEngine.calculateCurrentFatigue(
          initialFatigue: initialFatigue,
          timeSinceWorkout: Duration.zero,
          recoveryTau: 48.0,
        );
        
        expect(currentFatigue, equals(initialFatigue));
      });

      test('should handle negative time gracefully', () {
        const initialFatigue = 100.0;
        
        final currentFatigue = recoveryEngine.calculateCurrentFatigue(
          initialFatigue: initialFatigue,
          timeSinceWorkout: const Duration(hours: -1),
          recoveryTau: 48.0,
        );
        
        expect(currentFatigue, equals(initialFatigue));
      });
    });

    group('calculateMuscleGroupFatigue', () {
      test('should use correct recovery tau for muscle group', () {
        const initialFatigue = 100.0;
        const timeSinceWorkout = Duration(hours: 48);
        
        final quadricepsFatigue = recoveryEngine.calculateMuscleGroupFatigue(
          initialFatigue: initialFatigue,
          timeSinceWorkout: timeSinceWorkout,
          muscleGroupId: 'quadriceps',
        );
        
        final chestFatigue = recoveryEngine.calculateMuscleGroupFatigue(
          initialFatigue: initialFatigue,
          timeSinceWorkout: timeSinceWorkout,
          muscleGroupId: 'chest',
        );
        
        // Quadriceps has longer recovery tau (72h) than chest (48h)
        // So quadriceps should have higher remaining fatigue
        expect(quadricepsFatigue, greaterThan(chestFatigue));
      });

      test('should use default tau for unknown muscle group', () {
        const initialFatigue = 100.0;
        const timeSinceWorkout = Duration(hours: 48);
        
        final unknownFatigue = recoveryEngine.calculateMuscleGroupFatigue(
          initialFatigue: initialFatigue,
          timeSinceWorkout: timeSinceWorkout,
          muscleGroupId: 'unknown_muscle',
        );
        
        // Should use default tau of 48.0
        final expectedFatigue = initialFatigue * math.exp(-48 / 48);
        expect(unknownFatigue, closeTo(expectedFatigue, 0.1));
      });
    });

    group('determineReadinessLevel', () {
      test('should return Ready for low fatigue', () {
        final readiness = recoveryEngine.determineReadinessLevel(20.0);
        expect(readiness, equals(ReadinessLevel.ready));
      });

      test('should return Warm for medium fatigue', () {
        final readiness = recoveryEngine.determineReadinessLevel(50.0);
        expect(readiness, equals(ReadinessLevel.warm));
      });

      test('should return Fatigued for high fatigue', () {
        final readiness = recoveryEngine.determineReadinessLevel(80.0);
        expect(readiness, equals(ReadinessLevel.fatigued));
      });

      test('should handle boundary values correctly', () {
        expect(recoveryEngine.determineReadinessLevel(READY_THRESHOLD - 0.1), 
               equals(ReadinessLevel.ready));
        expect(recoveryEngine.determineReadinessLevel(READY_THRESHOLD), 
               equals(ReadinessLevel.warm));
        expect(recoveryEngine.determineReadinessLevel(WARM_THRESHOLD - 0.1), 
               equals(ReadinessLevel.warm));
        expect(recoveryEngine.determineReadinessLevel(WARM_THRESHOLD), 
               equals(ReadinessLevel.fatigued));
      });
    });

    group('updateRecoveryState', () {
      test('should update fatigue and readiness based on time passage', () {
        final updatedState = recoveryEngine.updateRecoveryState(
          currentState: testRecoveryState,
          muscleGroupId: 'quadriceps',
          currentTime: DateTime.now(),
        );
        
        // After 24 hours, fatigue should be reduced
        expect(updatedState.currentFatigue, lessThan(testRecoveryState.currentFatigue));
        expect(updatedState.lastUpdated, isAfter(testRecoveryState.lastUpdated));
      });

      test('should handle state with no last workout time', () {
        final stateWithoutWorkout = testRecoveryState.copyWith(
          lastWorkoutTime: null,
        );
        
        final updatedState = recoveryEngine.updateRecoveryState(
          currentState: stateWithoutWorkout,
          muscleGroupId: 'quadriceps',
        );
        
        expect(updatedState.currentFatigue, equals(0.0));
        expect(updatedState.readinessLevel, equals(ReadinessLevel.ready));
      });
    });

    group('calculateRecoveryPercentage', () {
      test('should calculate correct recovery percentage', () {
        final percentage = recoveryEngine.calculateRecoveryPercentage(
          currentFatigue: 25.0,
          initialFatigue: 100.0,
        );
        
        expect(percentage, equals(0.75)); // 75% recovered
      });

      test('should return 1.0 for zero initial fatigue', () {
        final percentage = recoveryEngine.calculateRecoveryPercentage(
          currentFatigue: 0.0,
          initialFatigue: 0.0,
        );
        
        expect(percentage, equals(1.0));
      });

      test('should not exceed 1.0', () {
        final percentage = recoveryEngine.calculateRecoveryPercentage(
          currentFatigue: 0.0,
          initialFatigue: 100.0,
        );
        
        expect(percentage, equals(1.0));
      });
    });

    group('estimateTimeToReadiness', () {
      test('should estimate time to reach Ready level', () {
        final timeToReady = recoveryEngine.estimateTimeToReadiness(
          currentFatigue: 50.0,
          targetReadiness: ReadinessLevel.ready,
          muscleGroupId: 'quadriceps',
        );
        
        expect(timeToReady.inHours, greaterThan(0));
        expect(timeToReady.inHours, lessThan(200)); // Reasonable upper bound
      });

      test('should return zero duration if already at target readiness', () {
        final timeToReady = recoveryEngine.estimateTimeToReadiness(
          currentFatigue: 20.0, // Already ready
          targetReadiness: ReadinessLevel.ready,
          muscleGroupId: 'quadriceps',
        );
        
        expect(timeToReady, equals(Duration.zero));
      });

      test('should handle different muscle groups correctly', () {
        const currentFatigue = 50.0;
        
        final quadricepsTime = recoveryEngine.estimateTimeToReadiness(
          currentFatigue: currentFatigue,
          targetReadiness: ReadinessLevel.ready,
          muscleGroupId: 'quadriceps', // 72h tau
        );
        
        final chestTime = recoveryEngine.estimateTimeToReadiness(
          currentFatigue: currentFatigue,
          targetReadiness: ReadinessLevel.ready,
          muscleGroupId: 'chest', // 48h tau
        );
        
        // Quadriceps should take longer to recover
        expect(quadricepsTime, greaterThan(chestTime));
      });
    });

    group('estimateTimeToFullRecovery', () {
      test('should estimate time to full recovery', () {
        final timeToRecover = recoveryEngine.estimateTimeToFullRecovery(
          currentFatigue: 100.0,
          muscleGroupId: 'quadriceps',
        );
        
        expect(timeToRecover.inHours, greaterThan(0));
        expect(timeToRecover.inHours, lessThan(500)); // Reasonable upper bound
      });

      test('should return zero for already recovered muscle', () {
        final timeToRecover = recoveryEngine.estimateTimeToFullRecovery(
          currentFatigue: 0.5, // Below threshold
          muscleGroupId: 'quadriceps',
        );
        
        expect(timeToRecover, equals(Duration.zero));
      });
    });

    group('calculateRecoveryRate', () {
      test('should calculate correct recovery rate', () {
        final rate = recoveryEngine.calculateRecoveryRate(
          currentFatigue: 72.0,
          muscleGroupId: 'quadriceps', // 72h tau
        );
        
        expect(rate, equals(1.0)); // 72/72 = 1 fatigue unit per hour
      });

      test('should return 0 for zero fatigue', () {
        final rate = recoveryEngine.calculateRecoveryRate(
          currentFatigue: 0.0,
          muscleGroupId: 'quadriceps',
        );
        
        expect(rate, equals(0.0));
      });
    });

    group('isInOptimalRecoveryWindow', () {
      test('should identify optimal recovery window', () {
        // 85% recovered (within 80-95% range)
        final isOptimal = recoveryEngine.isInOptimalRecoveryWindow(
          currentFatigue: 15.0,
          initialFatigue: 100.0,
        );
        
        expect(isOptimal, isTrue);
      });

      test('should reject too early recovery', () {
        // 70% recovered (below 80% threshold)
        final isOptimal = recoveryEngine.isInOptimalRecoveryWindow(
          currentFatigue: 30.0,
          initialFatigue: 100.0,
        );
        
        expect(isOptimal, isFalse);
      });

      test('should reject too late recovery', () {
        // 98% recovered (above 95% threshold)
        final isOptimal = recoveryEngine.isInOptimalRecoveryWindow(
          currentFatigue: 2.0,
          initialFatigue: 100.0,
        );
        
        expect(isOptimal, isFalse);
      });
    });

    group('calculateSupercompensationWindow', () {
      test('should calculate reasonable supercompensation window', () {
        final window = recoveryEngine.calculateSupercompensationWindow(
          initialFatigue: 100.0,
          muscleGroupId: 'quadriceps',
        );
        
        expect(window.start, lessThan(window.peakTime));
        expect(window.peakTime, lessThan(window.end));
        expect(window.start.inHours, greaterThan(0));
        expect(window.end.inHours, lessThan(500));
      });

      test('should handle different muscle groups', () {
        final quadricepsWindow = recoveryEngine.calculateSupercompensationWindow(
          initialFatigue: 100.0,
          muscleGroupId: 'quadriceps', // 72h tau
        );
        
        final chestWindow = recoveryEngine.calculateSupercompensationWindow(
          initialFatigue: 100.0,
          muscleGroupId: 'chest', // 48h tau
        );
        
        // Quadriceps should have later window
        expect(quadricepsWindow.peakTime, greaterThan(chestWindow.peakTime));
      });
    });

    group('updateMultipleRecoveryStates', () {
      test('should update multiple states efficiently', () {
        final states = {
          'quadriceps': testRecoveryState,
          'chest': testRecoveryState.copyWith(
            id: 'recovery2',
            muscleGroupId: 'chest',
          ),
        };
        
        final updatedStates = recoveryEngine.updateMultipleRecoveryStates(
          currentStates: states,
        );
        
        expect(updatedStates.length, equals(2));
        expect(updatedStates.containsKey('quadriceps'), isTrue);
        expect(updatedStates.containsKey('chest'), isTrue);
        
        // All states should be updated
        for (final state in updatedStates.values) {
          expect(state.lastUpdated, isAfter(testRecoveryState.lastUpdated));
        }
      });
    });

    group('calculateAggregateMetrics', () {
      test('should calculate correct aggregate metrics', () {
        final states = {
          'quadriceps': testRecoveryState.copyWith(readinessLevel: ReadinessLevel.ready),
          'chest': testRecoveryState.copyWith(
            id: 'recovery2',
            muscleGroupId: 'chest',
            readinessLevel: ReadinessLevel.warm,
          ),
          'biceps': testRecoveryState.copyWith(
            id: 'recovery3',
            muscleGroupId: 'biceps',
            readinessLevel: ReadinessLevel.fatigued,
          ),
        };
        
        final metrics = recoveryEngine.calculateAggregateMetrics(
          recoveryStates: states,
        );
        
        expect(metrics.totalMuscleGroups, equals(3));
        expect(metrics.readyCount, equals(1));
        expect(metrics.warmCount, equals(1));
        expect(metrics.fatiguedCount, equals(1));
        expect(metrics.averageRecoveryPercentage, greaterThan(0.0));
        expect(metrics.averageRecoveryPercentage, lessThanOrEqualTo(1.0));
      });

      test('should handle empty states', () {
        final metrics = recoveryEngine.calculateAggregateMetrics(
          recoveryStates: {},
        );
        
        expect(metrics.totalMuscleGroups, equals(0));
        expect(metrics.readyCount, equals(0));
        expect(metrics.warmCount, equals(0));
        expect(metrics.fatiguedCount, equals(0));
        expect(metrics.averageRecoveryPercentage, equals(1.0));
        expect(metrics.overallReadinessLevel, equals(ReadinessLevel.ready));
      });

      test('should determine overall readiness correctly', () {
        // Majority ready
        final mostlyReadyStates = {
          'muscle1': testRecoveryState.copyWith(readinessLevel: ReadinessLevel.ready),
          'muscle2': testRecoveryState.copyWith(readinessLevel: ReadinessLevel.ready),
          'muscle3': testRecoveryState.copyWith(readinessLevel: ReadinessLevel.warm),
        };
        
        final mostlyReadyMetrics = recoveryEngine.calculateAggregateMetrics(
          recoveryStates: mostlyReadyStates,
        );
        
        expect(mostlyReadyMetrics.overallReadinessLevel, equals(ReadinessLevel.ready));
        
        // Significant portion fatigued
        final mostlyFatiguedStates = {
          'muscle1': testRecoveryState.copyWith(readinessLevel: ReadinessLevel.fatigued),
          'muscle2': testRecoveryState.copyWith(readinessLevel: ReadinessLevel.fatigued),
          'muscle3': testRecoveryState.copyWith(readinessLevel: ReadinessLevel.ready),
        };
        
        final mostlyFatiguedMetrics = recoveryEngine.calculateAggregateMetrics(
          recoveryStates: mostlyFatiguedStates,
        );
        
        expect(mostlyFatiguedMetrics.overallReadinessLevel, equals(ReadinessLevel.fatigued));
      });
    });

    group('Edge Cases and Mathematical Accuracy', () {
      test('should handle very small fatigue values', () {
        final currentFatigue = recoveryEngine.calculateCurrentFatigue(
          initialFatigue: 0.001,
          timeSinceWorkout: const Duration(hours: 100),
          recoveryTau: 48.0,
        );
        
        expect(currentFatigue, greaterThanOrEqualTo(0.0));
        expect(currentFatigue, lessThan(0.001));
      });

      test('should handle very large fatigue values', () {
        final currentFatigue = recoveryEngine.calculateCurrentFatigue(
          initialFatigue: 10000.0,
          timeSinceWorkout: const Duration(hours: 1),
          recoveryTau: 48.0,
        );
        
        expect(currentFatigue, greaterThan(0.0));
        expect(currentFatigue, lessThan(10000.0));
      });

      test('should maintain mathematical consistency', () {
        const initialFatigue = 100.0;
        const recoveryTau = 48.0;
        
        // After one tau period, fatigue should be ~36.8% of initial
        final fatigueAfterOneTau = recoveryEngine.calculateCurrentFatigue(
          initialFatigue: initialFatigue,
          timeSinceWorkout: const Duration(hours: 48),
          recoveryTau: recoveryTau,
        );
        
        final expectedAfterOneTau = initialFatigue * math.exp(-1);
        expect(fatigueAfterOneTau, closeTo(expectedAfterOneTau, 0.1));
        
        // After two tau periods, fatigue should be ~13.5% of initial
        final fatigueAfterTwoTau = recoveryEngine.calculateCurrentFatigue(
          initialFatigue: initialFatigue,
          timeSinceWorkout: const Duration(hours: 96),
          recoveryTau: recoveryTau,
        );
        
        final expectedAfterTwoTau = initialFatigue * math.exp(-2);
        expect(fatigueAfterTwoTau, closeTo(expectedAfterTwoTau, 0.1));
      });
    });
  });

  group('SupercompensationWindow', () {
    test('should correctly identify if time is within window', () {
      final window = SupercompensationWindow(
        start: const Duration(hours: 48),
        end: const Duration(hours: 96),
        peakTime: const Duration(hours: 72),
      );
      
      expect(window.isWithinWindow(const Duration(hours: 60)), isTrue);
      expect(window.isWithinWindow(const Duration(hours: 30)), isFalse);
      expect(window.isWithinWindow(const Duration(hours: 100)), isFalse);
    });

    test('should correctly identify peak time', () {
      final window = SupercompensationWindow(
        start: const Duration(hours: 48),
        end: const Duration(hours: 96),
        peakTime: const Duration(hours: 72),
      );
      
      expect(window.isAtPeak(const Duration(hours: 72)), isTrue);
      expect(window.isAtPeak(const Duration(hours: 73)), isTrue); // Within tolerance
      expect(window.isAtPeak(const Duration(hours: 80)), isFalse);
    });
  });

  group('AggregateRecoveryMetrics', () {
    test('should calculate percentages correctly', () {
      final metrics = AggregateRecoveryMetrics(
        averageRecoveryPercentage: 0.75,
        readyCount: 3,
        warmCount: 1,
        fatiguedCount: 1,
        totalMuscleGroups: 5,
        overallReadinessLevel: ReadinessLevel.ready,
      );
      
      expect(metrics.readyPercentage, equals(0.6)); // 3/5
      expect(metrics.fatiguedPercentage, equals(0.2)); // 1/5
      expect(metrics.isSuitableForTraining, isTrue);
    });

    test('should handle zero muscle groups', () {
      final metrics = AggregateRecoveryMetrics(
        averageRecoveryPercentage: 1.0,
        readyCount: 0,
        warmCount: 0,
        fatiguedCount: 0,
        totalMuscleGroups: 0,
        overallReadinessLevel: ReadinessLevel.ready,
      );
      
      expect(metrics.readyPercentage, equals(0.0));
      expect(metrics.fatiguedPercentage, equals(0.0));
    });
  });
}