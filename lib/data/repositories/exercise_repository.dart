import 'dart:async';
import 'dart:convert';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:logger/logger.dart';

import '../../domain/entities/exercise.dart';
import '../../domain/entities/enums.dart';
import '../datasources/local/database_helper.dart';
import 'base_repository.dart';

/// Repository interface for Exercise operations
abstract class ExerciseRepository extends BaseRepository<Exercise, String> {
  /// Find exercises by category
  Future<List<Exercise>> findByCategory(String category);
  
  /// Find exercises by equipment type
  Future<List<Exercise>> findByEquipment(EquipmentType equipment);
  
  /// Find exercises that target a specific muscle group
  Future<List<Exercise>> findByMuscleGroup(String muscleGroupId);
  
  /// Find compound exercises
  Future<List<Exercise>> findCompoundExercises();
  
  /// Search exercises by name (supports localization)
  Future<List<Exercise>> searchByName(String query, {String locale = 'en'});
  
  /// Find exercises suitable for a specific training goal
  Future<List<Exercise>> findByTrainingGoal(TrainingGoal goal);
  
  /// Get exercises with their usage frequency
  Future<List<Map<String, dynamic>>> getExerciseUsageStats();
}

/// Implementation of ExerciseRepository using SQLite
class ExerciseRepositoryImpl extends BaseRepositoryImpl<Exercise, String> 
    with RepositoryErrorHandling 
    implements ExerciseRepository {
  
  final DatabaseHelper _databaseHelper;
  final Logger _logger = Logger();
  
  ExerciseRepositoryImpl(this._databaseHelper);
  
  @override
  String get tableName => 'exercises';
  
  @override
  Future<Database> get database => _databaseHelper.database;
  
  @override
  Map<String, dynamic> toMap(Exercise exercise) {
    return {
      'id': exercise.id,
      'names': jsonEncode(exercise.names),
      'category': exercise.category,
      'equipment': exercise.equipment.name,
      'instructions': jsonEncode(exercise.instructions),
      'primary_muscle_groups': jsonEncode(exercise.primaryMuscleGroups),
      'secondary_muscle_groups': jsonEncode(exercise.secondaryMuscleGroups),
      'is_compound': exercise.isCompound ? 1 : 0,
      'created_at': exercise.createdAt.millisecondsSinceEpoch,
    };
  }
  
  @override
  Exercise fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as String,
      names: Map<String, String>.from(jsonDecode(map['names'] as String)),
      category: map['category'] as String,
      equipment: EquipmentType.values.firstWhere(
        (e) => e.name == map['equipment'],
        orElse: () => EquipmentType.other,
      ),
      instructions: Map<String, String>.from(jsonDecode(map['instructions'] as String)),
      primaryMuscleGroups: List<String>.from(jsonDecode(map['primary_muscle_groups'] as String)),
      secondaryMuscleGroups: List<String>.from(jsonDecode(map['secondary_muscle_groups'] as String)),
      isCompound: (map['is_compound'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
  
  @override
  String getId(Exercise exercise) => exercise.id;
  
  @override
  Future<Exercise> create(Exercise exercise) async {
    return executeWithErrorHandling(() async {
      // Validate exercise data
      final validation = exercise.validate();
      if (validation != null) {
        throw RepositoryException('Invalid exercise data: $validation');
      }
      
      final db = await database;
      await db.insert(tableName, toMap(exercise));
      
      _logger.d('Created exercise: ${exercise.id}');
      return exercise;
    }, 'create exercise');
  }
  
  @override
  Future<Exercise?> findById(String id) async {
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
    }, 'find exercise by id');
  }
  
  @override
  Future<List<Exercise>> findAll() async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(tableName, orderBy: 'names ASC');
      return maps.map((map) => fromMap(map)).toList();
    }, 'find all exercises');
  }
  
  @override
  Future<Exercise> update(Exercise exercise) async {
    return executeWithErrorHandling(() async {
      // Validate exercise data
      final validation = exercise.validate();
      if (validation != null) {
        throw RepositoryException('Invalid exercise data: $validation');
      }
      
      final db = await database;
      final rowsAffected = await db.update(
        tableName,
        toMap(exercise),
        where: 'id = ?',
        whereArgs: [exercise.id],
      );
      
      if (rowsAffected == 0) {
        throw RepositoryException('Exercise not found: ${exercise.id}');
      }
      
      _logger.d('Updated exercise: ${exercise.id}');
      return exercise;
    }, 'update exercise');
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
        _logger.d('Deleted exercise: $id');
      }
      return deleted;
    }, 'delete exercise');
  }
  
  @override
  Future<List<Exercise>> findByCategory(String category) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'names ASC',
      );
      return maps.map((map) => fromMap(map)).toList();
    }, 'find exercises by category');
  }
  
  @override
  Future<List<Exercise>> findByEquipment(EquipmentType equipment) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'equipment = ?',
        whereArgs: [equipment.name],
        orderBy: 'names ASC',
      );
      return maps.map((map) => fromMap(map)).toList();
    }, 'find exercises by equipment');
  }
  
  @override
  Future<List<Exercise>> findByMuscleGroup(String muscleGroupId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'primary_muscle_groups LIKE ? OR secondary_muscle_groups LIKE ?',
        whereArgs: ['%"$muscleGroupId"%', '%"$muscleGroupId"%'],
        orderBy: 'names ASC',
      );
      return maps.map((map) => fromMap(map)).toList();
    }, 'find exercises by muscle group');
  }
  
  @override
  Future<List<Exercise>> findCompoundExercises() async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'is_compound = ?',
        whereArgs: [1],
        orderBy: 'names ASC',
      );
      return maps.map((map) => fromMap(map)).toList();
    }, 'find compound exercises');
  }
  
  @override
  Future<List<Exercise>> searchByName(String query, {String locale = 'en'}) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      
      // Search in the names JSON field for the specific locale
      final maps = await db.query(
        tableName,
        where: 'names LIKE ?',
        whereArgs: ['%"$locale"%"%$query%"%'],
        orderBy: 'names ASC',
      );
      
      // Filter results to ensure the query matches the localized name
      final exercises = maps.map((map) => fromMap(map)).toList();
      return exercises.where((exercise) {
        final localizedName = exercise.getLocalizedName(locale).toLowerCase();
        return localizedName.contains(query.toLowerCase());
      }).toList();
    }, 'search exercises by name');
  }
  
  @override
  Future<List<Exercise>> findByTrainingGoal(TrainingGoal goal) async {
    return executeWithErrorHandling(() async {
      // This is a simplified implementation
      // In practice, you might want to store training goal compatibility in the database
      final allExercises = await findAll();
      
      switch (goal) {
        case TrainingGoal.strength:
          // Prefer compound exercises for strength training
          return allExercises.where((exercise) => exercise.isCompound).toList();
        case TrainingGoal.hypertrophy:
          // All exercises are suitable for hypertrophy
          return allExercises;
        case TrainingGoal.general:
          // Focus on basic compound movements
          return allExercises.where((exercise) => 
            exercise.isCompound && 
            ['compound', 'basic'].contains(exercise.category)
          ).toList();
      }
    }, 'find exercises by training goal');
  }
  
  @override
  Future<List<Map<String, dynamic>>> getExerciseUsageStats() async {
    return executeWithErrorHandling(() async {
      final db = await database;
      
      // Join with workout_sets to get usage statistics
      final maps = await db.rawQuery('''
        SELECT 
          e.id,
          e.names,
          COUNT(ws.id) as usage_count,
          MAX(ws.created_at) as last_used_at,
          AVG(ws.weight) as avg_weight,
          AVG(ws.reps) as avg_reps
        FROM exercises e
        LEFT JOIN workout_sets ws ON e.id = ws.exercise_id
        GROUP BY e.id, e.names
        ORDER BY usage_count DESC, e.names ASC
      ''');
      
      return maps.map((map) => {
        'exercise_id': map['id'],
        'names': jsonDecode(map['names'] as String),
        'usage_count': map['usage_count'] as int,
        'last_used_at': map['last_used_at'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(map['last_used_at'] as int)
            : null,
        'avg_weight': map['avg_weight'] as double?,
        'avg_reps': map['avg_reps'] as double?,
      }).toList();
    }, 'get exercise usage stats');
  }
}