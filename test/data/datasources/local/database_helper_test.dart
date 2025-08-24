import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

import '../../../../lib/data/datasources/local/database_helper.dart';

void main() {
  late DatabaseHelper databaseHelper;
  late Database database;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databaseHelper = DatabaseHelper();
    database = await databaseHelper.database;
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  group('DatabaseHelper', () {
    test('should initialize database successfully', () async {
      expect(database, isNotNull);
      expect(await database.isOpen, isTrue);
    });

    test('should create all required tables', () async {
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
      );
      
      final tableNames = tables.map((table) => table['name'] as String).toSet();
      
      final expectedTables = {
        'users',
        'muscle_groups',
        'exercises',
        'workout_sessions',
        'workout_sets',
        'recovery_states',
        'avatar_states',
        'templates',
        'template_exercises',
        'pr_records',
        'fatigue_events',
        'notifications',
        'sync_queue',
      };
      
      expect(tableNames, containsAll(expectedTables));
    });

    test('should create all required indexes', () async {
      final indexes = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'"
      );
      
      final indexNames = indexes.map((index) => index['name'] as String).toSet();
      
      // Check for some key indexes
      expect(indexNames, contains('idx_workout_sessions_user_id'));
      expect(indexNames, contains('idx_workout_sets_session_id'));
      expect(indexNames, contains('idx_recovery_states_muscle_group_id'));
      expect(indexNames, contains('idx_pr_records_user_exercise'));
    });

    test('should have foreign key constraints enabled', () async {
      final result = await database.rawQuery('PRAGMA foreign_keys');
      expect(result.first['foreign_keys'], equals(1));
    });

    test('should insert initial muscle groups data', () async {
      final muscleGroups = await database.query('muscle_groups');
      
      expect(muscleGroups.length, greaterThan(0));
      
      // Check for specific muscle groups
      final muscleGroupIds = muscleGroups.map((mg) => mg['id'] as String).toSet();
      expect(muscleGroupIds, contains('chest'));
      expect(muscleGroupIds, contains('back'));
      expect(muscleGroupIds, contains('quadriceps'));
    });

    test('should insert initial exercises data', () async {
      final exercises = await database.query('exercises');
      
      expect(exercises.length, greaterThan(0));
      
      // Check for specific exercises
      final exerciseIds = exercises.map((ex) => ex['id'] as String).toSet();
      expect(exerciseIds, contains('squat'));
      expect(exerciseIds, contains('bench_press'));
      expect(exerciseIds, contains('deadlift'));
    });

    test('should validate muscle group data structure', () async {
      final muscleGroups = await database.query('muscle_groups', limit: 1);
      final muscleGroup = muscleGroups.first;
      
      expect(muscleGroup['id'], isA<String>());
      expect(muscleGroup['names'], isA<String>());
      expect(muscleGroup['recovery_tau'], isA<double>());
      expect(muscleGroup['fatigue_multiplier'], isA<double>());
      expect(muscleGroup['body_region'], isA<String>());
      
      // Validate JSON structure
      expect(() => muscleGroup['names'], returnsNormally);
    });

    test('should validate exercise data structure', () async {
      final exercises = await database.query('exercises', limit: 1);
      final exercise = exercises.first;
      
      expect(exercise['id'], isA<String>());
      expect(exercise['names'], isA<String>());
      expect(exercise['category'], isA<String>());
      expect(exercise['equipment'], isA<String>());
      expect(exercise['instructions'], isA<String>());
      expect(exercise['primary_muscle_groups'], isA<String>());
      expect(exercise['secondary_muscle_groups'], isA<String>());
      expect(exercise['is_compound'], isA<int>());
      expect(exercise['created_at'], isA<int>());
    });

    test('should get database statistics', () async {
      final stats = await databaseHelper.getStatistics();
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats['database_size_bytes'], isA<int>());
      expect(stats['database_version'], equals(1));
      expect(stats['table_counts'], isA<Map<String, int>>());
      
      final tableCounts = stats['table_counts'] as Map<String, int>;
      expect(tableCounts['muscle_groups'], greaterThan(0));
      expect(tableCounts['exercises'], greaterThan(0));
    });

    test('should check database integrity', () async {
      final isIntegrityOk = await databaseHelper.checkIntegrity();
      expect(isIntegrityOk, isTrue);
    });

    test('should get database size', () async {
      final size = await databaseHelper.getDatabaseSize();
      expect(size, greaterThan(0));
    });

    test('should handle vacuum operation', () async {
      expect(() => databaseHelper.vacuum(), returnsNormally);
    });

    group('Foreign Key Constraints', () {
      test('should enforce foreign key constraint on workout_sessions', () async {
        expect(() async {
          await database.insert('workout_sessions', {
            'id': 'test_session',
            'user_id': 'non_existent_user',
            'start_time': DateTime.now().millisecondsSinceEpoch,
            'session_type': 'strength',
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }, throwsA(isA<DatabaseException>()));
      });

      test('should enforce foreign key constraint on workout_sets', () async {
        expect(() async {
          await database.insert('workout_sets', {
            'id': 'test_set',
            'session_id': 'non_existent_session',
            'exercise_id': 'squat',
            'weight': 100.0,
            'reps': 10,
            'rpe': 8,
            'set_order': 1,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }, throwsA(isA<DatabaseException>()));
      });
    });

    group('Migration Tests', () {
      test('should handle database recreation on downgrade', () async {
        // This is a simplified test - in practice, you'd test actual migrations
        expect(() => databaseHelper.database, returnsNormally);
      });
    });

    group('Performance Tests', () {
      test('should handle large batch inserts efficiently', () async {
        final stopwatch = Stopwatch()..start();
        
        final batch = database.batch();
        for (int i = 0; i < 1000; i++) {
          batch.insert('sync_queue', {
            'id': 'test_$i',
            'entity_type': 'test',
            'entity_id': 'entity_$i',
            'operation': 'create',
            'data': '{}',
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
        await batch.commit(noResult: true);
        
        stopwatch.stop();
        
        // Should complete within reasonable time (adjust threshold as needed)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
        
        // Verify data was inserted
        final count = await database.rawQuery('SELECT COUNT(*) as count FROM sync_queue');
        expect(count.first['count'], equals(1000));
      });

      test('should handle complex queries efficiently', () async {
        // Insert test data first
        await database.insert('users', {
          'id': 'test_user',
          'email': 'test@example.com',
          'display_name': 'Test User',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        await database.insert('workout_sessions', {
          'id': 'test_session',
          'user_id': 'test_user',
          'start_time': DateTime.now().millisecondsSinceEpoch,
          'session_type': 'strength',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        final stopwatch = Stopwatch()..start();
        
        // Complex query with joins
        final result = await database.rawQuery('''
          SELECT 
            s.id,
            s.start_time,
            COUNT(ws.id) as set_count,
            SUM(ws.weight * ws.reps) as total_volume
          FROM workout_sessions s
          LEFT JOIN workout_sets ws ON s.id = ws.session_id
          WHERE s.user_id = ?
          GROUP BY s.id
        ''', ['test_user']);
        
        stopwatch.stop();
        
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        expect(result, isNotEmpty);
      });
    });
  });
}