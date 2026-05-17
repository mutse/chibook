import 'package:chibook/data/models/reader_preferences.dart';
import 'package:chibook/services/reader_preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reader preferences load falls back to defaults', () async {
    SharedPreferences.setMockInitialValues({});

    final preferences = await const ReaderPreferencesService().load();

    expect(preferences.themeMode, ReaderThemeMode.paper);
    expect(preferences.fontPreset, ReaderFontPreset.sans);
    expect(preferences.pageTurnMode, ReaderPageTurnMode.simulation);
    expect(preferences.brightness, closeTo(0.96, 0.001));
  });

  test('reader preferences save and reload extended fields', () async {
    SharedPreferences.setMockInitialValues({});
    const service = ReaderPreferencesService();
    const next = ReaderPreferences(
      themeMode: ReaderThemeMode.night,
      fontSize: 21,
      lineHeight: 2.05,
      brightness: 0.72,
      fontPreset: ReaderFontPreset.literary,
      pageTurnMode: ReaderPageTurnMode.slide,
    );

    await service.save(next);
    final loaded = await service.load();

    expect(loaded.themeMode, ReaderThemeMode.night);
    expect(loaded.fontSize, 21);
    expect(loaded.lineHeight, 2.05);
    expect(loaded.brightness, 0.72);
    expect(loaded.fontPreset, ReaderFontPreset.literary);
    expect(loaded.pageTurnMode, ReaderPageTurnMode.slide);
  });
}
