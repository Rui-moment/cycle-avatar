import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:logger/logger.dart';

import '../../../../lib/data/datasources/local/database_helper.dart';
import '../../../../lib/data/datasources/local/database_migration_manager.dart';
import '../../../../lib/data/datasources/local/database_config.dart';

void main() {
  late DatabaseHelper databaseHelper;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Disable logging during tests
    Logger.level = Level.off;
  });

  setUp(() async {
    databaseHelper = DatabaseHelper();
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  group('Database Migration Tests', () {
    group('Migration Logging', () {
      test('should create migration log table', () async {
        final db = await databaseHelper.database;
        
        // Check if migration_log table exists
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='migration_log'"
        );
        
        expect(tables, isNotEmpty);
        
        // Check table structure
        final columns = await db.rawQuery('PRAGMA table_info(migration_log)');
        final columnNames = columns.map((c) => c['name'] as String).toSet();
        
        expect(columnNames, contains('id'));
        expect(columnNames, contains('version'));
        expect(columnNames, contains('migration_type'));
        expect(columnNames, contains('executed_at'));
        expect(columnNames, contains('success'));
      });

      test('should log successful migration', () async {
        final db = await databaseHelper.database;
        
        await DatabaseMigrationManager.executeMigration(
          db: db,
          fromVersion: 1,
          toVersion: 2,
          migrationFunction: (db) async {
            // Simple test migration
            await db.execute('CREATE TABLE test_migration (id INTEGER PRIMARY KEY)');
          },
          description: 'Test migration',
        );
        
        // Check migration log
        final logs = await db.query(
          'migration_log',
          where: 'version = ? AND migration_type = ?',
          whereArgs: [2, 'upgrade'],
        );
        
        expect(logs, isNotEmpty);
        expect(logs.first['success'], equals(1));
        expect(logs.first['description'], equals('Test migration'));
      });
    });
  });
}  
    test('should log failed migration and rollback', () async {
        final db = await databaseHelper.database;
        
        try {
          await DatabaseMigrationManager.executeMigration(
            db: db,
            fromVersion: 1,
            toVersion: 3,
            migrationFunction: (db) async {
              // This should fail
              await db.execute('CREATE TABLE invalid_table (invalid_column INVALID_TYPE)');
              throw Exception('Simulated migration failure');
            },
            description: 'Failing test migration',
          );
          fail('Migration should have failed');
        } catch (e) {
          // Expected to fail
        }
        
        // Check migration log for failure
        final logs = await db.query(
          'migration_log',
          where: 'version = ? AND migration_type = ?',
          whereArgs: [3, 'upgrade'],
        );
        
        expect(logs, isNotEmpty);
        expect(logs.first['success'], equals(0));
        expect(logs.first['error_message'], contains('Simulated migration failure'));
      });

      test('should track migration history', () async {
        final db = await databaseHelper.database;
        
        // Execute multiple migrations
        for (int version = 2; version <= 4; version++) {
          await DatabaseMigrationManager.executeMigration(
            db: db,
            fromVersion: version - 1,
            toVersion: version,
            migrationFunction: (db) async {
              await db.execute('CREATE TABLE test_table_v$version (id INTEGER)');
            },
            description: 'Migration to version $version',
          );
        }
        
        final history = await DatabaseMigrationManager.getMigrationHistory(db);
        expect(history.length, greaterThanOrEqualTo(3));
        
        // Check that migrations are ordered by execution time (newest first)
        for (int i = 0; i < history.length - 1; i++) {
          final current = history[i]['executed_at'] as int;
          final next = history[i + 1]['executed_at'] as int;
          expect(current, greaterThanOrEqualTo(next));
        }
      });
    });

    group('Migration Validation', () {
      test('should validate migration success', () async {
        final db = await databaseHelper.database;
        
        // Execute a migration
        await DatabaseMigrationManager.executeMigration(
          db: db,
          fromVersion: 1,
          toVersion: 2,
          migrationFunction: (db) async {
            await db.execute('CREATE TABLE validation_test (id INTEGER PRIMARY KEY)');
          },
        );
        
        // Check if migration was successful
        final wasSuccessful = await DatabaseMigrationManager.wasMigrationSuccessful(db, 2);
        expect(wasSuccessful, isTrue);
        
        // Check non-existent migration
        final wasNotSuccessful = await DatabaseMigrationManager.wasMigrationSuccessful(db, 99);
        expect(wasNotSuccessful, isFalse);
      });

      test('should get last successful migration version', () async {
        final db = await databaseHelper.database;
        
        // Execute migrations
        await DatabaseMigrationManager.executeMigration(
          db: db,
          fromVersion: 1,
          toVersion: 2,
          migrationFunction: (db) async {
            await db.execute('CREATE TABLE last_version_test_v2 (id INTEGER)');
          },
        );
        
        await DatabaseMigrationManager.executeMigration(
          db: db,
          fromVersion: 2,
          toVersion: 3,
          migrationFunction: (db) async {
            await db.execute('CREATE TABLE last_version_test_v3 (id INTEGER)');
          },
        );
        
        final lastVersion = await DatabaseMigrationManager.getLastSuccessfulMigrationVersion(db);
        expect(lastVersion, equals(3));
      });

      test('should validate expected tables after migration', () async {
        final db = await databaseHelper.database;
        
        // This should pass validation
        await DatabaseMigrationManager.executeMigration(
          db: db,
          fromVersion: 1,
          toVersion: 1, // Stay at version 1
          migrationFunction: (db) async {
            // No-op migration
          },
        );
        
        // Verify all base tables exist
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        );
        
        final tableNames = tables.map((t) => t['name'] as String).toSet();
        expect(tableNames, contains('users'));
        expect(tableNames, contains('exercises'));
        expect(tableNames, contains('workout_sessions'));
      });
    });

    group('Migration Rollback', () {
      test('should rollback on migration failure', () async {
        final db = await databaseHelper.database;
        
        // Get initial table count
        final initialTables = await db.rawQuery(
          "SELECT COUNT(*) as count FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        );
        final initialCount = initialTables.first['count'] as int;
        
        try {
          await DatabaseMigrationManager.executeMigration(
            db: db,
            fromVersion: 1,
            toVersion: 2,
            migrationFunction: (db) async {
              // Create a table first
              await db.execute('CREATE TABLE rollback_test (id INTEGER PRIMARY KEY)');
              
              // Then fail
              throw Exception('Rollback test failure');
            },
          );
          fail('Migration should have failed');
        } catch (e) {
          // Expected to fail
        }
        
        // Check that table was not created due to rollback
        final finalTables = await db.rawQuery(
          "SELECT COUNT(*) as count FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        );
        final finalCount = finalTables.first['count'] as int;
        
        expect(finalCount, equals(initialCount));
        
        // Verify specific table doesn't exist
        final rollbackTable = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='rollback_test'"
        );
        expect(rollbackTable, isEmpty);
      });
    });

    group('Migration Performance', () {
      test('should complete migrations within timeout', () async {
        final db = await databaseHelper.database;
        final stopwatch = Stopwatch()..start();
        
        await DatabaseMigrationManager.executeMigration(
          db: db,
          fromVersion: 1,
          toVersion: 2,
          migrationFunction: (db) async {
            // Simulate some work
            for (int i = 0; i < 100; i++) {
              await db.execute('CREATE TEMP TABLE temp_$i (id INTEGER)');
              await db.execute('DROP TABLE temp_$i');
            }
          },
        );
        
        stopwatch.stop();
        
        // Should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
        
        // Check that execution time was logged
        final logs = await db.query(
          'migration_log',
          where: 'version = ?',
          whereArgs: [2],
          orderBy: 'executed_at DESC',
          limit: 1,
        );
        
        expect(logs, isNotEmpty);
        expect(logs.first['execution_time_ms'], isA<int>());
        expect(logs.first['execution_time_ms'] as int, greaterThan(0));
      });
    });

    group('Migration Configuration', () {
      test('should validate database configuration', () async {
        final isValid = DatabaseConfig.validateConfig();
        expect(isValid, isTrue);
      });

      test('should get migration info', () async {
        final migrationInfo = MigrationInfo.getMigrationInfo(2);
        expect(migrationInfo, isNotNull);
        expect(migrationInfo!.version, equals(2));
        expect(migrationInfo.description, isNotEmpty);
      });

      test('should check migration availability', () async {
        expect(MigrationInfo.isMigrationAvailable(2), isTrue);
        expect(MigrationInfo.isMigrationAvailable(99), isFalse);
      });
    });

    group('Database Health Checks', () {
      test('should create healthy check result', () async {
        final metrics = {
          'table_count': 10,
          'size_bytes': 1024,
          'integrity_ok': true,
        };
        
        final healthCheck = DatabaseHealthCheck.healthy(metrics);
        
        expect(healthCheck.isHealthy, isTrue);
        expect(healthCheck.issues, isEmpty);
        expect(healthCheck.metrics, equals(metrics));
        expect(healthCheck.checkedAt, isA<DateTime>());
      });

      test('should create unhealthy check result', () async {
        final issues = ['Integrity check failed', 'Missing indexes'];
        final metrics = {'integrity_ok': false};
        
        final healthCheck = DatabaseHealthCheck.unhealthy(issues, metrics);
        
        expect(healthCheck.isHealthy, isFalse);
        expect(healthCheck.issues, equals(issues));
        expect(healthCheck.metrics, equals(metrics));
      });

      test('should convert health check to JSON', () async {
        final healthCheck = DatabaseHealthCheck.healthy({'test': 'value'});
        final json = healthCheck.toJson();
        
        expect(json, isA<Map<String, dynamic>>());
        expect(json['isHealthy'], isTrue);
        expect(json['issues'], isEmpty);
        expect(json['metrics'], equals({'test': 'value'}));
        expect(json['checkedAt'], isA<String>());
      });
    });
  });
}