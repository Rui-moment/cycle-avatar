import 'dart:async';
import 'package:logger/logger.dart';

import '../entities/pr_record.dart';
import '../entities/workout_session.dart';
import '../entities/exercise.dart';
import '../../data/repositories/pr_repository.dart';
import '../../data/repositories/exercise_repository.dart';

/// Service for tracking and managing personal records (PRs)
class PRTrackingService {
  final PRRepository _prRepository;
  final ExerciseRepository _exerciseRepository;
  final Logger _logger = Logger();
  
  PRTrackingService(this._prRepository, this._exerciseRepository);
  
  /// Check if a workout set represents a new PR and create it if so
  Future<PRRecord?> checkAndCreatePR({
    required String userId,
    required WorkoutSet workoutSet,
    String? notes,
  }) async {
    try {
      // Check if this is a new PR
      final isNewPR = await _prRepository.isNewPR(
        userId,
        workoutSet.exerciseId,
        workoutSet.weight,
        workoutSet.reps,
      );
      
      if (!isNewPR) {
        _logger.d('Set is not a new PR for exercise ${workoutSet.exerciseId}');
        return null;
      }
      
      // Create the new PR record
      final pr = await _prRepository.createFromWorkoutSet(
        userId: userId,
        exerciseId: workoutSet.exerciseId,
        weight: workoutSet.weight,
        reps: workoutSet.reps,
        achievedAt: workoutSet.createdAt,
        workoutSessionId: workoutSet.sessionId,
        notes: notes,
      );
      
      _logger.i('New PR created: ${pr.id} for exercise ${pr.exerciseId}');
      return pr;
    } catch (e) {
      _logger.e('Error checking/creating PR: $e');
      rethrow;
    }
  }
  
  /// Process a completed workout session and check for PRs
  Future<List<PRRecord>> processWorkoutSessionForPRs({
    required String userId,
    required WorkoutSession session,
  }) async {
    final newPRs = <PRRecord>[];
    
    try {
      // Group sets by exercise
      final setsByExercise = <String, List<WorkoutSet>>{};
      for (final set in session.sets) {
        setsByExercise.putIfAbsent(set.exerciseId, () => []).add(set);
      }
      
      // Check each exercise for PRs
      for (final entry in setsByExercise.entries) {
        final exerciseId = entry.key;
        final sets = entry.value;
        
        // Find the best set for this exercise in this session
        final bestSet = _findBestSet(sets);
        
        // Check if it's a PR
        final pr = await checkAndCreatePR(
          userId: userId,
          workoutSet: bestSet,
          notes: 'Achieved during workout session on ${session.startTime.toLocal()}',
        );
        
        if (pr != null) {
          newPRs.add(pr);
        }
      }
      
      if (newPRs.isNotEmpty) {
        _logger.i('Found ${newPRs.length} new PRs in session ${session.id}');
      }
      
      return newPRs;
    } catch (e) {
      _logger.e('Error processing workout session for PRs: $e');
      rethrow;
    }
  }
  
  /// Get current PRs for a user
  Future<List<PRRecord>> getCurrentPRs(String userId) async {
    try {
      final allPRs = await _prRepository.findByUserId(userId);
      
      // Group by exercise and get the best PR for each
      final prsByExercise = <String, PRRecord>{};
      for (final pr in allPRs) {
        final existing = prsByExercise[pr.exerciseId];
        if (existing == null || pr.estimatedMax > existing.estimatedMax) {
          prsByExercise[pr.exerciseId] = pr;
        }
      }
      
      return prsByExercise.values.toList()
        ..sort((a, b) => b.estimatedMax.compareTo(a.estimatedMax));
    } catch (e) {
      _logger.e('Error getting current PRs: $e');
      rethrow;
    }
  }
  
  /// Get PR history for a specific exercise
  Future<List<PRRecord>> getPRHistory(String userId, String exerciseId) async {
    try {
      return await _prRepository.getPRHistory(userId, exerciseId);
    } catch (e) {
      _logger.e('Error getting PR history: $e');
      rethrow;
    }
  }
  
  /// Get recent PRs for a user
  Future<List<PRRecord>> getRecentPRs(String userId, {int limit = 10}) async {
    try {
      return await _prRepository.getRecentPRs(userId, limit: limit);
    } catch (e) {
      _logger.e('Error getting recent PRs: $e');
      rethrow;
    }
  }
  
  /// Get PR statistics for a user
  Future<Map<String, dynamic>> getPRStats(String userId) async {
    try {
      final stats = await _prRepository.getPRStats(userId);
      
      // Add additional calculated stats
      final recentPRs = await getRecentPRs(userId, limit: 30);
      final prsByMonth = _groupPRsByMonth(recentPRs);
      
      return {
        ...stats,
        'prs_by_month': prsByMonth,
        'pr_trend': _calculatePRTrend(recentPRs),
      };
    } catch (e) {
      _logger.e('Error getting PR stats: $e');
      rethrow;
    }
  }
  
  /// Get PRs achieved in a specific date range
  Future<List<PRRecord>> getPRsInDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      return await _prRepository.getPRsInDateRange(userId, startDate, endDate);
    } catch (e) {
      _logger.e('Error getting PRs in date range: $e');
      rethrow;
    }
  }
  
  /// Verify a PR record
  Future<PRRecord> verifyPR(String prId) async {
    try {
      return await _prRepository.verifyPR(prId);
    } catch (e) {
      _logger.e('Error verifying PR: $e');
      rethrow;
    }
  }
  
  /// Get unverified PRs for a user
  Future<List<PRRecord>> getUnverifiedPRs(String userId) async {
    try {
      return await _prRepository.getUnverifiedPRs(userId);
    } catch (e) {
      _logger.e('Error getting unverified PRs: $e');
      rethrow;
    }
  }
  
  /// Calculate PR improvement percentage over time
  Future<double> calculatePRImprovement(
    String userId,
    String exerciseId,
    Duration timeframe,
  ) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(timeframe);
      
      final prs = await _prRepository.findByUserAndExercise(userId, exerciseId);
      if (prs.length < 2) return 0.0;
      
      // Find PRs at start and end of timeframe
      final oldestInRange = prs
          .where((pr) => pr.achievedAt.isAfter(startDate))
          .fold<PRRecord?>(null, (oldest, pr) => 
              oldest == null || pr.achievedAt.isBefore(oldest.achievedAt) 
                  ? pr : oldest);
      
      final newestInRange = prs
          .where((pr) => pr.achievedAt.isBefore(endDate))
          .fold<PRRecord?>(null, (newest, pr) => 
              newest == null || pr.achievedAt.isAfter(newest.achievedAt) 
                  ? pr : newest);
      
      if (oldestInRange == null || newestInRange == null) return 0.0;
      
      return newestInRange.calculateImprovementPercentage(oldestInRange);
    } catch (e) {
      _logger.e('Error calculating PR improvement: $e');
      return 0.0;
    }
  }
  
  /// Get PR celebration data for UI
  Future<Map<String, dynamic>> getPRCelebrationData(PRRecord pr) async {
    try {
      final exercise = await _exerciseRepository.findById(pr.exerciseId);
      final previousPRs = await _prRepository.findByUserAndExercise(
        pr.userId,
        pr.exerciseId,
      );
      
      // Find previous best PR
      final previousBest = previousPRs
          .where((p) => p.achievedAt.isBefore(pr.achievedAt))
          .fold<PRRecord?>(null, (best, p) => 
              best == null || p.estimatedMax > best.estimatedMax ? p : best);
      
      final improvementPercentage = previousBest != null 
          ? pr.calculateImprovementPercentage(previousBest)
          : 0.0;
      
      return {
        'pr': pr,
        'exercise': exercise,
        'previous_best': previousBest,
        'improvement_percentage': improvementPercentage,
        'is_significant': previousBest != null && pr.isSignificantImprovement(previousBest),
        'pr_type': pr.prType,
        'strength_level': pr.getStrengthLevel(),
      };
    } catch (e) {
      _logger.e('Error getting PR celebration data: $e');
      rethrow;
    }
  }
  
  /// Find the best set from a list of sets (highest estimated 1RM)
  WorkoutSet _findBestSet(List<WorkoutSet> sets) {
    return sets.reduce((best, current) => 
        current.estimated1RM > best.estimated1RM ? current : best);
  }
  
  /// Group PRs by month for statistics
  Map<String, int> _groupPRsByMonth(List<PRRecord> prs) {
    final prsByMonth = <String, int>{};
    
    for (final pr in prs) {
      final monthKey = '${pr.achievedAt.year}-${pr.achievedAt.month.toString().padLeft(2, '0')}';
      prsByMonth[monthKey] = (prsByMonth[monthKey] ?? 0) + 1;
    }
    
    return prsByMonth;
  }
  
  /// Calculate PR trend (positive = improving, negative = declining)
  double _calculatePRTrend(List<PRRecord> recentPRs) {
    if (recentPRs.length < 2) return 0.0;
    
    // Sort by date
    final sortedPRs = List<PRRecord>.from(recentPRs)
      ..sort((a, b) => a.achievedAt.compareTo(b.achievedAt));
    
    // Calculate average improvement over time
    double totalImprovement = 0.0;
    int improvementCount = 0;
    
    for (int i = 1; i < sortedPRs.length; i++) {
      final current = sortedPRs[i];
      final previous = sortedPRs[i - 1];
      
      // Only compare PRs for the same exercise
      if (current.exerciseId == previous.exerciseId) {
        totalImprovement += current.calculateImprovementPercentage(previous);
        improvementCount++;
      }
    }
    
    return improvementCount > 0 ? totalImprovement / improvementCount : 0.0;
  }
}

/// Exception thrown when PR tracking operations fail
class PRTrackingException implements Exception {
  final String message;
  final dynamic originalError;
  
  const PRTrackingException(this.message, {this.originalError});
  
  @override
  String toString() => 'PRTrackingException: $message';
}