import 'dart:math' as math;
import '../entities/enums.dart';
import '../entities/constants.dart';
import '../entities/recovery_state.dart';
import '../entities/fatigue_event.dart';
import '../entities/muscle_group.dart';

/// Engine for calculating recovery using exponential decay model
/// and determining readiness levels for muscle groups
class RecoveryEngine {
  /// Calculates current fatigue using exponential decay model
  /// Formula: currentFatigue = initialFatigue * e^(-t/τ)
  double calculateCurrentFatigue({
    required double initialFatigue,
    required Duration timeSinceWorkout,
    required double recoveryTau,
  }) {
    if (initialFatigue <= 0) return 0.0;
    if (timeSinceWorkout.inMilliseconds <= 0) return initialFatigue;
    
    final hoursElapsed = timeSinceWorkout.inMilliseconds / (1000 * 60 * 60);
    final currentFatigue = initialFatigue * math.exp(-hoursElapsed / recoveryTau);
    
    // Ensure fatigue doesn't go below a minimal threshold
    return math.max(0.0, currentFatigue);
  }

  /// Calculates current fatigue for a muscle group using its recovery tau
  double calculateMuscleGroupFatigue({
    required double initialFatigue,
    required Duration timeSinceWorkout,
    required String muscleGroupId,
  }) {
    final recoveryTau = RECOVERY_TAU[muscleGroupId] ?? 48.0;
    return calculateCurrentFatigue(
      initialFatigue: initialFatigue,
      timeSinceWorkout: timeSinceWorkout,
      recoveryTau: recoveryTau,
    );
  }

  /// Determines readiness level based on current fatigue score
  ReadinessLevel determineReadinessLevel(double currentFatigue) {
    if (currentFatigue < READY_THRESHOLD) return ReadinessLevel.ready;
    if (currentFatigue < WARM_THRESHOLD) return ReadinessLevel.warm;
    return ReadinessLevel.fatigued;
  }

  /// Updates recovery state based on time passage
  RecoveryState updateRecoveryState({
    required RecoveryState currentState,
    required String muscleGroupId,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    
    // If no last workout time, assume fully recovered
    if (currentState.lastWorkoutTime == null) {
      return currentState.copyWith(
        currentFatigue: 0.0,
        lastUpdated: now,
        readinessLevel: ReadinessLevel.ready,
      );
    }
    
    final timeSinceWorkout = now.difference(currentState.lastWorkoutTime!);
    final initialFatigue = currentState.initialFatigue ?? currentState.currentFatigue;
    
    final newFatigue = calculateMuscleGroupFatigue(
      initialFatigue: initialFatigue,
      timeSinceWorkout: timeSinceWorkout,
      muscleGroupId: muscleGroupId,
    );
    
    final newReadinessLevel = determineReadinessLevel(newFatigue);
    
    return currentState.updateRecovery(
      newFatigue: newFatigue,
      newReadinessLevel: newReadinessLevel,
    );
  }

  /// Calculates recovery percentage (0.0 = fully fatigued, 1.0 = fully recovered)
  double calculateRecoveryPercentage({
    required double currentFatigue,
    required double initialFatigue,
  }) {
    if (initialFatigue <= 0) return 1.0;
    return math.max(0.0, 1.0 - (currentFatigue / initialFatigue));
  }

  /// Estimates time until muscle group reaches a specific readiness level
  Duration estimateTimeToReadiness({
    required double currentFatigue,
    required ReadinessLevel targetReadiness,
    required String muscleGroupId,
  }) {
    final targetFatigue = _getTargetFatigueForReadiness(targetReadiness);
    
    if (currentFatigue <= targetFatigue) {
      return Duration.zero;
    }
    
    final recoveryTau = RECOVERY_TAU[muscleGroupId] ?? 48.0;
    
    // Solve exponential decay equation for time
    // targetFatigue = currentFatigue * e^(-t/τ)
    // t = -τ * ln(targetFatigue / currentFatigue)
    final hoursToTarget = -recoveryTau * math.log(targetFatigue / currentFatigue);
    
    return Duration(milliseconds: (hoursToTarget * 60 * 60 * 1000).round());
  }

  /// Estimates time until full recovery (fatigue < 1.0)
  Duration estimateTimeToFullRecovery({
    required double currentFatigue,
    required String muscleGroupId,
  }) {
    if (currentFatigue <= 1.0) return Duration.zero;
    
    final recoveryTau = RECOVERY_TAU[muscleGroupId] ?? 48.0;
    final hoursToRecover = recoveryTau * math.log(currentFatigue);
    
    return Duration(milliseconds: (hoursToRecover * 60 * 60 * 1000).round());
  }

  /// Calculates recovery rate (fatigue reduction per hour)
  double calculateRecoveryRate({
    required double currentFatigue,
    required String muscleGroupId,
  }) {
    if (currentFatigue <= 0) return 0.0;
    
    final recoveryTau = RECOVERY_TAU[muscleGroupId] ?? 48.0;
    return currentFatigue / recoveryTau;
  }

  /// Checks if muscle group is in optimal recovery window
  bool isInOptimalRecoveryWindow({
    required double currentFatigue,
    required double initialFatigue,
  }) {
    final recoveryPercentage = calculateRecoveryPercentage(
      currentFatigue: currentFatigue,
      initialFatigue: initialFatigue,
    );
    
    // Optimal window: 80-95% recovered
    return recoveryPercentage >= 0.8 && recoveryPercentage <= 0.95;
  }

  /// Calculates supercompensation window (period of enhanced performance)
  SupercompensationWindow calculateSupercompensationWindow({
    required double initialFatigue,
    required String muscleGroupId,
  }) {
    final recoveryTau = RECOVERY_TAU[muscleGroupId] ?? 48.0;
    
    // Supercompensation typically occurs at 80-120% of recovery time
    final baseRecoveryHours = recoveryTau * math.log(initialFatigue.clamp(1.0, double.infinity));
    final windowStart = Duration(milliseconds: (baseRecoveryHours * 0.8 * 60 * 60 * 1000).round());
    final windowEnd = Duration(milliseconds: (baseRecoveryHours * 1.2 * 60 * 60 * 1000).round());
    
    return SupercompensationWindow(
      start: windowStart,
      end: windowEnd,
      peakTime: Duration(milliseconds: (baseRecoveryHours * 60 * 60 * 1000).round()),
    );
  }

  /// Updates multiple recovery states efficiently
  Map<String, RecoveryState> updateMultipleRecoveryStates({
    required Map<String, RecoveryState> currentStates,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final updatedStates = <String, RecoveryState>{};
    
    for (final entry in currentStates.entries) {
      final muscleGroupId = entry.key;
      final currentState = entry.value;
      
      updatedStates[muscleGroupId] = updateRecoveryState(
        currentState: currentState,
        muscleGroupId: muscleGroupId,
        currentTime: now,
      );
    }
    
    return updatedStates;
  }

  /// Calculates aggregate recovery metrics for multiple muscle groups
  AggregateRecoveryMetrics calculateAggregateMetrics({
    required Map<String, RecoveryState> recoveryStates,
  }) {
    if (recoveryStates.isEmpty) {
      return const AggregateRecoveryMetrics(
        averageRecoveryPercentage: 1.0,
        readyCount: 0,
        warmCount: 0,
        fatiguedCount: 0,
        totalMuscleGroups: 0,
        overallReadinessLevel: ReadinessLevel.ready,
      );
    }
    
    var readyCount = 0;
    var warmCount = 0;
    var fatiguedCount = 0;
    var totalRecoveryPercentage = 0.0;
    
    for (final state in recoveryStates.values) {
      switch (state.readinessLevel) {
        case ReadinessLevel.ready:
          readyCount++;
          break;
        case ReadinessLevel.warm:
          warmCount++;
          break;
        case ReadinessLevel.fatigued:
          fatiguedCount++;
          break;
      }
      
      totalRecoveryPercentage += state.recoveryPercentage;
    }
    
    final averageRecoveryPercentage = totalRecoveryPercentage / recoveryStates.length;
    final overallReadinessLevel = _determineOverallReadiness(readyCount, warmCount, fatiguedCount);
    
    return AggregateRecoveryMetrics(
      averageRecoveryPercentage: averageRecoveryPercentage,
      readyCount: readyCount,
      warmCount: warmCount,
      fatiguedCount: fatiguedCount,
      totalMuscleGroups: recoveryStates.length,
      overallReadinessLevel: overallReadinessLevel,
    );
  }

  /// Gets target fatigue level for a specific readiness level
  double _getTargetFatigueForReadiness(ReadinessLevel readiness) {
    switch (readiness) {
      case ReadinessLevel.ready:
        return READY_THRESHOLD;
      case ReadinessLevel.warm:
        return WARM_THRESHOLD;
      case ReadinessLevel.fatigued:
        return double.infinity;
    }
  }

  /// Determines overall readiness based on individual muscle group states
  ReadinessLevel _determineOverallReadiness(int readyCount, int warmCount, int fatiguedCount) {
    final total = readyCount + warmCount + fatiguedCount;
    if (total == 0) return ReadinessLevel.ready;
    
    final readyPercentage = readyCount / total;
    final fatiguedPercentage = fatiguedCount / total;
    
    // If majority are ready, overall is ready
    if (readyPercentage >= 0.6) return ReadinessLevel.ready;
    
    // If significant portion is fatigued, overall is fatigued
    if (fatiguedPercentage >= 0.4) return ReadinessLevel.fatigued;
    
    // Otherwise, overall is warm
    return ReadinessLevel.warm;
  }
}

/// Represents the supercompensation window for optimal training timing
class SupercompensationWindow {
  final Duration start;
  final Duration end;
  final Duration peakTime;

  const SupercompensationWindow({
    required this.start,
    required this.end,
    required this.peakTime,
  });

  /// Checks if a given time is within the supercompensation window
  bool isWithinWindow(Duration timeSinceWorkout) {
    return timeSinceWorkout >= start && timeSinceWorkout <= end;
  }

  /// Checks if a given time is at the peak of supercompensation
  bool isAtPeak(Duration timeSinceWorkout, {Duration tolerance = const Duration(hours: 2)}) {
    final difference = (timeSinceWorkout - peakTime).abs();
    return difference <= tolerance;
  }

  @override
  String toString() {
    return 'SupercompensationWindow(start: ${start.inHours}h, peak: ${peakTime.inHours}h, end: ${end.inHours}h)';
  }
}

/// Aggregate recovery metrics for multiple muscle groups
class AggregateRecoveryMetrics {
  final double averageRecoveryPercentage;
  final int readyCount;
  final int warmCount;
  final int fatiguedCount;
  final int totalMuscleGroups;
  final ReadinessLevel overallReadinessLevel;

  const AggregateRecoveryMetrics({
    required this.averageRecoveryPercentage,
    required this.readyCount,
    required this.warmCount,
    required this.fatiguedCount,
    required this.totalMuscleGroups,
    required this.overallReadinessLevel,
  });

  /// Gets the percentage of muscle groups that are ready
  double get readyPercentage => totalMuscleGroups > 0 ? readyCount / totalMuscleGroups : 0.0;

  /// Gets the percentage of muscle groups that are fatigued
  double get fatiguedPercentage => totalMuscleGroups > 0 ? fatiguedCount / totalMuscleGroups : 0.0;

  /// Checks if the overall state is suitable for training
  bool get isSuitableForTraining => overallReadinessLevel != ReadinessLevel.fatigued;

  @override
  String toString() {
    return 'AggregateRecoveryMetrics('
        'avgRecovery: ${(averageRecoveryPercentage * 100).toStringAsFixed(1)}%, '
        'ready: $readyCount, warm: $warmCount, fatigued: $fatiguedCount, '
        'overall: $overallReadinessLevel'
        ')';
  }
}