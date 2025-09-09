import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';

/// A simple 2D avatar widget that reflects the current avatar level
/// and per-muscle group fatigue with localized status chips.
class Avatar2DWidget extends ConsumerWidget {
  const Avatar2DWidget({super.key, this.size = 160});

  final double size;

  Color _fatigueToColor(double fatigue) {
    if (fatigue >= 80) return Colors.red;
    if (fatigue >= 40) return Colors.orange;
    return Colors.green;
  }

  String _stateText(MuscleGroupState state, AppLocalizations l10n) {
    switch (state) {
      case MuscleGroupState.ready:
        return l10n.ready;
      case MuscleGroupState.warm:
        return l10n.warm;
      case MuscleGroupState.fatigued:
        return l10n.fatigued;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(workoutDataProvider);

    // Average fatigue → subtle outer glow only (no full overlay)
    final avgFatigue = data.muscleGroupFatigue.values.isEmpty
        ? 0.0
        : data.muscleGroupFatigue.values.reduce((a, b) => a + b) /
            data.muscleGroupFatigue.values.length;
    final glowColor = _fatigueToColor(avgFatigue).withValues(alpha: 0.35);

    // Scale avatar slightly by level progress (fractional part 0..1)
    final levelProgress = data.avatarLevel % 1.0; // 0.0 .. <1.0
    final scale = 1.0 + levelProgress * 0.08; // up to +8%

    // Convenience getters
    double f(String k) => data.muscleGroupFatigue[k] ?? 0.0;
    MuscleGroupState s(String k) => data.muscleGroupStates[k] ?? MuscleGroupState.ready;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.12),
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Base image (PNG asset)
              Transform.scale(
                scale: scale,
                child: Image.asset(
                  'assets/fitness_avatar.png',
                  fit: BoxFit.contain,
                ),
              ),

              // 5 muscle group status badges around the avatar
              // Shoulders (top center)
              Positioned(
                top: 6,
                child: _StatusBadge(
                  label: l10n.shoulders,
                  value: f('Shoulders').toInt(),
                  stateText: _stateText(s('Shoulders'), l10n),
                  color: _fatigueToColor(f('Shoulders')),
                ),
              ),
              // Chest (left center)
              Positioned(
                left: 6,
                child: _StatusBadge(
                  label: l10n.chest,
                  value: f('Chest').toInt(),
                  stateText: _stateText(s('Chest'), l10n),
                  color: _fatigueToColor(f('Chest')),
                ),
              ),
              // Back (right center)
              Positioned(
                right: 6,
                child: _StatusBadge(
                  label: l10n.back,
                  value: f('Back').toInt(),
                  stateText: _stateText(s('Back'), l10n),
                  color: _fatigueToColor(f('Back')),
                ),
              ),
              // Arms (bottom-left)
              Positioned(
                left: 6,
                bottom: 6,
                child: _StatusBadge(
                  label: l10n.arms,
                  value: f('Arms').toInt(),
                  stateText: _stateText(s('Arms'), l10n),
                  color: _fatigueToColor(f('Arms')),
                ),
              ),
              // Legs (bottom-right)
              Positioned(
                right: 6,
                bottom: 6,
                child: _StatusBadge(
                  label: l10n.legs,
                  value: f('Legs').toInt(),
                  stateText: _stateText(s('Legs'), l10n),
                  color: _fatigueToColor(f('Legs')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Level ${data.avatarLevel.toStringAsFixed(1)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.value,
    required this.stateText,
    required this.color,
  });

  final String label;
  final int value;
  final String stateText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textColor = color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: textColor)),
              Text('$stateText • ${value}%',
                  style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.9))),
            ],
          ),
        ],
      ),
    );
  }
}
