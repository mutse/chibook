enum ReaderThemeMode { paper, sepia, night }

enum ReaderFontPreset { sans, literary, focus }

enum ReaderPageTurnMode { cover, simulation, slide, none }

class ReaderPreferences {
  const ReaderPreferences({
    required this.themeMode,
    required this.fontSize,
    required this.lineHeight,
    required this.brightness,
    required this.fontPreset,
    required this.pageTurnMode,
  });

  factory ReaderPreferences.defaults() {
    return const ReaderPreferences(
      themeMode: ReaderThemeMode.paper,
      fontSize: 18,
      lineHeight: 1.85,
      brightness: 0.96,
      fontPreset: ReaderFontPreset.sans,
      pageTurnMode: ReaderPageTurnMode.simulation,
    );
  }

  final ReaderThemeMode themeMode;
  final double fontSize;
  final double lineHeight;
  final double brightness;
  final ReaderFontPreset fontPreset;
  final ReaderPageTurnMode pageTurnMode;

  ReaderPreferences copyWith({
    ReaderThemeMode? themeMode,
    double? fontSize,
    double? lineHeight,
    double? brightness,
    ReaderFontPreset? fontPreset,
    ReaderPageTurnMode? pageTurnMode,
  }) {
    return ReaderPreferences(
      themeMode: themeMode ?? this.themeMode,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      brightness: brightness ?? this.brightness,
      fontPreset: fontPreset ?? this.fontPreset,
      pageTurnMode: pageTurnMode ?? this.pageTurnMode,
    );
  }
}

String readerThemeLabel(ReaderThemeMode mode) {
  return switch (mode) {
    ReaderThemeMode.paper => '纸白',
    ReaderThemeMode.sepia => '护眼',
    ReaderThemeMode.night => '夜间',
  };
}

String readerFontPresetLabel(ReaderFontPreset preset) {
  return switch (preset) {
    ReaderFontPreset.sans => '简约无衬线',
    ReaderFontPreset.literary => '经典衬线',
    ReaderFontPreset.focus => '专注等宽',
  };
}

String readerPageTurnModeLabel(ReaderPageTurnMode mode) {
  return switch (mode) {
    ReaderPageTurnMode.cover => '覆盖',
    ReaderPageTurnMode.simulation => '仿真',
    ReaderPageTurnMode.slide => '滑动',
    ReaderPageTurnMode.none => '无',
  };
}

String? readerFontFamily(ReaderFontPreset preset) {
  return switch (preset) {
    ReaderFontPreset.sans => null,
    ReaderFontPreset.literary => 'Georgia',
    ReaderFontPreset.focus => 'Courier',
  };
}

double readerLetterSpacing(ReaderFontPreset preset) {
  return switch (preset) {
    ReaderFontPreset.sans => 0,
    ReaderFontPreset.literary => 0.25,
    ReaderFontPreset.focus => -0.15,
  };
}
