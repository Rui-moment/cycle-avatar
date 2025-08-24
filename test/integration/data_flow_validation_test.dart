import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cycle_avatar/main.dart' as app;
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/exercise.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';
import 'package:cycle_avatar/domain/entities/avatar_state.dart';
import 'package:cycle_avatar/domain/entities/recovery_state.dart';
import 'package:cycle_avatar/domain/entities/pr_record.dart';

/// Data flow validation tests to ensure data integrity throughout the system
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Data Flow Validation Tests', () {
    
    group('Workout Data Flow', () {
      testWidgets('Complete workout data flow from input to storage', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Step 1: Start workout session
        await tester.tap(find.text('Workout'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('start_session_button')));
        await tester.pumpAndSettle();

        // Step 2: Add exercise and verify data propagation
        await tester.tap(find.byKey(const Key('add_exercise_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('exercise_search')), 'Squat');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Squat').first);
        await tester.pumpAndSettle();

        // Step 3: Add sets and verify immediate data updates
        final testSets = [
          {'weight': '100.0', 'reps': '8', 'rpe': 7},
          {'weight': '102.5', 'reps': '8', 'rpe': 8},
          {'weight': '105.0', 'reps': '6', 'rpe': 9},
        ];

        for (int i = 0; i < testSets.length; i++) {
          final set = testSets[i];
          
          await tester.enterText(find.byKey(const Key('weight_input')), set['weight'] as String);
          await tester.enterText(find.byKey(const Key('reps_input')), set['reps'] as String);
          await tester.tap(find.byKey(Key('rpe_${set['rpe']}')));
          await tester.tap(find.byKey(const Key('add_set_button')));
          await tester.pumpAndSettle();

          // Verify set appears in UI immediately
          expect(find.text('Set ${i + 1}: ${set['weight']}kg × ${set['reps']} @ RPE ${set['rpe']}'), findsOneWidget);
          
          // Verify set count updates
          expect(find.text('${i + 1} sets'), findsOneWidget);
        }

        // Step 4: End session and verify data persistence
        await tester.tap(find.byKey(const Key('end_session_button')));
        await tester.pumpAndSettle();

        // Verify session summary
        expect(find.text('3 sets completed'), findsOneWidget);
        expect(find.text('1 exercise'), findsOneWidget);

        // Step 5: Navigate to history and verify data persistence
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();

        // Verify workout appears in history
        expect(find.text('Squat'), findsOneWidget);
        expect(find.text('3 sets'), findsOneWidget);

        // Step 6: Open workout details and verify all data
        await tester.tap(find.byKey(const Key('workout_detail_button')));
        await tester.pumpAndSettle();

        // Verify all sets are preserved
        for (int i = 0; i < testSets.length; i++) {
          final set = testSets[i];
          expect(find.text('${set['weight']}kg × ${set['reps']} @ RPE ${set['rpe']}'), findsOneWidget);
        }

        // Verify calculated metrics
        expect(find.textContaining('Total Volume:'), findsOneWidget);
        expect(find.textContaining('Average RPE:'), findsOneWidget);
      });

      testWidgets('Workout data validation and error handling', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Workout'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('start_session_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('add_exercise_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('exercise_search')), 'Squat');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Squat').first);
        await tester.pumpAndSettle();

        // Test invalid data handling
        final invalidInputs = [
          {'weight': '-10', 'reps': '8', 'error': 'Weight must be positive'},
          {'weight': '0', 'reps': '8', 'error': 'Weight must be greater than 0'},
          {'weight': '100', 'reps': '0', 'error': 'Reps must be at least 1'},
          {'weight': '100', 'reps': '-5', 'error': 'Reps must be positive'},
          {'weight': 'abc', 'reps': '8', 'error': 'Invalid weight format'},
          {'weight': '100', 'reps': 'xyz', 'error': 'Invalid reps format'},
        ];

        for (final input in invalidInputs) {
          await tester.enterText(find.byKey(const Key('weight_input')), input['weight'] as String);
          await tester.enterText(find.byKey(const Key('reps_input')), input['reps'] as String);
          await tester.tap(find.byKey(const Key('add_set_button')));
          await tester.pumpAndSettle();

          // Verify error message appears
          expect(find.text(input['error'] as String), findsOneWidget);

          // Verify set was not added
          expect(find.text('Set 1:'), findsNothing);
        }

        // Test valid input after errors
        await tester.enterText(find.byKey(const Key('weight_input')), '100');
        await tester.enterText(find.byKey(const Key('reps_input')), '8');
        await tester.tap(find.byKey(const Key('add_set_button')));
        await tester.pumpAndSettle();

        // Verify valid set was added
        expect(find.text('Set 1: 100.0kg × 8 @ RPE 7'), findsOneWidget);
      });
    });

    group('Fatigue and Recovery Data Flow', () {
      testWidgets('Fatigue calculation and recovery state updates', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Step 1: Check initial recovery state (should be Ready)
        expect(find.byKey(const Key('muscle_group_recovery')), findsOneWidget);
        
        // Verify initial state is Ready for all muscle groups
        final muscleGroups = ['chest', 'back', 'shoulders', 'legs', 'arms'];
        for (final group in muscleGroups) {
          expect(find.byKey(Key('${group}_ready')), findsOneWidget);
        }

        // Step 2: Complete high-intensity leg workout
        await _completeHighIntensityLegWorkout(tester);

        // Step 3: Verify fatigue calculation and state update
        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();

        // Verify leg muscle groups show fatigue
        expect(find.byKey(const Key('quadriceps_fatigued')), findsOneWidget);
        expect(find.byKey(const Key('hamstrings_warm')), findsOneWidget);
        expect(find.byKey(const Key('glutes_warm')), findsOneWidget);

        // Verify other muscle groups remain Ready
        expect(find.byKey(const Key('chest_ready')), findsOneWidget);
        expect(find.byKey(const Key('back_ready')), findsOneWidget);

        // Step 4: Simulate time passage and verify recovery
        await _simulateTimePassage(tester, hours: 24);

        // Verify partial recovery
        expect(find.byKey(const Key('quadriceps_warm')), findsOneWidget);
        expect(find.byKey(const Key('hamstrings_ready')), findsOneWidget);

        // Step 5: Complete recovery simulation
        await _simulateTimePassage(tester, hours: 48);

        // Verify full recovery
        expect(find.byKey(const Key('quadriceps_ready')), findsOneWidget);
        expect(find.byKey(const Key('hamstrings_ready')), findsOneWidget);
      });

      testWidgets('Multi-muscle group fatigue distribution', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Complete compound exercise workout (affects multiple muscle groups)
        await _completeCompoundExerciseWorkout(tester);

        // Verify fatigue distributed across muscle groups
        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();

        // Deadlift should affect: back (primary), legs (secondary), arms (tertiary)
        expect(find.byKey(const Key('back_fatigued')), findsOneWidget);
        expect(find.byKey(const Key('hamstrings_warm')), findsOneWidget);
        expect(find.byKey(const Key('glutes_warm')), findsOneWidget);
        expect(find.byKey(const Key('biceps_warm')), findsOneWidget);

        // Verify fatigue levels are proportional
        // Primary movers should have higher fatigue than secondary
        expect(find.textContaining('Back: High fatigue'), findsOneWidget);
        expect(find.textContaining('Legs: Moderate fatigue'), findsOneWidget);
        expect(find.textContaining('Arms: Low fatigue'), findsOneWidget);
      });
    });

    group('Avatar Growth Data Flow', () {
      testWidgets('Avatar progression from workout to level up', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Step 1: Check initial avatar state
        await tester.tap(find.text('Avatar'));
        await tester.pumpAndSettle();

        // Record initial levels
        final initialLevels = await _getAvatarLevels(tester);

        // Step 2: Complete progression workout in Ready state
        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();

        // Verify muscle groups are Ready
        expect(find.byKey(const Key('legs_ready')), findsOneWidget);

        // Complete progressive workout
        await _completeProgressiveWorkout(tester);

        // Step 3: Verify growth points awarded
        expect(find.text('Growth points earned!'), findsOneWidget);
        expect(find.textContaining('+'), findsOneWidget); // Growth points indicator

        // Step 4: Check avatar level progression
        await tester.tap(find.text('Avatar'));
        await tester.pumpAndSettle();

        // Verify level increased
        final newLevels = await _getAvatarLevels(tester);
        expect(newLevels['legs'], greaterThan(initialLevels['legs']!));

        // Verify level up animation if triggered
        if (find.byKey(const Key('level_up_animation')).evaluate().isNotEmpty) {
          expect(find.text('Level Up!'), findsOneWidget);
          expect(find.textContaining('Legs Level'), findsOneWidget);
        }

        // Step 5: Verify growth points and progress tracking
        expect(find.byKey(const Key('growth_progress_bar')), findsOneWidget);
        expect(find.textContaining('XP'), findsOneWidget);
      });

      testWidgets('Avatar cooldown when overtraining', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Step 1: Fatigue muscle groups first
        await _completeHighIntensityLegWorkout(tester);

        // Step 2: Train again while fatigued (overtraining)
        await _completeProgressiveWorkout(tester);

        // Step 3: Verify cooldown applied
        expect(find.text('Overtraining detected'), findsOneWidget);
        expect(find.text('Growth reduced'), findsOneWidget);

        // Step 4: Check avatar page for cooldown indicator
        await tester.tap(find.text('Avatar'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('cooldown_indicator')), findsOneWidget);
        expect(find.text('Cooldown active'), findsOneWidget);

        // Step 5: Verify reduced growth points
        expect(find.textContaining('Growth: 50%'), findsOneWidget);
      });
    });

    group('PR Tracking Data Flow', () {
      testWidgets('PR detection and recording flow', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Step 1: Complete baseline workout
        await _completeBaselineWorkout(tester);

        // Step 2: Complete PR workout
        await _completePRWorkout(tester);

        // Step 3: Verify PR detection
        expect(find.text('New Personal Record!'), findsOneWidget);
        expect(find.byKey(const Key('pr_celebration')), findsOneWidget);

        // Step 4: Navigate to PR history
        await tester.tap(find.byKey(const Key('view_pr_history')));
        await tester.pumpAndSettle();

        // Verify PR recorded
        expect(find.text('Bench Press PR'), findsOneWidget);
        expect(find.text('120.0kg × 1'), findsOneWidget);
        expect(find.textContaining('Today'), findsOneWidget);

        // Step 5: Verify PR affects avatar growth
        await tester.tap(find.text('Avatar'));
        await tester.pumpAndSettle();

        expect(find.text('PR Bonus!'), findsOneWidget);
        expect(find.byKey(const Key('pr_bonus_indicator')), findsOneWidget);
      });

      testWidgets('PR comparison and progression tracking', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Complete multiple PRs over time
        final prWorkouts = [
          {'weight': '100', 'reps': '1', 'date': 'Week 1'},
          {'weight': '105', 'reps': '1', 'date': 'Week 2'},
          {'weight': '110', 'reps': '1', 'date': 'Week 3'},
          {'weight': '115', 'reps': '1', 'date': 'Week 4'},
        ];

        for (final workout in prWorkouts) {
          await _completePRWorkoutWithWeight(tester, workout['weight']!);
          await _simulateTimePassage(tester, hours: 168); // 1 week
        }

        // Navigate to PR history
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('PR Records'));
        await tester.pumpAndSettle();

        // Verify progression tracking
        expect(find.text('Bench Press Progression'), findsOneWidget);
        expect(find.byKey(const Key('pr_progression_chart')), findsOneWidget);

        // Verify all PRs recorded
        for (final workout in prWorkouts) {
          expect(find.text('${workout['weight']}.0kg'), findsOneWidget);
        }

        // Verify progression percentage
        expect(find.textContaining('+15%'), findsOneWidget); // 100kg to 115kg
      });
    });

    group('Notification Data Flow', () {
      testWidgets('Recovery notification scheduling and delivery', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Step 1: Enable notifications
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Notifications'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('recovery_notifications_toggle')));
        await tester.pumpAndSettle();

        // Step 2: Complete workout to trigger fatigue
        await _completeHighIntensityLegWorkout(tester);

        // Step 3: Verify notification scheduled
        expect(find.text('Recovery notification scheduled'), findsOneWidget);
        expect(find.textContaining('in 48 hours'), findsOneWidget);

        // Step 4: Simulate time passage to trigger notification
        await _simulateTimePassage(tester, hours: 48);

        // Step 5: Verify notification triggered
        expect(find.text('Legs are ready to train!'), findsOneWidget);
        expect(find.byKey(const Key('recovery_notification')), findsOneWidget);

        // Step 6: Verify notification can be dismissed
        await tester.tap(find.byKey(const Key('dismiss_notification')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('recovery_notification')), findsNothing);
      });

      testWidgets('Deload notification flow', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Simulate 4 weeks of high volume training
        await _simulateHighVolumeTrainingPeriod(tester);

        // Verify deload notification
        expect(find.text('Deload week recommended'), findsOneWidget);
        expect(find.byKey(const Key('deload_notification')), findsOneWidget);

        // Accept deload recommendation
        await tester.tap(find.byKey(const Key('accept_deload')));
        await tester.pumpAndSettle();

        // Verify deload plan generated
        expect(find.text('Deload plan created'), findsOneWidget);

        // Navigate to plan
        await tester.tap(find.text('Smart Plan'));
        await tester.pumpAndSettle();

        expect(find.text('Deload Week'), findsOneWidget);
        expect(find.textContaining('40-60% volume'), findsOneWidget);
      });
    });

    group('Template Data Flow', () {
      testWidgets('Template creation to workout execution flow', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Step 1: Create template
        await tester.tap(find.text('Templates'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('create_template_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('template_name_input')), 'Push Day');
        await tester.enterText(
          find.byKey(const Key('template_description_input')), 
          'Chest, shoulders, triceps'
        );

        // Add exercises to template
        final exercises = ['Bench Press', 'Overhead Press', 'Tricep Dips'];
        for (final exercise in exercises) {
          await tester.tap(find.byKey(const Key('add_exercise_to_template')));
          await tester.pumpAndSettle();

          await tester.enterText(find.byKey(const Key('exercise_search')), exercise);
          await tester.pumpAndSettle();
          await tester.tap(find.text(exercise).first);
          await tester.pumpAndSettle();
        }

        await tester.tap(find.byKey(const Key('save_template_button')));
        await tester.pumpAndSettle();

        // Step 2: Use template for workout
        await tester.tap(find.byKey(const Key('use_template_Push Day')));
        await tester.pumpAndSettle();

        // Step 3: Verify template data loaded correctly
        for (final exercise in exercises) {
          expect(find.text(exercise), findsOneWidget);
        }

        // Step 4: Complete workout using template
        await tester.tap(find.byKey(const Key('start_session_button')));
        await tester.pumpAndSettle();

        // Log sets for each exercise
        for (int i = 0; i < exercises.length; i++) {
          await tester.tap(find.text(exercises[i]));
          await tester.pumpAndSettle();

          // Add 3 sets per exercise
          for (int setNum = 1; setNum <= 3; setNum++) {
            await tester.enterText(find.byKey(const Key('weight_input')), '${80 + i * 10}');
            await tester.enterText(find.byKey(const Key('reps_input')), '8');
            await tester.tap(find.byKey(const Key('rpe_7')));
            await tester.tap(find.byKey(const Key('add_set_button')));
            await tester.pumpAndSettle();
          }
        }

        await tester.tap(find.byKey(const Key('end_session_button')));
        await tester.pumpAndSettle();

        // Step 5: Verify workout completion with template data
        expect(find.text('9 sets completed'), findsOneWidget);
        expect(find.text('3 exercises'), findsOneWidget);
        expect(find.text('Template: Push Day'), findsOneWidget);

        // Step 6: Verify template usage tracking
        await tester.tap(find.text('Templates'));
        await tester.pumpAndSettle();

        expect(find.text('Used 1 time'), findsOneWidget);
        expect(find.text('Last used: Today'), findsOneWidget);
      });
    });

    group('Sync Data Flow', () {
      testWidgets('Offline to online sync data flow', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Step 1: Go offline
        await _simulateOfflineMode(tester);

        // Step 2: Complete workout offline
        await _completeTestWorkout(tester);

        // Verify offline storage
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        expect(find.text('Saved locally'), findsOneWidget);

        // Step 3: Add more data offline
        await _completeTestWorkout(tester);
        await _completeTestWorkout(tester);

        // Verify multiple workouts queued
        expect(find.text('3 workouts pending sync'), findsOneWidget);

        // Step 4: Go online
        await _simulateOnlineMode(tester);

        // Step 5: Verify sync process
        expect(find.byIcon(Icons.sync), findsOneWidget);
        expect(find.text('Syncing...'), findsOneWidget);

        // Wait for sync completion
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Step 6: Verify sync completion
        expect(find.byIcon(Icons.cloud_done), findsOneWidget);
        expect(find.text('All data synced'), findsOneWidget);

        // Step 7: Verify data integrity after sync
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();

        expect(find.text('3 workouts'), findsOneWidget);
        
        // Verify all workouts are present
        final workoutTiles = find.byKey(const Key('workout_tile'));
        expect(workoutTiles, findsNWidgets(3));
      });
    });
  });
}

// Helper functions for data flow tests

Future<void> _completeHighIntensityLegWorkout(WidgetTester tester) async {
  await tester.tap(find.text('Workout'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('start_session_button')));
  await tester.pumpAndSettle();

  // Add Squat
  await tester.tap(find.byKey(const Key('add_exercise_button')));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('exercise_search')), 'Squat');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Squat').first);
  await tester.pumpAndSettle();

  // High intensity sets
  final sets = [
    {'weight': '140', 'reps': '5', 'rpe': 9},
    {'weight': '145', 'reps': '3', 'rpe': 10},
    {'weight': '150', 'reps': '1', 'rpe': 10},
  ];

  for (final set in sets) {
    await tester.enterText(find.byKey(const Key('weight_input')), set['weight']!);
    await tester.enterText(find.byKey(const Key('reps_input')), set['reps']!);
    await tester.tap(find.byKey(Key('rpe_${set['rpe']}')));
    await tester.tap(find.byKey(const Key('add_set_button')));
    await tester.pumpAndSettle();
  }

  await tester.tap(find.byKey(const Key('end_session_button')));
  await tester.pumpAndSettle();
}

Future<void> _completeCompoundExerciseWorkout(WidgetTester tester) async {
  await tester.tap(find.text('Workout'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('start_session_button')));
  await tester.pumpAndSettle();

  // Add Deadlift (compound exercise affecting multiple muscle groups)
  await tester.tap(find.byKey(const Key('add_exercise_button')));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('exercise_search')), 'Deadlift');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Deadlift').first);
  await tester.pumpAndSettle();

  // Heavy deadlift sets
  for (int i = 1; i <= 3; i++) {
    await tester.enterText(find.byKey(const Key('weight_input')), '${160 + i * 10}');
    await tester.enterText(find.byKey(const Key('reps_input')), '5');
    await tester.tap(find.byKey(const Key('rpe_8')));
    await tester.tap(find.byKey(const Key('add_set_button')));
    await tester.pumpAndSettle();
  }

  await tester.tap(find.byKey(const Key('end_session_button')));
  await tester.pumpAndSettle();
}

Future<Map<String, int>> _getAvatarLevels(WidgetTester tester) async {
  // Extract current avatar levels from UI
  // This would need to be implemented based on actual avatar widget structure
  return {
    'chest': 1,
    'back': 1,
    'shoulders': 1,
    'legs': 1,
    'arms': 1,
  };
}

Future<void> _completeProgressiveWorkout(WidgetTester tester) async {
  await tester.tap(find.text('Workout'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('start_session_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('add_exercise_button')));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('exercise_search')), 'Squat');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Squat').first);
  await tester.pumpAndSettle();

  // Progressive sets (increasing weight)
  await tester.enterText(find.byKey(const Key('weight_input')), '105'); // +5kg from previous
  await tester.enterText(find.byKey(const Key('reps_input')), '8');
  await tester.tap(find.byKey(const Key('rpe_8')));
  await tester.tap(find.byKey(const Key('add_set_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('end_session_button')));
  await tester.pumpAndSettle();
}

Future<void> _completeBaselineWorkout(WidgetTester tester) async {
  await tester.tap(find.text('Workout'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('start_session_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('add_exercise_button')));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('exercise_search')), 'Bench Press');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bench Press').first);
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('weight_input')), '100');
  await tester.enterText(find.byKey(const Key('reps_input')), '1');
  await tester.tap(find.byKey(const Key('rpe_9')));
  await tester.tap(find.byKey(const Key('add_set_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('end_session_button')));
  await tester.pumpAndSettle();
}

Future<void> _completePRWorkout(WidgetTester tester) async {
  await tester.tap(find.text('Workout'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('start_session_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('add_exercise_button')));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('exercise_search')), 'Bench Press');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bench Press').first);
  await tester.pumpAndSettle();

  // PR weight (20kg more than baseline)
  await tester.enterText(find.byKey(const Key('weight_input')), '120');
  await tester.enterText(find.byKey(const Key('reps_input')), '1');
  await tester.tap(find.byKey(const Key('rpe_10')));
  await tester.tap(find.byKey(const Key('add_set_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('end_session_button')));
  await tester.pumpAndSettle();
}

Future<void> _completePRWorkoutWithWeight(WidgetTester tester, String weight) async {
  await tester.tap(find.text('Workout'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('start_session_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('add_exercise_button')));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('exercise_search')), 'Bench Press');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bench Press').first);
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('weight_input')), weight);
  await tester.enterText(find.byKey(const Key('reps_input')), '1');
  await tester.tap(find.byKey(const Key('rpe_10')));
  await tester.tap(find.byKey(const Key('add_set_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('end_session_button')));
  await tester.pumpAndSettle();
}

Future<void> _simulateHighVolumeTrainingPeriod(WidgetTester tester) async {
  // Simulate 4 weeks of progressively increasing volume
  for (int week = 1; week <= 4; week++) {
    for (int session = 1; session <= 3; session++) {
      await _completeHighIntensityLegWorkout(tester);
      await _simulateTimePassage(tester, hours: 48);
    }
  }
}

Future<void> _completeTestWorkout(WidgetTester tester) async {
  await tester.tap(find.text('Workout'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('start_session_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('add_exercise_button')));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('exercise_search')), 'Squat');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Squat').first);
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('weight_input')), '100');
  await tester.enterText(find.byKey(const Key('reps_input')), '8');
  await tester.tap(find.byKey(const Key('rpe_7')));
  await tester.tap(find.byKey(const Key('add_set_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('end_session_button')));
  await tester.pumpAndSettle();
}

Future<void> _simulateTimePassage(WidgetTester tester, {required int hours}) async {
  // In a real implementation, this would manipulate the system clock
  await Future.delayed(const Duration(milliseconds: 100));
}

Future<void> _simulateOfflineMode(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('connectivity_plus'),
    (methodCall) async => 'none',
  );
}

Future<void> _simulateOnlineMode(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('connectivity_plus'),
    (methodCall) async => 'wifi',
  );
}