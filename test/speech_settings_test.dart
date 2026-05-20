import 'package:chibook/data/models/speech_settings.dart';
import 'package:chibook/services/secure_settings_service.dart';
import 'package:chibook/services/speech_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureSettingsService extends SecureSettingsService {
  _FakeSecureSettingsService(this._values);

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default speech settings prefer local mode with azure speech preset', () {
    final settings = SpeechSettings.defaults();

    expect(settings.providerMode, SpeechProviderMode.local);
    expect(settings.cloudProvider, CloudTtsProvider.azureSpeech);
    expect(
      settings.endpoint,
      SpeechSettings.defaultEndpointFor(CloudTtsProvider.azureSpeech),
    );
    expect(settings.apiKey, isEmpty);
    expect(
      settings.model,
      SpeechSettings.defaultModelFor(CloudTtsProvider.azureSpeech),
    );
    expect(
      settings.voice,
      SpeechSettings.defaultVoiceFor(CloudTtsProvider.azureSpeech),
    );
    expect(settings.hasCloudConfig, isFalse);
  });

  test('azure speech cloud config requires an api key', () {
    const settings = SpeechSettings(
      providerMode: SpeechProviderMode.cloud,
      cloudProvider: CloudTtsProvider.azureSpeech,
      endpoint:
          'https://eastus.tts.speech.microsoft.com/cognitiveservices/v1',
      apiKey: 'azure-key',
      model: 'audio-24khz-48kbitrate-mono-mp3',
      voice: 'zh-CN-XiaoxiaoNeural',
      localVoiceId: '',
      speed: 1.0,
      localSpeechRate: 0.45,
    );

    expect(settings.hasCloudConfig, isTrue);
    expect(settings.isCloudReady, isTrue);
  });

  test('legacy microsoft edge endpoint normalizes to edge read aloud', () {
    final endpoint = SpeechSettings.normalizeEndpointFor(
      CloudTtsProvider.azureSpeech,
      'https://eastus.tts.speech.microsoft.com/cognitiveservices/v1',
    );

    expect(
      endpoint,
      SpeechSettings.defaultEndpointFor(CloudTtsProvider.azureSpeech),
    );
  });

  test('microsoft edge voices list endpoint normalizes to websocket endpoint',
      () {
    final endpoint = SpeechSettings.normalizeEndpointFor(
      CloudTtsProvider.azureSpeech,
      'https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list?trustedclienttoken=test',
    );

    expect(
      endpoint,
      SpeechSettings.defaultEndpointFor(CloudTtsProvider.azureSpeech),
    );
  });

  test('microsoft edge voice normalizes azure display name', () {
    final voice = SpeechSettings.normalizeVoiceFor(
      CloudTtsProvider.azureSpeech,
      'Microsoft Server Speech Text to Speech Voice (en-US, JennyNeural)',
    );

    expect(voice, 'en-US-JennyNeural');
  });

  test('microsoft edge voice falls back when another provider voice is saved',
      () {
    final voice = SpeechSettings.normalizeVoiceFor(
      CloudTtsProvider.azureSpeech,
      'alloy',
    );

    expect(
      voice,
      SpeechSettings.defaultVoiceFor(CloudTtsProvider.azureSpeech),
    );
  });

  test('elevenlabs endpoint strips pasted voice id path', () {
    final endpoint = SpeechSettings.normalizeEndpointFor(
      CloudTtsProvider.elevenlabs,
      'https://api.elevenlabs.io/v1/text-to-speech/JBFqnCBsd6RMkjVDRZzb',
    );

    expect(
      endpoint,
      SpeechSettings.defaultEndpointFor(CloudTtsProvider.elevenlabs),
    );
  });

  test('elevenlabs endpoint strips voice placeholder path', () {
    final endpoint = SpeechSettings.normalizeEndpointFor(
      CloudTtsProvider.elevenlabs,
      'https://api.elevenlabs.io/v1/text-to-speech/{voice_id}',
    );

    expect(
      endpoint,
      SpeechSettings.defaultEndpointFor(CloudTtsProvider.elevenlabs),
    );
  });

  test('microsoft edge model falls back when another provider model is saved',
      () {
    final model = SpeechSettings.normalizeModelFor(
      CloudTtsProvider.azureSpeech,
      'gpt-4o-mini-tts',
    );

    expect(
      model,
      SpeechSettings.defaultModelFor(CloudTtsProvider.azureSpeech),
    );
  });

  test('service load normalizes legacy microsoft edge into azure speech preset',
      () async {
    SharedPreferences.setMockInitialValues({
      SpeechSettingsStorageKeys.cloudProvider:
          CloudTtsProvider.microsoftEdge.name,
    });
    final secureSettings = _FakeSecureSettingsService({});

    final settings = await SpeechSettingsService(
      secureSettingsService: secureSettings,
    ).load();

    expect(settings.cloudProvider, CloudTtsProvider.azureSpeech);
    expect(
      settings.endpoint,
      SpeechSettings.defaultEndpointFor(CloudTtsProvider.azureSpeech),
    );
    expect(
      settings.model,
      SpeechSettings.defaultModelFor(CloudTtsProvider.azureSpeech),
    );
    expect(
      settings.voice,
      SpeechSettings.defaultVoiceFor(CloudTtsProvider.azureSpeech),
    );
    expect(settings.apiKey, isEmpty);
  });

  test('service load repairs invalid microsoft edge model and voice', () async {
    SharedPreferences.setMockInitialValues({
      SpeechSettingsStorageKeys.cloudProvider:
          CloudTtsProvider.microsoftEdge.name,
      SpeechSettingsStorageKeys.model: 'gpt-4o-mini-tts',
      SpeechSettingsStorageKeys.voice: 'alloy',
      SpeechSettingsStorageKeys.legacyEndpoint:
          'https://eastus.tts.speech.microsoft.com/cognitiveservices/v1',
    });
    final secureSettings = _FakeSecureSettingsService({});

    final settings = await SpeechSettingsService(
      secureSettingsService: secureSettings,
    ).load();

    expect(
      settings.endpoint,
      SpeechSettings.defaultEndpointFor(CloudTtsProvider.azureSpeech),
    );
    expect(
      settings.model,
      SpeechSettings.defaultModelFor(CloudTtsProvider.azureSpeech),
    );
    expect(
      settings.voice,
      SpeechSettings.defaultVoiceFor(CloudTtsProvider.azureSpeech),
    );
  });

  test('service load defaults reader-facing provider to azure speech',
      () async {
    SharedPreferences.setMockInitialValues({});
    final secureSettings = _FakeSecureSettingsService({});

    final settings = await SpeechSettingsService(
      secureSettingsService: secureSettings,
    ).load();

    expect(settings.cloudProvider, CloudTtsProvider.azureSpeech);
    expect(
      settings.endpoint,
      SpeechSettings.defaultEndpointFor(CloudTtsProvider.azureSpeech),
    );
  });
}
