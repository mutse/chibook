import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class SpeechPlaybackService {
  SpeechPlaybackService({
    AudioPlayer? audioPlayer,
  }) : _audioPlayer = audioPlayer ?? AudioPlayer() {
    _configureAudioSession();
    _playerCompleteSubscription = _audioPlayer.playerStateStream.listen((
      state,
    ) {
      if (state.processingState == ProcessingState.completed) {
        _completionController.add(null);
      }
    });
  }

  final AudioPlayer _audioPlayer;
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();
  StreamSubscription<PlayerState>? _playerCompleteSubscription;

  Stream<void> get onPlaybackCompleted => _completionController.stream;

  Future<void> playFile(File file) async {
    await _audioPlayer.stop();
    await _audioPlayer.setFilePath(file.path);
    await _audioPlayer.play();
  }

  Future<void> pause() => _audioPlayer.pause();

  Future<void> resume() => _audioPlayer.play();

  Future<void> stop() => _audioPlayer.stop();

  Future<void> dispose() async {
    await _playerCompleteSubscription?.cancel();
    await _completionController.close();
    await _audioPlayer.dispose();
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }
}
