import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';
import 'database_config.dart';

/// Advanced database migration manager with rollback support and validation
class DatabaseMigrationManager {
  static final Logger _logger = Logger();
  
  /// Execute migration with comprehensive error handling and logging
  static Future<void> executeMigration({
    required DatabaseExecutor db,
    required int fromVersion,
    required int toVersion,
    required Future<void> Function(DatabaseExecutor) migrationFunction,
    String? description,
  }) async {
    final stopwatch = Stopwatch()..start();
    final migrationId = '${fromVersion}_to_$toVersion';
    
    _logger.i('Starting migration: $migrationId${description != null ? ' - $description' : ''}');
    
    try {
      // Create savepoint for rollback capability
      await db.execute('SAVEPOINT migration_$migrationId');
      
      // Execute the migration
      await migrationFunction(db);
      
      // Validate migration success
      await _validateMigration(db, toVersion);
      
      // Release savepoint
      await db.execute('RELEASE SAVEPOINT migration_$migrationId');
      
      stopwatch.stop();
      _logger.i('Migration $migrationId completed successfully in ${stopwatch.elapsedMilliseconds}ms');
      
      // Log successful migration
      await _logMigrationResult(
        db: db,
        version: toVersion,
        migrationType: 'upgrade',
        success: true,
        executionTimeMs: stopwatch.elapsedMilliseconds,
        description: description,
      );
      
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logger.e('Migration $migrationId failed: $e', error: e, stackTrace: stackTrace);
      
      try {
        // Rollback to savepoint
        await db.execute('ROLLBACK TO SAVEPOINT migration_$migrationId');
        _logger.i('Migration $migrationId rolled back successfully');
      } catch (rollbackError) {
        _logger.e('Failed to rollback migration $migrationId: $rollbackError');
      }
      
      // Log failed migration
      await _logMigrationResult(
        db: db,
        version: toVersion,
        migrationType: 'upgrade',
        success: false,
        executionTimeMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
        description: description,
      );
      
      rethrow;
    }
  }
  
  /// Validate migration by checking schema and data integrity
  static Future<void> _validateMigration(DatabaseExecutor db, int version) async {
    // Check if all expected tables exist
    final expectedTables = _getExpectedTablesForVersion(version);
    
    for (final tableName in expectedTables) {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      
      if (result.isEmpty) {
        throw Exception('Expected table $tableName not found after migration to version $version');
      }
    }
    
    // Run integrity check
    final integrityResult = await db.rawQuery('PRAGMA integrity_check');
    if (integrityResult.isEmpty || integrityResult.first['integrity_check'] != 'ok') {
      throw Exception('Database integrity check failed after migration to version $version');
    }
    
    _logger.d('Migration validation passed for version $version');
  }
  
  /// Get expected tables for a specific version
  static List<String> _getExpectedTablesForVersion(int version) {
    final baseTables = [
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
      'migration_log',
    ];
    
    switch (version) {
      case 2:
        return [...baseTables, 'user_preferences'];
      case 3:
        return [...baseTables, 'user_preferences', 'workout_analytics'];
      case 4:
        return [...baseTables, 'user_preferences', 'workout_analytics', 'achievements'];
      default:
        return baseTables;
    }
  }
  
  /// Log migration result to migration_log table
  static Future<void> _logMigrationResult({
    required DatabaseExecutor db,
    required int version,
    required String migrationType,
    required bool success,
    required int executionTimeMs,
    String? errorMessage,
    String? description,
  }) async {
    try {
      await db.insert('migration_log', {
        'version': version,
        'migration_type': migrationType,
        'executed_at': DateTime.now().millisecondsSinceEpoch,
        'success': success ? 1 : 0,
        'error_message': errorMessage,
        'execution_time_ms': executionTimeMs,
        'description': description,
      });
    } catch (e) {
      _logger.w('Failed to log migration result: $e');
    }
  }
  
  /// Create a database backup before migration
  static Future<String?> createPreMigrationBackup(String databasePath) async {
    try {
      final backupPath = '${databasePath}_backup_${DateTime.now().millisecondsSinceEpoch}';
      
      // Copy database file
      final sourceFile = File(databasePath);
      if (await sourceFile.exists()) {
        await sourceFile.copy(backupPath);
        _logger.i('Pre-migration backup created: $backupPath');
        return backupPath;
      }
      
      return null;
    } catch (e) {
      _logger.e('Failed to create pre-migration backup: $e');
      return null;
    }
  }
  
  /// Restore from backup if migration fails
  static Future<bool> restoreFromBackup(String databasePath, String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.copy(databasePath);
        _logger.i('Database restored from backup: $backupPath');
        return true;
      }
      
      return false;
    } catch (e) {
      _logger.e('Failed to restore from backup: $e');
      return false;
    }
  }
  
  /// Clean up old backup files
  static Future<void> cleanupOldBackups(String databasesPath) async {
    try {
      final directory = Directory(databasesPath);
      final files = await directory.list().toList();
      
      final backupFiles = files
          .whereType<File>()
          .where((file) => file.path.contains('_backup_'))
          .toList();
      
      // Sort by creation time (newest first)
      backupFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      
      // Keep only the most recent backups
      if (backupFiles.length > DatabaseConfig.maxBackupFiles) {
        final filesToDelete = backupFiles.skip(DatabaseConfig.maxBackupFiles);
        
        for (final file in filesToDelete) {
          await file.delete();
          _logger.d('Deleted old backup: ${file.path}');
        }
      }
      
      // Delete backups older than retention period
      final cutoffDate = DateTime.now().subtract(DatabaseConfig.backupRetentionPeriod);
      
      for (final file in backupFiles) {
        final stat = file.statSync();
        if (stat.modified.isBefore(cutoffDate)) {
          await file.delete();
          _logger.d('Deleted expired backup: ${file.path}');
        }
      }
      
    } catch (e) {
      _logger.w('Failed to cleanup old backups: $e');
    }
  }
  
  /// Get migration history with detailed information
  static Future<List<Map<String, dynamic>>> getMigrationHistory(DatabaseExecutor db) async {
    try {
      return await db.query(
        'migration_log',
        orderBy: 'executed_at DESC',
        limit: 100,
      );
    } catch (e) {
      _logger.w('Could not retrieve migration history: $e');
      return [];
    }
  }
  
  /// Check if a specific migration was successful
  static Future<bool> wasMigrationSuccessful(DatabaseExecutor db, int version) async {
    try {
      final result = await db.query(
        'migration_log',
        where: 'version = ? AND success = 1',
        whereArgs: [version],
        limit: 1,
      );
      
      return result.isNotEmpty;
    } catch (e) {
      _logger.w('Could not check migration status for version $version: $e');
      return false;
    }
  }
  
  /// Get the last successful migration version
  static Future<int?> getLastSuccessfulMigrationVersion(DatabaseExecutor db) async {
    try {
      final result = await db.query(
        'migration_log',
        where: 'success = 1',
        orderBy: 'version DESC',
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        return result.first['version'] as int;
      }
      
      return null;
    } catch (e) {
      _logger.w('Could not get last successful migration version: $e');
      return null;
    }
  }
}

import 'dart:io';