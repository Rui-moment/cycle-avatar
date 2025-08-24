import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/exercise.dart';
import '../../domain/entities/muscle_group.dart';
import '../../domain/entities/enums.dart';
import '../constants/multilingual_data.dart';
import 'localization_service.dart';

/// Service for providing localized names for exercises and muscle groups
class LocalizedNamesService {
  final String _currentLocale;
  
  LocalizedNamesService(this._currentLocale);
  
  /// Get localized muscle group name
  String getMuscleGroupName(String muscleGroupId) {
    return MultilingualData.getMuscleGroupName(muscleGroupId, _currentLocale);
  }
  
  /// Get localized muscle group name from MuscleGroup entity
  String getMuscleGroupNameFromEntity(MuscleGroup muscleGroup) {
    return muscleGroup.getLocalizedName(_currentLocale);
  }
  
  /// Get localized exercise name
  String getExerciseName(String exerciseId) {
    return MultilingualData.getExerciseName(exerciseId, _currentLocale);
  }
  
  /// Get localized exercise name from Exercise entity
  String getExerciseNameFromEntity(Exercise exercise) {
    return exercise.getLocalizedName(_currentLocale);
  }
  
  /// Get localized exercise instructions
  String getExerciseInstructions(String exerciseId) {
    return MultilingualData.getExerciseInstructions(exerciseId, _currentLocale);
  }
  
  /// Get localized exercise instructions from Exercise entity
  String getExerciseInstructionsFromEntity(Exercise exercise) {
    return exercise.getLocalizedInstructions(_currentLocale);
  }
  
  /// Get localized equipment name
  String getEquipmentName(EquipmentType equipment) {
    return MultilingualData.getEquipmentName(equipment, _currentLocale);
  }
  
  /// Get localized body region name
  String getBodyRegionName(String regionId) {
    return MultilingualData.getBodyRegionName(regionId, _currentLocale);
  }
  
  /// Get localized exercise category name
  String getExerciseCategoryName(String categoryId) {
    return MultilingualData.getExerciseCategoryName(categoryId, _currentLocale);
  }
  
  /// Get localized readiness level name
  String getReadinessLevelName(ReadinessLevel level) {
    switch (level) {
      case ReadinessLevel.ready:
        return _currentLocale == 'ja' ? '準備完了' : 'Ready';
      case ReadinessLevel.warm:
        return _currentLocale == 'ja' ? 'ウォーミング' : 'Warm';
      case ReadinessLevel.fatigued:
        return _currentLocale == 'ja' ? '疲労' : 'Fatigued';
    }
  }
  
  /// Get localized training goal name
  String getTrainingGoalName(TrainingGoal goal) {
    switch (goal) {
      case TrainingGoal.hypertrophy:
        return _currentLocale == 'ja' ? '筋肥大' : 'Hypertrophy';
      case TrainingGoal.strength:
        return _currentLocale == 'ja' ? '筋力' : 'Strength';
      case TrainingGoal.general:
        return _currentLocale == 'ja' ? '一般' : 'General';
    }
  }
  
  /// Get all available muscle groups with localized names
  List<MapEntry<String, String>> getAllMuscleGroups() {
    return MUSCLE_GROUP_NAMES.entries
        .map((entry) => MapEntry(
              entry.key,
              entry.value[_currentLocale] ?? entry.value['en'] ?? entry.key,
            ))
        .toList();
  }
  
  /// Get all available exercises with localized names
  List<MapEntry<String, String>> getAllExercises() {
    return EXERCISE_NAMES.entries
        .map((entry) => MapEntry(
              entry.key,
              entry.value[_currentLocale] ?? entry.value['en'] ?? entry.key,
            ))
        .toList();
  }
  
  /// Search exercises by localized name
  List<MapEntry<String, String>> searchExercises(String query) {
    if (query.isEmpty) return getAllExercises();
    
    final lowercaseQuery = query.toLowerCase();
    return getAllExercises()
        .where((entry) => entry.value.toLowerCase().contains(lowercaseQuery))
        .toList();
  }
  
  /// Search muscle groups by localized name
  List<MapEntry<String, String>> searchMuscleGroups(String query) {
    if (query.isEmpty) return getAllMuscleGroups();
    
    final lowercaseQuery = query.toLowerCase();
    return getAllMuscleGroups()
        .where((entry) => entry.value.toLowerCase().contains(lowercaseQuery))
        .toList();
  }
  
  /// Get muscle groups by body region with localized names
  List<MapEntry<String, String>> getMuscleGroupsByRegion(String regionId) {
    // This would need to be implemented based on the body region mapping
    // For now, return all muscle groups
    return getAllMuscleGroups();
  }
  
  /// Get exercises by category with localized names
  List<MapEntry<String, String>> getExercisesByCategory(String categoryId) {
    // This would need to be implemented based on exercise-category mapping
    // For now, return all exercises
    return getAllExercises();
  }
  
  /// Get exercises by equipment type with localized names
  List<MapEntry<String, String>> getExercisesByEquipment(EquipmentType equipment) {
    // This would need to be implemented based on exercise-equipment mapping
    // For now, return all exercises
    return getAllExercises();
  }
}

/// Provider for LocalizedNamesService that updates with locale changes
final localizedNamesServiceProvider = Provider<LocalizedNamesService>((ref) {
  final currentLocale = ref.watch(localeProvider);
  return LocalizedNamesService(currentLocale.languageCode);
});

/// Extension methods for easy access to localized names
extension LocalizedExercise on Exercise {
  String localizedName(WidgetRef ref) {
    final service = ref.read(localizedNamesServiceProvider);
    return service.getExerciseNameFromEntity(this);
  }
  
  String localizedInstructions(WidgetRef ref) {
    final service = ref.read(localizedNamesServiceProvider);
    return service.getExerciseInstructionsFromEntity(this);
  }
}

extension LocalizedMuscleGroup on MuscleGroup {
  String localizedName(WidgetRef ref) {
    final service = ref.read(localizedNamesServiceProvider);
    return service.getMuscleGroupNameFromEntity(this);
  }
}

extension LocalizedEquipmentType on EquipmentType {
  String localizedName(WidgetRef ref) {
    final service = ref.read(localizedNamesServiceProvider);
    return service.getEquipmentName(this);
  }
}

extension LocalizedReadinessLevel on ReadinessLevel {
  String localizedName(WidgetRef ref) {
    final service = ref.read(localizedNamesServiceProvider);
    return service.getReadinessLevelName(this);
  }
}

extension LocalizedTrainingGoal on TrainingGoal {
  String localizedName(WidgetRef ref) {
    final service = ref.read(localizedNamesServiceProvider);
    return service.getTrainingGoalName(this);
  }
}