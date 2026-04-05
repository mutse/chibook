import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF136B5C);

  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
    scaffoldBackgroundColor: const Color(0xFFF6F1E7),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFF18211D),
      elevation: 0,
    ),
  );
}
