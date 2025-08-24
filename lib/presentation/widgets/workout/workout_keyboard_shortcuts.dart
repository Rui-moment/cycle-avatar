import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard shortcuts for high-speed workout logging
class WorkoutKeyboardShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? onQuickAdd;
  final VoidCallback? onRepeatLast;
  final Function(int)? onRPEChange;
  final VoidCallback? onFocusWeight;
  final VoidCallback? onFocusReps;

  const WorkoutKeyboardShortcuts({
    super.key,
    required this.child,
    this.onQuickAdd,
    this.onRepeatLast,
    this.onRPEChange,
    this.onFocusWeight,
    this.onFocusReps,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        // Enter to add set
        LogicalKeySet(LogicalKeyboardKey.enter): const _QuickAddIntent(),
        
        // Ctrl+Enter to repeat last set
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter): const _RepeatLastIntent(),
        
        // Tab to switch between weight and reps
        LogicalKeySet(LogicalKeyboardKey.tab): const _SwitchFieldIntent(),
        
        // Number keys for RPE (1-9, 0 for 10)
        LogicalKeySet(LogicalKeyboardKey.digit1): const _SetRPEIntent(1),
        LogicalKeySet(LogicalKeyboardKey.digit2): const _SetRPEIntent(2),
        LogicalKeySet(LogicalKeyboardKey.digit3): const _SetRPEIntent(3),
        LogicalKeySet(LogicalKeyboardKey.digit4): const _SetRPEIntent(4),
        LogicalKeySet(LogicalKeyboardKey.digit5): const _SetRPEIntent(5),
        LogicalKeySet(LogicalKeyboardKey.digit6): const _SetRPEIntent(6),
        LogicalKeySet(LogicalKeyboardKey.digit7): const _SetRPEIntent(7),
        LogicalKeySet(LogicalKeyboardKey.digit8): const _SetRPEIntent(8),
        LogicalKeySet(LogicalKeyboardKey.digit9): const _SetRPEIntent(9),
        LogicalKeySet(LogicalKeyboardKey.digit0): const _SetRPEIntent(10),
        
        // Arrow keys for RPE adjustment
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _AdjustRPEIntent(1),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _AdjustRPEIntent(-1),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _QuickAddIntent: CallbackAction<_QuickAddIntent>(
            onInvoke: (_) => onQuickAdd?.call(),
          ),
          _RepeatLastIntent: CallbackAction<_RepeatLastIntent>(
            onInvoke: (_) => onRepeatLast?.call(),
          ),
          _SwitchFieldIntent: CallbackAction<_SwitchFieldIntent>(
            onInvoke: (_) => _switchFocus(),
          ),
          _SetRPEIntent: CallbackAction<_SetRPEIntent>(
            onInvoke: (intent) => onRPEChange?.call(intent.rpe),
          ),
          _AdjustRPEIntent: CallbackAction<_AdjustRPEIntent>(
            onInvoke: (intent) => _adjustRPE(intent.delta),
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }

  void _switchFocus() {
    // This would need to be implemented with focus management
    // For now, we'll just call the focus callbacks
    onFocusWeight?.call();
  }

  void _adjustRPE(int delta) {
    // This would need current RPE value to adjust
    // Implementation would depend on the parent widget's state
  }
}

// Intent classes for keyboard shortcuts
class _QuickAddIntent extends Intent {
  const _QuickAddIntent();
}

class _RepeatLastIntent extends Intent {
  const _RepeatLastIntent();
}

class _SwitchFieldIntent extends Intent {
  const _SwitchFieldIntent();
}

class _SetRPEIntent extends Intent {
  final int rpe;
  const _SetRPEIntent(this.rpe);
}

class _AdjustRPEIntent extends Intent {
  final int delta;
  const _AdjustRPEIntent(this.delta);
}

/// Helper widget to show keyboard shortcuts
class KeyboardShortcutsHelp extends StatelessWidget {
  const KeyboardShortcutsHelp({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Keyboard Shortcuts'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildShortcutItem('Enter', 'Add set'),
            _buildShortcutItem('Ctrl + Enter', 'Repeat last set'),
            _buildShortcutItem('Tab', 'Switch between fields'),
            _buildShortcutItem('1-9, 0', 'Set RPE (0 = RPE 10)'),
            _buildShortcutItem('↑ ↓', 'Adjust RPE'),
            const SizedBox(height: 16),
            Text(
              'Pro tip: Keep your hands on the keyboard for lightning-fast logging!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }

  Widget _buildShortcutItem(String shortcut, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              shortcut,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(description),
          ),
        ],
      ),
    );
  }
}