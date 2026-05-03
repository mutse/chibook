import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'models.dart';

class EdgeTtsClient {
  EdgeTtsClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const _edgeOrigin =
      'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold';
  static const _chromiumFullVersion = '143.0.3650.75';
  static const _chromiumMajorVersion = '143';
  static const _windowsEpochSeconds = 11644473600;
  static const _defaultEndpoint =
      'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1';
  static double _clockSkewSeconds = 0;
  static const _uuid = Uuid();

  static const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0';
  static const _secChUa =
      '" Not;A Brand";v="99", "Microsoft Edge";v="$_chromiumMajorVersion", '
      '"Chromium";v="$_chromiumMajorVersion"';

  Future<List<EdgeTtsVoiceOption>> listVoices({String? endpoint}) async {
    final secMsGec = _edgeSecMsGec();
    final response = await _httpClient.get(
      _edgeVoicesUri(endpoint ?? _defaultEndpoint, secMsGec: secMsGec),
      headers: _edgeVoiceRequestHeaders(includeMuid: true),
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
          (item) => EdgeTtsVoiceOption(
            id: item['ShortName']?.toString().trim() ?? '',
            name: item['FriendlyName']?.toString().trim() ??
                item['ShortName']?.toString().trim() ??
                '',
            locale: item['Locale']?.toString().trim() ?? '',
            gender: item['Gender']?.toString().trim() ?? '',
          ),
        )
        .where((voice) => voice.id.isNotEmpty)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return voices;
  }

  Stream<TtsChunk> stream(
    String text,
    TtsConfig config, {
    String? endpoint,
  }) async* {
    final socket = await _connectEdgeSocket(endpoint ?? _defaultEndpoint);
    final timestamp = _edgeTimestamp();
    var audioReceived = false;

    try {
      await socket.sendText(
        _edgeSpeechConfigMessage(
          timestamp: timestamp,
          outputFormat: config.outputFormat,
        ),
      );
      await socket.sendText(
        _edgeSsmlRequestMessage(
          requestId: _edgeRequestId(),
          timestamp: timestamp,
          ssml: _buildSsml(text, config),
        ),
      );

      while (true) {
        final frame = await socket.nextFrame(
          timeout: const Duration(seconds: 20),
        );
        if (frame.opcode == _EdgeRawWebSocketClient.closeOpcode) {
          break;
        }

        if (frame.opcode == _EdgeRawWebSocketClient.textOpcode) {
          final payload = utf8.decode(frame.payload, allowMalformed: true);
          if (payload.contains('Path:turn.end')) {
            break;
          }
          for (final chunk in _parseTextMessage(payload)) {
            yield chunk;
          }
          continue;
        }

        if (frame.opcode == _EdgeRawWebSocketClient.binaryOpcode) {
          final chunk = _parseBinaryMessage(frame.payload);
          if (chunk != null) {
            audioReceived = true;
            yield chunk;
          }
        }
      }
    } finally {
      await socket.close();
    }

    if (!audioReceived) {
      throw StateError('EdgeTTS: no audio received — token may be expired');
    }
  }

  Future<Uint8List> synthesize(
    String text,
    TtsConfig config, {
    String? endpoint,
  }) async {
    final buffer = <int>[];
    await for (final chunk in stream(text, config, endpoint: endpoint)) {
      if (chunk.type == 'audio' && chunk.audioData != null) {
        buffer.addAll(chunk.audioData!);
      }
    }
    if (buffer.isEmpty) {
      throw StateError('EdgeTTS: empty audio');
    }
    return Uint8List.fromList(buffer);
  }

  List<TtsChunk> _parseTextMessage(String message) {
    if (!message.contains('Path:audio.metadata')) {
      return const [];
    }

    final bodyStart = message.indexOf('\r\n\r\n');
    if (bodyStart == -1) {
      return const [];
    }

    try {
      final body = message.substring(bodyStart + 4);
      final json = jsonDecode(body) as Map<String, dynamic>;
      final metadata = json['Metadata'];
      if (metadata is! List) {
        return const [];
      }

      final chunks = <TtsChunk>[];
      for (final item in metadata.whereType<Map>()) {
        final normalized = Map<String, dynamic>.from(item);
        final data = normalized['Data'];
        if (data is! Map) continue;
        final typedData = Map<String, dynamic>.from(data);
        final type = normalized['Type']?.toString().trim();
        final offset = (typedData['Offset'] as num?)?.toDouble();
        final duration = (typedData['Duration'] as num?)?.toDouble();
        final text = _metadataText(typedData);
        if (type == null || type.isEmpty) continue;
        chunks.add(
          TtsChunk(
            type: type,
            offset: offset,
            duration: duration,
            text: text,
          ),
        );
      }
      return chunks;
    } catch (_) {
      return const [];
    }
  }

  String? _metadataText(Map<String, dynamic> data) {
    final candidates = [data['text'], data['Text'], data['textBoundary']];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
      if (candidate is Map) {
        final map = Map<String, dynamic>.from(candidate);
        final value = map['Text']?.toString().trim() ??
            map['text']?.toString().trim() ??
            '';
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  TtsChunk? _parseBinaryMessage(Uint8List data) {
    if (data.length < 2) return null;

    final headerLength = (data[0] << 8) | data[1];
    if (data.length < 2 + headerLength) return null;

    final header = ascii.decode(
      data.sublist(2, 2 + headerLength),
      allowInvalid: true,
    );
    if (!header.contains('Path:audio')) {
      return null;
    }

    final audioBytes = data.sublist(2 + headerLength);
    if (audioBytes.isEmpty) return null;

    return TtsChunk(type: 'audio', audioData: audioBytes);
  }

  Future<_EdgeRawWebSocketClient> _connectEdgeSocket(String endpoint) async {
    _EdgeRawWebSocketClient? socket;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        socket = await _EdgeRawWebSocketClient.connect(
          _edgeWebSocketUri(
            endpoint,
            connectionId: _edgeConnectionId(),
            secMsGec: _edgeSecMsGec(),
          ),
          headers: _edgeWebSocketHeaders(includeMuid: true),
        );
        break;
      } on _EdgeHandshakeException catch (error) {
        final adjusted = attempt == 0 &&
            error.statusCode == 403 &&
            _adjustClockSkew(error.headers);
        if (!adjusted) {
          rethrow;
        }
      }
    }

    if (socket == null) {
      throw Exception('Microsoft Edge websocket handshake failed.');
    }
    return socket;
  }

  String _buildSsml(String text, TtsConfig config) {
    final locale = _voiceLocale(config.voice);
    return '<speak version="1.0" '
        'xmlns="http://www.w3.org/2001/10/synthesis" '
        'xmlns:mstts="http://www.w3.org/2001/mstts" '
        'xml:lang="$locale">'
        '<voice xml:lang="$locale" name="${config.voice}">'
        '<prosody rate="${config.rate}" '
        'pitch="${config.pitch}" '
        'volume="${config.volume}">'
        '${const HtmlEscape().convert(_sanitizeText(text))}'
        '</prosody>'
        '</voice>'
        '</speak>';
  }

  String _sanitizeText(String text) {
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

  Uri _edgeVoicesUri(
    String endpoint, {
    required String secMsGec,
  }) {
    final uri = _edgeBaseUri(endpoint);
    return uri.replace(
      scheme: uri.scheme == 'ws' ? 'http' : 'https',
      path: _edgeNormalizedPath(uri.path, synthesisPath: false),
      queryParameters: {
        ..._edgeQueryParameters(uri.queryParameters),
        'trustedclienttoken': trustedClientToken,
        'Sec-MS-GEC': secMsGec,
        'Sec-MS-GEC-Version': _secMsGecVersion,
      },
    );
  }

  Uri _edgeWebSocketUri(
    String endpoint, {
    required String connectionId,
    required String secMsGec,
  }) {
    final uri = _edgeBaseUri(endpoint);
    return uri.replace(
      scheme: uri.scheme == 'http' ? 'ws' : 'wss',
      path: _edgeNormalizedPath(uri.path, synthesisPath: true),
      queryParameters: {
        ..._edgeQueryParameters(uri.queryParameters),
        'TrustedClientToken': trustedClientToken,
        'Sec-MS-GEC': secMsGec,
        'Sec-MS-GEC-Version': _secMsGecVersion,
        'ConnectionId': connectionId,
      },
    );
  }

  Map<String, String> _edgeBaseHeaders() {
    return {
      'User-Agent': _userAgent,
      'Accept-Encoding': 'gzip, deflate, br, zstd',
      'Accept-Language': 'en-US,en;q=0.9',
    };
  }

  Map<String, String> _edgeVoiceRequestHeaders({
    required bool includeMuid,
  }) {
    final headers = {
      ..._edgeBaseHeaders(),
      'Authority': 'speech.platform.bing.com',
      'Sec-CH-UA': _secChUa,
      'Sec-CH-UA-Mobile': '?0',
      'Accept': '*/*',
      'Sec-Fetch-Site': 'none',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Dest': 'empty',
    };
    if (includeMuid) {
      headers['Cookie'] = 'muid=${_edgeMuid()};';
    }
    return headers;
  }

  Map<String, String> _edgeWebSocketHeaders({
    required bool includeMuid,
  }) {
    final headers = {
      ..._edgeBaseHeaders(),
      'Origin': _edgeOrigin,
      'Pragma': 'no-cache',
      'Cache-Control': 'no-cache',
      'Sec-WebSocket-Version': '13',
    };
    if (includeMuid) {
      headers['Cookie'] = 'muid=${_edgeMuid()};';
    }
    return headers;
  }

  Uri _edgeBaseUri(String endpoint) {
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty) {
      return Uri.parse(_defaultEndpoint);
    }
    final candidate = trimmed.startsWith('speech.platform.bing.com')
        ? 'wss://$trimmed'
        : trimmed;
    return Uri.parse(candidate);
  }

  String _edgeNormalizedPath(
    String rawPath, {
    required bool synthesisPath,
  }) {
    var path = rawPath.trim();
    if (path.isEmpty || path == '/') {
      return synthesisPath
          ? '/consumer/speech/synthesize/readaloud/edge/v1'
          : '/consumer/speech/synthesize/readaloud/voices/list';
    }
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    if (synthesisPath) {
      if (path.endsWith('/voices/list')) {
        return path.replaceFirst(RegExp(r'/voices/list$'), '/edge/v1');
      }
      if (path.endsWith('/readaloud')) {
        return '$path/edge/v1';
      }
      return path;
    }

    if (path.endsWith('/edge/v1')) {
      return path.replaceFirst(RegExp(r'/edge/v1$'), '/voices/list');
    }
    if (path.endsWith('/readaloud')) {
      return '$path/voices/list';
    }
    return path;
  }

  Map<String, String> _edgeQueryParameters(Map<String, String> raw) {
    final query = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'trustedclienttoken' ||
          key == 'connectionid' ||
          key == 'sec-ms-gec' ||
          key == 'sec-ms-gec-version') {
        continue;
      }
      query[entry.key] = entry.value;
    }
    return query;
  }

  String _edgeSpeechConfigMessage({
    required String timestamp,
    required String outputFormat,
  }) {
    return 'X-Timestamp:$timestamp\r\n'
        'Content-Type:application/json; charset=utf-8\r\n'
        'Path:speech.config\r\n\r\n'
        '{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"true","wordBoundaryEnabled":"true"},"outputFormat":"$outputFormat"}}}}';
  }

  String _edgeSsmlRequestMessage({
    required String requestId,
    required String timestamp,
    required String ssml,
  }) {
    return 'X-RequestId:$requestId\r\n'
        'Content-Type:application/ssml+xml\r\n'
        'X-Timestamp:$timestamp\r\n'
        'Path:ssml\r\n\r\n'
        '$ssml';
  }

  String _edgeRequestId() {
    return _uuid.v4().replaceAll('-', '').toUpperCase();
  }

  String _edgeConnectionId() {
    return _uuid.v4().replaceAll('-', '');
  }

  String _edgeMuid() {
    return _uuid.v4().replaceAll('-', '').toUpperCase();
  }

  String get _secMsGecVersion => '1-$_chromiumFullVersion';

  String _edgeSecMsGec() {
    final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch / 1000.0 +
        _clockSkewSeconds;
    var ticks = nowSeconds + _windowsEpochSeconds;
    ticks -= ticks % 300;
    final windowsFileTimeTicks = (ticks * 10000000).round();
    final hashInput = '$windowsFileTimeTicks$trustedClientToken';
    return sha256.convert(ascii.encode(hashInput)).toString().toUpperCase();
  }

  bool _adjustClockSkew(Map<String, String> headers) {
    final serverDate = headers.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == 'date',
          orElse: () => const MapEntry('', ''),
        )
        .value;
    if (serverDate.isEmpty) return false;

    try {
      final parsed = HttpDate.parse(serverDate).toUtc();
      final clientSeconds =
          DateTime.now().toUtc().millisecondsSinceEpoch / 1000.0 +
              _clockSkewSeconds;
      final serverSeconds = parsed.millisecondsSinceEpoch / 1000.0;
      _clockSkewSeconds += serverSeconds - clientSeconds;
      return true;
    } catch (_) {
      return false;
    }
  }

  String _edgeTimestamp() {
    final now = DateTime.now().toUtc();
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

    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return '$weekday $month $day ${now.year} $hour:$minute:$second GMT+0000 (Coordinated Universal Time)';
  }

  String _voiceLocale(String voice) {
    final parts = voice.split('-');
    if (parts.length >= 2) {
      return '${parts[0]}-${parts[1]}';
    }
    return 'en-US';
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
          final detailMessage = detail['message']?.toString().trim() ?? '';
          if (detailMessage.isNotEmpty) return detailMessage;
        }
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final errorMessage = error['message']?.toString().trim() ?? '';
          if (errorMessage.isNotEmpty) return errorMessage;
        }
      }
    } catch (_) {
      final text = responseBody.trim();
      if (text.isNotEmpty) return text;
    }
    return 'Unknown error';
  }
}

class _EdgeHandshakeException implements Exception {
  const _EdgeHandshakeException({
    required this.statusCode,
    required this.headers,
    required this.message,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String message;

  @override
  String toString() => message;
}

class _EdgeSocketFrame {
  const _EdgeSocketFrame({
    required this.opcode,
    required this.payload,
  });

  final int opcode;
  final Uint8List payload;
}

class _EdgeRawWebSocketClient {
  _EdgeRawWebSocketClient._(this._socket);

  static const textOpcode = 0x1;
  static const binaryOpcode = 0x2;
  static const closeOpcode = 0x8;
  static const _pingOpcode = 0x9;
  static const _pongOpcode = 0xA;
  static const _webSocketGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

  final SecureSocket _socket;
  late final StreamSubscription<List<int>> _subscription;
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  final List<_EdgeSocketFrame> _frames = [];

  Completer<void>? _handshakeCompleter;
  Completer<_EdgeSocketFrame>? _frameCompleter;
  Object? _streamError;
  bool _handshakeDone = false;
  bool _closed = false;
  late Map<String, String> _handshakeHeaders;

  static Future<_EdgeRawWebSocketClient> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final port = uri.hasPort ? uri.port : 443;
    final socket = await SecureSocket.connect(
      uri.host,
      port,
      timeout: const Duration(seconds: 20),
    );

    late final _EdgeRawWebSocketClient client;
    client = _EdgeRawWebSocketClient._(socket);
    client._handshakeCompleter = Completer<void>();

    client._subscription = socket.listen(
      client._handleChunk,
      onError: client._handleError,
      onDone: client._handleDone,
      cancelOnError: false,
    );

    final secWebSocketKey = base64.encode(client._randomBytes(16));
    final requestPath = uri.path.isEmpty ? '/' : uri.path;
    final requestTarget =
        uri.hasQuery ? '$requestPath?${uri.query}' : requestPath;
    final request = StringBuffer()
      ..write('GET $requestTarget HTTP/1.1\r\n')
      ..write(
        'Host: ${uri.host}${uri.hasPort && port != 443 ? ':$port' : ''}\r\n',
      )
      ..write('Upgrade: websocket\r\n')
      ..write('Connection: Upgrade\r\n')
      ..write('Sec-WebSocket-Key: $secWebSocketKey\r\n')
      ..write('Sec-WebSocket-Version: 13\r\n');
    for (final entry in headers.entries) {
      request.write('${entry.key}: ${entry.value}\r\n');
    }
    request.write('\r\n');

    socket.add(utf8.encode(request.toString()));
    await socket.flush();

    await client._handshakeCompleter!.future.timeout(
      const Duration(seconds: 20),
    );

    final acceptSeed = '$secWebSocketKey$_webSocketGuid';
    client._verifyHandshakeAccept(
      expected: base64.encode(sha1.convert(utf8.encode(acceptSeed)).bytes),
    );
    return client;
  }

  Future<void> sendText(String text) async {
    _ensureOpen();
    _socket.add(_frameBytes(textOpcode, utf8.encode(text)));
    await _socket.flush();
  }

  Future<_EdgeSocketFrame> nextFrame({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    _ensureOpen();
    if (_frames.isNotEmpty) {
      return _frames.removeAt(0);
    }
    final completer = Completer<_EdgeSocketFrame>();
    _frameCompleter = completer;
    try {
      return await completer.future.timeout(timeout);
    } finally {
      if (identical(_frameCompleter, completer)) {
        _frameCompleter = null;
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      _socket.add(_frameBytes(closeOpcode, const []));
      await _socket.flush();
    } catch (_) {}
    await _subscription.cancel();
    await _socket.close();
  }

  void _handleChunk(List<int> chunk) {
    _buffer.add(chunk);
    if (!_handshakeDone) {
      _tryCompleteHandshake();
    }
    if (_handshakeDone) {
      _pumpFrames();
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    _streamError = error;
    _handshakeCompleter?.completeError(error, stackTrace);
    _frameCompleter?.completeError(error, stackTrace);
  }

  void _handleDone() {
    if (!_handshakeDone) {
      _handshakeCompleter?.completeError(
        StateError('Microsoft Edge websocket closed during handshake.'),
      );
    }
    _frameCompleter?.completeError(
      StateError('Microsoft Edge websocket closed unexpectedly.'),
    );
  }

  void _tryCompleteHandshake() {
    final data = _buffer.toBytes();
    final boundary = _indexOfBytes(data, const [13, 10, 13, 10]);
    if (boundary < 0) return;

    final headerBytes = data.sublist(0, boundary);
    final remaining = data.sublist(boundary + 4);
    _buffer.clear();
    if (remaining.isNotEmpty) {
      _buffer.add(remaining);
    }

    final headerText = ascii.decode(headerBytes, allowInvalid: true);
    final lines = headerText.split('\r\n');
    final statusLine = lines.isEmpty ? '' : lines.first;
    final headers = <String, String>{};
    for (final line in lines.skip(1)) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      headers[line.substring(0, separator)] =
          line.substring(separator + 1).trim();
    }

    final statusMatch =
        RegExp(r'^HTTP/\d+\.\d+\s+(\d+)').firstMatch(statusLine);
    final statusCode = int.tryParse(statusMatch?.group(1) ?? '') ?? 0;
    if (statusCode != 101) {
      throw _EdgeHandshakeException(
        statusCode: statusCode,
        headers: headers,
        message:
            'Microsoft Edge websocket handshake failed ($statusCode): $statusLine',
      );
    }

    _handshakeDone = true;
    _handshakeHeaders = headers;
    _handshakeCompleter?.complete();
  }

  void _verifyHandshakeAccept({
    required String expected,
  }) {
    final actual = _handshakeHeaders.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == 'sec-websocket-accept',
          orElse: () => const MapEntry('', ''),
        )
        .value;
    if (actual != expected) {
      throw Exception('Microsoft Edge websocket accept header mismatch.');
    }
  }

  void _pumpFrames() {
    final data = _buffer.toBytes();
    var offset = 0;
    while (offset < data.length) {
      final parsed = _tryParseFrame(data, offset);
      if (parsed == null) break;
      offset = parsed.nextOffset;
      final frame = parsed.frame;
      if (frame.opcode == _pingOpcode) {
        _socket.add(_frameBytes(_pongOpcode, frame.payload));
        continue;
      }
      _frames.add(frame);
    }

    _buffer.clear();
    if (offset < data.length) {
      _buffer.add(data.sublist(offset));
    }

    if (_frameCompleter != null &&
        !_frameCompleter!.isCompleted &&
        _frames.isNotEmpty) {
      final completer = _frameCompleter!;
      _frameCompleter = null;
      completer.complete(_frames.removeAt(0));
    }
  }

  _ParsedFrame? _tryParseFrame(Uint8List data, int offset) {
    if (data.length - offset < 2) return null;

    final byte1 = data[offset];
    final byte2 = data[offset + 1];
    final opcode = byte1 & 0x0f;
    final isMasked = (byte2 & 0x80) != 0;
    var payloadLength = byte2 & 0x7f;
    var headerLength = 2;

    if (payloadLength == 126) {
      if (data.length - offset < 4) return null;
      payloadLength = (data[offset + 2] << 8) | data[offset + 3];
      headerLength = 4;
    } else if (payloadLength == 127) {
      if (data.length - offset < 10) return null;
      payloadLength = 0;
      for (var index = 0; index < 8; index++) {
        payloadLength = (payloadLength << 8) | data[offset + 2 + index];
      }
      headerLength = 10;
    }

    final maskLength = isMasked ? 4 : 0;
    final totalLength = headerLength + maskLength + payloadLength;
    if (data.length - offset < totalLength) return null;

    final payloadOffset = offset + headerLength + maskLength;
    final payload = Uint8List.fromList(
      data.sublist(payloadOffset, payloadOffset + payloadLength),
    );
    if (isMasked) {
      final mask = data.sublist(offset + headerLength, payloadOffset);
      for (var index = 0; index < payload.length; index++) {
        payload[index] ^= mask[index % 4];
      }
    }

    return _ParsedFrame(
      frame: _EdgeSocketFrame(opcode: opcode, payload: payload),
      nextOffset: offset + totalLength,
    );
  }

  Uint8List _frameBytes(int opcode, List<int> payload) {
    final mask = _randomBytes(4);
    final builder = BytesBuilder(copy: false)..addByte(0x80 | (opcode & 0x0f));

    if (payload.length <= 125) {
      builder.addByte(0x80 | payload.length);
    } else if (payload.length <= 0xffff) {
      builder
        ..addByte(0x80 | 126)
        ..add([(payload.length >> 8) & 0xff, payload.length & 0xff]);
    } else {
      throw UnsupportedError('Edge websocket payload is too large.');
    }

    builder.add(mask);
    final maskedPayload = Uint8List(payload.length);
    for (var index = 0; index < payload.length; index++) {
      maskedPayload[index] = payload[index] ^ mask[index % 4];
    }
    builder.add(maskedPayload);
    return builder.takeBytes();
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  int _indexOfBytes(Uint8List source, List<int> target) {
    if (target.isEmpty || source.length < target.length) {
      return -1;
    }
    for (var index = 0; index <= source.length - target.length; index++) {
      var matched = true;
      for (var targetIndex = 0; targetIndex < target.length; targetIndex++) {
        if (source[index + targetIndex] != target[targetIndex]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return index;
      }
    }
    return -1;
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('Microsoft Edge websocket client is closed.');
    }
    if (_streamError != null) {
      throw StateError('Microsoft Edge websocket client failed: $_streamError');
    }
  }
}

class _ParsedFrame {
  const _ParsedFrame({
    required this.frame,
    required this.nextOffset,
  });

  final _EdgeSocketFrame frame;
  final int nextOffset;
}
