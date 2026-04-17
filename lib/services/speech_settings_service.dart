import 'package:chibook/data/models/speech_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpeechSettingsStorageKeys {
  static const providerMode = 'speech_output_mode';
  static const cloudProvider = 'cloud_tts_provider';
  static const endpoint = 'cloud_tts_endpoint';
  static const apiKey = 'cloud_tts_api_key';
  static const model = 'cloud_tts_model';
  static const voice = 'cloud_tts_voice';
  static const localVoiceId = 'local_tts_voice_id';
  static const speed = 'cloud_tts_speed';
  static const localSpeechRate = 'local_tts_speech_rate';

  static const legacyProviderMode = 'tts_provider_mode';
  static const legacyCloudProvider = 'tts_cloud_provider';
  static const legacyEndpoint = 'tts_endpoint';
  static const legacyApiKey = 'tts_api_key';
  static const legacyModel = 'tts_model';
  static const legacyVoice = 'tts_voice';
  static const legacyLocalVoiceId = 'tts_local_voice_id';
  static const legacySpeed = 'tts_speed';
  static const legacyLocalSpeechRate = 'tts_local_speech_rate';
}

class SpeechSettingsService {
  const SpeechSettingsService();

  Future<SpeechSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = SpeechSettings.defaults();
    final providerName = _readString(
      prefs,
      SpeechSettingsStorageKeys.providerMode,
      SpeechSettingsStorageKeys.legacyProviderMode,
    );
    final cloudProviderName = _readString(
      prefs,
      SpeechSettingsStorageKeys.cloudProvider,
      SpeechSettingsStorageKeys.legacyCloudProvider,
    );
    final providerMode = _parseMode(providerName) ?? defaults.providerMode;
    final cloudProvider =
        _parseCloudProvider(cloudProviderName) ?? defaults.cloudProvider;
    final defaultEndpoint = SpeechSettings.defaultEndpointFor(cloudProvider);
    final defaultModel = SpeechSettings.defaultModelFor(cloudProvider);
    final defaultVoice = SpeechSettings.defaultVoiceFor(cloudProvider);
    final rawEndpoint = _readString(
      prefs,
      SpeechSettingsStorageKeys.endpoint,
      SpeechSettingsStorageKeys.legacyEndpoint,
    );

    return defaults.copyWith(
      providerMode: providerMode,
      cloudProvider: cloudProvider,
      endpoint: rawEndpoint == null
          ? defaultEndpoint
          : SpeechSettings.normalizeEndpointFor(cloudProvider, rawEndpoint),
      apiKey: _readString(
            prefs,
            SpeechSettingsStorageKeys.apiKey,
            SpeechSettingsStorageKeys.legacyApiKey,
          ) ??
          defaults.apiKey,
      model: _readString(
            prefs,
            SpeechSettingsStorageKeys.model,
            SpeechSettingsStorageKeys.legacyModel,
          ) ??
          defaultModel,
      voice: _readString(
            prefs,
            SpeechSettingsStorageKeys.voice,
            SpeechSettingsStorageKeys.legacyVoice,
          ) ??
          defaultVoice,
      localVoiceId: _readString(
            prefs,
            SpeechSettingsStorageKeys.localVoiceId,
            SpeechSettingsStorageKeys.legacyLocalVoiceId,
          ) ??
          defaults.localVoiceId,
      speed: _readDouble(
            prefs,
            SpeechSettingsStorageKeys.speed,
            SpeechSettingsStorageKeys.legacySpeed,
          ) ??
          defaults.speed,
      localSpeechRate: _readDouble(
            prefs,
            SpeechSettingsStorageKeys.localSpeechRate,
            SpeechSettingsStorageKeys.legacyLocalSpeechRate,
          ) ??
          defaults.localSpeechRate,
    );
  }

  Future<void> save(SpeechSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SpeechSettingsStorageKeys.providerMode,
      settings.providerMode.name,
    );
    await prefs.setString(
      SpeechSettingsStorageKeys.cloudProvider,
      settings.cloudProvider.name,
    );
    await prefs.setString(
      SpeechSettingsStorageKeys.endpoint,
      SpeechSettings.normalizeEndpointFor(
        settings.cloudProvider,
        settings.endpoint,
      ),
    );
    await prefs.setString(SpeechSettingsStorageKeys.apiKey, settings.apiKey);
    await prefs.setString(SpeechSettingsStorageKeys.model, settings.model);
    await prefs.setString(SpeechSettingsStorageKeys.voice, settings.voice);
    await prefs.setString(
      SpeechSettingsStorageKeys.localVoiceId,
      settings.localVoiceId,
    );
    await prefs.setDouble(SpeechSettingsStorageKeys.speed, settings.speed);
    await prefs.setDouble(
      SpeechSettingsStorageKeys.localSpeechRate,
      settings.localSpeechRate,
    );
  }

  SpeechProviderMode? _parseMode(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value == 'openai') return SpeechProviderMode.cloud;
    for (final mode in SpeechProviderMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }

  CloudTtsProvider? _parseCloudProvider(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final provider in CloudTtsProvider.values) {
      if (provider.name == value) return provider;
    }
    return null;
  }

  String? _readString(SharedPreferences prefs, String key, String legacyKey) {
    return prefs.getString(key) ?? prefs.getString(legacyKey);
  }

  double? _readDouble(SharedPreferences prefs, String key, String legacyKey) {
    return prefs.getDouble(key) ?? prefs.getDouble(legacyKey);
  }
}
