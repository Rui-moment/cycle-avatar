import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/workout_session.dart';
import '../../providers/exercise_provider.dart';

class ExerciseSetsList extends ConsumerWidget {
  final WorkoutSession session;
  final ScrollController? scrollController;

  const ExerciseSetsList({
    super.key,
    required this.session,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Group sets by exercise
    final exerciseGroups = <String, List<WorkoutSet>>{};
    for (final set in session.sets) {
      exerciseGroups.putIfAbsent(set.exerciseId, () => []).add(set);
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: exerciseGroups.length,
      itemBuilder: (context, index) {
        final exerciseId = exerciseGroups.keys.elementAt(index);
        final sets = exerciseGroups[exerciseId]!;
        
        return _ExerciseGroupCard(
          exerciseId: exerciseId,
          sets: sets,
        );
      },
    );
  }
}

class _ExerciseGroupCard extends ConsumerWidget {
  final String exerciseId;
  final List<WorkoutSet> sets;

  const _ExerciseGroupCard({
    required this.exerciseId,
    required this.sets,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exerciseAsync = ref.watch(exerciseProvider(exerciseId));

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise header
            Row(
              children: [
                Expanded(
                  child: exerciseAsync.when(
                    data: (exercise) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise?.getLocalizedName('en') ?? 'Unknown Exercise',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (exercise != null)
                          Text(
                            exercise.category,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                    loading: () => const Text('Loading...'),
                    error: (_, __) => const Text('Unknown Exercise'),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${sets.length} sets',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sets table header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 40, child: Text('Set', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Expanded(child: Text('Weight', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Expanded(child: Text('Reps', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Expanded(child: Text('RPE', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Expanded(child: Text('Volume', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),

            // Sets list
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Column(
                children: sets.asMap().entries.map((entry) {
                  final index = entry.key;
                  final set = entry.value;
                  final isLast = index == sets.length - 1;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      border: isLast ? null : Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${index + 1}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text('${set.weight} kg'),
                        ),
                        Expanded(
                          child: Text('${set.reps}'),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRPEColor(set.rpe).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${set.rpe}',
                              style: TextStyle(
                                color: _getRPEColor(set.rpe),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${set.volume.toStringAsFixed(0)} kg',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // Exercise summary
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    context,
                    'Total Volume',
                    '${sets.fold(0.0, (sum, set) => sum + set.volume).toStringAsFixed(0)} kg',
                  ),
                  _buildSummaryItem(
                    context,
                    'Avg RPE',
                    '${(sets.fold(0, (sum, set) => sum + set.rpe) / sets.length).toStringAsFixed(1)}',
                  ),
                  _buildSummaryItem(
                    context,
                    'Best Set',
                    '${sets.reduce((a, b) => a.volume > b.volume ? a : b).weight} kg × ${sets.reduce((a, b) => a.volume > b.volume ? a : b).reps}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

  Color _getRPEColor(int rpe) {
    if (rpe <= 4) return Colors.green;
    if (rpe <= 6) return Colors.lightGreen;
    if (rpe <= 7) return Colors.yellow.shade700;
    if (rpe <= 8) return Colors.orange;
    if (rpe <= 9) return Colors.red;
    return Colors.red.shade900;
  }
}