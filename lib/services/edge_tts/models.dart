import 'package:chibook/services/edge_tts/edge_tts_voices.dart';

class TtsChunk {
  const TtsChunk({
    required this.type,
    this.audioData,
    this.offset,
    this.duration,
    this.text,
  });

  final String type;
  final List<int>? audioData;
  final double? offset;
  final double? duration;
  final String? text;
}

class TtsConfig {
  const TtsConfig({
    this.voice = EdgeTtsVoices.defaultVoice,
    this.rate = '+0%',
    this.volume = '+0%',
    this.pitch = '+0Hz',
    this.outputFormat = 'audio-24khz-48kbitrate-mono-mp3',
  });

  final String voice;
  final String rate;
  final String volume;
  final String pitch;
  final String outputFormat;
}

class EdgeTtsVoiceOption {
  const EdgeTtsVoiceOption({
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
