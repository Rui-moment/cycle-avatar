import 'package:flutter/material.dart';

import '../../../domain/entities/workout_session.dart';

class SessionStatsCard extends StatelessWidget {
  final WorkoutSession session;

  const SessionStatsCard({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final duration = session.isActive 
        ? DateTime.now().difference(session.startTime)
        : session.duration ?? Duration.zero;

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  session.sessionType.getLocalizedName('en'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (session.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Duration',
                    _formatDuration(duration),
                    Icons.timer,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Sets',
                    '${session.totalSets}',
                    Icons.repeat,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Volume',
                    '${session.totalVolume.toStringAsFixed(0)} kg',
                    Icons.fitness_center,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Exercises',
                    '${session.uniqueExercises.length}',
                    Icons.list,
                  ),
                ),
              ],
            ),
            if (session.averageRPE > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.speed,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Average RPE: ${session.averageRPE.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}