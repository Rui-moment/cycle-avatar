import 'package:freezed_annotation/freezed_annotation.dart';
import 'enums.dart';
import 'constants.dart';

part 'workout_session.freezed.dart';
part 'workout_session.g.dart';

@freezed
class WorkoutSession with _$WorkoutSession {
  const factory WorkoutSession({
    required String id,
    required String userId,
    required DateTime startTime,
    DateTime? endTime,
    required SessionType sessionType,
    String? notes,
    @Default(false) bool isSynced,
    required DateTime createdAt,
    @Default([]) List<WorkoutSet> sets,
  }) = _WorkoutSession;

  const WorkoutSession._();

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => 
      _$WorkoutSessionFromJson(json);

  /// Validates workout session data
  String? validate() {
    if (id.isEmpty) return 'Session ID cannot be empty';
    if (userId.isEmpty) return 'User ID cannot be empty';
    if (endTime != null && endTime!.isBefore(startTime)) {
      return 'End time cannot be before start time';
    }
    
    // Validate sets
    for (int i = 0; i < sets.length; i++) {
      final setValidation = sets[i].validate();
      if (setValidation != null) {
        return 'Set ${i + 1}: $setValidation';
      }
    }
    
    return null;
  }

  /// Checks if the session data is valid
  bool get isValid => validate() == null;

  /// Gets the duration of the workout session
  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  /// Checks if the session is currently active (not ended)
  bool get isActive => endTime == null;

  /// Gets total volume (weight × reps) for the session
  double get totalVolume {
    return sets.fold(0.0, (sum, set) => sum + (set.weight * set.reps));
  }

  /// Gets total number of sets in the session
  int get totalSets => sets.length;

  /// Gets unique exercises in the session
  Set<String> get uniqueExercises => sets.map((set) => set.exerciseId).toSet();

  /// Gets sets for a specific exercise
  List<WorkoutSet> getSetsForExercise(String exerciseId) {
    return sets.where((set) => set.exerciseId == exerciseId).toList();
  }

  /// Calculates average RPE for the session
  double get averageRPE {
    if (sets.isEmpty) return 0.0;
    return sets.fold(0.0, (sum, set) => sum + set.rpe) / sets.length;
  }

  /// Ends the workout session
  WorkoutSession endSession() {
    return copyWith(endTime: DateTime.now());
  }

  /// Adds a set to the session
  WorkoutSession addSet(WorkoutSet set) {
    return copyWith(sets: [...sets, set]);
  }
}

@freezed
class WorkoutSet with _$WorkoutSet {
  const factory WorkoutSet({
    required String id,
    required String sessionId,
    required String exerciseId,
    required double weight,
    required int reps,
    required int rpe, // Rate of Perceived Exertion (1-10)
    @Default(0) int restSeconds,
    String? notes,
    required int setOrder,
    required DateTime createdAt,
  }) = _WorkoutSet;

  const WorkoutSet._();

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => 
      _$WorkoutSetFromJson(json);

  /// Validates workout set data
  String? validate() {
    if (id.isEmpty) return 'Set ID cannot be empty';
    if (sessionId.isEmpty) return 'Session ID cannot be empty';
    if (exerciseId.isEmpty) return 'Exercise ID cannot be empty';
    if (weight < MIN_WEIGHT_KG || weight > MAX_WEIGHT_KG) {
      return 'Weight must be between $MIN_WEIGHT_KG and $MAX_WEIGHT_KG kg';
    }
    if (reps < MIN_REPS || reps > MAX_REPS) {
      return 'Reps must be between $MIN_REPS and $MAX_REPS';
    }
    if (rpe < MIN_RPE || rpe > MAX_RPE) {
      return 'RPE must be between $MIN_RPE and $MAX_RPE';
    }
    if (restSeconds < MIN_REST_SECONDS || restSeconds > MAX_REST_SECONDS) {
      return 'Rest time must be between $MIN_REST_SECONDS and $MAX_REST_SECONDS seconds';
    }
    if (setOrder < 1) return 'Set order must be positive';
    
    return null;
  }

  /// Checks if the set data is valid
  bool get isValid => validate() == null;

  /// Calculates the volume (weight × reps) for this set
  double get volume => weight * reps;

  /// Calculates estimated 1RM using Epley formula
  double get estimated1RM {
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  /// Calculates intensity as percentage of estimated 1RM
  double calculateIntensity(double oneRepMax) {
    if (oneRepMax <= 0) return 0.0;
    return (weight / oneRepMax) * 100;
  }

  /// Gets RPE-based intensity factor for fatigue calculation
  double get rpeIntensityFactor => (rpe - 5) / 5.0;

  /// Gets RPE factor for fatigue calculation
  double get rpeFactor => rpe / 10.0;

  /// Checks if this set represents progression from a previous set
  bool isProgressionFrom(WorkoutSet previousSet) {
    // Weight progression
    if (weight >= previousSet.weight + MIN_WEIGHT_PROGRESSION_KG) return true;
    
    // Rep progression at same weight
    if (weight == previousSet.weight && reps >= previousSet.reps + MIN_REP_PROGRESSION) {
      return true;
    }
    
    return false;
  }
}