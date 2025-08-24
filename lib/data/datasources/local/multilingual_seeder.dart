import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/muscle_group.dart';
import '../../../core/constants/multilingual_data.dart';
import 'database_helper.dart';

/// Service for seeding multilingual exercise and muscle group data
class MultilingualSeeder {
  final DatabaseHelper _databaseHelper;
  final Logger _logger = Logger();
  
  MultilingualSeeder(this._databaseHelper);
  
  /// Seed all multilingual data
  Future<void> seedAll() async {
    try {
      await seedMuscleGroups();
      await seedExercises();
      _logger.i('Successfully seeded all multilingual data');
    } catch (e) {
      _logger.e('Error seeding multilingual data: $e');
      rethrow;
    }
  }
  
  /// Seed muscle groups with multilingual names
  Future<void> seedMuscleGroups() async {
    try {
      final db = await _databaseHelper.database;
      final muscleGroups = MultilingualData.createDefaultMuscleGroups();
      
      _logger.d('Seeding ${muscleGroups.length} muscle groups');
      
      for (final muscleGroup in muscleGroups) {
        await _insertOrUpdateMuscleGroup(db, muscleGroup);
      }
      
      _logger.i('Successfully seeded ${muscleGroups.length} muscle groups');
    } catch (e) {
      _logger.e('Error seeding muscle groups: $e');
      rethrow;
    }
  }
  
  /// Seed exercises with multilingual names
  Future<void> seedExercises() async {
    try {
      final db = await _databaseHelper.database;
      final exercises = MultilingualData.createDefaultExercises();
      
      _logger.d('Seeding ${exercises.length} exercises');
      
      for (final exercise in exercises) {
        await _insertOrUpdateExercise(db, exercise);
      }
      
      _logger.i('Successfully seeded ${exercises.length} exercises');
    } catch (e) {
      _logger.e('Error seeding exercises: $e');
      rethrow;
    }
  }
  
  /// Insert or update a muscle group
  Future<void> _insertOrUpdateMuscleGroup(Database db, MuscleGroup muscleGroup) async {
    try {
      final existingMuscleGroup = await db.query(
        'muscle_groups',
        where: 'id = ?',
        whereArgs: [muscleGroup.id],
        limit: 1,
      );
      
      final muscleGroupData = {
        'id': muscleGroup.id,
        'names_json': _encodeNamesMap(muscleGroup.names),
        'recovery_tau': muscleGroup.recoveryTau,
        'fatigue_multiplier': muscleGroup.fatigueMultiplier,
        'body_region': muscleGroup.bodyRegion,
      };
      
      if (existingMuscleGroup.isEmpty) {
        // Insert new muscle group
        await db.insert('muscle_groups', muscleGroupData);
        _logger.d('Inserted muscle group: ${muscleGroup.id}');
      } else {
        // Update existing muscle group (preserve user customizations if any)
        await db.update(
          'muscle_groups',
          muscleGroupData,
          where: 'id = ?',
          whereArgs: [muscleGroup.id],
        );
        _logger.d('Updated muscle group: ${muscleGroup.id}');
      }
    } catch (e) {
      _logger.e('Error inserting/updating muscle group ${muscleGroup.id}: $e');
      rethrow;
    }
  }
  
  /// Insert or update an exercise
  Future<void> _insertOrUpdateExercise(Database db, Exercise exercise) async {
    try {
      final existingExercise = await db.query(
        'exercises',
        where: 'id = ?',
        whereArgs: [exercise.id],
        limit: 1,
      );
      
      final exerciseData = {
        'id': exercise.id,
        'names_json': _encodeNamesMap(exercise.names),
        'category': exercise.category,
        'equipment': exercise.equipment.toString(),
        'instructions_json': _encodeNamesMap(exercise.instructions),
        'primary_muscle_groups_json': _encodeStringList(exercise.primaryMuscleGroups),
        'secondary_muscle_groups_json': _encodeStringList(exercise.secondaryMuscleGroups),
        'is_compound': exercise.isCompound ? 1 : 0,
        'created_at': exercise.createdAt.millisecondsSinceEpoch,
      };
      
      if (existingExercise.isEmpty) {
        // Insert new exercise
        await db.insert('exercises', exerciseData);
        _logger.d('Inserted exercise: ${exercise.id}');
      } else {
        // Update existing exercise (preserve user customizations if any)
        await db.update(
          'exercises',
          exerciseData,
          where: 'id = ?',
          whereArgs: [exercise.id],
        );
        _logger.d('Updated exercise: ${exercise.id}');
      }
    } catch (e) {
      _logger.e('Error inserting/updating exercise ${exercise.id}: $e');
      rethrow;
    }
  }
  
  /// Encode a Map<String, String> to JSON string for database storage
  String _encodeNamesMap(Map<String, String> names) {
    // Simple JSON encoding - in production, use proper JSON encoding
    final entries = names.entries
        .map((e) => '"${e.key}":"${e.value.replaceAll('"', '\\"')}"')
        .join(',');
    return '{$entries}';
  }
  
  /// Encode a List<String> to JSON string for database storage
  String _encodeStringList(List<String> list) {
    final entries = list.map((s) => '"$s"').join(',');
    return '[$entries]';
  }
  
  /// Check if seeding is needed (no muscle groups or exercises exist)
  Future<bool> needsSeeding() async {
    try {
      final db = await _databaseHelper.database;
      
      final muscleGroupCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM muscle_groups'),
      ) ?? 0;
      
      final exerciseCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM exercises'),
      ) ?? 0;
      
      final needsSeeding = muscleGroupCount == 0 || exerciseCount == 0;
      _logger.d('Needs seeding: $needsSeeding (muscle groups: $muscleGroupCount, exercises: $exerciseCount)');
      
      return needsSeeding;
    } catch (e) {
      _logger.e('Error checking if seeding is needed: $e');
      return true; // Default to needing seeding if we can't check
    }
  }
  
  /// Force reseed all data (useful for updates)
  Future<void> forceReseed() async {
    try {
      final db = await _databaseHelper.database;
      
      // Clear existing data
      await db.delete('exercises');
      await db.delete('muscle_groups');
      
      _logger.d('Cleared existing multilingual data');
      
      // Reseed
      await seedAll();
      
      _logger.i('Successfully force reseeded all multilingual data');
    } catch (e) {
      _logger.e('Error force reseeding multilingual data: $e');
      rethrow;
    }
  }
  
  /// Update only the multilingual names without affecting other data
  Future<void> updateMultilingualNames() async {
    try {
      final db = await _databaseHelper.database;
      
      // Update muscle group names
      for (final entry in MUSCLE_GROUP_NAMES.entries) {
        await db.update(
          'muscle_groups',
          {'names_json': _encodeNamesMap(entry.value)},
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
      
      // Update exercise names and instructions
      for (final entry in EXERCISE_NAMES.entries) {
        final exerciseId = entry.key;
        final names = entry.value;
        final instructions = EXERCISE_INSTRUCTIONS[exerciseId] ?? <String, String>{};
        
        await db.update(
          'exercises',
          {
            'names_json': _encodeNamesMap(names),
            'instructions_json': _encodeNamesMap(instructions),
          },
          where: 'id = ?',
          whereArgs: [exerciseId],
        );
      }
      
      _logger.i('Successfully updated multilingual names');
    } catch (e) {
      _logger.e('Error updating multilingual names: $e');
      rethrow;
    }
  }
}