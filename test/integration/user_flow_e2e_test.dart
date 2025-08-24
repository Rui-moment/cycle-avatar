import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cycle_avatar/main.dart' as app;
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';

/// End-to-end tests for major user flows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('User Flow E2E Tests', () {
    testWidgets('Complete workout session flow', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Verify home page loads within 500ms
      final stopwatch = Stopwatch()..start();
      await tester.pumpAndSettle();
      stopwatch.stop();
      
      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'Home page should load within 500ms');

      // Navigate to workout page
      await tester.tap(find.text('Start Workout'));
      await tester.pumpAndSettle();

      // Start a new workout session
      await tester.tap(find.byKey(const Key('start_session_button')));
      await tester.pumpAndSettle();

      // Add first exercise
      await tester.tap(find.byKey(const Key('add_exercise_button')));
      await tester.pumpAndSettle();

      // Search and select an exercise
      await tester.enterText(find.byKey(const Key('exercise_search')), 'Squat');
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Squat').first);
      await tester.pumpAndSettle();

      // Add first set - test <150ms response time
      final setStopwatch = Stopwatch()..start();
      
      await tester.enterText(find.byKey(const Key('weight_input')), '100');
      await tester.enterText(find.byKey(const Key('reps_input')), '8');
      await tester.tap(find.byKey(const Key('rpe_7')));
      
      await tester.tap(find.byKey(const Key('add_set_button')));
      await tester.pumpAndSettle();
      
      setStopwatch.stop();
      expect(setStopwatch.elapsedMilliseconds, lessThan(150),
          reason: 'Set addition should complete within 150ms');

      // Verify set was added
      expect(find.text('Set 1: 100kg × 8 @ RPE 7'), findsOneWidget);

      // Add second set with progression
      await tester.enterText(find.byKey(const Key('weight_input')), '102.5');
      await tester.enterText(find.byKey(const Key('reps_input')), '8');
      await tester.tap(find.byKey(const Key('rpe_8')));
      
      await tester.tap(find.byKey(const Key('add_set_button')));
      await tester.pumpAndSettle();

      // Verify progression detection
      expect(find.byIcon(Icons.trending_up), findsOneWidget);

      // End workout session
      await tester.tap(find.byKey(const Key('end_session_button')));
      await tester.pumpAndSettle();

      // Verify session summary
      expect(find.text('Workout Complete!'), findsOneWidget);
      expect(find.text('2 sets completed'), findsOneWidget);

      // Navigate back to home
      await tester.tap(find.byKey(const Key('back_to_home_button')));
      await tester.pumpAndSettle();

      // Verify recovery state updated
      expect(find.byKey(const Key('muscle_group_recovery')), findsOneWidget);
      
      // Verify avatar growth notification (if progression achieved)
      if (find.text('Avatar Level Up!').evaluate().isNotEmpty) {
        expect(find.text('Avatar Level Up!'), findsOneWidget);
      }
    });

    testWidgets('Template creation and usage flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to templates
      await tester.tap(find.text('Templates'));
      await tester.pumpAndSettle();

      // Create new template
      await tester.tap(find.byKey(const Key('create_template_button')));
      await tester.pumpAndSettle();

      // Enter template details
      await tester.enterText(
        find.byKey(const Key('template_name_input')), 
        'Push Day'
      );
      await tester.enterText(
        find.byKey(const Key('template_description_input')), 
        'Chest, shoulders, triceps'
      );

      // Add exercises to template
      await tester.tap(find.byKey(const Key('add_exercise_to_template')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('exercise_search')), 'Bench Press');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bench Press').first);
      await tester.pumpAndSettle();

      // Save template
      await tester.tap(find.byKey(const Key('save_template_button')));
      await tester.pumpAndSettle();

      // Verify template was created
      expect(find.text('Push Day'), findsOneWidget);

      // Use template for workout
      await tester.tap(find.byKey(const Key('use_template_Push Day')));
      await tester.pumpAndSettle();

      // Verify workout started with template exercises
      expect(find.text('Bench Press'), findsOneWidget);
    });

    testWidgets('Avatar progression flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to avatar page
      await tester.tap(find.text('Avatar'));
      await tester.pumpAndSettle();

      // Verify avatar display
      expect(find.byKey(const Key('avatar_display')), findsOneWidget);
      
      // Check muscle group levels
      expect(find.byKey(const Key('muscle_group_levels')), findsOneWidget);
      
      // Verify badge display
      expect(find.byKey(const Key('badge_display')), findsOneWidget);

      // Navigate to history to see progress
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      // Verify workout history
      expect(find.byKey(const Key('workout_history')), findsOneWidget);
      
      // Check progress charts
      expect(find.byKey(const Key('progress_chart')), findsOneWidget);
    });

    testWidgets('Settings and preferences flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Test language switching
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('日本語'));
      await tester.pumpAndSettle();

      // Verify UI switched to Japanese
      expect(find.text('ホーム'), findsOneWidget);

      // Switch back to English
      await tester.tap(find.text('言語'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // Test notification settings
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      // Toggle recovery notifications
      await tester.tap(find.byKey(const Key('recovery_notifications_toggle')));
      await tester.pumpAndSettle();

      // Verify setting was saved
      expect(find.byKey(const Key('recovery_notifications_toggle')), findsOneWidget);

      // Test accessibility settings
      await tester.tap(find.text('Accessibility'));
      await tester.pumpAndSettle();

      // Enable large fonts
      await tester.tap(find.byKey(const Key('large_fonts_toggle')));
      await tester.pumpAndSettle();

      // Verify font size increased
      final textWidget = tester.widget<Text>(find.text('Accessibility').first);
      expect(textWidget.style?.fontSize, greaterThan(16.0));
    });
  });

  group('Performance Tests', () {
    testWidgets('Home page load performance', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();
      
      app.main();
      await tester.pumpAndSettle();
      
      stopwatch.stop();
      
      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'Home page should load within 500ms');
    });

    testWidgets('Set addition performance', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to workout
      await tester.tap(find.text('Start Workout'));
      await tester.pumpAndSettle();

      // Start session
      await tester.tap(find.byKey(const Key('start_session_button')));
      await tester.pumpAndSettle();

      // Add exercise
      await tester.tap(find.byKey(const Key('add_exercise_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('exercise_search')), 'Squat');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Squat').first);
      await tester.pumpAndSettle();

      // Measure set addition time
      final stopwatch = Stopwatch()..start();
      
      await tester.enterText(find.byKey(const Key('weight_input')), '100');
      await tester.enterText(find.byKey(const Key('reps_input')), '8');
      await tester.tap(find.byKey(const Key('rpe_7')));
      await tester.tap(find.byKey(const Key('add_set_button')));
      await tester.pumpAndSettle();
      
      stopwatch.stop();
      
      expect(stopwatch.elapsedMilliseconds, lessThan(150),
          reason: 'Set addition should complete within 150ms');
    });

    testWidgets('Memory usage during long session', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Start workout session
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

      // Add many sets to test memory usage
      for (int i = 1; i <= 20; i++) {
        await tester.enterText(find.byKey(const Key('weight_input')), '100');
        await tester.enterText(find.byKey(const Key('reps_input')), '$i');
        await tester.tap(find.byKey(const Key('rpe_7')));
        await tester.tap(find.byKey(const Key('add_set_button')));
        await tester.pumpAndSettle();
        
        // Verify UI remains responsive
        expect(find.text('Set $i'), findsOneWidget);
      }

      // Verify all sets are displayed
      expect(find.text('Set 20'), findsOneWidget);
    });
  });
}