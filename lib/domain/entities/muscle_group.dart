import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';
import 'constants.dart';

part 'muscle_group.freezed.dart';
part 'muscle_group.g.dart';

@freezed
class MuscleGroup with _$MuscleGroup {
  const factory MuscleGroup({
    required String id,
    required Map<String, String> names, // {'en': 'Chest', 'ja': '胸筋'}
    required double recoveryTau, // Recovery time constant in hours
    required double fatigueMultiplier,
    required String bodyRegion,
  }) = _MuscleGroup;

  const MuscleGroup._();

  factory MuscleGroup.fromJson(Map<String, dynamic> json) => 
      _$MuscleGroupFromJson(json);

  /// Gets localized name for the muscle group
  String getLocalizedName(String locale) {
    return names[locale] ?? names['en'] ?? id;
  }

  /// Validates muscle group data
  String? validate() {
    if (id.isEmpty) return 'Muscle group ID cannot be empty';
    if (names.isEmpty) return 'Muscle group must have at least one name';
    if (!names.containsKey('en')) return 'Muscle group must have English name';
    if (recoveryTau <= 0) return 'Recovery tau must be positive';
    if (fatigueMultiplier <= 0) return 'Fatigue multiplier must be positive';
    if (bodyRegion.isEmpty) return 'Body region cannot be empty';
    return null;
  }

  /// Checks if the muscle group data is valid
  bool get isValid => validate() == null;

  /// Calculates recovery percentage based on time elapsed
  double calculateRecoveryPercentage(Duration timeSinceWorkout) {
    final hoursElapsed = timeSinceWorkout.inMilliseconds / (1000 * 60 * 60);
    return 1.0 - (1.0 / (1.0 + (hoursElapsed / recoveryTau)));
  }

  /// Calculates current fatigue based on initial fatigue and time elapsed
  double calculateCurrentFatigue(double initialFatigue, Duration timeSinceWorkout) {
    final hoursElapsed = timeSinceWorkout.inMilliseconds / (1000 * 60 * 60);
    return initialFatigue * (1.0 / (1.0 + (hoursElapsed / recoveryTau)));
  }

  /// Gets readiness level based on current fatigue
  ReadinessLevel getReadinessLevel(double currentFatigue) {
    return ReadinessLevel.fromFatigueScore(currentFatigue);
  }

  /// Creates a muscle group with default values from constants
  factory MuscleGroup.withDefaults({
    required String id,
    required Map<String, String> names,
    required String bodyRegion,
  }) {
    return MuscleGroup(
      id: id,
      names: names,
      recoveryTau: RECOVERY_TAU[id] ?? 48.0,
      fatigueMultiplier: FATIGUE_MULTIPLIERS[id] ?? 1.0,
      bodyRegion: bodyRegion,
    );
  }
}