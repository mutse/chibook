import 'package:chibook/data/models/speech_settings.dart';
import 'package:chibook/services/speech_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default speech settings prefer microsoft edge without api key', () {
    final settings = SpeechSettings.defaults();

    expect(settings.providerMode, SpeechProviderMode.auto);
    expect(settings.cloudProvider, CloudTtsProvider.microsoftEdge);
    expect(
      settings.endpoint,
      SpeechSettings.defaultEndpointFor(CloudTtsProvider.microsoftEdge),
    );
    expect(settings.apiKey, isEmpty);
    expect(
      settings.model,
      SpeechSettings.defaultModelFor(CloudTtsProvider.microsoftEdge),
    );
    expect(
      settings.voice,
      SpeechSettings.defaultVoiceFor(CloudTtsProvider.microsoftEdge),
    );
    expect(settings.hasCloudConfig, isTrue);
  });

  test('microsoft edge cloud config does not require an api key', () {
    const settings = SpeechSettings(
      providerMode: SpeechProviderMode.cloud,
      cloudProvider: CloudTtsProvider.microsoftEdge,
      endpoint:
          'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1',
      apiKey: '',
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
      CloudTtsProvider.microsoftEdge,
      'https://eastus.tts.speech.microsoft.com/cognitiveservices/v1',
    );

    expect(
      endpoint,
      SpeechSettings.defaultEndpointFor(CloudTtsProvider.microsoftEdge),
    );
  });

  test('microsoft edge voices list endpoint normalizes to websocket endpoint',
      () {
    final endpoint = SpeechSettings.normalizeEndpointFor(
      CloudTtsProvider.microsoftEdge,
      'https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list?trustedclienttoken=test',
    );

    expect(
      endpoint,
      SpeechSettings.defaultEndpointFor(CloudTtsProvider.microsoftEdge),
    );
  });

  test('microsoft edge voice normalizes azure display name', () {
    final voice = SpeechSettings.normalizeVoiceFor(
      CloudTtsProvider.microsoftEdge,
      'Microsoft Server Speech Text to Speech Voice (en-US, JennyNeural)',
    );

    expect(voice, 'en-US-JennyNeural');
  });

  test('microsoft edge voice falls back when another provider voice is saved',
      () {
    final voice = SpeechSettings.normalizeVoiceFor(
      CloudTtsProvider.microsoftEdge,
      'alloy',
    );

    expect(
      voice,
      SpeechSettings.defaultVoiceFor(CloudTtsProvider.microsoftEdge),
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
      CloudTtsProvider.microsoftEdge,
      'gpt-4o-mini-tts',
    );

    expect(
      model,
      SpeechSettings.defaultModelFor(CloudTtsProvider.microsoftEdge),
    );
  });

  test('service load uses provider-specific defaults for microsoft edge',
      () async {
    SharedPreferences.setMockInitialValues({
      SpeechSettingsStorageKeys.cloudProvider:
          CloudTtsProvider.microsoftEdge.name,
    });

    final settings = await const SpeechSettingsService().load();

    expect(settings.cloudProvider, CloudTtsProvider.microsoftEdge);
    expect(
      settings.endpoint,
      SpeechSettings.defaultEndpointFor(CloudTtsProvider.microsoftEdge),
    );
    expect(
      settings.model,
      SpeechSettings.defaultModelFor(CloudTtsProvider.microsoftEdge),
    );
    expect(
      settings.voice,
      SpeechSettings.defaultVoiceFor(CloudTtsProvider.microsoftEdge),
    );
    expect(settings.apiKey, isEmpty);
  });

  test('service load repairs invalid microsoft edge model and voice', () async {
    SharedPreferences.setMockInitialValues({
      SpeechSettingsStorageKeys.cloudProvider:
          CloudTtsProvider.microsoftEdge.name,
      SpeechSettingsStorageKeys.model: 'gpt-4o-mini-tts',
      SpeechSettingsStorageKeys.voice: 'alloy',
      SpeechSettingsStorageKeys.endpoint:
          'https://eastus.tts.speech.microsoft.com/cognitiveservices/v1',
    });

    final settings = await const SpeechSettingsService().load();

    expect(
      settings.endpoint,
      SpeechSettings.defaultEndpointFor(CloudTtsProvider.microsoftEdge),
    );
    expect(
      settings.model,
      SpeechSettings.defaultModelFor(CloudTtsProvider.microsoftEdge),
    );
    expect(
      settings.voice,
      SpeechSettings.defaultVoiceFor(CloudTtsProvider.microsoftEdge),
    );
  });

  test('service load defaults reader-facing provider to microsoft edge',
      () async {
    SharedPreferences.setMockInitialValues({});

    final settings = await const SpeechSettingsService().load();

    expect(settings.cloudProvider, CloudTtsProvider.microsoftEdge);
    expect(
      settings.endpoint,
      SpeechSettings.defaultEndpointFor(CloudTtsProvider.microsoftEdge),
    );
  });
}
