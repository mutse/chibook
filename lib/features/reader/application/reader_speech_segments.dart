List<String> buildReaderSpeechSegments(
  String text, {
  int maxSegmentLength = 180,
}) {
  final normalized = text
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  if (normalized.isEmpty) return const [];

  final blocks = normalized
      .split(RegExp(r'\n\s*\n'))
      .map((block) => block.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((block) => block.isNotEmpty);

  final segments = <String>[];
  for (final block in blocks) {
    if (block.length <= maxSegmentLength) {
      segments.add(block);
      continue;
    }

    final sentences = block
        .split(RegExp(r'(?<=[。！？!?；;:：\.])\s*'))
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.isNotEmpty);

    var buffer = StringBuffer();
    for (final sentence in sentences) {
      final current = buffer.toString();
      final candidate = current.isEmpty ? sentence : '$current $sentence';
      if (candidate.length <= maxSegmentLength) {
        buffer
          ..clear()
          ..write(candidate);
        continue;
      }

      if (current.isNotEmpty) {
        segments.add(current);
      }

      if (sentence.length <= maxSegmentLength) {
        buffer
          ..clear()
          ..write(sentence);
        continue;
      }

      final chunks = _splitLongSentence(sentence, maxSegmentLength);
      segments.addAll(chunks.take(chunks.length - 1));
      buffer
        ..clear()
        ..write(chunks.last);
    }

    final remainder = buffer.toString().trim();
    if (remainder.isNotEmpty) {
      segments.add(remainder);
    }
  }

  return segments.where((segment) => segment.trim().isNotEmpty).toList();
}

String buildPdfHighlightQuery(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) return '';

  final sentences = normalized
      .split(RegExp(r'(?<=[。！？!?；;:：\.])\s*'))
      .map((sentence) => sentence.trim())
      .where((sentence) => sentence.length >= 8)
      .toList();
  final base = sentences.isNotEmpty ? sentences.first : normalized;
  return base.length <= 36 ? base : base.substring(0, 36).trim();
}

List<String> _splitLongSentence(String sentence, int maxSegmentLength) {
  final words = sentence.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
  if (words.length <= 1) {
    final output = <String>[];
    for (var i = 0; i < sentence.length; i += maxSegmentLength) {
      final end = (i + maxSegmentLength).clamp(0, sentence.length);
      output.add(sentence.substring(i, end).trim());
    }
    return output.where((chunk) => chunk.isNotEmpty).toList();
  }

  final output = <String>[];
  var buffer = StringBuffer();
  for (final word in words) {
    final current = buffer.toString();
    final candidate = current.isEmpty ? word : '$current $word';
    if (candidate.length <= maxSegmentLength) {
      buffer
        ..clear()
        ..write(candidate);
      continue;
    }
    if (current.isNotEmpty) {
      output.add(current);
    }
    buffer
      ..clear()
      ..write(word);
  }
  final remainder = buffer.toString().trim();
  if (remainder.isNotEmpty) {
    output.add(remainder);
  }
  return output;
}
