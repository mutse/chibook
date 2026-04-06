import 'package:chibook/data/models/speech_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpeechSettingsService {
  const SpeechSettingsService();

  Future<SpeechSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = SpeechSettings.defaults();
    final providerName = prefs.getString('tts_provider_mode');

    return defaults.copyWith(
      providerMode: _parseMode(providerName) ?? defaults.providerMode,
      endpoint: prefs.getString('tts_endpoint') ?? defaults.endpoint,
      apiKey: prefs.getString('tts_api_key') ?? defaults.apiKey,
      model: prefs.getString('tts_model') ?? defaults.model,
      voice: prefs.getString('tts_voice') ?? defaults.voice,
      localVoiceId:
          prefs.getString('tts_local_voice_id') ?? defaults.localVoiceId,
      speed: prefs.getDouble('tts_speed') ?? defaults.speed,
      localSpeechRate:
          prefs.getDouble('tts_local_speech_rate') ?? defaults.localSpeechRate,
    );
  }

  Future<void> save(SpeechSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tts_provider_mode', settings.providerMode.name);
    await prefs.setString('tts_endpoint', settings.endpoint);
    await prefs.setString('tts_api_key', settings.apiKey);
    await prefs.setString('tts_model', settings.model);
    await prefs.setString('tts_voice', settings.voice);
    await prefs.setString('tts_local_voice_id', settings.localVoiceId);
    await prefs.setDouble('tts_speed', settings.speed);
    await prefs.setDouble('tts_local_speech_rate', settings.localSpeechRate);
  }

  SpeechProviderMode? _parseMode(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final mode in SpeechProviderMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}
