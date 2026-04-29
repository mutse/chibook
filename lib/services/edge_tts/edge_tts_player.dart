import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'edge_tts_client.dart';
import 'models.dart';

class EdgeTtsPlayer {
  EdgeTtsPlayer({
    EdgeTtsClient? client,
    AudioPlayer? audioPlayer,
    this.config = const TtsConfig(),
  })  : _client = client ?? EdgeTtsClient(),
        _player = audioPlayer ?? AudioPlayer();

  final EdgeTtsClient _client;
  final AudioPlayer _player;
  TtsConfig config;

  Future<void> speak(String text, {String? endpoint}) async {
    final bytes = await _client.synthesize(text, config, endpoint: endpoint);
    final file = await _writeTempFile(bytes);
    await _player.stop();
    await _player.play(DeviceFileSource(file.path, mimeType: 'audio/mpeg'));
  }

  Future<void> speakStream(String text, {String? endpoint}) async {
    final buffer = <int>[];
    await for (final chunk
        in _client.stream(text, config, endpoint: endpoint)) {
      if (chunk.type == 'audio' && chunk.audioData != null) {
        buffer.addAll(chunk.audioData!);
      }
    }

    if (buffer.isEmpty) {
      throw StateError('EdgeTTS: empty audio');
    }

    final file = await _writeTempFile(Uint8List.fromList(buffer));
    await _player.stop();
    await _player.play(DeviceFileSource(file.path, mimeType: 'audio/mpeg'));
  }

  Future<void> stop() => _player.stop();

  Future<void> pause() => _player.pause();

  Future<void> resume() => _player.resume();

  Future<void> dispose() => _player.dispose();

  Future<File> _writeTempFile(Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      path.join(
        directory.path,
        'edge_tts_${DateTime.now().microsecondsSinceEpoch}.mp3',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
