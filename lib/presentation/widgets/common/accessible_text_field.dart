import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/accessibility_service.dart';

/// An accessible text field with proper semantics and voice input support
class AccessibleTextField extends ConsumerWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? semanticLabel;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final int? maxLines;
  final bool enableVoiceInput;
  final String? voiceInputHint;

  const AccessibleTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.semanticLabel,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.suffixIcon,
    this.prefixIcon,
    this.maxLines = 1,
    this.enableVoiceInput = false,
    this.voiceInputHint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessibilitySettings = ref.watch(accessibilitySettingsProvider);
    
    Widget textField = TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: _handleTap(accessibilitySettings),
      readOnly: readOnly,
      enabled: enabled,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: 16 * accessibilitySettings.textScaleFactor,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        suffixIcon: _buildSuffixIcon(context, ref),
        prefixIcon: prefixIcon,
      ),
    );

    // Add semantics
    return Semantics(
      label: semanticLabel ?? labelText ?? hintText,
      textField: true,
      enabled: enabled,
      readOnly: readOnly,
      hint: hintText,
      child: textField,
    );
  }

  Widget? _buildSuffixIcon(BuildContext context, WidgetRef ref) {
    if (!enableVoiceInput) return suffixIcon;
    
    final voiceIcon = IconButton(
      onPressed: () => _startVoiceInput(context, ref),
      icon: const Icon(Icons.mic),
      tooltip: voiceInputHint ?? 'Voice input',
    );
    
    if (suffixIcon == null) return voiceIcon;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        suffixIcon!,
        voiceIcon,
      ],
    );
  }

  VoidCallback? _handleTap(AccessibilitySettings settings) {
    if (onTap == null) return null;
    
    return () {
      if (settings.hapticFeedbackEnabled) {
        AccessibilityService.provideSelectionHapticFeedback();
      }
      onTap!();
    };
  }

  void _startVoiceInput(BuildContext context, WidgetRef ref) {
    // This would integrate with speech recognition
    // For now, show a placeholder dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Input'),
        content: Text(voiceInputHint ?? 'Speak now to input text'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Specialized accessible number input field
class AccessibleNumberField extends ConsumerWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? semanticLabel;
  final ValueChanged<double?>? onChanged;
  final double? min;
  final double? max;
  final int decimalPlaces;
  final String? unit;
  final bool enableVoiceInput;

  const AccessibleNumberField({
    super.key,
    this.controller,
    this.labelText,
    this.semanticLabel,
    this.onChanged,
    this.min,
    this.max,
    this.decimalPlaces = 1,
    this.unit,
    this.enableVoiceInput = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AccessibleTextField(
      controller: controller,
      labelText: labelText,
      semanticLabel: semanticLabel,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onChanged: (value) {
        final number = double.tryParse(value);
        if (number != null && _isValidNumber(number)) {
          onChanged?.call(number);
        } else if (value.isEmpty) {
          onChanged?.call(null);
        }
      },
      suffixIcon: unit != null 
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                unit!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : null,
      enableVoiceInput: enableVoiceInput,
      voiceInputHint: 'Say a number${unit != null ? ' in $unit' : ''}',
    );
  }

  bool _isValidNumber(double number) {
    if (min != null && number < min!) return false;
    if (max != null && number > max!) return false;
    return true;
  }
}