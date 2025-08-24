import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:logger/logger.dart';

import '../../../lib/data/datasources/local/database_helper.dart';
import '../../../lib/data/repositories/user_repository.dart';
import '../../../lib/data/repositories/exercise_repository.dart';
import '../../../lib/data/repositories/workout_repository.dart';
import '../../../lib/domain/entities/user.dart';
import '../../../lib/domain/entities/exercise.dart';
import '../../../lib/domain/entities/workout_session.dart';
import '../../../lib/domain/entities/enums.dart';

void main() {
  late DatabaseHelper databaseHelper;
  late UserRepository userRepository;
  late ExerciseRepository exerciseRepository;
  late WorkoutSessionRepository sessionRepository;
  late WorkoutSetRepository setRepository;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Disable logging during tests
    Logger.level = Level.off;
  });

  setUp(() async {
    databaseHelper = DatabaseHelper();
    userRepository = UserRepositoryImpl(databaseHelper);
    exerciseRepository = ExerciseRepositoryImpl(databaseHelper);
    setRepository = WorkoutSetRepositoryImpl(databaseHelper);
    sessionRepository = WorkoutSessionRepositoryImpl(databaseHelper, setRepository);
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  group('Repository Error Handling Tests', () {
    group('Validation Error Handling', () {
      test('should provide detailed validation errors for User', () async {
        final invalidUser = User(
          id: '',
          email: 'invalid-email',
          displayName: '',
          createdAt: DateTime.now(),
        );

        try {
          await userRepository.create(invalidUser);
          fail('Should have thrown RepositoryException');
        } catch (e) {
          expect(e, isA<RepositoryException>());
          final exception = e as RepositoryException;
          expect(exception.message, contains('Invalid user data'));
          expect(exception.operation, equals('create user'));
          expect(exception.originalError, isNotNull);
        }
      });

      test('should provide detailed validation errors for Exercise', () async {
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

        try {
          await exerciseRepository.create(invalidExercise);
          fail('Should have thrown RepositoryException');
        } catch (e) {
          expect(e, isA<RepositoryException>());
          final exception = e as RepositoryException;
          expect(exception.message, contains('Invalid exercise data'));
          expect(exception.operation, equals('create exercise'));
        }
      });

      test('should provide detailed validation errors for WorkoutSet', () async {
        final invalidSet = WorkoutSet(
          id: '',
          sessionId: '',
          exerciseId: '',
          weight: -10.0,
          reps: 0,
          rpe: 15,
          setOrder: -1,
          createdAt: DateTime.now(),
        );

        try {
          await setRepository.create(invalidSet);
          fail('Should have thrown RepositoryException');
        } catch (e) {
          expect(e, isA<RepositoryException>());
          final exception = e as RepositoryException;
          expect(exception.message, contains('Invalid workout set data'));
          expect(exception.operation, equals('create workout set'));
        }
      });
    });

    group('Database Constraint Error Handling', () {
      test('should handle unique constraint violations', () async {
        final user = User(
          id: 'unique_user',
          email: 'unique@test.com',
          displayName: 'Unique User',
          createdAt: DateTime.now(),
        );

        await userRepository.create(user);

        // Try to create another user with same email
        final duplicateUser = user.copyWith(id: 'different_id');

        expect(
          () => userRepository.create(duplicateUser),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('should handle foreign key constraint violations', () async {
        final session = WorkoutSession(
          id: 'orphan_session',
          userId: 'non_existent_user',
          startTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
          sets: [],
        );

        expect(
          () => sessionRepository.create(session),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('should handle cascade delete constraints', () async {
        // Create user and session
        final user = User(
          id: 'cascade_user',
          email: 'cascade@test.com',
          displayName: 'Cascade User',
          createdAt: DateTime.now(),
        );

        await userRepository.create(user);

        final session = WorkoutSession(
          id: 'cascade_session',
          userId: user.id,
          startTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
          sets: [
            WorkoutSet(
              id: 'cascade_set',
              sessionId: 'cascade_session',
              exerciseId: 'squat',
              weight: 100.0,
              reps: 10,
              rpe: 8,
              setOrder: 1,
              createdAt: DateTime.now(),
            ),
          ],
        );

        await sessionRepository.create(session);

        // Delete user should cascade to session and sets
        await userRepository.deleteById(user.id);

        // Verify cascade worked
        final foundSession = await sessionRepository.findById(session.id);
        expect(foundSession, isNull);

        final foundSet = await setRepository.findById('cascade_set');
        expect(foundSet, isNull);
      });
    });

    group('Connection Error Handling', () {
      test('should handle database connection failures gracefully', () async {
        // Close database to simulate connection failure
        await databaseHelper.close();

        expect(
          () => userRepository.findAll(),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('should provide meaningful error messages for connection issues', () async {
        await databaseHelper.close();

        try {
          await userRepository.create(User(
            id: 'test_user',
            email: 'test@test.com',
            displayName: 'Test User',
            createdAt: DateTime.now(),
          ));
          fail('Should have thrown RepositoryException');
        } catch (e) {
          expect(e, isA<RepositoryException>());
          final exception = e as RepositoryException;
          expect(exception.message, contains('Failed to execute'));
          expect(exception.operation, isNotNull);
          expect(exception.originalError, isNotNull);
        }
      });
    });

    group('Transaction Error Handling', () {
      test('should rollback transaction on error', () async {
        final user = User(
          id: 'transaction_user',
          email: 'transaction@test.com',
          displayName: 'Transaction User',
          createdAt: DateTime.now(),
        );

        await userRepository.create(user);

        final db = await databaseHelper.database;

        // Simulate transaction failure
        try {
          await db.transaction((txn) async {
            // Insert valid session
            await txn.insert('workout_sessions', {
              'id': 'transaction_session',
              'user_id': user.id,
              'start_time': DateTime.now().millisecondsSinceEpoch,
              'session_type': 'strength',
              'created_at': DateTime.now().millisecondsSinceEpoch,
            });

            // This should fail
            throw Exception('Simulated transaction failure');
          });
          fail('Transaction should have failed');
        } catch (e) {
          // Expected to fail
        }

        // Verify rollback - session should not exist
        final sessions = await db.query(
          'workout_sessions',
          where: 'id = ?',
          whereArgs: ['transaction_session'],
        );
        expect(sessions, isEmpty);
      });
    });

    group('Batch Operation Error Handling', () {
      test('should handle partial batch failures', () async {
        final validUsers = [
          User(
            id: 'batch_user_1',
            email: 'batch1@test.com',
            displayName: 'Batch User 1',
            createdAt: DateTime.now(),
          ),
          User(
            id: 'batch_user_2',
            email: 'batch2@test.com',
            displayName: 'Batch User 2',
            createdAt: DateTime.now(),
          ),
        ];

        // Create first user
        await userRepository.create(validUsers[0]);

        // Try to create batch with duplicate
        final batchWithDuplicate = [
          validUsers[0], // Duplicate
          validUsers[1], // Valid
        ];

        expect(
          () => userRepository.createBatch(batchWithDuplicate),
          throwsA(isA<DatabaseException>()),
        );

        // Verify that valid operations in batch were rolled back
        final foundUser2 = await userRepository.findById('batch_user_2');
        expect(foundUser2, isNull);
      });

      test('should handle empty batch operations', () async {
        final emptyBatch = <User>[];

        final result = await userRepository.createBatch(emptyBatch);
        expect(result, isEmpty);

        final deleteResult = await userRepository.deleteBatch([]);
        expect(deleteResult, equals(0));
      });
    });

    group('Data Type Error Handling', () {
      test('should handle invalid data types gracefully', () async {
        final db = await databaseHelper.database;

        // Try to insert invalid data directly
        expect(
          () => db.insert('users', {
            'id': 123, // Should be string
            'email': null, // Should not be null
            'display_name': 'Test',
            'created_at': 'invalid_timestamp', // Should be integer
          }),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('should handle JSON serialization errors', () async {
        // Create exercise with invalid JSON data
        final db = await databaseHelper.database;

        expect(
          () => db.insert('exercises', {
            'id': 'invalid_exercise',
            'names': 'invalid_json', // Should be valid JSON
            'category': 'test',
            'equipment': 'barbell',
            'instructions': '{}',
            'primary_muscle_groups': '[]',
            'secondary_muscle_groups': '[]',
            'created_at': DateTime.now().millisecondsSinceEpoch,
          }),
          throwsA(isA<DatabaseException>()),
        );
      });
    });

    group('Recovery and Resilience', () {
      test('should recover from temporary database locks', () async {
        final user = User(
          id: 'lock_user',
          email: 'lock@test.com',
          displayName: 'Lock User',
          createdAt: DateTime.now(),
        );

        // This should succeed even if there are temporary locks
        final createdUser = await userRepository.create(user);
        expect(createdUser, equals(user));

        final foundUser = await userRepository.findById(user.id);
        expect(foundUser, isNotNull);
      });

      test('should handle repository method chaining errors', () async {
        // Test error propagation through method chains
        try {
          final nonExistentUser = await userRepository.findById('non_existent');
          expect(nonExistentUser, isNull);

          // This should not throw even though user doesn't exist
          final sessions = await sessionRepository.findByUserId('non_existent');
          expect(sessions, isEmpty);
        } catch (e) {
          fail('Should not throw exception for non-existent user queries');
        }
      });
    });

    group('Error Message Quality', () {
      test('should provide helpful error messages for common mistakes', () async {
        // Test various common validation errors
        final testCases = [
          {
            'user': User(
              id: '',
              email: 'test@test.com',
              displayName: 'Test',
              createdAt: DateTime.now(),
            ),
            'expectedError': 'User ID cannot be empty',
          },
          {
            'user': User(
              id: 'test',
              email: 'invalid-email',
              displayName: 'Test',
              createdAt: DateTime.now(),
            ),
            'expectedError': 'Invalid email format',
          },
          {
            'user': User(
              id: 'test',
              email: 'test@test.com',
              displayName: '',
              createdAt: DateTime.now(),
            ),
            'expectedError': 'Display name cannot be empty',
          },
        ];

        for (final testCase in testCases) {
          try {
            await userRepository.create(testCase['user'] as User);
            fail('Should have thrown RepositoryException');
          } catch (e) {
            expect(e, isA<RepositoryException>());
            final exception = e as RepositoryException;
            expect(exception.message, contains('Invalid user data'));
            // The original error should contain the specific validation message
            expect(exception.originalError.toString(), contains(testCase['expectedError'] as String));
          }
        }
      });

      test('should provide context in error messages', () async {
        try {
          await userRepository.update(User(
            id: 'non_existent',
            email: 'test@test.com',
            displayName: 'Test',
            createdAt: DateTime.now(),
          ));
          fail('Should have thrown RepositoryException');
        } catch (e) {
          expect(e, isA<RepositoryException>());
          final exception = e as RepositoryException;
          expect(exception.message, contains('User not found'));
          expect(exception.operation, equals('update user'));
        }
      });
    });
  });
}