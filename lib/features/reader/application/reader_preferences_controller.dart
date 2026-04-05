import 'package:chibook/data/models/reader_preferences.dart';
import 'package:chibook/services/reader_preferences_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final readerPreferencesServiceProvider = Provider<ReaderPreferencesService>((ref) {
  return const ReaderPreferencesService();
});

final readerPreferencesControllerProvider =
    AsyncNotifierProvider<ReaderPreferencesController, ReaderPreferences>(
  ReaderPreferencesController.new,
);

class ReaderPreferencesController extends AsyncNotifier<ReaderPreferences> {
  @override
  Future<ReaderPreferences> build() async {
    return ref.read(readerPreferencesServiceProvider).load();
  }

  Future<void> save(ReaderPreferences preferences) async {
    await ref.read(readerPreferencesServiceProvider).save(preferences);
    state = AsyncData(preferences);
  }
}
