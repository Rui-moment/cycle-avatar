import 'package:logger/logger.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web implementation of the [DatabaseHelper] that relies on
/// `sqflite_common_ffi_web`. This provides a lightweight SQLite
/// database backed by IndexedDB and mirrors the mobile API so that
/// repositories can interact with it transparently.
class DatabaseHelper {
  static const String _databaseName = 'cycle_avatar.db';
  static const int _databaseVersion = 1;

  Database? _database;
  final Logger _logger = Logger();

  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  /// Provides the opened database instance, initialising it on first use.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final factory = databaseFactoryFfiWeb;
    _logger.i('Initializing web database');
    return factory.openDatabase(
      _databaseName,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onCreate: _onCreate,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    _logger.i('Creating web database schema version \$version');
    // Web implementation intentionally minimal; create tables as needed.
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

