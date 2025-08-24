import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/workout_session.dart';
import '../../providers/workout_session_provider.dart';
import 'exercise_search_field.dart';
import 'quick_set_entry.dart';
import 'exercise_sets_list.dart';

/// High-speed workout logger optimized for quick set entry
class HighSpeedWorkoutLogger extends ConsumerStatefulWidget {
  final VoidCallback? onWorkoutComplete;

  const HighSpeedWorkoutLogger({
    super.key,
    this.onWorkoutComplete,
  });

  @override
  ConsumerState<HighSpeedWorkoutLogger> createState() => _HighSpeedWorkoutLoggerState();
}

class _HighSpeedWorkoutLoggerState extends ConsumerState<HighSpeedWorkoutLogger> {
  Exercise? _selectedExercise;
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workoutState = ref.watch(workoutSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Log'),
        actions: [
          if (workoutState.currentSession != null)
            TextButton.icon(
              onPressed: _endWorkout,
              icon: const Icon(Icons.stop),
              label: const Text('End'),
            ),
        ],
      ),
      body: workoutState.currentSession == null
          ? _buildStartWorkoutView()
          : _buildWorkoutView(),
      bottomNavigationBar: workoutState.currentSession != null && _selectedExercise != null
          ? _buildBottomNavigationBar()
          : null,
    );
  }

  Widget _buildStartWorkoutView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Ready to start your workout?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Start logging sets quickly and efficiently',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _startWorkout,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Workout'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutView() {
    return Column(
      children: [
        // Exercise selection
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ExerciseSearchField(
            selectedExercise: _selectedExercise,
            onExerciseSelected: (exercise) {
              setState(() {
                _selectedExercise = exercise;
              });
            },
            hintText: 'Select exercise to log sets...',
            showRecentExercises: true,
            enableQuickSelection: true,
          ),
        ),

        // Content area
        Expanded(
          child: _selectedExercise == null
              ? _buildExerciseSelectionPrompt()
              : PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPageIndex = index;
                    });
                  },
                  children: [
                    _buildQuickEntryView(),
                    _buildSetsHistoryView(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildExerciseSelectionPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Select an exercise to start logging',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the search field above or tap a recent exercise',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickEntryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick set entry
          QuickSetEntry(
            exerciseId: _selectedExercise!.id,
            showExerciseName: false,
            onSetAdded: () {
              // Optionally scroll to show the new set
            },
          ),

          const SizedBox(height: 16),

          // Current session sets for this exercise
          _buildCurrentExerciseSets(),
        ],
      ),
    );
  }

  Widget _buildSetsHistoryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All Sets - ${_selectedExercise!.getLocalizedName('en')}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ExerciseSetsList(
            exerciseId: _selectedExercise!.id,
            showExerciseName: false,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentExerciseSets() {
    final workoutState = ref.watch(workoutSessionProvider);
    final currentSets = workoutState.currentSession?.getSetsForExercise(_selectedExercise!.id) ?? [];

    if (currentSets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Text(
              'No sets logged yet for this exercise',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Sets',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ...currentSets.asMap().entries.map((entry) {
          final index = entry.key;
          final set = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              title: Text(
                '${set.weight}kg × ${set.reps} reps',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text('RPE ${set.rpe}'),
              trailing: Text(
                '${set.volume.toStringAsFixed(0)}kg',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentPageIndex,
      onTap: (index) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          activeIcon: Icon(Icons.add_circle),
          label: 'Quick Entry',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          activeIcon: Icon(Icons.history),
          label: 'History',
        ),
      ],
    );
  }

  Future<void> _startWorkout() async {
    await ref.read(workoutSessionProvider.notifier).startSession(
      userId: 'user_1', // TODO: Get from user provider
      sessionType: SessionType.strength, // TODO: Allow user to select
    );
  }

  Future<void> _endWorkout() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Workout'),
        content: const Text('Are you sure you want to end this workout session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End Workout'),
          ),
        ],
      ),
    );

    if (shouldEnd == true) {
      await ref.read(workoutSessionProvider.notifier).endSession();
      widget.onWorkoutComplete?.call();
    }
  }
}