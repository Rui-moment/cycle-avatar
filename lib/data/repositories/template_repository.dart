import 'dart:async';
import 'dart:convert';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:logger/logger.dart';

import '../../domain/entities/template.dart';
import '../datasources/local/database_helper.dart';
import 'base_repository.dart';

/// Repository interface for Template operations
abstract class TemplateRepository extends BaseRepository<Template, String> {
  /// Find templates by user ID
  Future<List<Template>> findByUserId(String userId);
  
  /// Find public templates
  Future<List<Template>> findPublicTemplates();
  
  /// Find templates by tags
  Future<List<Template>> findByTags(List<String> tags);
  
  /// Find templates that target specific muscle groups
  Future<List<Template>> findByMuscleGroups(List<String> muscleGroupIds);
  
  /// Search templates by name or description
  Future<List<Template>> searchTemplates(String query, {String? userId});
  
  /// Get most used templates for a user
  Future<List<Template>> getMostUsedTemplates(String userId, {int limit = 10});
  
  /// Mark template as used (increment usage count)
  Future<void> markAsUsed(String templateId);
  
  /// Get template with exercises
  Future<Template?> findByIdWithExercises(String id);
}

/// Implementation of TemplateRepository using SQLite
class TemplateRepositoryImpl extends BaseRepositoryImpl<Template, String> 
    with RepositoryErrorHandling 
    implements TemplateRepository {
  
  final DatabaseHelper _databaseHelper;
  final Logger _logger = Logger();
  
  TemplateRepositoryImpl(this._databaseHelper);
  
  @override
  String get tableName => 'templates';
  
  @override
  Future<Database> get database => _databaseHelper.database;
  
  @override
  Map<String, dynamic> toMap(Template template) {
    return {
      'id': template.id,
      'user_id': template.userId,
      'name': template.name,
      'description': template.description,
      'is_public': template.isPublic ? 1 : 0,
      'usage_count': template.usageCount,
      'created_at': template.createdAt.millisecondsSinceEpoch,
      'last_used_at': template.lastUsedAt?.millisecondsSinceEpoch,
      'tags': jsonEncode(template.tags),
    };
  }
  
  @override
  Template fromMap(Map<String, dynamic> map) {
    return Template(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      exercises: [], // Will be loaded separately when needed
      isPublic: (map['is_public'] as int) == 1,
      usageCount: map['usage_count'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      lastUsedAt: map['last_used_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['last_used_at'] as int)
          : null,
      tags: List<String>.from(jsonDecode(map['tags'] as String)),
    );
  }
  
  @override
  String getId(Template template) => template.id;
  
  @override
  Future<Template> create(Template template) async {
    return executeWithErrorHandling(() async {
      // Validate template data
      final validation = template.validate();
      if (validation != null) {
        throw RepositoryException('Invalid template data: $validation');
      }
      
      final db = await database;
      
      // Use transaction to ensure consistency
      await db.transaction((txn) async {
        // Insert template
        await txn.insert(tableName, toMap(template));
        
        // Insert template exercises
        for (final exercise in template.exercises) {
          await txn.insert('template_exercises', _exerciseToMap(exercise, template.id));
        }
      });
      
      _logger.d('Created template: ${template.id}');
      return template;
    }, 'create template');
  }
  
  @override
  Future<Template?> findById(String id) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      if (maps.isEmpty) return null;
      
      final template = fromMap(maps.first);
      
      // Load exercises for this template
      final exercises = await _loadTemplateExercises(id);
      return template.copyWith(exercises: exercises);
    }, 'find template by id');
  }
  
  @override
  Future<Template?> findByIdWithExercises(String id) async {
    return findById(id); // Already loads exercises
  }
  
  @override
  Future<List<Template>> findAll() async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(tableName, orderBy: 'created_at DESC');
      
      final templates = <Template>[];
      for (final map in maps) {
        final template = fromMap(map);
        final exercises = await _loadTemplateExercises(template.id);
        templates.add(template.copyWith(exercises: exercises));
      }
      
      return templates;
    }, 'find all templates');
  }
  
  @override
  Future<Template> update(Template template) async {
    return executeWithErrorHandling(() async {
      // Validate template data
      final validation = template.validate();
      if (validation != null) {
        throw RepositoryException('Invalid template data: $validation');
      }
      
      final db = await database;
      
      await db.transaction((txn) async {
        // Update template
        final rowsAffected = await txn.update(
          tableName,
          toMap(template),
          where: 'id = ?',
          whereArgs: [template.id],
        );
        
        if (rowsAffected == 0) {
          throw RepositoryException('Template not found: ${template.id}');
        }
        
        // Delete existing exercises and insert new ones
        await txn.delete(
          'template_exercises',
          where: 'template_id = ?',
          whereArgs: [template.id],
        );
        
        for (final exercise in template.exercises) {
          await txn.insert('template_exercises', _exerciseToMap(exercise, template.id));
        }
      });
      
      _logger.d('Updated template: ${template.id}');
      return template;
    }, 'update template');
  }
  
  @override
  Future<bool> deleteById(String id) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      
      // Template exercises will be deleted automatically due to CASCADE constraint
      final rowsAffected = await db.delete(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      final deleted = rowsAffected > 0;
      if (deleted) {
        _logger.d('Deleted template: $id');
      }
      return deleted;
    }, 'delete template');
  }
  
  @override
  Future<List<Template>> findByUserId(String userId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'last_used_at DESC, created_at DESC',
      );
      
      final templates = <Template>[];
      for (final map in maps) {
        final template = fromMap(map);
        final exercises = await _loadTemplateExercises(template.id);
        templates.add(template.copyWith(exercises: exercises));
      }
      
      return templates;
    }, 'find templates by user id');
  }
  
  @override
  Future<List<Template>> findPublicTemplates() async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'is_public = ?',
        whereArgs: [1],
        orderBy: 'usage_count DESC, created_at DESC',
      );
      
      final templates = <Template>[];
      for (final map in maps) {
        final template = fromMap(map);
        final exercises = await _loadTemplateExercises(template.id);
        templates.add(template.copyWith(exercises: exercises));
      }
      
      return templates;
    }, 'find public templates');
  }
  
  @override
  Future<List<Template>> findByTags(List<String> tags) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      
      // Build query for templates that contain any of the specified tags
      final placeholders = tags.map((_) => '?').join(',');
      final likeConditions = tags.map((_) => 'tags LIKE ?').join(' OR ');
      
      final maps = await db.query(
        tableName,
        where: likeConditions,
        whereArgs: tags.map((tag) => '%"$tag"%').toList(),
        orderBy: 'usage_count DESC, created_at DESC',
      );
      
      final templates = <Template>[];
      for (final map in maps) {
        final template = fromMap(map);
        final exercises = await _loadTemplateExercises(template.id);
        templates.add(template.copyWith(exercises: exercises));
      }
      
      return templates;
    }, 'find templates by tags');
  }
  
  @override
  Future<List<Template>> findByMuscleGroups(List<String> muscleGroupIds) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      
      // Find templates that have exercises targeting the specified muscle groups
      final placeholders = muscleGroupIds.map((_) => '?').join(',');
      final likeConditions = muscleGroupIds.map((_) => 
          'te.primary_muscle_groups LIKE ? OR te.secondary_muscle_groups LIKE ?'
      ).join(' OR ');
      
      final whereArgs = <String>[];
      for (final muscleGroupId in muscleGroupIds) {
        whereArgs.add('%"$muscleGroupId"%');
        whereArgs.add('%"$muscleGroupId"%');
      }
      
      final maps = await db.rawQuery('''
        SELECT DISTINCT t.* FROM templates t
        JOIN template_exercises te ON t.id = te.template_id
        WHERE $likeConditions
        ORDER BY t.usage_count DESC, t.created_at DESC
      ''', whereArgs);
      
      final templates = <Template>[];
      for (final map in maps) {
        final template = fromMap(map);
        final exercises = await _loadTemplateExercises(template.id);
        templates.add(template.copyWith(exercises: exercises));
      }
      
      return templates;
    }, 'find templates by muscle groups');
  }
  
  @override
  Future<List<Template>> searchTemplates(String query, {String? userId}) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      
      String whereClause = 'name LIKE ? OR description LIKE ?';
      List<dynamic> whereArgs = ['%$query%', '%$query%'];
      
      if (userId != null) {
        whereClause += ' AND (user_id = ? OR is_public = 1)';
        whereArgs.add(userId);
      }
      
      final maps = await db.query(
        tableName,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'usage_count DESC, created_at DESC',
      );
      
      final templates = <Template>[];
      for (final map in maps) {
        final template = fromMap(map);
        final exercises = await _loadTemplateExercises(template.id);
        templates.add(template.copyWith(exercises: exercises));
      }
      
      return templates;
    }, 'search templates');
  }
  
  @override
  Future<List<Template>> getMostUsedTemplates(String userId, {int limit = 10}) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final maps = await db.query(
        tableName,
        where: 'user_id = ? AND usage_count > 0',
        whereArgs: [userId],
        orderBy: 'usage_count DESC, last_used_at DESC',
        limit: limit,
      );
      
      final templates = <Template>[];
      for (final map in maps) {
        final template = fromMap(map);
        final exercises = await _loadTemplateExercises(template.id);
        templates.add(template.copyWith(exercises: exercises));
      }
      
      return templates;
    }, 'get most used templates');
  }
  
  @override
  Future<void> markAsUsed(String templateId) async {
    return executeWithErrorHandling(() async {
      final db = await database;
      final rowsAffected = await db.rawUpdate('''
        UPDATE templates 
        SET usage_count = usage_count + 1, 
            last_used_at = ?
        WHERE id = ?
      ''', [DateTime.now().millisecondsSinceEpoch, templateId]);
      
      if (rowsAffected == 0) {
        throw RepositoryException('Template not found: $templateId');
      }
      
      _logger.d('Marked template as used: $templateId');
    }, 'mark template as used');
  }
  
  /// Load template exercises from database
  Future<List<TemplateExercise>> _loadTemplateExercises(String templateId) async {
    final db = await database;
    final maps = await db.query(
      'template_exercises',
      where: 'template_id = ?',
      whereArgs: [templateId],
      orderBy: 'exercise_order ASC',
    );
    
    return maps.map((map) => _exerciseFromMap(map)).toList();
  }
  
  /// Convert TemplateExercise to database map
  Map<String, dynamic> _exerciseToMap(TemplateExercise exercise, String templateId) {
    return {
      'id': '${templateId}_${exercise.exerciseId}_${exercise.order}',
      'template_id': templateId,
      'exercise_id': exercise.exerciseId,
      'sets': exercise.sets,
      'target_reps': exercise.targetReps,
      'rest_seconds': exercise.restSeconds,
      'exercise_order': exercise.order,
      'primary_muscle_groups': jsonEncode(exercise.primaryMuscleGroups),
      'secondary_muscle_groups': jsonEncode(exercise.secondaryMuscleGroups),
      'notes': exercise.notes,
      'target_weight': exercise.targetWeight,
      'is_superset': exercise.isSuperset ? 1 : 0,
      'superset_group': exercise.supersetGroup,
    };
  }
  
  /// Convert database map to TemplateExercise
  TemplateExercise _exerciseFromMap(Map<String, dynamic> map) {
    return TemplateExercise(
      exerciseId: map['exercise_id'] as String,
      sets: map['sets'] as int,
      targetReps: map['target_reps'] as int,
      restSeconds: map['rest_seconds'] as int,
      order: map['exercise_order'] as int,
      primaryMuscleGroups: List<String>.from(jsonDecode(map['primary_muscle_groups'] as String)),
      secondaryMuscleGroups: List<String>.from(jsonDecode(map['secondary_muscle_groups'] as String)),
      notes: map['notes'] as String?,
      targetWeight: map['target_weight'] as double?,
      isSuperset: (map['is_superset'] as int) == 1,
      supersetGroup: map['superset_group'] as String?,
    );
  }
}