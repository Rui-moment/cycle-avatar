import 'package:flutter_test/flutter_test.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';
import 'package:cycle_avatar/domain/entities/constants.dart';
import 'package:cycle_avatar/domain/entities/avatar_state.dart';
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/exercise.dart';
import 'package:cycle_avatar/domain/entities/recovery_state.dart';
import 'package:cycle_avatar/domain/entities/pr_record.dart';
import 'package:cycle_avatar/domain/services/avatar_system.dart';
import 'package:cycle_avatar/domain/services/badge_system.dart';

void main() {
  group('Avatar Growth Integration Tests', () {
    late AvatarSystem avatarSystem;
    late BadgeSystem badgeSystem;
    late AvatarState initialAvatarState;
    late Map<String, Exercise> exercises;

    setUp(() {
      avatarSystem = AvatarSystem();
      badgeSystem = BadgeSystem();
      
      // Create initial avatar state for a new user
      initialAvatarState = AvatarState.fresh(
        id: 'test_avatar',
        userId: 'test_user',
        muscleGroupIds: ['chest', 'triceps', 'shoulders', 'back', 'biceps', 'legs'],
      );

      // Create test exercises
      exercises = {
        'bench_press': Exercise(
          id: 'bench_press',
          names: {'en': 'Bench Press', 'ja': 'ベンチプレス'},
          category: 'chest',
          equipment: EquipmentType.barbell,
          primaryMuscleGroups: ['chest'],
          secondaryMuscleGroups: ['triceps', 'shoulders'],
          instructions: {'en': 'Bench press instructions', 'ja': 'ベンチプレスの説明'},
          isCompound: true,
          createdAt: DateTime.now(),
        ),
        'squat': Exercise(
          id: 'squat',
          names: {'en': 'Squat', 'ja': 'スクワット'},
          category: 'legs',
          equipment: EquipmentType.barbell,
          primaryMuscleGroups: ['legs'],
          secondaryMuscleGroups: [],
          instructions: {'en': 'Squat instructions', 'ja': 'スクワットの説明'},
          isCompound: true,
          createdAt: DateTime.now(),
        ),
        'pull_up': Exercise(
          id: 'pull_up',
          names: {'en': 'Pull Up', 'ja': '懸垂'},
          category: 'back',
          equipment: EquipmentType.bodyweight,
          primaryMuscleGroups: ['back'],
          secondaryMuscleGroups: ['biceps'],
          instructions: {'en': 'Pull up instructions', 'ja': '懸垂の説明'},
          isCompound: true,
          createdAt: DateTime.now(),
        ),
      };
    });

    group('Complete Workout Progression Scenario', () {
      test('should handle complete workout progression with optimal recovery', () {
        var currentAvatarState = initialAvatarState;
        final allSessions = <WorkoutSession>[];
        final prRecords = <PRRecord>[];

        // Simulate 4 weeks of progressive training
        for (int week = 0; week < 4; week++) {
          for (int day = 0; day < 3; day++) { // 3 workouts per week
            final sessionDate = DateTime.now().subtract(
              Duration(days: (3 - week) * 7 + (2 - day)),
            );

            // Create progressive workout session
            final session = _createProgressiveSession(
              sessionId: 'session_${week}_$day',
              sessionDate: sessionDate,
              week: week,
              day: day,
            );

            allSessions.add(session);

            // Simulate optimal recovery state (all muscle groups ready)
            final preWorkoutReadiness = <String, ReadinessLevel>{};
            for (final muscleGroupId in currentAvatarState.muscleGroupLevels.keys) {
              preWorkoutReadiness[muscleGroupId] = ReadinessLevel.ready;
            }

            // Update avatar after workout
            final updateResult = avatarSystem.updateAvatarComprehensive(
              currentState: currentAvatarState,
              session: session,
              preWorkoutReadiness: preWorkoutReadiness,
              exercises: exercises,
              previousSessions: allSessions.take(allSessions.length - 1).toList(),
              prRecords: prRecords,
              currentStreak: allSessions.length,
            );

            currentAvatarState = updateResult.updatedState;

            // Verify progression was achieved (except for first session)
            if (allSessions.length > 1) {
              expect(updateResult.achievedProgression, isTrue,
                  reason: 'Should achieve progression in week $week, day $day');
            }

            // Verify growth points were awarded for progression
            if (updateResult.achievedProgression) {
              expect(currentAvatarState.totalGrowthPoints, 
                     greaterThan(initialAvatarState.totalGrowthPoints),
                     reason: 'Should have growth points after progression');
            }

            // Check for level-ups
            if (updateResult.hasLevelUps) {
              print('Level-ups in week $week, day $day: ${updateResult.levelUps}');
            }

            // Check for new badges
            if (updateResult.hasNewBadges) {
              print('New badges in week $week, day $day: ${updateResult.newBadges}');
            }
          }
        }

        // Verify final state
        expect(currentAvatarState.totalGrowthPoints, 
               greaterThan(initialAvatarState.totalGrowthPoints));
        expect(currentAvatarState.maxLevel, greaterThan(0));
        expect(currentAvatarState.unlockedBadges, isNotEmpty);
        
        // Should have first workout badge
        expect(currentAvatarState.unlockedBadges, 
               contains(BadgeSystem.FIRST_WORKOUT));
        
        // Should have some level progression
        final chestLevel = currentAvatarState.getLevelForMuscleGroup('chest');
        expect(chestLevel, greaterThan(0));
      });

      test('should handle overtraining scenario with cooldowns', () {
        var currentAvatarState = initialAvatarState;
        final allSessions = <WorkoutSession>[];

        // Simulate overtraining scenario
        for (int day = 0; day < 7; day++) { // Daily training (overtraining)
          final sessionDate = DateTime.now().subtract(Duration(days: 6 - day));

          final session = _createProgressiveSession(
            sessionId: 'session_$day',
            sessionDate: sessionDate,
            week: 0,
            day: day,
          );

          allSessions.add(session);

          // Simulate fatigued state (overtraining)
          final preWorkoutReadiness = <String, ReadinessLevel>{};
          for (final muscleGroupId in currentAvatarState.muscleGroupLevels.keys) {
            preWorkoutReadiness[muscleGroupId] = ReadinessLevel.fatigued;
          }

          // Update avatar after workout
          final updateResult = avatarSystem.updateAvatarComprehensive(
            currentState: currentAvatarState,
            session: session,
            preWorkoutReadiness: preWorkoutReadiness,
            exercises: exercises,
            previousSessions: allSessions.take(allSessions.length - 1).toList(),
            prRecords: [],
            currentStreak: allSessions.length,
          );

          currentAvatarState = updateResult.updatedState;

          // After a few sessions, should have cooldowns applied
          if (day > 2) {
            expect(currentAvatarState.muscleGroupsInCooldown, isNotEmpty,
                   reason: 'Should have cooldowns after overtraining');
          }
        }

        // Verify cooldowns were applied
        expect(currentAvatarState.muscleGroupsInCooldown.length, greaterThan(0));
        
        // Growth should be reduced due to overtraining penalties
        final totalGrowthPoints = currentAvatarState.totalGrowthPoints;
        expect(totalGrowthPoints, greaterThan(0)); // Still some growth
        
        // But levels should be lower than optimal training
        final maxLevel = currentAvatarState.maxLevel;
        expect(maxLevel, lessThanOrEqualTo(2)); // Limited due to penalties
      });

      test('should handle mixed recovery states realistically', () {
        var currentAvatarState = initialAvatarState;
        final allSessions = <WorkoutSession>[];

        // Simulate realistic mixed recovery scenario
        for (int session = 0; session < 10; session++) {
          final sessionDate = DateTime.now().subtract(Duration(days: 20 - session * 2));

          final workoutSession = _createProgressiveSession(
            sessionId: 'session_$session',
            sessionDate: sessionDate,
            week: session ~/ 3,
            day: session % 3,
          );

          allSessions.add(workoutSession);

          // Simulate realistic mixed recovery states
          final preWorkoutReadiness = <String, ReadinessLevel>{
            'chest': session % 3 == 0 ? ReadinessLevel.ready : ReadinessLevel.warm,
            'triceps': session % 2 == 0 ? ReadinessLevel.ready : ReadinessLevel.fatigued,
            'shoulders': ReadinessLevel.warm,
            'back': session % 4 == 0 ? ReadinessLevel.ready : ReadinessLevel.warm,
            'biceps': ReadinessLevel.ready,
            'legs': session % 3 == 1 ? ReadinessLevel.ready : ReadinessLevel.warm,
          };

          // Update avatar
          final updateResult = avatarSystem.updateAvatarComprehensive(
            currentState: currentAvatarState,
            session: workoutSession,
            preWorkoutReadiness: preWorkoutReadiness,
            exercises: exercises,
            previousSessions: allSessions.take(allSessions.length - 1).toList(),
            prRecords: [],
            currentStreak: session + 1,
          );

          currentAvatarState = updateResult.updatedState;

          // Verify realistic progression
          if (session > 0) {
            // Should have some progression most of the time
            final progressionRate = allSessions
                .map((s) => avatarSystem.hasAchievedProgression(
                      currentSession: s,
                      previousSessions: allSessions.where((prev) => prev != s).toList(),
                      exercises: exercises,
                    ))
                .where((achieved) => achieved)
                .length / allSessions.length;
            
            expect(progressionRate, greaterThan(0.5)); // At least 50% progression rate
          }
        }

        // Verify balanced growth
        expect(currentAvatarState.totalGrowthPoints, greaterThan(0));
        expect(currentAvatarState.maxLevel, greaterThan(0));
        
        // Should have some variety in muscle group levels
        final levels = currentAvatarState.muscleGroupLevels.values.toList();
        final minLevel = levels.reduce((a, b) => a < b ? a : b);
        final maxLevel = levels.reduce((a, b) => a > b ? a : b);
        expect(maxLevel - minLevel, lessThanOrEqualTo(3)); // Balanced development
      });
    });

    group('Badge Progression Integration', () {
      test('should award badges progressively through training journey', () {
        var currentAvatarState = initialAvatarState;
        final allSessions = <WorkoutSession>[];
        final prRecords = <PRRecord>[];

        // Track badge progression
        final badgeTimeline = <String, int>{}; // badge -> session number

        // Simulate extended training period
        for (int session = 0; session < 50; session++) {
          final sessionDate = DateTime.now().subtract(Duration(days: 100 - session * 2));

          final workoutSession = _createProgressiveSession(
            sessionId: 'session_$session',
            sessionDate: sessionDate,
            week: session ~/ 3,
            day: session % 3,
          );

          allSessions.add(workoutSession);

          // Add PR records occasionally
          if (session % 5 == 0 && session > 0) {
            prRecords.add(PRRecord(
              id: 'pr_$session',
              userId: 'test_user',
              exerciseId: 'bench_press',
              weight: 80.0 + session * 2.5,
              reps: 8,
              estimatedMax: 100.0 + session * 3.0,
              achievedAt: sessionDate,
            ));
          }

          // Optimal recovery for consistent progression
          final preWorkoutReadiness = <String, ReadinessLevel>{};
          for (final muscleGroupId in currentAvatarState.muscleGroupLevels.keys) {
            preWorkoutReadiness[muscleGroupId] = ReadinessLevel.ready;
          }

          // Update avatar
          final updateResult = avatarSystem.updateAvatarComprehensive(
            currentState: currentAvatarState,
            session: workoutSession,
            preWorkoutReadiness: preWorkoutReadiness,
            exercises: exercises,
            previousSessions: allSessions.take(allSessions.length - 1).toList(),
            prRecords: prRecords,
            currentStreak: session + 1,
          );

          currentAvatarState = updateResult.updatedState;

          // Track new badges
          for (final badge in updateResult.newBadges) {
            badgeTimeline[badge] = session;
          }
        }

        // Verify badge progression
        expect(badgeTimeline[BadgeSystem.FIRST_WORKOUT], equals(0));
        expect(badgeTimeline[BadgeSystem.FIRST_PR], isNotNull);
        
        // Should have volume milestone badges
        expect(badgeTimeline.keys, contains(BadgeSystem.VOLUME_MILESTONE_1000));
        
        // Should have level-based badges
        if (currentAvatarState.maxLevel >= 10) {
          expect(badgeTimeline.keys, contains(BadgeSystem.LEVEL_10_MUSCLE));
        }

        print('Badge timeline: $badgeTimeline');
        print('Final avatar state: ${currentAvatarState.muscleGroupLevels}');
        print('Total badges: ${currentAvatarState.unlockedBadges.length}');
      });
    });

    group('Edge Cases and Boundary Conditions', () {
      test('should handle zero progression gracefully', () {
        final session = _createProgressiveSession(
          sessionId: 'test_session',
          sessionDate: DateTime.now(),
          week: 0,
          day: 0,
        );

        // Create identical previous session (no progression)
        final identicalPreviousSession = _createProgressiveSession(
          sessionId: 'prev_session',
          sessionDate: DateTime.now().subtract(const Duration(days: 2)),
          week: 0,
          day: 0,
        );

        final preWorkoutReadiness = <String, ReadinessLevel>{
          'chest': ReadinessLevel.ready,
          'triceps': ReadinessLevel.ready,
          'shoulders': ReadinessLevel.ready,
        };

        final updateResult = avatarSystem.updateAvatarComprehensive(
          currentState: initialAvatarState,
          session: session,
          preWorkoutReadiness: preWorkoutReadiness,
          exercises: exercises,
          previousSessions: [identicalPreviousSession],
          prRecords: [],
          currentStreak: 1,
        );

        expect(updateResult.achievedProgression, isFalse);
        expect(updateResult.updatedState.totalGrowthPoints, 
               equals(initialAvatarState.totalGrowthPoints));
      });

      test('should handle extreme cooldown scenarios', () {
        var currentAvatarState = initialAvatarState;

        // Apply extreme cooldowns
        currentAvatarState = currentAvatarState.copyWith(
          cooldownUntil: {
            'chest': DateTime.now().add(const Duration(days: 7)),
            'triceps': DateTime.now().add(const Duration(days: 5)),
            'shoulders': DateTime.now().add(const Duration(days: 3)),
          },
        );

        final session = _createProgressiveSession(
          sessionId: 'test_session',
          sessionDate: DateTime.now(),
          week: 0,
          day: 0,
        );

        final preWorkoutReadiness = <String, ReadinessLevel>{
          'chest': ReadinessLevel.fatigued,
          'triceps': ReadinessLevel.fatigued,
          'shoulders': ReadinessLevel.fatigued,
        };

        final updateResult = avatarSystem.updateAvatarComprehensive(
          currentState: currentAvatarState,
          session: session,
          preWorkoutReadiness: preWorkoutReadiness,
          exercises: exercises,
          previousSessions: [],
          prRecords: [],
          currentStreak: 1,
        );

        // Should still function but with heavy penalties
        expect(updateResult.updatedState.muscleGroupsInCooldown.length, 
               greaterThanOrEqualTo(3));
      });
    });
  });
}

/// Helper function to create progressive workout sessions
WorkoutSession _createProgressiveSession({
  required String sessionId,
  required DateTime sessionDate,
  required int week,
  required int day,
}) {
  // Progressive weight increase: start at 60kg, add 2.5kg per week
  final baseWeight = 60.0 + (week * 2.5);
  
  return WorkoutSession(
    id: sessionId,
    userId: 'test_user',
    startTime: sessionDate,
    endTime: sessionDate.add(const Duration(hours: 1)),
    sessionType: SessionType.strength,
    createdAt: sessionDate,
    sets: [
      // Bench press sets
      WorkoutSet(
        id: '${sessionId}_bench_1',
        sessionId: sessionId,
        exerciseId: 'bench_press',
        weight: baseWeight,
        reps: 8,
        rpe: 7 + (day % 2), // Vary RPE
        setOrder: 1,
        createdAt: sessionDate,
      ),
      WorkoutSet(
        id: '${sessionId}_bench_2',
        sessionId: sessionId,
        exerciseId: 'bench_press',
        weight: baseWeight,
        reps: 8,
        rpe: 8,
        setOrder: 2,
        createdAt: sessionDate,
      ),
      // Squat sets
      WorkoutSet(
        id: '${sessionId}_squat_1',
        sessionId: sessionId,
        exerciseId: 'squat',
        weight: baseWeight + 20.0, // Squats typically heavier
        reps: 8,
        rpe: 8,
        setOrder: 3,
        createdAt: sessionDate,
      ),
      // Pull-up sets (bodyweight)
      WorkoutSet(
        id: '${sessionId}_pullup_1',
        sessionId: sessionId,
        exerciseId: 'pull_up',
        weight: 0.0, // Bodyweight
        reps: 8 + (week ~/ 2), // Progressive reps
        rpe: 8,
        setOrder: 4,
        createdAt: sessionDate,
      ),
    ],
  );
}