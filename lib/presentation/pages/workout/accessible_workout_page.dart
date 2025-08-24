import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/keyboard_navigation_service.dart';
import '../../../core/services/accessibility_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../widgets/common/accessible_button.dart';
import '../../widgets/workout/voice_input_widget.dart';
import '../../providers/workout_session_provider.dart';

/// Enhanced workout page with full accessibility support
class AccessibleWorkoutPage extends ConsumerWidget {
  const AccessibleWorkoutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workoutState = ref.watch(workoutSessionProvider);
    final accessibilitySettings = ref.watch(accessibilitySettingsProvider);

    return KeyboardNavigationWrapper(
      additionalShortcuts: {
        const LogicalKeySet(LogicalKeyboardKey.keyS, LogicalKeyboardKey.control): () {
          // Save current workout
          _saveWorkout(ref);
        },
        const LogicalKeySet(LogicalKeyboardKey.keyA, LogicalKeyboardKey.control): () {
          // Add new set
          _addSet(context, ref);
        },
        const LogicalKeySet(LogicalKeyboardKey.keyE, LogicalKeyboardKey.control): () {
          // End workout
          _endWorkout(context, ref);
        },
      },
      child: Scaffold(
        appBar: AppBar(
          title: Semantics(
            label: '${l10n?.workout ?? 'Workout'} page',
            child: Text(l10n?.workout ?? 'Workout'),
          ),
          actions: [
            if (workoutState.currentSession != null)
              AccessibleIconButton(
                icon: Icons.stop,
                semanticLabel: l10n?.endWorkout ?? 'End workout',
                tooltip: l10n?.endWorkout ?? 'End workout',
                onPressed: () => _endWorkout(context, ref),
              ),
            AccessibleIconButton(
              icon: Icons.help,
              semanticLabel: 'Keyboard shortcuts help',
              tooltip: 'Show keyboard shortcuts',
              onPressed: () => _showKeyboardShortcuts(context),
            ),
          ],
        ),
        body: workoutState.currentSession != null
            ? _buildActiveWorkoutView(context, ref)
            : _buildStartWorkoutView(context, ref),
        floatingActionButton: workoutState.currentSession == null
            ? Semantics(
                label: l10n?.startWorkout ?? 'Start workout',
                child: FloatingActionButton.extended(
                  onPressed: () => _startWorkout(context, ref),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l10n?.startWorkout ?? 'Start Workout'),
                ),
              )
            : Semantics(
                label: l10n?.addSet ?? 'Add set',
                child: FloatingActionButton(
                  onPressed: () => _addSet(context, ref),
                  child: const Icon(Icons.add),
                ),
              ),
      ),
    );
  }

  Widget _buildStartWorkoutView(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Semantics(
      label: 'Start workout screen',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: 80,
              color: theme.primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              l10n?.startWorkout ?? 'Start Your Workout',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Ready to train? Tap the button below to begin your workout session.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            AccessibleButton(
              onPressed: () => _startWorkout(context, ref),
              semanticLabel: l10n?.startWorkout ?? 'Start workout',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Text(
                  l10n?.startWorkout ?? 'Start Workout',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AccessibleButton(
              onPressed: () => _showTemplates(context),
              semanticLabel: 'Start from template',
              isElevated: false,
              child: Text('Start from Template'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveWorkoutView(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workoutState = ref.watch(workoutSessionProvider);
    final session = workoutState.currentSession!;

    return Semantics(
      label: 'Active workout session',
      child: Column(
        children: [
          // Workout header with session info
          AccessibleCard(
            semanticLabel: 'Workout session information',
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Semantics(
                      label: 'Workout duration',
                      child: Text(
                        _formatDuration(session.duration),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Session type: ${session.sessionType}',
                  child: Text(
                    'Session: ${session.sessionType}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          
          // Exercise selection and set logging
          Expanded(
            child: _buildExerciseSection(context, ref),
          ),
          
          // Quick actions bar
          _buildQuickActionsBar(context, ref),
        ],
      ),
    );
  }

  Widget _buildExerciseSection(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'Exercise logging section',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            // Exercise selector
            AccessibleCard(
              semanticLabel: 'Select exercise',
              child: ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Select Exercise'),
                subtitle: const Text('Tap to choose an exercise'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectExercise(context, ref),
              ),
            ),
            const SizedBox(height: 16),
            
            // Voice-enabled set form
            Expanded(
              child: VoiceEnabledSetForm(
                onSetAdded: (setData) => _handleSetAdded(context, ref, setData),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsBar(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    
    return Semantics(
      label: 'Quick actions',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            AccessibleButton(
              onPressed: () => _addSet(context, ref),
              semanticLabel: l10n?.addSet ?? 'Add set',
              isElevated: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add),
                  const SizedBox(height: 4),
                  Text(l10n?.addSet ?? 'Add Set'),
                ],
              ),
            ),
            AccessibleButton(
              onPressed: () => _saveWorkout(ref),
              semanticLabel: 'Save workout',
              isElevated: false,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save),
                  SizedBox(height: 4),
                  Text('Save'),
                ],
              ),
            ),
            AccessibleButton(
              onPressed: () => _endWorkout(context, ref),
              semanticLabel: l10n?.endWorkout ?? 'End workout',
              isElevated: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stop),
                  const SizedBox(height: 4),
                  Text(l10n?.endWorkout ?? 'End'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startWorkout(BuildContext context, WidgetRef ref) {
    final accessibilitySettings = ref.read(accessibilitySettingsProvider);
    if (accessibilitySettings.hapticFeedbackEnabled) {
      AccessibilityService.provideMediumHapticFeedback();
    }
    
    // Start workout logic
    ref.read(workoutSessionProvider.notifier).startSession('General');
    
    // Announce to screen reader
    if (accessibilitySettings.screenReaderEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workout started'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _addSet(BuildContext context, WidgetRef ref) {
    final accessibilitySettings = ref.read(accessibilitySettingsProvider);
    if (accessibilitySettings.hapticFeedbackEnabled) {
      AccessibilityService.provideLightHapticFeedback();
    }
    
    // Focus on the weight input field
    // This would be implemented with proper focus management
  }

  void _endWorkout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Workout'),
        content: const Text('Are you sure you want to end this workout?'),
        actions: [
          AccessibleButton(
            onPressed: () => Navigator.of(context).pop(),
            semanticLabel: 'Cancel ending workout',
            isElevated: false,
            child: const Text('Cancel'),
          ),
          AccessibleButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(workoutSessionProvider.notifier).endSession();
              
              final accessibilitySettings = ref.read(accessibilitySettingsProvider);
              if (accessibilitySettings.hapticFeedbackEnabled) {
                AccessibilityService.provideHeavyHapticFeedback();
              }
            },
            semanticLabel: 'Confirm end workout',
            child: const Text('End Workout'),
          ),
        ],
      ),
    );
  }

  void _saveWorkout(WidgetRef ref) {
    // Save workout logic
    final accessibilitySettings = ref.read(accessibilitySettingsProvider);
    if (accessibilitySettings.hapticFeedbackEnabled) {
      AccessibilityService.provideLightHapticFeedback();
    }
  }

  void _selectExercise(BuildContext context, WidgetRef ref) {
    // Show exercise selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Exercise'),
        content: const Text('Exercise selection coming soon'),
        actions: [
          AccessibleButton(
            onPressed: () => Navigator.of(context).pop(),
            semanticLabel: 'Close exercise selection',
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTemplates(BuildContext context) {
    // Navigate to templates
  }

  void _handleSetAdded(BuildContext context, WidgetRef ref, SetData setData) {
    // Handle set addition
    final accessibilitySettings = ref.read(accessibilitySettingsProvider);
    if (accessibilitySettings.hapticFeedbackEnabled) {
      AccessibilityService.provideMediumHapticFeedback();
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Set added: ${setData.weight}kg × ${setData.reps} @ RPE ${setData.rpe}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showKeyboardShortcuts(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keyboard Shortcuts'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ctrl+S: Save workout'),
              SizedBox(height: 8),
              Text('Ctrl+A: Add set'),
              SizedBox(height: 8),
              Text('Ctrl+E: End workout'),
              SizedBox(height: 8),
              Text('Tab: Next field'),
              SizedBox(height: 8),
              Text('Shift+Tab: Previous field'),
              SizedBox(height: 8),
              Text('Enter/Space: Activate button'),
              SizedBox(height: 8),
              Text('Escape: Cancel/Go back'),
            ],
          ),
        ),
        actions: [
          AccessibleButton(
            onPressed: () => Navigator.of(context).pop(),
            semanticLabel: 'Close keyboard shortcuts help',
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}