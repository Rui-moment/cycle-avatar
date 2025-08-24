import 'dart:math' as math;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';

part 'avatar_state.freezed.dart';
part 'avatar_state.g.dart';

@freezed
class AvatarState with _$AvatarState {
  const factory AvatarState({
    required String id,
    required String userId,
    required Map<String, int> muscleGroupLevels, // muscle_group_id -> level
    required Map<String, double> growthPoints, // muscle_group_id -> points
    required double totalGrowthPoints,
    DateTime? lastLevelUp,
    @Default([]) List<String> unlockedBadges,
    @Default({}) Map<String, DateTime> cooldownUntil, // muscle_group_id -> cooldown_end
  }) = _AvatarState;

  const AvatarState._();

  factory AvatarState.fromJson(Map<String, dynamic> json) => 
      _$AvatarStateFromJson(json);

  /// Validates avatar state data
  String? validate() {
    if (id.isEmpty) return 'Avatar state ID cannot be empty';
    if (userId.isEmpty) return 'User ID cannot be empty';
    
    // Validate muscle group levels are non-negative
    for (final entry in muscleGroupLevels.entries) {
      if (entry.key.isEmpty) return 'Muscle group ID cannot be empty';
      if (entry.value < 0) return 'Muscle group level cannot be negative';
    }
    
    // Validate growth points are non-negative
    for (final entry in growthPoints.entries) {
      if (entry.key.isEmpty) return 'Muscle group ID cannot be empty';
      if (entry.value < 0) return 'Growth points cannot be negative';
    }
    
    if (totalGrowthPoints < 0) return 'Total growth points cannot be negative';
    
    return null;
  }

  /// Checks if the avatar state data is valid
  bool get isValid => validate() == null;

  /// Gets the level for a specific muscle group
  int getLevelForMuscleGroup(String muscleGroupId) {
    return muscleGroupLevels[muscleGroupId] ?? 0;
  }

  /// Gets the growth points for a specific muscle group
  double getGrowthPointsForMuscleGroup(String muscleGroupId) {
    return growthPoints[muscleGroupId] ?? 0.0;
  }

  /// Gets the overall avatar level (average of all muscle groups)
  double get overallLevel {
    if (muscleGroupLevels.isEmpty) return 0.0;
    final totalLevels = muscleGroupLevels.values.fold(0, (sum, level) => sum + level);
    return totalLevels / muscleGroupLevels.length;
  }

  /// Gets the highest level among all muscle groups
  int get maxLevel {
    if (muscleGroupLevels.isEmpty) return 0;
    return muscleGroupLevels.values.reduce((a, b) => a > b ? a : b);
  }

  /// Checks if a muscle group is in cooldown
  bool isMuscleGroupInCooldown(String muscleGroupId) {
    final cooldownEnd = cooldownUntil[muscleGroupId];
    if (cooldownEnd == null) return false;
    return DateTime.now().isBefore(cooldownEnd);
  }

  /// Gets remaining cooldown time for a muscle group
  Duration? getCooldownRemaining(String muscleGroupId) {
    final cooldownEnd = cooldownUntil[muscleGroupId];
    if (cooldownEnd == null) return null;
    final remaining = cooldownEnd.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Calculates points needed for next level for a muscle group
  double getPointsNeededForNextLevel(String muscleGroupId) {
    final currentLevel = getLevelForMuscleGroup(muscleGroupId);
    final currentPoints = getGrowthPointsForMuscleGroup(muscleGroupId);
    final pointsForNextLevel = _calculatePointsForLevel(currentLevel + 1);
    return (pointsForNextLevel - currentPoints).clamp(0.0, double.infinity);
  }

  /// Calculates progress percentage to next level for a muscle group
  double getProgressToNextLevel(String muscleGroupId) {
    final currentLevel = getLevelForMuscleGroup(muscleGroupId);
    final currentPoints = getGrowthPointsForMuscleGroup(muscleGroupId);
    final pointsForCurrentLevel = _calculatePointsForLevel(currentLevel);
    final pointsForNextLevel = _calculatePointsForLevel(currentLevel + 1);
    
    if (pointsForNextLevel == pointsForCurrentLevel) return 1.0;
    
    final progress = (currentPoints - pointsForCurrentLevel) / 
                    (pointsForNextLevel - pointsForCurrentLevel);
    return progress.clamp(0.0, 1.0);
  }

  /// Adds growth points to a muscle group
  AvatarState addGrowthPoints({
    required String muscleGroupId,
    required double points,
    bool applyPenalty = false,
  }) {
    final adjustedPoints = applyPenalty ? points * 0.5 : points;
    final currentPoints = getGrowthPointsForMuscleGroup(muscleGroupId);
    final newPoints = currentPoints + adjustedPoints;
    final currentLevel = getLevelForMuscleGroup(muscleGroupId);
    
    // Check if level up occurs
    final newLevel = _calculateLevelFromPoints(newPoints);
    final leveledUp = newLevel > currentLevel;
    
    return copyWith(
      growthPoints: {...growthPoints, muscleGroupId: newPoints},
      muscleGroupLevels: {...muscleGroupLevels, muscleGroupId: newLevel},
      totalGrowthPoints: totalGrowthPoints + adjustedPoints,
      lastLevelUp: leveledUp ? DateTime.now() : lastLevelUp,
    );
  }

  /// Applies cooldown to a muscle group
  AvatarState applyCooldown({
    required String muscleGroupId,
    required Duration cooldownDuration,
  }) {
    final cooldownEnd = DateTime.now().add(cooldownDuration);
    return copyWith(
      cooldownUntil: {...cooldownUntil, muscleGroupId: cooldownEnd},
    );
  }

  /// Unlocks a new badge
  AvatarState unlockBadge(String badgeId) {
    if (unlockedBadges.contains(badgeId)) return this;
    return copyWith(unlockedBadges: [...unlockedBadges, badgeId]);
  }

  /// Calculates points required for a specific level
  double _calculatePointsForLevel(int level) {
    if (level <= 0) return 0.0;
    // Exponential growth: level^2 * 100
    return level * level * 100.0;
  }

  /// Calculates level from total points
  int _calculateLevelFromPoints(double points) {
    if (points <= 0) return 0;
    // Inverse of exponential growth: sqrt(points/100)
    return math.sqrt(points / 100.0).floor();
  }

  /// Calculates growth points to award based on progression and readiness
  static double calculateGrowthPoints({
    required bool achievedProgression,
    required ReadinessLevel preWorkoutReadiness,
    double basePoints = 10.0,
  }) {
    if (!achievedProgression) return 0.0;
    
    switch (preWorkoutReadiness) {
      case ReadinessLevel.ready:
        return basePoints * 1.5; // Optimal recovery bonus
      case ReadinessLevel.warm:
        return basePoints;
      case ReadinessLevel.fatigued:
        return basePoints * 0.5; // Overtraining penalty
    }
  }

  /// Checks if any muscle group has leveled up recently (within 24 hours)
  bool get hasRecentLevelUp {
    if (lastLevelUp == null) return false;
    return DateTime.now().difference(lastLevelUp!).inHours <= 24;
  }

  /// Gets all muscle groups that are currently in cooldown
  List<String> get muscleGroupsInCooldown {
    final now = DateTime.now();
    return cooldownUntil.entries
        .where((entry) => now.isBefore(entry.value))
        .map((entry) => entry.key)
        .toList();
  }

  /// Creates a fresh avatar state for a new user
  factory AvatarState.fresh({
    required String id,
    required String userId,
    required List<String> muscleGroupIds,
  }) {
    final muscleGroupLevels = <String, int>{};
    final growthPoints = <String, double>{};
    
    for (final muscleGroupId in muscleGroupIds) {
      muscleGroupLevels[muscleGroupId] = 0;
      growthPoints[muscleGroupId] = 0.0;
    }
    
    return AvatarState(
      id: id,
      userId: userId,
      muscleGroupLevels: muscleGroupLevels,
      growthPoints: growthPoints,
      totalGrowthPoints: 0.0,
    );
  }
}