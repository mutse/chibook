class AudioCacheEntry {
  const AudioCacheEntry({
    required this.id,
    required this.bookId,
    required this.segmentId,
    required this.segmentLabel,
    required this.filePath,
    required this.fileSizeBytes,
    required this.providerName,
    required this.createdAt,
  });

  final String id;
  final String bookId;
  final String segmentId;
  final String segmentLabel;
  final String filePath;
  final int fileSizeBytes;
  final String providerName;
  final DateTime createdAt;

  String get formattedSizeLabel {
    final size = fileSizeBytes;
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (size >= 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '$size B';
  }
}
