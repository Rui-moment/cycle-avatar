import 'package:freezed_annotation/freezed_annotation.dart';

part 'pr_record.freezed.dart';
part 'pr_record.g.dart';

@freezed
class PRRecord with _$PRRecord {
  const factory PRRecord({
    required String id,
    required String userId,
    required String exerciseId,
    required double weight,
    required int reps,
    required double estimatedMax,
    required DateTime achievedAt,
    String? workoutSessionId,
    String? notes,
    @Default(false) bool isVerified, // Whether the PR has been verified/confirmed
  }) = _PRRecord;

  const PRRecord._();

  factory PRRecord.fromJson(Map<String, dynamic> json) => 
      _$PRRecordFromJson(json);

  /// Validates PR record data
  String? validate() {
    if (id.isEmpty) return 'PR record ID cannot be empty';
    if (userId.isEmpty) return 'User ID cannot be empty';
    if (exerciseId.isEmpty) return 'Exercise ID cannot be empty';
    if (weight <= 0) return 'Weight must be positive';
    if (reps <= 0) return 'Reps must be positive';
    if (estimatedMax <= 0) return 'Estimated max must be positive';
    if (achievedAt.isAfter(DateTime.now())) {
      return 'Achievement date cannot be in the future';
    }
    return null;
  }

  /// Checks if the PR record data is valid
  bool get isValid => validate() == null;

  /// Gets the age of this PR record
  Duration get age => DateTime.now().difference(achievedAt);

  /// Checks if this PR is recent (within last 30 days)
  bool get isRecent => age.inDays <= 30;

  /// Calculates the volume (weight × reps) for this PR
  double get volume => weight * reps;

  /// Compares this PR with another PR for the same exercise
  /// Returns positive if this PR is better, negative if worse, 0 if equal
  int compareWith(PRRecord other) {
    if (exerciseId != other.exerciseId) {
      throw ArgumentError('Cannot compare PRs for different exercises');
    }
    
    // Compare by estimated 1RM first
    final maxDiff = estimatedMax - other.estimatedMax;
    if (maxDiff.abs() > 0.1) return maxDiff > 0 ? 1 : -1;
    
    // If estimated max is similar, compare by volume
    final volumeDiff = volume - other.volume;
    if (volumeDiff.abs() > 0.1) return volumeDiff > 0 ? 1 : -1;
    
    return 0;
  }

  /// Checks if this PR is better than another PR
  bool isBetterThan(PRRecord other) => compareWith(other) > 0;

  /// Gets a description of the PR type
  String get prType {
    if (reps == 1) return '1RM';
    if (reps <= 3) return '${reps}RM';
    if (reps <= 5) return 'Strength';
    if (reps <= 12) return 'Hypertrophy';
    return 'Endurance';
  }

  /// Creates a PR record from a workout set
  factory PRRecord.fromWorkoutSet({
    required String id,
    required String userId,
    required String exerciseId,
    required double weight,
    required int reps,
    required DateTime achievedAt,
    String? workoutSessionId,
    String? notes,
  }) {
    // Calculate estimated 1RM using Epley formula
    final estimatedMax = reps == 1 ? weight : weight * (1 + reps / 30.0);
    
    return PRRecord(
      id: id,
      userId: userId,
      exerciseId: exerciseId,
      weight: weight,
      reps: reps,
      estimatedMax: estimatedMax,
      achievedAt: achievedAt,
      workoutSessionId: workoutSessionId,
      notes: notes,
    );
  }

  /// Verifies the PR record
  PRRecord verify() => copyWith(isVerified: true);

  /// Updates the PR with new data if it's better
  PRRecord? updateIfBetter({
    required double newWeight,
    required int newReps,
    required DateTime newAchievedAt,
    String? newWorkoutSessionId,
    String? newNotes,
  }) {
    final newEstimatedMax = newReps == 1 ? newWeight : newWeight * (1 + newReps / 30.0);
    
    // Only update if the new PR is actually better
    if (newEstimatedMax <= estimatedMax) return null;
    
    return copyWith(
      weight: newWeight,
      reps: newReps,
      estimatedMax: newEstimatedMax,
      achievedAt: newAchievedAt,
      workoutSessionId: newWorkoutSessionId,
      notes: newNotes,
      isVerified: false, // New PR needs verification
    );
  }

  /// Calculates the improvement percentage over a previous PR
  double calculateImprovementPercentage(PRRecord previousPR) {
    if (previousPR.estimatedMax == 0) return 0.0;
    return ((estimatedMax - previousPR.estimatedMax) / previousPR.estimatedMax) * 100;
  }

  /// Checks if this PR represents a significant improvement (>2.5%)
  bool isSignificantImprovement(PRRecord previousPR) {
    return calculateImprovementPercentage(previousPR) >= 2.5;
  }

  /// Gets the strength level category based on estimated max
  String getStrengthLevel() {
    // This is a simplified categorization - in practice, this would
    // depend on bodyweight, gender, and exercise type
    if (estimatedMax < 60) return 'Beginner';
    if (estimatedMax < 100) return 'Novice';
    if (estimatedMax < 140) return 'Intermediate';
    if (estimatedMax < 180) return 'Advanced';
    return 'Elite';
  }
}