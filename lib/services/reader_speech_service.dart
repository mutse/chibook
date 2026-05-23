import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chibook/data/models/speech_settings.dart';
import 'package:chibook/services/entitlement_service.dart';
import 'package:chibook/services/edge_tts/edge_tts_voices.dart';
import 'package:chibook/services/speech_cache_service.dart';
import 'package:chibook/services/speech_playback_service.dart';
import 'package:chibook/services/speech_settings_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ReaderSpeechService {
  ReaderSpeechService({
    FlutterTts? flutterTts,
    http.Client? client,
    SpeechSettingsService? speechSettingsService,
    SpeechCacheService? speechCacheService,
    SpeechPlaybackService? speechPlaybackService,
    EntitlementService? entitlementService,
  })  : _flutterTts = flutterTts ?? FlutterTts(),
        _client = client ?? http.Client(),
        _speechSettingsService = speechSettingsService ?? SpeechSettingsService(),
        _speechCacheService = speechCacheService,
        _speechPlaybackService = speechPlaybackService ?? SpeechPlaybackService(),
        _entitlementService = entitlementService ?? EntitlementService() {
    _configurePlaybackCallbacks();
  }

  final FlutterTts _flutterTts;
  final http.Client _client;
  final SpeechSettingsService _speechSettingsService;
  final SpeechCacheService? _speechCacheService;
  final SpeechPlaybackService _speechPlaybackService;
  final EntitlementService _entitlementService;

  Completer<void>? _playbackCompleter;
  Object? _activePlaybackToken;
  StreamSubscription<void>? _completionSubscription;

  static const List<String> openAiVoices = [
    'alloy',
    'ash',
    'ballad',
    'coral',
    'echo',
    'fable',
    'onyx',
    'nova',
    'sage',
    'shimmer',
    'verse',
  ];

  static const List<String> elevenLabsModels = [
    'eleven_multilingual_v2',
    'eleven_turbo_v2_5',
    'eleven_flash_v2_5',
    'eleven_v3',
  ];

  static const List<String> edgePreviewVoices = EdgeTtsVoices.previewVoices;

  Future<void> speak(String text) async {
    final config = await _loadConfig();
    if (config.providerMode != SpeechProviderMode.local &&
        config.hasCloudConfig) {
      final ok = await _tryCloudSpeech(
        text,
        config,
        bookId: 'preview',
        segmentId: 'preview',
        segmentLabel: 'Preview',
      );
      if (ok) {
        return;
      }
      if (config.providerMode == SpeechProviderMode.cloud) {
        throw Exception(_cloudFailureMessage(config));
      }
    }
    await _speakLocally(text);
  }

  Future<void> speakCachedSegment({
    required String bookId,
    required String segmentId,
    required String text,
  }) async {
    final config = await _loadConfig();
    if (config.providerMode != SpeechProviderMode.local &&
        config.hasCloudConfig &&
        _speechCacheService != null) {
      final cachedFile = await _cachedAudioFile(
        bookId: bookId,
        segmentId: segmentId,
        text: text,
        config: config,
      );
      if (await cachedFile.exists()) {
        await _playCachedFile(cachedFile);
        return;
      }

      final ok = await _tryCloudSpeech(
        text,
        config,
        bookId: bookId,
        segmentId: segmentId,
        segmentLabel: segmentId,
        targetFile: cachedFile,
      );
      if (ok) {
        return;
      }
      if (config.providerMode == SpeechProviderMode.cloud) {
        throw Exception(_cloudFailureMessage(config));
      }
    }
    await _speakLocally(text);
  }

  Future<void> cacheSegment({
    required String bookId,
    required String segmentId,
    required String text,
  }) async {
    final config = await _loadConfig();
    if (config.providerMode == SpeechProviderMode.local ||
        !config.hasCloudConfig ||
        _speechCacheService == null) {
      return;
    }

    final cachedFile = await _cachedAudioFile(
      bookId: bookId,
      segmentId: segmentId,
      text: text,
      config: config,
    );
    if (await cachedFile.exists()) {
      return;
    }
    final ok = await _tryCloudSpeech(
      text,
      config,
      bookId: bookId,
      segmentId: segmentId,
      segmentLabel: segmentId,
      targetFile: cachedFile,
      autoplay: false,
    );
    if (!ok && config.providerMode == SpeechProviderMode.cloud) {
      throw Exception('${config.cloudProviderLabel} TTS cache request failed.');
    }
  }

  Future<bool> hasCachedSegment({
    required String bookId,
    required String segmentId,
    required String text,
  }) async {
    final config = await _loadConfig();
    if (config.providerMode == SpeechProviderMode.local ||
        !config.hasCloudConfig ||
        _speechCacheService == null) {
      return false;
    }
    final file = await _cachedAudioFile(
      bookId: bookId,
      segmentId: segmentId,
      text: text,
      config: config,
    );
    return file.exists();
  }

  Future<void> pause() async {
    await _speechPlaybackService.pause();
    await _flutterTts.pause();
  }

  Future<void> stop() async {
    _cancelTrackedPlayback();
    await _speechPlaybackService.stop();
    await _flutterTts.stop();
  }

  Future<void> resume() async {
    await _speechPlaybackService.resume();
  }

  Future<void> _speakLocally(String text) async {
    final config = await _loadConfig();
    _cancelTrackedPlayback();
    await _speechPlaybackService.stop();
    await _flutterTts.setSpeechRate(config.localSpeechRate);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
    if (config.localVoiceId.isNotEmpty) {
      await _setLocalVoiceById(config.localVoiceId);
    }
    await _runTrackedPlayback(() => _flutterTts.speak(text));
  }

  Future<List<LocalVoiceOption>> listLocalVoices() async {
    try {
      final voicesRaw = await _flutterTts.getVoices;
      if (voicesRaw is! List) return const [];
      final voices = <LocalVoiceOption>[];
      for (final item in voicesRaw) {
        if (item is! Map) continue;
        final normalized = Map<String, dynamic>.from(item);
        final id = _readVoiceField(normalized, ['name', 'identifier', 'id']);
        if (id.isEmpty) continue;
        voices.add(
          LocalVoiceOption(
            id: id,
            name: _readVoiceField(normalized, [
              'displayName',
              'name',
              'identifier',
              'id',
            ]),
            locale: _readVoiceField(normalized, ['locale']),
            gender: _readVoiceField(normalized, ['gender', 'sex']),
          ),
        );
      }
      voices.sort((a, b) => a.label.compareTo(b.label));
      return voices;
    } catch (_) {
      return const [];
    }
  }

  Future<List<CloudVoiceOption>> listElevenLabsVoices({
    required String apiKey,
    required String endpoint,
  }) async {
    final normalizedApiKey = _normalizeApiKey(apiKey);
    if (normalizedApiKey.isEmpty) {
      return const [];
    }

    final voicesEndpoint = _elevenLabsVoicesUri(endpoint);
    final response = await _client.get(
      voicesEndpoint,
      headers: {
        'xi-api-key': normalizedApiKey,
        'Accept': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to load ElevenLabs voices (${response.statusCode}): ${_extractErrorMessage(response.body)}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];
    final voicesRaw = decoded['voices'];
    if (voicesRaw is! List) return const [];

    final voices = voicesRaw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => CloudVoiceOption(
            id: item['voice_id']?.toString().trim() ?? '',
            name: item['name']?.toString().trim() ?? '',
            category: item['category']?.toString().trim() ?? '',
          ),
        )
        .where((voice) => voice.id.isNotEmpty)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return voices;
  }

  Future<List<CloudVoiceOption>> listEdgeVoices({
    required String endpoint,
    String apiKey = '',
  }) async {
    final normalizedApiKey = _normalizeApiKey(apiKey);
    if (normalizedApiKey.isEmpty) {
      return edgePreviewVoices
          .map(
            (voice) => CloudVoiceOption(
              id: voice,
              name: voice,
              category: 'Preview',
            ),
          )
          .toList(growable: false);
    }
    final response = await _client.get(
      _azureVoicesUri(endpoint),
      headers: {
        'Ocp-Apim-Subscription-Key': normalizedApiKey,
        'Accept': 'application/json',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to load Azure Speech voices (${response.statusCode}): ${_extractErrorMessage(response.body)}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final voices = decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => CloudVoiceOption(
            id: item['ShortName']?.toString().trim() ?? '',
            name: item['DisplayName']?.toString().trim() ?? '',
            category: [
              item['Locale']?.toString().trim() ?? '',
              item['Gender']?.toString().trim() ?? '',
            ].where((value) => value.isNotEmpty).join(' · '),
          ),
        )
        .where((voice) => voice.id.isNotEmpty)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return voices;
  }

  Future<void> _setLocalVoiceById(String voiceId) async {
    final voicesRaw = await _flutterTts.getVoices;
    if (voicesRaw is! List) return;
    for (final item in voicesRaw) {
      if (item is! Map) continue;
      final normalized = Map<String, dynamic>.from(item);
      final id = _readVoiceField(normalized, ['name', 'identifier', 'id']);
      if (id != voiceId) continue;
      await _flutterTts.setVoice({
        'name': _readVoiceField(normalized, ['name', 'displayName', 'id']),
        'locale': _readVoiceField(normalized, ['locale']),
      });
      return;
    }
  }

  String _readVoiceField(Map<String, dynamic> voice, List<String> keys) {
    for (final key in keys) {
      final value = voice[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Future<bool> _tryCloudSpeech(
    String text,
    SpeechConfig config, {
    required String bookId,
    required String segmentId,
    required String segmentLabel,
    File? targetFile,
    bool autoplay = true,
  }) async {
    try {
      await _flutterTts.stop();
      final audioBytes = switch (config.cloudProvider) {
        CloudTtsProvider.openai => await _postOpenAiSpeech(text, config),
        CloudTtsProvider.azureSpeech => await _postAzureSpeech(text, config),
        CloudTtsProvider.microsoftEdge => await _postAzureSpeech(text, config),
        CloudTtsProvider.elevenlabs => await _postElevenLabsSpeech(text, config),
      };
      if (audioBytes.isEmpty) {
        return false;
      }

      final file = targetFile ?? await _uncachedAudioFile();
      await file.writeAsBytes(audioBytes, flush: true);
      final speechCacheService = _speechCacheService;
      if (speechCacheService != null && targetFile != null) {
        await speechCacheService.registerCacheFile(
          bookId: bookId,
          segmentId: segmentId,
          segmentLabel: segmentLabel,
          providerName: config.cloudProviderLabel,
          file: file,
        );
      }
      if (autoplay) {
        await _playCachedFile(file);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SpeechConfig> _loadConfig() async {
    final settings = await _speechSettingsService.load();
    final isProUnlocked = await _entitlementService.isProUnlocked();
    return SpeechConfig(
      providerMode: isProUnlocked
          ? settings.providerMode
          : SpeechProviderMode.local,
      cloudProvider: settings.cloudProvider,
      endpoint: settings.endpoint,
      apiKey: settings.apiKey,
      model: settings.model,
      voice: settings.voice,
      localVoiceId: settings.localVoiceId,
      speed: settings.speed,
      localSpeechRate: settings.localSpeechRate,
    );
  }

  Future<Uint8List> _postOpenAiSpeech(
    String text,
    SpeechConfig config,
  ) async {
    final response = await _client.post(
      Uri.parse(config.endpoint),
      headers: {
        'Authorization': 'Bearer ${_normalizeApiKey(config.apiKey)}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': config.model,
        'voice': config.voice,
        'input': text,
        'speed': config.speed,
        'response_format': 'mp3',
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response.body));
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<Uint8List> _postElevenLabsSpeech(
    String text,
    SpeechConfig config,
  ) async {
    final voiceId = _resolveElevenLabsVoiceId(config);
    if (voiceId.isEmpty) {
      throw Exception('ElevenLabs voice ID is required.');
    }

    final baseEndpoint = _resolveElevenLabsEndpoint(config.endpoint);
    final endpoint = '$baseEndpoint/$voiceId';

    final uri = Uri.parse(endpoint).replace(
      queryParameters: {
        ...Uri.parse(endpoint).queryParameters,
        'output_format': 'mp3_44100_128',
      },
    );

    final response = await _client.post(
      uri,
      headers: {
        'xi-api-key': _normalizeApiKey(config.apiKey),
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      },
      body: jsonEncode({
        'text': text,
        'model_id': config.model,
        'voice_settings': {
          'speed': config.speed,
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response.body));
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Future<Uint8List> _postAzureSpeech(
    String text,
    SpeechConfig config,
  ) async {
    final tokenResponse = await _client.post(
      _azureTokenUri(config.endpoint),
      headers: {
        'Ocp-Apim-Subscription-Key': _normalizeApiKey(config.apiKey),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    );
    if (tokenResponse.statusCode < 200 || tokenResponse.statusCode >= 300) {
      throw Exception(_extractErrorMessage(tokenResponse.body));
    }
    final token = tokenResponse.body.trim();
    final voice = SpeechSettings.normalizeVoiceFor(
      CloudTtsProvider.azureSpeech,
      config.voice,
    );
    final rate = _azureRate(config.speed);
    final ssml = '''
<speak version="1.0" xml:lang="en-US">
  <voice name="$voice">
    <prosody rate="$rate">$text</prosody>
  </voice>
</speak>
''';
    final response = await _client.post(
      Uri.parse(config.endpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': SpeechSettings.normalizeModelFor(
          CloudTtsProvider.azureSpeech,
          config.model,
        ),
        'User-Agent': 'Chibook',
      },
      body: ssml,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response.body));
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Uri _elevenLabsVoicesUri(String endpoint) {
    final baseEndpoint = _resolveElevenLabsEndpoint(endpoint);
    final uri = Uri.parse(baseEndpoint);
    return uri.replace(path: '/v2/voices', queryParameters: null);
  }

  String _resolveElevenLabsEndpoint(String endpoint) {
    return SpeechSettings.normalizeEndpointFor(
      CloudTtsProvider.elevenlabs,
      endpoint,
    );
  }

  String _resolveElevenLabsVoiceId(SpeechConfig config) {
    final configuredVoice = config.voice.trim();
    if (configuredVoice.isNotEmpty) {
      return configuredVoice;
    }

    final endpoint = config.endpoint.trim();
    if (endpoint.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(endpoint);
    if (uri == null) {
      return '';
    }

    final segments = uri.pathSegments;
    final speechIndex = segments.indexOf('text-to-speech');
    if (speechIndex == -1 || speechIndex + 1 >= segments.length) {
      return '';
    }

    final voiceId = segments[speechIndex + 1].trim();
    if (voiceId.isEmpty || voiceId == '{voice_id}') {
      return '';
    }
    return voiceId;
  }

  String _azureRate(double speed) {
    final delta = ((speed - 1.0) * 100).round().clamp(-100, 100);
    return '${delta >= 0 ? '+' : ''}$delta%';
  }

  Uri _azureTokenUri(String endpoint) {
    final speechUri = Uri.parse(
      SpeechSettings.normalizeEndpointFor(
        CloudTtsProvider.azureSpeech,
        endpoint,
      ),
    );
    final host = speechUri.host.endsWith('.tts.speech.microsoft.com')
        ? speechUri.host.replaceFirst(
            '.tts.speech.microsoft.com',
            '.api.cognitive.microsoft.com',
          )
        : '${speechUri.host}.api.cognitive.microsoft.com';
    return Uri.https(host, '/sts/v1.0/issueToken');
  }

  Uri _azureVoicesUri(String endpoint) {
    final speechUri = Uri.parse(
      SpeechSettings.normalizeEndpointFor(
        CloudTtsProvider.azureSpeech,
        endpoint,
      ),
    );
    return speechUri.replace(path: '/cognitiveservices/voices/list');
  }

  String _normalizeApiKey(String raw) {
    var value = raw.trim();
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      value = value.substring(1, value.length - 1).trim();
    }
    value = value.replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    );
    value = value.replaceFirst(
      RegExp(r'^Authorization\s*:\s*Bearer\s+', caseSensitive: false),
      '',
    );
    value = value.replaceFirst(
      RegExp(
        r'^Ocp-Apim-Subscription-Key\b\s*:?\s*',
        caseSensitive: false,
      ),
      '',
    );
    value = value.replaceFirst(
      RegExp(r'^xi-api-key\b\s*:?\s*', caseSensitive: false),
      '',
    );
    return value.trim();
  }

  String _extractErrorMessage(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString().trim() ?? '';
        if (message.isNotEmpty) return message;
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
        if (detail is Map<String, dynamic>) {
          final message = detail['message']?.toString().trim() ?? '';
          if (message.isNotEmpty) return message;
        }
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message']?.toString().trim() ?? '';
          if (message.isNotEmpty) return message;
        }
      }
    } catch (_) {
      final text = responseBody.trim();
      if (text.isNotEmpty) return text;
    }
    return 'Unknown error';
  }

  String _cloudFailureMessage(SpeechConfig config) {
    return switch (config.cloudProvider) {
      CloudTtsProvider.openai =>
        'OpenAI TTS request failed. Please check your endpoint, voice and API key.',
      CloudTtsProvider.azureSpeech =>
        'Azure Speech request failed. Please check your region endpoint, voice and API key.',
      CloudTtsProvider.microsoftEdge =>
        'Azure Speech request failed. Please check your region endpoint, voice and API key.',
      CloudTtsProvider.elevenlabs =>
        'ElevenLabs TTS request failed. Please check your endpoint, voice and API key.',
    };
  }

  Future<File> _uncachedAudioFile() async {
    final directory = await getTemporaryDirectory();
    return File(
      path.join(
        directory.path,
        'speech_${DateTime.now().microsecondsSinceEpoch}.mp3',
      ),
    );
  }

  Future<File> _cachedAudioFile({
    required String bookId,
    required String segmentId,
    required String text,
    required SpeechConfig config,
  }) async {
    final speechCacheService = _speechCacheService;
    if (speechCacheService == null) {
      return _uncachedAudioFile();
    }
    final hash = _cacheKey(
      '$segmentId|${config.model}|${config.voice}|${config.speed}|$text',
    );
    return speechCacheService.cachedFile(
      bookId: bookId,
      fileName: '${_safeSlug(segmentId)}_$hash.mp3',
    );
  }

  Future<void> _playCachedFile(File file) async {
    _cancelTrackedPlayback();
    await _speechPlaybackService.stop();
    await _runTrackedPlayback(
      () => _speechPlaybackService.playFile(file),
    );
  }

  void _configurePlaybackCallbacks() {
    _flutterTts.setCompletionHandler(_completeTrackedPlayback);
    _flutterTts.setCancelHandler(_cancelTrackedPlayback);
    _flutterTts.setPauseHandler(() {});
    _flutterTts.setContinueHandler(() {});
    _flutterTts.setErrorHandler((error) {
      _failTrackedPlayback(Exception(error));
    });
    _completionSubscription =
        _speechPlaybackService.onPlaybackCompleted.listen((_) {
      _completeTrackedPlayback();
    });
  }

  Future<void> _runTrackedPlayback(Future<dynamic> Function() starter) async {
    final token = Object();
    final completer = Completer<void>();
    _activePlaybackToken = token;
    _playbackCompleter = completer;
    try {
      await starter();
      await completer.future;
    } catch (error) {
      if (identical(_activePlaybackToken, token) && !completer.isCompleted) {
        completer.completeError(error);
      }
      rethrow;
    } finally {
      if (identical(_activePlaybackToken, token)) {
        _activePlaybackToken = null;
        _playbackCompleter = null;
      }
    }
  }

  void _completeTrackedPlayback() {
    final completer = _playbackCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.complete();
  }

  void _cancelTrackedPlayback() {
    final completer = _playbackCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.complete();
    _playbackCompleter = null;
    _activePlaybackToken = null;
  }

  void _failTrackedPlayback(Object error) {
    final completer = _playbackCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.completeError(error);
    _playbackCompleter = null;
    _activePlaybackToken = null;
  }

  String _cacheKey(String input) {
    var hash = 0x811c9dc5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _safeSlug(String input) {
    final sanitized = input.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    return sanitized.length > 32 ? sanitized.substring(0, 32) : sanitized;
  }

  Future<void> dispose() async {
    await _completionSubscription?.cancel();
    await _speechPlaybackService.dispose();
    _client.close();
  }
}

class SpeechConfig {
  const SpeechConfig({
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

  final SpeechProviderMode providerMode;
  final CloudTtsProvider cloudProvider;
  final String endpoint;
  final String apiKey;
  final String model;
  final String voice;
  final String localVoiceId;
  final double speed;
  final double localSpeechRate;

  String get cloudProviderLabel {
    return switch (cloudProvider) {
      CloudTtsProvider.openai => 'OpenAI',
      CloudTtsProvider.azureSpeech => 'Azure Speech',
      CloudTtsProvider.microsoftEdge => 'Azure Speech',
      CloudTtsProvider.elevenlabs => 'ElevenLabs',
    };
  }

  bool get hasCloudConfig {
    return switch (cloudProvider) {
      CloudTtsProvider.openai => endpoint.isNotEmpty && apiKey.isNotEmpty,
      CloudTtsProvider.azureSpeech => endpoint.isNotEmpty && apiKey.isNotEmpty,
      CloudTtsProvider.microsoftEdge =>
        endpoint.isNotEmpty && apiKey.isNotEmpty,
      CloudTtsProvider.elevenlabs => endpoint.isNotEmpty && apiKey.isNotEmpty,
    };
  }
}

class LocalVoiceOption {
  const LocalVoiceOption({
    required this.id,
    required this.name,
    required this.locale,
    required this.gender,
  });

  final String id;
  final String name;
  final String locale;
  final String gender;

  String get label {
    final parts = <String>[
      if (name.isNotEmpty) name else id,
      if (locale.isNotEmpty) locale,
      if (gender.isNotEmpty) gender,
    ];
    return parts.join(' · ');
  }
}

class CloudVoiceOption {
  const CloudVoiceOption({
    required this.id,
    required this.name,
    required this.category,
  });

  final String id;
  final String name;
  final String category;

  String get label {
    if (category.isEmpty) {
      return name.isEmpty ? id : name;
    }
    final displayName = name.isEmpty ? id : name;
    return '$displayName · $category';
  }
}
