import 'package:chibook/data/models/book.dart';

class BookAiRequest {
  const BookAiRequest({
    required this.bookId,
    required this.filePath,
    required this.title,
    required this.author,
    required this.format,
    required this.progress,
  });

  factory BookAiRequest.fromBook(Book book) {
    return BookAiRequest(
      bookId: book.id,
      filePath: book.filePath,
      title: book.title,
      author: book.author,
      format: book.format,
      progress: book.progress,
    );
  }

  final String bookId;
  final String filePath;
  final String title;
  final String author;
  final BookFormat format;
  final double progress;

  @override
  bool operator ==(Object other) {
    return other is BookAiRequest &&
        other.bookId == bookId &&
        other.filePath == filePath &&
        other.title == title &&
        other.author == author &&
        other.format == format &&
        other.progress == progress;
  }

  @override
  int get hashCode =>
      Object.hash(bookId, filePath, title, author, format, progress);
}

class BookContentSection {
  const BookContentSection({
    required this.id,
    required this.title,
    required this.locationLabel,
    required this.text,
    required this.estimatedMinutes,
    this.chapterIndex,
    this.pageNumber,
  });

  final String id;
  final String title;
  final String locationLabel;
  final String text;
  final int estimatedMinutes;
  final int? chapterIndex;
  final int? pageNumber;
}

class BookMindMapBranch {
  const BookMindMapBranch({
    required this.title,
    required this.leaves,
  });

  final String title;
  final List<String> leaves;
}

class BookAiBundle {
  const BookAiBundle({
    required this.overview,
    required this.summaryPoints,
    required this.readingAdvice,
    required this.quoteCandidates,
    required this.askSuggestions,
    required this.mindMapBranches,
    required this.sections,
    required this.keywords,
  });

  final String overview;
  final List<String> summaryPoints;
  final String readingAdvice;
  final List<String> quoteCandidates;
  final List<String> askSuggestions;
  final List<BookMindMapBranch> mindMapBranches;
  final List<BookContentSection> sections;
  final List<String> keywords;
}
