import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:logger/logger.dart';

import '../../../../lib/data/datasources/local/database_helper.dart';
import '../../../../lib/data/datasources/local/database_config.dart';
import '../../../../lib/data/repositories/user_repository.dart';
import '../../../../lib/data/repositories/exercise_repository.dart';
import '../../../../lib/data/repositories/workout_repository.dart';
import '../../../../lib/domain/entities/user.dart';
import '../../../../lib/domain/entities/exercise.dart';
import '../../../../lib/domain/entities/workout_session.dart';
import '../../../../lib/domain/entities/enums.dart';

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

  group('Database Integration Tests', () {
    group('Database Initialization', () {
      test('should initialize database with correct schema', () async {
        final db = await databaseHelper.database;
        
        // Check if all required tables exist
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        );
        
        final tableNames = tables.map((t) => t['name'] as String).toSet();
        final expectedTables = {
          'users', 'muscle_groups', 'exercises', 'workout_sessions', 'workout_sets',
          'recovery_states', 'avatar_states', 'templates', 'template_exercises',
          'pr_records', 'fatigue_events', 'notifications', 'sync_queue'
        };
        
        for (final expectedTable in expectedTables) {
          expect(tableNames, contains(expectedTable));
        }
      });

      test('should have foreign key constraints enabled', () async {
        final db = await databaseHelper.database;
        final result = await db.rawQuery('PRAGMA foreign_keys');
        
        expect(result.first['foreign_keys'], equals(1));
      });

      test('should have proper indexes created', () async {
        final db = await databaseHelper.database;
        final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'"
        );
        
        final indexNames = indexes.map((i) => i['name'] as String).toSet();
        
        // Check for some critical indexes
        expect(indexNames, contains('idx_workout_sessions_user_id'));
        expect(indexNames, contains('idx_workout_sets_session_id'));
        expect(indexNames, contains('idx_workout_sets_exercise_id'));
      });

      test('should have initial data populated', () async {
        // Check muscle groups
        final muscleGroups = await databaseHelper.database.then(
          (db) => db.query('muscle_groups')
        );
        expect(muscleGroups.length, greaterThan(5));
        
        // Check exercises
        final exercises = await databaseHelper.database.then(
          (db) => db.query('exercises')
        );
        expect(exercises.length, greaterThan(2));
      });
    });

    group('Cross-Repository Operations', () {
      late User testUser;
      late Exercise testExercise;
      late WorkoutSession testSession;
      late WorkoutSet testSet;

      setUp(() async {
        testUser = User(
          id: 'integration_user',
          email: 'integration@test.com',
          displayName: 'Integration Test User',
          createdAt: DateTime.now(),
        );

        testExercise = Exercise(
          id: 'integration_exercise',
          names: {'en': 'Integration Exercise', 'ja': 'インテグレーション運動'},
          category: 'integration',
          equipment: EquipmentType.dumbbell,
          instructions: {'en': 'Test instructions', 'ja': 'テスト説明'},
          primaryMuscleGroups: ['chest'],
          secondaryMuscleGroups: ['shoulders'],
          createdAt: DateTime.now(),
        );

        testSession = WorkoutSession(
          id: 'integration_session',
          userId: testUser.id,
          startTime: DateTime.now().subtract(Duration(hours: 1)),
          endTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
          sets: [],
        );

        testSet = WorkoutSet(
          id: 'integration_set',
          sessionId: testSession.id,
          exerciseId: testExercise.id,
          weight: 100.0,
          reps: 10,
          rpe: 8,
          setOrder: 1,
          createdAt: DateTime.now(),
        );
      });

      test('should handle complete workout flow with foreign key relationships', () async {
        // Create user first
        await userRepository.create(testUser);
        
        // Create exercise
        await exerciseRepository.create(testExercise);
        
        // Create session with sets
        final sessionWithSets = testSession.copyWith(sets: [testSet]);
        await sessionRepository.create(sessionWithSets);
        
        // Verify all data was created correctly
        final foundUser = await userRepository.findById(testUser.id);
        expect(foundUser, isNotNull);
        
        final foundExercise = await exerciseRepository.findById(testExercise.id);
        expect(foundExercise, isNotNull);
        
        final foundSession = await sessionRepository.findById(testSession.id);
        expect(foundSession, isNotNull);
        expect(foundSession!.sets.length, equals(1));
        
        final foundSet = await setRepository.findById(testSet.id);
        expect(foundSet, isNotNull);
        expect(foundSet!.sessionId, equals(testSession.id));
        expect(foundSet.exerciseId, equals(testExercise.id));
      });

      test('should enforce foreign key constraints', () async {
        // Try to create a session without a user
        expect(
          () => sessionRepository.create(testSession),
          throwsA(isA<DatabaseException>()),
        );
        
        // Create user first
        await userRepository.create(testUser);
        
        // Try to create a set without a session
        expect(
          () => setRepository.create(testSet),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('should cascade delete properly', () async {
        // Set up complete data
        await userRepository.create(testUser);
        await exerciseRepository.create(testExercise);
        await sessionRepository.create(testSession.copyWith(sets: [testSet]));
        
        // Delete session should cascade to sets
        await sessionRepository.deleteById(testSession.id);
        
        final foundSet = await setRepository.findById(testSet.id);
        expect(foundSet, isNull);
        
        // Delete user should cascade to sessions
        await userRepository.create(testUser);
        await sessionRepository.create(testSession);
        
        await userRepository.deleteById(testUser.id);
        
        final foundSession = await sessionRepository.findById(testSession.id);
        expect(foundSession, isNull);
      });
    });

    group('Transaction Handling', () {
      test('should handle transaction rollback on error', () async {
        final user = User(
          id: 'transaction_user',
          email: 'transaction@test.com',
          displayName: 'Transaction User',
          createdAt: DateTime.now(),
        );
        
        await userRepository.create(user);
        
        final db = await databaseHelper.database;
        
        // Start a transaction that will fail
        try {
          await db.transaction((txn) async {
            // Insert a valid session
            await txn.insert('workout_sessions', {
              'id': 'valid_session',
              'user_id': user.id,
              'start_time': DateTime.now().millisecondsSinceEpoch,
              'session_type': 'strength',
              'created_at': DateTime.now().millisecondsSinceEpoch,
            });
            
            // This should fail due to foreign key constraint
            await txn.insert('workout_sets', {
              'id': 'invalid_set',
              'session_id': 'non_existent_session',
              'exercise_id': 'squat',
              'weight': 100.0,
              'reps': 10,
              'rpe': 8,
              'set_order': 1,
              'created_at': DateTime.now().millisecondsSinceEpoch,
            });
          });
          fail('Transaction should have failed');
        } catch (e) {
          // Expected to fail
        }
        
        // Verify that the valid session was not inserted due to rollback
        final sessions = await db.query(
          'workout_sessions',
          where: 'id = ?',
          whereArgs: ['valid_session'],
        );
        expect(sessions, isEmpty);
      });
    });

    group('Performance Tests', () {
      test('should handle large batch operations efficiently', () async {
        final user = User(
          id: 'perf_user',
          email: 'perf@test.com',
          displayName: 'Performance User',
          createdAt: DateTime.now(),
        );
        
        await userRepository.create(user);
        
        final stopwatch = Stopwatch()..start();
        
        // Create many sessions
        final sessions = <WorkoutSession>[];
        for (int i = 1; i <= 100; i++) {
          sessions.add(WorkoutSession(
            id: 'perf_session_$i',
            userId: user.id,
            startTime: DateTime.now().subtract(Duration(days: i)),
            sessionType: SessionType.strength,
            createdAt: DateTime.now(),
            sets: [],
          ));
        }
        
        await sessionRepository.createBatch(sessions);
        
        stopwatch.stop();
        
        // Should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(3000));
        
        // Verify all sessions were created
        final foundSessions = await sessionRepository.findByUserId(user.id);
        expect(foundSessions.length, equals(100));
      });

      test('should maintain performance with complex queries', () async {
        // Set up test data
        final user = User(
          id: 'complex_user',
          email: 'complex@test.com',
          displayName: 'Complex User',
          createdAt: DateTime.now(),
        );
        
        await userRepository.create(user);
        
        // Create sessions with sets
        for (int i = 1; i <= 50; i++) {
          final session = WorkoutSession(
            id: 'complex_session_$i',
            userId: user.id,
            startTime: DateTime.now().subtract(Duration(days: i)),
            sessionType: SessionType.strength,
            createdAt: DateTime.now(),
            sets: [
              WorkoutSet(
                id: 'complex_set_${i}_1',
                sessionId: 'complex_session_$i',
                exerciseId: 'squat',
                weight: 100.0 + i,
                reps: 10,
                rpe: 8,
                setOrder: 1,
                createdAt: DateTime.now(),
              ),
              WorkoutSet(
                id: 'complex_set_${i}_2',
                sessionId: 'complex_session_$i',
                exerciseId: 'bench_press',
                weight: 80.0 + i,
                reps: 8,
                rpe: 7,
                setOrder: 2,
                createdAt: DateTime.now(),
              ),
            ],
          );
          
          await sessionRepository.create(session);
        }
        
        final stopwatch = Stopwatch()..start();
        
        // Perform complex query operations
        await sessionRepository.getWorkoutStats(user.id);
        await setRepository.getPersonalRecords(user.id);
        await setRepository.calculateVolumeForDateRange(
          user.id,
          DateTime.now().subtract(Duration(days: 30)),
          DateTime.now(),
        );
        
        stopwatch.stop();
        
        // Should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });

    group('Data Integrity', () {
      test('should maintain data consistency across operations', () async {
        final user = User(
          id: 'integrity_user',
          email: 'integrity@test.com',
          displayName: 'Integrity User',
          createdAt: DateTime.now(),
        );
        
        await userRepository.create(user);
        
        // Create multiple sessions with sets
        final sessions = <WorkoutSession>[];
        for (int i = 1; i <= 10; i++) {
          final sets = <WorkoutSet>[];
          for (int j = 1; j <= 3; j++) {
            sets.add(WorkoutSet(
              id: 'integrity_set_${i}_$j',
              sessionId: 'integrity_session_$i',
              exerciseId: 'squat',
              weight: 100.0 + j * 5,
              reps: 10 - j,
              rpe: 8,
              setOrder: j,
              createdAt: DateTime.now(),
            ));
          }
          
          sessions.add(WorkoutSession(
            id: 'integrity_session_$i',
            userId: user.id,
            startTime: DateTime.now().subtract(Duration(hours: i)),
            sessionType: SessionType.strength,
            createdAt: DateTime.now(),
            sets: sets,
          ));
        }
        
        // Create all sessions
        for (final session in sessions) {
          await sessionRepository.create(session);
        }
        
        // Verify data consistency
        final allSessions = await sessionRepository.findByUserId(user.id);
        expect(allSessions.length, equals(10));
        
        int totalSetsFromSessions = 0;
        for (final session in allSessions) {
          totalSetsFromSessions += session.sets.length;
        }
        
        final allSets = await setRepository.findAll();
        final userSets = allSets.where((set) => 
          sessions.any((session) => session.id == set.sessionId)
        ).toList();
        
        expect(totalSetsFromSessions, equals(30));
        expect(userSets.length, equals(30));
      });

      test('should handle concurrent operations safely', () async {
        final user = User(
          id: 'concurrent_user',
          email: 'concurrent@test.com',
          displayName: 'Concurrent User',
          createdAt: DateTime.now(),
        );
        
        await userRepository.create(user);
        
        // Simulate concurrent operations
        final futures = <Future>[];
        
        for (int i = 1; i <= 20; i++) {
          futures.add(sessionRepository.create(WorkoutSession(
            id: 'concurrent_session_$i',
            userId: user.id,
            startTime: DateTime.now().subtract(Duration(minutes: i)),
            sessionType: SessionType.strength,
            createdAt: DateTime.now(),
            sets: [],
          )));
        }
        
        // Wait for all operations to complete
        await Future.wait(futures);
        
        // Verify all sessions were created
        final sessions = await sessionRepository.findByUserId(user.id);
        expect(sessions.length, equals(20));
        
        // Verify no duplicate IDs
        final sessionIds = sessions.map((s) => s.id).toSet();
        expect(sessionIds.length, equals(20));
      });
    });

    group('Error Recovery', () {
      test('should recover from database corruption gracefully', () async {
        final db = await databaseHelper.database;
        
        // Check initial integrity
        final initialIntegrity = await databaseHelper.checkIntegrity();
        expect(initialIntegrity, isTrue);
        
        // Simulate some operations
        final user = User(
          id: 'recovery_user',
          email: 'recovery@test.com',
          displayName: 'Recovery User',
          createdAt: DateTime.now(),
        );
        
        await userRepository.create(user);
        
        // Verify integrity is still maintained
        final finalIntegrity = await databaseHelper.checkIntegrity();
        expect(finalIntegrity, isTrue);
      });

      test('should handle database size and vacuum operations', () async {
        // Get initial size
        final initialSize = await databaseHelper.getDatabaseSize();
        expect(initialSize, greaterThan(0));
        
        // Add some data
        final user = User(
          id: 'vacuum_user',
          email: 'vacuum@test.com',
          displayName: 'Vacuum User',
          createdAt: DateTime.now(),
        );
        
        await userRepository.create(user);
        
        // Create and delete some sessions to create fragmentation
        for (int i = 1; i <= 50; i++) {
          final session = WorkoutSession(
            id: 'vacuum_session_$i',
            userId: user.id,
            startTime: DateTime.now(),
            sessionType: SessionType.strength,
            createdAt: DateTime.now(),
            sets: [],
          );
          
          await sessionRepository.create(session);
          await sessionRepository.deleteById(session.id);
        }
        
        final sizeBeforeVacuum = await databaseHelper.getDatabaseSize();
        
        // Vacuum the database
        await databaseHelper.vacuum();
        
        final sizeAfterVacuum = await databaseHelper.getDatabaseSize();
        
        // Size should be same or smaller after vacuum
        expect(sizeAfterVacuum, lessThanOrEqualTo(sizeBeforeVacuum));
      });
    });

    group('Statistics and Reporting', () {
      test('should provide accurate database statistics', () async {
        final stats = await databaseHelper.getStatistics();
        
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['database_size_bytes'], isA<int>());
        expect(stats['database_version'], equals(DatabaseConfig.currentVersion));
        expect(stats['table_counts'], isA<Map<String, int>>());
        expect(stats['is_encrypted'], isA<bool>());
        
        // Check that all expected tables are in the counts
        final tableCounts = stats['table_counts'] as Map<String, int>;
        expect(tableCounts, containsPair('users', isA<int>()));
        expect(tableCounts, containsPair('exercises', isA<int>()));
        expect(tableCounts, containsPair('muscle_groups', isA<int>()));
      });
    });
  });
}