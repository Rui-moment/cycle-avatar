import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';

import 'package:cycle_avatar/presentation/widgets/workout/exercise_search_field.dart';
import 'package:cycle_avatar/presentation/providers/exercise_provider.dart';
import 'package:cycle_avatar/domain/entities/exercise.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';

// Mock classes
class MockExercise extends Mock implements Exercise {}

void main() {
  group('ExerciseSearchField Widget Tests', () {
    late List<Exercise> mockExercises;
    late List<Exercise> mockRecentExercises;

    setUp(() {
      // Setup mock exercises
      mockExercises = [
        _createMockExercise('1', 'Bench Press', 'chest'),
        _createMockExercise('2', 'Squat', 'legs'),
        _createMockExercise('3', 'Deadlift', 'back'),
      ];

      mockRecentExercises = [
        _createMockExercise('1', 'Bench Press', 'chest'),
        _createMockExercise('2', 'Squat', 'legs'),
      ];
    });

    testWidgets('should display recent exercises as quick selection chips', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickAccessExercisesProvider.overrideWith((ref) => AsyncValue.data(mockRecentExercises)),
            exerciseSearchProvider(any).overrideWith((ref) => AsyncValue.data([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ExerciseSearchField(
                onExerciseSelected: (exercise) {},
                enableQuickSelection: true,
                showRecentExercises: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify quick selection chips are displayed
      expect(find.byType(ActionChip), findsNWidgets(2));
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Squat'), findsOneWidget);
    });

    testWidgets('should filter exercises based on search query', (WidgetTester tester) async {
      Exercise? selectedExercise;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickAccessExercisesProvider.overrideWith((ref) => AsyncValue.data(mockRecentExercises)),
            exerciseSearchProvider(any).overrideWith((ref) {
              final params = ref.arg as Map<String, String>;
              final query = params['query'] ?? '';
              
              if (query.isEmpty) return AsyncValue.data(mockExercises);
              
              final filtered = mockExercises
                  .where((e) => e.getLocalizedName('en').toLowerCase().contains(query.toLowerCase()))
                  .toList();
              
              return AsyncValue.data(filtered);
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ExerciseSearchField(
                onExerciseSelected: (exercise) {
                  selectedExercise = exercise;
                },
              ),
            ),
          ),
        ),
      );

      // Enter search query
      await tester.enterText(find.byType(TextFormField), 'bench');
      await tester.pumpAndSettle();

      // Verify filtered results
      expect(find.text('Bench Press'), findsWidgets);
      expect(find.text('Squat'), findsNothing);
      expect(find.text('Deadlift'), findsNothing);
    });

    testWidgets('should call onExerciseSelected when exercise is tapped', (WidgetTester tester) async {
      Exercise? selectedExercise;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickAccessExercisesProvider.overrideWith((ref) => AsyncValue.data(mockRecentExercises)),
            exerciseSearchProvider(any).overrideWith((ref) => AsyncValue.data(mockExercises)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ExerciseSearchField(
                onExerciseSelected: (exercise) {
                  selectedExercise = exercise;
                },
              ),
            ),
          ),
        ),
      );

      // Tap on search field to show suggestions
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      // Tap on an exercise
      await tester.tap(find.text('Bench Press').last);
      await tester.pumpAndSettle();

      // Verify callback was called
      expect(selectedExercise, isNotNull);
      expect(selectedExercise!.getLocalizedName('en'), equals('Bench Press'));
    });

    testWidgets('should show recent exercises when field is focused and empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickAccessExercisesProvider.overrideWith((ref) => AsyncValue.data(mockRecentExercises)),
            exerciseSearchProvider(any).overrideWith((ref) => AsyncValue.data(mockExercises)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ExerciseSearchField(
                onExerciseSelected: (exercise) {},
                showRecentExercises: true,
              ),
            ),
          ),
        ),
      );

      // Focus on the search field
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      // Verify recent exercises section is shown
      expect(find.text('Recent Exercises'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsWidgets);
    });

    testWidgets('should clear search when clear button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickAccessExercisesProvider.overrideWith((ref) => AsyncValue.data(mockRecentExercises)),
            exerciseSearchProvider(any).overrideWith((ref) => AsyncValue.data(mockExercises)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ExerciseSearchField(
                onExerciseSelected: (exercise) {},
              ),
            ),
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(TextFormField), 'bench');
      await tester.pumpAndSettle();

      // Verify clear button appears
      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // Verify text is cleared
      expect(find.text('bench'), findsNothing);
    });

    testWidgets('should select exercise from quick selection chip', (WidgetTester tester) async {
      Exercise? selectedExercise;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickAccessExercisesProvider.overrideWith((ref) => AsyncValue.data(mockRecentExercises)),
            exerciseSearchProvider(any).overrideWith((ref) => AsyncValue.data([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ExerciseSearchField(
                onExerciseSelected: (exercise) {
                  selectedExercise = exercise;
                },
                enableQuickSelection: true,
                showRecentExercises: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on a quick selection chip
      await tester.tap(find.byType(ActionChip).first);
      await tester.pumpAndSettle();

      // Verify exercise was selected
      expect(selectedExercise, isNotNull);
      expect(selectedExercise!.getLocalizedName('en'), equals('Bench Press'));
    });
  });

  group('ExerciseSearchField Performance Tests', () {
    testWidgets('should handle rapid typing without lag', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickAccessExercisesProvider.overrideWith((ref) => AsyncValue.data([])),
            exerciseSearchProvider(any).overrideWith((ref) => AsyncValue.data([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ExerciseSearchField(
                onExerciseSelected: (exercise) {},
              ),
            ),
          ),
        ),
      );

      final textField = find.byType(TextFormField);
      
      // Simulate rapid typing
      const queries = ['b', 'be', 'ben', 'benc', 'bench'];
      
      for (final query in queries) {
        await tester.enterText(textField, query);
        await tester.pump(const Duration(milliseconds: 50)); // Fast typing
      }

      // Should not crash or show errors
      expect(tester.takeException(), isNull);
    });
  });
}

Exercise _createMockExercise(String id, String name, String category) {
  return Exercise(
    id: id,
    names: {'en': name},
    category: category,
    equipment: EquipmentType.barbell,
    instructions: {'en': 'Instructions for $name'},
    primaryMuscleGroups: [category],
    secondaryMuscleGroups: [],
    isCompound: true,
    createdAt: DateTime.now(),
  );
}