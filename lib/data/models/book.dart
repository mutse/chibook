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
    required this.fileHash,
    required this.fileSizeBytes,
    this.coverImagePath,
    this.lastReadAt,
    this.lastReadLocation,
    this.progress = 0,
    this.totalLocations = 0,
    this.pageCount = 0,
    this.chapterCount = 0,
    this.languageCode,
  });

  final String id;
  final String title;
  final String author;
  final String filePath;
  final String originalFileName;
  final BookFormat format;
  final DateTime importedAt;
  final String fileHash;
  final int fileSizeBytes;
  final String? coverImagePath;
  final DateTime? lastReadAt;
  final String? lastReadLocation;
  final double progress;
  final int totalLocations;
  final int pageCount;
  final int chapterCount;
  final String? languageCode;

  String get formatLabel => format == BookFormat.epub ? 'EPUB' : 'PDF';
  bool get hasCoverImage => coverImagePath?.trim().isNotEmpty == true;

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    String? originalFileName,
    BookFormat? format,
    DateTime? importedAt,
    String? fileHash,
    int? fileSizeBytes,
    String? coverImagePath,
    DateTime? lastReadAt,
    String? lastReadLocation,
    double? progress,
    int? totalLocations,
    int? pageCount,
    int? chapterCount,
    String? languageCode,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      originalFileName: originalFileName ?? this.originalFileName,
      format: format ?? this.format,
      importedAt: importedAt ?? this.importedAt,
      fileHash: fileHash ?? this.fileHash,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastReadLocation: lastReadLocation ?? this.lastReadLocation,
      progress: progress ?? this.progress,
      totalLocations: totalLocations ?? this.totalLocations,
      pageCount: pageCount ?? this.pageCount,
      chapterCount: chapterCount ?? this.chapterCount,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}
