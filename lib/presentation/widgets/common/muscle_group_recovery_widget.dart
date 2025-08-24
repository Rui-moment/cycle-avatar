import 'package:flutter/material.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/recovery_state.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../domain/entities/constants.dart';

/// Widget for displaying muscle group recovery status
class MuscleGroupRecoveryWidget extends StatelessWidget {
  final Map<String, RecoveryState> recoveryStates;
  final bool isCompact;

  const MuscleGroupRecoveryWidget({
    super.key,
    required this.recoveryStates,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    if (isCompact) {
      return _buildCompactView(context, l10n);
    }
    
    return _buildDetailedView(context, l10n);
  }

  Widget _buildCompactView(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.muscleGroupRecovery,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRecoveryOverview(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedView(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.muscleGroupRecovery,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRecoveryOverview(context, l10n),
            const SizedBox(height: 16),
            _buildMuscleGroupGrid(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryOverview(BuildContext context, AppLocalizations l10n) {
    final readyCount = recoveryStates.values
        .where((state) => state.readinessLevel == ReadinessLevel.ready)
        .length;
    final warmCount = recoveryStates.values
        .where((state) => state.readinessLevel == ReadinessLevel.warm)
        .length;
    final fatiguedCount = recoveryStates.values
        .where((state) => state.readinessLevel == ReadinessLevel.fatigued)
        .length;

    return Row(
      children: [
        _buildStatusChip(
          context,
          l10n.ready,
          readyCount,
          Colors.green,
          Icons.check_circle,
        ),
        const SizedBox(width: 8),
        _buildStatusChip(
          context,
          l10n.warm,
          warmCount,
          Colors.orange,
          Icons.schedule,
        ),
        const SizedBox(width: 8),
        _buildStatusChip(
          context,
          l10n.fatigued,
          fatiguedCount,
          Colors.red,
          Icons.warning,
        ),
      ],
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    String label,
    int count,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleGroupGrid(BuildContext context, AppLocalizations l10n) {
    final muscleGroups = recoveryStates.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 3,
      ),
      itemCount: muscleGroups.length,
      itemBuilder: (context, index) {
        final entry = muscleGroups[index];
        final muscleGroupId = entry.key;
        final recoveryState = entry.value;
        
        return _buildMuscleGroupTile(
          context,
          l10n,
          muscleGroupId,
          recoveryState,
        );
      },
    );
  }

  Widget _buildMuscleGroupTile(
    BuildContext context,
    AppLocalizations l10n,
    String muscleGroupId,
    RecoveryState recoveryState,
  ) {
    final color = _getColorForReadiness(recoveryState.readinessLevel);
    final icon = _getIconForReadiness(recoveryState.readinessLevel);
    final muscleGroupName = _getMuscleGroupName(muscleGroupId, l10n);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  muscleGroupName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${(recoveryState.recoveryPercentage * 100).round()}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForReadiness(ReadinessLevel readiness) {
    switch (readiness) {
      case ReadinessLevel.ready:
        return Colors.green;
      case ReadinessLevel.warm:
        return Colors.orange;
      case ReadinessLevel.fatigued:
        return Colors.red;
    }
  }

  IconData _getIconForReadiness(ReadinessLevel readiness) {
    switch (readiness) {
      case ReadinessLevel.ready:
        return Icons.check_circle;
      case ReadinessLevel.warm:
        return Icons.schedule;
      case ReadinessLevel.fatigued:
        return Icons.warning;
    }
  }

  String _getMuscleGroupName(String muscleGroupId, AppLocalizations l10n) {
    // For now, return the ID capitalized
    // In a real app, this would use localized muscle group names
    return muscleGroupId.split('_').map((word) => 
        word[0].toUpperCase() + word.substring(1)).join(' ');
  }
}