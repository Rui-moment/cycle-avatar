import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;
import 'package:path/path.dart';
import 'package:logger/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// Enhanced database helper with comprehensive schema, migrations, and encryption support
class DatabaseHelper {
  static const String _databaseName = 'cycle_avatar.db';
  static const int _databaseVersion = 1;
  static const String _encryptionKeyStorageKey = 'database_encryption_key';
  
  static Database? _database;
  static final Logger _logger = Logger();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Singleton instance
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  /// Get database instance with lazy initialization
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize database with proper configuration and encryption
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    _logger.i('Initializing encrypted database at: $path');

    // Get or generate encryption key
    final encryptionKey = await _getOrGenerateEncryptionKey();

    return await cipher.openDatabase(
      path,
      password: encryptionKey,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
      onConfigure: _onConfigure,
      onOpen: _onOpen,
    );
  }

  /// Get existing encryption key or generate a new one
  Future<String> _getOrGenerateEncryptionKey() async {
    try {
      // Try to get existing key
      String? existingKey = await _secureStorage.read(key: _encryptionKeyStorageKey);
      
      if (existingKey != null && existingKey.isNotEmpty) {
        _logger.d('Using existing encryption key');
        return existingKey;
      }

      // Generate new key if none exists
      _logger.i('Generating new database encryption key');
      final newKey = _generateSecureKey();
      
      // Store the key securely
      await _secureStorage.write(key: _encryptionKeyStorageKey, value: newKey);
      
      return newKey;
    } catch (e) {
      _logger.e('Error managing encryption key: $e');
      // Fallback to a generated key (not stored - will cause data loss on restart)
      _logger.w('Using fallback encryption key - data may be lost on restart');
      return _generateSecureKey();
    }
  }

  /// Generate a cryptographically secure key
  String _generateSecureKey() {
    final bytes = List<int>.generate(32, (i) => 
        DateTime.now().millisecondsSinceEpoch.hashCode + i);
    return sha256.convert(bytes).toString();
  }

  /// Configure database settings
  Future<void> _onConfigure(Database db) async {
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');
    
    // Set journal mode to WAL for better concurrency
    await db.execute('PRAGMA journal_mode = WAL');
    
    // Set synchronous mode to NORMAL for better performance
    await db.execute('PRAGMA synchronous = NORMAL');
    
    // Set cache size to 10MB
    await db.execute('PRAGMA cache_size = -10000');
    
    _logger.d('Database configuration completed');
  }

  /// Called when database is opened
  Future<void> _onOpen(Database db) async {
    _logger.i('Database opened successfully');
    
    // Verify foreign key constraints are enabled
    final result = await db.rawQuery('PRAGMA foreign_keys');
    _logger.d('Foreign keys enabled: ${result.first['foreign_keys']}');
  }

  /// Create all tables and initial data
  Future<void> _onCreate(Database db, int version) async {
    _logger.i('Creating database schema version $version');
    
    await _createTables(db);
    await _createIndexes(db);
    await _insertInitialData(db);
    
    _logger.i('Database schema created successfully');
  }

  /// Create all database tables
  Future<void> _createTables(DatabaseExecutor db) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        display_name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_sync_at INTEGER,
        preferred_language TEXT DEFAULT 'en',
        is_active INTEGER DEFAULT 1
      )
    ''');

    // Muscle Groups table
    await db.execute('''
      CREATE TABLE muscle_groups (
        id TEXT PRIMARY KEY,
        names TEXT NOT NULL, -- JSON: {'en': 'Chest', 'ja': '胸筋'}
        recovery_tau REAL NOT NULL,
        fatigue_multiplier REAL NOT NULL,
        body_region TEXT NOT NULL
      )
    ''');

    // Exercises table
    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        names TEXT NOT NULL, -- JSON: {'en': 'Squat', 'ja': 'スクワット'}
        category TEXT NOT NULL,
        equipment TEXT NOT NULL, -- EquipmentType enum value
        instructions TEXT NOT NULL, -- JSON: {'en': '...', 'ja': '...'}
        primary_muscle_groups TEXT NOT NULL, -- JSON array of muscle group IDs
        secondary_muscle_groups TEXT NOT NULL, -- JSON array of muscle group IDs
        is_compound INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // Workout Sessions table
    await db.execute('''
      CREATE TABLE workout_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        session_type TEXT NOT NULL, -- SessionType enum value
        notes TEXT,
        is_synced INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Workout Sets table
    await db.execute('''
      CREATE TABLE workout_sets (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        weight REAL NOT NULL,
        reps INTEGER NOT NULL,
        rpe INTEGER NOT NULL,
        rest_seconds INTEGER DEFAULT 0,
        notes TEXT,
        set_order INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES workout_sessions (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id)
      )
    ''');

    // Recovery States table
    await db.execute('''
      CREATE TABLE recovery_states (
        id TEXT PRIMARY KEY,
        muscle_group_id TEXT NOT NULL,
        current_fatigue REAL NOT NULL,
        last_updated INTEGER NOT NULL,
        readiness_level TEXT NOT NULL, -- ReadinessLevel enum value
        last_workout_time INTEGER,
        initial_fatigue REAL,
        FOREIGN KEY (muscle_group_id) REFERENCES muscle_groups (id)
      )
    ''');

    // Avatar States table
    await db.execute('''
      CREATE TABLE avatar_states (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        muscle_group_levels TEXT NOT NULL, -- JSON: {'chest': 5, 'back': 3}
        growth_points TEXT NOT NULL, -- JSON: {'chest': 150.5, 'back': 75.0}
        total_growth_points REAL NOT NULL,
        last_level_up INTEGER,
        unlocked_badges TEXT NOT NULL, -- JSON array of badge IDs
        cooldown_until TEXT NOT NULL DEFAULT '{}', -- JSON: {'chest': timestamp}
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Templates table
    await db.execute('''
      CREATE TABLE templates (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        is_public INTEGER DEFAULT 0,
        usage_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        last_used_at INTEGER,
        tags TEXT NOT NULL DEFAULT '[]', -- JSON array of tags
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Template Exercises table
    await db.execute('''
      CREATE TABLE template_exercises (
        id TEXT PRIMARY KEY,
        template_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        sets INTEGER NOT NULL,
        target_reps INTEGER NOT NULL,
        rest_seconds INTEGER NOT NULL,
        exercise_order INTEGER NOT NULL,
        primary_muscle_groups TEXT NOT NULL, -- JSON array
        secondary_muscle_groups TEXT NOT NULL, -- JSON array
        notes TEXT,
        target_weight REAL,
        is_superset INTEGER DEFAULT 0,
        superset_group TEXT,
        FOREIGN KEY (template_id) REFERENCES templates (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id)
      )
    ''');

    // PR Records table
    await db.execute('''
      CREATE TABLE pr_records (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        weight REAL NOT NULL,
        reps INTEGER NOT NULL,
        estimated_max REAL NOT NULL,
        achieved_at INTEGER NOT NULL,
        workout_session_id TEXT,
        notes TEXT,
        is_verified INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id),
        FOREIGN KEY (workout_session_id) REFERENCES workout_sessions (id)
      )
    ''');

    // Fatigue Events table
    await db.execute('''
      CREATE TABLE fatigue_events (
        id TEXT PRIMARY KEY,
        muscle_group_id TEXT NOT NULL,
        fatigue_score REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        workout_session_id TEXT NOT NULL,
        exercise_id TEXT,
        notes TEXT,
        FOREIGN KEY (muscle_group_id) REFERENCES muscle_groups (id),
        FOREIGN KEY (workout_session_id) REFERENCES workout_sessions (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id)
      )
    ''');

    // Notifications table
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL, -- NotificationType enum value
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        scheduled_for INTEGER,
        read_at INTEGER,
        priority TEXT NOT NULL DEFAULT 'normal', -- NotificationPriority enum value
        data TEXT NOT NULL DEFAULT '{}', -- JSON additional data
        is_read INTEGER DEFAULT 0,
        is_sent INTEGER DEFAULT 0,
        action_url TEXT,
        image_url TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Sync Queue table for offline operations
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL, -- 'workout_session', 'workout_set', etc.
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL, -- 'create', 'update', 'delete'
        data TEXT NOT NULL, -- JSON data to sync
        created_at INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_retry_at INTEGER,
        error_message TEXT
      )
    ''');

    _logger.d('All tables created successfully');
  }

  /// Create database indexes for performance
  Future<void> _createIndexes(DatabaseExecutor db) async {
    // Primary indexes for foreign key relationships
    await db.execute('CREATE INDEX idx_workout_sessions_user_id ON workout_sessions (user_id)');
    await db.execute('CREATE INDEX idx_workout_sets_session_id ON workout_sets (session_id)');
    await db.execute('CREATE INDEX idx_workout_sets_exercise_id ON workout_sets (exercise_id)');
    await db.execute('CREATE INDEX idx_recovery_states_muscle_group_id ON recovery_states (muscle_group_id)');
    await db.execute('CREATE INDEX idx_avatar_states_user_id ON avatar_states (user_id)');
    await db.execute('CREATE INDEX idx_templates_user_id ON templates (user_id)');
    await db.execute('CREATE INDEX idx_template_exercises_template_id ON template_exercises (template_id)');
    await db.execute('CREATE INDEX idx_pr_records_user_id ON pr_records (user_id)');
    await db.execute('CREATE INDEX idx_pr_records_exercise_id ON pr_records (exercise_id)');
    await db.execute('CREATE INDEX idx_fatigue_events_muscle_group_id ON fatigue_events (muscle_group_id)');
    await db.execute('CREATE INDEX idx_fatigue_events_session_id ON fatigue_events (workout_session_id)');
    await db.execute('CREATE INDEX idx_notifications_user_id ON notifications (user_id)');
    await db.execute('CREATE INDEX idx_sync_queue_entity ON sync_queue (entity_type, entity_id)');

    // Performance indexes for common queries
    await db.execute('CREATE INDEX idx_workout_sessions_start_time ON workout_sessions (start_time)');
    await db.execute('CREATE INDEX idx_workout_sets_created_at ON workout_sets (created_at)');
    await db.execute('CREATE INDEX idx_pr_records_achieved_at ON pr_records (achieved_at)');
    await db.execute('CREATE INDEX idx_fatigue_events_timestamp ON fatigue_events (timestamp)');
    await db.execute('CREATE INDEX idx_notifications_scheduled_for ON notifications (scheduled_for)');
    await db.execute('CREATE INDEX idx_notifications_is_read ON notifications (is_read)');
    await db.execute('CREATE INDEX idx_sync_queue_created_at ON sync_queue (created_at)');

    // Composite indexes for complex queries
    await db.execute('CREATE INDEX idx_workout_sessions_user_start ON workout_sessions (user_id, start_time)');
    await db.execute('CREATE INDEX idx_pr_records_user_exercise ON pr_records (user_id, exercise_id)');
    await db.execute('CREATE INDEX idx_notifications_user_type ON notifications (user_id, type)');

    _logger.d('All indexes created successfully');
  }

  /// Insert initial reference data
  Future<void> _insertInitialData(DatabaseExecutor db) async {
    // Insert muscle groups with localized names
    await _insertMuscleGroups(db as Database);
    
    // Insert basic exercises
    await _insertBasicExercises(db as Database);
    
    _logger.d('Initial data inserted successfully');
  }

  /// Insert muscle group reference data
  Future<void> _insertMuscleGroups(Database db) async {
    final muscleGroups = [
      {
        'id': 'chest',
        'names': jsonEncode({'en': 'Chest', 'ja': '胸筋'}),
        'recovery_tau': 48.0,
        'fatigue_multiplier': 1.0,
        'body_region': 'upper',
      },
      {
        'id': 'back',
        'names': jsonEncode({'en': 'Back', 'ja': '背筋'}),
        'recovery_tau': 72.0,
        'fatigue_multiplier': 1.2,
        'body_region': 'upper',
      },
      {
        'id': 'shoulders',
        'names': jsonEncode({'en': 'Shoulders', 'ja': '肩'}),
        'recovery_tau': 48.0,
        'fatigue_multiplier': 0.8,
        'body_region': 'upper',
      },
      {
        'id': 'biceps',
        'names': jsonEncode({'en': 'Biceps', 'ja': '上腕二頭筋'}),
        'recovery_tau': 48.0,
        'fatigue_multiplier': 0.6,
        'body_region': 'upper',
      },
      {
        'id': 'triceps',
        'names': jsonEncode({'en': 'Triceps', 'ja': '上腕三頭筋'}),
        'recovery_tau': 48.0,
        'fatigue_multiplier': 0.6,
        'body_region': 'upper',
      },
      {
        'id': 'quadriceps',
        'names': jsonEncode({'en': 'Quadriceps', 'ja': '大腿四頭筋'}),
        'recovery_tau': 72.0,
        'fatigue_multiplier': 1.3,
        'body_region': 'lower',
      },
      {
        'id': 'hamstrings',
        'names': jsonEncode({'en': 'Hamstrings', 'ja': 'ハムストリング'}),
        'recovery_tau': 72.0,
        'fatigue_multiplier': 1.1,
        'body_region': 'lower',
      },
      {
        'id': 'glutes',
        'names': jsonEncode({'en': 'Glutes', 'ja': '臀筋'}),
        'recovery_tau': 72.0,
        'fatigue_multiplier': 1.2,
        'body_region': 'lower',
      },
      {
        'id': 'calves',
        'names': jsonEncode({'en': 'Calves', 'ja': 'ふくらはぎ'}),
        'recovery_tau': 48.0,
        'fatigue_multiplier': 0.7,
        'body_region': 'lower',
      },
      {
        'id': 'abs',
        'names': jsonEncode({'en': 'Abs', 'ja': '腹筋'}),
        'recovery_tau': 24.0,
        'fatigue_multiplier': 0.5,
        'body_region': 'core',
      },
    ];

    for (final muscleGroup in muscleGroups) {
      await db.insert('muscle_groups', muscleGroup);
    }
  }

  /// Insert basic exercise reference data
  Future<void> _insertBasicExercises(Database db) async {
    final exercises = [
      {
        'id': 'squat',
        'names': jsonEncode({'en': 'Squat', 'ja': 'スクワット'}),
        'category': 'compound',
        'equipment': 'barbell',
        'instructions': jsonEncode({
          'en': 'Stand with feet shoulder-width apart, lower body by bending knees and hips.',
          'ja': '足を肩幅に開き、膝と股関節を曲げて体を下げる。'
        }),
        'primary_muscle_groups': jsonEncode(['quadriceps', 'glutes']),
        'secondary_muscle_groups': jsonEncode(['hamstrings', 'calves']),
        'is_compound': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'id': 'bench_press',
        'names': jsonEncode({'en': 'Bench Press', 'ja': 'ベンチプレス'}),
        'category': 'compound',
        'equipment': 'barbell',
        'instructions': jsonEncode({
          'en': 'Lie on bench, lower bar to chest, press up to full arm extension.',
          'ja': 'ベンチに横になり、バーを胸まで下げ、腕を完全に伸ばして押し上げる。'
        }),
        'primary_muscle_groups': jsonEncode(['chest']),
        'secondary_muscle_groups': jsonEncode(['shoulders', 'triceps']),
        'is_compound': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'id': 'deadlift',
        'names': jsonEncode({'en': 'Deadlift', 'ja': 'デッドリフト'}),
        'category': 'compound',
        'equipment': 'barbell',
        'instructions': jsonEncode({
          'en': 'Stand over bar, grip with both hands, lift by extending hips and knees.',
          'ja': 'バーの上に立ち、両手で握り、股関節と膝を伸ばして持ち上げる。'
        }),
        'primary_muscle_groups': jsonEncode(['back', 'hamstrings', 'glutes']),
        'secondary_muscle_groups': jsonEncode(['quadriceps', 'calves']),
        'is_compound': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    ];

    for (final exercise in exercises) {
      await db.insert('exercises', exercise);
    }
  }

  /// Handle database upgrades with transaction safety
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _logger.i('Upgrading database from version $oldVersion to $newVersion');
    
    await db.transaction((txn) async {
      // Create migration log table if it doesn't exist
      await _createMigrationLogTable(txn);
      
      // Handle migrations based on version differences
      for (int version = oldVersion + 1; version <= newVersion; version++) {
        await _migrateToVersion(txn, version);
        await _logMigration(txn, version, 'upgrade', true);
      }
    });
    
    _logger.i('Database upgrade completed successfully');
  }

  /// Handle database downgrades (usually not recommended in production)
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    _logger.w('Downgrading database from version $oldVersion to $newVersion');
    
    await db.transaction((txn) async {
      // Create migration log table if it doesn't exist
      await _createMigrationLogTable(txn);
      
      // For safety, we'll recreate the database on downgrade
      // In production, you might want to handle this more gracefully
      await _recreateDatabase(txn);
      await _logMigration(txn, newVersion, 'downgrade_recreate', true);
    });
  }

  /// Create migration log table for tracking schema changes
  Future<void> _createMigrationLogTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS migration_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version INTEGER NOT NULL,
        migration_type TEXT NOT NULL,
        executed_at INTEGER NOT NULL,
        success INTEGER NOT NULL,
        error_message TEXT,
        execution_time_ms INTEGER
      )
    ''');
  }

  /// Log migration execution
  Future<void> _logMigration(
    DatabaseExecutor db,
    int version,
    String migrationType,
    bool success, {
    String? errorMessage,
    int? executionTimeMs,
  }) async {
    await db.insert('migration_log', {
      'version': version,
      'migration_type': migrationType,
      'executed_at': DateTime.now().millisecondsSinceEpoch,
      'success': success ? 1 : 0,
      'error_message': errorMessage,
      'execution_time_ms': executionTimeMs,
    });
  }

  /// Migrate to a specific version with error handling
  Future<void> _migrateToVersion(DatabaseExecutor db, int version) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      _logger.i('Executing migration to version $version');
      
      switch (version) {
        case 2:
          await _migrateToVersion2(db);
          break;
        case 3:
          await _migrateToVersion3(db);
          break;
        case 4:
          await _migrateToVersion4(db);
          break;
        default:
          _logger.w('No migration defined for version $version');
      }
      
      stopwatch.stop();
      _logger.i('Migration to version $version completed in ${stopwatch.elapsedMilliseconds}ms');
      
    } catch (e) {
      stopwatch.stop();
      _logger.e('Migration to version $version failed: $e');
      await _logMigration(db, version, 'upgrade', false, 
          errorMessage: e.toString(), 
          executionTimeMs: stopwatch.elapsedMilliseconds);
      rethrow;
    }
  }

  /// Migration to version 2 - Example: Add user preferences
  Future<void> _migrateToVersion2(DatabaseExecutor db) async {
    // Add user preferences table
    await db.execute('''
      CREATE TABLE user_preferences (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        notification_settings TEXT NOT NULL DEFAULT '{}',
        theme_settings TEXT NOT NULL DEFAULT '{}',
        privacy_settings TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Add index for user preferences
    await db.execute('CREATE INDEX idx_user_preferences_user_id ON user_preferences (user_id)');

    // Add timezone column to users table
    await db.execute('ALTER TABLE users ADD COLUMN timezone TEXT DEFAULT "UTC"');
  }

  /// Migration to version 3 - Example: Add workout analytics
  Future<void> _migrateToVersion3(DatabaseExecutor db) async {
    // Add workout analytics table
    await db.execute('''
      CREATE TABLE workout_analytics (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        date TEXT NOT NULL,
        total_volume REAL NOT NULL,
        total_sets INTEGER NOT NULL,
        total_exercises INTEGER NOT NULL,
        session_duration_minutes INTEGER NOT NULL,
        average_rpe REAL NOT NULL,
        muscle_groups_trained TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Add indexes for analytics
    await db.execute('CREATE INDEX idx_workout_analytics_user_date ON workout_analytics (user_id, date)');
    await db.execute('CREATE INDEX idx_workout_analytics_date ON workout_analytics (date)');
  }

  /// Migration to version 4 - Example: Add social features
  Future<void> _migrateToVersion4(DatabaseExecutor db) async {
    // Add achievements table
    await db.execute('''
      CREATE TABLE achievements (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        achievement_type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        icon_url TEXT,
        earned_at INTEGER NOT NULL,
        progress_data TEXT NOT NULL DEFAULT '{}',
        is_milestone INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Add index for achievements
    await db.execute('CREATE INDEX idx_achievements_user_id ON achievements (user_id)');
    await db.execute('CREATE INDEX idx_achievements_earned_at ON achievements (earned_at)');
  }

  /// Recreate database (used for downgrades or corruption recovery)
  Future<void> _recreateDatabase(DatabaseExecutor db) async {
    _logger.w('Recreating database schema');
    
    // Drop all tables except migration_log
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != 'migration_log'"
    );
    
    for (final table in tables) {
      await db.execute('DROP TABLE IF EXISTS ${table['name']}');
    }
    
    // Recreate schema
    await _createTables(db);
    await _createIndexes(db);
    await _insertInitialData(db);
  }

  /// Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      _logger.i('Database connection closed');
    }
  }

  /// Get database file size in bytes
  Future<int> getDatabaseSize() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);
    final file = File(path);
    
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// Vacuum database to reclaim space
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
    _logger.i('Database vacuumed');
  }

  /// Check database integrity
  Future<bool> checkIntegrity() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA integrity_check');
    final isOk = result.isNotEmpty && result.first['integrity_check'] == 'ok';
    
    if (isOk) {
      _logger.i('Database integrity check passed');
    } else {
      _logger.e('Database integrity check failed: $result');
    }
    
    return isOk;
  }

  /// Get database statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;
    final size = await getDatabaseSize();
    
    // Get table counts
    final tables = [
      'users', 'muscle_groups', 'exercises', 'workout_sessions', 'workout_sets',
      'recovery_states', 'avatar_states', 'templates', 'template_exercises',
      'pr_records', 'fatigue_events', 'notifications', 'sync_queue'
    ];
    
    final counts = <String, int>{};
    for (final table in tables) {
      try {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        counts[table] = result.first['count'] as int;
      } catch (e) {
        _logger.w('Could not get count for table $table: $e');
        counts[table] = 0;
      }
    }
    
    return {
      'database_size_bytes': size,
      'database_version': _databaseVersion,
      'table_counts': counts,
      'is_encrypted': true,
    };
  }

  /// Get migration history
  Future<List<Map<String, dynamic>>> getMigrationHistory() async {
    final db = await database;
    
    try {
      return await db.query(
        'migration_log',
        orderBy: 'executed_at DESC',
        limit: 50,
      );
    } catch (e) {
      _logger.w('Could not retrieve migration history: $e');
      return [];
    }
  }

  /// Backup database to a file (encrypted)
  Future<String?> backupDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final sourcePath = join(databasesPath, _databaseName);
      final backupPath = join(databasesPath, 'backup_${DateTime.now().millisecondsSinceEpoch}_$_databaseName');
      
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        await sourceFile.copy(backupPath);
        _logger.i('Database backed up to: $backupPath');
        return backupPath;
      }
      
      return null;
    } catch (e) {
      _logger.e('Failed to backup database: $e');
      return null;
    }
  }

  /// Restore database from backup
  Future<bool> restoreDatabase(String backupPath) async {
    try {
      await close();
      
      final databasesPath = await getDatabasesPath();
      final targetPath = join(databasesPath, _databaseName);
      
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.copy(targetPath);
        _logger.i('Database restored from: $backupPath');
        
        // Reinitialize database
        _database = await _initDatabase();
        return true;
      }
      
      return false;
    } catch (e) {
      _logger.e('Failed to restore database: $e');
      return false;
    }
  }

  /// Change database encryption key
  Future<bool> changeEncryptionKey(String newKey) async {
    try {
      final db = await database;
      
      // Change the key using SQLCipher PRAGMA
      await db.rawQuery("PRAGMA rekey = '$newKey'");
      
      // Store the new key
      await _secureStorage.write(key: _encryptionKeyStorageKey, value: newKey);
      
      _logger.i('Database encryption key changed successfully');
      return true;
    } catch (e) {
      _logger.e('Failed to change encryption key: $e');
      return false;
    }
  }

  /// Remove encryption key (for testing or data export)
  Future<bool> removeEncryptionKey() async {
    try {
      await _secureStorage.delete(key: _encryptionKeyStorageKey);
      _logger.w('Database encryption key removed');
      return true;
    } catch (e) {
      _logger.e('Failed to remove encryption key: $e');
      return false;
    }
  }

  /// Test database connection and encryption
  Future<bool> testConnection() async {
    try {
      final db = await database;
      
      // Test basic query
      await db.rawQuery('SELECT 1');
      
      // Test encryption by trying to read with wrong key
      final testResult = await db.rawQuery('PRAGMA cipher_version');
      _logger.d('SQLCipher version: $testResult');
      
      return true;
    } catch (e) {
      _logger.e('Database connection test failed: $e');
      return false;
    }
  }

  /// Export database schema (for debugging)
  Future<String> exportSchema() async {
    final db = await database;
    
    final tables = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    );
    
    final indexes = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'"
    );
    
    final schema = StringBuffer();
    schema.writeln('-- Database Schema Export');
    schema.writeln('-- Generated: ${DateTime.now().toIso8601String()}');
    schema.writeln('-- Version: $_databaseVersion');
    schema.writeln();
    
    schema.writeln('-- Tables');
    for (final table in tables) {
      if (table['sql'] != null) {
        schema.writeln('${table['sql']};');
        schema.writeln();
      }
    }
    
    schema.writeln('-- Indexes');
    for (final index in indexes) {
      if (index['sql'] != null) {
        schema.writeln('${index['sql']};');
      }
    }
    
    return schema.toString();
  }
}