import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/plan_generator.dart';
import '../../domain/entities/workout_session.dart';
import 'recovery_provider.dart';

/// State class for workout plan data
class WorkoutPlanData {
  final WorkoutPlan? todaysRecommendation;
  final bool isLoading;
  final String? error;

  const WorkoutPlanData({
    this.todaysRecommendation,
    this.isLoading = false,
    this.error,
  });

  WorkoutPlanData copyWith({
    WorkoutPlan? todaysRecommendation,
    bool? isLoading,
    String? error,
  }) {
    return WorkoutPlanData(
      todaysRecommendation: todaysRecommendation ?? this.todaysRecommendation,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing workout plan
class PlanNotifier extends StateNotifier<WorkoutPlanData> {
  final PlanGenerator _planGenerator;

  PlanNotifier(this._planGenerator) : super(const WorkoutPlanData());

  /// Generate today's workout recommendation
  void generateTodaysRecommendation({
    required Map<String, ReadinessLevel> muscleGroupReadiness,
    TrainingGoal goal = TrainingGoal.hypertrophy,
    List<WorkoutSession> recentSessions = const [],
  }) {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // For now, create a simple recommendation since we don't have exercises loaded
      // In a real implementation, this would load exercises from the repository
      final recommendation = _createSimpleRecommendation(
        muscleGroupReadiness: muscleGroupReadiness,
        goal: goal,
      );
      
      state = state.copyWith(
        todaysRecommendation: recommendation,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to generate recommendation: $e',
      );
    }
  }

  /// Creates a simple workout recommendation for demo purposes
  WorkoutPlan _createSimpleRecommendation({
    required Map<String, ReadinessLevel> muscleGroupReadiness,
    required TrainingGoal goal,
  }) {
    // Get ready muscle groups
    final readyMuscleGroups = muscleGroupReadiness.entries
        .where((entry) => entry.value == ReadinessLevel.ready)
        .map((entry) => entry.key)
        .toList();

    // If no muscle groups are ready, suggest rest day
    if (readyMuscleGroups.isEmpty) {
      return WorkoutPlan.restDay(
        reason: 'All muscle groups need more recovery time',
        nextRecommendedTime: DateTime.now().add(const Duration(hours: 12)),
      );
    }

    // Create a simple recommendation based on ready muscle groups
    final sessionType = goal == TrainingGoal.strength 
        ? SessionType.strength 
        : goal == TrainingGoal.hypertrophy 
            ? SessionType.hypertrophy 
            : SessionType.custom;

    String reasoning;
    switch (goal) {
      case TrainingGoal.strength:
        reasoning = 'Strength focus: Heavy weight, low reps (1-5), long rest';
        break;
      case TrainingGoal.hypertrophy:
        reasoning = 'Hypertrophy focus: Moderate weight, higher volume (8-12 reps)';
        break;
      case TrainingGoal.general:
        reasoning = 'General fitness: Balanced approach (6-15 reps)';
        break;
    }

    return WorkoutPlan(
      sessionType: sessionType,
      targetMuscleGroups: readyMuscleGroups,
      exercises: [], // Empty for now - would be populated with actual exercises
      estimatedDuration: const Duration(minutes: 60),
      reasoning: reasoning,
    );
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for plan generator
final planGeneratorProvider = Provider<PlanGenerator>((ref) {
  return PlanGenerator();
});

/// Provider for workout plan
final planProvider = StateNotifierProvider<PlanNotifier, WorkoutPlanData>((ref) {
  final planGenerator = ref.watch(planGeneratorProvider);
  return PlanNotifier(planGenerator);
});

/// Provider for today's recommendation based on recovery state
final todaysRecommendationProvider = Provider<WorkoutPlan?>((ref) {
  final recoveryState = ref.watch(recoveryProvider);
  final planNotifier = ref.watch(planProvider.notifier);
  
  if (recoveryState.recoveryStates.isNotEmpty) {
    final muscleGroupReadiness = recoveryState.recoveryStates.map(
      (key, value) => MapEntry(key, value.readinessLevel),
    );
    
    planNotifier.generateTodaysRecommendation(
      muscleGroupReadiness: muscleGroupReadiness,
    );
  }
  
  return ref.watch(planProvider).todaysRecommendation;
});