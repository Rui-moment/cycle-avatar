import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/workout_session_provider.dart';
import '../../providers/exercise_provider.dart';
import '../../../domain/entities/workout_session.dart';
import '../../../domain/entities/constants.dart';

/// Quick set entry widget for high-speed workout logging
class QuickSetEntry extends ConsumerStatefulWidget {
  final String exerciseId;
  final VoidCallback? onSetAdded;
  final bool showExerciseName;

  const QuickSetEntry({
    super.key,
    required this.exerciseId,
    this.onSetAdded,
    this.showExerciseName = true,
  });

  @override
  ConsumerState<QuickSetEntry> createState() => _QuickSetEntryState();
}

class _QuickSetEntryState extends ConsumerState<QuickSetEntry> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _weightFocusNode = FocusNode();
  final _repsFocusNode = FocusNode();
  
  int _selectedRPE = 7;
  bool _isLoading = false;
  WorkoutSet? _lastSet;

  @override
  void initState() {
    super.initState();
    _loadPreviousValues();
  }

  @override
  void didUpdateWidget(QuickSetEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseId != widget.exerciseId) {
      _loadPreviousValues();
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  void _loadPreviousValues() {
    // Load previous values from the current session first
    final workoutState = ref.read(workoutSessionProvider);
    final lastSet = workoutState.currentSession?.getSetsForExercise(widget.exerciseId).lastOrNull;
    
    if (lastSet != null) {
      _lastSet = lastSet;
      _weightController.text = lastSet.weight.toString();
      _repsController.text = lastSet.reps.toString();
      _selectedRPE = lastSet.rpe;
      setState(() {});
    } else {
      // Load from recent sessions
      final recentSetsAsync = ref.read(recentSetsForExerciseProvider({
        'userId': 'user_1', // TODO: Get from user provider
        'exerciseId': widget.exerciseId,
      }));
      
      recentSetsAsync.whenData((recentSets) {
        if (recentSets.isNotEmpty && mounted) {
          final lastRecentSet = recentSets.first;
          _lastSet = lastRecentSet;
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

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Exercise name (optional)
            if (widget.showExerciseName)
              exerciseAsync.when(
                data: (exercise) => Text(
                  exercise?.getLocalizedName('en') ?? 'Unknown Exercise',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                loading: () => const Text('Loading...'),
                error: (_, __) => const Text('Error loading exercise'),
              ),
            
            if (widget.showExerciseName) const SizedBox(height: 8),

            // Previous set indicator
            if (_lastSet != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history,
                      size: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Last: ${_lastSet!.weight}kg × ${_lastSet!.reps} @ ${_lastSet!.rpe}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            
            if (_lastSet != null) const SizedBox(height: 8),

            // Quick input row
            Row(
              children: [
                // Weight input
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _weightController,
                    focusNode: _weightFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'kg',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onSubmitted: (_) => _repsFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Reps input
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _repsController,
                    focusNode: _repsFocusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: 'reps',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onSubmitted: (_) => _addSet(),
                  ),
                ),
                const SizedBox(width: 8),
                
                // RPE quick selector
                Expanded(
                  flex: 3,
                  child: _buildQuickRPESelector(),
                ),
                const SizedBox(width: 8),
                
                // Add button
                SizedBox(
                  width: 44,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addSet,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add, size: 20),
                  ),
                ),
              ],
            ),

            // One-tap repeat button
            if (_lastSet != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _repeatLastSet,
                  icon: const Icon(Icons.repeat, size: 16),
                  label: Text(
                    'Repeat ${_lastSet!.weight}kg × ${_lastSet!.reps} @ ${_lastSet!.rpe}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],

            // Error display
            if (workoutState.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        workoutState.error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 11,
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

  Widget _buildQuickRPESelector() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // RPE decrease button
          SizedBox(
            width: 28,
            child: IconButton(
              onPressed: _selectedRPE > MIN_RPE ? () => setState(() => _selectedRPE--) : null,
              icon: const Icon(Icons.remove, size: 16),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          
          // RPE display
          Expanded(
            child: Container(
              alignment: Alignment.center,
              child: Text(
                '$_selectedRPE',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getRPEColor(_selectedRPE),
                ),
              ),
            ),
          ),
          
          // RPE increase button
          SizedBox(
            width: 28,
            child: IconButton(
              onPressed: _selectedRPE < MAX_RPE ? () => setState(() => _selectedRPE++) : null,
              icon: const Icon(Icons.add, size: 16),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
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

  Future<void> _addSet() async {
    // Validate inputs
    final weightText = _weightController.text.trim();
    final repsText = _repsController.text.trim();

    if (weightText.isEmpty || repsText.isEmpty) {
      _showError('Enter weight and reps');
      return;
    }

    final weight = double.tryParse(weightText);
    final reps = int.tryParse(repsText);

    if (weight == null || weight < MIN_WEIGHT_KG || weight > MAX_WEIGHT_KG) {
      _showError('Weight: $MIN_WEIGHT_KG-${MAX_WEIGHT_KG}kg');
      return;
    }

    if (reps == null || reps < MIN_REPS || reps > MAX_REPS) {
      _showError('Reps: $MIN_REPS-$MAX_REPS');
      return;
    }

    await _performAddSet(weight, reps, _selectedRPE);
  }

  Future<void> _repeatLastSet() async {
    if (_lastSet == null) return;
    await _performAddSet(_lastSet!.weight, _lastSet!.reps, _lastSet!.rpe);
  }

  Future<void> _performAddSet(double weight, int reps, int rpe) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(workoutSessionProvider.notifier).addSet(
        exerciseId: widget.exerciseId,
        weight: weight,
        reps: reps,
        rpe: rpe,
      );

      // Update last set for next quick repeat
      _lastSet = WorkoutSet(
        id: '',
        sessionId: '',
        exerciseId: widget.exerciseId,
        weight: weight,
        reps: reps,
        rpe: rpe,
        setOrder: 0,
        createdAt: DateTime.now(),
      );

      // Provide haptic feedback
      HapticFeedback.lightImpact();
      
      // Call callback
      widget.onSetAdded?.call();

      // Show brief success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Set added: ${weight}kg × $reps @ $rpe'),
            duration: const Duration(milliseconds: 800),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to add set');
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
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        ),
      );
    }
  }
}