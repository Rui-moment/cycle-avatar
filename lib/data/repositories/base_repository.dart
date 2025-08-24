import 'dart:async';
import 'package:sqflite/sqflite.dart';

/// Base repository interface defining common CRUD operations
/// All repositories should implement this interface for consistency
abstract class BaseRepository<T, ID> {
  /// Create a new entity
  Future<T> create(T entity);
  
  /// Create multiple entities in a batch
  Future<List<T>> createBatch(List<T> entities);
  
  /// Find entity by ID
  Future<T?> findById(ID id);
  
  /// Find all entities
  Future<List<T>> findAll();
  
  /// Update an existing entity
  Future<T> update(T entity);
  
  /// Update multiple entities in a batch
  Future<List<T>> updateBatch(List<T> entities);
  
  /// Delete entity by ID
  Future<bool> deleteById(ID id);
  
  /// Delete an entity
  Future<bool> delete(T entity);
  
  /// Delete multiple entities
  Future<int> deleteBatch(List<ID> ids);
  
  /// Check if entity exists by ID
  Future<bool> exists(ID id);
  
  /// Count total entities
  Future<int> count();
  
  /// Find entities with pagination
  Future<List<T>> findWithPagination({
    int offset = 0,
    int limit = 50,
  });
  
  /// Clear all entities (use with caution)
  Future<int> clear();
}

/// Base repository implementation with common database operations
abstract class BaseRepositoryImpl<T, ID> implements BaseRepository<T, ID> {
  /// Table name for this repository
  String get tableName;
  
  /// Convert entity to database map
  Map<String, dynamic> toMap(T entity);
  
  /// Convert database map to entity
  T fromMap(Map<String, dynamic> map);
  
  /// Get the ID from an entity
  ID getId(T entity);
  
  /// Get the ID column name (default: 'id')
  String get idColumn => 'id';
  
  @override
  Future<bool> exists(ID id) async {
    final db = await database;
    final result = await db.query(
      tableName,
      columns: [idColumn],
      where: '$idColumn = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty;
  }
  
  @override
  Future<int> count() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    return result.first['count'] as int;
  }
  
  @override
  Future<List<T>> findWithPagination({
    int offset = 0,
    int limit = 50,
  }) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      offset: offset,
      limit: limit,
      orderBy: '$idColumn ASC',
    );
    return maps.map((map) => fromMap(map)).toList();
  }
  
  @override
  Future<int> clear() async {
    final db = await database;
    return await db.delete(tableName);
  }
  
  @override
  Future<List<T>> createBatch(List<T> entities) async {
    final db = await database;
    final batch = db.batch();
    
    for (final entity in entities) {
      batch.insert(tableName, toMap(entity));
    }
    
    await batch.commit(noResult: true);
    return entities;
  }
  
  @override
  Future<List<T>> updateBatch(List<T> entities) async {
    final db = await database;
    final batch = db.batch();
    
    for (final entity in entities) {
      final id = getId(entity);
      batch.update(
        tableName,
        toMap(entity),
        where: '$idColumn = ?',
        whereArgs: [id],
      );
    }
    
    await batch.commit(noResult: true);
    return entities;
  }
  
  @override
  Future<int> deleteBatch(List<ID> ids) async {
    if (ids.isEmpty) return 0;
    
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.rawDelete(
      'DELETE FROM $tableName WHERE $idColumn IN ($placeholders)',
      ids,
    );
  }
  
  @override
  Future<bool> delete(T entity) async {
    final id = getId(entity);
    return await deleteById(id);
  }
  
  /// Get database instance - to be implemented by concrete repositories
  Future<Database> get database;
}

/// Repository exception for handling database errors
class RepositoryException implements Exception {
  final String message;
  final String? operation;
  final dynamic originalError;
  
  const RepositoryException(
    this.message, {
    this.operation,
    this.originalError,
  });
  
  @override
  String toString() {
    final buffer = StringBuffer('RepositoryException: $message');
    if (operation != null) {
      buffer.write(' (Operation: $operation)');
    }
    if (originalError != null) {
      buffer.write(' (Original: $originalError)');
    }
    return buffer.toString();
  }
}

/// Mixin for handling common repository operations with error handling
mixin RepositoryErrorHandling {
  /// Execute database operation with error handling
  Future<T> executeWithErrorHandling<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    try {
      return await operation();
    } catch (e) {
      throw RepositoryException(
        'Failed to execute $operationName',
        operation: operationName,
        originalError: e,
      );
    }
  }
}