import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/workout_session.dart';
import '../../domain/entities/enums.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/performance_utils.dart';

/// State class for managing the current workout session
class WorkoutSessionState {
  final WorkoutSession? currentSession;
  final bool isLoading;
  final String? error;
  final List<WorkoutSession> recentSessions;

  const WorkoutSessionState({
    this.currentSession,
    this.isLoading = false,
    this.error,
    this.recentSessions = const [],
  });

  WorkoutSessionState copyWith({
    WorkoutSession? currentSession,
    bool? isLoading,
    String? error,
    List<WorkoutSession>? recentSessions,
  }) {
    return WorkoutSessionState(
      currentSession: currentSession ?? this.currentSession,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      recentSessions: recentSessions ?? this.recentSessions,
    );
  }
}

/// Notifier for managing workout session state
class WorkoutSessionNotifier extends StateNotifier<WorkoutSessionState> {
  final dynamic _sessionRepository; // Temporary fix
  final dynamic _setRepository; // Temporary fix
  final Uuid _uuid = const Uuid();
  final ComputationCache<String, WorkoutSet> _setCache;

  WorkoutSessionNotifier(this._sessionRepository, this._setRepository)
      : _setCache = ComputationCache<String, WorkoutSet>(
          ttl: const Duration(hours: 1),
          maxSize: 100,
        ),
        super(const WorkoutSessionState());

  /// Start a new workout session
  Future<void> startSession({
    required String userId,
    required SessionType sessionType,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Check if there's already an active session
      final activeSessions = await _sessionRepository.findActiveSessionsByUserId(userId);
      if (activeSessions.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'There is already an active workout session',
        );
        return;
      }

      final session = WorkoutSession(
        id: _uuid.v4(),
        userId: userId,
        startTime: DateTime.now(),
        sessionType: sessionType,
        notes: notes,
        createdAt: DateTime.now(),
      );

      final createdSession = await _sessionRepository.create(session);
      
      state = state.copyWith(
        currentSession: createdSession,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to start workout session: $e',
      );
    }
  }

  /// End the current workout session
  Future<void> endSession() async {
    if (state.currentSession == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final endedSession = state.currentSession!.endSession();
      await _sessionRepository.update(endedSession);
      
      state = state.copyWith(
        currentSession: null,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to end workout session: $e',
      );
    }
  }

  /// Add a set to the current session (optimized for <150ms response)
  Future<void> addSet({
    required String exerciseId,
    required double weight,
    required int reps,
    required int rpe,
    int restSeconds = 0,
    String? notes,
  }) async {
    if (state.currentSession == null) {
      state = state.copyWith(error: 'No active workout session');
      return;
    }

    return PerformanceUtils.measureAsync('Add set operation', () async {
      // Optimistic UI update - update state immediately
      final setOrder = state.currentSession!.sets.length + 1;
      
      final newSet = WorkoutSet(
        id: _uuid.v4(),
        sessionId: state.currentSession!.id,
        exerciseId: exerciseId,
        weight: weight,
        reps: reps,
        rpe: rpe,
        restSeconds: restSeconds,
        notes: notes,
        setOrder: setOrder,
        createdAt: DateTime.now(),
      );

      // Quick validation
      final validation = newSet.validate();
      if (validation != null) {
        state = state.copyWith(error: validation);
        return;
      }

      // Update UI immediately (optimistic update)
      final updatedSession = state.currentSession!.addSet(newSet);
      state = state.copyWith(currentSession: updatedSession);

      // Cache the set for quick access
      _setCache.put('${exerciseId}_latest', newSet);

      // Persist to database asynchronously
      try {
        await _setRepository.create(newSet);
      } catch (e) {
        // Rollback optimistic update on failure
        final rolledBackSession = state.currentSession!.removeSet(newSet.id);
        state = state.copyWith(
          currentSession: rolledBackSession,
          error: 'Failed to save set: $e',
        );
        _setCache.clear(); // Clear cache on error
      }
    });
  }

  /// Load recent sessions for a user
  Future<void> loadRecentSessions(String userId) async {
    try {
      final sessions = await _sessionRepository.getRecentSessions(userId, limit: 5);
      state = state.copyWith(recentSessions: sessions);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load recent sessions: $e');
    }
  }

  /// Get the last set for a specific exercise (cached for performance)
  WorkoutSet? getLastSetForExercise(String exerciseId) {
    // Check cache first
    final cachedSet = _setCache.get('${exerciseId}_latest');
    if (cachedSet != null) return cachedSet;
    
    if (state.currentSession == null) return null;
    
    final exerciseSets = state.currentSession!.getSetsForExercise(exerciseId);
    final lastSet = exerciseSets.isNotEmpty ? exerciseSets.last : null;
    
    // Cache the result
    if (lastSet != null) {
      _setCache.put('${exerciseId}_latest', lastSet);
    }
    
    return lastSet;
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for workout session state
final workoutSessionProvider = StateNotifierProvider<WorkoutSessionNotifier, WorkoutSessionState>((ref) {
  final sessionRepository = ref.watch(workoutSessionRepositoryProvider);
  final setRepository = ref.watch(workoutSetRepositoryProvider);
  return WorkoutSessionNotifier(sessionRepository, setRepository);
});

/// Provider for getting recent sets for an exercise (for showing previous values)
final recentSetsForExerciseProvider = FutureProvider.family<List<WorkoutSet>, Map<String, String>>((ref, params) async {
  final setRepository = ref.watch(workoutSetRepositoryProvider);
  final userId = params['userId']!;
  final exerciseId = params['exerciseId']!;
  
  return setRepository.findRecentSetsForExercise(exerciseId, userId, limit: 3);
});