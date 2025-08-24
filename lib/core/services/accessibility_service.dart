import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for managing accessibility features
class AccessibilityService {
  static const _channel = MethodChannel('cycle_avatar/accessibility');
  
  /// Check if screen reader is enabled
  static Future<bool> isScreenReaderEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isScreenReaderEnabled');
      return result ?? false;
    } on PlatformException {
      // Fallback to Flutter's built-in method
      return WidgetsBinding.instance.accessibilityFeatures.accessibleNavigation;
    }
  }
  
  /// Check if high contrast is enabled
  static Future<bool> isHighContrastEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isHighContrastEnabled');
      return result ?? false;
    } on PlatformException {
      // Fallback to Flutter's built-in method
      return WidgetsBinding.instance.accessibilityFeatures.highContrast;
    }
  }
  
  /// Check if large text is enabled
  static Future<bool> isLargeTextEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isLargeTextEnabled');
      return result ?? false;
    } on PlatformException {
      // Fallback to Flutter's built-in method
      return WidgetsBinding.instance.accessibilityFeatures.boldText;
    }
  }
  
  /// Get text scale factor based on system settings
  static double getTextScaleFactor(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.textScaler.scale(1.0).clamp(1.0, 2.0);
  }
  
  /// Provide haptic feedback
  static void provideLightHapticFeedback() {
    HapticFeedback.lightImpact();
  }
  
  static void provideMediumHapticFeedback() {
    HapticFeedback.mediumImpact();
  }
  
  static void provideHeavyHapticFeedback() {
    HapticFeedback.heavyImpact();
  }
  
  static void provideSelectionHapticFeedback() {
    HapticFeedback.selectionClick();
  }
}

/// Provider for accessibility settings
final accessibilitySettingsProvider = StateNotifierProvider<AccessibilitySettingsNotifier, AccessibilitySettings>((ref) {
  return AccessibilitySettingsNotifier();
});

class AccessibilitySettings {
  final bool screenReaderEnabled;
  final bool highContrastEnabled;
  final bool largeTextEnabled;
  final bool hapticFeedbackEnabled;
  final double textScaleFactor;
  
  const AccessibilitySettings({
    this.screenReaderEnabled = false,
    this.highContrastEnabled = false,
    this.largeTextEnabled = false,
    this.hapticFeedbackEnabled = true,
    this.textScaleFactor = 1.0,
  });
  
  AccessibilitySettings copyWith({
    bool? screenReaderEnabled,
    bool? highContrastEnabled,
    bool? largeTextEnabled,
    bool? hapticFeedbackEnabled,
    double? textScaleFactor,
  }) {
    return AccessibilitySettings(
      screenReaderEnabled: screenReaderEnabled ?? this.screenReaderEnabled,
      highContrastEnabled: highContrastEnabled ?? this.highContrastEnabled,
      largeTextEnabled: largeTextEnabled ?? this.largeTextEnabled,
      hapticFeedbackEnabled: hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
    );
  }
}

class AccessibilitySettingsNotifier extends StateNotifier<AccessibilitySettings> {
  AccessibilitySettingsNotifier() : super(const AccessibilitySettings()) {
    _loadAccessibilitySettings();
  }
  
  Future<void> _loadAccessibilitySettings() async {
    final screenReader = await AccessibilityService.isScreenReaderEnabled();
    final highContrast = await AccessibilityService.isHighContrastEnabled();
    final largeText = await AccessibilityService.isLargeTextEnabled();
    
    state = state.copyWith(
      screenReaderEnabled: screenReader,
      highContrastEnabled: highContrast,
      largeTextEnabled: largeText,
    );
  }
  
  void updateTextScaleFactor(double factor) {
    state = state.copyWith(textScaleFactor: factor);
  }
  
  void toggleHapticFeedback() {
    state = state.copyWith(hapticFeedbackEnabled: !state.hapticFeedbackEnabled);
  }
  
  void refreshAccessibilitySettings() {
    _loadAccessibilitySettings();
  }
}