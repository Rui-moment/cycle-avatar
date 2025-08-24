import 'package:freezed_annotation/freezed_annotation.dart';

import 'pr_record.dart';
import 'streak_record.dart';

part 'weekly_highlight.freezed.dart';
part 'weekly_highlight.g.dart';

@freezed
class WeeklyHighlight with _$WeeklyHighlight {
  const factory WeeklyHighlight({
    required String id,
    required String userId,
    required DateTime weekStartDate,
    required DateTime weekEndDate,
    required WeeklyStats stats,
    required List<WeeklyAchievement> achievements,
    required List<PRRecord> newPRs,
    required List<StreakMilestone> milestones,
    required WeeklyTrend trend,
    String? motivationalMessage,
    String? weeklyGoal,
    bool? goalAchieved,
    required DateTime createdAt,
  }) = _WeeklyHighlight;

  const WeeklyHighlight._();

  factory WeeklyHighlight.fromJson(Map<String, dynamic> json) => 
      _$WeeklyHighlightFromJson(json);

  /// Validates weekly highlight data
  String? validate() {
    if (id.isEmpty) return 'Weekly highlight ID cannot be empty';
    if (userId.isEmpty) return 'User ID cannot be empty';
    if (weekEndDate.isBefore(weekStartDate)) {
      return 'Week end date cannot be before start date';
    }
    if (weekEndDate.difference(weekStartDate).inDays != 6) {
      return 'Week must be exactly 7 days';
    }
    return null;
  }

  /// Checks if the weekly highlight data is valid
  bool get isValid => validate() == null;

  /// Gets the week number of the year
  int get weekNumber {
    final dayOfYear = weekStartDate.difference(DateTime(weekStartDate.year, 1, 1)).inDays;
    return (dayOfYear / 7).ceil();
  }

  /// Gets a formatted week range string
  String get weekRangeString {
    final startMonth = weekStartDate.month;
    final startDay = weekStartDate.day;
    final endMonth = weekEndDate.month;
    final endDay = weekEndDate.day;
    
    if (startMonth == endMonth) {
      return '${_getMonthName(startMonth)} $startDay-$endDay';
    } else {
      return '${_getMonthName(startMonth)} $startDay - ${_getMonthName(endMonth)} $endDay';
    }
  }

  /// Gets the overall performance rating for the week
  PerformanceRating get performanceRating {
    final score = _calculatePerformanceScore();
    
    if (score >= 90) return PerformanceRating.excellent;
    if (score >= 75) return PerformanceRating.great;
    if (score >= 60) return PerformanceRating.good;
    if (score >= 40) return PerformanceRating.fair;
    return PerformanceRating.needsImprovement;
  }

  /// Gets the performance rating description
  String get performanceDescription {
    switch (performanceRating) {
      case PerformanceRating.excellent:
        return 'Outstanding week! You\'re crushing your goals!';
      case PerformanceRating.great:
        return 'Great week! Keep up the excellent work!';
      case PerformanceRating.good:
        return 'Good week! You\'re making solid progress!';
      case PerformanceRating.fair:
        return 'Fair week. There\'s room for improvement!';
      case PerformanceRating.needsImprovement:
        return 'Challenging week. Let\'s focus on consistency!';
    }
  }

  /// Gets the key highlights for display
  List<String> get keyHighlights {
    final highlights = <String>[];
    
    // Workout frequency
    if (stats.totalSessions >= 5) {
      highlights.add('🔥 ${stats.totalSessions} workouts completed');
    } else if (stats.totalSessions >= 3) {
      highlights.add('💪 ${stats.totalSessions} solid workouts');
    }
    
    // Volume achievement
    if (trend.volumeChange > 10) {
      highlights.add('📈 ${trend.volumeChange.toStringAsFixed(1)}% volume increase');
    }
    
    // PRs
    if (newPRs.isNotEmpty) {
      highlights.add('🏆 ${newPRs.length} new personal record${newPRs.length > 1 ? 's' : ''}');
    }
    
    // Milestones
    if (milestones.isNotEmpty) {
      highlights.add('🎯 ${milestones.length} streak milestone${milestones.length > 1 ? 's' : ''}');
    }
    
    // Consistency
    if (stats.totalSessions >= 4) {
      highlights.add('⚡ Excellent consistency');
    }
    
    // If no major highlights, add encouraging message
    if (highlights.isEmpty) {
      highlights.add('🌱 Building momentum for next week');
    }
    
    return highlights;
  }

  /// Checks if this was a breakthrough week
  bool get isBreakthroughWeek {
    return newPRs.length >= 2 || 
           milestones.isNotEmpty || 
           trend.volumeChange > 20 ||
           stats.totalSessions >= 6;
  }

  /// Gets improvement suggestions for next week
  List<String> get improvementSuggestions {
    final suggestions = <String>[];
    
    if (stats.totalSessions < 3) {
      suggestions.add('Aim for at least 3 workouts next week');
    }
    
    if (stats.averageRPE < 6) {
      suggestions.add('Consider increasing workout intensity');
    }
    
    if (trend.volumeChange < 0) {
      suggestions.add('Focus on progressive overload');
    }
    
    if (stats.averageSessionDuration < 45) {
      suggestions.add('Try extending workout duration slightly');
    }
    
    return suggestions;
  }

  double _calculatePerformanceScore() {
    double score = 0.0;
    
    // Session frequency (40% of score)
    final sessionScore = (stats.totalSessions / 5.0).clamp(0.0, 1.0) * 40;
    score += sessionScore;
    
    // Volume progress (25% of score)
    final volumeScore = trend.volumeChange > 0 ? 25.0 : 0.0;
    score += volumeScore;
    
    // PRs and achievements (20% of score)
    final achievementScore = (newPRs.length * 5 + milestones.length * 10).clamp(0.0, 20.0);
    score += achievementScore;
    
    // Consistency (15% of score)
    final consistencyScore = stats.totalSessions >= 3 ? 15.0 : (stats.totalSessions * 5.0);
    score += consistencyScore;
    
    return score.clamp(0.0, 100.0);
  }

  String _getMonthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }
}

@freezed
class WeeklyStats with _$WeeklyStats {
  const factory WeeklyStats({
    required int totalSessions,
    required int totalSets,
    required double totalVolume,
    required double averageRPE,
    required double averageSessionDuration, // in minutes
    required int uniqueExercises,
    required Map<String, int> exerciseFrequency,
    required Map<String, double> muscleGroupVolume,
    required double totalRestTime, // in minutes
  }) = _WeeklyStats;

  const WeeklyStats._();

  factory WeeklyStats.fromJson(Map<String, dynamic> json) => 
      _$WeeklyStatsFromJson(json);

  /// Gets the most trained muscle group
  String? get topMuscleGroup {
    if (muscleGroupVolume.isEmpty) return null;
    return muscleGroupVolume.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Gets the most performed exercise
  String? get topExercise {
    if (exerciseFrequency.isEmpty) return null;
    return exerciseFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Gets average sets per session
  double get averageSetsPerSession {
    return totalSessions > 0 ? totalSets / totalSessions : 0.0;
  }

  /// Gets average volume per session
  double get averageVolumePerSession {
    return totalSessions > 0 ? totalVolume / totalSessions : 0.0;
  }

  /// Gets training density (volume per minute)
  double get trainingDensity {
    final totalTrainingTime = averageSessionDuration * totalSessions;
    return totalTrainingTime > 0 ? totalVolume / totalTrainingTime : 0.0;
  }
}

@freezed
class WeeklyAchievement with _$WeeklyAchievement {
  const factory WeeklyAchievement({
    required String id,
    required AchievementType type,
    required String title,
    required String description,
    String? icon,
    Map<String, dynamic>? metadata,
    required DateTime achievedAt,
  }) = _WeeklyAchievement;

  const WeeklyAchievement._();

  factory WeeklyAchievement.fromJson(Map<String, dynamic> json) => 
      _$WeeklyAchievementFromJson(json);
}

@freezed
class WeeklyTrend with _$WeeklyTrend {
  const factory WeeklyTrend({
    required double volumeChange, // percentage change from previous week
    required double sessionChange, // percentage change in session count
    required double intensityChange, // percentage change in average RPE
    required double durationChange, // percentage change in session duration
    required TrendDirection overallTrend,
    required List<String> trendInsights,
  }) = _WeeklyTrend;

  const WeeklyTrend._();

  factory WeeklyTrend.fromJson(Map<String, dynamic> json) => 
      _$WeeklyTrendFromJson(json);

  /// Gets the trend emoji
  String get trendEmoji {
    switch (overallTrend) {
      case TrendDirection.stronglyUp:
        return '🚀';
      case TrendDirection.up:
        return '📈';
      case TrendDirection.stable:
        return '➡️';
      case TrendDirection.down:
        return '📉';
      case TrendDirection.stronglyDown:
        return '⚠️';
    }
  }

  /// Gets the trend description
  String get trendDescription {
    switch (overallTrend) {
      case TrendDirection.stronglyUp:
        return 'Excellent progress!';
      case TrendDirection.up:
        return 'Good improvement';
      case TrendDirection.stable:
        return 'Maintaining level';
      case TrendDirection.down:
        return 'Slight decline';
      case TrendDirection.stronglyDown:
        return 'Needs attention';
    }
  }
}

enum PerformanceRating {
  excellent,
  great,
  good,
  fair,
  needsImprovement,
}

enum AchievementType {
  volumeRecord,
  sessionRecord,
  consistencyStreak,
  newExercise,
  intensityPeak,
  durationRecord,
  custom,
}

enum TrendDirection {
  stronglyUp,
  up,
  stable,
  down,
  stronglyDown,
}