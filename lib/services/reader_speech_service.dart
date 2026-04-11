import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:chibook/data/models/speech_settings.dart';
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
  })  : _flutterTts = flutterTts ?? FlutterTts(),
        _client = client ?? http.Client(),
        _audioPlayer = audioPlayer ?? AudioPlayer();

  final FlutterTts _flutterTts;
  final http.Client _client;
  final AudioPlayer _audioPlayer;

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

  Future<void> speak(String text) async {
    final config = await _loadConfig();
    if (config.providerMode != SpeechProviderMode.local &&
        config.hasCloudConfig) {
      final ok = await _tryCloudSpeech(text, config);
      if (ok) {
        return;
      }
      if (config.providerMode == SpeechProviderMode.cloud) {
        throw Exception(
          '${config.cloudProviderLabel} TTS request failed. Please check your endpoint, voice and API key.',
        );
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
        throw Exception(
          '${config.cloudProviderLabel} TTS request failed. Please check your endpoint, voice and API key.',
        );
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
    await _audioPlayer.stop();
    await _flutterTts.stop();
  }

  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  Future<void> _speakLocally(String text) async {
    final config = await _loadConfig();
    await _audioPlayer.stop();
    await _flutterTts.setSpeechRate(config.localSpeechRate);
    await _flutterTts.setPitch(1.0);
    if (config.localVoiceId.isNotEmpty) {
      await _setLocalVoiceById(config.localVoiceId);
    }
    await _flutterTts.speak(text);
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
    final normalizedApiKey = apiKey.trim();
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
          'Failed to load ElevenLabs voices (${response.statusCode}).');
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
      final response = switch (config.cloudProvider) {
        CloudTtsProvider.openai => await _postOpenAiSpeech(text, config),
        CloudTtsProvider.elevenlabs =>
          await _postElevenLabsSpeech(text, config),
      };

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final file = targetFile ?? await _uncachedAudioFile();
      await file.writeAsBytes(response.bodyBytes, flush: true);
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
        CloudTtsProvider.openai;
    return SpeechConfig(
      providerMode: _parseMode(providerModeName),
      cloudProvider: cloudProvider,
      endpoint: prefs.getString(SpeechSettingsStorageKeys.endpoint) ??
          prefs.getString(SpeechSettingsStorageKeys.legacyEndpoint) ??
          SpeechSettings.defaultEndpointFor(cloudProvider),
      apiKey: prefs.getString(SpeechSettingsStorageKeys.apiKey) ??
          prefs.getString(SpeechSettingsStorageKeys.legacyApiKey) ??
          '',
      model: prefs.getString(SpeechSettingsStorageKeys.model) ??
          prefs.getString(SpeechSettingsStorageKeys.legacyModel) ??
          SpeechSettings.defaultModelFor(cloudProvider),
      voice: prefs.getString(SpeechSettingsStorageKeys.voice) ??
          prefs.getString(SpeechSettingsStorageKeys.legacyVoice) ??
          SpeechSettings.defaultVoiceFor(cloudProvider),
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

  Future<http.Response> _postOpenAiSpeech(
    String text,
    SpeechConfig config,
  ) async {
    return _client.post(
      Uri.parse(config.endpoint),
      headers: {
        'Authorization': 'Bearer ${config.apiKey}',
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
  }

  Future<http.Response> _postElevenLabsSpeech(
    String text,
    SpeechConfig config,
  ) async {
    final voiceId = config.voice.trim();
    if (voiceId.isEmpty) {
      throw Exception('ElevenLabs voice ID is required.');
    }

    final baseEndpoint = config.endpoint.trim().isEmpty
        ? SpeechSettings.defaultEndpointFor(CloudTtsProvider.elevenlabs)
        : config.endpoint.trim();
    final endpoint = baseEndpoint.contains('{voice_id}')
        ? baseEndpoint.replaceAll('{voice_id}', voiceId)
        : '$baseEndpoint/$voiceId';

    final uri = Uri.parse(endpoint).replace(
      queryParameters: {
        ...Uri.parse(endpoint).queryParameters,
        'output_format': 'mp3_44100_128',
      },
    );

    return _client.post(
      uri,
      headers: {
        'xi-api-key': config.apiKey,
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
  }

  Uri _elevenLabsVoicesUri(String endpoint) {
    final baseEndpoint = endpoint.trim().isEmpty
        ? SpeechSettings.defaultEndpointFor(CloudTtsProvider.elevenlabs)
        : endpoint.trim();
    final uri = Uri.parse(baseEndpoint);
    return uri.replace(path: '/v2/voices', queryParameters: null);
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
    await _audioPlayer.stop();
    await _audioPlayer.play(
      DeviceFileSource(file.path, mimeType: 'audio/mpeg'),
    );
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

  bool get hasCloudConfig => endpoint.isNotEmpty && apiKey.isNotEmpty;

  String get cloudProviderLabel {
    return switch (cloudProvider) {
      CloudTtsProvider.openai => 'OpenAI',
      CloudTtsProvider.elevenlabs => 'ElevenLabs',
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
