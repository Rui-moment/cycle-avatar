import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../../data/repositories/user_repository.dart';
import '../../core/providers/providers.dart';

/// Service for managing app localization
class LocalizationService {
  static const String _languageKey = 'preferred_language';
  static const List<String> supportedLanguages = ['en', 'ja'];
  
  final FlutterSecureStorage _storage;
  final UserRepository? _userRepository;
  final Logger _logger = Logger();
  
  LocalizationService({
    FlutterSecureStorage? storage,
    UserRepository? userRepository,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _userRepository = userRepository;
  
  /// Get the current locale from storage or device settings
  Future<Locale> getCurrentLocale() async {
    try {
      // First try to get from secure storage
      final storedLanguage = await _storage.read(key: _languageKey);
      if (storedLanguage != null && supportedLanguages.contains(storedLanguage)) {
        _logger.d('Retrieved stored language: $storedLanguage');
        return Locale(storedLanguage);
      }
      
      // Fall back to device locale
      final deviceLocale = PlatformDispatcher.instance.locale;
      final deviceLanguage = deviceLocale.languageCode;
      
      if (supportedLanguages.contains(deviceLanguage)) {
        _logger.d('Using device language: $deviceLanguage');
        // Store the device language for future use
        await _storage.write(key: _languageKey, value: deviceLanguage);
        return Locale(deviceLanguage);
      }
      
      // Default to English
      _logger.d('Defaulting to English');
      await _storage.write(key: _languageKey, value: 'en');
      return const Locale('en');
      
    } catch (e) {
      _logger.e('Error getting current locale: $e');
      return const Locale('en');
    }
  }
  
  /// Change the app language
  Future<void> changeLanguage(String languageCode) async {
    if (!supportedLanguages.contains(languageCode)) {
      throw ArgumentError('Unsupported language: $languageCode');
    }
    
    try {
      // Store in secure storage
      await _storage.write(key: _languageKey, value: languageCode);
      _logger.d('Language changed to: $languageCode');
      
      // Update user preference in database if user repository is available
      if (_userRepository != null) {
        // Note: In a real app, you'd get the current user ID from auth state
        // For now, we'll just log that we would update it
        _logger.d('Would update user language preference to: $languageCode');
      }
      
    } catch (e) {
      _logger.e('Error changing language: $e');
      rethrow;
    }
  }
  
  /// Get supported locales
  List<Locale> getSupportedLocales() {
    return supportedLanguages.map((lang) => Locale(lang)).toList();
  }
  
  /// Get language display name
  String getLanguageDisplayName(String languageCode, String currentLanguage) {
    switch (languageCode) {
      case 'en':
        return currentLanguage == 'ja' ? 'English' : 'English';
      case 'ja':
        return currentLanguage == 'ja' ? '日本語' : 'Japanese';
      default:
        return languageCode.toUpperCase();
    }
  }
  
  /// Clear stored language preference
  Future<void> clearLanguagePreference() async {
    try {
      await _storage.delete(key: _languageKey);
      _logger.d('Language preference cleared');
    } catch (e) {
      _logger.e('Error clearing language preference: $e');
    }
  }
}

/// Provider for LocalizationService
final localizationServiceProvider = Provider<LocalizationService>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return LocalizationService(userRepository: userRepository);
});

/// State notifier for managing current locale
class LocaleNotifier extends StateNotifier<Locale> {
  final LocalizationService _localizationService;
  
  LocaleNotifier(this._localizationService) : super(const Locale('en')) {
    _initializeLocale();
  }
  
  Future<void> _initializeLocale() async {
    final locale = await _localizationService.getCurrentLocale();
    state = locale;
  }
  
  Future<void> changeLanguage(String languageCode) async {
    await _localizationService.changeLanguage(languageCode);
    state = Locale(languageCode);
  }
  
  List<Locale> get supportedLocales => _localizationService.getSupportedLocales();
  
  String getLanguageDisplayName(String languageCode) {
    return _localizationService.getLanguageDisplayName(
      languageCode, 
      state.languageCode,
    );
  }
}

/// Provider for current locale state
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  final localizationService = ref.watch(localizationServiceProvider);
  return LocaleNotifier(localizationService);
});