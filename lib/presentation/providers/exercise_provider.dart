import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/exercise.dart';
import '../../domain/entities/enums.dart';
import '../../core/providers/providers.dart';

/// Provider for all exercises
final exercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final repository = ref.watch(exerciseRepositoryProvider);
  return repository.findAll();
});

/// Provider for exercise list (alias for exercisesProvider for consistency)
final exerciseListProvider = exercisesProvider;

/// Provider for a single exercise by ID
final exerciseProvider = FutureProvider.family<Exercise?, String>((ref, exerciseId) async {
  final repository = ref.watch(exerciseRepositoryProvider);
  return repository.findById(exerciseId);
});

/// Provider for searching exercises by name
final exerciseSearchProvider = FutureProvider.family<List<Exercise>, Map<String, String>>((ref, params) async {
  final repository = ref.watch(exerciseRepositoryProvider);
  final query = params['query'] ?? '';
  final locale = params['locale'] ?? 'en';
  
  if (query.isEmpty) {
    return repository.findAll();
  }
  
  return repository.searchByName(query, locale: locale);
});

/// Provider for exercises by category
final exercisesByCategoryProvider = FutureProvider.family<List<Exercise>, String>((ref, category) async {
  final repository = ref.watch(exerciseRepositoryProvider);
  return repository.findByCategory(category);
});

/// Provider for exercises by muscle group
final exercisesByMuscleGroupProvider = FutureProvider.family<List<Exercise>, String>((ref, muscleGroupId) async {
  final repository = ref.watch(exerciseRepositoryProvider);
  return repository.findByMuscleGroup(muscleGroupId);
});

/// Provider for compound exercises
final compoundExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final repository = ref.watch(exerciseRepositoryProvider);
  return repository.findCompoundExercises();
});

/// Provider for exercise usage statistics
final exerciseUsageStatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(exerciseRepositoryProvider);
  return repository.getExerciseUsageStats();
});

/// Provider for recent exercises (most frequently used)
final recentExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final repository = ref.watch(exerciseRepositoryProvider);
  final stats = await repository.getExerciseUsageStats();
  
  if (stats.isEmpty) return [];
  
  // Get the top 8 most used exercises
  final recentIds = stats.take(8).map((stat) => stat['exerciseId'] as String).toList();
  
  // Load the actual exercise objects
  final exercises = await Future.wait(
    recentIds.map((id) => repository.findById(id))
  );
  
  return exercises.whereType<Exercise>().toList();
});

/// Provider for quick access exercises (favorites + recent)
final quickAccessExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final repository = ref.watch(exerciseRepositoryProvider);
  
  // Get compound exercises (typically more important)
  final compoundExercises = await repository.findCompoundExercises();
  
  // Get recent exercises
  final recentExercises = await ref.watch(recentExercisesProvider.future);
  
  // Combine and deduplicate
  final allExercises = <String, Exercise>{};
  
  // Add compound exercises first
  for (final exercise in compoundExercises.take(4)) {
    allExercises[exercise.id] = exercise;
  }
  
  // Add recent exercises
  for (final exercise in recentExercises.take(6)) {
    allExercises[exercise.id] = exercise;
  }
  
  return allExercises.values.toList();
});