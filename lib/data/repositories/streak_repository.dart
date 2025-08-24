import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';

import '../../domain/entities/streak_record.dart';
import '../datasources/local/database_helper.dart';
import 'base_repository.dart';

/// Repository interface for StreakRecord operations
abstract class StreakRepository extends BaseRepository<StreakRecord, String> {
  /// Find streak records by user ID
  Future<List<StreakRecord>> findByUserId(String userId);
  
  /// Find streak record by user and type
  Future<StreakRecord?> findByUserAndType(String userId, StreakType streakType);
  
  /// Get current active streaks for a user
  Future<List<StreakRecord>> getActiveStreaks(String userId);
  
  /// Get streak statistics for a user
  Future<Map<String, dynamic>> getStreakStats(String userId);
  
  /// Update streak with new workout
  Future<StreakRecord> updateStreakWithWorkout(
    String userId,
    StreakType streakType,
    DateTime workoutDate,
  );
  
  /// Break a streak
  Future<StreakRecord> breakStreak(String streakId);
  
  /// Get recent milestones for a user
  Future<List<StreakMilestone>> getRecentMilestones(
    String userId, {
    int limit = 10,
  });
  
  /// Get all milestones for a user
  Future<List<StreakMilestone>> getAllMilestones(String userId);
  
  /// Check for broken streaks and update them
  Future<List<StreakRecord>> checkAndUpdateBrokenStreaks(String userId);
}

/// Implementation of StreakRepository using SQLite
class StreakRepositoryImpl extends BaseRepositoryImpl<StreakRecord, String> 
    with RepositoryErrorHandling 
    implements StreakRepository {
  
  final DatabaseHelper _databaseHelper;
  final Logger _logger = Logger();
  
  StreakRepositoryImpl(this._databaseHelper);
  
  @override
  String get tableName => 'streak_records';
  
  @override
  Future<Database> get database => _databaseHelper.database;
  
  @override
  Map<String, dynamic> toMap(StreakRecord streak) {
    return {
      'id': streak.id,
      'user_id': streak.userId,
      'streak_type': streak.streakType.name,
      'current_streak': streak.currentStreak,
      'longest_streak': streak.longestStreak,
      'last_workout_date': streak.lastWorkoutDate.millisecondsSinceEpoch,
      'streak_start_date': streak.streakStartDate.millisecondsSinceEpoch,
      'streak_end_date': streak.streakEndDate?.millisecondsSinceEpoch,
      'milestones': jsonEncode(streak.milestones.map((m) => m.toJson()).toList()),
      'created_at': streak.createdAt.millisecondsSinceEpoch,
      'updated_at': streak.updatedAt.millisecondsSinceEpoch,
    };
  }
  
  @override
  StreakRecord fromMap(Map<String, dynamic> map) {
    final milestonesJson = map['milestones'] as String? ?? '[]';
    final milestonesList = jsonDecode(milestonesJson) as List;
    final milestones = milestonesList
        .map((m) => StreakMilestone.fromJson(m as Map<String, dynamic>))
        .toList();
    
    return StreakRecord(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      streakType: StreakType.values.firstWhere(
        (e) => e.name == map['streak_type'],
        orElse: () => StreakType.workout,
      ),
      currentStreak: map['current_streak'] as int,
      longestStreak: map['longest_streak'] as int,
      lastWorkoutDate: DateTime.fromMillisecondsSinceEpoch(map['last_workout_date'] as int),
      streakStartDate: DateTime.fromMillisecondsSinceEpoch(map['streak_start_date'] as int),
      streakEndDate: map['streak_end_date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['streak_end_date'] as int)
          : null,
      milestones: milestones,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
  
  @override
  String getId(StreakRecord streak) => streak.id;
  
  @override
  Future<StreakRecord> create(StreakRecord streak) async {
    return executeWithErrorHandling(() async {
      // Validate streak data
      final validation = streak.validate();
      if (validation != null) {
        throw RepositoryException('Invalid streak record data: $validation');
      }
      
      final db = await database;
      await db.insert(tableName, toMap(streak));
      
      _logger.d('Created streak record: ${streak.id}');
      return streak;
    }, 'create streak record');
  }
  
  @override
  Future<StreakRecord?> findById(String id) async {
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
    }, 'find streak record by id');
  }
  
  @override
  Future<List<StreakRecord>> findAll() async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(tableName, orderBy: 'updated_at DESC');
      return maps.map((map) => fromMap(map)).toList();
    }, 'find all streak records');
  }
  
  @override
  Future<StreakRecord> update(StreakRecord streak) async {
    return executeWithErrorHandling(() async {
      // Validate streak data
      final validation = streak.validate();
      if (validation != null) {
        throw RepositoryException('Invalid streak record data: $validation');
      }
      
      final db = await database;
      final rowsAffected = await db.update(
        tableName,
        toMap(streak),
        where: 'id = ?',
        whereArgs: [streak.id],
      );
      
      if (rowsAffected == 0) {
        throw RepositoryException('Streak record not found: ${streak.id}');
      }
      
      _logger.d('Updated streak record: ${streak.id}');
      return streak;
    }, 'update streak record');
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
        _logger.d('Deleted streak record: $id');
      }
      return deleted;
    }, 'delete streak record');
  }
  
  @override
  Future<List<StreakRecord>> findByUserId(String userId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'updated_at DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    }, 'find streak records by user id');
  }
  
  @override
  Future<StreakRecord?> findByUserAndType(String userId, StreakType streakType) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'user_id = ? AND streak_type = ?',
        whereArgs: [userId, streakType.name],
        limit: 1,
      );
      
      if (maps.isEmpty) return null;
      return fromMap(maps.first);
    }, 'find streak record by user and type');
  }
  
  @override
  Future<List<StreakRecord>> getActiveStreaks(String userId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'user_id = ? AND streak_end_date IS NULL',
        whereArgs: [userId],
        orderBy: 'current_streak DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    }, 'get active streaks');
  }
  
  @override
  Future<Map<String, dynamic>> getStreakStats(String userId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      
      // Get basic streak stats
      final basicStats = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_streaks,
          COUNT(CASE WHEN streak_end_date IS NULL THEN 1 END) as active_streaks,
          MAX(longest_streak) as max_longest_streak,
          AVG(longest_streak) as avg_longest_streak,
          SUM(current_streak) as total_current_streak_days
        FROM streak_records 
        WHERE user_id = ?
      ''', [userId]);
      
      // Get milestone stats
      final milestoneStats = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_milestones
        FROM (
          SELECT json_each.value as milestone
          FROM streak_records, json_each(milestones)
          WHERE user_id = ?
        )
      ''', [userId]);
      
      final basicData = basicStats.first;
      final milestoneData = milestoneStats.first;
      
      return {
        'total_streaks': basicData['total_streaks'] as int,
        'active_streaks': basicData['active_streaks'] as int,
        'max_longest_streak': basicData['max_longest_streak'] as int? ?? 0,
        'avg_longest_streak': basicData['avg_longest_streak'] as double? ?? 0.0,
        'total_current_streak_days': basicData['total_current_streak_days'] as int? ?? 0,
        'total_milestones': milestoneData['total_milestones'] as int? ?? 0,
      };
    }, 'get streak stats');
  }
  
  @override
  Future<StreakRecord> updateStreakWithWorkout(
    String userId,
    StreakType streakType,
    DateTime workoutDate,
  ) async {
    return executeWithErrorHandling(() async {
      // Find existing streak or create new one
      StreakRecord streak = await findByUserAndType(userId, streakType) ??
          StreakRecord(
            id: 'streak_${userId}_${streakType.name}_${DateTime.now().millisecondsSinceEpoch}',
            userId: userId,
            streakType: streakType,
            currentStreak: 0,
            longestStreak: 0,
            lastWorkoutDate: workoutDate,
            streakStartDate: workoutDate,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
      
      // Update streak with new workout
      final updatedStreak = streak.updateWithWorkout(workoutDate);
      
      // Save to database
      if (await exists(updatedStreak.id)) {
        return await update(updatedStreak);
      } else {
        return await create(updatedStreak);
      }
    }, 'update streak with workout');
  }
  
  @override
  Future<StreakRecord> breakStreak(String streakId) async {
    return executeWithErrorHandling(() async {
      final streak = await findById(streakId);
      if (streak == null) {
        throw RepositoryException('Streak record not found: $streakId');
      }
      
      final brokenStreak = streak.breakStreak();
      return await update(brokenStreak);
    }, 'break streak');
  }
  
  @override
  Future<List<StreakMilestone>> getRecentMilestones(
    String userId, {
    int limit = 10,
  }) async {
    return executeWithErrorHandling(() async {
      final streaks = await findByUserId(userId);
      
      // Collect all milestones from all streaks
      final allMilestones = <StreakMilestone>[];
      for (final streak in streaks) {
        allMilestones.addAll(streak.milestones);
      }
      
      // Sort by achievement date (newest first) and limit
      allMilestones.sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
      return allMilestones.take(limit).toList();
    }, 'get recent milestones');
  }
  
  @override
  Future<List<StreakMilestone>> getAllMilestones(String userId) async {
    return executeWithErrorHandling(() async {
      final streaks = await findByUserId(userId);
      
      // Collect all milestones from all streaks
      final allMilestones = <StreakMilestone>[];
      for (final streak in streaks) {
        allMilestones.addAll(streak.milestones);
      }
      
      // Sort by achievement date (newest first)
      allMilestones.sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
      return allMilestones;
    }, 'get all milestones');
  }
  
  @override
  Future<List<StreakRecord>> checkAndUpdateBrokenStreaks(String userId) async {
    return executeWithErrorHandling(() async {
      final activeStreaks = await getActiveStreaks(userId);
      final brokenStreaks = <StreakRecord>[];
      
      for (final streak in activeStreaks) {
        if (streak.isBroken) {
          final brokenStreak = await breakStreak(streak.id);
          brokenStreaks.add(brokenStreak);
          _logger.d('Broke streak: ${streak.id} (${streak.streakType.name})');
        }
      }
      
      return brokenStreaks;
    }, 'check and update broken streaks');
  }
}