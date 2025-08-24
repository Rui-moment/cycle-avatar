import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service for handling keyboard navigation and shortcuts
class KeyboardNavigationService {
  static const Map<LogicalKeySet, String> _shortcuts = {
    LogicalKeySet(LogicalKeyboardKey.tab): 'next_focus',
    LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.tab): 'previous_focus',
    LogicalKeySet(LogicalKeyboardKey.enter): 'activate',
    LogicalKeySet(LogicalKeyboardKey.space): 'activate',
    LogicalKeySet(LogicalKeyboardKey.escape): 'cancel',
    LogicalKeySet(LogicalKeyboardKey.arrowUp): 'navigate_up',
    LogicalKeySet(LogicalKeyboardKey.arrowDown): 'navigate_down',
    LogicalKeySet(LogicalKeyboardKey.arrowLeft): 'navigate_left',
    LogicalKeySet(LogicalKeyboardKey.arrowRight): 'navigate_right',
    LogicalKeySet(LogicalKeyboardKey.keyA, LogicalKeyboardKey.control): 'add_set',
    LogicalKeySet(LogicalKeyboardKey.keyS, LogicalKeyboardKey.control): 'save',
    LogicalKeySet(LogicalKeyboardKey.keyN, LogicalKeyboardKey.control): 'new_workout',
  };
  
  /// Get keyboard shortcuts map
  static Map<LogicalKeySet, String> get shortcuts => _shortcuts;
  
  /// Handle keyboard shortcut
  static bool handleShortcut(String action, BuildContext context) {
    switch (action) {
      case 'next_focus':
        FocusScope.of(context).nextFocus();
        return true;
      case 'previous_focus':
        FocusScope.of(context).previousFocus();
        return true;
      case 'activate':
        _activateCurrentFocus(context);
        return true;
      case 'cancel':
        Navigator.of(context).maybePop();
        return true;
      default:
        return false;
    }
  }
  
  static void _activateCurrentFocus(BuildContext context) {
    final focusedWidget = FocusScope.of(context).focusedChild?.context?.widget;
    if (focusedWidget is Button) {
      // Simulate button press
      HapticFeedback.lightImpact();
    }
  }
}

/// Widget that provides keyboard navigation support
class KeyboardNavigationWrapper extends StatelessWidget {
  final Widget child;
  final Map<LogicalKeySet, VoidCallback>? additionalShortcuts;
  
  const KeyboardNavigationWrapper({
    super.key,
    required this.child,
    this.additionalShortcuts,
  });
  
  @override
  Widget build(BuildContext context) {
    final shortcuts = <LogicalKeySet, Intent>{};
    final actions = <Type, Action<Intent>>{};
    
    // Add default shortcuts
    for (final entry in KeyboardNavigationService.shortcuts.entries) {
      final intent = _KeyboardIntent(entry.value);
      shortcuts[entry.key] = intent;
      actions[intent.runtimeType] = _KeyboardAction(context);
    }
    
    // Add additional shortcuts if provided
    if (additionalShortcuts != null) {
      for (final entry in additionalShortcuts!.entries) {
        final intent = _CallbackIntent(entry.value);
        shortcuts[entry.key] = intent;
        actions[intent.runtimeType] = _CallbackAction();
      }
    }
    
    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: actions,
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

class _KeyboardIntent extends Intent {
  final String action;
  const _KeyboardIntent(this.action);
}

class _CallbackIntent extends Intent {
  final VoidCallback callback;
  const _CallbackIntent(this.callback);
}

class _KeyboardAction extends Action<_KeyboardIntent> {
  final BuildContext context;
  _KeyboardAction(this.context);
  
  @override
  Object? invoke(_KeyboardIntent intent) {
    return KeyboardNavigationService.handleShortcut(intent.action, context);
  }
}

class _CallbackAction extends Action<_CallbackIntent> {
  @override
  Object? invoke(_CallbackIntent intent) {
    intent.callback();
    return null;
  }
}

/// Focus-aware button that supports keyboard navigation
class FocusableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final bool autofocus;
  final FocusNode? focusNode;
  
  const FocusableButton({
    super.key,
    required this.child,
    this.onPressed,
    this.semanticLabel,
    this.autofocus = false,
    this.focusNode,
  });
  
  @override
  State<FocusableButton> createState() => _FocusableButtonState();
}

class _FocusableButtonState extends State<FocusableButton> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  
  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }
  
  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }
  
  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onPressed?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        decoration: _isFocused
            ? BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: ElevatedButton(
          onPressed: widget.onPressed,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Focus-aware text field with keyboard navigation
class FocusableTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onNextField;
  
  const FocusableTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.focusNode,
    this.onNextField,
  });
  
  @override
  State<FocusableTextField> createState() => _FocusableTextFieldState();
}

class _FocusableTextFieldState extends State<FocusableTextField> {
  late FocusNode _focusNode;
  
  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }
  
  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      onSubmitted: (value) {
        widget.onSubmitted?.call(value);
        widget.onNextField?.call();
      },
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
      ),
    );
  }
}