import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/l10n/app_localizations.dart';
import 'core/l10n/localization_service.dart';
import 'core/services/accessibility_service.dart';

void main() {
  runApp(
    const ProviderScope(
      child: CycleAvatarApp(),
    ),
  );
}

class CycleAvatarApp extends ConsumerWidget {
  const CycleAvatarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final currentLocale = ref.watch(localeProvider);
    final accessibilitySettings = ref.watch(accessibilitySettingsProvider);
    
    // Update text scale factor based on system settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mediaQuery = MediaQuery.of(context);
      final systemTextScaleFactor = mediaQuery.textScaleFactor;
      if (systemTextScaleFactor != accessibilitySettings.textScaleFactor) {
        ref.read(accessibilitySettingsProvider.notifier)
            .updateTextScaleFactor(systemTextScaleFactor);
      }
    });
    
    return MaterialApp.router(
      title: 'CycleAvatar',
      theme: _getTheme(Brightness.light, accessibilitySettings),
      darkTheme: _getTheme(Brightness.dark, accessibilitySettings),
      themeMode: ThemeMode.system,
      routerConfig: router,
      locale: currentLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ja'),
      ],
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: accessibilitySettings.textScaleFactor.clamp(1.0, 2.0),
          ),
          child: child!,
        );
      },
    );
  }
  
  ThemeData _getTheme(Brightness brightness, AccessibilitySettings settings) {
    if (brightness == Brightness.light) {
      if (settings.highContrastEnabled) {
        return AppTheme.highContrastLightThemeWithScale(settings.textScaleFactor);
      } else {
        return AppTheme.lightThemeWithScale(settings.textScaleFactor);
      }
    } else {
      if (settings.highContrastEnabled) {
        return AppTheme.highContrastDarkThemeWithScale(settings.textScaleFactor);
      } else {
        return AppTheme.darkThemeWithScale(settings.textScaleFactor);
      }
    }
  }
}