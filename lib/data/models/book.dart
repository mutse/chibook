enum BookFormat { epub, pdf }

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.originalFileName,
    required this.format,
    required this.importedAt,
    this.coverPath,
    this.lastReadAt,
    this.progress = 0,
    this.totalLocations = 0,
  });

  final String id;
  final String title;
  final String author;
  final String filePath;
  final String originalFileName;
  final BookFormat format;
  final DateTime importedAt;
  final String? coverPath;
  final DateTime? lastReadAt;
  final double progress;
  final int totalLocations;

  String get formatLabel => format == BookFormat.epub ? 'EPUB' : 'PDF';

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    String? originalFileName,
    BookFormat? format,
    DateTime? importedAt,
    String? coverPath,
    DateTime? lastReadAt,
    double? progress,
    int? totalLocations,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      originalFileName: originalFileName ?? this.originalFileName,
      format: format ?? this.format,
      importedAt: importedAt ?? this.importedAt,
      coverPath: coverPath ?? this.coverPath,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      progress: progress ?? this.progress,
      totalLocations: totalLocations ?? this.totalLocations,
    );
  }
}
