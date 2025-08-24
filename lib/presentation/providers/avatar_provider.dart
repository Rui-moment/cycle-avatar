import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/avatar_state.dart';
import '../../domain/services/avatar_system.dart';
import '../../domain/entities/constants.dart';

/// State class for avatar data
class AvatarStateData {
  final AvatarState? avatarState;
  final bool isLoading;
  final String? error;

  const AvatarStateData({
    this.avatarState,
    this.isLoading = false,
    this.error,
  });

  AvatarStateData copyWith({
    AvatarState? avatarState,
    bool? isLoading,
    String? error,
  }) {
    return AvatarStateData(
      avatarState: avatarState ?? this.avatarState,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing avatar state
class AvatarNotifier extends StateNotifier<AvatarStateData> {
  final AvatarSystem _avatarSystem;

  AvatarNotifier(this._avatarSystem) : super(const AvatarStateData()) {
    _initializeAvatarState();
  }

  /// Initialize avatar state for a user
  void _initializeAvatarState() {
    state = state.copyWith(isLoading: true);
    
    try {
      // Create a fresh avatar state for demo purposes
      // In a real app, this would load from the database
      final avatarState = AvatarState.fresh(
        id: 'avatar_demo_user',
        userId: 'demo_user',
        muscleGroupIds: MUSCLE_GROUP_IDS,
      );
      
      state = state.copyWith(
        avatarState: avatarState,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize avatar state: $e',
      );
    }
  }

  /// Update avatar state
  void updateAvatarState(AvatarState newState) {
    state = state.copyWith(avatarState: newState);
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for avatar system
final avatarSystemProvider = Provider<AvatarSystem>((ref) {
  return AvatarSystem();
});

/// Provider for avatar state
final avatarProvider = StateNotifierProvider<AvatarNotifier, AvatarStateData>((ref) {
  final avatarSystem = ref.watch(avatarSystemProvider);
  return AvatarNotifier(avatarSystem);
});