import 'dart:async';
import 'dart:io' show File, Directory;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'database_config.dart';

/// Database health monitoring and maintenance utilities
class DatabaseHealthMonitor {
  static final Logger _logger = Logger();
  
  /// Perform comprehensive database health check
  static Future<DatabaseHealthCheck> performHealthCheck(Database db) async {
    final issues = <String>[];
    final metrics = <String, dynamic>{};
    final stopwatch = Stopwatch()..start();
    
    try {
      // Check database connectivity
      await _checkConnectivity(db, issues, metrics);
      
      // Check database integrity
      await _checkIntegrity(db, issues, metrics);
      
      // Check encryption status
      await _checkEncryption(db, issues, metrics);
      
      // Check performance metrics
      await _checkPerformance(db, issues, metrics);
      
      // Check disk space
      await _checkDiskSpace(db, issues, metrics);
      
      // Check table statistics
      await _checkTableStatistics(db, issues, metrics);
      
      // Check migration status
      await _checkMigrationStatus(db, issues, metrics);
      
      stopwatch.stop();
      metrics['health_check_duration_ms'] = stopwatch.elapsedMilliseconds;
      
      final isHealthy = issues.isEmpty;
      
      if (isHealthy) {
        _logger.i('Database health check passed (${stopwatch.elapsedMilliseconds}ms)');
        return DatabaseHealthCheck.healthy(metrics);
      } else {
        _logger.w('Database health check found ${issues.length} issues: ${issues.join(', ')}');
        return DatabaseHealthCheck.unhealthy(issues, metrics);
      }
      
    } catch (e) {
      stopwatch.stop();
      _logger.e('Database health check failed: $e');
      
      issues.add('Health check failed: $e');
      metrics['health_check_duration_ms'] = stopwatch.elapsedMilliseconds;
      
      return DatabaseHealthCheck.unhealthy(issues, metrics);
    }
  }
  
  /// Check basic database connectivity
  static Future<void> _checkConnectivity(
    Database db,
    List<String> issues,
    Map<String, dynamic> metrics,
  ) async {
    try {
      final result = await db.rawQuery('SELECT 1 as test');
      if (result.isEmpty || result.first['test'] != 1) {
        issues.add('Database connectivity test failed');
      }
      metrics['connectivity_test'] = 'passed';
    } catch (e) {
      issues.add('Database connectivity error: $e');
      metrics['connectivity_test'] = 'failed';
    }
  }
  
  /// Check database integrity
  static Future<void> _checkIntegrity(
    Database db,
    List<String> issues,
    Map<String, dynamic> metrics,
  ) async {
    try {
      final result = await db.rawQuery('PRAGMA integrity_check');
      
      if (result.isEmpty) {
        issues.add('Integrity check returned no results');
        metrics['integrity_check'] = 'no_results';
      } else {
        final checkResult = result.first['integrity_check'] as String;
        if (checkResult != 'ok') {
          issues.add('Database integrity check failed: $checkResult');
          metrics['integrity_check'] = 'failed';
        } else {
          metrics['integrity_check'] = 'passed';
        }
      }
    } catch (e) {
      issues.add('Integrity check error: $e');
      metrics['integrity_check'] = 'error';
    }
  }
  
  /// Check encryption status
  static Future<void> _checkEncryption(
    Database db,
    List<String> issues,
    Map<String, dynamic> metrics,
  ) async {
    try {
      // Check if SQLCipher is available
      final cipherVersion = await db.rawQuery('PRAGMA cipher_version');
      
      if (cipherVersion.isNotEmpty) {
        metrics['cipher_version'] = cipherVersion.first['cipher_version'];
        metrics['encryption_enabled'] = true;
        
        // Check cipher settings
        final pageSize = await db.rawQuery('PRAGMA cipher_page_size');
        final kdfIter = await db.rawQuery('PRAGMA kdf_iter');
        
        metrics['cipher_page_size'] = pageSize.isNotEmpty ? pageSize.first['cipher_page_size'] : 'unknown';
        metrics['kdf_iterations'] = kdfIter.isNotEmpty ? kdfIter.first['kdf_iter'] : 'unknown';
        
      } else {
        if (DatabaseConfig.encryptionEnabled) {
          issues.add('Encryption is enabled but SQLCipher is not available');
        }
        metrics['encryption_enabled'] = false;
      }
    } catch (e) {
      if (DatabaseConfig.encryptionEnabled) {
        issues.add('Encryption check error: $e');
      }
      metrics['encryption_check'] = 'error';
    }
  }
  
  /// Check database performance metrics
  static Future<void> _checkPerformance(
    Database db,
    List<String> issues,
    Map<String, dynamic> metrics,
  ) async {
    try {
      // Check journal mode
      final journalMode = await db.rawQuery('PRAGMA journal_mode');
      metrics['journal_mode'] = journalMode.isNotEmpty ? journalMode.first['journal_mode'] : 'unknown';
      
      // Check synchronous mode
      final synchronous = await db.rawQuery('PRAGMA synchronous');
      metrics['synchronous_mode'] = synchronous.isNotEmpty ? synchronous.first['synchronous'] : 'unknown';
      
      // Check cache size
      final cacheSize = await db.rawQuery('PRAGMA cache_size');
      metrics['cache_size'] = cacheSize.isNotEmpty ? cacheSize.first['cache_size'] : 'unknown';
      
      // Check page size
      final pageSize = await db.rawQuery('PRAGMA page_size');
      metrics['page_size'] = pageSize.isNotEmpty ? pageSize.first['page_size'] : 'unknown';
      
      // Check database size
      final pageCount = await db.rawQuery('PRAGMA page_count');
      if (pageCount.isNotEmpty && pageSize.isNotEmpty) {
        final pages = pageCount.first['page_count'] as int;
        final size = pageSize.first['page_size'] as int;
        metrics['database_size_bytes'] = pages * size;
      }
      
      // Performance test - simple query timing
      final stopwatch = Stopwatch()..start();
      await db.rawQuery('SELECT COUNT(*) FROM sqlite_master');
      stopwatch.stop();
      metrics['simple_query_time_ms'] = stopwatch.elapsedMilliseconds;
      
      if (stopwatch.elapsedMilliseconds > 1000) {
        issues.add('Simple query took too long: ${stopwatch.elapsedMilliseconds}ms');
      }
      
    } catch (e) {
      issues.add('Performance check error: $e');
      metrics['performance_check'] = 'error';
    }
  }
  
  /// Check available disk space
static Future<void> _checkDiskSpace(
    Database db,
    List<String> issues,
    Map<String, dynamic> metrics,
  ) async {
    if (kIsWeb) {
      // IndexedDB handles storage; disk space checks not applicable.
      return;
    }
    try {
      final databasesPath = await getDatabasesPath();
      final directory = Directory(databasesPath);

      if (await directory.exists()) {
        metrics['database_directory'] = databasesPath;

        // Get database file size
        final dbFile = File(join(databasesPath, DatabaseConfig.databaseName));
        if (await dbFile.exists()) {
          final dbSize = await dbFile.length();
          metrics['database_file_size_bytes'] = dbSize;

          // Warn if database grows too large
          if (dbSize > 100 * 1024 * 1024) {
            _logger.w('Database file is large ${(dbSize / 1024 / 1024).toStringAsFixed(1)}MB');
          }
        }
      }
    } catch (e) {
      issues.add('Disk space check error: $e');
      metrics['disk_space_check'] = 'error';
    }
  }
  
  /// Check table statistics and potential issues
  static Future<void> _checkTableStatistics(
    Database db,
    List<String> issues,
    Map<String, dynamic> metrics,
  ) async {
    try {
      final tables = [
        'users', 'muscle_groups', 'exercises', 'workout_sessions', 'workout_sets',
        'recovery_states', 'avatar_states', 'templates', 'template_exercises',
        'pr_records', 'fatigue_events', 'notifications', 'sync_queue'
      ];
      
      final tableCounts = <String, int>{};
      final tableStats = <String, Map<String, dynamic>>{};
      
      for (final table in tables) {
        try {
          // Get row count
          final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
          final count = countResult.first['count'] as int;
          tableCounts[table] = count;
          
          // Get table info
          final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
          tableStats[table] = {
            'row_count': count,
            'column_count': tableInfo.length,
          };
          
          // Check for potential issues
          if (count > 100000) {
            _logger.w('Table $table has many rows ($count) - consider archiving old data');
          }
          
        } catch (e) {
          issues.add('Error checking table $table: $e');
          tableCounts[table] = -1;
        }
      }
      
      metrics['table_counts'] = tableCounts;
      metrics['table_statistics'] = tableStats;
      
    } catch (e) {
      issues.add('Table statistics check error: $e');
      metrics['table_statistics_check'] = 'error';
    }
  }
  
  /// Check migration status and history
  static Future<void> _checkMigrationStatus(
    Database db,
    List<String> issues,
    Map<String, dynamic> metrics,
  ) async {
    try {
      // Check if migration_log table exists
      final migrationTableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='migration_log'"
      );
      
      if (migrationTableExists.isEmpty) {
        issues.add('Migration log table does not exist');
        metrics['migration_log_exists'] = false;
        return;
      }
      
      metrics['migration_log_exists'] = true;
      
      // Get migration history
      final migrations = await db.query(
        'migration_log',
        orderBy: 'executed_at DESC',
        limit: 10,
      );
      
      metrics['recent_migrations'] = migrations.length;
      
      // Check for failed migrations
      final failedMigrations = migrations.where((m) => m['success'] == 0).toList();
      if (failedMigrations.isNotEmpty) {
        issues.add('Found ${failedMigrations.length} failed migrations');
        metrics['failed_migrations'] = failedMigrations.length;
      }
      
      // Get current schema version
      final userVersion = await db.rawQuery('PRAGMA user_version');
      if (userVersion.isNotEmpty) {
        metrics['schema_version'] = userVersion.first['user_version'];
      }
      
    } catch (e) {
      issues.add('Migration status check error: $e');
      metrics['migration_status_check'] = 'error';
    }
  }
  
  /// Perform database maintenance tasks
  static Future<void> performMaintenance(Database db) async {
    _logger.i('Starting database maintenance');
    
    try {
      // Analyze database for query optimization
      await db.execute('ANALYZE');
      _logger.d('Database analysis completed');
      
      // Vacuum database to reclaim space (if needed)
      final pageCount = await db.rawQuery('PRAGMA page_count');
      final freelistCount = await db.rawQuery('PRAGMA freelist_count');
      
      if (pageCount.isNotEmpty && freelistCount.isNotEmpty) {
        final pages = pageCount.first['page_count'] as int;
        final freePages = freelistCount.first['freelist_count'] as int;
        
        // Vacuum if more than 10% of pages are free
        if (freePages > pages * 0.1) {
          _logger.i('Vacuuming database (${freePages} free pages out of ${pages})');
          await db.execute('VACUUM');
          _logger.i('Database vacuum completed');
        }
      }
      
      // Update table statistics
      await db.execute('PRAGMA optimize');
      _logger.d('Database optimization completed');
      
    } catch (e) {
      _logger.e('Database maintenance error: $e');
    }
  }
  
  /// Schedule periodic health checks
  static Timer? _healthCheckTimer;
  
  static void startPeriodicHealthChecks(Database db, {
    Duration interval = const Duration(hours: 6),
    Function(DatabaseHealthCheck)? onHealthCheckComplete,
  }) {
    _healthCheckTimer?.cancel();
    
    _healthCheckTimer = Timer.periodic(interval, (timer) async {
      try {
        final healthCheck = await performHealthCheck(db);
        
        if (!healthCheck.isHealthy) {
          _logger.w('Periodic health check found issues: ${healthCheck.issues}');
        }
        
        onHealthCheckComplete?.call(healthCheck);
        
        // Perform maintenance if needed
        if (healthCheck.metrics['simple_query_time_ms'] != null &&
            healthCheck.metrics['simple_query_time_ms'] > 500) {
          await performMaintenance(db);
        }
        
      } catch (e) {
        _logger.e('Periodic health check failed: $e');
      }
    });
    
    _logger.i('Started periodic health checks (interval: ${interval.inHours}h)');
  }
  
  static void stopPeriodicHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _logger.i('Stopped periodic health checks');
  }
}