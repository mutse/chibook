enum ReaderThemeMode { paper, sepia, night }

class ReaderPreferences {
  const ReaderPreferences({
    required this.themeMode,
    required this.fontSize,
    required this.lineHeight,
  });

  factory ReaderPreferences.defaults() {
    return const ReaderPreferences(
      themeMode: ReaderThemeMode.paper,
      fontSize: 18,
      lineHeight: 1.85,
    );
  }

  final ReaderThemeMode themeMode;
  final double fontSize;
  final double lineHeight;

  ReaderPreferences copyWith({
    ReaderThemeMode? themeMode,
    double? fontSize,
    double? lineHeight,
  }) {
    return ReaderPreferences(
      themeMode: themeMode ?? this.themeMode,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }
}
