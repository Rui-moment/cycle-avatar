import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/entities/pr_record.dart';
import '../../domain/entities/enums.dart';
import '../../core/providers/providers.dart';

/// State class for workout history data
class WorkoutHistoryState {
  final List<WorkoutSession> sessions;
  final List<PRRecord> personalRecords;
  final Map<String, dynamic> statistics;
  final bool isLoading;
  final String? error;
  final DateTime? selectedDate;
  final String? selectedExerciseFilter;

  const WorkoutHistoryState({
    this.sessions = const [],
    this.personalRecords = const [],
    this.statistics = const {},
    this.isLoading = false,
    this.error,
    this.selectedDate,
    this.selectedExerciseFilter,
  });

  WorkoutHistoryState copyWith({
    List<WorkoutSession>? sessions,
    List<PRRecord>? personalRecords,
    Map<String, dynamic>? statistics,
    bool? isLoading,
    String? error,
    DateTime? selectedDate,
    String? selectedExerciseFilter,
  }) {
    return WorkoutHistoryState(
      sessions: sessions ?? this.sessions,
      personalRecords: personalRecords ?? this.personalRecords,
      statistics: statistics ?? this.statistics,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedExerciseFilter: selectedExerciseFilter ?? this.selectedExerciseFilter,
    );
  }
}

/// Notifier for managing workout history
class WorkoutHistoryNotifier extends StateNotifier<WorkoutHistoryState> {
  final dynamic _sessionRepository; // Temporary fix
  final dynamic _prRepository; // Temporary fix

  WorkoutHistoryNotifier(this._sessionRepository, this._prRepository) 
      : super(const WorkoutHistoryState());

  /// Load workout history for a user
  Future<void> loadHistory(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Load recent sessions
      final sessions = await _sessionRepository.findByUserId(userId);
      
      // Load personal records
      final prRecords = await _prRepository.findByUserId(userId);
      
      // Calculate statistics
      final statistics = await _calculateStatistics(userId, sessions);
      
      state = state.copyWith(
        sessions: sessions,
        personalRecords: prRecords,
        statistics: statistics,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load workout history: $e',
      );
    }
  }

  /// Load sessions for a specific date range
  Future<void> loadSessionsForDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final sessions = await _sessionRepository.findByUserIdAndDateRange(
        userId,
        startDate,
        endDate,
      );
      
      state = state.copyWith(
        sessions: sessions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load sessions for date range: $e',
      );
    }
  }

  /// Filter sessions by exercise
  void filterByExercise(String? exerciseId) {
    state = state.copyWith(selectedExerciseFilter: exerciseId);
  }

  /// Set selected date for filtering
  void setSelectedDate(DateTime? date) {
    state = state.copyWith(selectedDate: date);
  }

  /// Get filtered sessions based on current filters
  List<WorkoutSession> getFilteredSessions() {
    var filteredSessions = state.sessions;
    
    // Filter by date if selected
    if (state.selectedDate != null) {
      final selectedDate = state.selectedDate!;
      filteredSessions = filteredSessions.where((session) {
        final sessionDate = DateTime(
          session.startTime.year,
          session.startTime.month,
          session.startTime.day,
        );
        final filterDate = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
        return sessionDate.isAtSameMomentAs(filterDate);
      }).toList();
    }
    
    // Filter by exercise if selected
    if (state.selectedExerciseFilter != null) {
      filteredSessions = filteredSessions.where((session) {
        return session.uniqueExercises.contains(state.selectedExerciseFilter);
      }).toList();
    }
    
    return filteredSessions;
  }

  /// Clear all filters
  void clearFilters() {
    state = state.copyWith(
      selectedDate: null,
      selectedExerciseFilter: null,
    );
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Calculate workout statistics
  Future<Map<String, dynamic>> _calculateStatistics(
    String userId,
    List<WorkoutSession> sessions,
  ) async {
    if (sessions.isEmpty) {
      return {
        'totalSessions': 0,
        'totalVolume': 0.0,
        'averageDuration': 0.0,
        'totalSets': 0,
        'averageRPE': 0.0,
        'weeklyVolume': <double>[],
        'monthlyVolume': <double>[],
        'exerciseFrequency': <String, int>{},
      };
    }

    // Basic statistics
    final totalSessions = sessions.length;
    final completedSessions = sessions.where((s) => s.endTime != null).toList();
    
    final totalVolume = sessions.fold(0.0, (sum, session) => sum + session.totalVolume);
    final totalSets = sessions.fold(0, (sum, session) => sum + session.sets.length);
    
    final averageDuration = completedSessions.isNotEmpty
        ? completedSessions.fold(0.0, (sum, session) {
            final duration = session.endTime!.difference(session.startTime);
            return sum + duration.inMinutes;
          }) / completedSessions.length
        : 0.0;

    final averageRPE = totalSets > 0
        ? sessions.expand((s) => s.sets).fold(0.0, (sum, set) => sum + set.rpe) / totalSets
        : 0.0;

    // Weekly volume for the last 12 weeks
    final weeklyVolume = _calculateWeeklyVolume(sessions, 12);
    
    // Monthly volume for the last 6 months
    final monthlyVolume = _calculateMonthlyVolume(sessions, 6);
    
    // Exercise frequency
    final exerciseFrequency = <String, int>{};
    for (final session in sessions) {
      for (final exerciseId in session.uniqueExercises) {
        exerciseFrequency[exerciseId] = (exerciseFrequency[exerciseId] ?? 0) + 1;
      }
    }

    return {
      'totalSessions': totalSessions,
      'totalVolume': totalVolume,
      'averageDuration': averageDuration,
      'totalSets': totalSets,
      'averageRPE': averageRPE,
      'weeklyVolume': weeklyVolume,
      'monthlyVolume': monthlyVolume,
      'exerciseFrequency': exerciseFrequency,
    };
  }

  /// Calculate weekly volume for the specified number of weeks
  List<double> _calculateWeeklyVolume(List<WorkoutSession> sessions, int weeks) {
    final weeklyVolume = <double>[];
    final now = DateTime.now();
    
    for (int i = weeks - 1; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + (i * 7)));
      final weekEnd = weekStart.add(const Duration(days: 6));
      
      final weekSessions = sessions.where((session) {
        return session.startTime.isAfter(weekStart) && 
               session.startTime.isBefore(weekEnd.add(const Duration(days: 1)));
      });
      
      final volume = weekSessions.fold(0.0, (sum, session) => sum + session.totalVolume);
      weeklyVolume.add(volume);
    }
    
    return weeklyVolume;
  }

  /// Calculate monthly volume for the specified number of months
  List<double> _calculateMonthlyVolume(List<WorkoutSession> sessions, int months) {
    final monthlyVolume = <double>[];
    final now = DateTime.now();
    
    for (int i = months - 1; i >= 0; i--) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0);
      
      final monthSessions = sessions.where((session) {
        return session.startTime.isAfter(monthStart.subtract(const Duration(days: 1))) && 
               session.startTime.isBefore(monthEnd.add(const Duration(days: 1)));
      });
      
      final volume = monthSessions.fold(0.0, (sum, session) => sum + session.totalVolume);
      monthlyVolume.add(volume);
    }
    
    return monthlyVolume;
  }
}

/// Provider for workout history
final workoutHistoryProvider = StateNotifierProvider<WorkoutHistoryNotifier, WorkoutHistoryState>((ref) {
  final sessionRepository = ref.watch(workoutSessionRepositoryProvider);
  final prRepository = ref.watch(prRepositoryProvider);
  return WorkoutHistoryNotifier(sessionRepository, prRepository);
});

/// Provider for filtered sessions
final filteredSessionsProvider = Provider<List<WorkoutSession>>((ref) {
  final historyNotifier = ref.watch(workoutHistoryProvider.notifier);
  return historyNotifier.getFilteredSessions();
});