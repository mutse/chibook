import 'dart:convert';

import 'package:chibook/services/reader_speech_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('edge voices request includes security query params and muid cookie', () async {
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
          'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1',
    );

    expect(voices, isNotEmpty);
    final request = client.lastRequest;
    expect(request, isNotNull);

    expect(
      request!.url.toString(),
      contains(
        'https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list',
      ),
    );
    expect(
      request.url.queryParameters['trustedclienttoken'],
      '6A5AA1D4EAFF4E9FB37E23D68491D6F4',
    );
    expect(
      request.url.queryParameters['Sec-MS-GEC-Version'],
      startsWith('1-'),
    );
    expect(
      request.url.queryParameters['Sec-MS-GEC'],
      matches(RegExp(r'^[A-F0-9]{64}$')),
    );
    expect(
      request.headers['cookie'],
      matches(RegExp(r'^muid=[A-F0-9]{32};$')),
    );
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
