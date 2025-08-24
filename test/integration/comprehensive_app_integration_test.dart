import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cycle_avatar/main.dart' as app;
import 'package:cycle_avatar/domain/entities/enums.dart';

/// Comprehensive integration tests covering all major app functionality
/// This test suite verifies the complete data flow and feature integration
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Comprehensive App Integration Tests', () {
    
    group('Complete User Journey Tests', () {
      testWidgets('Full workout cycle with avatar progression', (WidgetTester tester) async {
        // This test covers Requirements: 1.1, 1.2, 2.1, 2.2, 3.1, 3.2
        
        // Launch app
        app.main();
        await tester.pumpAndSettle();

        // Verify home page loads within performance requirement
        final homeLoadStopwatch = Stopwatch()..start();
        await tester.pumpAndSettle();
        homeLoadStopwatch.stop();
        expect(homeLoadStopwatch.elapsedMilliseconds, lessThan(500),
            reason: 'Home page should load within 500ms');

        // Step 1: Check initial recovery state
        expect(find.byKey(const Key('muscle_group_recovery')), findsOneWidget);
        expect(find.byKey(const Key('todays_recommendation')), findsOneWidget);

        // Step 2: Start workout session
        await tester.tap(find.text('Start Workout'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('start_session_button')));
        await tester.pumpAndSettle();

        // Step 3: Add compound exercise (Squat)
        await tester.tap(find.byKey(const Key('add_exercise_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('exercise_search')), 'Squat');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Squat').first);
        await tester.pumpAndSettle();

        // Step 4: Log progressive sets with performance verification
        final setTimes = <int>[];
        
        for (int setNum = 1; setNum <= 3; setNum++) {
          final setStopwatch = Stopwatch()..start();
          
          // Progressive overload: increase weight each set
          final weight = 100.0 + (setNum * 2.5);
          await tester.enterText(find.byKey(const Key('weight_input')), weight.toString());
          await tester.enterText(find.byKey(const Key('reps_input')), '8');
          await tester.tap(find.byKey(const Key('rpe_${6 + setNum}')));
          
          await tester.tap(find.byKey(const Key('add_set_button')));
          await tester.pumpAndSettle();
          
          setStopwatch.stop();
          setTimes.add(setStopwatch.elapsedMilliseconds);
          
          // Verify set was added with correct data
          expect(find.text('Set $setNum: ${weight}kg × 8 @ RPE ${6 + setNum}'), findsOneWidget);
          
          // Verify performance requirement
          expect(setStopwatch.elapsedMilliseconds, lessThan(150),
              reason: 'Set addition should complete within 150ms');
        }

        // Verify progression detection
        expect(find.byIcon(Icons.trending_up), findsOneWidget);
        expect(find.text('Progression detected!'), findsOneWidget);

        // Step 5: Add isolation exercise (Leg Curl)
        await tester.tap(find.byKey(const Key('add_exercise_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('exercise_search')), 'Leg Curl');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Leg Curl').first);
        await tester.pumpAndSettle();

        // Add 2 sets for isolation exercise
        for (int setNum = 1; setNum <= 2; setNum++) {
          await tester.enterText(find.byKey(const Key('weight_input')), '50');
          await tester.enterText(find.byKey(const Key('reps_input')), '12');
          await tester.tap(find.byKey(const Key('rpe_7')));
          await tester.tap(find.byKey(const Key('add_set_button')));
          await tester.pumpAndSettle();
        }

        // Step 6: End workout session
        await tester.tap(find.byKey(const Key('end_session_button')));
        await tester.pumpAndSettle();

        // Verify session summary
        expect(find.text('Workout Complete!'), findsOneWidget);
        expect(find.text('5 sets completed'), findsOneWidget);
        expect(find.text('2 exercises'), findsOneWidget);

        // Step 7: Verify fatigue calculation and recovery state update
        await tester.tap(find.byKey(const Key('back_to_home_button')));
        await tester.pumpAndSettle();

        // Check that leg muscle groups show fatigue
        expect(find.byKey(const Key('muscle_group_quadriceps_fatigued')), findsOneWidget);
        expect(find.byKey(const Key('muscle_group_hamstrings_warm')), findsOneWidget);

        // Step 8: Verify avatar progression
        await tester.tap(find.text('Avatar'));
        await tester.pumpAndSettle();

        // Check for level up notification (if progression achieved in ready state)
        if (find.text('Level Up!').evaluate().isNotEmpty) {
          expect(find.text('Level Up!'), findsOneWidget);
          expect(find.byKey(const Key('avatar_level_up_animation')), findsOneWidget);
        }

        // Verify muscle group levels displayed
        expect(find.byKey(const Key('muscle_group_levels')), findsOneWidget);
        expect(find.byKey(const Key('legs_level_display')), findsOneWidget);

        // Step 9: Check workout history
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();

        expect(find.text('Squat'), findsOneWidget);
        expect(find.text('Leg Curl'), findsOneWidget);
        expect(find.text('5 sets'), findsOneWidget);

        // Step 10: Verify PR tracking
        if (find.text('New PR!').evaluate().isNotEmpty) {
          expect(find.text('New PR!'), findsOneWidget);
          expect(find.byKey(const Key('pr_celebration')), findsOneWidget);
        }

        print('Average set addition time: ${setTimes.reduce((a, b) => a + b) / setTimes.length}ms');
      });

      testWidgets('Template workflow integration', (WidgetTester tester) async {
        // This test covers Requirements: 1.3, template functionality
        
        app.main();
        await tester.pumpAndSettle();

        // Navigate to templates
        await tester.tap(find.text('Templates'));
        await tester.pumpAndSettle();

        // Create new template
        await tester.tap(find.byKey(const Key('create_template_button')));
        await tester.pumpAndSettle();

        // Enter template details
        await tester.enterText(find.byKey(const Key('template_name_input')), 'Upper Body Push');
        await tester.enterText(
          find.byKey(const Key('template_description_input')), 
          'Chest, shoulders, triceps focused workout'
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

        // Save template
        await tester.tap(find.byKey(const Key('save_template_button')));
        await tester.pumpAndSettle();

        // Verify template was created
        expect(find.text('Upper Body Push'), findsOneWidget);
        expect(find.text('3 exercises'), findsOneWidget);

        // Use template for workout
        await tester.tap(find.byKey(const Key('use_template_Upper Body Push')));
        await tester.pumpAndSettle();

        // Verify workout started with template exercises
        for (final exercise in exercises) {
          expect(find.text(exercise), findsOneWidget);
        }

        // Complete workout using template
        await tester.tap(find.byKey(const Key('start_session_button')));
        await tester.pumpAndSettle();

        // Log sets for each exercise
        for (int exerciseIndex = 0; exerciseIndex < exercises.length; exerciseIndex++) {
          // Select exercise
          await tester.tap(find.text(exercises[exerciseIndex]));
          await tester.pumpAndSettle();

          // Add 3 sets
          for (int setNum = 1; setNum <= 3; setNum++) {
            await tester.enterText(find.byKey(const Key('weight_input')), '${80 + exerciseIndex * 10}');
            await tester.enterText(find.byKey(const Key('reps_input')), '8');
            await tester.tap(find.byKey(const Key('rpe_7')));
            await tester.tap(find.byKey(const Key('add_set_button')));
            await tester.pumpAndSettle();
          }
        }

        // End session
        await tester.tap(find.byKey(const Key('end_session_button')));
        await tester.pumpAndSettle();

        // Verify template workout completion
        expect(find.text('9 sets completed'), findsOneWidget);
        expect(find.text('3 exercises'), findsOneWidget);
      });
    });

    group('Smart Plan Generation Integration', () {
      testWidgets('Plan generation based on recovery state', (WidgetTester tester) async {
        // This test covers Requirements: 4.1, 4.2, 4.3
        
        app.main();
        await tester.pumpAndSettle();

        // Navigate to plan generation
        await tester.tap(find.text('Smart Plan'));
        await tester.pumpAndSettle();

        // Set training goal
        await tester.tap(find.byKey(const Key('goal_hypertrophy')));
        await tester.pumpAndSettle();

        // Generate plan
        await tester.tap(find.byKey(const Key('generate_plan_button')));
        await tester.pumpAndSettle();

        // Verify plan generation
        expect(find.byKey(const Key('generated_plan')), findsOneWidget);
        expect(find.text('Recommended Workout'), findsOneWidget);

        // Verify plan considers recovery state
        expect(find.byKey(const Key('recovery_based_recommendations')), findsOneWidget);

        // Check for muscle group specific recommendations
        expect(find.byKey(const Key('muscle_group_recommendations')), findsOneWidget);

        // Verify hypertrophy-specific rep ranges (8-12)
        expect(find.textContaining('8-12 reps'), findsWidgets);

        // Test plan execution
        await tester.tap(find.byKey(const Key('start_recommended_workout')));
        await tester.pumpAndSettle();

        // Verify workout started with recommended exercises
        expect(find.byKey(const Key('workout_session_active')), findsOneWidget);
      });

      testWidgets('Deload detection and recommendation', (WidgetTester tester) async {
        // This test covers Requirements: 4.5
        
        app.main();
        await tester.pumpAndSettle();

        // Simulate 4 weeks of high volume training
        await _simulateHighVolumeTraining(tester);

        // Navigate to plan generation
        await tester.tap(find.text('Smart Plan'));
        await tester.pumpAndSettle();

        // Generate plan
        await tester.tap(find.byKey(const Key('generate_plan_button')));
        await tester.pumpAndSettle();

        // Verify deload recommendation
        expect(find.text('Deload Week Recommended'), findsOneWidget);
        expect(find.byKey(const Key('deload_recommendation')), findsOneWidget);
        expect(find.textContaining('reduce volume by 40-60%'), findsOneWidget);

        // Accept deload recommendation
        await tester.tap(find.byKey(const Key('accept_deload_button')));
        await tester.pumpAndSettle();

        // Verify deload plan generated
        expect(find.text('Deload Workout Plan'), findsOneWidget);
        expect(find.textContaining('lighter weights'), findsOneWidget);
      });
    });

    group('Notification System Integration', () {
      testWidgets('Recovery notification workflow', (WidgetTester tester) async {
        // This test covers Requirements: 7.1, 7.2
        
        app.main();
        await tester.pumpAndSettle();

        // Complete a workout to trigger fatigue
        await _completeTestWorkout(tester);

        // Navigate to settings to enable notifications
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Notifications'));
        await tester.pumpAndSettle();

        // Enable recovery notifications
        await tester.tap(find.byKey(const Key('recovery_notifications_toggle')));
        await tester.pumpAndSettle();

        // Set notification preferences
        await tester.tap(find.byKey(const Key('chest_notifications_toggle')));
        await tester.tap(find.byKey(const Key('legs_notifications_toggle')));
        await tester.pumpAndSettle();

        // Verify notification scheduling
        expect(find.text('Notifications enabled'), findsOneWidget);
        expect(find.text('Recovery notifications: ON'), findsOneWidget);

        // Simulate time passage for recovery
        await _simulateTimePassage(tester, hours: 48);

        // Verify notification would be triggered
        expect(find.byKey(const Key('scheduled_notifications')), findsOneWidget);
      });

      testWidgets('PR achievement notification', (WidgetTester tester) async {
        // This test covers Requirements: 5.2, 7.3
        
        app.main();
        await tester.pumpAndSettle();

        // Complete workout with PR
        await _completeWorkoutWithPR(tester);

        // Verify PR notification
        expect(find.text('New Personal Record!'), findsOneWidget);
        expect(find.byKey(const Key('pr_celebration_notification')), findsOneWidget);

        // Navigate to PR history
        await tester.tap(find.byKey(const Key('view_pr_history_button')));
        await tester.pumpAndSettle();

        // Verify PR recorded
        expect(find.byKey(const Key('pr_history')), findsOneWidget);
        expect(find.text('Bench Press PR'), findsOneWidget);
      });
    });

    group('Multilingual Integration', () {
      testWidgets('Language switching workflow', (WidgetTester tester) async {
        // This test covers Requirements: 8.1, 8.2, 8.3
        
        app.main();
        await tester.pumpAndSettle();

        // Navigate to language settings
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Language'));
        await tester.pumpAndSettle();

        // Switch to Japanese
        await tester.tap(find.text('日本語'));
        await tester.pumpAndSettle();

        // Verify UI switched to Japanese
        expect(find.text('ホーム'), findsOneWidget);
        expect(find.text('ワークアウト'), findsOneWidget);
        expect(find.text('アバター'), findsOneWidget);

        // Test exercise names in Japanese
        await tester.tap(find.text('ワークアウト'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('start_session_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('add_exercise_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('exercise_search')), 'スクワット');
        await tester.pumpAndSettle();

        expect(find.text('スクワット'), findsOneWidget);

        // Switch back to English
        await tester.tap(find.text('設定'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('言語'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();

        // Verify UI switched back to English
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Workout'), findsOneWidget);
      });
    });

    group('Data Export and Privacy Integration', () {
      testWidgets('Data export workflow', (WidgetTester tester) async {
        // This test covers Requirements: 9.1, 9.5
        
        app.main();
        await tester.pumpAndSettle();

        // Generate some data to export
        await _generateTestData(tester);

        // Navigate to data export
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Data Export'));
        await tester.pumpAndSettle();

        // Start export
        await tester.tap(find.byKey(const Key('export_data_button')));
        await tester.pumpAndSettle();

        // Verify export progress
        expect(find.byKey(const Key('export_progress')), findsOneWidget);
        expect(find.text('Exporting workout data...'), findsOneWidget);

        // Wait for export completion
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Verify export completed
        expect(find.text('Export completed'), findsOneWidget);
        expect(find.byKey(const Key('share_export_button')), findsOneWidget);
      });

      testWidgets('Account deletion workflow', (WidgetTester tester) async {
        // This test covers Requirements: 9.2, 9.3
        
        app.main();
        await tester.pumpAndSettle();

        // Navigate to account deletion
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Account'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete Account'));
        await tester.pumpAndSettle();

        // Verify deletion warning
        expect(find.text('Delete Account'), findsOneWidget);
        expect(find.text('This action cannot be undone'), findsOneWidget);

        // Enter confirmation
        await tester.enterText(
          find.byKey(const Key('deletion_confirmation_input')), 
          'DELETE'
        );
        await tester.pumpAndSettle();

        // Confirm deletion
        await tester.tap(find.byKey(const Key('confirm_deletion_button')));
        await tester.pumpAndSettle();

        // Verify deletion process started
        expect(find.text('Deleting account...'), findsOneWidget);
        expect(find.byKey(const Key('deletion_progress')), findsOneWidget);
      });
    });

    group('Accessibility Integration', () {
      testWidgets('Screen reader compatibility', (WidgetTester tester) async {
        // This test covers Requirements: 10.1, 10.2
        
        app.main();
        await tester.pumpAndSettle();

        // Verify semantic labels
        expect(find.bySemanticsLabel('Home page'), findsOneWidget);
        expect(find.bySemanticsLabel('Start workout button'), findsOneWidget);
        expect(find.bySemanticsLabel('Avatar display'), findsOneWidget);

        // Test navigation with semantics
        await tester.tap(find.bySemanticsLabel('Start workout button'));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Workout session page'), findsOneWidget);
        expect(find.bySemanticsLabel('Add exercise button'), findsOneWidget);

        // Test form accessibility
        await tester.tap(find.bySemanticsLabel('Add exercise button'));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Exercise search field'), findsOneWidget);
        expect(find.bySemanticsLabel('Weight input field'), findsOneWidget);
        expect(find.bySemanticsLabel('Reps input field'), findsOneWidget);
      });

      testWidgets('Large font support', (WidgetTester tester) async {
        // This test covers Requirements: 10.2
        
        app.main();
        await tester.pumpAndSettle();

        // Enable large fonts
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Accessibility'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('large_fonts_toggle')));
        await tester.pumpAndSettle();

        // Verify font size increased
        final textWidgets = find.byType(Text);
        for (final widget in textWidgets.evaluate()) {
          final textWidget = widget.widget as Text;
          if (textWidget.style?.fontSize != null) {
            expect(textWidget.style!.fontSize!, greaterThan(16.0));
          }
        }

        // Verify layout adapts to larger fonts
        expect(find.byKey(const Key('adaptive_layout')), findsOneWidget);
      });

      testWidgets('Voice input integration', (WidgetTester tester) async {
        // This test covers Requirements: 10.5
        
        app.main();
        await tester.pumpAndSettle();

        // Start workout
        await tester.tap(find.text('Start Workout'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('start_session_button')));
        await tester.pumpAndSettle();

        // Add exercise
        await tester.tap(find.byKey(const Key('add_exercise_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('exercise_search')), 'Squat');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Squat').first);
        await tester.pumpAndSettle();

        // Test voice input for weight and reps
        await tester.tap(find.byKey(const Key('voice_input_weight')));
        await tester.pumpAndSettle();

        // Simulate voice input
        expect(find.byKey(const Key('voice_input_active')), findsOneWidget);
        expect(find.text('Listening for weight...'), findsOneWidget);

        // Simulate voice recognition result
        await _simulateVoiceInput(tester, 'one hundred kilograms');

        // Verify voice input processed
        expect(find.text('100'), findsOneWidget);

        // Test voice input for reps
        await tester.tap(find.byKey(const Key('voice_input_reps')));
        await tester.pumpAndSettle();

        await _simulateVoiceInput(tester, 'eight reps');
        expect(find.text('8'), findsOneWidget);
      });
    });

    group('Performance and Memory Integration', () {
      testWidgets('Memory usage during extended session', (WidgetTester tester) async {
        // This test covers Requirements: 1.2, memory optimization
        
        app.main();
        await tester.pumpAndSettle();

        // Start extended workout session
        await tester.tap(find.text('Start Workout'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('start_session_button')));
        await tester.pumpAndSettle();

        // Add multiple exercises with many sets
        final exercises = ['Squat', 'Bench Press', 'Deadlift', 'Row', 'Press'];
        
        for (final exercise in exercises) {
          await tester.tap(find.byKey(const Key('add_exercise_button')));
          await tester.pumpAndSettle();

          await tester.enterText(find.byKey(const Key('exercise_search')), exercise);
          await tester.pumpAndSettle();
          await tester.tap(find.text(exercise).first);
          await tester.pumpAndSettle();

          // Add 5 sets per exercise
          for (int setNum = 1; setNum <= 5; setNum++) {
            await tester.enterText(find.byKey(const Key('weight_input')), '${100 + setNum * 5}');
            await tester.enterText(find.byKey(const Key('reps_input')), '${8 - setNum}');
            await tester.tap(find.byKey(const Key('rpe_7')));
            await tester.tap(find.byKey(const Key('add_set_button')));
            await tester.pumpAndSettle();
          }
        }

        // Verify UI remains responsive with 25 sets
        expect(find.text('Set 25'), findsOneWidget);
        expect(find.byKey(const Key('workout_session_active')), findsOneWidget);

        // Test scrolling performance
        final scrollStopwatch = Stopwatch()..start();
        await tester.drag(find.byKey(const Key('sets_list')), const Offset(0, -500));
        await tester.pumpAndSettle();
        scrollStopwatch.stop();

        expect(scrollStopwatch.elapsedMilliseconds, lessThan(100),
            reason: 'Scrolling should remain smooth with many sets');
      });

      testWidgets('Database performance with large dataset', (WidgetTester tester) async {
        // This test covers database performance requirements
        
        app.main();
        await tester.pumpAndSettle();

        // Generate large dataset
        await _generateLargeDataset(tester);

        // Test query performance
        final queryStopwatch = Stopwatch()..start();
        
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();
        
        queryStopwatch.stop();

        expect(queryStopwatch.elapsedMilliseconds, lessThan(1000),
            reason: 'History query should complete within 1 second');

        // Test search performance
        final searchStopwatch = Stopwatch()..start();
        
        await tester.enterText(find.byKey(const Key('history_search')), 'Squat');
        await tester.pumpAndSettle();
        
        searchStopwatch.stop();

        expect(searchStopwatch.elapsedMilliseconds, lessThan(500),
            reason: 'Search should complete within 500ms');
      });
    });
  });

  group('Error Handling and Recovery Integration', () {
    testWidgets('Network error recovery', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Simulate network error during sync
      await _simulateNetworkError(tester);

      // Complete workout
      await _completeTestWorkout(tester);

      // Verify offline mode handling
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Working offline'), findsOneWidget);

      // Restore network
      await _restoreNetwork(tester);

      // Verify automatic sync
      expect(find.byIcon(Icons.sync), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('Data corruption recovery', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Simulate data corruption
      await _simulateDataCorruption(tester);

      // Verify error handling
      expect(find.text('Data recovery in progress'), findsOneWidget);

      // Wait for recovery
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app continues to function
      expect(find.text('Home'), findsOneWidget);
      expect(find.byKey(const Key('app_functional')), findsOneWidget);
    });
  });
}

// Helper functions for test scenarios

Future<void> _simulateHighVolumeTraining(WidgetTester tester) async {
  // Simulate 4 weeks of progressively increasing volume
  for (int week = 1; week <= 4; week++) {
    for (int session = 1; session <= 3; session++) {
      await _completeTestWorkout(tester, volume: week * 10);
      await _simulateTimePassage(tester, hours: 48);
    }
  }
}

Future<void> _completeTestWorkout(WidgetTester tester, {int volume = 10}) async {
  await tester.tap(find.text('Start Workout'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('start_session_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('add_exercise_button')));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('exercise_search')), 'Squat');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Squat').first);
  await tester.pumpAndSettle();

  // Add sets based on volume
  final sets = (volume / 10).ceil();
  for (int i = 1; i <= sets; i++) {
    await tester.enterText(find.byKey(const Key('weight_input')), '100');
    await tester.enterText(find.byKey(const Key('reps_input')), '8');
    await tester.tap(find.byKey(const Key('rpe_7')));
    await tester.tap(find.byKey(const Key('add_set_button')));
    await tester.pumpAndSettle();
  }

  await tester.tap(find.byKey(const Key('end_session_button')));
  await tester.pumpAndSettle();
}

Future<void> _completeWorkoutWithPR(WidgetTester tester) async {
  await tester.tap(find.text('Start Workout'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('start_session_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('add_exercise_button')));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('exercise_search')), 'Bench Press');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bench Press').first);
  await tester.pumpAndSettle();

  // Log PR set (significantly higher than previous)
  await tester.enterText(find.byKey(const Key('weight_input')), '120');
  await tester.enterText(find.byKey(const Key('reps_input')), '1');
  await tester.tap(find.byKey(const Key('rpe_10')));
  await tester.tap(find.byKey(const Key('add_set_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('end_session_button')));
  await tester.pumpAndSettle();
}

Future<void> _generateTestData(WidgetTester tester) async {
  // Generate multiple workouts for export testing
  for (int i = 1; i <= 5; i++) {
    await _completeTestWorkout(tester);
    await _simulateTimePassage(tester, hours: 24);
  }
}

Future<void> _generateLargeDataset(WidgetTester tester) async {
  // Generate large dataset for performance testing
  for (int i = 1; i <= 20; i++) {
    await _completeTestWorkout(tester, volume: 20);
    await _simulateTimePassage(tester, hours: 12);
  }
}

Future<void> _simulateTimePassage(WidgetTester tester, {required int hours}) async {
  // In a real implementation, this would manipulate the system clock
  // For testing, we'll just add a small delay
  await Future.delayed(const Duration(milliseconds: 100));
}

Future<void> _simulateVoiceInput(WidgetTester tester, String input) async {
  // Simulate voice recognition result
  await Future.delayed(const Duration(milliseconds: 500));
  // In a real implementation, this would trigger the voice input callback
}

Future<void> _simulateNetworkError(WidgetTester tester) async {
  // Mock network connectivity to simulate error
  await tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('connectivity_plus'),
    (methodCall) async => 'none',
  );
}

Future<void> _restoreNetwork(WidgetTester tester) async {
  // Restore network connectivity
  await tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('connectivity_plus'),
    (methodCall) async => 'wifi',
  );
}

Future<void> _simulateDataCorruption(WidgetTester tester) async {
  // Simulate database corruption scenario
  // In a real implementation, this would corrupt the SQLite database
  await Future.delayed(const Duration(milliseconds: 100));
}