enum SpeechProviderMode { auto, cloud, local }

enum CloudTtsProvider { openai, microsoftEdge, elevenlabs }

class SpeechSettings {
  const SpeechSettings({
    required this.providerMode,
    required this.cloudProvider,
    required this.endpoint,
    required this.apiKey,
    required this.model,
    required this.voice,
    required this.localVoiceId,
    required this.speed,
    required this.localSpeechRate,
  });

  factory SpeechSettings.defaults() {
    return const SpeechSettings(
      providerMode: SpeechProviderMode.auto,
      cloudProvider: CloudTtsProvider.openai,
      endpoint: 'https://api.openai.com/v1/audio/speech',
      apiKey: '',
      model: 'gpt-4o-mini-tts',
      voice: 'alloy',
      localVoiceId: '',
      speed: 1.0,
      localSpeechRate: 0.45,
    );
  }

  final SpeechProviderMode providerMode;
  final CloudTtsProvider cloudProvider;
  final String endpoint;
  final String apiKey;
  final String model;
  final String voice;
  final String localVoiceId;
  final double speed;
  final double localSpeechRate;

  bool get hasCloudConfig => isCloudReady;
  bool get isCloudReady {
    return switch (cloudProvider) {
      CloudTtsProvider.openai => endpoint.isNotEmpty && apiKey.isNotEmpty,
      CloudTtsProvider.microsoftEdge => endpoint.isNotEmpty,
      CloudTtsProvider.elevenlabs => endpoint.isNotEmpty && apiKey.isNotEmpty,
    };
  }

  SpeechSettings copyWith({
    SpeechProviderMode? providerMode,
    CloudTtsProvider? cloudProvider,
    String? endpoint,
    String? apiKey,
    String? model,
    String? voice,
    String? localVoiceId,
    double? speed,
    double? localSpeechRate,
  }) {
    return SpeechSettings(
      providerMode: providerMode ?? this.providerMode,
      cloudProvider: cloudProvider ?? this.cloudProvider,
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      voice: voice ?? this.voice,
      localVoiceId: localVoiceId ?? this.localVoiceId,
      speed: speed ?? this.speed,
      localSpeechRate: localSpeechRate ?? this.localSpeechRate,
    );
  }

  static String defaultEndpointFor(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => 'https://api.openai.com/v1/audio/speech',
      CloudTtsProvider.microsoftEdge =>
        'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1',
      CloudTtsProvider.elevenlabs =>
        'https://api.elevenlabs.io/v1/text-to-speech',
    };
  }

  static String defaultModelFor(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => 'gpt-4o-mini-tts',
      CloudTtsProvider.microsoftEdge => 'audio-24khz-48kbitrate-mono-mp3',
      CloudTtsProvider.elevenlabs => 'eleven_multilingual_v2',
    };
  }

  static String defaultVoiceFor(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => 'alloy',
      CloudTtsProvider.microsoftEdge => 'zh-CN-XiaoxiaoNeural',
      CloudTtsProvider.elevenlabs => '',
    };
  }
}
