import 'package:flutter/material.dart';

import '../../../domain/entities/recovery_state.dart';
import '../../../domain/entities/avatar_state.dart';
import 'anime_avatar_widget.dart';
import 'fitness_avatar_widget.dart';

/// Avatar style options
enum AvatarStyle {
  anime,
  fitness,
}

/// Composite avatar widget that can switch between different avatar styles
/// while maintaining the same interface and functionality
class CompositeAvatarWidget extends StatelessWidget {
  final AvatarState avatarState;
  final Map<String, RecoveryState> recoveryStates;
  final double size;
  final AvatarStyle style;
  final bool showLevelIndicator;
  final bool showCooldownEffects;
  final bool showStyleToggle;
  final ValueChanged<AvatarStyle>? onStyleChanged;

  const CompositeAvatarWidget({
    super.key,
    required this.avatarState,
    required this.recoveryStates,
    this.size = 200,
    this.style = AvatarStyle.fitness,
    this.showLevelIndicator = true,
    this.showCooldownEffects = true,
    this.showStyleToggle = false,
    this.onStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Main avatar display
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: _buildCurrentAvatar(),
        ),

        // Style toggle button (if enabled)
        if (showStyleToggle && onStyleChanged != null)
          Positioned(
            top: 0,
            left: 0,
            child: _buildStyleToggle(context),
          ),
      ],
    );
  }

  /// Builds the current avatar based on selected style
  Widget _buildCurrentAvatar() {
    switch (style) {
      case AvatarStyle.anime:
        return SizedBox(
          key: const ValueKey('anime_avatar'),
          width: size,
          height: size * 1.33, // Adjust aspect ratio for anime avatar
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Anime avatar (scaled to fit)
              Transform.scale(
                scale: size / 180, // AnimeAvatarWidget uses fixed 180x240 size
                child: AnimeAvatarWidget(recoveryStates: recoveryStates),
              ),

              // Additional overlays for anime avatar
              if (showLevelIndicator)
                Positioned(
                  top: size * 0.05,
                  right: size * 0.05,
                  child: _buildLevelBadge(context),
                ),

              if (showCooldownEffects && _hasActiveCooldowns())
                Positioned(
                  bottom: size * 0.05,
                  child: _buildCooldownBadge(context),
                ),
            ],
          ),
        );

      case AvatarStyle.fitness:
        return FitnessAvatarWidget(
          key: const ValueKey('fitness_avatar'),
          avatarState: avatarState,
          recoveryStates: recoveryStates,
          size: size,
          showLevelIndicator: showLevelIndicator,
          showCooldownEffects: showCooldownEffects,
        );
    }
  }

  /// Builds the style toggle button
  Widget _buildStyleToggle(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final newStyle = style == AvatarStyle.fitness 
              ? AvatarStyle.anime 
              : AvatarStyle.fitness;
          onStyleChanged?.call(newStyle);
        },
        borderRadius: BorderRadius.circular(size * 0.03),
        child: Container(
          padding: EdgeInsets.all(size * 0.02),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(size * 0.03),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            style == AvatarStyle.fitness ? Icons.face : Icons.fitness_center,
            size: size * 0.06,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  /// Builds a level badge for the anime avatar
  Widget _buildLevelBadge(BuildContext context) {
    final maxLevel = avatarState.maxLevel;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.04,
        vertical: size * 0.02,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(size * 0.02),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'Lv $maxLevel',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.05,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Builds a cooldown badge for the anime avatar
  Widget _buildCooldownBadge(BuildContext context) {
    final cooldownGroups = avatarState.muscleGroupsInCooldown;
    if (cooldownGroups.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.04,
        vertical: size * 0.02,
      ),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.9),
        borderRadius: BorderRadius.circular(size * 0.02),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            color: Colors.white,
            size: size * 0.04,
          ),
          SizedBox(width: size * 0.02),
          Text(
            'Cooldown: ${cooldownGroups.length}',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.035,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Helper methods
  bool _hasActiveCooldowns() {
    return avatarState.muscleGroupsInCooldown.isNotEmpty;
  }
}

/// Extension to provide additional avatar style utilities
extension AvatarStyleExtensions on AvatarStyle {
  String get displayName {
    switch (this) {
      case AvatarStyle.anime:
        return 'Anime Style';
      case AvatarStyle.fitness:
        return 'Fitness Style';
    }
  }

  IconData get icon {
    switch (this) {
      case AvatarStyle.anime:
        return Icons.face;
      case AvatarStyle.fitness:
        return Icons.fitness_center;
    }
  }
}
