import 'package:freezed_annotation/freezed_annotation.dart';

part 'streak_record.freezed.dart';
part 'streak_record.g.dart';

@freezed
class StreakRecord with _$StreakRecord {
  const factory StreakRecord({
    required String id,
    required String userId,
    required StreakType streakType,
    required int currentStreak,
    required int longestStreak,
    required DateTime lastWorkoutDate,
    required DateTime streakStartDate,
    DateTime? streakEndDate, // null if streak is active
    @Default([]) List<StreakMilestone> milestones,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _StreakRecord;

  const StreakRecord._();

  factory StreakRecord.fromJson(Map<String, dynamic> json) => 
      _$StreakRecordFromJson(json);

  /// Validates streak record data
  String? validate() {
    if (id.isEmpty) return 'Streak record ID cannot be empty';
    if (userId.isEmpty) return 'User ID cannot be empty';
    if (currentStreak < 0) return 'Current streak cannot be negative';
    if (longestStreak < 0) return 'Longest streak cannot be negative';
    if (longestStreak < currentStreak) return 'Longest streak cannot be less than current streak';
    if (lastWorkoutDate.isAfter(DateTime.now())) {
      return 'Last workout date cannot be in the future';
    }
    if (streakStartDate.isAfter(lastWorkoutDate)) {
      return 'Streak start date cannot be after last workout date';
    }
    if (streakEndDate != null && streakEndDate!.isBefore(streakStartDate)) {
      return 'Streak end date cannot be before start date';
    }
    return null;
  }

  /// Checks if the streak record data is valid
  bool get isValid => validate() == null;

  /// Checks if the streak is currently active
  bool get isActive => streakEndDate == null;

  /// Gets the duration of the current streak
  Duration get streakDuration {
    final endDate = streakEndDate ?? DateTime.now();
    return endDate.difference(streakStartDate);
  }

  /// Checks if the streak is broken (more than 48 hours since last workout)
  bool get isBroken {
    final now = DateTime.now();
    final hoursSinceLastWorkout = now.difference(lastWorkoutDate).inHours;
    return hoursSinceLastWorkout > 48; // Allow 48 hours between workouts
  }

  /// Gets the next milestone target
  int? get nextMilestone {
    final achievedMilestones = milestones.map((m) => m.streakCount).toSet();
    const milestoneTargets = [3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 365];
    
    for (final target in milestoneTargets) {
      if (!achievedMilestones.contains(target) && target > currentStreak) {
        return target;
      }
    }
    
    // If all predefined milestones are achieved, next is every 100 days
    return ((currentStreak ~/ 100) + 1) * 100;
  }

  /// Gets days until next milestone
  int? get daysToNextMilestone {
    final next = nextMilestone;
    return next != null ? next - currentStreak : null;
  }

  /// Updates the streak with a new workout
  StreakRecord updateWithWorkout(DateTime workoutDate) {
    final now = DateTime.now();
    final daysSinceLastWorkout = workoutDate.difference(lastWorkoutDate).inDays;
    
    // If workout is on the same day, don't update streak count
    if (daysSinceLastWorkout == 0) {
      return copyWith(
        lastWorkoutDate: workoutDate,
        updatedAt: now,
      );
    }
    
    // If workout is consecutive (next day), increment streak
    if (daysSinceLastWorkout == 1) {
      final newStreak = currentStreak + 1;
      final newLongestStreak = newStreak > longestStreak ? newStreak : longestStreak;
      
      // Check for new milestones
      final newMilestones = List<StreakMilestone>.from(milestones);
      final nextMilestoneTarget = nextMilestone;
      
      if (nextMilestoneTarget != null && newStreak >= nextMilestoneTarget) {
        newMilestones.add(StreakMilestone(
          id: 'milestone_${userId}_${nextMilestoneTarget}_${now.millisecondsSinceEpoch}',
          streakCount: nextMilestoneTarget,
          achievedAt: workoutDate,
          milestoneType: _getMilestoneType(nextMilestoneTarget),
        ));
      }
      
      return copyWith(
        currentStreak: newStreak,
        longestStreak: newLongestStreak,
        lastWorkoutDate: workoutDate,
        milestones: newMilestones,
        updatedAt: now,
      );
    }
    
    // If gap is more than 1 day, reset streak
    return copyWith(
      currentStreak: 1,
      lastWorkoutDate: workoutDate,
      streakStartDate: workoutDate,
      streakEndDate: null, // Reset end date as streak is active again
      updatedAt: now,
    );
  }

  /// Breaks the current streak
  StreakRecord breakStreak() {
    if (!isActive) return this; // Already broken
    
    return copyWith(
      streakEndDate: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Gets streak status description
  String get statusDescription {
    if (!isActive) return 'Streak ended';
    if (isBroken) return 'Streak at risk';
    if (currentStreak == 0) return 'No active streak';
    if (currentStreak == 1) return '1 day streak';
    return '$currentStreak day streak';
  }

  /// Gets encouragement message based on streak status
  String get encouragementMessage {
    if (isBroken) {
      return 'Don\'t give up! Start a new streak today.';
    }
    
    final next = nextMilestone;
    if (next != null) {
      final days = daysToNextMilestone!;
      if (days <= 3) {
        return 'You\'re so close! Only $days more days to reach $next days!';
      } else if (days <= 7) {
        return 'Keep it up! $days more days to reach $next days.';
      } else {
        return 'Great progress! Next milestone: $next days.';
      }
    }
    
    return 'Amazing streak! Keep up the great work!';
  }

  /// Gets the most recent milestone
  StreakMilestone? get latestMilestone {
    if (milestones.isEmpty) return null;
    return milestones.reduce((a, b) => 
        a.achievedAt.isAfter(b.achievedAt) ? a : b);
  }

  /// Checks if a milestone was recently achieved (within last 24 hours)
  bool get hasRecentMilestone {
    final latest = latestMilestone;
    if (latest == null) return false;
    
    final hoursSinceAchievement = DateTime.now().difference(latest.achievedAt).inHours;
    return hoursSinceAchievement <= 24;
  }

  MilestoneType _getMilestoneType(int streakCount) {
    if (streakCount <= 7) return MilestoneType.weekly;
    if (streakCount <= 30) return MilestoneType.monthly;
    if (streakCount <= 100) return MilestoneType.milestone;
    return MilestoneType.legendary;
  }
}

@freezed
class StreakMilestone with _$StreakMilestone {
  const factory StreakMilestone({
    required String id,
    required int streakCount,
    required DateTime achievedAt,
    required MilestoneType milestoneType,
    String? customMessage,
  }) = _StreakMilestone;

  const StreakMilestone._();

  factory StreakMilestone.fromJson(Map<String, dynamic> json) => 
      _$StreakMilestoneFromJson(json);

  /// Gets the milestone title
  String get title {
    switch (milestoneType) {
      case MilestoneType.weekly:
        return '$streakCount Day${streakCount > 1 ? 's' : ''} Strong!';
      case MilestoneType.monthly:
        return '$streakCount Day Champion!';
      case MilestoneType.milestone:
        return '$streakCount Day Warrior!';
      case MilestoneType.legendary:
        return '$streakCount Day Legend!';
    }
  }

  /// Gets the milestone description
  String get description {
    if (customMessage != null) return customMessage!;
    
    switch (milestoneType) {
      case MilestoneType.weekly:
        return 'You\'ve built a solid habit!';
      case MilestoneType.monthly:
        return 'Your consistency is paying off!';
      case MilestoneType.milestone:
        return 'You\'re becoming unstoppable!';
      case MilestoneType.legendary:
        return 'You\'re a true fitness legend!';
    }
  }

  /// Gets the milestone icon
  String get icon {
    switch (milestoneType) {
      case MilestoneType.weekly:
        return '🔥';
      case MilestoneType.monthly:
        return '💪';
      case MilestoneType.milestone:
        return '🏆';
      case MilestoneType.legendary:
        return '👑';
    }
  }
}

enum StreakType {
  workout,      // Any workout
  strength,     // Strength training only
  cardio,       // Cardio only
  custom,       // Custom streak type
}

enum MilestoneType {
  weekly,       // 3-7 days
  monthly,      // 8-30 days
  milestone,    // 31-100 days
  legendary,    // 100+ days
}