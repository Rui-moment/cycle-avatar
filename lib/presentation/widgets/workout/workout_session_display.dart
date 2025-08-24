import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/workout_session.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/enums.dart';
import '../../providers/exercise_provider.dart';

class WorkoutSessionDisplay extends ConsumerWidget {
  final WorkoutSession session;
  final bool showEndButton;
  final VoidCallback? onEndSession;

  const WorkoutSessionDisplay({
    super.key,
    required this.session,
    this.showEndButton = false,
    this.onEndSession,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: session.isActive 
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        session.isActive ? Icons.play_circle : Icons.check_circle,
                        size: 16,
                        color: session.isActive 
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        session.isActive ? 'Active' : 'Completed',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: session.isActive 
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (showEndButton && session.isActive)
                  TextButton.icon(
                    onPressed: onEndSession,
                    icon: const Icon(Icons.stop),
                    label: const Text('End Workout'),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Session info
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    context,
                    'Type',
                    session.sessionType.getLocalizedName('en'),
                    Icons.category,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    context,
                    'Duration',
                    _formatDuration(session.duration ?? Duration.zero),
                    Icons.timer,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    context,
                    'Sets',
                    '${session.totalSets}',
                    Icons.fitness_center,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    context,
                    'Volume',
                    '${session.totalVolume.toStringAsFixed(0)} kg',
                    Icons.scale,
                  ),
                ),
              ],
            ),
            
            if (session.sets.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              
              // Sets by exercise
              Text(
                'Exercises',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              ...session.uniqueExercises.map((exerciseId) {
                final exerciseSets = session.getSetsForExercise(exerciseId);
                return _buildExerciseSection(context, ref, exerciseId, exerciseSets);
              }).toList(),
            ],
            
            if (session.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                session.notes!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExerciseSection(
    BuildContext context, 
    WidgetRef ref, 
    String exerciseId, 
    List<WorkoutSet> sets,
  ) {
    return Consumer(
      builder: (context, ref, child) {
        final exerciseAsync = ref.watch(exercisesProvider);
        
        return exerciseAsync.when(
          data: (exercises) {
            final exercise = exercises.firstWhere(
              (e) => e.id == exerciseId,
              orElse: () => Exercise(
                id: exerciseId,
                names: {'en': 'Unknown Exercise'},
                category: 'Unknown',
                equipment: EquipmentType.other,
                instructions: {},
                primaryMuscleGroups: [],
                secondaryMuscleGroups: [],
                createdAt: DateTime.now(),
              ),
            );
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.getLocalizedName('en'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: sets.map((set) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${set.weight}kg × ${set.reps} @ ${set.rpe}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(
            height: 20,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Text('Error loading exercise: $error'),
        );
      },
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