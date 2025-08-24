import 'dart:async';
import 'package:logger/logger.dart';

import '../entities/weekly_highlight.dart';
import '../entities/workout_session.dart';
import '../entities/pr_record.dart';
import '../entities/streak_record.dart';
import '../../data/repositories/workout_repository.dart';
import 'pr_tracking_service.dart';
import 'streak_tracking_service.dart';

/// Service for generating and managing weekly highlights
class WeeklyHighlightService {
  final WorkoutSessionRepository _workoutRepository;
  final PRTrackingService _prTrackingService;
  final StreakTrackingService _streakTrackingService;
  final Logger _logger = Logger();
  
  WeeklyHighlightService(
    this._workoutRepository,
    this._prTrackingService,
    this._streakTrackingService,
  );
  
  /// Generate weekly highlight for a specific week
  Future<WeeklyHighlight> generateWeeklyHighlight({
    required String userId,
    required DateTime weekStartDate,
  }) async {
    try {
      final weekEndDate = weekStartDate.add(const Duration(days: 6));
      
      // Get workout sessions for the week
      final sessions = await _workoutRepository.findByUserIdAndDateRange(
        userId,
        weekStartDate,
        weekEndDate.add(const Duration(days: 1)), // Include end date
      );
      
      // Calculate weekly stats
      final stats = await _calculateWeeklyStats(sessions);
      
      // Get PRs achieved during the week
      final newPRs = await _prTrackingService.getPRsInDateRange(
        userId,
        weekStartDate,
        weekEndDate.add(const Duration(days: 1)),
      );
      
      // Get milestones achieved during the week
      final milestones = await _getWeeklyMilestones(userId, weekStartDate, weekEndDate);
      
      // Calculate trend compared to previous week
      final trend = await _calculateWeeklyTrend(userId, weekStartDate, stats);
      
      // Generate achievements
      final achievements = _generateAchievements(stats, newPRs, milestones, trend);
      
      // Generate motivational message
      final motivationalMessage = _generateMotivationalMessage(stats, achievements, trend);
      
      final highlight = WeeklyHighlight(
        id: 'highlight_${userId}_${weekStartDate.millisecondsSinceEpoch}',
        userId: userId,
        weekStartDate: weekStartDate,
        weekEndDate: weekEndDate,
        stats: stats,
        achievements: achievements,
        newPRs: newPRs,
        milestones: milestones,
        trend: trend,
        motivationalMessage: motivationalMessage,
        createdAt: DateTime.now(),
      );
      
      _logger.i('Generated weekly highlight for user $userId, week ${highlight.weekRangeString}');
      return highlight;
    } catch (e) {
      _logger.e('Error generating weekly highlight: $e');
      rethrow;
    }
  }
  
  /// Generate weekly highlight for current week
  Future<WeeklyHighlight> generateCurrentWeekHighlight(String userId) async {
    final now = DateTime.now();
    final weekStartDate = _getWeekStartDate(now);
    return generateWeeklyHighlight(userId: userId, weekStartDate: weekStartDate);
  }
  
  /// Generate weekly highlight for previous week
  Future<WeeklyHighlight> generatePreviousWeekHighlight(String userId) async {
    final now = DateTime.now();
    final weekStartDate = _getWeekStartDate(now).subtract(const Duration(days: 7));
    return generateWeeklyHighlight(userId: userId, weekStartDate: weekStartDate);
  }
  
  /// Get weekly highlights for a date range
  Future<List<WeeklyHighlight>> getWeeklyHighlights({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final highlights = <WeeklyHighlight>[];
      var currentWeekStart = _getWeekStartDate(startDate);
      
      while (currentWeekStart.isBefore(endDate)) {
        final highlight = await generateWeeklyHighlight(
          userId: userId,
          weekStartDate: currentWeekStart,
        );
        highlights.add(highlight);
        currentWeekStart = currentWeekStart.add(const Duration(days: 7));
      }
      
      return highlights;
    } catch (e) {
      _logger.e('Error getting weekly highlights: $e');
      rethrow;
    }
  }
  
  /// Get weekly progress summary for multiple weeks
  Future<Map<String, dynamic>> getWeeklyProgressSummary({
    required String userId,
    int weeks = 4,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: weeks * 7));
      
      final highlights = await getWeeklyHighlights(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );
      
      // Calculate summary statistics
      final totalSessions = highlights.fold<int>(0, (sum, h) => sum + h.stats.totalSessions);
      final totalVolume = highlights.fold<double>(0, (sum, h) => sum + h.stats.totalVolume);
      final totalPRs = highlights.fold<int>(0, (sum, h) => sum + h.newPRs.length);
      final totalMilestones = highlights.fold<int>(0, (sum, h) => sum + h.milestones.length);
      
      // Calculate averages
      final avgSessionsPerWeek = highlights.isNotEmpty ? totalSessions / highlights.length : 0.0;
      final avgVolumePerWeek = highlights.isNotEmpty ? totalVolume / highlights.length : 0.0;
      
      // Find best week
      final bestWeek = highlights.isNotEmpty 
          ? highlights.reduce((a, b) => a.stats.totalVolume > b.stats.totalVolume ? a : b)
          : null;
      
      // Calculate consistency score (percentage of weeks with 3+ sessions)
      final consistentWeeks = highlights.where((h) => h.stats.totalSessions >= 3).length;
      final consistencyScore = highlights.isNotEmpty ? (consistentWeeks / highlights.length) * 100 : 0.0;
      
      return {
        'period_weeks': weeks,
        'total_sessions': totalSessions,
        'total_volume': totalVolume,
        'total_prs': totalPRs,
        'total_milestones': totalMilestones,
        'avg_sessions_per_week': avgSessionsPerWeek,
        'avg_volume_per_week': avgVolumePerWeek,
        'consistency_score': consistencyScore,
        'best_week': bestWeek != null ? {
          'week_range': bestWeek.weekRangeString,
          'sessions': bestWeek.stats.totalSessions,
          'volume': bestWeek.stats.totalVolume,
          'prs': bestWeek.newPRs.length,
        } : null,
        'weekly_data': highlights.map((h) => {
          'week_start': h.weekStartDate.toIso8601String(),
          'week_range': h.weekRangeString,
          'sessions': h.stats.totalSessions,
          'volume': h.stats.totalVolume,
          'prs': h.newPRs.length,
          'milestones': h.milestones.length,
          'performance_rating': h.performanceRating.name,
          'trend_direction': h.trend.overallTrend.name,
        }).toList(),
      };
    } catch (e) {
      _logger.e('Error getting weekly progress summary: $e');
      rethrow;
    }
  }
  
  Future<WeeklyStats> _calculateWeeklyStats(List<WorkoutSession> sessions) async {
    if (sessions.isEmpty) {
      return const WeeklyStats(
        totalSessions: 0,
        totalSets: 0,
        totalVolume: 0.0,
        averageRPE: 0.0,
        averageSessionDuration: 0.0,
        uniqueExercises: 0,
        exerciseFrequency: {},
        muscleGroupVolume: {},
        totalRestTime: 0.0,
      );
    }
    
    final totalSessions = sessions.length;
    var totalSets = 0;
    var totalVolume = 0.0;
    var totalRPE = 0.0;
    var totalRPECount = 0;
    var totalDuration = 0.0;
    var totalRestTime = 0.0;
    
    final exerciseFrequency = <String, int>{};
    final muscleGroupVolume = <String, double>{};
    final uniqueExercises = <String>{};
    
    for (final session in sessions) {
      // Session duration
      if (session.duration != null) {
        totalDuration += session.duration!.inMinutes.toDouble();
      }
      
      // Process sets
      for (final set in session.sets) {
        totalSets++;
        totalVolume += set.volume;
        totalRPE += set.rpe;
        totalRPECount++;
        totalRestTime += set.restSeconds / 60.0; // Convert to minutes
        
        // Exercise frequency
        uniqueExercises.add(set.exerciseId);
        exerciseFrequency[set.exerciseId] = (exerciseFrequency[set.exerciseId] ?? 0) + 1;
        
        // TODO: Add muscle group volume calculation when exercise-muscle group mapping is available
        // For now, use exercise ID as placeholder
        muscleGroupVolume[set.exerciseId] = (muscleGroupVolume[set.exerciseId] ?? 0.0) + set.volume;
      }
    }
    
    return WeeklyStats(
      totalSessions: totalSessions,
      totalSets: totalSets,
      totalVolume: totalVolume,
      averageRPE: totalRPECount > 0 ? totalRPE / totalRPECount : 0.0,
      averageSessionDuration: totalSessions > 0 ? totalDuration / totalSessions : 0.0,
      uniqueExercises: uniqueExercises.length,
      exerciseFrequency: exerciseFrequency,
      muscleGroupVolume: muscleGroupVolume,
      totalRestTime: totalRestTime,
    );
  }
  
  Future<List<StreakMilestone>> _getWeeklyMilestones(
    String userId,
    DateTime weekStartDate,
    DateTime weekEndDate,
  ) async {
    final allMilestones = await _streakTrackingService.getAllMilestones(userId);
    
    return allMilestones.where((milestone) =>
        milestone.achievedAt.isAfter(weekStartDate) &&
        milestone.achievedAt.isBefore(weekEndDate.add(const Duration(days: 1)))
    ).toList();
  }
  
  Future<WeeklyTrend> _calculateWeeklyTrend(
    String userId,
    DateTime weekStartDate,
    WeeklyStats currentStats,
  ) async {
    try {
      // Get previous week's sessions
      final previousWeekStart = weekStartDate.subtract(const Duration(days: 7));
      final previousWeekEnd = previousWeekStart.add(const Duration(days: 6));
      
      final previousSessions = await _workoutRepository.findByUserIdAndDateRange(
        userId,
        previousWeekStart,
        previousWeekEnd.add(const Duration(days: 1)),
      );
      
      final previousStats = await _calculateWeeklyStats(previousSessions);
      
      // Calculate percentage changes
      final volumeChange = _calculatePercentageChange(
        previousStats.totalVolume,
        currentStats.totalVolume,
      );
      
      final sessionChange = _calculatePercentageChange(
        previousStats.totalSessions.toDouble(),
        currentStats.totalSessions.toDouble(),
      );
      
      final intensityChange = _calculatePercentageChange(
        previousStats.averageRPE,
        currentStats.averageRPE,
      );
      
      final durationChange = _calculatePercentageChange(
        previousStats.averageSessionDuration,
        currentStats.averageSessionDuration,
      );
      
      // Determine overall trend
      final overallTrend = _determineOverallTrend(
        volumeChange,
        sessionChange,
        intensityChange,
      );
      
      // Generate trend insights
      final trendInsights = _generateTrendInsights(
        volumeChange,
        sessionChange,
        intensityChange,
        durationChange,
      );
      
      return WeeklyTrend(
        volumeChange: volumeChange,
        sessionChange: sessionChange,
        intensityChange: intensityChange,
        durationChange: durationChange,
        overallTrend: overallTrend,
        trendInsights: trendInsights,
      );
    } catch (e) {
      _logger.w('Error calculating weekly trend, using default: $e');
      return const WeeklyTrend(
        volumeChange: 0.0,
        sessionChange: 0.0,
        intensityChange: 0.0,
        durationChange: 0.0,
        overallTrend: TrendDirection.stable,
        trendInsights: [],
      );
    }
  }
  
  List<WeeklyAchievement> _generateAchievements(
    WeeklyStats stats,
    List<PRRecord> newPRs,
    List<StreakMilestone> milestones,
    WeeklyTrend trend,
  ) {
    final achievements = <WeeklyAchievement>[];
    final now = DateTime.now();
    
    // Volume achievements
    if (stats.totalVolume > 10000) {
      achievements.add(WeeklyAchievement(
        id: 'volume_${now.millisecondsSinceEpoch}',
        type: AchievementType.volumeRecord,
        title: 'Volume Beast',
        description: 'Achieved ${stats.totalVolume.toStringAsFixed(0)}kg total volume',
        icon: '💪',
        achievedAt: now,
      ));
    }
    
    // Session frequency achievements
    if (stats.totalSessions >= 6) {
      achievements.add(WeeklyAchievement(
        id: 'sessions_${now.millisecondsSinceEpoch}',
        type: AchievementType.sessionRecord,
        title: 'Workout Warrior',
        description: 'Completed ${stats.totalSessions} workouts this week',
        icon: '🔥',
        achievedAt: now,
      ));
    } else if (stats.totalSessions >= 4) {
      achievements.add(WeeklyAchievement(
        id: 'consistency_${now.millisecondsSinceEpoch}',
        type: AchievementType.consistencyStreak,
        title: 'Consistent Performer',
        description: 'Maintained excellent workout consistency',
        icon: '⚡',
        achievedAt: now,
      ));
    }
    
    // Intensity achievements
    if (stats.averageRPE >= 8.5) {
      achievements.add(WeeklyAchievement(
        id: 'intensity_${now.millisecondsSinceEpoch}',
        type: AchievementType.intensityPeak,
        title: 'High Intensity Hero',
        description: 'Averaged ${stats.averageRPE.toStringAsFixed(1)} RPE across all sets',
        icon: '🚀',
        achievedAt: now,
      ));
    }
    
    // Exercise variety achievements
    if (stats.uniqueExercises >= 15) {
      achievements.add(WeeklyAchievement(
        id: 'variety_${now.millisecondsSinceEpoch}',
        type: AchievementType.newExercise,
        title: 'Exercise Explorer',
        description: 'Performed ${stats.uniqueExercises} different exercises',
        icon: '🎯',
        achievedAt: now,
      ));
    }
    
    // Trend-based achievements
    if (trend.volumeChange > 20) {
      achievements.add(WeeklyAchievement(
        id: 'growth_${now.millisecondsSinceEpoch}',
        type: AchievementType.volumeRecord,
        title: 'Growth Mindset',
        description: 'Increased volume by ${trend.volumeChange.toStringAsFixed(1)}%',
        icon: '📈',
        achievedAt: now,
      ));
    }
    
    return achievements;
  }
  
  String _generateMotivationalMessage(
    WeeklyStats stats,
    List<WeeklyAchievement> achievements,
    WeeklyTrend trend,
  ) {
    if (achievements.length >= 3) {
      return 'Incredible week! You\'re absolutely crushing your fitness goals! 🌟';
    }
    
    if (stats.totalSessions >= 5) {
      return 'Outstanding consistency this week! Your dedication is truly inspiring! 💪';
    }
    
    if (trend.volumeChange > 15) {
      return 'Amazing progress! You\'re getting stronger every week! 🚀';
    }
    
    if (stats.totalSessions >= 3) {
      return 'Great work this week! You\'re building excellent habits! 🔥';
    }
    
    if (stats.totalSessions >= 1) {
      return 'Every workout counts! Keep building momentum for next week! 🌱';
    }
    
    return 'New week, new opportunities! Let\'s make it count! ⭐';
  }
  
  double _calculatePercentageChange(double previous, double current) {
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100;
  }
  
  TrendDirection _determineOverallTrend(
    double volumeChange,
    double sessionChange,
    double intensityChange,
  ) {
    final avgChange = (volumeChange + sessionChange + intensityChange) / 3;
    
    if (avgChange > 15) return TrendDirection.stronglyUp;
    if (avgChange > 5) return TrendDirection.up;
    if (avgChange > -5) return TrendDirection.stable;
    if (avgChange > -15) return TrendDirection.down;
    return TrendDirection.stronglyDown;
  }
  
  List<String> _generateTrendInsights(
    double volumeChange,
    double sessionChange,
    double intensityChange,
    double durationChange,
  ) {
    final insights = <String>[];
    
    if (volumeChange > 10) {
      insights.add('Volume increased significantly');
    } else if (volumeChange < -10) {
      insights.add('Volume decreased this week');
    }
    
    if (sessionChange > 0) {
      insights.add('Improved workout frequency');
    } else if (sessionChange < 0) {
      insights.add('Fewer workouts than last week');
    }
    
    if (intensityChange > 5) {
      insights.add('Training intensity increased');
    } else if (intensityChange < -5) {
      insights.add('Training intensity decreased');
    }
    
    if (durationChange > 10) {
      insights.add('Longer workout sessions');
    } else if (durationChange < -10) {
      insights.add('Shorter workout sessions');
    }
    
    return insights;
  }
  
  DateTime _getWeekStartDate(DateTime date) {
    // Get Monday of the week containing the given date
    final daysFromMonday = (date.weekday - 1) % 7;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysFromMonday));
  }
}

/// Exception thrown when weekly highlight operations fail
class WeeklyHighlightException implements Exception {
  final String message;
  final dynamic originalError;
  
  const WeeklyHighlightException(this.message, {this.originalError});
  
  @override
  String toString() => 'WeeklyHighlightException: $message';
}