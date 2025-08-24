import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/voice_input_service.dart';
import '../../../core/services/accessibility_service.dart';
import '../../../core/l10n/app_localizations.dart';

/// Widget for voice input during workout logging
class VoiceInputWidget extends ConsumerStatefulWidget {
  final VoiceInputType inputType;
  final ValueChanged<String>? onResult;
  final String? currentValue;
  
  const VoiceInputWidget({
    super.key,
    required this.inputType,
    this.onResult,
    this.currentValue,
  });
  
  @override
  ConsumerState<VoiceInputWidget> createState() => _VoiceInputWidgetState();
}

class _VoiceInputWidgetState extends ConsumerState<VoiceInputWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final voiceInputState = ref.watch(voiceInputProvider);
    final isAvailable = ref.watch(voiceInputAvailableProvider);
    
    return isAvailable.when(
      data: (available) {
        if (!available) {
          return _buildUnavailableWidget(context, l10n);
        }
        
        return _buildVoiceInputButton(context, l10n, voiceInputState);
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => _buildUnavailableWidget(context, l10n),
    );
  }
  
  Widget _buildUnavailableWidget(BuildContext context, AppLocalizations? l10n) {
    return Tooltip(
      message: l10n?.voiceInputNotSupported ?? 'Voice input not supported',
      child: IconButton(
        onPressed: null,
        icon: const Icon(Icons.mic_off),
      ),
    );
  }
  
  Widget _buildVoiceInputButton(
    BuildContext context,
    AppLocalizations? l10n,
    VoiceInputState voiceInputState,
  ) {
    if (voiceInputState.isListening) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: voiceInputState.isListening ? _pulseAnimation.value : 1.0,
              child: IconButton(
                onPressed: voiceInputState.isListening
                    ? null
                    : () => _startVoiceInput(context, l10n),
                icon: Icon(
                  voiceInputState.isListening ? Icons.mic : Icons.mic_none,
                  color: voiceInputState.isListening
                      ? Theme.of(context).primaryColor
                      : null,
                ),
                tooltip: _getTooltipText(l10n),
              ),
            );
          },
        ),
        if (voiceInputState.isListening)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n?.listeningForVoice ?? 'Listening...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (voiceInputState.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n?.voiceInputError ?? 'Voice input error',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
  
  String _getTooltipText(AppLocalizations? l10n) {
    switch (widget.inputType) {
      case VoiceInputType.weight:
        return l10n?.voiceInputWeight ?? 'Say the weight';
      case VoiceInputType.reps:
        return l10n?.voiceInputReps ?? 'Say the number of reps';
      case VoiceInputType.rpe:
        return l10n?.voiceInputRPE ?? 'Say the RPE from 1 to 10';
    }
  }
  
  String _getPromptText(AppLocalizations? l10n) {
    switch (widget.inputType) {
      case VoiceInputType.weight:
        return l10n?.weightInKg ?? 'Weight in kg';
      case VoiceInputType.reps:
        return l10n?.numberOfReps ?? 'Number of reps';
      case VoiceInputType.rpe:
        return l10n?.rpeScale ?? 'RPE on scale of 1 to 10';
    }
  }
  
  Future<void> _startVoiceInput(BuildContext context, AppLocalizations? l10n) async {
    final accessibilitySettings = ref.read(accessibilitySettingsProvider);
    
    if (accessibilitySettings.hapticFeedbackEnabled) {
      AccessibilityService.provideLightHapticFeedback();
    }
    
    final prompt = _getPromptText(l10n);
    await ref.read(voiceInputProvider.notifier).startListening(
      prompt: prompt,
      language: Localizations.of(context).languageCode,
    );
    
    final result = ref.read(voiceInputProvider).lastResult;
    if (result != null) {
      _processVoiceResult(result);
    }
  }
  
  void _processVoiceResult(String voiceText) {
    String? processedResult;
    
    switch (widget.inputType) {
      case VoiceInputType.weight:
        final weight = VoiceInputService.parseWeightFromVoice(voiceText);
        if (weight != null) {
          processedResult = weight.toString();
        }
        break;
      case VoiceInputType.reps:
        final reps = VoiceInputService.parseRepsFromVoice(voiceText);
        if (reps != null) {
          processedResult = reps.toString();
        }
        break;
      case VoiceInputType.rpe:
        final rpe = VoiceInputService.parseRPEFromVoice(voiceText);
        if (rpe != null) {
          processedResult = rpe.toString();
        }
        break;
    }
    
    if (processedResult != null) {
      widget.onResult?.call(processedResult);
      
      // Provide success feedback
      final accessibilitySettings = ref.read(accessibilitySettingsProvider);
      if (accessibilitySettings.hapticFeedbackEnabled) {
        AccessibilityService.provideMediumHapticFeedback();
      }
    } else {
      // Show error feedback
      _showVoiceInputError();
    }
    
    // Clear the result
    ref.read(voiceInputProvider.notifier).clearResult();
  }
  
  void _showVoiceInputError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)?.voiceInputError ?? 
          'Could not understand voice input. Please try again.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

enum VoiceInputType {
  weight,
  reps,
  rpe,
}

/// Enhanced set input form with voice input support
class VoiceEnabledSetForm extends ConsumerStatefulWidget {
  final ValueChanged<SetData>? onSetAdded;
  final SetData? previousSet;
  
  const VoiceEnabledSetForm({
    super.key,
    this.onSetAdded,
    this.previousSet,
  });
  
  @override
  ConsumerState<VoiceEnabledSetForm> createState() => _VoiceEnabledSetFormState();
}

class _VoiceEnabledSetFormState extends ConsumerState<VoiceEnabledSetForm> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _rpeController = TextEditingController();
  
  final _weightFocusNode = FocusNode();
  final _repsFocusNode = FocusNode();
  final _rpeFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    if (widget.previousSet != null) {
      _weightController.text = widget.previousSet!.weight.toString();
      _repsController.text = widget.previousSet!.reps.toString();
    }
  }
  
  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _rpeController.dispose();
    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    _rpeFocusNode.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.addSet ?? 'Add Set',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Weight input with voice support
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    focusNode: _weightFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n?.weight ?? 'Weight',
                      suffixText: 'kg',
                    ),
                    onSubmitted: (_) => _repsFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 8),
                VoiceInputWidget(
                  inputType: VoiceInputType.weight,
                  onResult: (result) {
                    _weightController.text = result;
                    _repsFocusNode.requestFocus();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Reps input with voice support
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    focusNode: _repsFocusNode,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n?.reps ?? 'Reps',
                    ),
                    onSubmitted: (_) => _rpeFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 8),
                VoiceInputWidget(
                  inputType: VoiceInputType.reps,
                  onResult: (result) {
                    _repsController.text = result;
                    _rpeFocusNode.requestFocus();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // RPE input with voice support
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rpeController,
                    focusNode: _rpeFocusNode,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n?.rpe ?? 'RPE',
                      hintText: '1-10',
                    ),
                    onSubmitted: (_) => _addSet(),
                  ),
                ),
                const SizedBox(width: 8),
                VoiceInputWidget(
                  inputType: VoiceInputType.rpe,
                  onResult: (result) {
                    _rpeController.text = result;
                    _addSet();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: _addSet,
              child: Text(l10n?.addSet ?? 'Add Set'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _addSet() {
    final weight = double.tryParse(_weightController.text);
    final reps = int.tryParse(_repsController.text);
    final rpe = int.tryParse(_rpeController.text);
    
    if (weight != null && reps != null && rpe != null && rpe >= 1 && rpe <= 10) {
      final setData = SetData(
        weight: weight,
        reps: reps,
        rpe: rpe,
      );
      
      widget.onSetAdded?.call(setData);
      
      // Clear RPE for next set, keep weight and reps
      _rpeController.clear();
      _weightFocusNode.requestFocus();
      
      // Provide haptic feedback
      final accessibilitySettings = ref.read(accessibilitySettingsProvider);
      if (accessibilitySettings.hapticFeedbackEnabled) {
        AccessibilityService.provideMediumHapticFeedback();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter valid weight, reps, and RPE (1-10)',
          ),
        ),
      );
    }
  }
}

class SetData {
  final double weight;
  final int reps;
  final int rpe;
  
  const SetData({
    required this.weight,
    required this.reps,
    required this.rpe,
  });
}