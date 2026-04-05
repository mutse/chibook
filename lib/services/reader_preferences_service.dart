import 'package:chibook/data/models/reader_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderPreferencesService {
  const ReaderPreferencesService();

  Future<ReaderPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = ReaderPreferences.defaults();
    final themeName = prefs.getString('reader_theme_mode');

    return defaults.copyWith(
      themeMode: _parseTheme(themeName) ?? defaults.themeMode,
      fontSize: prefs.getDouble('reader_font_size') ?? defaults.fontSize,
      lineHeight: prefs.getDouble('reader_line_height') ?? defaults.lineHeight,
    );
  }

  Future<void> save(ReaderPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_theme_mode', preferences.themeMode.name);
    await prefs.setDouble('reader_font_size', preferences.fontSize);
    await prefs.setDouble('reader_line_height', preferences.lineHeight);
  }

  ReaderThemeMode? _parseTheme(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final item in ReaderThemeMode.values) {
      if (item.name == value) return item;
    }
    return null;
  }
}
