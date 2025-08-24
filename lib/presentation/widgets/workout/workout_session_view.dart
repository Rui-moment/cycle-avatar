import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/workout_session.dart';
import '../../providers/exercise_provider.dart';
import 'exercise_selector.dart';
import 'set_entry_form.dart';
import 'session_stats_card.dart';
import 'exercise_sets_list.dart';

class WorkoutSessionView extends ConsumerStatefulWidget {
  final WorkoutSession session;

  const WorkoutSessionView({
    super.key,
    required this.session,
  });

  @override
  ConsumerState<WorkoutSessionView> createState() => _WorkoutSessionViewState();
}

class _WorkoutSessionViewState extends ConsumerState<WorkoutSessionView> {
  String? _selectedExerciseId;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Session stats at the top
        SessionStatsCard(session: widget.session),
        
        // Exercise selector
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ExerciseSelector(
            selectedExerciseId: _selectedExerciseId,
            onExerciseSelected: (exerciseId) {
              setState(() {
                _selectedExerciseId = exerciseId;
              });
            },
          ),
        ),

        // Set entry form (only shown when exercise is selected)
        if (_selectedExerciseId != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SetEntryForm(
              exerciseId: _selectedExerciseId!,
              onSetAdded: () {
                // Scroll to bottom to show new set
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
              },
            ),
          ),

        const SizedBox(height: 16),

        // Exercise sets list
        Expanded(
          child: widget.session.sets.isEmpty
              ? _buildEmptyState()
              : ExerciseSetsList(
                  session: widget.session,
                  scrollController: _scrollController,
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No sets logged yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select an exercise above to start logging sets',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}