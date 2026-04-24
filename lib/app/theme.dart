import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF5D7CFF);
  const textColor = Color(0xFF1A2747);
  const secondaryText = Color(0xFF6E7EA4);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  ).copyWith(
    primary: seed,
    secondary: const Color(0xFF79B8FF),
    surface: Colors.white.withValues(alpha: 0.72),
    outline: const Color(0xFFD9E5FF),
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF1F5FF),
    useMaterial3: true,
    textTheme: ThemeData.light().textTheme.copyWith(
          headlineMedium: const TextStyle(
            color: textColor,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
          headlineSmall: const TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
          titleLarge: const TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: const TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: const TextStyle(
            color: textColor,
            fontSize: 16,
          ),
          bodyMedium: const TextStyle(
            color: secondaryText,
            fontSize: 14,
          ),
        ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: textColor,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.62),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: seed, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: secondaryText),
      hintStyle: const TextStyle(color: secondaryText),
    ),
    dividerColor: const Color(0xFFE2EAFF),
    sliderTheme: SliderThemeData(
      activeTrackColor: seed,
      inactiveTrackColor: const Color(0xFFD8E4FF),
      thumbColor: Colors.white,
      overlayColor: seed.withValues(alpha: 0.16),
      trackHeight: 4,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        side: const BorderSide(color: Color(0xCDE3EDFF)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: seed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
  );
}
