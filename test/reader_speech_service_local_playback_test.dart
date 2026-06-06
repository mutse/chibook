import 'dart:async';
import 'dart:io';

import 'package:chibook/data/models/speech_settings.dart';
import 'package:chibook/services/entitlement_service.dart';
import 'package:chibook/services/reader_speech_service.dart';
import 'package:chibook/services/speech_playback_service.dart';
import 'package:chibook/services/speech_settings_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getTemporaryDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test('local segment playback synthesizes to file before playing', () async {
    final flutterTts = _FakeFlutterTts();
    final playbackService = _FakeSpeechPlaybackService();
    final service = ReaderSpeechService(
      flutterTts: flutterTts,
      speechPlaybackService: playbackService,
      speechSettingsService: _FakeSpeechSettingsService(
        const SpeechSettings(
          providerMode: SpeechProviderMode.local,
          cloudProvider: CloudTtsProvider.azureSpeech,
          endpoint:
              'https://eastus.tts.speech.microsoft.com/cognitiveservices/v1',
          apiKey: '',
          model: 'audio-24khz-48kbitrate-mono-mp3',
          voice: 'zh-CN-XiaoxiaoNeural',
          localVoiceId: '',
          speed: 1.0,
          localSpeechRate: 0.45,
        ),
      ),
      entitlementService: _FakeEntitlementService(),
    );

    await service.speakCachedSegment(
      bookId: 'book-1',
      segmentId: 'segment-1',
      text: '测试锁屏后还能继续播放',
    );

    expect(flutterTts.speakCalls, 0);
    expect(flutterTts.synthesizedFiles, hasLength(1));
    expect(playbackService.playedFiles, hasLength(1));
    expect(
      playbackService.playedFiles.single.path,
      flutterTts.synthesizedFiles.single.path,
    );

    await service.dispose();
  });
}

class _FakeSpeechSettingsService extends SpeechSettingsService {
  _FakeSpeechSettingsService(this._settings);

  final SpeechSettings _settings;

  @override
  Future<SpeechSettings> load() async => _settings;
}

class _FakeEntitlementService extends EntitlementService {
  @override
  Future<bool> isProUnlocked() async => true;
}

class _FakeFlutterTts extends FlutterTts {
  int speakCalls = 0;
  final List<File> synthesizedFiles = <File>[];

  bool _awaitSpeakCompletion = false;
  bool _awaitSynthCompletion = false;
  VoidCallback? _completionHandler;
  VoidCallback? _cancelHandler;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async {
    _awaitSpeakCompletion = awaitCompletion;
    return 1;
  }

  @override
  Future<dynamic> awaitSynthCompletion(bool awaitCompletion) async {
    _awaitSynthCompletion = awaitCompletion;
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    speakCalls += 1;
    if (_awaitSpeakCompletion) {
      scheduleMicrotask(() => _completionHandler?.call());
    }
    return 1;
  }

  @override
  Future<dynamic> synthesizeToFile(
    String text,
    String fileName, [
    bool isFullPath = false,
  ]) async {
    final file = File(fileName);
    await file.writeAsBytes(<int>[1, 2, 3], flush: true);
    synthesizedFiles.add(file);
    if (_awaitSynthCompletion) {
      scheduleMicrotask(() => _completionHandler?.call());
    }
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    _cancelHandler?.call();
    return 1;
  }

  @override
  void setCompletionHandler(VoidCallback callback) {
    _completionHandler = callback;
  }

  @override
  void setCancelHandler(VoidCallback callback) {
    _cancelHandler = callback;
  }

  @override
  void setPauseHandler(VoidCallback callback) {}

  @override
  void setContinueHandler(VoidCallback callback) {}

  @override
  void setErrorHandler(ErrorHandler callback) {}
}

class _FakeSpeechPlaybackService extends SpeechPlaybackService {
  _FakeSpeechPlaybackService();

  final List<File> playedFiles = <File>[];
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();

  @override
  Stream<void> get onPlaybackCompleted => _completionController.stream;

  @override
  Future<void> playFile(File file) async {
    playedFiles.add(file);
    scheduleMicrotask(() => _completionController.add(null));
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _completionController.close();
  }
}
