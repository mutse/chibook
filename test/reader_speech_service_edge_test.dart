import 'dart:convert';
import 'dart:typed_data';

import 'package:chibook/services/reader_speech_service.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GlobalAudioplayersPlatformInterface.instance =
      _FakeGlobalAudioplayersPlatform();
  AudioplayersPlatformInterface.instance = _FakeAudioplayersPlatform();

  test('azure speech voices request uses secured REST endpoint',
      () async {
    final client = _RecordingClient(
      handler: (request) async {
        return http.Response(
          jsonEncode([
            {
              'ShortName': 'zh-CN-XiaoxiaoNeural',
              'FriendlyName': 'zh-CN-XiaoxiaoNeural',
              'Locale': 'zh-CN',
              'Gender': 'Female',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      },
    );
    final service = ReaderSpeechService(client: client);

    final voices = await service.listEdgeVoices(
      endpoint:
          'https://eastus.tts.speech.microsoft.com/cognitiveservices/v1',
      apiKey: 'Ocp-Apim-Subscription-Key azure-key',
    );

    expect(voices, isNotEmpty);
    final request = client.lastRequest;
    expect(request, isNotNull);

    expect(
      request!.url.toString(),
      'https://eastus.tts.speech.microsoft.com/cognitiveservices/voices/list',
    );
    expect(request.headers['ocp-apim-subscription-key'], 'azure-key');
    expect(request.headers['accept'], 'application/json');
  });

  test('elevenlabs voices request uses v2 voices endpoint and parses labels',
      () async {
    final client = _RecordingClient(
      handler: (request) async {
        return http.Response(
          jsonEncode({
            'voices': [
              {
                'voice_id': 'EXAVITQu4vr4xnSDxMaL',
                'name': 'Sarah',
                'category': 'premade',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      },
    );
    final service = ReaderSpeechService(client: client);

    final voices = await service.listElevenLabsVoices(
      apiKey: 'xi-api-key test-key',
      endpoint:
          'https://api.elevenlabs.io/v1/text-to-speech/EXAVITQu4vr4xnSDxMaL',
    );

    expect(voices, hasLength(1));
    expect(voices.first.id, 'EXAVITQu4vr4xnSDxMaL');
    expect(voices.first.label, 'Sarah · premade');

    final request = client.lastRequest;
    expect(request, isNotNull);
    expect(request!.url.toString(), 'https://api.elevenlabs.io/v2/voices');
    expect(request.headers['xi-api-key'], 'test-key');
    expect(request.headers['accept'], 'application/json');
  });
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient({
    required this.handler,
  });

  final Future<http.Response> Function(http.BaseRequest request) handler;
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    final response = await handler(request);
    final bytes = utf8.encode(response.body);
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}

class _FakeAudioplayersPlatform extends AudioplayersPlatformInterface {
  final _eventStreams = <String, Stream<AudioEvent>>{};

  @override
  Future<void> create(String playerId) async {
    _eventStreams[playerId] = const Stream<AudioEvent>.empty();
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) {
    return _eventStreams[playerId] ?? const Stream<AudioEvent>.empty();
  }

  @override
  Future<void> dispose(String playerId) async {}

  @override
  Future<void> emitError(String playerId, String code, String message) async {}

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<int?> getDuration(String playerId) async => 0;

  @override
  Future<void> pause(String playerId) async {}

  @override
  Future<void> release(String playerId) async {}

  @override
  Future<void> resume(String playerId) async {}

  @override
  Future<void> seek(String playerId, Duration position) async {}

  @override
  Future<void> setAudioContext(
      String playerId, AudioContext audioContext) async {}

  @override
  Future<void> setBalance(String playerId, double balance) async {}

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {}

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}

  @override
  Future<void> setSourceBytes(
    String playerId,
    Uint8List bytes, {
    String? mimeType,
  }) async {}

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {}

  @override
  Future<void> setVolume(String playerId, double volume) async {}

  @override
  Future<void> stop(String playerId) async {}
}

class _FakeGlobalAudioplayersPlatform
    extends GlobalAudioplayersPlatformInterface {
  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() {
    return const Stream<GlobalAudioEvent>.empty();
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}
}
