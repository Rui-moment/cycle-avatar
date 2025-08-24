import 'dart:math' as math;
import '../entities/enums.dart';
import '../entities/constants.dart';
import '../entities/workout_session.dart';
import '../entities/recovery_state.dart';

/// Service for detecting when deload weeks should be recommended
/// based on volume progression and chronic fatigue indicators
class DeloadDetector {
  /// Analyzes training data to determine if deload is recommended
  DeloadRecommendation analyzeDeloadNeed({
    required List<WorkoutSession> recentSessions,
    required Map<String, RecoveryState> currentRecoveryStates,
    int analysisWeeks = 4,
  }) {
    if (recentSessions.length < 8) {
      return DeloadRecommendation.notNeeded(
        reason: 'Insufficient training history for deload analysis',
      );
    }

    // Calculate volume progression over the analysis period
    final volumeAnalysis = calculateVolumeProgression(
      sessions: recentSessions,
      weeks: analysisWeeks,
    );

    // Analyze chronic fatigue patterns
    final fatigueAnalysis = analyzeChronicFatigue(
      recoveryStates: currentRecoveryStates,
      recentSessions: recentSessions,
    );

    // Check for performance stagnation
    final performanceAnalysis = analyzePerformanceStagnation(
      sessions: recentSessions,
      weeks: 2,
    );

    // Determine deload recommendation based on multiple factors
    return _determineDeloadRecommendation(
      volumeAnalysis: volumeAnalysis,
      fatigueAnalysis: fatigueAnalysis,
      performanceAnalysis: performanceAnalysis,
    );
  }

  /// Calculates volume progression over specified weeks
  VolumeProgressionAnalysis calculateVolumeProgression({
    required List<WorkoutSession> sessions,
    int weeks = 4,
  }) {
    final now = DateTime.now();
    final analysisStart = now.subtract(Duration(days: weeks * 7));
    
    // Filter sessions within analysis period
    final relevantSessions = sessions
        .where((session) => session.startTime.isAfter(analysisStart))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (relevantSessions.length < 4) {
      return VolumeProgressionAnalysis(
        weeklyVolumes: [],
        totalVolumeIncrease: 0.0,
        averageWeeklyIncrease: 0.0,
        isExcessiveIncrease: false,
      );
    }

    // Group sessions by week
    final weeklyVolumes = <double>[];
    final weeklySessionCounts = <int>[];
    
    for (int week = 0; week < weeks; week++) {
      final weekStart = analysisStart.add(Duration(days: week * 7));
      final weekEnd = weekStart.add(const Duration(days: 7));
      
      final weekSessions = relevantSessions
          .where((session) => 
              session.startTime.isAfter(weekStart) && 
              session.startTime.isBefore(weekEnd))
          .toList();
      
      final weekVolume = weekSessions.fold(0.0, (sum, session) => sum + session.totalVolume);
      weeklyVolumes.add(weekVolume);
      weeklySessionCounts.add(weekSessions.length);
    }

    // Calculate progression metrics
    final totalVolumeIncrease = _calculateTotalVolumeIncrease(weeklyVolumes);
    final averageWeeklyIncrease = _calculateAverageWeeklyIncrease(weeklyVolumes);
    final isExcessiveIncrease = totalVolumeIncrease > VOLUME_INCREASE_THRESHOLD;

    return VolumeProgressionAnalysis(
      weeklyVolumes: weeklyVolumes,
      totalVolumeIncrease: totalVolumeIncrease,
      averageWeeklyIncrease: averageWeeklyIncrease,
      isExcessiveIncrease: isExcessiveIncrease,
      weeklySessionCounts: weeklySessionCounts,
    );
  }

  /// Analyzes chronic fatigue patterns across muscle groups
  ChronicFatigueAnalysis analyzeChronicFatigue({
    required Map<String, RecoveryState> recoveryStates,
    required List<WorkoutSession> recentSessions,
  }) {
    final highFatigueMuscleGroups = <String>[];
    final moderateFatigueMuscleGroups = <String>[];
    var totalFatigueScore = 0.0;
    var averageRecoveryPercentage = 0.0;

    // Analyze current fatigue levels
    for (final entry in recoveryStates.entries) {
      final muscleGroupId = entry.key;
      final recoveryState = entry.value;
      
      totalFatigueScore += recoveryState.currentFatigue;
      averageRecoveryPercentage += recoveryState.recoveryPercentage;

      if (recoveryState.currentFatigue > CHRONIC_FATIGUE_THRESHOLD) {
        highFatigueMuscleGroups.add(muscleGroupId);
      } else if (recoveryState.currentFatigue > WARM_THRESHOLD) {
        moderateFatigueMuscleGroups.add(muscleGroupId);
      }
    }

    if (recoveryStates.isNotEmpty) {
      averageRecoveryPercentage /= recoveryStates.length;
    }

    // Analyze fatigue persistence over time
    final fatiguePersistence = _analyzeFatiguePersistence(
      recoveryStates: recoveryStates,
      recentSessions: recentSessions,
    );

    return ChronicFatigueAnalysis(
      highFatigueMuscleGroups: highFatigueMuscleGroups,
      moderateFatigueMuscleGroups: moderateFatigueMuscleGroups,
      totalFatigueScore: totalFatigueScore,
      averageRecoveryPercentage: averageRecoveryPercentage,
      fatiguePersistenceDays: fatiguePersistence,
      isChronicFatiguePresent: highFatigueMuscleGroups.length >= HIGH_FATIGUE_GROUPS_THRESHOLD,
    );
  }

  /// Analyzes performance stagnation indicators
  PerformanceStagnationAnalysis analyzePerformanceStagnation({
    required List<WorkoutSession> sessions,
    int weeks = 2,
  }) {
    final now = DateTime.now();
    final analysisStart = now.subtract(Duration(days: weeks * 7));
    
    final recentSessions = sessions
        .where((session) => session.startTime.isAfter(analysisStart))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (recentSessions.length < 4) {
      return PerformanceStagnationAnalysis(
        averageRPEIncrease: 0.0,
        volumeToRPERatio: 0.0,
        isPerformanceStagnant: false,
        stagnantExercises: [],
      );
    }

    // Calculate RPE trends
    final rpeProgression = _calculateRPEProgression(recentSessions);
    
    // Calculate volume to RPE ratio (efficiency metric)
    final volumeToRPERatio = _calculateVolumeToRPERatio(recentSessions);
    
    // Identify stagnant exercises
    final stagnantExercises = _identifyStagnantExercises(recentSessions);

    return PerformanceStagnationAnalysis(
      averageRPEIncrease: rpeProgression,
      volumeToRPERatio: volumeToRPERatio,
      isPerformanceStagnant: rpeProgression > 1.0 || stagnantExercises.length >= 2,
      stagnantExercises: stagnantExercises,
    );
  }

  /// Determines final deload recommendation based on all analyses
  DeloadRecommendation _determineDeloadRecommendation({
    required VolumeProgressionAnalysis volumeAnalysis,
    required ChronicFatigueAnalysis fatigueAnalysis,
    required PerformanceStagnationAnalysis performanceAnalysis,
  }) {
    final reasons = <String>[];
    var priority = DeloadPriority.low;

    // Check volume progression
    if (volumeAnalysis.isExcessiveIncrease) {
      reasons.add('Volume increased by ${(volumeAnalysis.totalVolumeIncrease * 100).toStringAsFixed(1)}% over 4 weeks');
      priority = DeloadPriority.medium;
    }

    // Check chronic fatigue
    if (fatigueAnalysis.isChronicFatiguePresent) {
      reasons.add('${fatigueAnalysis.highFatigueMuscleGroups.length} muscle groups showing chronic fatigue');
      priority = DeloadPriority.high;
    }

    // Check performance stagnation
    if (performanceAnalysis.isPerformanceStagnant) {
      reasons.add('Performance stagnation detected (RPE increasing without volume gains)');
      if (priority == DeloadPriority.low) priority = DeloadPriority.medium;
    }

    // Check for multiple moderate indicators
    final moderateIndicators = [
      volumeAnalysis.averageWeeklyIncrease > 0.1,
      fatigueAnalysis.averageRecoveryPercentage < 0.7,
      performanceAnalysis.volumeToRPERatio < 0.8,
    ].where((indicator) => indicator).length;

    if (moderateIndicators >= 2 && priority == DeloadPriority.low) {
      reasons.add('Multiple moderate fatigue indicators present');
      priority = DeloadPriority.medium;
    }

    // Determine recommendation
    if (reasons.isEmpty) {
      return DeloadRecommendation.notNeeded(
        reason: 'Training load and recovery are well balanced',
      );
    }

    return DeloadRecommendation.needed(
      priority: priority,
      reasons: reasons,
      recommendedDuration: _calculateRecommendedDeloadDuration(priority),
      volumeReduction: _calculateRecommendedVolumeReduction(priority),
      intensityReduction: _calculateRecommendedIntensityReduction(priority),
    );
  }

  /// Calculates total volume increase over the analysis period
  double _calculateTotalVolumeIncrease(List<double> weeklyVolumes) {
    if (weeklyVolumes.length < 2) return 0.0;
    
    // Compare first week to last week
    final firstWeek = weeklyVolumes.first;
    final lastWeek = weeklyVolumes.last;
    
    if (firstWeek <= 0) return 0.0;
    return (lastWeek - firstWeek) / firstWeek;
  }

  /// Calculates average weekly volume increase
  double _calculateAverageWeeklyIncrease(List<double> weeklyVolumes) {
    if (weeklyVolumes.length < 2) return 0.0;
    
    var totalIncrease = 0.0;
    var validComparisons = 0;
    
    for (int i = 1; i < weeklyVolumes.length; i++) {
      if (weeklyVolumes[i - 1] > 0) {
        totalIncrease += (weeklyVolumes[i] - weeklyVolumes[i - 1]) / weeklyVolumes[i - 1];
        validComparisons++;
      }
    }
    
    return validComparisons > 0 ? totalIncrease / validComparisons : 0.0;
  }

  /// Analyzes how long muscle groups have been in high fatigue state
  int _analyzeFatiguePersistence({
    required Map<String, RecoveryState> recoveryStates,
    required List<WorkoutSession> recentSessions,
  }) {
    // Simplified implementation - in real app would track fatigue history
    final highFatigueCount = recoveryStates.values
        .where((state) => state.currentFatigue > CHRONIC_FATIGUE_THRESHOLD)
        .length;
    
    // Estimate persistence based on recent session frequency and fatigue levels
    if (highFatigueCount >= HIGH_FATIGUE_GROUPS_THRESHOLD) {
      return 7; // Assume 7 days of persistence for high fatigue
    }
    
    return 0;
  }

  /// Calculates RPE progression over recent sessions
  double _calculateRPEProgression(List<WorkoutSession> sessions) {
    if (sessions.length < 4) return 0.0;
    
    final firstHalf = sessions.take(sessions.length ~/ 2).toList();
    final secondHalf = sessions.skip(sessions.length ~/ 2).toList();
    
    final firstHalfRPE = firstHalf.fold(0.0, (sum, session) => sum + session.averageRPE) / firstHalf.length;
    final secondHalfRPE = secondHalf.fold(0.0, (sum, session) => sum + session.averageRPE) / secondHalf.length;
    
    return secondHalfRPE - firstHalfRPE;
  }

  /// Calculates volume to RPE ratio as efficiency metric
  double _calculateVolumeToRPERatio(List<WorkoutSession> sessions) {
    if (sessions.isEmpty) return 0.0;
    
    final totalVolume = sessions.fold(0.0, (sum, session) => sum + session.totalVolume);
    final totalRPE = sessions.fold(0.0, (sum, session) => sum + session.averageRPE);
    
    if (totalRPE <= 0) return 0.0;
    return totalVolume / totalRPE;
  }

  /// Identifies exercises showing performance stagnation
  List<String> _identifyStagnantExercises(List<WorkoutSession> sessions) {
    final exercisePerformance = <String, List<double>>{};
    
    // Collect performance data for each exercise
    for (final session in sessions) {
      for (final set in session.sets) {
        exercisePerformance.putIfAbsent(set.exerciseId, () => []).add(set.volume);
      }
    }
    
    final stagnantExercises = <String>[];
    
    // Check for stagnation (no improvement in volume)
    for (final entry in exercisePerformance.entries) {
      final volumes = entry.value;
      if (volumes.length >= 4) {
        final firstHalf = volumes.take(volumes.length ~/ 2).toList();
        final secondHalf = volumes.skip(volumes.length ~/ 2).toList();
        
        final firstAvg = firstHalf.fold(0.0, (sum, vol) => sum + vol) / firstHalf.length;
        final secondAvg = secondHalf.fold(0.0, (sum, vol) => sum + vol) / secondHalf.length;
        
        // Consider stagnant if no improvement or decline
        if (secondAvg <= firstAvg * 1.02) { // Less than 2% improvement
          stagnantExercises.add(entry.key);
        }
      }
    }
    
    return stagnantExercises;
  }

  /// Calculates recommended deload duration based on priority
  int _calculateRecommendedDeloadDuration(DeloadPriority priority) {
    switch (priority) {
      case DeloadPriority.low:
        return 3; // 3 days
      case DeloadPriority.medium:
        return 5; // 5 days
      case DeloadPriority.high:
        return 7; // Full week
    }
  }

  /// Calculates recommended volume reduction percentage
  double _calculateRecommendedVolumeReduction(DeloadPriority priority) {
    switch (priority) {
      case DeloadPriority.low:
        return 0.3; // 30% reduction
      case DeloadPriority.medium:
        return 0.4; // 40% reduction
      case DeloadPriority.high:
        return 0.5; // 50% reduction
    }
  }

  /// Calculates recommended intensity reduction
  int _calculateRecommendedIntensityReduction(DeloadPriority priority) {
    switch (priority) {
      case DeloadPriority.low:
        return 1; // Reduce RPE by 1
      case DeloadPriority.medium:
        return 2; // Reduce RPE by 2
      case DeloadPriority.high:
        return 3; // Reduce RPE by 3
    }
  }
}

/// Analysis of volume progression over time
class VolumeProgressionAnalysis {
  final List<double> weeklyVolumes;
  final double totalVolumeIncrease;
  final double averageWeeklyIncrease;
  final bool isExcessiveIncrease;
  final List<int>? weeklySessionCounts;

  const VolumeProgressionAnalysis({
    required this.weeklyVolumes,
    required this.totalVolumeIncrease,
    required this.averageWeeklyIncrease,
    required this.isExcessiveIncrease,
    this.weeklySessionCounts,
  });

  /// Gets the trend direction of volume progression
  VolumeTrend get trend {
    if (totalVolumeIncrease > 0.1) return VolumeTrend.increasing;
    if (totalVolumeIncrease < -0.1) return VolumeTrend.decreasing;
    return VolumeTrend.stable;
  }
}

/// Analysis of chronic fatigue patterns
class ChronicFatigueAnalysis {
  final List<String> highFatigueMuscleGroups;
  final List<String> moderateFatigueMuscleGroups;
  final double totalFatigueScore;
  final double averageRecoveryPercentage;
  final int fatiguePersistenceDays;
  final bool isChronicFatiguePresent;

  const ChronicFatigueAnalysis({
    required this.highFatigueMuscleGroups,
    required this.moderateFatigueMuscleGroups,
    required this.totalFatigueScore,
    required this.averageRecoveryPercentage,
    required this.fatiguePersistenceDays,
    required this.isChronicFatiguePresent,
  });

  /// Gets the overall fatigue severity level
  FatigueSeverity get severity {
    if (highFatigueMuscleGroups.length >= 4) return FatigueSeverity.severe;
    if (highFatigueMuscleGroups.length >= 2) return FatigueSeverity.moderate;
    if (moderateFatigueMuscleGroups.length >= 3) return FatigueSeverity.mild;
    return FatigueSeverity.none;
  }
}

/// Analysis of performance stagnation indicators
class PerformanceStagnationAnalysis {
  final double averageRPEIncrease;
  final double volumeToRPERatio;
  final bool isPerformanceStagnant;
  final List<String> stagnantExercises;

  const PerformanceStagnationAnalysis({
    required this.averageRPEIncrease,
    required this.volumeToRPERatio,
    required this.isPerformanceStagnant,
    required this.stagnantExercises,
  });
}

/// Deload recommendation with priority and specific guidance
class DeloadRecommendation {
  final bool isNeeded;
  final DeloadPriority priority;
  final List<String> reasons;
  final String primaryReason;
  final int recommendedDurationDays;
  final double volumeReduction;
  final int intensityReduction;

  const DeloadRecommendation({
    required this.isNeeded,
    required this.priority,
    required this.reasons,
    required this.primaryReason,
    required this.recommendedDurationDays,
    required this.volumeReduction,
    required this.intensityReduction,
  });

  factory DeloadRecommendation.needed({
    required DeloadPriority priority,
    required List<String> reasons,
    required int recommendedDuration,
    required double volumeReduction,
    required int intensityReduction,
  }) {
    return DeloadRecommendation(
      isNeeded: true,
      priority: priority,
      reasons: reasons,
      primaryReason: reasons.isNotEmpty ? reasons.first : 'Deload recommended',
      recommendedDurationDays: recommendedDuration,
      volumeReduction: volumeReduction,
      intensityReduction: intensityReduction,
    );
  }

  factory DeloadRecommendation.notNeeded({required String reason}) {
    return DeloadRecommendation(
      isNeeded: false,
      priority: DeloadPriority.low,
      reasons: [],
      primaryReason: reason,
      recommendedDurationDays: 0,
      volumeReduction: 0.0,
      intensityReduction: 0,
    );
  }

  /// Gets formatted volume reduction as percentage
  String get formattedVolumeReduction => '${(volumeReduction * 100).toStringAsFixed(0)}%';

  /// Gets formatted duration
  String get formattedDuration {
    if (recommendedDurationDays >= 7) {
      return '${recommendedDurationDays ~/ 7} week${recommendedDurationDays ~/ 7 > 1 ? 's' : ''}';
    }
    return '$recommendedDurationDays day${recommendedDurationDays > 1 ? 's' : ''}';
  }
}

/// Priority levels for deload recommendations
enum DeloadPriority {
  low,
  medium,
  high;

  String getLocalizedName(String locale) {
    switch (this) {
      case DeloadPriority.low:
        return locale == 'ja' ? '低' : 'Low';
      case DeloadPriority.medium:
        return locale == 'ja' ? '中' : 'Medium';
      case DeloadPriority.high:
        return locale == 'ja' ? '高' : 'High';
    }
  }
}

/// Volume progression trends
enum VolumeTrend {
  increasing,
  stable,
  decreasing;

  String getLocalizedName(String locale) {
    switch (this) {
      case VolumeTrend.increasing:
        return locale == 'ja' ? '増加' : 'Increasing';
      case VolumeTrend.stable:
        return locale == 'ja' ? '安定' : 'Stable';
      case VolumeTrend.decreasing:
        return locale == 'ja' ? '減少' : 'Decreasing';
    }
  }
}

/// Fatigue severity levels
enum FatigueSeverity {
  none,
  mild,
  moderate,
  severe;

  String getLocalizedName(String locale) {
    switch (this) {
      case FatigueSeverity.none:
        return locale == 'ja' ? 'なし' : 'None';
      case FatigueSeverity.mild:
        return locale == 'ja' ? '軽度' : 'Mild';
      case FatigueSeverity.moderate:
        return locale == 'ja' ? '中度' : 'Moderate';
      case FatigueSeverity.severe:
        return locale == 'ja' ? '重度' : 'Severe';
    }
  }
}