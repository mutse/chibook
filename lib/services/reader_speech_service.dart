import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:chibook/data/models/speech_settings.dart';
import 'package:chibook/services/speech_settings_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
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
  final Random _random = Random.secure();

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

  static const List<String> edgePreviewVoices = [
    'zh-CN-XiaoxiaoNeural',
    'zh-CN-YunxiNeural',
    'zh-CN-XiaoyiNeural',
    'zh-HK-HiuGaaiNeural',
    'zh-TW-HsiaoChenNeural',
    'en-US-AriaNeural',
    'en-US-JennyNeural',
    'en-US-GuyNeural',
    'en-GB-SoniaNeural',
  ];

  static const _edgeTrustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const _edgeSecMsGecVersion = '1-143.0.3650.0';
  static const _edgeUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 '
      'Safari/537.36 Edg/143.0.3650.0';

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
    final response = await _client.get(
      _edgeVoicesUri(endpoint),
      headers: {
        'Accept': 'application/json',
        'User-Agent': _edgeUserAgent,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to load Microsoft Edge voices (${response.statusCode}): ${_extractErrorMessage(response.body)}',
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
            name: item['FriendlyName']?.toString().trim() ??
                item['ShortName']?.toString().trim() ??
                '',
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
    File? targetFile,
    bool autoplay = true,
  }) async {
    try {
      await _flutterTts.stop();
      final audioBytes = switch (config.cloudProvider) {
        CloudTtsProvider.openai => await _postOpenAiSpeech(text, config),
        CloudTtsProvider.microsoftEdge =>
          await _synthesizeMicrosoftEdgeSpeech(text, config),
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

  Future<Uint8List> _synthesizeMicrosoftEdgeSpeech(
    String text,
    SpeechConfig config,
  ) async {
    final chunks = _splitEdgeText(text);
    final output = BytesBuilder(copy: false);

    for (final chunk in chunks) {
      final audio = await _synthesizeMicrosoftEdgeChunk(chunk, config);
      if (audio.isNotEmpty) {
        output.add(audio);
      }
    }

    return output.takeBytes();
  }

  Future<Uint8List> _synthesizeMicrosoftEdgeChunk(
    String text,
    SpeechConfig config,
  ) async {
    final connectionId = _edgeRequestId();
    final endpoint = _edgeWebSocketUri(
      config.endpoint,
      connectionId: connectionId,
    );
    final requestId = _edgeRequestId();
    final audio = BytesBuilder(copy: false);
    final muid = _edgeMuid();

    final socket = await WebSocket.connect(
      endpoint.toString(),
      headers: {
        'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
        'User-Agent': _edgeUserAgent,
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Pragma': 'no-cache',
        'Cache-Control': 'no-cache',
        'Cookie': 'MUID=$muid; MUIDB=$muid',
      },
    );

    try {
      socket.add(_edgeSpeechConfig(config.model));
      socket.add(
        _edgeSsmlRequest(
          requestId: requestId,
          timestamp: _edgeTimestamp(),
          voice: config.voice.trim().isEmpty
              ? SpeechSettings.defaultVoiceFor(CloudTtsProvider.microsoftEdge)
              : config.voice.trim(),
          rate: _edgeRate(config.speed),
          text: text,
        ),
      );

      await for (final message in socket) {
        if (message is String) {
          final headerEnd = message.indexOf('\r\n\r\n');
          if (headerEnd == -1) continue;
          final headers = _parseHeaderLines(message.substring(0, headerEnd));
          if (headers['Path'] == 'turn.end') {
            break;
          }
          continue;
        }

        if (message is List<int>) {
          final bytes = Uint8List.fromList(message);
          if (bytes.length < 2) continue;
          final headerLength = (bytes[0] << 8) | bytes[1];
          if (headerLength >= bytes.length) continue;
          final headerBytes = bytes.sublist(2, 2 + headerLength);
          final body = bytes.sublist(2 + headerLength);
          final headers = _parseHeaderLines(utf8.decode(headerBytes));
          if (headers['Path'] == 'audio' && body.isNotEmpty) {
            audio.add(body);
          }
        }
      }
    } finally {
      await socket.close();
    }

    return _outputOrEmpty(audio);
  }

  Uri _elevenLabsVoicesUri(String endpoint) {
    final baseEndpoint = endpoint.trim().isEmpty
        ? SpeechSettings.defaultEndpointFor(CloudTtsProvider.elevenlabs)
        : endpoint.trim();
    final uri = Uri.parse(baseEndpoint);
    return uri.replace(path: '/v2/voices', queryParameters: null);
  }

  Uri _edgeVoicesUri(String endpoint) {
    final baseEndpoint = endpoint.trim().isEmpty
        ? SpeechSettings.defaultEndpointFor(CloudTtsProvider.microsoftEdge)
        : endpoint.trim();
    final uri =
        Uri.parse(baseEndpoint.replaceFirst(RegExp(r'^wss:'), 'https:'));
    return uri.replace(
      scheme: uri.scheme == 'wss' ? 'https' : uri.scheme,
      path: '/consumer/speech/synthesize/readaloud/voices/list',
      queryParameters: {
        'trustedclienttoken': _edgeTrustedClientToken,
      },
    );
  }

  Uri _edgeWebSocketUri(
    String endpoint, {
    required String connectionId,
  }) {
    final baseEndpoint = endpoint.trim().isEmpty
        ? SpeechSettings.defaultEndpointFor(CloudTtsProvider.microsoftEdge)
        : endpoint.trim();
    final uri = Uri.parse(baseEndpoint);
    final normalizedScheme = uri.scheme == 'https' ? 'wss' : uri.scheme;
    return uri.replace(
      scheme: normalizedScheme,
      path: '/consumer/speech/synthesize/readaloud/edge/v1',
      queryParameters: {
        'TrustedClientToken': _edgeTrustedClientToken,
        'ConnectionId': connectionId,
        'Sec-MS-GEC': _generateEdgeSecMsGec(),
        'Sec-MS-GEC-Version': _edgeSecMsGecVersion,
      },
    );
  }

  String _edgeSpeechConfig(String outputFormat) {
    return 'X-Timestamp:${_edgeDateHeader()}\r\n'
        'Content-Type:application/json; charset=utf-8\r\n'
        'Path:speech.config\r\n\r\n'
        '{"context":{"synthesis":{"audio":{"metadataoptions":{'
        '"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"'
        '},"outputFormat":"${outputFormat.trim().isEmpty ? SpeechSettings.defaultModelFor(CloudTtsProvider.microsoftEdge) : outputFormat.trim()}"}}}}';
  }

  String _edgeSsmlRequest({
    required String requestId,
    required String timestamp,
    required String voice,
    required String rate,
    required String text,
  }) {
    return 'X-RequestId:$requestId\r\n'
        'Content-Type:application/ssml+xml\r\n'
        'X-Timestamp:${timestamp}Z\r\n'
        'Path:ssml\r\n\r\n'
        '<speak version="1.0" xml:lang="en-US">'
        '<voice name="$voice"><prosody rate="$rate">'
        '${const HtmlEscape().convert(_sanitizeEdgeText(text))}'
        '</prosody></voice></speak>';
  }

  List<String> _splitEdgeText(String text, {int maxBytes = 3800}) {
    final cleaned = _sanitizeEdgeText(text).trim();
    if (cleaned.isEmpty) return const [];

    final source = utf8.encode(cleaned);
    final chunks = <String>[];
    var offset = 0;

    while (offset < source.length) {
      final remaining = source.length - offset;
      final candidateLength = remaining <= maxBytes ? remaining : maxBytes;
      var split = offset + candidateLength;

      while (split > offset &&
          split < source.length &&
          (source[split] & 0xC0) == 0x80) {
        split--;
      }
      if (split <= offset) {
        split = offset + candidateLength;
      }

      var chunk = utf8.decode(source.sublist(offset, split)).trim();
      final naturalBreak = _lastNaturalBreak(chunk);
      if (naturalBreak > 0 && naturalBreak >= chunk.length ~/ 2) {
        chunk = chunk.substring(0, naturalBreak).trim();
        split = offset + utf8.encode(chunk).length;
      }

      if (chunk.isEmpty) {
        chunk = utf8.decode(source.sublist(offset, split)).trim();
      }
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }
      offset = split;
    }

    return chunks;
  }

  int _lastNaturalBreak(String value) {
    const breakChars = [
      '\n',
      '。',
      '！',
      '？',
      '.',
      '!',
      '?',
      ';',
      '；',
      ',',
      '，',
      ' '
    ];
    var index = -1;
    for (final char in breakChars) {
      final next = value.lastIndexOf(char);
      if (next > index) {
        index = next;
      }
    }
    return index == -1 ? -1 : index + 1;
  }

  String _sanitizeEdgeText(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if ((rune >= 0 && rune <= 8) ||
          (rune >= 11 && rune <= 12) ||
          (rune >= 14 && rune <= 31)) {
        buffer.write(' ');
      } else {
        buffer.write(String.fromCharCode(rune));
      }
    }
    return buffer.toString();
  }

  Map<String, String> _parseHeaderLines(String raw) {
    final headers = <String, String>{};
    for (final line in raw.split('\r\n')) {
      final index = line.indexOf(':');
      if (index <= 0) continue;
      headers[line.substring(0, index)] = line.substring(index + 1).trim();
    }
    return headers;
  }

  String _edgeRate(double speed) {
    final delta = ((speed - 1.0) * 100).round().clamp(-100, 100);
    return '${delta >= 0 ? '+' : ''}$delta%';
  }

  String _edgeRequestId() => _randomHex(32).toLowerCase();

  String _edgeMuid() => _randomHex(32);

  String _edgeTimestamp() => _edgeDateHeader();

  String _edgeDateHeader() {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now().toUtc();
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return '$weekday $month $day ${now.year} $hour:$minute:$second GMT+0000 (Coordinated Universal Time)';
  }

  String _generateEdgeSecMsGec() {
    const windowsEpoch = 11644473600;
    final seconds = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
    final roundedSeconds =
        seconds + windowsEpoch - ((seconds + windowsEpoch) % 300);
    final ticks = (roundedSeconds * 10000000).round();
    final digest = sha256.convert(
      ascii.encode('$ticks$_edgeTrustedClientToken'),
    );
    return digest.toString().toUpperCase();
  }

  String _randomHex(int length) {
    const digits = '0123456789ABCDEF';
    final buffer = StringBuffer();
    for (var index = 0; index < length; index++) {
      buffer.write(digits[_random.nextInt(digits.length)]);
    }
    return buffer.toString();
  }

  Uint8List _outputOrEmpty(BytesBuilder builder) {
    final bytes = builder.takeBytes();
    return bytes.isEmpty ? Uint8List(0) : Uint8List.fromList(bytes);
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
      RegExp(r'^xi-api-key\s*:\s*', caseSensitive: false),
      '',
    );
    return value.trim();
  }

  String _extractErrorMessage(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
        if (detail is Map<String, dynamic>) {
          final message = detail['message']?.toString().trim() ?? '';
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
