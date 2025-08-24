import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../lib/data/datasources/local/database_helper.dart';
import '../../../lib/data/repositories/exercise_repository.dart';
import '../../../lib/domain/entities/exercise.dart';
import '../../../lib/domain/entities/enums.dart';

void main() {
  late DatabaseHelper databaseHelper;
  late ExerciseRepository exerciseRepository;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databaseHelper = DatabaseHelper();
    exerciseRepository = ExerciseRepositoryImpl(databaseHelper);
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  group('ExerciseRepository', () {
    final testExercise = Exercise(
      id: 'test_exercise',
      names: {'en': 'Test Exercise', 'ja': 'テスト運動'},
      category: 'strength',
      equipment: EquipmentType.dumbbell,
      instructions: {
        'en': 'Perform the exercise correctly',
        'ja': '正しく運動を行う'
      },
      primaryMuscleGroups: ['chest', 'shoulders'],
      secondaryMuscleGroups: ['triceps'],
      isCompound: true,
      createdAt: DateTime.now(),
    );

    group('Create Operations', () {
      test('should create exercise successfully', () async {
        final createdExercise = await exerciseRepository.create(testExercise);
        
        expect(createdExercise, equals(testExercise));
        
        // Verify exercise was saved to database
        final foundExercise = await exerciseRepository.findById(testExercise.id);
        expect(foundExercise, isNotNull);
        expect(foundExercise!.names, equals(testExercise.names));
      });

      test('should throw exception when creating exercise with invalid data', () async {
        final invalidExercise = Exercise(
          id: '',
          names: {},
          category: '',
          equipment: EquipmentType.barbell,
          instructions: {},
          primaryMuscleGroups: [],
          secondaryMuscleGroups: [],
          createdAt: DateTime.now(),
        );

        expect(
          () => exerciseRepository.create(invalidExercise),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('should create multiple exercises in batch', () async {
        final exercises = [
          testExercise,
          testExercise.copyWith(
            id: 'exercise_2',
            names: {'en': 'Exercise 2', 'ja': '運動2'},
          ),
          testExercise.copyWith(
            id: 'exercise_3',
            names: {'en': 'Exercise 3', 'ja': '運動3'},
          ),
        ];

        final createdExercises = await exerciseRepository.createBatch(exercises);
        
        expect(createdExercises.length, equals(3));
        
        // Verify all exercises were created
        for (final exercise in exercises) {
          final foundExercise = await exerciseRepository.findById(exercise.id);
          expect(foundExercise, isNotNull);
        }
      });
    });

    group('Read Operations', () {
      setUp(() async {
        await exerciseRepository.create(testExercise);
      });

      test('should find exercise by id', () async {
        final foundExercise = await exerciseRepository.findById(testExercise.id);
        
        expect(foundExercise, isNotNull);
        expect(foundExercise!.id, equals(testExercise.id));
        expect(foundExercise.names, equals(testExercise.names));
        expect(foundExercise.equipment, equals(testExercise.equipment));
      });

      test('should return null when exercise not found', () async {
        final foundExercise = await exerciseRepository.findById('non_existent_id');
        expect(foundExercise, isNull);
      });

      test('should find all exercises', () async {
        // The database already has initial exercises, plus our test exercise
        final allExercises = await exerciseRepository.findAll();
        
        expect(allExercises.length, greaterThan(0));
        expect(allExercises.map((e) => e.id), contains(testExercise.id));
      });

      test('should find exercises by category', () async {
        final exercisesByCategory = await exerciseRepository.findByCategory('strength');
        
        expect(exercisesByCategory, isNotEmpty);
        expect(exercisesByCategory.map((e) => e.id), contains(testExercise.id));
        
        for (final exercise in exercisesByCategory) {
          expect(exercise.category, equals('strength'));
        }
      });

      test('should find exercises by equipment', () async {
        final exercisesByEquipment = await exerciseRepository.findByEquipment(EquipmentType.dumbbell);
        
        expect(exercisesByEquipment, isNotEmpty);
        expect(exercisesByEquipment.map((e) => e.id), contains(testExercise.id));
        
        for (final exercise in exercisesByEquipment) {
          expect(exercise.equipment, equals(EquipmentType.dumbbell));
        }
      });

      test('should find exercises by muscle group', () async {
        final exercisesByMuscleGroup = await exerciseRepository.findByMuscleGroup('chest');
        
        expect(exercisesByMuscleGroup, isNotEmpty);
        expect(exercisesByMuscleGroup.map((e) => e.id), contains(testExercise.id));
        
        for (final exercise in exercisesByMuscleGroup) {
          expect(
            exercise.primaryMuscleGroups.contains('chest') ||
            exercise.secondaryMuscleGroups.contains('chest'),
            isTrue,
          );
        }
      });

      test('should find compound exercises', () async {
        final compoundExercises = await exerciseRepository.findCompoundExercises();
        
        expect(compoundExercises, isNotEmpty);
        expect(compoundExercises.map((e) => e.id), contains(testExercise.id));
        
        for (final exercise in compoundExercises) {
          expect(exercise.isCompound, isTrue);
        }
      });

      test('should search exercises by name in English', () async {
        final searchResults = await exerciseRepository.searchByName('Test', locale: 'en');
        
        expect(searchResults, isNotEmpty);
        expect(searchResults.map((e) => e.id), contains(testExercise.id));
      });

      test('should search exercises by name in Japanese', () async {
        final searchResults = await exerciseRepository.searchByName('テスト', locale: 'ja');
        
        expect(searchResults, isNotEmpty);
        expect(searchResults.map((e) => e.id), contains(testExercise.id));
      });

      test('should return empty list for non-matching search', () async {
        final searchResults = await exerciseRepository.searchByName('NonExistentExercise');
        
        expect(searchResults, isEmpty);
      });

      test('should find exercises by training goal', () async {
        final strengthExercises = await exerciseRepository.findByTrainingGoal(TrainingGoal.strength);
        
        expect(strengthExercises, isNotEmpty);
        // Should include compound exercises for strength training
        expect(strengthExercises.map((e) => e.id), contains(testExercise.id));
      });
    });

    group('Update Operations', () {
      setUp(() async {
        await exerciseRepository.create(testExercise);
      });

      test('should update exercise successfully', () async {
        final updatedExercise = testExercise.copyWith(
          names: {'en': 'Updated Exercise', 'ja': '更新された運動'},
          category: 'updated_category',
          equipment: EquipmentType.machine,
        );

        final result = await exerciseRepository.update(updatedExercise);
        
        expect(result.names, equals(updatedExercise.names));
        expect(result.category, equals('updated_category'));
        expect(result.equipment, equals(EquipmentType.machine));
        
        // Verify update in database
        final foundExercise = await exerciseRepository.findById(testExercise.id);
        expect(foundExercise!.names, equals(updatedExercise.names));
        expect(foundExercise.category, equals('updated_category'));
      });

      test('should throw exception when updating non-existent exercise', () async {
        final nonExistentExercise = testExercise.copyWith(id: 'non_existent');

        expect(
          () => exerciseRepository.update(nonExistentExercise),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('should update multiple exercises in batch', () async {
        // Create additional exercise
        final exercise2 = testExercise.copyWith(
          id: 'exercise_2',
          names: {'en': 'Exercise 2', 'ja': '運動2'},
        );
        await exerciseRepository.create(exercise2);

        final updatedExercises = [
          testExercise.copyWith(category: 'updated_1'),
          exercise2.copyWith(category: 'updated_2'),
        ];

        await exerciseRepository.updateBatch(updatedExercises);

        // Verify updates
        final foundExercise1 = await exerciseRepository.findById(testExercise.id);
        final foundExercise2 = await exerciseRepository.findById(exercise2.id);
        
        expect(foundExercise1!.category, equals('updated_1'));
        expect(foundExercise2!.category, equals('updated_2'));
      });
    });

    group('Delete Operations', () {
      setUp(() async {
        await exerciseRepository.create(testExercise);
      });

      test('should delete exercise by id', () async {
        final deleted = await exerciseRepository.deleteById(testExercise.id);
        expect(deleted, isTrue);

        final foundExercise = await exerciseRepository.findById(testExercise.id);
        expect(foundExercise, isNull);
      });

      test('should return false when deleting non-existent exercise', () async {
        final deleted = await exerciseRepository.deleteById('non_existent_id');
        expect(deleted, isFalse);
      });

      test('should delete exercise entity', () async {
        final deleted = await exerciseRepository.delete(testExercise);
        expect(deleted, isTrue);

        final foundExercise = await exerciseRepository.findById(testExercise.id);
        expect(foundExercise, isNull);
      });
    });

    group('Statistics and Analytics', () {
      setUp(() async {
        await exerciseRepository.create(testExercise);
        
        // Create test user and workout data for statistics
        final db = await databaseHelper.database;
        await db.insert('users', {
          'id': 'test_user',
          'email': 'test@example.com',
          'display_name': 'Test User',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        await db.insert('workout_sessions', {
          'id': 'test_session',
          'user_id': 'test_user',
          'start_time': DateTime.now().millisecondsSinceEpoch,
          'session_type': 'strength',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        // Insert some workout sets
        for (int i = 1; i <= 3; i++) {
          await db.insert('workout_sets', {
            'id': 'set_$i',
            'session_id': 'test_session',
            'exercise_id': testExercise.id,
            'weight': 100.0 + i * 5,
            'reps': 10 - i,
            'rpe': 8,
            'set_order': i,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      });

      test('should get exercise usage statistics', () async {
        final usageStats = await exerciseRepository.getExerciseUsageStats();
        
        expect(usageStats, isNotEmpty);
        
        // Find our test exercise in the stats
        final testExerciseStats = usageStats.firstWhere(
          (stat) => stat['exercise_id'] == testExercise.id,
          orElse: () => <String, dynamic>{},
        );
        
        expect(testExerciseStats, isNotEmpty);
        expect(testExerciseStats['usage_count'], equals(3));
        expect(testExerciseStats['avg_weight'], isA<double>());
        expect(testExerciseStats['avg_reps'], isA<double>());
      });
    });

    group('Data Validation', () {
      test('should validate exercise data before operations', () async {
        final invalidExercise = Exercise(
          id: 'test',
          names: {'en': 'Valid Name'},
          category: '',
          equipment: EquipmentType.barbell,
          instructions: {'en': 'Instructions'},
          primaryMuscleGroups: [], // Invalid: empty
          secondaryMuscleGroups: [],
          createdAt: DateTime.now(),
        );

        expect(
          () => exerciseRepository.create(invalidExercise),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('should handle special characters in exercise data', () async {
        final exerciseWithSpecialChars = testExercise.copyWith(
          names: {
            'en': 'Exercise with émojis 🏋️‍♂️ and àccénts',
            'ja': '特殊文字を含む運動 💪'
          },
          instructions: {
            'en': 'Instructions with special chars: <>&"\'',
            'ja': '特殊文字を含む説明: <>＆"＇'
          },
        );

        final createdExercise = await exerciseRepository.create(exerciseWithSpecialChars);
        expect(createdExercise.names, equals(exerciseWithSpecialChars.names));

        final foundExercise = await exerciseRepository.findById(exerciseWithSpecialChars.id);
        expect(foundExercise!.names, equals(exerciseWithSpecialChars.names));
        expect(foundExercise.instructions, equals(exerciseWithSpecialChars.instructions));
      });
    });

    group('Localization', () {
      test('should handle localized names correctly', () async {
        final multilingualExercise = testExercise.copyWith(
          names: {
            'en': 'Push Up',
            'ja': 'プッシュアップ',
            'es': 'Flexión de brazos',
          },
        );

        await exerciseRepository.create(multilingualExercise);
        
        final foundExercise = await exerciseRepository.findById(multilingualExercise.id);
        expect(foundExercise!.names, equals(multilingualExercise.names));
        
        // Test localized name retrieval
        expect(foundExercise.getLocalizedName('en'), equals('Push Up'));
        expect(foundExercise.getLocalizedName('ja'), equals('プッシュアップ'));
        expect(foundExercise.getLocalizedName('es'), equals('Flexión de brazos'));
        expect(foundExercise.getLocalizedName('fr'), equals('Push Up')); // Fallback to English
      });

      test('should search exercises with different locales', () async {
        final multilingualExercise = testExercise.copyWith(
          names: {
            'en': 'Bicep Curl',
            'ja': 'バイセップカール',
          },
        );

        await exerciseRepository.create(multilingualExercise);
        
        // Search in English
        final englishResults = await exerciseRepository.searchByName('Bicep', locale: 'en');
        expect(englishResults.map((e) => e.id), contains(multilingualExercise.id));
        
        // Search in Japanese
        final japaneseResults = await exerciseRepository.searchByName('バイセップ', locale: 'ja');
        expect(japaneseResults.map((e) => e.id), contains(multilingualExercise.id));
      });
    });

    group('Error Handling', () {
      test('should handle database connection errors gracefully', () async {
        // Close database to simulate connection error
        await databaseHelper.close();

        expect(
          () => exerciseRepository.findById(testExercise.id),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('should provide meaningful error messages', () async {
        try {
          await exerciseRepository.create(Exercise(
            id: '',
            names: {},
            category: '',
            equipment: EquipmentType.barbell,
            instructions: {},
            primaryMuscleGroups: [],
            secondaryMuscleGroups: [],
            createdAt: DateTime.now(),
          ));
          fail('Should have thrown RepositoryException');
        } catch (e) {
          expect(e, isA<RepositoryException>());
          final exception = e as RepositoryException;
          expect(exception.message, contains('Invalid exercise data'));
          expect(exception.operation, equals('create exercise'));
        }
      });
    });
  });
}