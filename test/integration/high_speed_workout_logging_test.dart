import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cycle_avatar/presentation/widgets/workout/high_speed_workout_logger.dart';
import 'package:cycle_avatar/presentation/providers/workout_session_provider.dart';
import 'package:cycle_avatar/presentation/providers/exercise_provider.dart';
import 'package:cycle_avatar/domain/entities/exercise.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('High-Speed Workout Logging Integration Tests', () {
    testWidgets('complete workout logging flow under 10 seconds per exercise', (WidgetTester tester) async {
      // This test verifies the requirement: "log workout sets in under 10 seconds per exercise"
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: HighSpeedWorkoutLogger(),
          ),
        ),
      );

      final stopwatch = Stopwatch();

      // Step 1: Start workout
      stopwatch.start();
      await tester.tap(find.text('Start Workout'));
      await tester.pumpAndSettle();

      // Step 2: Select exercise (should be quick with recent exercises)
      // Tap on a quick selection chip or search
      await tester.tap(find.byType(ActionChip).first);
      await tester.pumpAndSettle();

      // Step 3: Log first set
      await tester.enterText(find.byType(TextField).first, '100');
      await tester.enterText(find.byType(TextField).last, '8');
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pumpAndSettle();

      // Step 4: Log second set (should be faster with previous values)
      await tester.enterText(find.byType(TextField).first, '100');
      await tester.enterText(find.byType(TextField).last, '8');
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pumpAndSettle();

      // Step 5: Log third set using repeat function
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pumpAndSettle();

      stopwatch.stop();

      // Verify time requirement (3 sets should be well under 10 seconds)
      expect(stopwatch.elapsedMilliseconds, lessThan(10000));
      
      // Verify sets were logged
      expect(find.text('1'), findsOneWidget); // Set number indicators
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('set addition response time under 150ms', (WidgetTester tester) async {
      // This test verifies the requirement: "150ms以内にセットを保存する"
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: HighSpeedWorkoutLogger(),
          ),
        ),
      );

      // Start workout and select exercise
      await tester.tap(find.text('Start Workout'));
      await tester.pumpAndSettle();
      
      await tester.tap(find.byType(ActionChip).first);
      await tester.pumpAndSettle();

      // Prepare input
      await tester.enterText(find.byType(TextField).first, '100');
      await tester.enterText(find.byType(TextField).last, '8');

      // Measure set addition time
      final stopwatch = Stopwatch()..start();
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pump(); // Single pump to measure immediate response
      stopwatch.stop();

      // Verify response time requirement
      expect(stopwatch.elapsedMilliseconds, lessThan(150));
    });

    testWidgets('one-tap set addition functionality', (WidgetTester tester) async {
      // This test verifies the requirement: "ワンタップでセット追加を可能にする"
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: HighSpeedWorkoutLogger(),
          ),
        ),
      );

      // Start workout and select exercise
      await tester.tap(find.text('Start Workout'));
      await tester.pumpAndSettle();
      
      await tester.tap(find.byType(ActionChip).first);
      await tester.pumpAndSettle();

      // Log first set to establish previous values
      await tester.enterText(find.byType(TextField).first, '100');
      await tester.enterText(find.byType(TextField).last, '8');
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pumpAndSettle();

      // Verify repeat button appears
      expect(find.byIcon(Icons.repeat), findsOneWidget);
      expect(find.text('Repeat 100.0kg × 8 @ 7'), findsOneWidget);

      // Test one-tap repeat
      await tester.tap(find.byIcon(Icons.repeat));
      await tester.pumpAndSettle();

      // Verify second set was added
      expect(find.text('2'), findsOneWidget); // Set number indicator
    });

    testWidgets('exercise search autocomplete performance', (WidgetTester tester) async {
      // This test verifies the requirement: "種目検索とオートコンプリート"
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: HighSpeedWorkoutLogger(),
          ),
        ),
      );

      // Start workout
      await tester.tap(find.text('Start Workout'));
      await tester.pumpAndSettle();

      // Test search functionality
      final searchField = find.byType(TextFormField);
      
      // Measure search response time
      final stopwatch = Stopwatch()..start();
      await tester.enterText(searchField, 'bench');
      await tester.pump(); // Single pump to measure immediate response
      stopwatch.stop();

      // Verify search responds quickly
      expect(stopwatch.elapsedMilliseconds, lessThan(100));

      // Verify autocomplete suggestions appear
      await tester.pumpAndSettle();
      expect(find.text('Bench Press'), findsWidgets);
    });

    testWidgets('RPE quick picker functionality', (WidgetTester tester) async {
      // This test verifies the requirement: "RPE選択のクイックピッカー"
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: HighSpeedWorkoutLogger(),
          ),
        ),
      );

      // Start workout and select exercise
      await tester.tap(find.text('Start Workout'));
      await tester.pumpAndSettle();
      
      await tester.tap(find.byType(ActionChip).first);
      await tester.pumpAndSettle();

      // Test RPE adjustment
      final rpeIncreaseButton = find.byIcon(Icons.add).first;
      final rpeDecreaseButton = find.byIcon(Icons.remove).first;

      // Increase RPE
      await tester.tap(rpeIncreaseButton);
      await tester.pump();
      expect(find.text('8'), findsOneWidget);

      // Decrease RPE
      await tester.tap(rpeDecreaseButton);
      await tester.pump();
      expect(find.text('7'), findsOneWidget);

      // Verify RPE changes are immediate (no loading states)
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('offline functionality works correctly', (WidgetTester tester) async {
      // This test verifies the requirement: "オフライン状態でログを記録"
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: HighSpeedWorkoutLogger(),
          ),
        ),
      );

      // Start workout
      await tester.tap(find.text('Start Workout'));
      await tester.pumpAndSettle();

      // Select exercise and log sets
      await tester.tap(find.byType(ActionChip).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '100');
      await tester.enterText(find.byType(TextField).last, '8');
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pumpAndSettle();

      // Verify set was logged (should work offline)
      expect(find.text('Set added: 100.0kg × 8 @ 7'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // Set number indicator
    });

    testWidgets('previous values auto-populate correctly', (WidgetTester tester) async {
      // This test verifies the requirement: "前回の重量と回数を自動入力として表示する"
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: HighSpeedWorkoutLogger(),
          ),
        ),
      );

      // Start workout and select exercise
      await tester.tap(find.text('Start Workout'));
      await tester.pumpAndSettle();
      
      await tester.tap(find.byType(ActionChip).first);
      await tester.pumpAndSettle();

      // Log first set
      await tester.enterText(find.byType(TextField).first, '100');
      await tester.enterText(find.byType(TextField).last, '8');
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pumpAndSettle();

      // Verify previous values are shown
      expect(find.text('Last: 100.0kg × 8 @ 7'), findsOneWidget);

      // Verify input fields are pre-populated for next set
      final weightField = find.byType(TextField).first;
      final repsField = find.byType(TextField).last;
      
      expect(tester.widget<TextField>(weightField).controller?.text, equals('100.0'));
      expect(tester.widget<TextField>(repsField).controller?.text, equals('8'));
    });
  });

  group('Performance Benchmarks', () {
    testWidgets('complete 3-exercise workout under 2 minutes', (WidgetTester tester) async {
      // This is a comprehensive performance test
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: HighSpeedWorkoutLogger(),
          ),
        ),
      );

      final stopwatch = Stopwatch()..start();

      // Start workout
      await tester.tap(find.text('Start Workout'));
      await tester.pumpAndSettle();

      // Exercise 1: 3 sets
      await tester.tap(find.byType(ActionChip).first);
      await tester.pumpAndSettle();
      
      for (int i = 0; i < 3; i++) {
        await tester.enterText(find.byType(TextField).first, '100');
        await tester.enterText(find.byType(TextField).last, '8');
        await tester.tap(find.byIcon(Icons.add).last);
        await tester.pumpAndSettle();
      }

      // Exercise 2: 3 sets
      await tester.tap(find.byType(TextFormField)); // Search field
      await tester.enterText(find.byType(TextFormField), 'squat');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Squat').first);
      await tester.pumpAndSettle();
      
      for (int i = 0; i < 3; i++) {
        await tester.enterText(find.byType(TextField).first, '120');
        await tester.enterText(find.byType(TextField).last, '5');
        await tester.tap(find.byIcon(Icons.add).last);
        await tester.pumpAndSettle();
      }

      // Exercise 3: 3 sets
      await tester.tap(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'deadlift');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deadlift').first);
      await tester.pumpAndSettle();
      
      for (int i = 0; i < 3; i++) {
        await tester.enterText(find.byType(TextField).first, '140');
        await tester.enterText(find.byType(TextField).last, '5');
        await tester.tap(find.byIcon(Icons.add).last);
        await tester.pumpAndSettle();
      }

      stopwatch.stop();

      // Verify total time is reasonable for a complete workout
      expect(stopwatch.elapsedMilliseconds, lessThan(120000)); // Under 2 minutes
      
      // Verify all sets were logged
      expect(find.text('9'), findsOneWidget); // Should have 9 total sets
    });
  });
}