import 'package:chibook/data/models/speech_settings.dart';
import 'package:chibook/services/speech_settings_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final speechSettingsServiceProvider = Provider<SpeechSettingsService>((ref) {
  return const SpeechSettingsService();
});

final speechSettingsControllerProvider =
    AsyncNotifierProvider<SpeechSettingsController, SpeechSettings>(
  SpeechSettingsController.new,
);

class SpeechSettingsController extends AsyncNotifier<SpeechSettings> {
  @override
  Future<SpeechSettings> build() async {
    return ref.read(speechSettingsServiceProvider).load();
  }

  Future<void> save(SpeechSettings settings) async {
    state = const AsyncLoading();
    await ref.read(speechSettingsServiceProvider).save(settings);
    state = AsyncData(settings);
  }
}
