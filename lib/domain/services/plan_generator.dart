import 'dart:math' as math;
import '../entities/enums.dart';
import '../entities/constants.dart';
import '../entities/workout_session.dart';
import '../entities/exercise.dart';
import '../entities/recovery_state.dart';

/// Service for generating smart workout plans based on recovery status and training goals
class PlanGenerator {
  /// Generates next workout session recommendation based on recovery state and goals
  WorkoutPlan generateNextSession({
    required Map<String, ReadinessLevel> muscleGroupReadiness,
    required TrainingGoal goal,
    required List<WorkoutSession> recentSessions,
    required Map<String, Exercise> availableExercises,
    String? preferredSplit,
  }) {
    // Check if deload is needed first
    if (shouldDeload(recentSessions: recentSessions)) {
      return _generateDeloadPlan(
        muscleGroupReadiness: muscleGroupReadiness,
        availableExercises: availableExercises,
      );
    }

    // Get ready muscle groups
    final readyMuscleGroups = muscleGroupReadiness.entries
        .where((entry) => entry.value == ReadinessLevel.ready)
        .map((entry) => entry.key)
        .toList();

    // If no muscle groups are ready, suggest rest day
    if (readyMuscleGroups.isEmpty) {
      return WorkoutPlan.restDay(
        reason: 'All muscle groups need more recovery time',
        nextRecommendedTime: _estimateNextReadyTime(muscleGroupReadiness),
      );
    }

    // Generate plan based on training goal
    return _generatePlanForGoal(
      goal: goal,
      readyMuscleGroups: readyMuscleGroups,
      recentSessions: recentSessions,
      availableExercises: availableExercises,
      preferredSplit: preferredSplit,
    );
  }

  /// Determines if a deload week should be recommended
  bool shouldDeload({
    required List<WorkoutSession> recentSessions,
    Map<String, double>? currentFatigue,
  }) {
    if (recentSessions.length < 8) return false; // Need at least 2 weeks of data

    // Calculate 4-week volume increase
    final volumeIncrease = _calculateVolumeIncrease(recentSessions);
    
    // Check for chronic high fatigue
    final highFatigueGroups = _countHighFatigueGroups(currentFatigue ?? {});
    
    // Deload conditions - either condition can trigger deload
    final volumeCondition = volumeIncrease > VOLUME_INCREASE_THRESHOLD;
    final fatigueCondition = highFatigueGroups >= HIGH_FATIGUE_GROUPS_THRESHOLD;
    
    return volumeCondition || fatigueCondition;
  }

  /// Generates workout plan for specific training goal
  WorkoutPlan _generatePlanForGoal({
    required TrainingGoal goal,
    required List<String> readyMuscleGroups,
    required List<WorkoutSession> recentSessions,
    required Map<String, Exercise> availableExercises,
    String? preferredSplit,
  }) {
    switch (goal) {
      case TrainingGoal.hypertrophy:
        return _generateHypertrophyPlan(
          readyMuscleGroups: readyMuscleGroups,
          recentSessions: recentSessions,
          availableExercises: availableExercises,
          preferredSplit: preferredSplit,
        );
      case TrainingGoal.strength:
        return _generateStrengthPlan(
          readyMuscleGroups: readyMuscleGroups,
          recentSessions: recentSessions,
          availableExercises: availableExercises,
          preferredSplit: preferredSplit,
        );
      case TrainingGoal.general:
        return _generateGeneralPlan(
          readyMuscleGroups: readyMuscleGroups,
          recentSessions: recentSessions,
          availableExercises: availableExercises,
          preferredSplit: preferredSplit,
        );
    }
  }

  /// Generates hypertrophy-focused workout plan (8-12 rep range)
  WorkoutPlan _generateHypertrophyPlan({
    required List<String> readyMuscleGroups,
    required List<WorkoutSession> recentSessions,
    required Map<String, Exercise> availableExercises,
    String? preferredSplit,
  }) {
    final exercises = _selectExercisesForMuscleGroups(
      muscleGroups: readyMuscleGroups,
      availableExercises: availableExercises,
      recentSessions: recentSessions,
      preferCompound: true,
    );

    final recommendations = exercises.map((exercise) {
      return ExerciseRecommendation(
        exercise: exercise,
        sets: _calculateSetsForHypertrophy(exercise, recentSessions),
        repRange: const RepRange(min: 8, max: 12),
        rpeRange: const RPERange(min: 7, max: 9),
        restSeconds: _calculateRestForHypertrophy(exercise),
        notes: 'Focus on controlled tempo and muscle connection',
      );
    }).toList();

    return WorkoutPlan(
      sessionType: SessionType.hypertrophy,
      targetMuscleGroups: readyMuscleGroups,
      exercises: recommendations,
      estimatedDuration: _estimateSessionDuration(recommendations),
      reasoning: 'Hypertrophy focus: moderate weight, higher volume, controlled tempo',
    );
  }

  /// Generates strength-focused workout plan (1-5 rep range)
  WorkoutPlan _generateStrengthPlan({
    required List<String> readyMuscleGroups,
    required List<WorkoutSession> recentSessions,
    required Map<String, Exercise> availableExercises,
    String? preferredSplit,
  }) {
    final exercises = _selectExercisesForMuscleGroups(
      muscleGroups: readyMuscleGroups,
      availableExercises: availableExercises,
      recentSessions: recentSessions,
      preferCompound: true,
      maxExercises: 4, // Fewer exercises for strength focus
    );

    final recommendations = exercises.map((exercise) {
      return ExerciseRecommendation(
        exercise: exercise,
        sets: _calculateSetsForStrength(exercise, recentSessions),
        repRange: const RepRange(min: 1, max: 5),
        rpeRange: const RPERange(min: 8, max: 10),
        restSeconds: _calculateRestForStrength(exercise),
        notes: 'Focus on maximum effort and perfect form',
      );
    }).toList();

    return WorkoutPlan(
      sessionType: SessionType.strength,
      targetMuscleGroups: readyMuscleGroups,
      exercises: recommendations,
      estimatedDuration: _estimateSessionDuration(recommendations),
      reasoning: 'Strength focus: heavy weight, low reps, long rest periods',
    );
  }

  /// Generates general fitness workout plan (6-15 rep range)
  WorkoutPlan _generateGeneralPlan({
    required List<String> readyMuscleGroups,
    required List<WorkoutSession> recentSessions,
    required Map<String, Exercise> availableExercises,
    String? preferredSplit,
  }) {
    final exercises = _selectExercisesForMuscleGroups(
      muscleGroups: readyMuscleGroups,
      availableExercises: availableExercises,
      recentSessions: recentSessions,
      preferCompound: true,
    );

    final recommendations = exercises.map((exercise) {
      return ExerciseRecommendation(
        exercise: exercise,
        sets: _calculateSetsForGeneral(exercise, recentSessions),
        repRange: const RepRange(min: 6, max: 15),
        rpeRange: const RPERange(min: 6, max: 8),
        restSeconds: _calculateRestForGeneral(exercise),
        notes: 'Balanced approach for general fitness',
      );
    }).toList();

    return WorkoutPlan(
      sessionType: SessionType.custom,
      targetMuscleGroups: readyMuscleGroups,
      exercises: recommendations,
      estimatedDuration: _estimateSessionDuration(recommendations),
      reasoning: 'General fitness: balanced intensity and volume',
    );
  }

  /// Generates deload workout plan with reduced intensity and volume
  WorkoutPlan _generateDeloadPlan({
    required Map<String, ReadinessLevel> muscleGroupReadiness,
    required Map<String, Exercise> availableExercises,
  }) {
    // Select exercises for muscle groups that aren't completely fatigued
    final targetMuscleGroups = muscleGroupReadiness.entries
        .where((entry) => entry.value != ReadinessLevel.fatigued)
        .map((entry) => entry.key)
        .toList();

    if (targetMuscleGroups.isEmpty) {
      return WorkoutPlan.restDay(
        reason: 'Complete rest recommended during deload week',
        nextRecommendedTime: DateTime.now().add(const Duration(days: 2)),
      );
    }

    final exercises = _selectExercisesForMuscleGroups(
      muscleGroups: targetMuscleGroups,
      availableExercises: availableExercises,
      recentSessions: [],
      preferCompound: false,
      maxExercises: 4,
    );

    final recommendations = exercises.map((exercise) {
      return ExerciseRecommendation(
        exercise: exercise,
        sets: 2, // Reduced sets
        repRange: const RepRange(min: 12, max: 15),
        rpeRange: const RPERange(min: 5, max: 7), // Reduced intensity
        restSeconds: 90,
        notes: 'Deload week: focus on movement quality and recovery',
      );
    }).toList();

    return WorkoutPlan(
      sessionType: SessionType.deload,
      targetMuscleGroups: targetMuscleGroups,
      exercises: recommendations,
      estimatedDuration: _estimateSessionDuration(recommendations),
      reasoning: 'Deload week: reduced volume and intensity for recovery',
    );
  }

  /// Calculates 4-week volume increase percentage
  double _calculateVolumeIncrease(List<WorkoutSession> recentSessions) {
    if (recentSessions.length < 8) return 0.0;

    // Sort sessions by date
    final sortedSessions = List<WorkoutSession>.from(recentSessions)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final now = DateTime.now();
    final fourWeeksAgo = now.subtract(const Duration(days: 28));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    // Calculate volume for weeks 3-4 (older) and weeks 1-2 (recent)
    final olderVolume = sortedSessions
        .where((s) => s.startTime.isAfter(fourWeeksAgo) && s.startTime.isBefore(twoWeeksAgo))
        .fold(0.0, (sum, session) => sum + session.totalVolume);

    final recentVolume = sortedSessions
        .where((s) => s.startTime.isAfter(twoWeeksAgo))
        .fold(0.0, (sum, session) => sum + session.totalVolume);

    if (olderVolume <= 0) return 0.0;
    return (recentVolume - olderVolume) / olderVolume;
  }

  /// Counts muscle groups with chronic high fatigue
  int _countHighFatigueGroups(Map<String, double> currentFatigue) {
    return currentFatigue.values
        .where((fatigue) => fatigue > CHRONIC_FATIGUE_THRESHOLD)
        .length;
  }

  /// Selects appropriate exercises for target muscle groups
  List<Exercise> _selectExercisesForMuscleGroups({
    required List<String> muscleGroups,
    required Map<String, Exercise> availableExercises,
    required List<WorkoutSession> recentSessions,
    bool preferCompound = true,
    int maxExercises = 6,
  }) {
    final selectedExercises = <Exercise>[];
    final recentExerciseIds = _getRecentExerciseIds(recentSessions, days: 7);

    // Separate compound and isolation exercises
    final compoundExercises = availableExercises.values
        .where((e) => e.isCompound)
        .toList();
    final isolationExercises = availableExercises.values
        .where((e) => !e.isCompound)
        .toList();

    // First, select compound exercises that target ready muscle groups
    if (preferCompound) {
      for (final exercise in compoundExercises) {
        if (selectedExercises.length >= maxExercises) break;

        final targetsReadyMuscles = exercise.primaryMuscleGroups
            .any((mg) => muscleGroups.contains(mg));

        if (targetsReadyMuscles && !recentExerciseIds.contains(exercise.id)) {
          selectedExercises.add(exercise);
        }
      }
    }

    // Then add isolation exercises if needed
    for (final exercise in isolationExercises) {
      if (selectedExercises.length >= maxExercises) break;

      final targetsReadyMuscles = exercise.primaryMuscleGroups
          .any((mg) => muscleGroups.contains(mg));

      if (targetsReadyMuscles && !recentExerciseIds.contains(exercise.id)) {
        selectedExercises.add(exercise);
      }
    }

    // If we don't have enough exercises, add some recent ones (compound first)
    if (selectedExercises.length < 3) {
      final allExercises = [...compoundExercises, ...isolationExercises];
      for (final exercise in allExercises) {
        if (selectedExercises.length >= maxExercises) break;
        if (!selectedExercises.contains(exercise)) {
          final targetsReadyMuscles = exercise.primaryMuscleGroups
              .any((mg) => muscleGroups.contains(mg));
          if (targetsReadyMuscles) {
            selectedExercises.add(exercise);
          }
        }
      }
    }

    return selectedExercises;
  }

  /// Gets exercise IDs used in recent sessions
  Set<String> _getRecentExerciseIds(List<WorkoutSession> sessions, {int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return sessions
        .where((session) => session.startTime.isAfter(cutoff))
        .expand((session) => session.uniqueExercises)
        .toSet();
  }

  /// Calculates appropriate number of sets for hypertrophy
  int _calculateSetsForHypertrophy(Exercise exercise, List<WorkoutSession> recentSessions) {
    // Base sets: 3-4 for compound, 2-3 for isolation
    final baseSets = exercise.isCompound ? 3 : 2;
    
    // Adjust based on recent volume (simplified)
    final recentVolume = _getRecentVolumeForExercise(exercise.id, recentSessions);
    if (recentVolume > 0) {
      return math.min(4, baseSets + 1); // Slight progression
    }
    
    return baseSets;
  }

  /// Calculates appropriate number of sets for strength
  int _calculateSetsForStrength(Exercise exercise, List<WorkoutSession> recentSessions) {
    // Strength training typically uses more sets with lower reps
    return exercise.isCompound ? 5 : 3;
  }

  /// Calculates appropriate number of sets for general fitness
  int _calculateSetsForGeneral(Exercise exercise, List<WorkoutSession> recentSessions) {
    return exercise.isCompound ? 3 : 2;
  }

  /// Calculates rest time for hypertrophy training
  int _calculateRestForHypertrophy(Exercise exercise) {
    return exercise.isCompound ? 120 : 90; // 2 min compound, 90s isolation
  }

  /// Calculates rest time for strength training
  int _calculateRestForStrength(Exercise exercise) {
    return exercise.isCompound ? 300 : 180; // 5 min compound, 3 min isolation
  }

  /// Calculates rest time for general fitness
  int _calculateRestForGeneral(Exercise exercise) {
    return exercise.isCompound ? 90 : 60; // 90s compound, 60s isolation
  }

  /// Gets recent volume for a specific exercise
  double _getRecentVolumeForExercise(String exerciseId, List<WorkoutSession> sessions) {
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    return sessions
        .where((session) => session.startTime.isAfter(cutoff))
        .expand((session) => session.sets)
        .where((set) => set.exerciseId == exerciseId)
        .fold(0.0, (sum, set) => sum + set.volume);
  }

  /// Estimates session duration based on exercises and rest times
  Duration _estimateSessionDuration(List<ExerciseRecommendation> exercises) {
    var totalMinutes = 0;
    
    for (final exercise in exercises) {
      // Estimate time per set (including rest)
      final timePerSet = (exercise.restSeconds / 60) + 2; // 2 min for set execution
      totalMinutes += (exercise.sets * timePerSet).round();
    }
    
    // Add warm-up and cool-down time
    totalMinutes += 15;
    
    return Duration(minutes: totalMinutes);
  }

  /// Estimates when the next muscle group will be ready
  DateTime _estimateNextReadyTime(Map<String, ReadinessLevel> muscleGroupReadiness) {
    // Simplified estimation - in real implementation, would use recovery engine
    final hoursUntilReady = muscleGroupReadiness.values.any((level) => level == ReadinessLevel.warm) ? 12 : 24;
    return DateTime.now().add(Duration(hours: hoursUntilReady));
  }
}

/// Represents a complete workout plan recommendation
class WorkoutPlan {
  final SessionType sessionType;
  final List<String> targetMuscleGroups;
  final List<ExerciseRecommendation> exercises;
  final Duration estimatedDuration;
  final String reasoning;
  final bool isRestDay;
  final DateTime? nextRecommendedTime;

  const WorkoutPlan({
    required this.sessionType,
    required this.targetMuscleGroups,
    required this.exercises,
    required this.estimatedDuration,
    required this.reasoning,
    this.isRestDay = false,
    this.nextRecommendedTime,
  });

  /// Creates a rest day recommendation
  factory WorkoutPlan.restDay({
    required String reason,
    DateTime? nextRecommendedTime,
  }) {
    return WorkoutPlan(
      sessionType: SessionType.custom,
      targetMuscleGroups: [],
      exercises: [],
      estimatedDuration: Duration.zero,
      reasoning: reason,
      isRestDay: true,
      nextRecommendedTime: nextRecommendedTime,
    );
  }

  /// Gets total estimated volume for the plan
  double get estimatedVolume {
    return exercises.fold(0.0, (sum, exercise) {
      final avgReps = (exercise.repRange.min + exercise.repRange.max) / 2;
      return sum + (exercise.sets * avgReps * 100); // Assuming 100kg average
    });
  }

  /// Checks if the plan is suitable for the user's current state
  bool get isRecommended => !isRestDay && exercises.isNotEmpty;
}

/// Represents an exercise recommendation within a workout plan
class ExerciseRecommendation {
  final Exercise exercise;
  final int sets;
  final RepRange repRange;
  final RPERange rpeRange;
  final int restSeconds;
  final String notes;

  const ExerciseRecommendation({
    required this.exercise,
    required this.sets,
    required this.repRange,
    required this.rpeRange,
    required this.restSeconds,
    required this.notes,
  });

  /// Gets formatted rest time as string
  String get formattedRestTime {
    final minutes = restSeconds ~/ 60;
    final seconds = restSeconds % 60;
    if (minutes > 0) {
      return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    }
    return '${seconds}s';
  }
}

/// Represents a rep range recommendation
class RepRange {
  final int min;
  final int max;

  const RepRange({required this.min, required this.max});

  @override
  String toString() => '$min-$max';
}

/// Represents an RPE range recommendation
class RPERange {
  final int min;
  final int max;

  const RPERange({required this.min, required this.max});

  @override
  String toString() => '$min-$max';
}