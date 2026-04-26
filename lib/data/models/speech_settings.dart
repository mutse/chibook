enum SpeechProviderMode { auto, cloud, local }

enum CloudTtsProvider { openai, microsoftEdge, elevenlabs }

class SpeechSettings {
  static final RegExp _edgeVoicePattern = RegExp(
    r'^[a-z]{2,3}-[A-Za-z]{2,4}-.+Neural$',
    caseSensitive: false,
  );
  static final RegExp _edgeVoiceDisplayNamePattern = RegExp(
    r'^Microsoft Server Speech Text to Speech Voice \(([^,]+),\s*([^)]+)\)$',
    caseSensitive: false,
  );
  static final RegExp _edgeVoiceLocaleSeparatorPattern = RegExp(
    r'^([a-z]{2,3}-[A-Za-z]{2,4})[\s,_]+(.+Neural)$',
    caseSensitive: false,
  );
  static final RegExp _edgeOutputFormatPattern = RegExp(
    r'^audio-[a-z0-9-]+$',
    caseSensitive: false,
  );

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

  static String normalizeEndpointFor(
    CloudTtsProvider provider,
    String endpoint,
  ) {
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty) {
      return defaultEndpointFor(provider);
    }

    return switch (provider) {
      CloudTtsProvider.microsoftEdge =>
        _normalizeMicrosoftEdgeEndpoint(trimmed),
      _ => trimmed,
    };
  }

  static String normalizeModelFor(
    CloudTtsProvider provider,
    String model,
  ) {
    final trimmed = model.trim();
    if (trimmed.isEmpty) {
      return defaultModelFor(provider);
    }

    return switch (provider) {
      CloudTtsProvider.microsoftEdge
          when !_edgeOutputFormatPattern.hasMatch(trimmed) =>
        defaultModelFor(provider),
      _ => trimmed,
    };
  }

  static String normalizeVoiceFor(
    CloudTtsProvider provider,
    String voice,
  ) {
    final trimmed = voice.trim();
    if (trimmed.isEmpty) {
      return defaultVoiceFor(provider);
    }

    return switch (provider) {
      CloudTtsProvider.microsoftEdge => _normalizeMicrosoftEdgeVoice(trimmed),
      _ => trimmed,
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

  static String _normalizeMicrosoftEdgeEndpoint(String endpoint) {
    final candidate = endpoint.startsWith('speech.platform.bing.com')
        ? 'wss://$endpoint'
        : endpoint;
    final uri = Uri.tryParse(candidate);
    if (uri == null) {
      return defaultEndpointFor(CloudTtsProvider.microsoftEdge);
    }

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final isKnownMicrosoftSpeechHost = host == 'speech.platform.bing.com' ||
        host.endsWith('.tts.speech.microsoft.com') ||
        host.endsWith('.speech.microsoft.com');

    if (isKnownMicrosoftSpeechHost &&
        (host != 'speech.platform.bing.com' ||
            path.contains('/cognitiveservices/') ||
            path.contains('/consumer/speech/synthesize/readaloud'))) {
      return defaultEndpointFor(CloudTtsProvider.microsoftEdge);
    }

    return candidate;
  }

  static String _normalizeMicrosoftEdgeVoice(String voice) {
    var normalized = voice.trim();
    if (normalized.startsWith('"') &&
        normalized.endsWith('"') &&
        normalized.length >= 2) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }

    final displayNameMatch = _edgeVoiceDisplayNamePattern.firstMatch(
      normalized,
    );
    if (displayNameMatch != null) {
      normalized =
          '${displayNameMatch.group(1)!.trim()}-${displayNameMatch.group(2)!.trim()}';
    }

    final localeSeparatorMatch = _edgeVoiceLocaleSeparatorPattern.firstMatch(
      normalized,
    );
    if (localeSeparatorMatch != null) {
      normalized =
          '${localeSeparatorMatch.group(1)!.trim()}-${localeSeparatorMatch.group(2)!.trim()}';
    }

    normalized = normalized.replaceAll(' ', '');
    if (_edgeVoicePattern.hasMatch(normalized)) {
      return normalized;
    }

    return defaultVoiceFor(CloudTtsProvider.microsoftEdge);
  }
}
