import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:chibook/data/models/speech_settings.dart';
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

  Future<void> speak(String text) async {
    final config = await _loadConfig();
    if (config.providerMode != SpeechProviderMode.local && config.hasCloudConfig) {
      final ok = await _tryCloudSpeech(text, config);
      if (ok) {
        return;
      }
      if (config.providerMode == SpeechProviderMode.openai) {
        throw Exception('OpenAI TTS request failed. Please check your endpoint or API key.');
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
    if (config.providerMode != SpeechProviderMode.local && config.hasCloudConfig) {
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
        targetFile: cachedFile,
      );
      if (ok) {
        return;
      }
      if (config.providerMode == SpeechProviderMode.openai) {
        throw Exception('OpenAI TTS request failed. Please check your endpoint or API key.');
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
    if (config.providerMode == SpeechProviderMode.local || !config.hasCloudConfig) {
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
    if (!ok && config.providerMode == SpeechProviderMode.openai) {
      throw Exception('OpenAI TTS cache request failed.');
    }
  }

  Future<bool> hasCachedSegment({
    required String bookId,
    required String segmentId,
    required String text,
  }) async {
    final config = await _loadConfig();
    if (config.providerMode == SpeechProviderMode.local || !config.hasCloudConfig) {
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
    await _flutterTts.speak(text);
  }

  Future<bool> _tryCloudSpeech(
    String text,
    SpeechConfig config, {
    File? targetFile,
    bool autoplay = true,
  }) async {
    try {
      await _flutterTts.stop();
      final response = await _client.post(
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
    final providerModeName = prefs.getString('tts_provider_mode') ?? '';
    return SpeechConfig(
      providerMode: _parseMode(providerModeName),
      endpoint: prefs.getString('tts_endpoint') ?? '',
      apiKey: prefs.getString('tts_api_key') ?? '',
      model: prefs.getString('tts_model') ?? 'gpt-4o-mini-tts',
      voice: prefs.getString('tts_voice') ?? 'alloy',
      speed: prefs.getDouble('tts_speed') ?? 1.0,
      localSpeechRate: prefs.getDouble('tts_local_speech_rate') ?? 0.45,
    );
  }

  SpeechProviderMode _parseMode(String value) {
    for (final mode in SpeechProviderMode.values) {
      if (mode.name == value) return mode;
    }
    return SpeechProviderMode.auto;
  }

  Future<File> _uncachedAudioFile() async {
    final directory = await getTemporaryDirectory();
    return File(
      path.join(directory.path, 'speech_${DateTime.now().microsecondsSinceEpoch}.mp3'),
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
    await _audioPlayer.play(DeviceFileSource(file.path, mimeType: 'audio/mpeg'));
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
    required this.endpoint,
    required this.apiKey,
    required this.model,
    required this.voice,
    required this.speed,
    required this.localSpeechRate,
  });

  final SpeechProviderMode providerMode;
  final String endpoint;
  final String apiKey;
  final String model;
  final String voice;
  final double speed;
  final double localSpeechRate;

  bool get hasCloudConfig => endpoint.isNotEmpty && apiKey.isNotEmpty;
}
