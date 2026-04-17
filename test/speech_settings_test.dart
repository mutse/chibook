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
}
