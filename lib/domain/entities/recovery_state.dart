import 'dart:math' as math;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';

part 'recovery_state.freezed.dart';
part 'recovery_state.g.dart';

@freezed
class RecoveryState with _$RecoveryState {
  const factory RecoveryState({
    required String id,
    required String muscleGroupId,
    required double currentFatigue,
    required DateTime lastUpdated,
    required ReadinessLevel readinessLevel,
    DateTime? lastWorkoutTime,
    double? initialFatigue, // Fatigue level immediately after last workout
  }) = _RecoveryState;

  const RecoveryState._();

  factory RecoveryState.fromJson(Map<String, dynamic> json) => 
      _$RecoveryStateFromJson(json);

  /// Validates recovery state data
  String? validate() {
    if (id.isEmpty) return 'Recovery state ID cannot be empty';
    if (muscleGroupId.isEmpty) return 'Muscle group ID cannot be empty';
    if (currentFatigue < 0) return 'Current fatigue cannot be negative';
    if (initialFatigue != null && initialFatigue! < 0) {
      return 'Initial fatigue cannot be negative';
    }
    if (lastWorkoutTime != null && lastWorkoutTime!.isAfter(DateTime.now())) {
      return 'Last workout time cannot be in the future';
    }
    return null;
  }

  /// Checks if the recovery state data is valid
  bool get isValid => validate() == null;

  /// Gets the time since last workout
  Duration? get timeSinceLastWorkout {
    if (lastWorkoutTime == null) return null;
    return DateTime.now().difference(lastWorkoutTime!);
  }

  /// Gets recovery percentage (0.0 = fully fatigued, 1.0 = fully recovered)
  double get recoveryPercentage {
    if (initialFatigue == null || initialFatigue == 0) return 1.0;
    return 1.0 - (currentFatigue / initialFatigue!);
  }

  /// Checks if the muscle group is ready for training
  bool get isReady => readinessLevel == ReadinessLevel.ready;

  /// Checks if the muscle group is in optimal recovery window
  bool get isInOptimalWindow {
    return readinessLevel == ReadinessLevel.ready && 
           recoveryPercentage >= 0.8; // 80% recovered
  }

  /// Gets estimated time until fully recovered
  Duration? getEstimatedRecoveryTime(double recoveryTau) {
    if (currentFatigue <= 1.0) return Duration.zero;
    if (initialFatigue == null || initialFatigue == 0) return Duration.zero;
    
    // Using exponential decay: fatigue = initial * e^(-t/tau)
    // Solving for t when fatigue = 1.0: t = tau * ln(initial/1.0)
    final hoursToRecover = recoveryTau * math.log(initialFatigue!.clamp(1.0, double.infinity));
    final currentHours = (timeSinceLastWorkout?.inMilliseconds ?? 0) / (1000 * 60 * 60);
    final remainingHours = (hoursToRecover - currentHours).clamp(0.0, double.infinity);
    
    return Duration(milliseconds: (remainingHours * 60 * 60 * 1000).round());
  }

  /// Creates a fresh recovery state (fully recovered)
  factory RecoveryState.fresh({
    required String id,
    required String muscleGroupId,
  }) {
    return RecoveryState(
      id: id,
      muscleGroupId: muscleGroupId,
      currentFatigue: 0.0,
      lastUpdated: DateTime.now(),
      readinessLevel: ReadinessLevel.ready,
    );
  }

  /// Updates the recovery state with new fatigue
  RecoveryState updateFatigue({
    required double newFatigue,
    required ReadinessLevel newReadinessLevel,
    DateTime? workoutTime,
  }) {
    return copyWith(
      currentFatigue: newFatigue,
      lastUpdated: DateTime.now(),
      readinessLevel: newReadinessLevel,
      lastWorkoutTime: workoutTime ?? lastWorkoutTime,
      initialFatigue: workoutTime != null ? newFatigue : initialFatigue,
    );
  }

  /// Updates the recovery state based on time passage
  RecoveryState updateRecovery({
    required double newFatigue,
    required ReadinessLevel newReadinessLevel,
  }) {
    return copyWith(
      currentFatigue: newFatigue,
      lastUpdated: DateTime.now(),
      readinessLevel: newReadinessLevel,
    );
  }
}