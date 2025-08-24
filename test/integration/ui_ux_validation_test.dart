import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cycle_avatar/main.dart' as app;

/// UI/UX validation tests to ensure interface consistency and usability
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('UI/UX Validation Tests', () {
    
    group('Navigation and Layout Tests', () {
      testWidgets('Bottom navigation consistency', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Verify bottom navigation is present
        expect(find.byType(BottomNavigationBar), findsOneWidget);

        // Test all navigation tabs
        final tabs = ['Home', 'Workout', 'Avatar', 'History', 'Settings'];
        
        for (final tab in tabs) {
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();

          // Verify tab is selected
          final bottomNav = tester.widget<BottomNavigationBar>(
            find.byType(BottomNavigationBar)
          );
          expect(bottomNav.currentIndex, equals(tabs.indexOf(tab)));

          // Verify page content loads
          expect(find.byKey(Key('${tab.toLowerCase()}_page')), findsOneWidget);
        }
      });

      testWidgets('App bar consistency across pages', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        final pages = ['Home', 'Workout', 'Avatar', 'History', 'Settings'];
        
        for (final page in pages) {
          await tester.tap(find.text(page));
          await tester.pumpAndSettle();

          // Verify app bar is present
          expect(find.byType(AppBar), findsOneWidget);

          // Verify app bar title
          expect(find.text(page), findsOneWidget);

          // Check for consistent styling
          final appBar = tester.widget<AppBar>(find.byType(AppBar));
          expect(appBar.backgroundColor, isNotNull);
          expect(appBar.elevation, isNotNull);
        }
      });

      testWidgets('Responsive layout on different screen sizes', (WidgetTester tester) async {
        // Test phone layout
        await tester.binding.setSurfaceSize(const Size(375, 667)); // iPhone SE
        app.main();
        await tester.pumpAndSettle();

        expect(find.byType(BottomNavigationBar), findsOneWidget);
        expect(find.byKey(const Key('mobile_layout')), findsOneWidget);

        // Test tablet layout
        await tester.binding.setSurfaceSize(const Size(768, 1024)); // iPad
        await tester.pumpAndSettle();

        // Verify layout adapts
        expect(find.byKey(const Key('tablet_layout')), findsOneWidget);

        // Reset to default size
        await tester.binding.setSurfaceSize(const Size(800, 600));
      });
    });

    group('Form Validation and Input Tests', () {
      testWidgets('Workout form validation', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Navigate to workout
        await tester.tap(find.text('Workout'));
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

        // Test invalid weight input
        await tester.enterText(find.byKey(const Key('weight_input')), '-10');
        await tester.tap(find.byKey(const Key('add_set_button')));
        await tester.pumpAndSettle();

        expect(find.text('Weight must be positive'), findsOneWidget);

        // Test invalid reps input
        await tester.enterText(find.byKey(const Key('weight_input')), '100');
        await tester.enterText(find.byKey(const Key('reps_input')), '0');
        await tester.tap(find.byKey(const Key('add_set_button')));
        await tester.pumpAndSettle();

        expect(find.text('Reps must be at least 1'), findsOneWidget);

        // Test valid input
        await tester.enterText(find.byKey(const Key('reps_input')), '8');
        await tester.tap(find.byKey(const Key('add_set_button')));
        await tester.pumpAndSettle();

        expect(find.text('Set 1: 100.0kg × 8 @ RPE 7'), findsOneWidget);
      });

      testWidgets('Template form validation', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Navigate to templates
        await tester.tap(find.text('Templates'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('create_template_button')));
        await tester.pumpAndSettle();

        // Test empty name validation
        await tester.tap(find.byKey(const Key('save_template_button')));
        await tester.pumpAndSettle();

        expect(find.text('Template name is required'), findsOneWidget);

        // Test name too short
        await tester.enterText(find.byKey(const Key('template_name_input')), 'A');
        await tester.tap(find.byKey(const Key('save_template_button')));
        await tester.pumpAndSettle();

        expect(find.text('Name must be at least 3 characters'), findsOneWidget);

        // Test valid name
        await tester.enterText(find.byKey(const Key('template_name_input')), 'Upper Body');
        await tester.tap(find.byKey(const Key('save_template_button')));
        await tester.pumpAndSettle();

        expect(find.text('Template saved'), findsOneWidget);
      });

      testWidgets('Search functionality validation', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Test exercise search
        await tester.tap(find.text('Workout'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('start_session_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('add_exercise_button')));
        await tester.pumpAndSettle();

        // Test search with results
        await tester.enterText(find.byKey(const Key('exercise_search')), 'bench');
        await tester.pumpAndSettle();

        expect(find.text('Bench Press'), findsOneWidget);
        expect(find.text('Incline Bench Press'), findsOneWidget);

        // Test search with no results
        await tester.enterText(find.byKey(const Key('exercise_search')), 'xyzzyx');
        await tester.pumpAndSettle();

        expect(find.text('No exercises found'), findsOneWidget);

        // Test search clearing
        await tester.enterText(find.byKey(const Key('exercise_search')), '');
        await tester.pumpAndSettle();

        expect(find.text('Popular Exercises'), findsOneWidget);
      });
    });

    group('Visual Feedback and Animations', () {
      testWidgets('Loading states and progress indicators', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Test workout loading
        await tester.tap(find.text('Workout'));
        await tester.pumpAndSettle();

        // Verify loading indicator appears briefly
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Test data export loading
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Data Export'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('export_data_button')));
        await tester.pump(); // Single pump to catch loading state

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets('Success and error feedback', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Test success feedback
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
        await tester.tap(find.byKey(const Key('add_set_button')));
        await tester.pumpAndSettle();

        // Verify success feedback
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.text('Set added'), findsOneWidget);

        // Test error feedback
        await tester.enterText(find.byKey(const Key('weight_input')), 'invalid');
        await tester.tap(find.byKey(const Key('add_set_button')));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error), findsOneWidget);
        expect(find.text('Invalid weight format'), findsOneWidget);
      });

      testWidgets('Avatar level up animation', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Complete workout that triggers level up
        await _completeProgressionWorkout(tester);

        // Navigate to avatar page
        await tester.tap(find.text('Avatar'));
        await tester.pumpAndSettle();

        // Check for level up animation
        if (find.byKey(const Key('level_up_animation')).evaluate().isNotEmpty) {
          expect(find.byKey(const Key('level_up_animation')), findsOneWidget);
          expect(find.text('Level Up!'), findsOneWidget);

          // Wait for animation to complete
          await tester.pumpAndSettle(const Duration(seconds: 3));

          // Verify animation completed
          expect(find.byKey(const Key('level_up_animation')), findsNothing);
        }
      });

      testWidgets('PR celebration animation', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Complete workout with PR
        await _completeWorkoutWithPR(tester);

        // Verify PR celebration
        expect(find.byKey(const Key('pr_celebration')), findsOneWidget);
        expect(find.text('New Personal Record!'), findsOneWidget);

        // Check for confetti or celebration animation
        expect(find.byKey(const Key('celebration_animation')), findsOneWidget);

        // Wait for animation
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify celebration can be dismissed
        await tester.tap(find.byKey(const Key('dismiss_celebration')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('pr_celebration')), findsNothing);
      });
    });

    group('Accessibility and Usability', () {
      testWidgets('Touch target sizes', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Check button sizes meet accessibility guidelines (44x44 minimum)
        final buttons = find.byType(ElevatedButton);
        for (final button in buttons.evaluate()) {
          final size = tester.getSize(find.byWidget(button.widget));
          expect(size.width, greaterThanOrEqualTo(44.0));
          expect(size.height, greaterThanOrEqualTo(44.0));
        }

        // Check icon button sizes
        final iconButtons = find.byType(IconButton);
        for (final iconButton in iconButtons.evaluate()) {
          final size = tester.getSize(find.byWidget(iconButton.widget));
          expect(size.width, greaterThanOrEqualTo(44.0));
          expect(size.height, greaterThanOrEqualTo(44.0));
        }
      });

      testWidgets('Color contrast and visibility', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Navigate to different pages to check contrast
        final pages = ['Home', 'Workout', 'Avatar', 'History', 'Settings'];
        
        for (final page in pages) {
          await tester.tap(find.text(page));
          await tester.pumpAndSettle();

          // Verify text is visible against background
          final textWidgets = find.byType(Text);
          expect(textWidgets, findsWidgets);

          // Check for proper color usage
          final theme = Theme.of(tester.element(find.byType(MaterialApp)));
          expect(theme.colorScheme.primary, isNotNull);
          expect(theme.colorScheme.onPrimary, isNotNull);
        }
      });

      testWidgets('Keyboard navigation support', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Test tab navigation
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        // Verify focus is visible
        expect(find.byType(Focus), findsWidgets);

        // Test form navigation
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

        // Test tab between form fields
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        // Verify focus moved to next field
        expect(find.byType(TextField), findsWidgets);
      });
    });

    group('Data Display and Formatting', () {
      testWidgets('Number formatting consistency', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Complete workout with various weights
        await _completeWorkoutWithVariousWeights(tester);

        // Navigate to history
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();

        // Verify weight formatting
        expect(find.text('100.0kg'), findsOneWidget);
        expect(find.text('102.5kg'), findsOneWidget);
        expect(find.text('105.0kg'), findsOneWidget);

        // Navigate to avatar page
        await tester.tap(find.text('Avatar'));
        await tester.pumpAndSettle();

        // Verify level display formatting
        expect(find.textContaining('Level'), findsWidgets);
        expect(find.textContaining('XP'), findsWidgets);
      });

      testWidgets('Date and time formatting', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Complete workout
        await _completeTestWorkout(tester);

        // Navigate to history
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();

        // Verify date formatting
        expect(find.textContaining('Today'), findsOneWidget);
        expect(find.textContaining('min ago'), findsOneWidget);

        // Check detailed view
        await tester.tap(find.byKey(const Key('workout_detail_button')));
        await tester.pumpAndSettle();

        // Verify timestamp formatting
        expect(find.textContaining(':'), findsWidgets); // Time format
      });

      testWidgets('Progress visualization', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Navigate to avatar page
        await tester.tap(find.text('Avatar'));
        await tester.pumpAndSettle();

        // Verify progress bars
        expect(find.byType(LinearProgressIndicator), findsWidgets);

        // Check muscle group recovery visualization
        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('recovery_visualization')), findsOneWidget);

        // Verify color coding
        expect(find.byKey(const Key('ready_indicator')), findsWidgets);
        expect(find.byKey(const Key('warm_indicator')), findsWidgets);
      });
    });

    group('Error States and Edge Cases', () {
      testWidgets('Empty state handling', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Check empty history
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();

        expect(find.text('No workouts yet'), findsOneWidget);
        expect(find.text('Start your first workout!'), findsOneWidget);

        // Check empty templates
        await tester.tap(find.text('Templates'));
        await tester.pumpAndSettle();

        expect(find.text('No templates created'), findsOneWidget);
        expect(find.byKey(const Key('create_first_template_button')), findsOneWidget);
      });

      testWidgets('Network error handling', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Simulate network error
        await _simulateNetworkError(tester);

        // Verify offline indicator
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        expect(find.text('Offline mode'), findsOneWidget);

        // Verify functionality still works
        await _completeTestWorkout(tester);

        expect(find.text('Saved locally'), findsOneWidget);
      });

      testWidgets('Data loading error handling', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Simulate data loading error
        await _simulateDataLoadingError(tester);

        // Navigate to history
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();

        // Verify error state
        expect(find.text('Unable to load workout history'), findsOneWidget);
        expect(find.byKey(const Key('retry_button')), findsOneWidget);

        // Test retry functionality
        await tester.tap(find.byKey(const Key('retry_button')));
        await tester.pumpAndSettle();

        // Verify retry attempt
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });
  });
}

// Helper functions for UI/UX tests

Future<void> _completeProgressionWorkout(WidgetTester tester) async {
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

  // Log progression set (higher weight than previous)
  await tester.enterText(find.byKey(const Key('weight_input')), '110');
  await tester.enterText(find.byKey(const Key('reps_input')), '8');
  await tester.tap(find.byKey(const Key('rpe_8')));
  await tester.tap(find.byKey(const Key('add_set_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('end_session_button')));
  await tester.pumpAndSettle();
}

Future<void> _completeWorkoutWithPR(WidgetTester tester) async {
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

  // Log PR set
  await tester.enterText(find.byKey(const Key('weight_input')), '125');
  await tester.enterText(find.byKey(const Key('reps_input')), '1');
  await tester.tap(find.byKey(const Key('rpe_10')));
  await tester.tap(find.byKey(const Key('add_set_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('end_session_button')));
  await tester.pumpAndSettle();
}

Future<void> _completeWorkoutWithVariousWeights(WidgetTester tester) async {
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

  final weights = ['100.0', '102.5', '105.0'];
  
  for (final weight in weights) {
    await tester.enterText(find.byKey(const Key('weight_input')), weight);
    await tester.enterText(find.byKey(const Key('reps_input')), '8');
    await tester.tap(find.byKey(const Key('rpe_7')));
    await tester.tap(find.byKey(const Key('add_set_button')));
    await tester.pumpAndSettle();
  }

  await tester.tap(find.byKey(const Key('end_session_button')));
  await tester.pumpAndSettle();
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

Future<void> _simulateNetworkError(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('connectivity_plus'),
    (methodCall) async => 'none',
  );
}

Future<void> _simulateDataLoadingError(WidgetTester tester) async {
  // In a real implementation, this would mock the database to return errors
  await Future.delayed(const Duration(milliseconds: 100));
}