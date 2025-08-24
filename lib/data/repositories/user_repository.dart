import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';

import '../../domain/entities/user.dart';
import '../datasources/local/database_helper.dart';
import 'base_repository.dart';

/// Repository interface for User operations
abstract class UserRepository extends BaseRepository<User, String> {
  /// Find user by email
  Future<User?> findByEmail(String email);
  
  /// Find active users
  Future<List<User>> findActiveUsers();
  
  /// Update user's last sync time
  Future<void> updateLastSyncTime(String userId, DateTime syncTime);
  
  /// Update user's preferred language
  Future<void> updatePreferredLanguage(String userId, String language);
  
  /// Deactivate user account
  Future<void> deactivateUser(String userId);
  
  /// Reactivate user account
  Future<void> reactivateUser(String userId);
}

/// Implementation of UserRepository using SQLite
class UserRepositoryImpl extends BaseRepositoryImpl<User, String> 
    with RepositoryErrorHandling 
    implements UserRepository {
  
  final DatabaseHelper _databaseHelper;
  final Logger _logger = Logger();
  
  UserRepositoryImpl(this._databaseHelper);
  
  @override
  String get tableName => 'users';
  
  @override
  Future<Database> get database => _databaseHelper.database;
  
  @override
  Map<String, dynamic> toMap(User user) {
    return {
      'id': user.id,
      'email': user.email,
      'display_name': user.displayName,
      'created_at': user.createdAt.millisecondsSinceEpoch,
      'last_sync_at': user.lastSyncAt?.millisecondsSinceEpoch,
      'preferred_language': user.preferredLanguage,
      'is_active': user.isActive ? 1 : 0,
    };
  }
  
  @override
  User fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      email: map['email'] as String,
      displayName: map['display_name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      lastSyncAt: map['last_sync_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['last_sync_at'] as int)
          : null,
      preferredLanguage: map['preferred_language'] as String? ?? 'en',
      isActive: (map['is_active'] as int) == 1,
    );
  }
  
  @override
  String getId(User user) => user.id;
  
  @override
  Future<User> create(User user) async {
    return executeWithErrorHandling(() async {
      // Validate user data
      final validation = user.validate();
      if (validation != null) {
        throw RepositoryException('Invalid user data: $validation');
      }
      
      final db = await database;
      await db.insert(tableName, toMap(user));
      
      _logger.d('Created user: ${user.id}');
      return user;
    }, 'create user');
  }
  
  @override
  Future<User?> findById(String id) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      if (maps.isEmpty) return null;
      return fromMap(maps.first);
    }, 'find user by id');
  }
  
  @override
  Future<List<User>> findAll() async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(tableName, orderBy: 'created_at DESC');
      return maps.map((map) => fromMap(map)).toList();
    }, 'find all users');
  }
  
  @override
  Future<User> update(User user) async {
    return executeWithErrorHandling(() async {
      // Validate user data
      final validation = user.validate();
      if (validation != null) {
        throw RepositoryException('Invalid user data: $validation');
      }
      
      final db = await database;
      final rowsAffected = await db.update(
        tableName,
        toMap(user),
        where: 'id = ?',
        whereArgs: [user.id],
      );
      
      if (rowsAffected == 0) {
        throw RepositoryException('User not found: ${user.id}');
      }
      
      _logger.d('Updated user: ${user.id}');
      return user;
    }, 'update user');
  }
  
  @override
  Future<bool> deleteById(String id) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final rowsAffected = await db.delete(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      final deleted = rowsAffected > 0;
      if (deleted) {
        _logger.d('Deleted user: $id');
      }
      return deleted;
    }, 'delete user');
  }
  
  @override
  Future<User?> findByEmail(String email) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'email = ?',
        whereArgs: [email],
        limit: 1,
      );
      
      if (maps.isEmpty) return null;
      return fromMap(maps.first);
    }, 'find user by email');
  }
  
  @override
  Future<List<User>> findActiveUsers() async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'created_at DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    }, 'find active users');
  }
  
  @override
  Future<void> updateLastSyncTime(String userId, DateTime syncTime) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final rowsAffected = await db.update(
        tableName,
        {'last_sync_at': syncTime.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [userId],
      );
      
      if (rowsAffected == 0) {
        throw RepositoryException('User not found: $userId');
      }
      
      _logger.d('Updated last sync time for user: $userId');
    }, 'update last sync time');
  }
  
  @override
  Future<void> updatePreferredLanguage(String userId, String language) async {
    return executeWithErrorHandling(() async {
      if (!['en', 'ja'].contains(language)) {
        throw RepositoryException('Unsupported language: $language');
      }
      
      final db = await database;
      final rowsAffected = await db.update(
        tableName,
        {'preferred_language': language},
        where: 'id = ?',
        whereArgs: [userId],
      );
      
      if (rowsAffected == 0) {
        throw RepositoryException('User not found: $userId');
      }
      
      _logger.d('Updated preferred language for user: $userId to $language');
    }, 'update preferred language');
  }
  
  @override
  Future<void> deactivateUser(String userId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final rowsAffected = await db.update(
        tableName,
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [userId],
      );
      
      if (rowsAffected == 0) {
        throw RepositoryException('User not found: $userId');
      }
      
      _logger.d('Deactivated user: $userId');
    }, 'deactivate user');
  }
  
  @override
  Future<void> reactivateUser(String userId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final rowsAffected = await db.update(
        tableName,
        {'is_active': 1},
        where: 'id = ?',
        whereArgs: [userId],
      );
      
      if (rowsAffected == 0) {
        throw RepositoryException('User not found: $userId');
      }
      
      _logger.d('Reactivated user: $userId');
    }, 'reactivate user');
  }
}