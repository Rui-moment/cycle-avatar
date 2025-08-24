import 'package:flutter/foundation.dart';

/// Database configuration class for managing encryption and performance settings
class DatabaseConfig {
  /// Database name
  static const String databaseName = 'cycle_avatar.db';
  
  /// Current database version
  static const int currentVersion = 1;
  
  /// Encryption key storage key
  static const String encryptionKeyStorageKey = 'database_encryption_key';
  
  /// Whether to enable encryption (always true in production)
  static bool get encryptionEnabled => !kDebugMode || const bool.fromEnvironment('FORCE_ENCRYPTION', defaultValue: false);
  
  /// Database performance settings
  static const Map<String, String> performanceSettings = {
    'journal_mode': 'WAL',
    'synchronous': 'NORMAL',
    'cache_size': '-10000', // 10MB cache
    'temp_store': 'MEMORY',
    'mmap_size': '268435456', // 256MB memory map
  };
  
  /// Security settings for SQLCipher
  static const Map<String, String> securitySettings = {
    'cipher_page_size': '4096',
    'kdf_iter': '256000', // PBKDF2 iterations
    'cipher_hmac_algorithm': 'HMAC_SHA512',
    'cipher_kdf_algorithm': 'PBKDF2_HMAC_SHA512',
  };
  
  /// Backup settings
  static const int maxBackupFiles = 5;
  static const Duration backupRetentionPeriod = Duration(days: 30);
  
  /// Migration settings
  static const bool enableMigrationLogging = true;
  static const Duration migrationTimeout = Duration(minutes: 5);
  
  /// Connection pool settings
  static const int maxConnections = 1; // SQLite is single-writer
  static const Duration connectionTimeout = Duration(seconds: 30);
  
  /// Validation settings
  static const bool enableIntegrityChecks = true;
  static const Duration integrityCheckInterval = Duration(hours: 24);
  
  /// Get all PRAGMA settings as a map
  static Map<String, String> getAllPragmaSettings() {
    final settings = <String, String>{};
    settings.addAll(performanceSettings);
    
    if (encryptionEnabled) {
      settings.addAll(securitySettings);
    }
    
    return settings;
  }
  
  /// Get database file path components
  static String getDatabaseFileName({bool isBackup = false, int? timestamp}) {
    if (isBackup) {
      final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
      return 'backup_${ts}_$databaseName';
    }
    return databaseName;
  }
  
  /// Validate database configuration
  static bool validateConfig() {
    // Check if all required settings are present
    final requiredSettings = ['journal_mode', 'synchronous', 'cache_size'];
    
    for (final setting in requiredSettings) {
      if (!performanceSettings.containsKey(setting)) {
        return false;
      }
    }
    
    // Validate encryption settings if enabled
    if (encryptionEnabled) {
      final requiredSecuritySettings = ['cipher_page_size', 'kdf_iter'];
      
      for (final setting in requiredSecuritySettings) {
        if (!securitySettings.containsKey(setting)) {
          return false;
        }
      }
    }
    
    return true;
  }
}

/// Database migration information
class MigrationInfo {
  final int version;
  final String description;
  final DateTime createdAt;
  final bool isRequired;
  final List<String> dependencies;
  
  const MigrationInfo({
    required this.version,
    required this.description,
    required this.createdAt,
    this.isRequired = true,
    this.dependencies = const [],
  });
  
  /// Available migrations
  static const List<MigrationInfo> availableMigrations = [
    MigrationInfo(
      version: 2,
      description: 'Add user preferences and timezone support',
      createdAt: null, // Will be set when migration is created
      isRequired: false,
    ),
    MigrationInfo(
      version: 3,
      description: 'Add workout analytics and reporting',
      createdAt: null,
      isRequired: false,
    ),
    MigrationInfo(
      version: 4,
      description: 'Add achievements and social features',
      createdAt: null,
      isRequired: false,
    ),
  ];
  
  /// Get migration info by version
  static MigrationInfo? getMigrationInfo(int version) {
    try {
      return availableMigrations.firstWhere((m) => m.version == version);
    } catch (e) {
      return null;
    }
  }
  
  /// Check if migration is available
  static bool isMigrationAvailable(int version) {
    return availableMigrations.any((m) => m.version == version);
  }
}

/// Database health check results
class DatabaseHealthCheck {
  final bool isHealthy;
  final List<String> issues;
  final Map<String, dynamic> metrics;
  final DateTime checkedAt;
  
  const DatabaseHealthCheck({
    required this.isHealthy,
    required this.issues,
    required this.metrics,
    required this.checkedAt,
  });
  
  /// Create a healthy check result
  factory DatabaseHealthCheck.healthy(Map<String, dynamic> metrics) {
    return DatabaseHealthCheck(
      isHealthy: true,
      issues: [],
      metrics: metrics,
      checkedAt: DateTime.now(),
    );
  }
  
  /// Create an unhealthy check result
  factory DatabaseHealthCheck.unhealthy(List<String> issues, Map<String, dynamic> metrics) {
    return DatabaseHealthCheck(
      isHealthy: false,
      issues: issues,
      metrics: metrics,
      checkedAt: DateTime.now(),
    );
  }
  
  /// Convert to JSON for logging
  Map<String, dynamic> toJson() {
    return {
      'isHealthy': isHealthy,
      'issues': issues,
      'metrics': metrics,
      'checkedAt': checkedAt.toIso8601String(),
    };
  }
}