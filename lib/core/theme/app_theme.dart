import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFE57373);
  static const Color warningColor = Color(0xFFFFB74D);
  
  // Readiness Level Colors
  static const Color readyColor = Color(0xFF4CAF50);    // Green
  static const Color warmColor = Color(0xFFFF9800);     // Orange
  static const Color fatiguedColor = Color(0xFFF44336); // Red
  
  // High Contrast Colors
  static const Color highContrastPrimary = Color(0xFF000000);
  static const Color highContrastSecondary = Color(0xFFFFFFFF);
  static const Color highContrastError = Color(0xFFFF0000);
  static const Color highContrastWarning = Color(0xFFFFFF00);
  static const Color highContrastReady = Color(0xFF00FF00);
  static const Color highContrastWarm = Color(0xFFFFFF00);
  static const Color highContrastFatigued = Color(0xFFFF0000);

  static ThemeData get lightTheme {
    return _buildTheme(Brightness.light, false, 1.0);
  }
  
  static ThemeData get highContrastLightTheme {
    return _buildTheme(Brightness.light, true, 1.0);
  }
  
  static ThemeData lightThemeWithScale(double textScaleFactor) {
    return _buildTheme(Brightness.light, false, textScaleFactor);
  }
  
  static ThemeData highContrastLightThemeWithScale(double textScaleFactor) {
    return _buildTheme(Brightness.light, true, textScaleFactor);
  }

  static ThemeData get darkTheme {
    return _buildTheme(Brightness.dark, false, 1.0);
  }
  
  static ThemeData get highContrastDarkTheme {
    return _buildTheme(Brightness.dark, true, 1.0);
  }
  
  static ThemeData darkThemeWithScale(double textScaleFactor) {
    return _buildTheme(Brightness.dark, false, textScaleFactor);
  }
  
  static ThemeData highContrastDarkThemeWithScale(double textScaleFactor) {
    return _buildTheme(Brightness.dark, true, textScaleFactor);
  }
  
  static ThemeData _buildTheme(Brightness brightness, bool highContrast, double textScaleFactor) {
    final seedColor = highContrast 
        ? (brightness == Brightness.light ? highContrastPrimary : highContrastSecondary)
        : primaryColor;
    
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    
    // Adjust colors for high contrast
    final adjustedColorScheme = highContrast ? colorScheme.copyWith(
      primary: brightness == Brightness.light ? highContrastPrimary : highContrastSecondary,
      onPrimary: brightness == Brightness.light ? highContrastSecondary : highContrastPrimary,
      secondary: brightness == Brightness.light ? highContrastPrimary : highContrastSecondary,
      onSecondary: brightness == Brightness.light ? highContrastSecondary : highContrastPrimary,
      error: highContrastError,
      onError: brightness == Brightness.light ? highContrastSecondary : highContrastPrimary,
      surface: brightness == Brightness.light ? highContrastSecondary : highContrastPrimary,
      onSurface: brightness == Brightness.light ? highContrastPrimary : highContrastSecondary,
    ) : colorScheme;
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: adjustedColorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: highContrast ? 4 : 0,
        titleTextStyle: TextStyle(
          fontSize: 20 * textScaleFactor,
          fontWeight: FontWeight.w600,
          color: adjustedColorScheme.onSurface,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: 24 * textScaleFactor, 
            vertical: 12 * textScaleFactor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: highContrast ? BorderSide(
              color: adjustedColorScheme.outline,
              width: 2,
            ) : BorderSide.none,
          ),
          textStyle: TextStyle(
            fontSize: 16 * textScaleFactor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: 16 * textScaleFactor,
            vertical: 8 * textScaleFactor,
          ),
          textStyle: TextStyle(
            fontSize: 16 * textScaleFactor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: highContrast ? 8 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: highContrast ? BorderSide(
            color: adjustedColorScheme.outline,
            width: 2,
          ) : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: adjustedColorScheme.outline,
            width: highContrast ? 2 : 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: adjustedColorScheme.outline,
            width: highContrast ? 2 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: adjustedColorScheme.primary,
            width: highContrast ? 3 : 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16 * textScaleFactor,
          vertical: 12 * textScaleFactor,
        ),
      ),
      textTheme: _buildTextTheme(adjustedColorScheme, textScaleFactor),
    );
  }
  
  static TextTheme _buildTextTheme(ColorScheme colorScheme, double textScaleFactor) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 57 * textScaleFactor,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 45 * textScaleFactor,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 36 * textScaleFactor,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: 32 * textScaleFactor,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 28 * textScaleFactor,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 24 * textScaleFactor,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 22 * textScaleFactor,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16 * textScaleFactor,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14 * textScaleFactor,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16 * textScaleFactor,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14 * textScaleFactor,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12 * textScaleFactor,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      labelLarge: TextStyle(
        fontSize: 14 * textScaleFactor,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 12 * textScaleFactor,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 11 * textScaleFactor,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
    );
  }
  
  /// Get readiness color with high contrast support
  static Color getReadinessColor(String readinessLevel, bool highContrast) {
    if (highContrast) {
      switch (readinessLevel.toLowerCase()) {
        case 'ready':
          return highContrastReady;
        case 'warm':
          return highContrastWarm;
        case 'fatigued':
          return highContrastFatigued;
        default:
          return highContrastPrimary;
      }
    } else {
      switch (readinessLevel.toLowerCase()) {
        case 'ready':
          return readyColor;
        case 'warm':
          return warmColor;
        case 'fatigued':
          return fatiguedColor;
        default:
          return primaryColor;
      }
    }
  }
}