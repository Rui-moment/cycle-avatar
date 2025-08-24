import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/recovery_state.dart';
import '../../domain/entities/muscle_group.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/recovery_engine.dart';
import '../../domain/entities/constants.dart';
import '../../core/utils/performance_utils.dart';

/// State class for recovery data
class RecoveryStateData {
  final Map<String, RecoveryState> recoveryStates;
  final bool isLoading;
  final String? error;

  const RecoveryStateData({
    this.recoveryStates = const {},
    this.isLoading = false,
    this.error,
  });

  RecoveryStateData copyWith({
    Map<String, RecoveryState>? recoveryStates,
    bool? isLoading,
    String? error,
  }) {
    return RecoveryStateData(
      recoveryStates: recoveryStates ?? this.recoveryStates,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing recovery state
class RecoveryNotifier extends StateNotifier<RecoveryStateData> {
  final RecoveryEngine _recoveryEngine;
  final ComputationCache<String, RecoveryState> _recoveryCache;
  DateTime? _lastUpdateTime;

  RecoveryNotifier(this._recoveryEngine) 
      : _recoveryCache = ComputationCache<String, RecoveryState>(
          ttl: const Duration(minutes: 1),
          maxSize: 50,
        ),
        super(const RecoveryStateData()) {
    _initializeRecoveryStates();
  }

  /// Initialize recovery states for all muscle groups
  void _initializeRecoveryStates() {
    PerformanceUtils.measureSync('Recovery states initialization', () {
      state = state.copyWith(isLoading: true);
      
      try {
        final recoveryStates = <String, RecoveryState>{};
        
        // Initialize with fresh recovery states for all muscle groups
        for (final muscleGroupId in MUSCLE_GROUP_IDS) {
          final recoveryState = RecoveryState.fresh(
            id: 'recovery_$muscleGroupId',
            muscleGroupId: muscleGroupId,
          );
          recoveryStates[muscleGroupId] = recoveryState;
          _recoveryCache.put(muscleGroupId, recoveryState);
        }
        
        state = state.copyWith(
          recoveryStates: recoveryStates,
          isLoading: false,
        );
        _lastUpdateTime = DateTime.now();
      } catch (e) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to initialize recovery states: $e',
        );
      }
    });
  }

  /// Update recovery states based on current time
  void updateRecoveryStates() {
    if (state.recoveryStates.isEmpty) return;
    
    // Throttle updates to avoid excessive computation
    final now = DateTime.now();
    if (_lastUpdateTime != null && 
        now.difference(_lastUpdateTime!) < const Duration(seconds: 30)) {
      return;
    }
    
    PerformanceUtils.measureSync('Recovery states update', () {
      try {
        final updatedStates = <String, RecoveryState>{};
        
        // Update states in batches to avoid blocking UI
        for (final entry in state.recoveryStates.entries) {
          final muscleGroupId = entry.key;
          final currentState = entry.value;
          
          // Check cache first
          final cachedState = _recoveryCache.get(muscleGroupId);
          if (cachedState != null && 
              cachedState.lastUpdated.isAfter(currentState.lastUpdated)) {
            updatedStates[muscleGroupId] = cachedState;
            continue;
          }
          
          // Calculate new recovery state
          final updatedState = _recoveryEngine.updateRecoveryState(currentState);
          updatedStates[muscleGroupId] = updatedState;
          _recoveryCache.put(muscleGroupId, updatedState);
        }
        
        state = state.copyWith(recoveryStates: updatedStates);
        _lastUpdateTime = now;
      } catch (e) {
        state = state.copyWith(error: 'Failed to update recovery states: $e');
      }
    });
  }

  /// Get aggregate recovery metrics
  AggregateRecoveryMetrics getAggregateMetrics() {
    return _recoveryEngine.calculateAggregateMetrics(
      recoveryStates: state.recoveryStates,
    );
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for recovery engine
final recoveryEngineProvider = Provider<RecoveryEngine>((ref) {
  return RecoveryEngine();
});

/// Provider for recovery state
final recoveryProvider = StateNotifierProvider<RecoveryNotifier, RecoveryStateData>((ref) {
  final recoveryEngine = ref.watch(recoveryEngineProvider);
  return RecoveryNotifier(recoveryEngine);
});

/// Provider for aggregate recovery metrics
final aggregateRecoveryMetricsProvider = Provider<AggregateRecoveryMetrics>((ref) {
  final recoveryNotifier = ref.watch(recoveryProvider.notifier);
  return recoveryNotifier.getAggregateMetrics();
});