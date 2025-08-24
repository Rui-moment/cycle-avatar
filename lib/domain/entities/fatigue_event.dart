import 'dart:math' as math;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'fatigue_event.freezed.dart';
part 'fatigue_event.g.dart';

@freezed
class FatigueEvent with _$FatigueEvent {
  const factory FatigueEvent({
    required String id,
    required String muscleGroupId,
    required double fatigueScore,
    required DateTime timestamp,
    required String workoutSessionId,
    String? exerciseId, // Optional: specific exercise that caused the fatigue
    String? notes,
  }) = _FatigueEvent;

  const FatigueEvent._();

  factory FatigueEvent.fromJson(Map<String, dynamic> json) => 
      _$FatigueEventFromJson(json);

  /// Validates fatigue event data
  String? validate() {
    if (id.isEmpty) return 'Fatigue event ID cannot be empty';
    if (muscleGroupId.isEmpty) return 'Muscle group ID cannot be empty';
    if (workoutSessionId.isEmpty) return 'Workout session ID cannot be empty';
    if (fatigueScore < 0) return 'Fatigue score cannot be negative';
    if (fatigueScore > 200) return 'Fatigue score seems unreasonably high (>200)';
    return null;
  }

  /// Checks if the fatigue event data is valid
  bool get isValid => validate() == null;

  /// Gets the age of this fatigue event
  Duration get age => DateTime.now().difference(timestamp);

  /// Checks if this fatigue event is recent (within last 7 days)
  bool get isRecent => age.inDays <= 7;

  /// Creates a fatigue event from a workout set
  factory FatigueEvent.fromWorkoutData({
    required String id,
    required String muscleGroupId,
    required double fatigueScore,
    required String workoutSessionId,
    String? exerciseId,
    DateTime? timestamp,
  }) {
    return FatigueEvent(
      id: id,
      muscleGroupId: muscleGroupId,
      fatigueScore: fatigueScore,
      timestamp: timestamp ?? DateTime.now(),
      workoutSessionId: workoutSessionId,
      exerciseId: exerciseId,
    );
  }

  /// Calculates the contribution of this fatigue event to current fatigue
  /// using exponential decay based on time elapsed
  double calculateCurrentContribution(double recoveryTau) {
    final hoursElapsed = age.inMilliseconds / (1000 * 60 * 60);
    return fatigueScore * math.exp(-hoursElapsed / recoveryTau);
  }

  /// Checks if this fatigue event is significant (above threshold)
  bool get isSignificant => fatigueScore >= 10.0;

  /// Gets the fatigue category based on score
  String get fatigueCategory {
    if (fatigueScore < 20) return 'Light';
    if (fatigueScore < 50) return 'Moderate';
    if (fatigueScore < 100) return 'Heavy';
    return 'Extreme';
  }
}