import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/recovery_state.dart';
import '../../../domain/entities/avatar_state.dart';
import '../../../domain/entities/enums.dart';

/// Enhanced fitness avatar widget that displays a vector-based fitness avatar
/// with dynamic coloring and effects based on muscle recovery states and levels
class FitnessAvatarWidget extends StatelessWidget {
  final AvatarState avatarState;
  final Map<String, RecoveryState> recoveryStates;
  final double size;
  final bool showLevelIndicator;
  final bool showCooldownEffects;

  const FitnessAvatarWidget({
    super.key,
    required this.avatarState,
    required this.recoveryStates,
    this.size = 200,
    this.showLevelIndicator = true,
    this.showCooldownEffects = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.5, // 400x600 aspect ratio
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background glow effect based on overall recovery
          if (_shouldShowGlowEffect())
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: _getGlowColor().withOpacity(0.3),
                      blurRadius: size * 0.15,
                      spreadRadius: size * 0.05,
                    ),
                  ],
                ),
              ),
            ),

          // Main avatar image with color overlay
          ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.05),
            child: Stack(
              children: [
                // Base avatar image
                Image.asset(
                  _getAvatarAssetPath(),
                  width: size,
                  height: size * 1.5,
                  fit: BoxFit.contain,
                ),

                // Color overlay based on recovery state
                if (_shouldShowColorOverlay())
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(size * 0.05),
                        color: _getOverlayColor().withOpacity(0.2),
                      ),
                    ),
                  ),

                // Cooldown overlay (grayscale effect)
                if (showCooldownEffects && _hasActiveCooldowns())
                  Positioned.fill(
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(size * 0.05),
                          color: Colors.black.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Level indicator
          if (showLevelIndicator)
            Positioned(
              top: size * 0.05,
              right: size * 0.05,
              child: _buildLevelIndicator(context),
            ),

          // Muscle group progress indicators
          ..._buildMuscleGroupIndicators(context),

          // Cooldown timer overlay
          if (showCooldownEffects && _hasActiveCooldowns())
            Positioned(
              bottom: size * 0.1,
              child: _buildCooldownIndicator(context),
            ),
        ],
      ),
    );
  }

  /// Gets the appropriate avatar asset path based on size requirements
  String _getAvatarAssetPath() {
    if (size <= 64) return 'assets/fitness_avatar_64.png';
    if (size <= 128) return 'assets/fitness_avatar_128.png';
    return 'assets/fitness_avatar.png';
  }

  /// Determines if glow effect should be shown
  bool _shouldShowGlowEffect() {
    final averageRecovery = _getAverageRecovery();
    return averageRecovery > 0.8 || avatarState.hasRecentLevelUp;
  }

  /// Gets glow color based on state
  Color _getGlowColor() {
    if (avatarState.hasRecentLevelUp) {
      return Colors.yellow; // Level up celebration
    }
    final averageRecovery = _getAverageRecovery();
    if (averageRecovery > 0.9) return Colors.green;
    if (averageRecovery > 0.8) return Colors.blue;
    return Colors.orange;
  }

  /// Determines if color overlay should be shown
  bool _shouldShowColorOverlay() {
    return _getAverageRecovery() < 0.6 || _hasHighFatigue();
  }

  /// Gets overlay color based on recovery state
  Color _getOverlayColor() {
    if (_hasHighFatigue()) return Colors.red;
    final averageRecovery = _getAverageRecovery();
    if (averageRecovery < 0.4) return Colors.red;
    if (averageRecovery < 0.6) return Colors.orange;
    return Colors.transparent;
  }

  /// Builds the level indicator badge
  Widget _buildLevelIndicator(BuildContext context) {
    final overallLevel = avatarState.overallLevel;
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
        'Lv ${maxLevel}',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.06,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Builds muscle group progress indicators around the avatar
  List<Widget> _buildMuscleGroupIndicators(BuildContext context) {
    if (size < 150) return []; // Too small to show indicators

    final indicators = <Widget>[];
    final muscleGroups = [
      // Upper body
      {'id': 'chest', 'position': Offset(size * 0.5, size * 0.4)},
      {'id': 'shoulders', 'position': Offset(size * 0.2, size * 0.3)},
      {'id': 'shoulders', 'position': Offset(size * 0.8, size * 0.3)},
      {'id': 'biceps', 'position': Offset(size * 0.15, size * 0.5)},
      {'id': 'triceps', 'position': Offset(size * 0.85, size * 0.5)},
      {'id': 'back', 'position': Offset(size * 0.5, size * 0.25)},
      // Lower body
      {'id': 'quadriceps', 'position': Offset(size * 0.4, size * 1.0)},
      {'id': 'quadriceps', 'position': Offset(size * 0.6, size * 1.0)},
      {'id': 'hamstrings', 'position': Offset(size * 0.4, size * 1.1)},
      {'id': 'hamstrings', 'position': Offset(size * 0.6, size * 1.1)},
      {'id': 'calves', 'position': Offset(size * 0.4, size * 1.3)},
      {'id': 'calves', 'position': Offset(size * 0.6, size * 1.3)},
    ];

    for (final group in muscleGroups) {
      final muscleGroupId = group['id'] as String;
      final position = group['position'] as Offset;
      final level = avatarState.getLevelForMuscleGroup(muscleGroupId);
      final progress = avatarState.getProgressToNextLevel(muscleGroupId);
      final recovery = recoveryStates[muscleGroupId];

      if (level > 0 || progress > 0) {
        indicators.add(
          Positioned(
            left: position.dx - size * 0.025,
            top: position.dy - size * 0.025,
            child: _buildMuscleGroupBadge(
              context,
              muscleGroupId,
              level,
              progress,
              recovery?.readinessLevel ?? ReadinessLevel.ready,
            ),
          ),
        );
      }
    }

    return indicators;
  }

  /// Builds individual muscle group badge
  Widget _buildMuscleGroupBadge(
    BuildContext context,
    String muscleGroupId,
    int level,
    double progress,
    ReadinessLevel readiness,
  ) {
    Color badgeColor;
    switch (readiness) {
      case ReadinessLevel.ready:
        badgeColor = Colors.green;
        break;
      case ReadinessLevel.warm:
        badgeColor = Colors.orange;
        break;
      case ReadinessLevel.fatigued:
        badgeColor = Colors.red;
        break;
    }

    return Container(
      width: size * 0.05,
      height: size * 0.05,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          level.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.025,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Builds cooldown indicator
  Widget _buildCooldownIndicator(BuildContext context) {
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
            size: size * 0.05,
          ),
          SizedBox(width: size * 0.02),
          Text(
            'Cooldown: ${cooldownGroups.length}',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.04,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Helper methods
  double _getAverageRecovery() {
    if (recoveryStates.isEmpty) return 1.0;
    final total = recoveryStates.values
        .map((s) => s.recoveryPercentage)
        .fold<double>(0, (a, b) => a + b);
    return total / recoveryStates.length;
  }

  bool _hasActiveCooldowns() {
    return avatarState.muscleGroupsInCooldown.isNotEmpty;
  }

  bool _hasHighFatigue() {
    return recoveryStates.values
        .any((state) => state.readinessLevel == ReadinessLevel.fatigued);
  }
}
