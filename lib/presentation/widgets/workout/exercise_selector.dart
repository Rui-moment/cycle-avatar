import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/exercise_provider.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/enums.dart';

class ExerciseSelector extends ConsumerStatefulWidget {
  final String? selectedExerciseId;
  final Function(String) onExerciseSelected;

  const ExerciseSelector({
    super.key,
    required this.selectedExerciseId,
    required this.onExerciseSelected,
  });

  @override
  ConsumerState<ExerciseSelector> createState() => _ExerciseSelectorState();
}

class _ExerciseSelectorState extends ConsumerState<ExerciseSelector> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exerciseListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Exercise',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search exercises...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
        const SizedBox(height: 8),
        exercisesAsync.when(
          data: (exercises) {
            final filteredExercises = _searchQuery.isEmpty
                ? exercises
                : exercises.where((exercise) {
                    final name = exercise.getLocalizedName('en').toLowerCase();
                    final category = exercise.category.toLowerCase();
                    return name.contains(_searchQuery) || category.contains(_searchQuery);
                  }).toList();

            if (filteredExercises.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No exercises found'),
              );
            }

            return SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filteredExercises.length,
                itemBuilder: (context, index) {
                  final exercise = filteredExercises[index];
                  final isSelected = exercise.id == widget.selectedExerciseId;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: SizedBox(
                      width: 140,
                      child: Card(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: InkWell(
                          onTap: () => widget.onExerciseSelected(exercise.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getEquipmentIcon(exercise.equipment),
                                      size: 16,
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.onPrimaryContainer
                                          : Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    if (exercise.isCompound)
                                      Icon(
                                        Icons.group_work,
                                        size: 12,
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.onPrimaryContainer
                                            : Theme.of(context).colorScheme.outline,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Text(
                                    exercise.getLocalizedName('en'),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: isSelected ? FontWeight.bold : null,
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.onPrimaryContainer
                                          : null,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  exercise.category,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.onPrimaryContainer
                                        : Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading exercises: $error'),
          ),
        ),
      ],
    );
  }

  IconData _getEquipmentIcon(EquipmentType equipment) {
    switch (equipment) {
      case EquipmentType.barbell:
        return Icons.fitness_center;
      case EquipmentType.dumbbell:
        return Icons.fitness_center;
      case EquipmentType.machine:
        return Icons.precision_manufacturing;
      case EquipmentType.cable:
        return Icons.cable;
      case EquipmentType.bodyweight:
        return Icons.accessibility;
      case EquipmentType.kettlebell:
        return Icons.sports_gymnastics;
      case EquipmentType.resistance_band:
        return Icons.linear_scale;
      case EquipmentType.other:
        return Icons.more_horiz;
    }
  }
}