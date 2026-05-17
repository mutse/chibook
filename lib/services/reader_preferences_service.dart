import 'package:chibook/data/models/reader_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderPreferencesService {
  const ReaderPreferencesService();

  Future<ReaderPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = ReaderPreferences.defaults();
    final themeName = prefs.getString('reader_theme_mode');
    final fontPreset = prefs.getString('reader_font_preset');
    final pageTurnMode = prefs.getString('reader_page_turn_mode');

    return defaults.copyWith(
      themeMode: _parseTheme(themeName) ?? defaults.themeMode,
      fontSize: prefs.getDouble('reader_font_size') ?? defaults.fontSize,
      lineHeight: prefs.getDouble('reader_line_height') ?? defaults.lineHeight,
      brightness: prefs.getDouble('reader_brightness')?.clamp(0.45, 1.0) ??
          defaults.brightness,
      fontPreset: _parseFontPreset(fontPreset) ?? defaults.fontPreset,
      pageTurnMode: _parsePageTurnMode(pageTurnMode) ?? defaults.pageTurnMode,
    );
  }

  Future<void> save(ReaderPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_theme_mode', preferences.themeMode.name);
    await prefs.setDouble('reader_font_size', preferences.fontSize);
    await prefs.setDouble('reader_line_height', preferences.lineHeight);
    await prefs.setDouble('reader_brightness', preferences.brightness);
    await prefs.setString('reader_font_preset', preferences.fontPreset.name);
    await prefs.setString(
      'reader_page_turn_mode',
      preferences.pageTurnMode.name,
    );
  }

  ReaderThemeMode? _parseTheme(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final item in ReaderThemeMode.values) {
      if (item.name == value) return item;
    }
    return null;
  }

  ReaderFontPreset? _parseFontPreset(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final item in ReaderFontPreset.values) {
      if (item.name == value) return item;
    }
    return null;
  }

  ReaderPageTurnMode? _parsePageTurnMode(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final item in ReaderPageTurnMode.values) {
      if (item.name == value) return item;
    }
    return null;
  }
}
