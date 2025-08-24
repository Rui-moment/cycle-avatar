import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for handling voice input functionality
class VoiceInputService {
  static const _channel = MethodChannel('cycle_avatar/voice_input');
  
  /// Check if voice input is available on the device
  static Future<bool> isVoiceInputAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isVoiceInputAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// Start listening for voice input
  static Future<String?> startVoiceInput({
    String? prompt,
    String? language = 'en',
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('startVoiceInput', {
        'prompt': prompt,
        'language': language,
      });
      return result;
    } on PlatformException {
      return null;
    }
  }
  
  /// Parse voice input for weight values
  static double? parseWeightFromVoice(String voiceText) {
    // Remove common words and extract numbers
    final cleanText = voiceText.toLowerCase()
        .replaceAll(RegExp(r'\b(kg|kilograms?|pounds?|lbs?)\b'), '')
        .replaceAll(RegExp(r'\b(point|dot)\b'), '.')
        .trim();
    
    // Extract number patterns
    final numberMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(cleanText);
    if (numberMatch != null) {
      return double.tryParse(numberMatch.group(1)!);
    }
    
    // Handle spoken numbers (basic implementation)
    return _parseSpokenNumber(cleanText);
  }
  
  /// Parse voice input for rep values
  static int? parseRepsFromVoice(String voiceText) {
    final cleanText = voiceText.toLowerCase()
        .replaceAll(RegExp(r'\b(reps?|repetitions?|times?)\b'), '')
        .trim();
    
    final numberMatch = RegExp(r'(\d+)').firstMatch(cleanText);
    if (numberMatch != null) {
      return int.tryParse(numberMatch.group(1)!);
    }
    
    // Handle spoken numbers
    final spokenNumber = _parseSpokenNumber(cleanText);
    return spokenNumber?.round();
  }
  
  /// Parse voice input for RPE values
  static int? parseRPEFromVoice(String voiceText) {
    final cleanText = voiceText.toLowerCase()
        .replaceAll(RegExp(r'\b(rpe|rate|rating|out of ten|of ten)\b'), '')
        .trim();
    
    final numberMatch = RegExp(r'(\d+)').firstMatch(cleanText);
    if (numberMatch != null) {
      final rpe = int.tryParse(numberMatch.group(1)!);
      if (rpe != null && rpe >= 1 && rpe <= 10) {
        return rpe;
      }
    }
    
    // Handle spoken numbers
    final spokenNumber = _parseSpokenNumber(cleanText);
    if (spokenNumber != null) {
      final rpe = spokenNumber.round();
      if (rpe >= 1 && rpe <= 10) {
        return rpe;
      }
    }
    
    return null;
  }
  
  /// Basic spoken number parsing (English)
  static double? _parseSpokenNumber(String text) {
    final numberWords = {
      'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
      'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
      'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
      'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19, 'twenty': 20,
      'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70,
      'eighty': 80, 'ninety': 90, 'hundred': 100,
    };
    
    for (final entry in numberWords.entries) {
      if (text.contains(entry.key)) {
        return entry.value.toDouble();
      }
    }
    
    return null;
  }
}

/// Provider for voice input availability
final voiceInputAvailableProvider = FutureProvider<bool>((ref) async {
  return await VoiceInputService.isVoiceInputAvailable();
});

/// Voice input state management
class VoiceInputState {
  final bool isListening;
  final String? lastResult;
  final String? error;
  
  const VoiceInputState({
    this.isListening = false,
    this.lastResult,
    this.error,
  });
  
  VoiceInputState copyWith({
    bool? isListening,
    String? lastResult,
    String? error,
  }) {
    return VoiceInputState(
      isListening: isListening ?? this.isListening,
      lastResult: lastResult ?? this.lastResult,
      error: error ?? this.error,
    );
  }
}

class VoiceInputNotifier extends StateNotifier<VoiceInputState> {
  VoiceInputNotifier() : super(const VoiceInputState());
  
  Future<void> startListening({
    String? prompt,
    String? language,
  }) async {
    state = state.copyWith(isListening: true, error: null);
    
    try {
      final result = await VoiceInputService.startVoiceInput(
        prompt: prompt,
        language: language,
      );
      
      state = state.copyWith(
        isListening: false,
        lastResult: result,
      );
    } catch (e) {
      state = state.copyWith(
        isListening: false,
        error: e.toString(),
      );
    }
  }
  
  void clearResult() {
    state = state.copyWith(lastResult: null, error: null);
  }
}

final voiceInputProvider = StateNotifierProvider<VoiceInputNotifier, VoiceInputState>((ref) {
  return VoiceInputNotifier();
});