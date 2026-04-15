import 'package:chibook/data/models/speech_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
