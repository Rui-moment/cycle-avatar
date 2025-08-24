import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/workout_session_provider.dart';
import '../../providers/exercise_provider.dart';
import '../../widgets/workout/workout_session_view.dart';
import '../../widgets/workout/start_workout_dialog.dart';
import '../../../domain/entities/enums.dart';
import '../../../core/l10n/app_localizations.dart';

class WorkoutPage extends ConsumerWidget {
  const WorkoutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutState = ref.watch(workoutSessionProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workout),
        actions: [
          if (workoutState.currentSession != null)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () => _showEndSessionDialog(context, ref),
              tooltip: 'End Workout',
            ),
        ],
      ),
      body: workoutState.currentSession != null
          ? WorkoutSessionView(session: workoutState.currentSession!)
          : _buildStartWorkoutView(context, ref),
      floatingActionButton: workoutState.currentSession == null
          ? FloatingActionButton.extended(
              onPressed: () => _showStartWorkoutDialog(context, ref),
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.startWorkout),
            )
          : null,
    );
  }

  Widget _buildStartWorkoutView(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final workoutState = ref.watch(workoutSessionProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.quickLog,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a new workout session to begin logging your sets.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 20),
                      const SizedBox(width: 8),
                      Text('Quick set entry (< 10 seconds per exercise)'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.history, size: 20),
                      const SizedBox(width: 8),
                      Text('Previous values auto-displayed'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.offline_bolt, size: 20),
                      const SizedBox(width: 8),
                      Text('Works completely offline'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (workoutState.recentSessions.isNotEmpty) ...[
            Text(
              'Recent Sessions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: workoutState.recentSessions.length,
                itemBuilder: (context, index) {
                  final session = workoutState.recentSessions[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(session.sessionType.name[0].toUpperCase()),
                      ),
                      title: Text(session.sessionType.getLocalizedName('en')),
                      subtitle: Text(
                        '${session.startTime.day}/${session.startTime.month}/${session.startTime.year} • '
                        '${session.totalSets} sets • ${session.totalVolume.toStringAsFixed(0)} kg',
                      ),
                      trailing: session.isActive
                          ? const Chip(
                              label: Text('Active'),
                              backgroundColor: Colors.green,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showStartWorkoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => StartWorkoutDialog(),
    );
  }

  void _showEndSessionDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Workout'),
        content: const Text('Are you sure you want to end this workout session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(workoutSessionProvider.notifier).endSession();
              Navigator.of(context).pop();
            },
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }
}