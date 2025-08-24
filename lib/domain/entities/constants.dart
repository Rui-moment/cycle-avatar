/// Domain constants for fatigue and recovery calculations
library;

import 'dart:math' as math;
import 'enums.dart';

/// Recovery time constants (τ) for different muscle groups in hours
/// Based on scientific literature on muscle recovery rates
const Map<String, double> RECOVERY_TAU = {
  // Major muscle groups
  'chest': 48.0,
  'back': 72.0,
  'quadriceps': 72.0,
  'hamstrings': 72.0,
  'glutes': 72.0,
  
  // Shoulder complex
  'shoulders': 48.0,
  'delts_anterior': 48.0,
  'delts_medial': 48.0,
  'delts_posterior': 48.0,
  
  // Arms
  'biceps': 48.0,
  'triceps': 48.0,
  'forearms': 24.0,
  
  // Back subdivisions
  'lats': 72.0,
  'traps': 48.0,
  'rhomboids': 48.0,
  'rear_delts': 48.0,
  
  // Lower body
  'calves': 48.0,
  'tibialis': 24.0,
  
  // Core
  'abs': 24.0,
  'obliques': 24.0,
  'lower_back': 48.0,
  
  // Additional muscle groups for comprehensive coverage
  'serratus': 36.0,
  'hip_flexors': 36.0,
  'adductors': 48.0,
  'abductors': 48.0,
};

/// Fatigue multipliers for different muscle groups
/// Larger muscle groups have higher multipliers
const Map<String, double> FATIGUE_MULTIPLIERS = {
  // Major muscle groups
  'chest': 1.0,
  'back': 1.2,      // Large muscle group
  'quadriceps': 1.3, // Largest muscle group
  'hamstrings': 1.1,
  'glutes': 1.2,
  
  // Shoulder complex
  'shoulders': 0.8,  // Smaller muscle group
  'delts_anterior': 0.7,
  'delts_medial': 0.7,
  'delts_posterior': 0.7,
  
  // Arms
  'biceps': 0.6,     // Small muscle group
  'triceps': 0.6,    // Small muscle group
  'forearms': 0.4,   // Very quick recovery
  
  // Back subdivisions
  'lats': 1.1,
  'traps': 0.8,
  'rhomboids': 0.6,
  'rear_delts': 0.6,
  
  // Lower body
  'calves': 0.7,
  'tibialis': 0.4,
  
  // Core
  'abs': 0.5,        // Quick recovery
  'obliques': 0.5,
  'lower_back': 0.8,
  
  // Additional muscle groups for comprehensive coverage
  'serratus': 0.5,
  'hip_flexors': 0.6,
  'adductors': 0.8,
  'abductors': 0.8,
};

/// Primary and secondary muscle involvement weights
/// Primary muscles receive full fatigue, secondary muscles receive reduced fatigue
const double PRIMARY_MUSCLE_WEIGHT = 1.0;
const double SECONDARY_MUSCLE_WEIGHT = 0.5;

/// RPE (Rate of Perceived Exertion) scale constants
const int MIN_RPE = 1;
const int MAX_RPE = 10;

/// Readiness level thresholds based on fatigue scores
const double READY_THRESHOLD = 30.0;
const double WARM_THRESHOLD = 70.0;

/// Avatar growth constants
const double GROWTH_POINTS_BASE = 10.0;
const double OVERTRAINING_PENALTY = 0.5; // 50% reduction in growth points
const double OPTIMAL_RECOVERY_BONUS = 1.5; // 50% bonus for optimal timing

/// Deload recommendation thresholds
const double VOLUME_INCREASE_THRESHOLD = 0.20; // 20% increase over 4 weeks
const int HIGH_FATIGUE_GROUPS_THRESHOLD = 3; // Number of muscle groups
const double CHRONIC_FATIGUE_THRESHOLD = 80.0;

/// Performance thresholds for UI responsiveness
const Duration MAX_SET_SAVE_DURATION = Duration(milliseconds: 150);
const Duration MAX_HOME_LOAD_DURATION = Duration(milliseconds: 500);

/// Validation constants
const int MIN_WEIGHT_KG = 0;
const int MAX_WEIGHT_KG = 1000;
const int MIN_REPS = 1;
const int MAX_REPS = 100;
const int MIN_REST_SECONDS = 0;
const int MAX_REST_SECONDS = 3600; // 1 hour

/// Progression detection constants
const double MIN_WEIGHT_PROGRESSION_KG = 2.5;
const int MIN_REP_PROGRESSION = 1;

/// Mathematical constants for calculations
const double E = 2.718281828459045; // Euler's number for exponential decay

/// List of all muscle group IDs for initialization
const List<String> MUSCLE_GROUP_IDS = [
  'chest',
  'back',
  'quadriceps',
  'hamstrings',
  'glutes',
  'shoulders',
  'delts_anterior',
  'delts_medial',
  'delts_posterior',
  'biceps',
  'triceps',
  'forearms',
  'lats',
  'traps',
  'rhomboids',
  'rear_delts',
  'calves',
  'tibialis',
  'abs',
  'obliques',
  'lower_back',
  'serratus',
  'hip_flexors',
  'adductors',
  'abductors',
];

/// Utility functions for fatigue and recovery calculations
class FatigueCalculations {
  /// Calculates fatigue score based on volume, intensity, RPE, and muscle group
  static double calculateFatigueScore({
    required double volume, // sets × reps × weight
    required double intensity, // RPE-based intensity factor
    required int rpe,
    required String muscleGroupId,
  }) {
    final rpeIntensityFactor = (rpe - 5) / 5.0; // Maps RPE 6-10 to 0.2-1.0
    final rpeFactor = rpe / 10.0;
    final muscleMultiplier = FATIGUE_MULTIPLIERS[muscleGroupId] ?? 1.0;
    
    return volume * rpeIntensityFactor * rpeFactor * muscleMultiplier;
  }
  
  /// Calculates recovery using exponential decay model
  static double calculateRecovery({
    required double initialFatigue,
    required double timeElapsedHours,
    required String muscleGroupId,
  }) {
    final tau = RECOVERY_TAU[muscleGroupId] ?? 48.0;
    return initialFatigue * math.exp(-timeElapsedHours / tau);
  }
  
  /// Determines readiness level from current fatigue score
  static ReadinessLevel getReadinessLevel(double fatigueScore) {
    if (fatigueScore < READY_THRESHOLD) return ReadinessLevel.ready;
    if (fatigueScore < WARM_THRESHOLD) return ReadinessLevel.warm;
    return ReadinessLevel.fatigued;
  }
  
  /// Calculates estimated 1RM using Epley formula
  static double calculateEstimated1RM(double weight, int reps) {
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }
  
  /// Calculates volume (weight × reps × sets)
  static double calculateVolume({
    required double weight,
    required int reps,
    required int sets,
  }) {
    return weight * reps * sets;
  }
}