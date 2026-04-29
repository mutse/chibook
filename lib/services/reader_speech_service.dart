import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:chibook/data/models/speech_settings.dart';
import 'package:chibook/services/edge_tts/edge_tts_client.dart';
import 'package:chibook/services/edge_tts/edge_tts_voices.dart';
import 'package:chibook/services/edge_tts/models.dart';
import 'package:chibook/services/speech_settings_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderSpeechService {
  ReaderSpeechService({
    FlutterTts? flutterTts,
    http.Client? client,
    AudioPlayer? audioPlayer,
    EdgeTtsClient? edgeTtsClient,
  })  : _flutterTts = flutterTts ?? FlutterTts(),
        _client = client ?? http.Client(),
        _audioPlayer = audioPlayer ?? AudioPlayer(),
        _edgeTtsClient = edgeTtsClient ?? EdgeTtsClient(httpClient: client) {
    _configurePlaybackCallbacks();
  }

  final FlutterTts _flutterTts;
  final http.Client _client;
  final AudioPlayer _audioPlayer;
  final EdgeTtsClient _edgeTtsClient;
  Completer<void>? _playbackCompleter;
  Object? _activePlaybackToken;

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
      final ok = await _tryCloudSpeech(text, config);
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
        config.hasCloudConfig) {
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

      final ok = await _tryCloudSpeech(text, config, targetFile: cachedFile);
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
        !config.hasCloudConfig) {
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
        !config.hasCloudConfig) {
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
    await _audioPlayer.pause();
    await _flutterTts.pause();
  }

  Future<void> stop() async {
    _cancelTrackedPlayback();
    await _audioPlayer.stop();
    await _flutterTts.stop();
  }

  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  Future<void> _speakLocally(String text) async {
    final config = await _loadConfig();
    _cancelTrackedPlayback();
    await _audioPlayer.stop();
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
  }) async {
    final voices = await _edgeTtsClient.listVoices(endpoint: endpoint);
    return voices
        .map(
          (voice) => CloudVoiceOption(
            id: voice.id,
            name: voice.name,
            category: [
              voice.locale,
              voice.gender,
            ].where((value) => value.isNotEmpty).join(' · '),
          ),
        )
        .toList();
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
    File? targetFile,
    bool autoplay = true,
  }) async {
    try {
      await _flutterTts.stop();
      final audioBytes = switch (config.cloudProvider) {
        CloudTtsProvider.openai => await _postOpenAiSpeech(text, config),
        CloudTtsProvider.microsoftEdge =>
          await _postMicrosoftEdgeSpeech(text, config),
        CloudTtsProvider.elevenlabs =>
          await _postElevenLabsSpeech(text, config),
      };
      if (audioBytes.isEmpty) {
        return false;
      }

      final file = targetFile ?? await _uncachedAudioFile();
      await file.writeAsBytes(audioBytes, flush: true);
      if (autoplay) {
        await _playCachedFile(file);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SpeechConfig> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final providerModeName =
        prefs.getString(SpeechSettingsStorageKeys.providerMode) ??
            prefs.getString(SpeechSettingsStorageKeys.legacyProviderMode) ??
            '';
    final cloudProvider = _parseCloudProvider(
          prefs.getString(SpeechSettingsStorageKeys.cloudProvider) ??
              prefs.getString(SpeechSettingsStorageKeys.legacyCloudProvider),
        ) ??
        CloudTtsProvider.microsoftEdge;
    return SpeechConfig(
      providerMode: _parseMode(providerModeName),
      cloudProvider: cloudProvider,
      endpoint: SpeechSettings.normalizeEndpointFor(
        cloudProvider,
        prefs.getString(SpeechSettingsStorageKeys.endpoint) ??
            prefs.getString(SpeechSettingsStorageKeys.legacyEndpoint) ??
            '',
      ),
      apiKey: prefs.getString(SpeechSettingsStorageKeys.apiKey) ??
          prefs.getString(SpeechSettingsStorageKeys.legacyApiKey) ??
          '',
      model: SpeechSettings.normalizeModelFor(
        cloudProvider,
        prefs.getString(SpeechSettingsStorageKeys.model) ??
            prefs.getString(SpeechSettingsStorageKeys.legacyModel) ??
            SpeechSettings.defaultModelFor(cloudProvider),
      ),
      voice: SpeechSettings.normalizeVoiceFor(
        cloudProvider,
        prefs.getString(SpeechSettingsStorageKeys.voice) ??
            prefs.getString(SpeechSettingsStorageKeys.legacyVoice) ??
            SpeechSettings.defaultVoiceFor(cloudProvider),
      ),
      localVoiceId: prefs.getString(SpeechSettingsStorageKeys.localVoiceId) ??
          prefs.getString(SpeechSettingsStorageKeys.legacyLocalVoiceId) ??
          '',
      speed: prefs.getDouble(SpeechSettingsStorageKeys.speed) ??
          prefs.getDouble(SpeechSettingsStorageKeys.legacySpeed) ??
          1.0,
      localSpeechRate:
          prefs.getDouble(SpeechSettingsStorageKeys.localSpeechRate) ??
              prefs.getDouble(
                SpeechSettingsStorageKeys.legacyLocalSpeechRate,
              ) ??
              0.45,
    );
  }

  SpeechProviderMode _parseMode(String value) {
    if (value == 'openai') return SpeechProviderMode.cloud;
    for (final mode in SpeechProviderMode.values) {
      if (mode.name == value) return mode;
    }
    return SpeechProviderMode.auto;
  }

  CloudTtsProvider? _parseCloudProvider(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final provider in CloudTtsProvider.values) {
      if (provider.name == value) return provider;
    }
    return null;
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

  Future<Uint8List> _postMicrosoftEdgeSpeech(
    String text,
    SpeechConfig config,
  ) async {
    return _edgeTtsClient.synthesize(
      text,
      TtsConfig(
        voice: SpeechSettings.normalizeVoiceFor(
          CloudTtsProvider.microsoftEdge,
          config.voice,
        ),
        rate: _edgeRate(config.speed),
        outputFormat: SpeechSettings.normalizeModelFor(
          CloudTtsProvider.microsoftEdge,
          config.model,
        ),
      ),
      endpoint: config.endpoint,
    );
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

  String _edgeRate(double speed) {
    final delta = ((speed - 1.0) * 100).round().clamp(-100, 100);
    return '${delta >= 0 ? '+' : ''}$delta%';
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
      RegExp(r'^Ocp-Apim-Subscription-Key\s*:\s*', caseSensitive: false),
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
      CloudTtsProvider.microsoftEdge =>
        'Microsoft Edge TTS request failed. Please check your endpoint and voice.',
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
    final baseDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(path.join(baseDir.path, 'audio_cache', bookId));
    if (!cacheDir.existsSync()) {
      await cacheDir.create(recursive: true);
    }

    final hash = _cacheKey(
      '$segmentId|${config.model}|${config.voice}|${config.speed}|$text',
    );
    return File(path.join(cacheDir.path, '${_safeSlug(segmentId)}_$hash.mp3'));
  }

  Future<void> _playCachedFile(File file) async {
    _cancelTrackedPlayback();
    await _audioPlayer.stop();
    await _runTrackedPlayback(
      () => _audioPlayer.play(
        DeviceFileSource(file.path, mimeType: 'audio/mpeg'),
      ),
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
    _audioPlayer.onPlayerComplete.listen((_) => _completeTrackedPlayback());
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
      CloudTtsProvider.microsoftEdge => 'Microsoft Edge',
      CloudTtsProvider.elevenlabs => 'ElevenLabs',
    };
  }

  bool get hasCloudConfig {
    return switch (cloudProvider) {
      CloudTtsProvider.openai => endpoint.isNotEmpty && apiKey.isNotEmpty,
      CloudTtsProvider.microsoftEdge => endpoint.isNotEmpty,
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
