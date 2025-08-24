import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';

part 'exercise.freezed.dart';
part 'exercise.g.dart';

@freezed
class Exercise with _$Exercise {
  const factory Exercise({
    required String id,
    required Map<String, String> names, // {'en': 'Squat', 'ja': 'スクワット'}
    required String category,
    required EquipmentType equipment,
    required Map<String, String> instructions,
    required List<String> primaryMuscleGroups,
    required List<String> secondaryMuscleGroups,
    @Default(false) bool isCompound,
    required DateTime createdAt,
  }) = _Exercise;

  const Exercise._();

  factory Exercise.fromJson(Map<String, dynamic> json) => 
      _$ExerciseFromJson(json);

  /// Gets localized name for the exercise
  String getLocalizedName(String locale) {
    return names[locale] ?? names['en'] ?? id;
  }

  /// Gets localized instructions
  String getLocalizedInstructions(String locale) {
    return instructions[locale] ?? instructions['en'] ?? '';
  }

  /// Validates exercise data
  String? validate() {
    if (id.isEmpty) return 'Exercise ID cannot be empty';
    if (names.isEmpty) return 'Exercise must have at least one name';
    if (!names.containsKey('en')) return 'Exercise must have English name';
    if (category.isEmpty) return 'Category cannot be empty';
    if (primaryMuscleGroups.isEmpty) return 'Must have at least one primary muscle group';
    
    // Validate muscle group IDs are not empty
    for (final muscleGroup in primaryMuscleGroups) {
      if (muscleGroup.isEmpty) return 'Primary muscle group ID cannot be empty';
    }
    for (final muscleGroup in secondaryMuscleGroups) {
      if (muscleGroup.isEmpty) return 'Secondary muscle group ID cannot be empty';
    }
    
    return null;
  }

  /// Checks if the exercise data is valid
  bool get isValid => validate() == null;

  /// Gets all muscle groups involved (primary + secondary)
  List<String> get allMuscleGroups => [
    ...primaryMuscleGroups,
    ...secondaryMuscleGroups,
  ];

  /// Checks if this exercise targets a specific muscle group
  bool targetsMuscleGroup(String muscleGroupId) {
    return primaryMuscleGroups.contains(muscleGroupId) ||
           secondaryMuscleGroups.contains(muscleGroupId);
  }

  /// Gets the involvement level of a muscle group (1.0 for primary, 0.5 for secondary, 0.0 for none)
  double getMuscleGroupInvolvement(String muscleGroupId) {
    if (primaryMuscleGroups.contains(muscleGroupId)) return 1.0;
    if (secondaryMuscleGroups.contains(muscleGroupId)) return 0.5;
    return 0.0;
  }
}