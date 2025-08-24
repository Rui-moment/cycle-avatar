import 'package:logger/logger.dart';

import '../../domain/entities/exercise.dart';
import '../../domain/entities/muscle_group.dart';
import '../../domain/entities/enums.dart';
import '../constants/multilingual_data.dart';

/// Service for handling fallback logic when localized content is not available
class FallbackService {
  static final Logger _logger = Logger();
  
  /// Get localized name with fallback logic
  /// Priority: requested locale -> English -> original ID
  static String getLocalizedName(
    Map<String, String> names,
    String requestedLocale,
    String fallbackId,
  ) {
    // Try requested locale first
    if (names.containsKey(requestedLocale) && names[requestedLocale]!.isNotEmpty) {
      return names[requestedLocale]!;
    }
    
    // Fallback to English
    if (names.containsKey('en') && names['en']!.isNotEmpty) {
      _logger.d('Falling back to English for: $fallbackId');
      return names['en']!;
    }
    
    // Fallback to any available language
    final availableNames = names.values.where((name) => name.isNotEmpty);
    if (availableNames.isNotEmpty) {
      _logger.d('Falling back to available language for: $fallbackId');
      return availableNames.first;
    }
    
    // Final fallback to ID
    _logger.w('No localized name found, using ID: $fallbackId');
    return fallbackId;
  }
  
  /// Get localized instructions with fallback logic
  static String getLocalizedInstructions(
    Map<String, String> instructions,
    String requestedLocale,
    String fallbackId,
  ) {
    // Try requested locale first
    if (instructions.containsKey(requestedLocale) && instructions[requestedLocale]!.isNotEmpty) {
      return instructions[requestedLocale]!;
    }
    
    // Fallback to English
    if (instructions.containsKey('en') && instructions['en']!.isNotEmpty) {
      _logger.d('Falling back to English instructions for: $fallbackId');
      return instructions['en']!;
    }
    
    // Fallback to any available language
    final availableInstructions = instructions.values.where((inst) => inst.isNotEmpty);
    if (availableInstructions.isNotEmpty) {
      _logger.d('Falling back to available language instructions for: $fallbackId');
      return availableInstructions.first;
    }
    
    // Final fallback to empty string
    _logger.w('No localized instructions found for: $fallbackId');
    return '';
  }
  
  /// Create a fallback exercise when database data is missing
  static Exercise createFallbackExercise(String exerciseId, String locale) {
    _logger.w('Creating fallback exercise for: $exerciseId');
    
    // Try to get from multilingual data first
    final names = EXERCISE_NAMES[exerciseId] ?? {
      'en': exerciseId.replaceAll('_', ' ').split(' ').map((word) => 
          word.isEmpty ? word : word[0].toUpperCase() + word.substring(1)).join(' '),
      'ja': exerciseId,
    };
    
    final instructions = EXERCISE_INSTRUCTIONS[exerciseId] ?? <String, String>{};
    
    return Exercise(
      id: exerciseId,
      names: names,
      category: 'unknown',
      equipment: EquipmentType.other,
      instructions: instructions,
      primaryMuscleGroups: ['chest'], // Default to chest
      secondaryMuscleGroups: [],
      isCompound: false,
      createdAt: DateTime.now(),
    );
  }
  
  /// Create a fallback muscle group when database data is missing
  static MuscleGroup createFallbackMuscleGroup(String muscleGroupId, String locale) {
    _logger.w('Creating fallback muscle group for: $muscleGroupId');
    
    // Try to get from multilingual data first
    final names = MUSCLE_GROUP_NAMES[muscleGroupId] ?? {
      'en': muscleGroupId.replaceAll('_', ' ').split(' ').map((word) => 
          word.isEmpty ? word : word[0].toUpperCase() + word.substring(1)).join(' '),
      'ja': muscleGroupId,
    };
    
    return MuscleGroup.withDefaults(
      id: muscleGroupId,
      names: names,
      bodyRegion: 'upper', // Default to upper body
    );
  }
  
  /// Validate and fix multilingual data
  static Map<String, String> validateAndFixNames(
    Map<String, String> names,
    String entityId,
  ) {
    final fixedNames = Map<String, String>.from(names);
    
    // Ensure English name exists
    if (!fixedNames.containsKey('en') || fixedNames['en']!.isEmpty) {
      fixedNames['en'] = entityId.replaceAll('_', ' ').split(' ').map((word) => 
          word.isEmpty ? word : word[0].toUpperCase() + word.substring(1)).join(' ');
      _logger.d('Added fallback English name for: $entityId');
    }
    
    // Remove empty names
    fixedNames.removeWhere((key, value) => value.isEmpty);
    
    return fixedNames;
  }
  
  /// Get supported locales for an entity
  static List<String> getSupportedLocales(Map<String, String> names) {
    return names.keys.where((key) => names[key]!.isNotEmpty).toList();
  }
  
  /// Check if an entity has complete multilingual support
  static bool hasCompleteMultilingualSupport(
    Map<String, String> names,
    List<String> requiredLocales,
  ) {
    for (final locale in requiredLocales) {
      if (!names.containsKey(locale) || names[locale]!.isEmpty) {
        return false;
      }
    }
    return true;
  }
  
  /// Get missing locales for an entity
  static List<String> getMissingLocales(
    Map<String, String> names,
    List<String> requiredLocales,
  ) {
    return requiredLocales.where((locale) => 
        !names.containsKey(locale) || names[locale]!.isEmpty).toList();
  }
  
  /// Create a localized error message
  static String getLocalizedErrorMessage(String errorKey, String locale) {
    final errorMessages = {
      'exercise_not_found': {
        'en': 'Exercise not found',
        'ja': '種目が見つかりません',
      },
      'muscle_group_not_found': {
        'en': 'Muscle group not found',
        'ja': '筋群が見つかりません',
      },
      'localization_error': {
        'en': 'Localization error',
        'ja': 'ローカライゼーションエラー',
      },
      'fallback_used': {
        'en': 'Using fallback data',
        'ja': 'フォールバックデータを使用',
      },
    };
    
    final messages = errorMessages[errorKey];
    if (messages == null) return errorKey;
    
    return getLocalizedName(messages, locale, errorKey);
  }
  
  /// Log multilingual data issues for debugging
  static void logMultilingualIssue(
    String entityType,
    String entityId,
    String issue,
    String locale,
  ) {
    _logger.w('Multilingual issue - Type: $entityType, ID: $entityId, Issue: $issue, Locale: $locale');
  }
}