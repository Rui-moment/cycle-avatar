import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';

part 'template.freezed.dart';
part 'template.g.dart';

@freezed
class Template with _$Template {
  const factory Template({
    required String id,
    required String userId,
    required String name,
    required String description,
    required List<TemplateExercise> exercises,
    @Default(false) bool isPublic,
    @Default(0) int usageCount, // How many times this template has been used
    required DateTime createdAt,
    DateTime? lastUsedAt,
    @Default([]) List<String> tags, // Tags for categorization
  }) = _Template;

  const Template._();

  factory Template.fromJson(Map<String, dynamic> json) => 
      _$TemplateFromJson(json);

  /// Validates template data
  String? validate() {
    if (id.isEmpty) return 'Template ID cannot be empty';
    if (userId.isEmpty) return 'User ID cannot be empty';
    if (name.isEmpty) return 'Template name cannot be empty';
    if (name.length > 100) return 'Template name too long (max 100 characters)';
    if (description.length > 500) return 'Description too long (max 500 characters)';
    if (exercises.isEmpty) return 'Template must have at least one exercise';
    
    // Validate exercises
    for (int i = 0; i < exercises.length; i++) {
      final exerciseValidation = exercises[i].validate();
      if (exerciseValidation != null) {
        return 'Exercise ${i + 1}: $exerciseValidation';
      }
    }
    
    return null;
  }

  /// Checks if the template data is valid
  bool get isValid => validate() == null;

  /// Gets the total number of exercises in the template
  int get totalExercises => exercises.length;

  /// Gets the estimated duration of the template in minutes
  int get estimatedDurationMinutes {
    int totalSets = exercises.fold(0, (sum, ex) => sum + ex.sets);
    int totalRestTime = exercises.fold(0, (sum, ex) => sum + (ex.restSeconds * ex.sets));
    int workTime = totalSets * 60; // Assume 1 minute per set for work
    return (workTime + totalRestTime) ~/ 60;
  }

  /// Gets unique muscle groups targeted by this template
  Set<String> get targetedMuscleGroups {
    final muscleGroups = <String>{};
    for (final exercise in exercises) {
      muscleGroups.addAll(exercise.primaryMuscleGroups);
      muscleGroups.addAll(exercise.secondaryMuscleGroups);
    }
    return muscleGroups;
  }

  /// Checks if the template targets a specific muscle group
  bool targetsMuscleGroup(String muscleGroupId) {
    return targetedMuscleGroups.contains(muscleGroupId);
  }

  /// Gets exercises that target a specific muscle group
  List<TemplateExercise> getExercisesForMuscleGroup(String muscleGroupId) {
    return exercises.where((ex) => 
      ex.primaryMuscleGroups.contains(muscleGroupId) ||
      ex.secondaryMuscleGroups.contains(muscleGroupId)
    ).toList();
  }

  /// Marks the template as used
  Template markAsUsed() {
    return copyWith(
      usageCount: usageCount + 1,
      lastUsedAt: DateTime.now(),
    );
  }

  /// Adds a tag to the template
  Template addTag(String tag) {
    if (tags.contains(tag)) return this;
    return copyWith(tags: [...tags, tag]);
  }

  /// Removes a tag from the template
  Template removeTag(String tag) {
    return copyWith(tags: tags.where((t) => t != tag).toList());
  }

  /// Creates a copy of the template for another user
  Template copyForUser({
    required String newId,
    required String newUserId,
    String? newName,
  }) {
    return copyWith(
      id: newId,
      userId: newUserId,
      name: newName ?? '$name (Copy)',
      isPublic: false,
      usageCount: 0,
      createdAt: DateTime.now(),
      lastUsedAt: null,
    );
  }

  /// Calculates the total volume if all exercises have target weights
  double? get totalVolume {
    double? total;
    for (final exercise in exercises) {
      final exerciseVolume = exercise.totalVolume;
      if (exerciseVolume == null) return null; // Can't calculate if any exercise lacks target weight
      total = (total ?? 0) + exerciseVolume;
    }
    return total;
  }

  /// Gets the workout split type based on muscle groups
  String get workoutSplit {
    final muscleGroups = targetedMuscleGroups;
    
    if (muscleGroups.contains('chest') && muscleGroups.contains('back')) {
      return 'Full Body';
    } else if (muscleGroups.contains('chest') || muscleGroups.contains('shoulders') || muscleGroups.contains('triceps')) {
      if (muscleGroups.contains('back') || muscleGroups.contains('biceps')) {
        return 'Upper Body';
      } else {
        return 'Push';
      }
    } else if (muscleGroups.contains('back') || muscleGroups.contains('biceps')) {
      return 'Pull';
    } else if (muscleGroups.contains('quadriceps') || muscleGroups.contains('hamstrings') || muscleGroups.contains('glutes')) {
      return 'Lower Body';
    }
    
    return 'Custom';
  }

  /// Checks if the template is suitable for a specific training goal
  bool isSuitableForGoal(TrainingGoal goal) {
    final avgReps = exercises.isEmpty ? 0 : 
        exercises.map((e) => e.targetReps).reduce((a, b) => a + b) / exercises.length;
    
    switch (goal) {
      case TrainingGoal.strength:
        return avgReps <= 5;
      case TrainingGoal.hypertrophy:
        return avgReps >= 6 && avgReps <= 12;
      case TrainingGoal.general:
        return true; // General goal accepts any rep range
    }
  }
}

@freezed
class TemplateExercise with _$TemplateExercise {
  const factory TemplateExercise({
    required String exerciseId,
    required int sets,
    required int targetReps,
    required int restSeconds,
    required int order, // Order within the template
    required List<String> primaryMuscleGroups,
    required List<String> secondaryMuscleGroups,
    String? notes,
    double? targetWeight, // Optional target weight
    @Default(false) bool isSuperset, // Whether this exercise is part of a superset
    String? supersetGroup, // Identifier for superset grouping
  }) = _TemplateExercise;

  const TemplateExercise._();

  factory TemplateExercise.fromJson(Map<String, dynamic> json) => 
      _$TemplateExerciseFromJson(json);

  /// Validates template exercise data
  String? validate() {
    if (exerciseId.isEmpty) return 'Exercise ID cannot be empty';
    if (sets <= 0) return 'Sets must be positive';
    if (sets > 20) return 'Sets seems unreasonably high (>20)';
    if (targetReps <= 0) return 'Target reps must be positive';
    if (targetReps > 100) return 'Target reps seems unreasonably high (>100)';
    if (restSeconds < 0) return 'Rest seconds cannot be negative';
    if (restSeconds > 3600) return 'Rest time seems unreasonably long (>1 hour)';
    if (order < 0) return 'Order cannot be negative';
    if (primaryMuscleGroups.isEmpty) return 'Must have at least one primary muscle group';
    if (targetWeight != null && targetWeight! < 0) return 'Target weight cannot be negative';
    
    return null;
  }

  /// Checks if the template exercise data is valid
  bool get isValid => validate() == null;

  /// Gets the total volume if target weight is specified
  double? get totalVolume {
    if (targetWeight == null) return null;
    return targetWeight! * targetReps * sets;
  }

  /// Gets the estimated time for this exercise in seconds
  int get estimatedTimeSeconds {
    return (sets * 60) + (restSeconds * (sets - 1)); // 1 min per set + rest between sets
  }

  /// Checks if this exercise targets a specific muscle group
  bool targetsMuscleGroup(String muscleGroupId) {
    return primaryMuscleGroups.contains(muscleGroupId) ||
           secondaryMuscleGroups.contains(muscleGroupId);
  }

  /// Gets all muscle groups involved (primary + secondary)
  List<String> get allMuscleGroups => [
    ...primaryMuscleGroups,
    ...secondaryMuscleGroups,
  ];
}