import 'dart:async';
import 'package:logger/logger.dart';

import '../entities/streak_record.dart';
import '../entities/workout_session.dart';
import '../entities/enums.dart';
import '../../data/repositories/streak_repository.dart';

/// Service for tracking and managing workout streaks
class StreakTrackingService {
  final StreakRepository _streakRepository;
  final Logger _logger = Logger();
  
  StreakTrackingService(this._streakRepository);
  
  /// Update streaks when a workout is completed
  Future<List<StreakRecord>> updateStreaksWithWorkout({
    required String userId,
    required WorkoutSession session,
  }) async {
    try {
      final updatedStreaks = <StreakRecord>[];
      
      // Update general workout streak
      final workoutStreak = await _streakRepository.updateStreakWithWorkout(
        userId,
        StreakType.workout,
        session.startTime,
      );
      updatedStreaks.add(workoutStreak);
      
      // Update specific streak based on session type
      StreakType? specificType;
      switch (session.sessionType) {
        case SessionType.strength:
        case SessionType.powerlifting:
        case SessionType.bodybuilding:
          specificType = StreakType.strength;
          break;
        case SessionType.cardio:
          specificType = StreakType.cardio;
          break;
        default:
          // No specific streak for other types
          break;
      }
      
      if (specificType != null) {
        final specificStreak = await _streakRepository.updateStreakWithWorkout(
          userId,
          specificType,
          session.startTime,
        );
        updatedStreaks.add(specificStreak);
      }
      
      _logger.i('Updated ${updatedStreaks.length} streaks for user $userId');
      return updatedStreaks;
    } catch (e) {
      _logger.e('Error updating streaks with workout: $e');
      rethrow;
    }
  }
  
  /// Get current active streaks for a user
  Future<List<StreakRecord>> getActiveStreaks(String userId) async {
    try {
      // First check for broken streaks and update them
      await _streakRepository.checkAndUpdateBrokenStreaks(userId);
      
      // Then get active streaks
      return await _streakRepository.getActiveStreaks(userId);
    } catch (e) {
      _logger.e('Error getting active streaks: $e');
      rethrow;
    }
  }
  
  /// Get streak statistics for a user
  Future<Map<String, dynamic>> getStreakStats(String userId) async {
    try {
      final stats = await _streakRepository.getStreakStats(userId);
      
      // Add additional calculated stats
      final activeStreaks = await getActiveStreaks(userId);
      final recentMilestones = await _streakRepository.getRecentMilestones(userId, limit: 5);
      
      return {
        ...stats,
        'active_streak_details': activeStreaks.map((s) => {
          'type': s.streakType.name,
          'current_streak': s.currentStreak,
          'longest_streak': s.longestStreak,
          'next_milestone': s.nextMilestone,
          'days_to_milestone': s.daysToNextMilestone,
          'status': s.statusDescription,
          'encouragement': s.encouragementMessage,
        }).toList(),
        'recent_milestones': recentMilestones.map((m) => {
          'streak_count': m.streakCount,
          'achieved_at': m.achievedAt.toIso8601String(),
          'title': m.title,
          'description': m.description,
          'icon': m.icon,
          'type': m.milestoneType.name,
        }).toList(),
      };
    } catch (e) {
      _logger.e('Error getting streak stats: $e');
      rethrow;
    }
  }
  
  /// Get streak by type for a user
  Future<StreakRecord?> getStreakByType(String userId, StreakType streakType) async {
    try {
      return await _streakRepository.findByUserAndType(userId, streakType);
    } catch (e) {
      _logger.e('Error getting streak by type: $e');
      rethrow;
    }
  }
  
  /// Get recent milestones for a user
  Future<List<StreakMilestone>> getRecentMilestones(String userId, {int limit = 10}) async {
    try {
      return await _streakRepository.getRecentMilestones(userId, limit: limit);
    } catch (e) {
      _logger.e('Error getting recent milestones: $e');
      rethrow;
    }
  }
  
  /// Get all milestones for a user
  Future<List<StreakMilestone>> getAllMilestones(String userId) async {
    try {
      return await _streakRepository.getAllMilestones(userId);
    } catch (e) {
      _logger.e('Error getting all milestones: $e');
      rethrow;
    }
  }
  
  /// Check if any streaks have new milestones
  Future<List<StreakMilestone>> checkForNewMilestones(String userId) async {
    try {
      final activeStreaks = await getActiveStreaks(userId);
      final newMilestones = <StreakMilestone>[];
      
      for (final streak in activeStreaks) {
        if (streak.hasRecentMilestone) {
          final latestMilestone = streak.latestMilestone;
          if (latestMilestone != null) {
            newMilestones.add(latestMilestone);
          }
        }
      }
      
      return newMilestones;
    } catch (e) {
      _logger.e('Error checking for new milestones: $e');
      rethrow;
    }
  }
  
  /// Get streak motivation data for UI
  Future<Map<String, dynamic>> getStreakMotivationData(String userId) async {
    try {
      final activeStreaks = await getActiveStreaks(userId);
      final recentMilestones = await getRecentMilestones(userId, limit: 3);
      
      // Find the best current streak
      final bestStreak = activeStreaks.isNotEmpty 
          ? activeStreaks.reduce((a, b) => a.currentStreak > b.currentStreak ? a : b)
          : null;
      
      // Calculate streak health (percentage of days with workouts in last 30 days)
      double streakHealth = 0.0;
      if (bestStreak != null && bestStreak.currentStreak > 0) {
        final daysInPeriod = 30;
        final workoutDays = bestStreak.currentStreak.clamp(0, daysInPeriod);
        streakHealth = (workoutDays / daysInPeriod) * 100;
      }
      
      return {
        'best_streak': bestStreak != null ? {
          'type': bestStreak.streakType.name,
          'current_streak': bestStreak.currentStreak,
          'longest_streak': bestStreak.longestStreak,
          'status': bestStreak.statusDescription,
          'encouragement': bestStreak.encouragementMessage,
          'next_milestone': bestStreak.nextMilestone,
          'days_to_milestone': bestStreak.daysToNextMilestone,
          'is_at_risk': bestStreak.isBroken,
        } : null,
        'streak_health': streakHealth,
        'recent_milestones': recentMilestones.map((m) => {
          'title': m.title,
          'description': m.description,
          'icon': m.icon,
          'streak_count': m.streakCount,
          'achieved_at': m.achievedAt.toIso8601String(),
        }).toList(),
        'total_active_streaks': activeStreaks.length,
        'motivation_level': _calculateMotivationLevel(activeStreaks, recentMilestones),
      };
    } catch (e) {
      _logger.e('Error getting streak motivation data: $e');
      rethrow;
    }
  }
  
  /// Manually break a streak (for testing or admin purposes)
  Future<StreakRecord> breakStreak(String streakId) async {
    try {
      return await _streakRepository.breakStreak(streakId);
    } catch (e) {
      _logger.e('Error breaking streak: $e');
      rethrow;
    }
  }
  
  /// Get streak visualization data for charts
  Future<Map<String, dynamic>> getStreakVisualizationData(
    String userId,
    StreakType streakType,
    {int days = 30}
  ) async {
    try {
      final streak = await getStreakByType(userId, streakType);
      if (streak == null) {
        return {
          'streak_data': [],
          'milestones': [],
          'current_streak': 0,
          'longest_streak': 0,
        };
      }
      
      // Generate daily streak data for the last N days
      final now = DateTime.now();
      final streakData = <Map<String, dynamic>>[];
      
      for (int i = days - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final daysSinceStart = date.difference(streak.streakStartDate).inDays;
        
        // Determine if this day was part of the streak
        bool wasStreakDay = false;
        if (daysSinceStart >= 0 && daysSinceStart < streak.currentStreak) {
          wasStreakDay = true;
        }
        
        streakData.add({
          'date': date.toIso8601String(),
          'day': date.day,
          'was_streak_day': wasStreakDay,
          'streak_count': wasStreakDay ? daysSinceStart + 1 : 0,
        });
      }
      
      // Get milestones within the timeframe
      final timeframeMilestones = streak.milestones
          .where((m) => m.achievedAt.isAfter(now.subtract(Duration(days: days))))
          .toList();
      
      return {
        'streak_data': streakData,
        'milestones': timeframeMilestones.map((m) => {
          'date': m.achievedAt.toIso8601String(),
          'streak_count': m.streakCount,
          'title': m.title,
          'icon': m.icon,
        }).toList(),
        'current_streak': streak.currentStreak,
        'longest_streak': streak.longestStreak,
        'streak_type': streak.streakType.name,
      };
    } catch (e) {
      _logger.e('Error getting streak visualization data: $e');
      rethrow;
    }
  }
  
  /// Calculate motivation level based on streaks and milestones
  String _calculateMotivationLevel(
    List<StreakRecord> activeStreaks,
    List<StreakMilestone> recentMilestones,
  ) {
    if (activeStreaks.isEmpty) return 'Getting Started';
    
    final maxStreak = activeStreaks
        .map((s) => s.currentStreak)
        .reduce((a, b) => a > b ? a : b);
    
    final hasRecentMilestone = recentMilestones.isNotEmpty &&
        DateTime.now().difference(recentMilestones.first.achievedAt).inDays <= 7;
    
    if (hasRecentMilestone) return 'On Fire!';
    if (maxStreak >= 30) return 'Unstoppable';
    if (maxStreak >= 14) return 'Strong';
    if (maxStreak >= 7) return 'Building Momentum';
    if (maxStreak >= 3) return 'Getting Started';
    return 'Just Beginning';
  }
}

/// Exception thrown when streak tracking operations fail
class StreakTrackingException implements Exception {
  final String message;
  final dynamic originalError;
  
  const StreakTrackingException(this.message, {this.originalError});
  
  @override
  String toString() => 'StreakTrackingException: $message';
}