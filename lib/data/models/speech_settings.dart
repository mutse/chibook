enum SpeechProviderMode { auto, cloud, local }

enum CloudTtsProvider { openai, azureSpeech, microsoftEdge, elevenlabs }

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
  static final RegExp _elevenLabsVoicePathPattern = RegExp(
    r'^(.*?/v1/text-to-speech)(?:/([^/?#]+)|/\{voice_id\})/?$',
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
      providerMode: SpeechProviderMode.local,
      cloudProvider: CloudTtsProvider.azureSpeech,
      endpoint: 'https://eastus.tts.speech.microsoft.com/cognitiveservices/v1',
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
      CloudTtsProvider.azureSpeech => endpoint.isNotEmpty && apiKey.isNotEmpty,
      CloudTtsProvider.microsoftEdge =>
        endpoint.isNotEmpty && apiKey.isNotEmpty,
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
      CloudTtsProvider.azureSpeech =>
        'https://eastus.tts.speech.microsoft.com/cognitiveservices/v1',
      CloudTtsProvider.microsoftEdge =>
        'https://eastus.tts.speech.microsoft.com/cognitiveservices/v1',
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
      CloudTtsProvider.azureSpeech => _normalizeAzureSpeechEndpoint(trimmed),
      CloudTtsProvider.microsoftEdge => _normalizeAzureSpeechEndpoint(trimmed),
      CloudTtsProvider.elevenlabs => _normalizeElevenLabsEndpoint(trimmed),
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
      CloudTtsProvider.azureSpeech
          when !_edgeOutputFormatPattern.hasMatch(trimmed) =>
        defaultModelFor(provider),
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
      CloudTtsProvider.azureSpeech => _normalizeAzureSpeechVoice(trimmed),
      CloudTtsProvider.microsoftEdge => _normalizeAzureSpeechVoice(trimmed),
      _ => trimmed,
    };
  }

  static String defaultModelFor(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => 'gpt-4o-mini-tts',
      CloudTtsProvider.azureSpeech => 'audio-24khz-48kbitrate-mono-mp3',
      CloudTtsProvider.microsoftEdge => 'audio-24khz-48kbitrate-mono-mp3',
      CloudTtsProvider.elevenlabs => 'eleven_multilingual_v2',
    };
  }

  static String defaultVoiceFor(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => 'alloy',
      CloudTtsProvider.azureSpeech => 'zh-CN-XiaoxiaoNeural',
      CloudTtsProvider.microsoftEdge => 'zh-CN-XiaoxiaoNeural',
      CloudTtsProvider.elevenlabs => '',
    };
  }

  static String _normalizeAzureSpeechEndpoint(String endpoint) {
    final candidate = endpoint.startsWith('eastus.tts.speech.microsoft.com')
        ? 'https://$endpoint'
        : endpoint;
    final uri = Uri.tryParse(candidate);
    if (uri == null) {
      return defaultEndpointFor(CloudTtsProvider.azureSpeech);
    }

    final host = uri.host.toLowerCase();
    final isAzureSpeechHost =
        host.endsWith('.tts.speech.microsoft.com') ||
            host.endsWith('.speech.microsoft.com');
    if (!isAzureSpeechHost) {
      return defaultEndpointFor(CloudTtsProvider.azureSpeech);
    }

    return candidate.endsWith('/cognitiveservices/v1')
        ? candidate
        : '${candidate.replaceAll(RegExp(r'/$'), '')}/cognitiveservices/v1';
  }

  static String _normalizeAzureSpeechVoice(String voice) {
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

    return defaultVoiceFor(CloudTtsProvider.azureSpeech);
  }

  static String _normalizeElevenLabsEndpoint(String endpoint) {
    final candidate = endpoint.startsWith('api.elevenlabs.io')
        ? 'https://$endpoint'
        : endpoint;
    final uri = Uri.tryParse(candidate);
    if (uri == null) {
      return defaultEndpointFor(CloudTtsProvider.elevenlabs);
    }

    final match = _elevenLabsVoicePathPattern.firstMatch(candidate);
    if (match != null) {
      return match.group(1)!;
    }

    return candidate.endsWith('/')
        ? candidate.substring(0, candidate.length - 1)
        : candidate;
  }
}
