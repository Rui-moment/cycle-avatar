import 'dart:math' as math;
import '../entities/enums.dart';
import '../entities/constants.dart';
import '../entities/avatar_state.dart';
import '../entities/workout_session.dart';
import '../entities/exercise.dart';
import '../entities/recovery_state.dart';
import '../entities/pr_record.dart';
import 'badge_system.dart';

/// System for managing avatar growth based on training progression
/// and recovery optimization
class AvatarSystem {
  /// Determines if progression was achieved in a workout session
  /// Checks for weight or rep progression compared to previous sessions
  bool hasAchievedProgression({
    required WorkoutSession currentSession,
    required List<WorkoutSession> previousSessions,
    required Map<String, Exercise> exercises,
  }) {
    if (currentSession.sets.isEmpty) return false;
    
    // Group current sets by exercise
    final currentSetsByExercise = <String, List<WorkoutSet>>{};
    for (final set in currentSession.sets) {
      currentSetsByExercise.putIfAbsent(set.exerciseId, () => []).add(set);
    }
    
    // Check progression for each exercise
    for (final entry in currentSetsByExercise.entries) {
      final exerciseId = entry.key;
      final currentSets = entry.value;
      
      // Get previous sets for this exercise (from last 2 sessions)
      final previousSets = _getPreviousSetsForExercise(
        exerciseId: exerciseId,
        previousSessions: previousSessions,
        maxSessions: 2,
      );
      
      if (previousSets.isEmpty) {
        // First time doing this exercise counts as progression
        return true;
      }
      
      // Check if any set shows progression
      for (final currentSet in currentSets) {
        if (_isSetProgression(currentSet, previousSets)) {
          return true;
        }
      }
    }
    
    return false;
  }

  /// Determines if avatar should level up based on progression and recovery state
  bool shouldLevelUp({
    required WorkoutSession session,
    required Map<String, ReadinessLevel> preWorkoutReadiness,
    required bool achievedProgression,
    required Map<String, Exercise> exercises,
  }) {
    if (!achievedProgression) return false;
    
    // Get muscle groups targeted in this session
    final targetedMuscleGroups = _getTargetedMuscleGroups(session, exercises);
    
    // Check if any targeted muscle group was in optimal state
    for (final muscleGroupId in targetedMuscleGroups) {
      final readiness = preWorkoutReadiness[muscleGroupId] ?? ReadinessLevel.fatigued;
      if (readiness == ReadinessLevel.ready) {
        return true; // At least one muscle group was optimally recovered
      }
    }
    
    return false;
  }

  /// Calculates growth points to award based on progression and recovery state
  Map<String, double> calculateGrowthPoints({
    required WorkoutSession session,
    required Map<String, ReadinessLevel> preWorkoutReadiness,
    required bool achievedProgression,
    required Map<String, Exercise> exercises,
  }) {
    final growthPoints = <String, double>{};
    
    if (!achievedProgression) return growthPoints;
    
    // Get muscle groups targeted in this session with their involvement
    final muscleGroupInvolvement = _getMuscleGroupInvolvement(session, exercises);
    
    for (final entry in muscleGroupInvolvement.entries) {
      final muscleGroupId = entry.key;
      final involvementWeight = entry.value;
      final readiness = preWorkoutReadiness[muscleGroupId] ?? ReadinessLevel.fatigued;
      
      // Calculate base points based on involvement
      final basePoints = GROWTH_POINTS_BASE * involvementWeight;
      
      // Apply readiness multiplier
      final points = AvatarState.calculateGrowthPoints(
        achievedProgression: true,
        preWorkoutReadiness: readiness,
        basePoints: basePoints,
      );
      
      if (points > 0) {
        growthPoints[muscleGroupId] = points;
      }
    }
    
    return growthPoints;
  }

  /// Calculates new level for a muscle group based on growth points
  int calculateNewLevel({
    required String muscleGroupId,
    required int currentLevel,
    required double totalGrowthPoints,
  }) {
    // Use the same formula as AvatarState
    if (totalGrowthPoints <= 0) return currentLevel;
    return math.sqrt(totalGrowthPoints / 100.0).floor();
  }

  /// Determines cooldown duration based on overtraining severity
  Duration calculateCooldownDuration({
    required String muscleGroupId,
    required ReadinessLevel preWorkoutReadiness,
    required int consecutiveOvertrainingDays,
  }) {
    if (preWorkoutReadiness != ReadinessLevel.fatigued) {
      return Duration.zero;
    }
    
    // Base cooldown is the recovery tau for the muscle group
    final baseCooldownHours = RECOVERY_TAU[muscleGroupId] ?? 48.0;
    
    // Increase cooldown based on consecutive overtraining
    final multiplier = 1.0 + (consecutiveOvertrainingDays * 0.2);
    final cooldownHours = baseCooldownHours * multiplier;
    
    return Duration(milliseconds: (cooldownHours * 60 * 60 * 1000).round());
  }

  /// Applies cooldown to avatar state for overtraining
  AvatarState applyCooldown({
    required AvatarState currentState,
    required WorkoutSession session,
    required Map<String, ReadinessLevel> preWorkoutReadiness,
    required Map<String, Exercise> exercises,
  }) {
    var updatedState = currentState;
    
    // Get muscle groups that were overtrained
    final targetedMuscleGroups = _getTargetedMuscleGroups(session, exercises);
    
    for (final muscleGroupId in targetedMuscleGroups) {
      final readiness = preWorkoutReadiness[muscleGroupId] ?? ReadinessLevel.ready;
      
      if (readiness == ReadinessLevel.fatigued) {
        // Calculate consecutive overtraining days (simplified - could be enhanced)
        final consecutiveDays = _calculateConsecutiveOvertrainingDays(
          muscleGroupId: muscleGroupId,
          currentState: currentState,
        );
        
        final cooldownDuration = calculateCooldownDuration(
          muscleGroupId: muscleGroupId,
          preWorkoutReadiness: readiness,
          consecutiveOvertrainingDays: consecutiveDays,
        );
        
        updatedState = updatedState.applyCooldown(
          muscleGroupId: muscleGroupId,
          cooldownDuration: cooldownDuration,
        );
      }
    }
    
    return updatedState;
  }

  /// Updates avatar state after a workout session
  AvatarState updateAvatarAfterWorkout({
    required AvatarState currentState,
    required WorkoutSession session,
    required Map<String, ReadinessLevel> preWorkoutReadiness,
    required Map<String, Exercise> exercises,
    required List<WorkoutSession> previousSessions,
  }) {
    // Check for progression
    final achievedProgression = hasAchievedProgression(
      currentSession: session,
      previousSessions: previousSessions,
      exercises: exercises,
    );
    
    // Calculate growth points
    final growthPoints = calculateGrowthPoints(
      session: session,
      preWorkoutReadiness: preWorkoutReadiness,
      achievedProgression: achievedProgression,
      exercises: exercises,
    );
    
    // Apply growth points to avatar state
    var updatedState = currentState;
    for (final entry in growthPoints.entries) {
      final muscleGroupId = entry.key;
      final points = entry.value;
      
      // Check if muscle group is in cooldown
      final isInCooldown = currentState.isMuscleGroupInCooldown(muscleGroupId);
      final applyPenalty = isInCooldown || 
          preWorkoutReadiness[muscleGroupId] == ReadinessLevel.fatigued;
      
      updatedState = updatedState.addGrowthPoints(
        muscleGroupId: muscleGroupId,
        points: points,
        applyPenalty: applyPenalty,
      );
    }
    
    // Apply cooldown for overtraining
    updatedState = applyCooldown(
      currentState: updatedState,
      session: session,
      preWorkoutReadiness: preWorkoutReadiness,
      exercises: exercises,
    );
    
    return updatedState;
  }

  /// Checks if training in optimal recovery window
  bool isInOptimalRecoveryWindow({
    required Map<String, RecoveryState> recoveryStates,
    required Map<String, Exercise> exercises,
    required WorkoutSession session,
  }) {
    final targetedMuscleGroups = _getTargetedMuscleGroups(session, exercises);
    
    for (final muscleGroupId in targetedMuscleGroups) {
      final recoveryState = recoveryStates[muscleGroupId];
      if (recoveryState == null) continue;
      
      // Check if in optimal recovery window (80-95% recovered)
      final recoveryPercentage = recoveryState.recoveryPercentage;
      if (recoveryPercentage >= 0.8 && recoveryPercentage <= 0.95) {
        return true;
      }
    }
    
    return false;
  }

  /// Gets previous sets for a specific exercise from recent sessions
  List<WorkoutSet> _getPreviousSetsForExercise({
    required String exerciseId,
    required List<WorkoutSession> previousSessions,
    int maxSessions = 2,
  }) {
    final previousSets = <WorkoutSet>[];
    
    // Sort sessions by date (most recent first)
    final sortedSessions = List<WorkoutSession>.from(previousSessions)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    
    int sessionCount = 0;
    for (final session in sortedSessions) {
      if (sessionCount >= maxSessions) break;
      
      final exerciseSets = session.sets
          .where((set) => set.exerciseId == exerciseId)
          .toList();
      
      if (exerciseSets.isNotEmpty) {
        previousSets.addAll(exerciseSets);
        sessionCount++;
      }
    }
    
    return previousSets;
  }

  /// Checks if a set represents progression from previous sets
  bool _isSetProgression(WorkoutSet currentSet, List<WorkoutSet> previousSets) {
    if (previousSets.isEmpty) return true;
    
    // Get best previous performance (highest weight, then highest reps)
    final bestPrevious = previousSets.reduce((a, b) {
      if (a.weight > b.weight) return a;
      if (a.weight == b.weight && a.reps > b.reps) return a;
      return b;
    });
    
    // Check for weight progression
    if (currentSet.weight >= bestPrevious.weight + MIN_WEIGHT_PROGRESSION_KG) {
      return true;
    }
    
    // Check for rep progression at same weight
    if (currentSet.weight == bestPrevious.weight && 
        currentSet.reps >= bestPrevious.reps + MIN_REP_PROGRESSION) {
      return true;
    }
    
    return false;
  }

  /// Gets muscle groups targeted in a workout session
  Set<String> _getTargetedMuscleGroups(
    WorkoutSession session,
    Map<String, Exercise> exercises,
  ) {
    final targetedGroups = <String>{};
    
    for (final set in session.sets) {
      final exercise = exercises[set.exerciseId];
      if (exercise != null) {
        targetedGroups.addAll(exercise.allMuscleGroups);
      }
    }
    
    return targetedGroups;
  }

  /// Gets muscle group involvement weights for a session
  Map<String, double> _getMuscleGroupInvolvement(
    WorkoutSession session,
    Map<String, Exercise> exercises,
  ) {
    final involvement = <String, double>{};
    
    for (final set in session.sets) {
      final exercise = exercises[set.exerciseId];
      if (exercise == null) continue;
      
      // Add primary muscle groups with full weight
      for (final muscleGroupId in exercise.primaryMuscleGroups) {
        involvement[muscleGroupId] = 
            (involvement[muscleGroupId] ?? 0.0) + PRIMARY_MUSCLE_WEIGHT;
      }
      
      // Add secondary muscle groups with reduced weight
      for (final muscleGroupId in exercise.secondaryMuscleGroups) {
        involvement[muscleGroupId] = 
            (involvement[muscleGroupId] ?? 0.0) + SECONDARY_MUSCLE_WEIGHT;
      }
    }
    
    // Normalize by number of sets to get average involvement
    final totalSets = session.sets.length;
    if (totalSets > 0) {
      for (final key in involvement.keys) {
        involvement[key] = involvement[key]! / totalSets;
      }
    }
    
    return involvement;
  }

  /// Processes level-up events and returns level-up information
  Map<String, LevelUpInfo> processLevelUps({
    required AvatarState previousState,
    required AvatarState newState,
  }) {
    final levelUps = <String, LevelUpInfo>{};
    
    for (final entry in newState.muscleGroupLevels.entries) {
      final muscleGroupId = entry.key;
      final newLevel = entry.value;
      final previousLevel = previousState.muscleGroupLevels[muscleGroupId] ?? 0;
      
      if (newLevel > previousLevel) {
        levelUps[muscleGroupId] = LevelUpInfo(
          muscleGroupId: muscleGroupId,
          previousLevel: previousLevel,
          newLevel: newLevel,
          levelsGained: newLevel - previousLevel,
          timestamp: DateTime.now(),
        );
      }
    }
    
    return levelUps;
  }

  /// Calculates muscle group level update based on new growth points
  Map<String, int> calculateLevelUpdates({
    required AvatarState currentState,
    required Map<String, double> newGrowthPoints,
  }) {
    final levelUpdates = <String, int>{};
    
    for (final entry in newGrowthPoints.entries) {
      final muscleGroupId = entry.key;
      final additionalPoints = entry.value;
      final currentPoints = currentState.getGrowthPointsForMuscleGroup(muscleGroupId);
      final totalPoints = currentPoints + additionalPoints;
      
      final newLevel = calculateNewLevel(
        muscleGroupId: muscleGroupId,
        currentLevel: currentState.getLevelForMuscleGroup(muscleGroupId),
        totalGrowthPoints: totalPoints,
      );
      
      levelUpdates[muscleGroupId] = newLevel;
    }
    
    return levelUpdates;
  }

  /// Manages cooldown expiration and cleanup
  AvatarState updateCooldowns({
    required AvatarState currentState,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final updatedCooldowns = <String, DateTime>{};
    
    // Keep only non-expired cooldowns
    for (final entry in currentState.cooldownUntil.entries) {
      final muscleGroupId = entry.key;
      final cooldownEnd = entry.value;
      
      if (now.isBefore(cooldownEnd)) {
        updatedCooldowns[muscleGroupId] = cooldownEnd;
      }
    }
    
    return currentState.copyWith(cooldownUntil: updatedCooldowns);
  }

  /// Checks for badge eligibility and awards new badges
  AvatarState awardNewBadges({
    required AvatarState currentState,
    required WorkoutSession session,
    required List<WorkoutSession> allSessions,
    required List<PRRecord> prRecords,
    required int currentStreak,
  }) {
    final badgeSystem = BadgeSystem();
    
    final newBadges = badgeSystem.checkForNewBadges(
      currentState: currentState,
      session: session,
      allSessions: allSessions,
      prRecords: prRecords,
      currentStreak: currentStreak,
    );
    
    var updatedState = currentState;
    for (final badgeId in newBadges) {
      updatedState = updatedState.unlockBadge(badgeId);
    }
    
    return updatedState;
  }

  /// Comprehensive avatar update after workout including badges
  AvatarUpdateResult updateAvatarComprehensive({
    required AvatarState currentState,
    required WorkoutSession session,
    required Map<String, ReadinessLevel> preWorkoutReadiness,
    required Map<String, Exercise> exercises,
    required List<WorkoutSession> previousSessions,
    required List<PRRecord> prRecords,
    required int currentStreak,
  }) {
    // Update avatar after workout
    final updatedAvatar = updateAvatarAfterWorkout(
      currentState: currentState,
      session: session,
      preWorkoutReadiness: preWorkoutReadiness,
      exercises: exercises,
      previousSessions: previousSessions,
    );
    
    // Award new badges
    final avatarWithBadges = awardNewBadges(
      currentState: updatedAvatar,
      session: session,
      allSessions: [...previousSessions, session],
      prRecords: prRecords,
      currentStreak: currentStreak,
    );
    
    // Update cooldowns
    final finalAvatar = updateCooldowns(currentState: avatarWithBadges);
    
    // Process level-ups
    final levelUps = processLevelUps(
      previousState: currentState,
      newState: finalAvatar,
    );
    
    // Get newly awarded badges
    final newBadges = finalAvatar.unlockedBadges
        .where((badge) => !currentState.unlockedBadges.contains(badge))
        .toList();
    
    return AvatarUpdateResult(
      updatedState: finalAvatar,
      levelUps: levelUps,
      newBadges: newBadges,
      achievedProgression: hasAchievedProgression(
        currentSession: session,
        previousSessions: previousSessions,
        exercises: exercises,
      ),
    );
  }

  /// Calculates consecutive overtraining days for a muscle group
  int _calculateConsecutiveOvertrainingDays({
    required String muscleGroupId,
    required AvatarState currentState,
  }) {
    // Simplified implementation - in a real app, this would check workout history
    // For now, return 0 if not in cooldown, 1 if in cooldown
    return currentState.isMuscleGroupInCooldown(muscleGroupId) ? 1 : 0;
  }
}

/// Information about a level-up event
class LevelUpInfo {
  final String muscleGroupId;
  final int previousLevel;
  final int newLevel;
  final int levelsGained;
  final DateTime timestamp;

  const LevelUpInfo({
    required this.muscleGroupId,
    required this.previousLevel,
    required this.newLevel,
    required this.levelsGained,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'LevelUpInfo(muscle: $muscleGroupId, $previousLevel → $newLevel, +$levelsGained)';
  }
}

/// Result of comprehensive avatar update
class AvatarUpdateResult {
  final AvatarState updatedState;
  final Map<String, LevelUpInfo> levelUps;
  final List<String> newBadges;
  final bool achievedProgression;

  const AvatarUpdateResult({
    required this.updatedState,
    required this.levelUps,
    required this.newBadges,
    required this.achievedProgression,
  });

  /// Checks if any level-ups occurred
  bool get hasLevelUps => levelUps.isNotEmpty;

  /// Checks if any new badges were earned
  bool get hasNewBadges => newBadges.isNotEmpty;

  /// Checks if any rewards were earned (level-ups or badges)
  bool get hasRewards => hasLevelUps || hasNewBadges;

  @override
  String toString() {
    return 'AvatarUpdateResult('
        'levelUps: ${levelUps.length}, '
        'newBadges: ${newBadges.length}, '
        'progression: $achievedProgression'
        ')';
  }
}