import 'package:flutter_test/flutter_test.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';
import 'package:cycle_avatar/domain/entities/constants.dart';
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/exercise.dart';
import 'package:cycle_avatar/domain/services/plan_generator.dart';

void main() {
  group('PlanGenerator Tests', () {
    late PlanGenerator planGenerator;
    late Map<String, Exercise> testExercises;
    late Map<String, ReadinessLevel> testReadiness;

    setUp(() {
      planGenerator = PlanGenerator();
      testExercises = _createTestExercises();
      testReadiness = _createTestReadiness();
    });

    group('generateNextSession', () {
      test('should generate hypertrophy plan with correct rep ranges', () {
        // Given: Ready muscle groups and hypertrophy goal
        final readiness = {
          'chest': ReadinessLevel.ready,
          'triceps': ReadinessLevel.ready,
          'shoulders': ReadinessLevel.ready,
        };

        // When: Generate hypertrophy plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.hypertrophy,
          recentSessions: [],
          availableExercises: testExercises,
        );

        // Then: Plan should have hypertrophy characteristics
        expect(plan.sessionType, SessionType.hypertrophy);
        expect(plan.exercises.isNotEmpty, true);
        
        for (final exercise in plan.exercises) {
          expect(exercise.repRange.min, greaterThanOrEqualTo(8));
          expect(exercise.repRange.max, lessThanOrEqualTo(12));
          expect(exercise.rpeRange.min, greaterThanOrEqualTo(7));
          expect(exercise.rpeRange.max, lessThanOrEqualTo(9));
        }
      });

      test('should generate strength plan with correct rep ranges', () {
        // Given: Ready muscle groups and strength goal
        final readiness = {
          'quadriceps': ReadinessLevel.ready,
          'glutes': ReadinessLevel.ready,
          'hamstrings': ReadinessLevel.ready,
        };

        // When: Generate strength plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.strength,
          recentSessions: [],
          availableExercises: testExercises,
        );

        // Then: Plan should have strength characteristics
        expect(plan.sessionType, SessionType.strength);
        expect(plan.exercises.isNotEmpty, true);
        
        for (final exercise in plan.exercises) {
          expect(exercise.repRange.min, greaterThanOrEqualTo(1));
          expect(exercise.repRange.max, lessThanOrEqualTo(5));
          expect(exercise.rpeRange.min, greaterThanOrEqualTo(8));
          expect(exercise.rpeRange.max, lessThanOrEqualTo(10));
          expect(exercise.restSeconds, greaterThanOrEqualTo(180)); // Longer rest for strength
        }
      });

      test('should generate general plan with balanced parameters', () {
        // Given: Ready muscle groups and general goal
        final readiness = {
          'back': ReadinessLevel.ready,
          'biceps': ReadinessLevel.ready,
        };

        // When: Generate general plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.general,
          recentSessions: [],
          availableExercises: testExercises,
        );

        // Then: Plan should have general fitness characteristics
        expect(plan.exercises.isNotEmpty, true);
        
        for (final exercise in plan.exercises) {
          expect(exercise.repRange.min, greaterThanOrEqualTo(6));
          expect(exercise.repRange.max, lessThanOrEqualTo(15));
          expect(exercise.rpeRange.min, greaterThanOrEqualTo(6));
          expect(exercise.rpeRange.max, lessThanOrEqualTo(8));
        }
      });

      test('should recommend rest day when no muscle groups are ready', () {
        // Given: All muscle groups fatigued
        final readiness = {
          'chest': ReadinessLevel.fatigued,
          'back': ReadinessLevel.fatigued,
          'quadriceps': ReadinessLevel.fatigued,
        };

        // When: Generate plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.hypertrophy,
          recentSessions: [],
          availableExercises: testExercises,
        );

        // Then: Should recommend rest day
        expect(plan.isRestDay, true);
        expect(plan.exercises.isEmpty, true);
        expect(plan.nextRecommendedTime, isNotNull);
      });

      test('should generate deload plan when deload is needed', () {
        // Given: High volume recent sessions indicating deload need
        final highVolumeSessions = _createHighVolumeSessions();
        final readiness = {
          'chest': ReadinessLevel.warm,
          'back': ReadinessLevel.warm,
        };

        // When: Generate plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.hypertrophy,
          recentSessions: highVolumeSessions,
          availableExercises: testExercises,
        );

        // Then: Should generate deload plan
        expect(plan.sessionType, SessionType.deload);
        
        for (final exercise in plan.exercises) {
          expect(exercise.sets, lessThanOrEqualTo(2)); // Reduced sets
          expect(exercise.rpeRange.max, lessThanOrEqualTo(7)); // Reduced intensity
        }
      });

      test('should prioritize compound exercises', () {
        // Given: Ready muscle groups
        final readiness = {
          'chest': ReadinessLevel.ready,
          'triceps': ReadinessLevel.ready,
        };

        // When: Generate plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.strength,
          recentSessions: [],
          availableExercises: testExercises,
        );

        // Then: Should prioritize compound exercises
        final compoundExercises = plan.exercises
            .where((rec) => rec.exercise.isCompound)
            .length;
        final totalExercises = plan.exercises.length;
        
        expect(compoundExercises / totalExercises, greaterThan(0.5));
      });

      test('should avoid recently used exercises', () {
        // Given: Recent sessions with specific exercises
        final recentSessions = [
          _createTestSession(exerciseIds: ['bench_press', 'squat']),
        ];
        final readiness = {
          'chest': ReadinessLevel.ready,
          'quadriceps': ReadinessLevel.ready,
        };

        // When: Generate plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.hypertrophy,
          recentSessions: recentSessions,
          availableExercises: testExercises,
        );

        // Then: Should avoid recently used exercises
        final usedExerciseIds = plan.exercises.map((rec) => rec.exercise.id).toList();
        expect(usedExerciseIds.contains('bench_press'), false);
        expect(usedExerciseIds.contains('squat'), false);
      });
    });

    group('shouldDeload', () {
      test('should return false with insufficient training history', () {
        // Given: Few recent sessions
        final sessions = [_createTestSession()];

        // When: Check deload need
        final shouldDeload = planGenerator.shouldDeload(recentSessions: sessions);

        // Then: Should not recommend deload
        expect(shouldDeload, false);
      });

      test('should return true with excessive volume increase', () {
        // Given: Sessions showing high volume increase
        final sessions = _createProgressiveVolumeSessions();

        // When: Check deload need
        final shouldDeload = planGenerator.shouldDeload(recentSessions: sessions);

        // Then: Should recommend deload
        expect(shouldDeload, true);
      });

      test('should return true with high fatigue in multiple muscle groups', () {
        // Given: Multiple sessions and high fatigue
        final sessions = _createModerateVolumeSessions();
        final highFatigue = {
          'chest': 85.0,
          'back': 90.0,
          'quadriceps': 88.0,
          'shoulders': 82.0,
        };

        // When: Check deload need
        final shouldDeload = planGenerator.shouldDeload(
          recentSessions: sessions,
          currentFatigue: highFatigue,
        );

        // Then: Should recommend deload
        expect(shouldDeload, true);
      });

      test('should return false with moderate volume and low fatigue', () {
        // Given: Moderate sessions and low fatigue
        final sessions = _createModerateVolumeSessions();
        final lowFatigue = {
          'chest': 25.0,
          'back': 30.0,
          'quadriceps': 20.0,
        };

        // When: Check deload need
        final shouldDeload = planGenerator.shouldDeload(
          recentSessions: sessions,
          currentFatigue: lowFatigue,
        );

        // Then: Should not recommend deload
        expect(shouldDeload, false);
      });
    });

    group('exercise selection', () {
      test('should select exercises targeting ready muscle groups', () {
        // Given: Specific ready muscle groups
        final readiness = {
          'chest': ReadinessLevel.ready,
          'triceps': ReadinessLevel.ready,
          'back': ReadinessLevel.fatigued, // Should be avoided
        };

        // When: Generate plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.hypertrophy,
          recentSessions: [],
          availableExercises: testExercises,
        );

        // Then: Should only target ready muscle groups
        for (final exerciseRec in plan.exercises) {
          final exercise = exerciseRec.exercise;
          final targetsReadyMuscles = exercise.primaryMuscleGroups
              .any((mg) => readiness[mg] == ReadinessLevel.ready);
          expect(targetsReadyMuscles, true);
        }
      });

      test('should limit number of exercises appropriately', () {
        // Given: Many ready muscle groups
        final readiness = {
          'chest': ReadinessLevel.ready,
          'back': ReadinessLevel.ready,
          'quadriceps': ReadinessLevel.ready,
          'hamstrings': ReadinessLevel.ready,
          'shoulders': ReadinessLevel.ready,
          'biceps': ReadinessLevel.ready,
          'triceps': ReadinessLevel.ready,
        };

        // When: Generate plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.hypertrophy,
          recentSessions: [],
          availableExercises: testExercises,
        );

        // Then: Should limit exercises to reasonable number
        expect(plan.exercises.length, lessThanOrEqualTo(6));
        expect(plan.exercises.length, greaterThanOrEqualTo(3));
      });
    });

    group('plan characteristics', () {
      test('should estimate reasonable session duration', () {
        // Given: Ready muscle groups
        final readiness = {
          'chest': ReadinessLevel.ready,
          'triceps': ReadinessLevel.ready,
        };

        // When: Generate plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.hypertrophy,
          recentSessions: [],
          availableExercises: testExercises,
        );

        // Then: Should have reasonable duration
        expect(plan.estimatedDuration.inMinutes, greaterThan(30));
        expect(plan.estimatedDuration.inMinutes, lessThan(120));
      });

      test('should provide meaningful reasoning', () {
        // Given: Ready muscle groups
        final readiness = {
          'quadriceps': ReadinessLevel.ready,
        };

        // When: Generate plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.strength,
          recentSessions: [],
          availableExercises: testExercises,
        );

        // Then: Should have meaningful reasoning
        expect(plan.reasoning.isNotEmpty, true);
        expect(plan.reasoning.toLowerCase().contains('strength'), true);
      });

      test('should calculate estimated volume correctly', () {
        // Given: Ready muscle groups
        final readiness = {
          'chest': ReadinessLevel.ready,
        };

        // When: Generate plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.hypertrophy,
          recentSessions: [],
          availableExercises: testExercises,
        );

        // Then: Should have positive estimated volume
        expect(plan.estimatedVolume, greaterThan(0));
      });
    });

    group('edge cases', () {
      test('should handle empty exercise database', () {
        // Given: Empty exercise database
        final readiness = {'chest': ReadinessLevel.ready};

        // When: Generate plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.hypertrophy,
          recentSessions: [],
          availableExercises: {},
        );

        // Then: Should handle gracefully
        expect(plan.exercises.isEmpty, true);
      });

      test('should handle empty readiness map', () {
        // Given: Empty readiness map
        final readiness = <String, ReadinessLevel>{};

        // When: Generate plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.hypertrophy,
          recentSessions: [],
          availableExercises: testExercises,
        );

        // Then: Should recommend rest day
        expect(plan.isRestDay, true);
      });

      test('should handle all muscle groups in warm state', () {
        // Given: All muscle groups warm
        final readiness = {
          'chest': ReadinessLevel.warm,
          'back': ReadinessLevel.warm,
          'quadriceps': ReadinessLevel.warm,
        };

        // When: Generate plan
        final plan = planGenerator.generateNextSession(
          muscleGroupReadiness: readiness,
          goal: TrainingGoal.hypertrophy,
          recentSessions: [],
          availableExercises: testExercises,
        );

        // Then: Should recommend rest day (no ready muscle groups)
        expect(plan.isRestDay, true);
      });
    });
  });
}

/// Helper function to create test exercises
Map<String, Exercise> _createTestExercises() {
  return {
    'bench_press': Exercise(
      id: 'bench_press',
      names: {'en': 'Bench Press', 'ja': 'ベンチプレス'},
      category: 'chest',
      equipment: EquipmentType.barbell,
      instructions: {'en': 'Press the barbell', 'ja': 'バーベルを押す'},
      primaryMuscleGroups: ['chest'],
      secondaryMuscleGroups: ['triceps', 'shoulders'],
      isCompound: true,
      createdAt: DateTime.now(),
    ),
    'squat': Exercise(
      id: 'squat',
      names: {'en': 'Squat', 'ja': 'スクワット'},
      category: 'legs',
      equipment: EquipmentType.barbell,
      instructions: {'en': 'Squat down', 'ja': 'しゃがむ'},
      primaryMuscleGroups: ['quadriceps'],
      secondaryMuscleGroups: ['glutes', 'hamstrings'],
      isCompound: true,
      createdAt: DateTime.now(),
    ),
    'deadlift': Exercise(
      id: 'deadlift',
      names: {'en': 'Deadlift', 'ja': 'デッドリフト'},
      category: 'back',
      equipment: EquipmentType.barbell,
      instructions: {'en': 'Lift the bar', 'ja': 'バーを持ち上げる'},
      primaryMuscleGroups: ['back'],
      secondaryMuscleGroups: ['hamstrings', 'glutes'],
      isCompound: true,
      createdAt: DateTime.now(),
    ),
    'bicep_curl': Exercise(
      id: 'bicep_curl',
      names: {'en': 'Bicep Curl', 'ja': 'バイセップカール'},
      category: 'arms',
      equipment: EquipmentType.dumbbell,
      instructions: {'en': 'Curl the weight', 'ja': 'ウェイトをカールする'},
      primaryMuscleGroups: ['biceps'],
      secondaryMuscleGroups: [],
      isCompound: false,
      createdAt: DateTime.now(),
    ),
    'tricep_extension': Exercise(
      id: 'tricep_extension',
      names: {'en': 'Tricep Extension', 'ja': 'トライセップエクステンション'},
      category: 'arms',
      equipment: EquipmentType.dumbbell,
      instructions: {'en': 'Extend the weight', 'ja': 'ウェイトを伸ばす'},
      primaryMuscleGroups: ['triceps'],
      secondaryMuscleGroups: [],
      isCompound: false,
      createdAt: DateTime.now(),
    ),
  };
}

/// Helper function to create test readiness levels
Map<String, ReadinessLevel> _createTestReadiness() {
  return {
    'chest': ReadinessLevel.ready,
    'back': ReadinessLevel.warm,
    'quadriceps': ReadinessLevel.fatigued,
    'hamstrings': ReadinessLevel.ready,
    'glutes': ReadinessLevel.ready,
    'shoulders': ReadinessLevel.warm,
    'biceps': ReadinessLevel.ready,
    'triceps': ReadinessLevel.ready,
  };
}

/// Helper function to create a test workout session
WorkoutSession _createTestSession({
  List<String>? exerciseIds,
  double volumeMultiplier = 1.0,
  DateTime? startTime,
}) {
  final ids = exerciseIds ?? ['bench_press'];
  final sets = ids.map((id) => WorkoutSet(
    id: '${id}_set_1',
    sessionId: 'test_session',
    exerciseId: id,
    weight: 100.0 * volumeMultiplier,
    reps: 10,
    rpe: 8,
    setOrder: 1,
    createdAt: DateTime.now(),
  )).toList();

  return WorkoutSession(
    id: 'test_session',
    userId: 'test_user',
    startTime: startTime ?? DateTime.now().subtract(const Duration(days: 1)),
    endTime: startTime?.add(const Duration(hours: 1)) ?? DateTime.now().subtract(const Duration(hours: 23)),
    sessionType: SessionType.hypertrophy,
    createdAt: DateTime.now(),
    sets: sets,
  );
}

/// Helper function to create high volume sessions for deload testing
List<WorkoutSession> _createHighVolumeSessions() {
  final sessions = <WorkoutSession>[];
  final now = DateTime.now();
  
  // Create 12 sessions over 4 weeks with increasing volume
  for (int i = 0; i < 12; i++) {
    final sessionDate = now.subtract(Duration(days: (12 - i) * 2));
    final volumeMultiplier = 1.0 + (i * 0.1); // 10% increase per session
    
    sessions.add(_createTestSession(
      exerciseIds: ['bench_press', 'squat'],
      volumeMultiplier: volumeMultiplier,
      startTime: sessionDate,
    ));
  }
  
  return sessions;
}

/// Helper function to create progressive volume sessions
List<WorkoutSession> _createProgressiveVolumeSessions() {
  final sessions = <WorkoutSession>[];
  final now = DateTime.now();
  
  // Create sessions with 25% volume increase over 4 weeks
  for (int week = 0; week < 4; week++) {
    for (int session = 0; session < 3; session++) {
      final sessionDate = now.subtract(Duration(days: (4 - week) * 7 - session * 2));
      final volumeMultiplier = 1.0 + (week * 0.08); // 8% increase per week
      
      sessions.add(_createTestSession(
        volumeMultiplier: volumeMultiplier,
        startTime: sessionDate,
      ));
    }
  }
  
  return sessions;
}

/// Helper function to create moderate volume sessions
List<WorkoutSession> _createModerateVolumeSessions() {
  final sessions = <WorkoutSession>[];
  final now = DateTime.now();
  
  // Create sessions with stable volume
  for (int i = 0; i < 10; i++) {
    final sessionDate = now.subtract(Duration(days: i * 3));
    sessions.add(_createTestSession(
      volumeMultiplier: 1.0,
      startTime: sessionDate,
    ));
  }
  
  return sessions;
}