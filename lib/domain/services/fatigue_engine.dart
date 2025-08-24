import 'dart:math' as math;
import '../entities/enums.dart';
import '../entities/constants.dart';
import '../entities/exercise.dart';
import '../entities/workout_session.dart';
import '../entities/muscle_group.dart';

/// Engine for calculating fatigue scores and managing fatigue distribution
/// across muscle groups based on workout data
class FatigueEngine {
  /// Calculates fatigue score for a single set
  /// Formula: Volume × IntensityFactor × RPEFactor × MuscleGroupMultiplier
  double calculateSetFatigueScore({
    required WorkoutSet set,
    required Exercise exercise,
    required String muscleGroupId,
  }) {
    // Validate inputs
    if (set.weight <= 0 || set.reps <= 0 || set.rpe < MIN_RPE || set.rpe > MAX_RPE) {
      return 0.0;
    }

    // Calculate volume (weight × reps)
    final volume = set.weight * set.reps;
    
    // Calculate intensity factor based on RPE (maps RPE 6-10 to 0.2-1.0)
    final intensityFactor = math.max(0.0, (set.rpe - 5) / 5.0);
    
    // Calculate RPE factor (RPE / 10)
    final rpeFactor = set.rpe / 10.0;
    
    // Get muscle group multiplier
    final muscleMultiplier = FATIGUE_MULTIPLIERS[muscleGroupId] ?? 1.0;
    
    // Get muscle involvement weight (1.0 for primary, 0.5 for secondary)
    final involvementWeight = exercise.getMuscleGroupInvolvement(muscleGroupId);
    
    return volume * intensityFactor * rpeFactor * muscleMultiplier * involvementWeight;
  }

  /// Calculates total fatigue score for multiple sets of the same exercise
  double calculateExerciseFatigueScore({
    required List<WorkoutSet> sets,
    required Exercise exercise,
    required String muscleGroupId,
  }) {
    if (sets.isEmpty) return 0.0;
    
    return sets.fold(0.0, (total, set) {
      return total + calculateSetFatigueScore(
        set: set,
        exercise: exercise,
        muscleGroupId: muscleGroupId,
      );
    });
  }

  /// Distributes fatigue across all muscle groups involved in a workout session
  /// Returns a map of muscle group ID to total fatigue score
  Map<String, double> distributeFatigueAcrossSession({
    required WorkoutSession session,
    required Map<String, Exercise> exercises,
  }) {
    final fatigueDistribution = <String, double>{};
    
    // Group sets by exercise
    final setsByExercise = <String, List<WorkoutSet>>{};
    for (final set in session.sets) {
      setsByExercise.putIfAbsent(set.exerciseId, () => []).add(set);
    }
    
    // Calculate fatigue for each exercise and distribute to muscle groups
    for (final entry in setsByExercise.entries) {
      final exerciseId = entry.key;
      final exerciseSets = entry.value;
      final exercise = exercises[exerciseId];
      
      if (exercise == null) continue;
      
      // Calculate fatigue for all muscle groups involved in this exercise
      for (final muscleGroupId in exercise.allMuscleGroups) {
        final exerciseFatigue = calculateExerciseFatigueScore(
          sets: exerciseSets,
          exercise: exercise,
          muscleGroupId: muscleGroupId,
        );
        
        fatigueDistribution[muscleGroupId] = 
            (fatigueDistribution[muscleGroupId] ?? 0.0) + exerciseFatigue;
      }
    }
    
    return fatigueDistribution;
  }

  /// Calculates fatigue for a specific muscle group from a workout session
  double calculateMuscleGroupFatigue({
    required WorkoutSession session,
    required Map<String, Exercise> exercises,
    required String muscleGroupId,
  }) {
    double totalFatigue = 0.0;
    
    // Group sets by exercise
    final setsByExercise = <String, List<WorkoutSet>>{};
    for (final set in session.sets) {
      setsByExercise.putIfAbsent(set.exerciseId, () => []).add(set);
    }
    
    // Calculate fatigue contribution from each exercise
    for (final entry in setsByExercise.entries) {
      final exerciseId = entry.key;
      final exerciseSets = entry.value;
      final exercise = exercises[exerciseId];
      
      if (exercise == null || !exercise.targetsMuscleGroup(muscleGroupId)) {
        continue;
      }
      
      totalFatigue += calculateExerciseFatigueScore(
        sets: exerciseSets,
        exercise: exercise,
        muscleGroupId: muscleGroupId,
      );
    }
    
    return totalFatigue;
  }

  /// Calculates weighted fatigue distribution considering primary vs secondary muscle involvement
  Map<String, double> calculateWeightedFatigueDistribution({
    required WorkoutSet set,
    required Exercise exercise,
  }) {
    final distribution = <String, double>{};
    
    // Calculate base fatigue score without muscle-specific multipliers
    final volume = set.weight * set.reps;
    final intensityFactor = math.max(0.0, (set.rpe - 5) / 5.0);
    final rpeFactor = set.rpe / 10.0;
    final baseFatigue = volume * intensityFactor * rpeFactor;
    
    // Distribute to primary muscle groups (full weight)
    for (final muscleGroupId in exercise.primaryMuscleGroups) {
      final muscleMultiplier = FATIGUE_MULTIPLIERS[muscleGroupId] ?? 1.0;
      distribution[muscleGroupId] = baseFatigue * muscleMultiplier * PRIMARY_MUSCLE_WEIGHT;
    }
    
    // Distribute to secondary muscle groups (reduced weight)
    for (final muscleGroupId in exercise.secondaryMuscleGroups) {
      final muscleMultiplier = FATIGUE_MULTIPLIERS[muscleGroupId] ?? 1.0;
      distribution[muscleGroupId] = baseFatigue * muscleMultiplier * SECONDARY_MUSCLE_WEIGHT;
    }
    
    return distribution;
  }

  /// Validates fatigue calculation inputs
  bool validateFatigueInputs({
    required WorkoutSet set,
    required Exercise exercise,
  }) {
    // Validate set data
    if (set.weight <= 0 || set.reps <= 0) return false;
    if (set.rpe < MIN_RPE || set.rpe > MAX_RPE) return false;
    
    // Validate exercise data
    if (exercise.primaryMuscleGroups.isEmpty) return false;
    
    return true;
  }

  /// Calculates session-level fatigue metrics
  SessionFatigueMetrics calculateSessionMetrics({
    required WorkoutSession session,
    required Map<String, Exercise> exercises,
  }) {
    final fatigueDistribution = distributeFatigueAcrossSession(
      session: session,
      exercises: exercises,
    );
    
    final totalFatigue = fatigueDistribution.values.fold(0.0, (a, b) => a + b);
    final averageRPE = session.averageRPE;
    final totalVolume = session.totalVolume;
    final muscleGroupsTargeted = fatigueDistribution.keys.toList();
    
    return SessionFatigueMetrics(
      totalFatigue: totalFatigue,
      fatigueDistribution: fatigueDistribution,
      averageRPE: averageRPE,
      totalVolume: totalVolume,
      muscleGroupsTargeted: muscleGroupsTargeted,
      sessionDuration: session.duration,
    );
  }
}

/// Metrics calculated for a workout session's fatigue impact
class SessionFatigueMetrics {
  final double totalFatigue;
  final Map<String, double> fatigueDistribution;
  final double averageRPE;
  final double totalVolume;
  final List<String> muscleGroupsTargeted;
  final Duration? sessionDuration;

  const SessionFatigueMetrics({
    required this.totalFatigue,
    required this.fatigueDistribution,
    required this.averageRPE,
    required this.totalVolume,
    required this.muscleGroupsTargeted,
    this.sessionDuration,
  });

  /// Gets the muscle group with highest fatigue
  String? get mostFatiguedMuscleGroup {
    if (fatigueDistribution.isEmpty) return null;
    
    return fatigueDistribution.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Gets the fatigue score for a specific muscle group
  double getFatigueForMuscleGroup(String muscleGroupId) {
    return fatigueDistribution[muscleGroupId] ?? 0.0;
  }

  /// Checks if the session targeted a specific muscle group
  bool targetedMuscleGroup(String muscleGroupId) {
    return muscleGroupsTargeted.contains(muscleGroupId);
  }

  @override
  String toString() {
    return 'SessionFatigueMetrics('
        'totalFatigue: ${totalFatigue.toStringAsFixed(2)}, '
        'averageRPE: ${averageRPE.toStringAsFixed(1)}, '
        'totalVolume: ${totalVolume.toStringAsFixed(1)}, '
        'muscleGroups: ${muscleGroupsTargeted.length}'
        ')';
  }
}