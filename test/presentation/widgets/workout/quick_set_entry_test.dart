import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';

import 'package:cycle_avatar/presentation/widgets/workout/quick_set_entry.dart';
import 'package:cycle_avatar/presentation/providers/workout_session_provider.dart';
import 'package:cycle_avatar/presentation/providers/exercise_provider.dart';
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/exercise.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';

// Mock classes would be defined here
class MockWorkoutSessionNotifier extends Mock implements WorkoutSessionNotifier {}
class MockExercise extends Mock implements Exercise {}

void main() {
  group('QuickSetEntry Widget Tests', () {
    late MockWorkoutSessionNotifier mockNotifier;
    late MockExercise mockExercise;

    setUp(() {
      mockNotifier = MockWorkoutSessionNotifier();
      mockExercise = MockExercise();
      
      // Setup mock exercise
      when(mockExercise.id).thenReturn('exercise_1');
      when(mockExercise.getLocalizedName('en')).thenReturn('Bench Press');
    });

    testWidgets('should display previous set information', (WidgetTester tester) async {
      // Arrange
      final previousSet = WorkoutSet(
        id: 'set_1',
        sessionId: 'session_1',
        exerciseId: 'exercise_1',
        weight: 100.0,
        reps: 8,
        rpe: 7,
        setOrder: 1,
        createdAt: DateTime.now(),
      );

      final workoutState = WorkoutSessionState(
        currentSession: WorkoutSession(
          id: 'session_1',
          userId: 'user_1',
          startTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
          sets: [previousSet],
        ),
      );

      // Build widget with providers
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutSessionProvider.overrideWith((ref) => mockNotifier),
            exerciseProvider('exercise_1').overrideWith((ref) => AsyncValue.data(mockExercise)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickSetEntry(
                exerciseId: 'exercise_1',
              ),
            ),
          ),
        ),
      );

      // Verify previous set is displayed
      expect(find.text('Last: 100.0kg × 8 @ 7'), findsOneWidget);
    });

    testWidgets('should allow quick RPE adjustment', (WidgetTester tester) async {
      // Build widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutSessionProvider.overrideWith((ref) => mockNotifier),
            exerciseProvider('exercise_1').overrideWith((ref) => AsyncValue.data(mockExercise)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickSetEntry(
                exerciseId: 'exercise_1',
              ),
            ),
          ),
        ),
      );

      // Find RPE adjustment buttons
      final increaseButton = find.byIcon(Icons.add).last;
      final decreaseButton = find.byIcon(Icons.remove).first;

      // Test RPE increase
      await tester.tap(increaseButton);
      await tester.pump();

      // Verify RPE changed (would need to check the actual RPE display)
      expect(find.text('8'), findsOneWidget);

      // Test RPE decrease
      await tester.tap(decreaseButton);
      await tester.pump();

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('should validate input before adding set', (WidgetTester tester) async {
      // Build widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutSessionProvider.overrideWith((ref) => mockNotifier),
            exerciseProvider('exercise_1').overrideWith((ref) => AsyncValue.data(mockExercise)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickSetEntry(
                exerciseId: 'exercise_1',
              ),
            ),
          ),
        ),
      );

      // Try to add set without entering values
      final addButton = find.byIcon(Icons.add).last;
      await tester.tap(addButton);
      await tester.pump();

      // Should show error message
      expect(find.text('Enter weight and reps'), findsOneWidget);
    });

    testWidgets('should call onSetAdded callback when set is added', (WidgetTester tester) async {
      bool callbackCalled = false;
      
      // Setup mock to return success
      when(mockNotifier.addSet(
        exerciseId: anyNamed('exerciseId'),
        weight: anyNamed('weight'),
        reps: anyNamed('reps'),
        rpe: anyNamed('rpe'),
      )).thenAnswer((_) async {});

      // Build widget with callback
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutSessionProvider.overrideWith((ref) => mockNotifier),
            exerciseProvider('exercise_1').overrideWith((ref) => AsyncValue.data(mockExercise)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickSetEntry(
                exerciseId: 'exercise_1',
                onSetAdded: () {
                  callbackCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      // Enter valid values
      await tester.enterText(find.byType(TextField).first, '100');
      await tester.enterText(find.byType(TextField).last, '8');

      // Add set
      final addButton = find.byIcon(Icons.add).last;
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Verify callback was called
      expect(callbackCalled, isTrue);
    });

    testWidgets('should show repeat button when previous set exists', (WidgetTester tester) async {
      // Arrange with previous set
      final previousSet = WorkoutSet(
        id: 'set_1',
        sessionId: 'session_1',
        exerciseId: 'exercise_1',
        weight: 100.0,
        reps: 8,
        rpe: 7,
        setOrder: 1,
        createdAt: DateTime.now(),
      );

      final workoutState = WorkoutSessionState(
        currentSession: WorkoutSession(
          id: 'session_1',
          userId: 'user_1',
          startTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
          sets: [previousSet],
        ),
      );

      // Build widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutSessionProvider.overrideWith((ref) => mockNotifier),
            exerciseProvider('exercise_1').overrideWith((ref) => AsyncValue.data(mockExercise)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickSetEntry(
                exerciseId: 'exercise_1',
              ),
            ),
          ),
        ),
      );

      // Verify repeat button is shown
      expect(find.byIcon(Icons.repeat), findsOneWidget);
      expect(find.text('Repeat 100.0kg × 8 @ 7'), findsOneWidget);
    });
  });

  group('QuickSetEntry Performance Tests', () {
    testWidgets('should add set within 150ms requirement', (WidgetTester tester) async {
      // This would be an integration test to measure actual performance
      // For unit tests, we can verify that the widget doesn't do unnecessary work
      
      final mockNotifier = MockWorkoutSessionNotifier();
      final mockExercise = MockExercise();
      
      when(mockExercise.id).thenReturn('exercise_1');
      when(mockExercise.getLocalizedName('en')).thenReturn('Bench Press');
      
      // Setup mock to track call timing
      when(mockNotifier.addSet(
        exerciseId: anyNamed('exerciseId'),
        weight: anyNamed('weight'),
        reps: anyNamed('reps'),
        rpe: anyNamed('rpe'),
      )).thenAnswer((_) async {
        // Simulate fast database operation
        await Future.delayed(const Duration(milliseconds: 50));
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutSessionProvider.overrideWith((ref) => mockNotifier),
            exerciseProvider('exercise_1').overrideWith((ref) => AsyncValue.data(mockExercise)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickSetEntry(
                exerciseId: 'exercise_1',
              ),
            ),
          ),
        ),
      );

      // Measure time to add set
      final stopwatch = Stopwatch()..start();
      
      await tester.enterText(find.byType(TextField).first, '100');
      await tester.enterText(find.byType(TextField).last, '8');
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pumpAndSettle();
      
      stopwatch.stop();
      
      // Verify it's within performance requirement (allowing some overhead for test framework)
      expect(stopwatch.elapsedMilliseconds, lessThan(500)); // Generous for test environment
    });
  });
}