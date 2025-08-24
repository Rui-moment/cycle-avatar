import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/workout_session_provider.dart';
import '../../providers/exercise_provider.dart';
import '../../../domain/entities/workout_session.dart';
import '../../../domain/entities/constants.dart';
import 'rpe_picker.dart';

class SetEntryForm extends ConsumerStatefulWidget {
  final String exerciseId;
  final VoidCallback? onSetAdded;

  const SetEntryForm({
    super.key,
    required this.exerciseId,
    this.onSetAdded,
  });

  @override
  ConsumerState<SetEntryForm> createState() => _SetEntryFormState();
}

class _SetEntryFormState extends ConsumerState<SetEntryForm> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _notesController = TextEditingController();
  int _selectedRPE = 7;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreviousValues();
  }

  @override
  void didUpdateWidget(SetEntryForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseId != widget.exerciseId) {
      _loadPreviousValues();
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadPreviousValues() {
    // Load previous values from the current session or recent sessions
    final workoutState = ref.read(workoutSessionProvider);
    final lastSet = workoutState.currentSession?.getSetsForExercise(widget.exerciseId).lastOrNull;
    
    if (lastSet != null) {
      _weightController.text = lastSet.weight.toString();
      _repsController.text = lastSet.reps.toString();
      _selectedRPE = lastSet.rpe;
    } else {
      // Load from recent sessions
      final recentSetsAsync = ref.read(recentSetsForExerciseProvider({
        'userId': 'user_1', // TODO: Get from user provider
        'exerciseId': widget.exerciseId,
      }));
      
      recentSetsAsync.whenData((recentSets) {
        if (recentSets.isNotEmpty && mounted) {
          final lastRecentSet = recentSets.first;
          _weightController.text = lastRecentSet.weight.toString();
          _repsController.text = lastRecentSet.reps.toString();
          _selectedRPE = lastRecentSet.rpe;
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final exerciseAsync = ref.watch(exerciseProvider(widget.exerciseId));
    final workoutState = ref.watch(workoutSessionProvider);
    final recentSetsAsync = ref.watch(recentSetsForExerciseProvider({
      'userId': 'user_1', // TODO: Get from user provider
      'exerciseId': widget.exerciseId,
    }));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            exerciseAsync.when(
              data: (exercise) => Text(
                'Add Set - ${exercise?.getLocalizedName('en') ?? 'Unknown Exercise'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              loading: () => const Text('Loading...'),
              error: (_, __) => const Text('Error loading exercise'),
            ),
            const SizedBox(height: 16),
            
            // Previous set display
            recentSetsAsync.when(
              data: (recentSets) {
                if (recentSets.isNotEmpty) {
                  final lastSet = recentSets.first;
                  return Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          size: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Previous: ${lastSet.weight}kg × ${lastSet.reps} reps @ RPE ${lastSet.rpe}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),

            // Weight and Reps input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Reps',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // RPE Picker
            RPEPicker(
              selectedRPE: _selectedRPE,
              onRPEChanged: (rpe) {
                setState(() {
                  _selectedRPE = rpe;
                });
              },
            ),
            const SizedBox(height: 16),

            // Notes (optional)
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Add Set Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addSet,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Set'),
              ),
            ),

            // Error display
            if (workoutState.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        workoutState.error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addSet() async {
    // Validate inputs
    final weightText = _weightController.text.trim();
    final repsText = _repsController.text.trim();

    if (weightText.isEmpty || repsText.isEmpty) {
      _showError('Please enter both weight and reps');
      return;
    }

    final weight = double.tryParse(weightText);
    final reps = int.tryParse(repsText);

    if (weight == null || weight < MIN_WEIGHT_KG || weight > MAX_WEIGHT_KG) {
      _showError('Weight must be between $MIN_WEIGHT_KG and $MAX_WEIGHT_KG kg');
      return;
    }

    if (reps == null || reps < MIN_REPS || reps > MAX_REPS) {
      _showError('Reps must be between $MIN_REPS and $MAX_REPS');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(workoutSessionProvider.notifier).addSet(
        exerciseId: widget.exerciseId,
        weight: weight,
        reps: reps,
        rpe: _selectedRPE,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      // Clear notes but keep weight/reps for next set
      _notesController.clear();
      
      // Call callback
      widget.onSetAdded?.call();

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Set added successfully!'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to add set: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}