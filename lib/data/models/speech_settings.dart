enum SpeechProviderMode { auto, openai, local }

class SpeechSettings {
  const SpeechSettings({
    required this.providerMode,
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
  final String endpoint;
  final String apiKey;
  final String model;
  final String voice;
  final String localVoiceId;
  final double speed;
  final double localSpeechRate;

  bool get hasCloudConfig => endpoint.isNotEmpty && apiKey.isNotEmpty;

  SpeechSettings copyWith({
    SpeechProviderMode? providerMode,
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
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      voice: voice ?? this.voice,
      localVoiceId: localVoiceId ?? this.localVoiceId,
      speed: speed ?? this.speed,
      localSpeechRate: localSpeechRate ?? this.localSpeechRate,
    );
  }
}
