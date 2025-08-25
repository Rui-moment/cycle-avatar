import 'dart:async';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:logger/logger.dart';

import '../../domain/entities/pr_record.dart';
import '../../domain/entities/workout_session.dart';
import '../datasources/local/database_helper.dart';
import 'base_repository.dart';

/// Repository interface for PRRecord operations
abstract class PRRepository extends BaseRepository<PRRecord, String> {
  /// Find PR records by user ID
  Future<List<PRRecord>> findByUserId(String userId);
  
  /// Find PR records by exercise ID
  Future<List<PRRecord>> findByExerciseId(String exerciseId);
  
  /// Find PR records by user and exercise
  Future<List<PRRecord>> findByUserAndExercise(String userId, String exerciseId);
  
  /// Get current PR for a specific exercise
  Future<PRRecord?> getCurrentPR(String userId, String exerciseId);
  
  /// Check if a workout set is a new PR
  Future<bool> isNewPR(String userId, String exerciseId, double weight, int reps);
  
  /// Create PR from workout set
  Future<PRRecord> createFromWorkoutSet({
    required String userId,
    required String exerciseId,
    required double weight,
    required int reps,
    required DateTime achievedAt,
    String? workoutSessionId,
    String? notes,
  });
  
  /// Get PR history for an exercise
  Future<List<PRRecord>> getPRHistory(String userId, String exerciseId);
  
  /// Get recent PRs for a user
  Future<List<PRRecord>> getRecentPRs(String userId, {int limit = 10});
  
  /// Get PR statistics for a user
  Future<Map<String, dynamic>> getPRStats(String userId);
  
  /// Get PRs achieved in date range
  Future<List<PRRecord>> getPRsInDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  );
  
  /// Verify a PR record
  Future<PRRecord> verifyPR(String prId);
  
  /// Get unverified PRs
  Future<List<PRRecord>> getUnverifiedPRs(String userId);
}

/// Implementation of PRRepository using SQLite
class PRRepositoryImpl extends BaseRepositoryImpl<PRRecord, String> 
    with RepositoryErrorHandling 
    implements PRRepository {
  
  final DatabaseHelper _databaseHelper;
  final Logger _logger = Logger();
  
  PRRepositoryImpl(this._databaseHelper);
  
  @override
  String get tableName => 'pr_records';
  
  @override
  Future<Database> get database => _databaseHelper.database;
  
  @override
  Map<String, dynamic> toMap(PRRecord pr) {
    return {
      'id': pr.id,
      'user_id': pr.userId,
      'exercise_id': pr.exerciseId,
      'weight': pr.weight,
      'reps': pr.reps,
      'estimated_max': pr.estimatedMax,
      'achieved_at': pr.achievedAt.millisecondsSinceEpoch,
      'workout_session_id': pr.workoutSessionId,
      'notes': pr.notes,
      'is_verified': pr.isVerified ? 1 : 0,
    };
  }
  
  @override
  PRRecord fromMap(Map<String, dynamic> map) {
    return PRRecord(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      exerciseId: map['exercise_id'] as String,
      weight: map['weight'] as double,
      reps: map['reps'] as int,
      estimatedMax: map['estimated_max'] as double,
      achievedAt: DateTime.fromMillisecondsSinceEpoch(map['achieved_at'] as int),
      workoutSessionId: map['workout_session_id'] as String?,
      notes: map['notes'] as String?,
      isVerified: (map['is_verified'] as int) == 1,
    );
  }
  
  @override
  String getId(PRRecord pr) => pr.id;
  
  @override
  Future<PRRecord> create(PRRecord pr) async {
    return executeWithErrorHandling(() async {
      // Validate PR data
      final validation = pr.validate();
      if (validation != null) {
        throw RepositoryException('Invalid PR record data: $validation');
      }
      
      final db = await database;
      await db.insert(tableName, toMap(pr));
      
      _logger.d('Created PR record: ${pr.id} for exercise ${pr.exerciseId}');
      return pr;
    }, 'create PR record');
  }
  
  @override
  Future<PRRecord?> findById(String id) async {
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
    }, 'find PR record by id');
  }
  
  @override
  Future<List<PRRecord>> findAll() async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(tableName, orderBy: 'achieved_at DESC');
      return maps.map((map) => fromMap(map)).toList();
    }, 'find all PR records');
  }
  
  @override
  Future<PRRecord> update(PRRecord pr) async {
    return executeWithErrorHandling(() async {
      // Validate PR data
      final validation = pr.validate();
      if (validation != null) {
        throw RepositoryException('Invalid PR record data: $validation');
      }
      
      final db = await database;
      final rowsAffected = await db.update(
        tableName,
        toMap(pr),
        where: 'id = ?',
        whereArgs: [pr.id],
      );
      
      if (rowsAffected == 0) {
        throw RepositoryException('PR record not found: ${pr.id}');
      }
      
      _logger.d('Updated PR record: ${pr.id}');
      return pr;
    }, 'update PR record');
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
        _logger.d('Deleted PR record: $id');
      }
      return deleted;
    }, 'delete PR record');
  }
  
  @override
  Future<List<PRRecord>> findByUserId(String userId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'achieved_at DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    }, 'find PR records by user id');
  }
  
  @override
  Future<List<PRRecord>> findByExerciseId(String exerciseId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'exercise_id = ?',
        whereArgs: [exerciseId],
        orderBy: 'achieved_at DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    }, 'find PR records by exercise id');
  }
  
  @override
  Future<List<PRRecord>> findByUserAndExercise(String userId, String exerciseId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'user_id = ? AND exercise_id = ?',
        whereArgs: [userId, exerciseId],
        orderBy: 'achieved_at DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    }, 'find PR records by user and exercise');
  }
  
  @override
  Future<PRRecord?> getCurrentPR(String userId, String exerciseId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'user_id = ? AND exercise_id = ?',
        whereArgs: [userId, exerciseId],
        orderBy: 'estimated_max DESC, achieved_at DESC',
        limit: 1,
      );
      
      if (maps.isEmpty) return null;
      return fromMap(maps.first);
    }, 'get current PR');
  }
  
  @override
  Future<bool> isNewPR(String userId, String exerciseId, double weight, int reps) async {
    return executeWithErrorHandling(() async {
      final currentPR = await getCurrentPR(userId, exerciseId);
      if (currentPR == null) return true;
      
      // Calculate estimated 1RM for the new set
      final newEstimatedMax = reps == 1 ? weight : weight * (1 + reps / 30.0);
      
      return newEstimatedMax > currentPR.estimatedMax;
    }, 'check if new PR');
  }
  
  @override
  Future<PRRecord> createFromWorkoutSet({
    required String userId,
    required String exerciseId,
    required double weight,
    required int reps,
    required DateTime achievedAt,
    String? workoutSessionId,
    String? notes,
  }) async {
    return executeWithErrorHandling(() async {
      // Generate unique ID
      final id = 'pr_${DateTime.now().millisecondsSinceEpoch}_${userId.hashCode}';
      
      final pr = PRRecord.fromWorkoutSet(
        id: id,
        userId: userId,
        exerciseId: exerciseId,
        weight: weight,
        reps: reps,
        achievedAt: achievedAt,
        workoutSessionId: workoutSessionId,
        notes: notes,
      );
      
      return await create(pr);
    }, 'create PR from workout set');
  }
  
  @override
  Future<List<PRRecord>> getPRHistory(String userId, String exerciseId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'user_id = ? AND exercise_id = ?',
        whereArgs: [userId, exerciseId],
        orderBy: 'achieved_at ASC', // Chronological order for history
      );
      return maps.map((map) => fromMap(map)).toList();
    }, 'get PR history');
  }
  
  @override
  Future<List<PRRecord>> getRecentPRs(String userId, {int limit = 10}) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'achieved_at DESC',
        limit: limit,
      );
      return maps.map((map) => fromMap(map)).toList();
    }, 'get recent PRs');
  }
  
  @override
  Future<Map<String, dynamic>> getPRStats(String userId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      
      // Get basic PR stats
      final basicStats = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_prs,
          COUNT(DISTINCT exercise_id) as exercises_with_prs,
          AVG(estimated_max) as avg_estimated_max,
          MAX(estimated_max) as max_estimated_max,
          COUNT(CASE WHEN achieved_at >= ? THEN 1 END) as recent_prs
        FROM pr_records 
        WHERE user_id = ?
      ''', [
        DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        userId,
      ]);
      
      // Get PR improvement stats
      final improvementStats = await db.rawQuery('''
        SELECT 
          AVG(improvement_percentage) as avg_improvement
        FROM (
          SELECT 
            exercise_id,
            (estimated_max - LAG(estimated_max) OVER (PARTITION BY exercise_id ORDER BY achieved_at)) / 
            LAG(estimated_max) OVER (PARTITION BY exercise_id ORDER BY achieved_at) * 100 as improvement_percentage
          FROM pr_records 
          WHERE user_id = ?
          ORDER BY exercise_id, achieved_at
        ) WHERE improvement_percentage IS NOT NULL
      ''', [userId]);
      
      final basicData = basicStats.first;
      final improvementData = improvementStats.first;
      
      return {
        'total_prs': basicData['total_prs'] as int,
        'exercises_with_prs': basicData['exercises_with_prs'] as int,
        'avg_estimated_max': basicData['avg_estimated_max'] as double? ?? 0.0,
        'max_estimated_max': basicData['max_estimated_max'] as double? ?? 0.0,
        'recent_prs': basicData['recent_prs'] as int,
        'avg_improvement_percentage': improvementData['avg_improvement'] as double? ?? 0.0,
      };
    }, 'get PR stats');
  }
  
  @override
  Future<List<PRRecord>> getPRsInDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'user_id = ? AND achieved_at >= ? AND achieved_at <= ?',
        whereArgs: [
          userId,
          startDate.millisecondsSinceEpoch,
          endDate.millisecondsSinceEpoch,
        ],
        orderBy: 'achieved_at DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    }, 'get PRs in date range');
  }
  
  @override
  Future<PRRecord> verifyPR(String prId) async {
    return executeWithErrorHandling(() async {
      final pr = await findById(prId);
      if (pr == null) {
        throw RepositoryException('PR record not found: $prId');
      }
      
      final verifiedPR = pr.verify();
      return await update(verifiedPR);
    }, 'verify PR');
  }
  
  @override
  Future<List<PRRecord>> getUnverifiedPRs(String userId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'user_id = ? AND is_verified = ?',
        whereArgs: [userId, 0],
        orderBy: 'achieved_at DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    }, 'get unverified PRs');
  }
}