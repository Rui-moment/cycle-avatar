import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/accessibility_service.dart';

/// An accessible button widget with proper semantics and haptic feedback
class AccessibleButton extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final String? tooltip;
  final ButtonStyle? style;
  final bool enableHapticFeedback;
  final bool isElevated;

  const AccessibleButton({
    super.key,
    required this.child,
    this.onPressed,
    this.semanticLabel,
    this.tooltip,
    this.style,
    this.enableHapticFeedback = true,
    this.isElevated = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessibilitySettings = ref.watch(accessibilitySettingsProvider);
    
    Widget button = isElevated
        ? ElevatedButton(
            onPressed: _handlePress(accessibilitySettings),
            style: style,
            child: child,
          )
        : TextButton(
            onPressed: _handlePress(accessibilitySettings),
            style: style,
            child: child,
          );

    // Add semantics wrapper
    button = Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      child: button,
    );

    // Add tooltip if provided
    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }

  VoidCallback? _handlePress(AccessibilitySettings settings) {
    if (onPressed == null) return null;
    
    return () {
      if (enableHapticFeedback && settings.hapticFeedbackEnabled) {
        AccessibilityService.provideLightHapticFeedback();
      }
      onPressed!();
    };
  }
}

/// An accessible icon button with proper semantics
class AccessibleIconButton extends ConsumerWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final String? tooltip;
  final double? iconSize;
  final Color? color;
  final bool enableHapticFeedback;

  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.tooltip,
    this.iconSize,
    this.color,
    this.enableHapticFeedback = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessibilitySettings = ref.watch(accessibilitySettingsProvider);
    final theme = Theme.of(context);
    
    Widget button = IconButton(
      onPressed: _handlePress(accessibilitySettings),
      icon: Icon(
        icon,
        size: iconSize != null 
            ? iconSize! * accessibilitySettings.textScaleFactor
            : null,
        color: color,
      ),
      tooltip: tooltip ?? semanticLabel,
    );

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      child: ExcludeSemantics(child: button),
    );
  }

  VoidCallback? _handlePress(AccessibilitySettings settings) {
    if (onPressed == null) return null;
    
    return () {
      if (enableHapticFeedback && settings.hapticFeedbackEnabled) {
        AccessibilityService.provideLightHapticFeedback();
      }
      onPressed!();
    };
  }
}

/// An accessible card widget with proper semantics
class AccessibleCard extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const AccessibleCard({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessibilitySettings = ref.watch(accessibilitySettingsProvider);
    
    Widget card = Card(
      margin: margin,
      child: InkWell(
        onTap: onTap != null ? _handleTap(accessibilitySettings) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

    if (semanticLabel != null) {
      card = Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: card,
      );
    }

    return card;
  }

  VoidCallback? _handleTap(AccessibilitySettings settings) {
    if (onTap == null) return null;
    
    return () {
      if (settings.hapticFeedbackEnabled) {
        AccessibilityService.provideLightHapticFeedback();
      }
      onTap!();
    };
  }
}