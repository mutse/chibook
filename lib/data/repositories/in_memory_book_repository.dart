import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/reading_progress.dart';
import 'package:chibook/data/repositories/book_repository.dart';

class InMemoryBookRepository implements BookRepository {
  final Map<String, Book> _books = {};
  final Map<String, ReadingProgress> _progress = {};

  @override
  Future<Book?> getBook(String id) async {
    final book = _books[id];
    final progress = _progress[id];
    if (book == null) return null;
    if (progress == null) return book;
    return book.copyWith(
      progress: progress.percentage,
      lastReadAt: progress.updatedAt,
    );
  }

  @override
  Future<List<Book>> getBooks() async {
    final items = <Book>[];
    for (final book in _books.values) {
      final progress = _progress[book.id];
      items.add(
        book.copyWith(
          progress: progress?.percentage ?? book.progress,
          lastReadAt: progress?.updatedAt ?? book.lastReadAt,
        ),
      );
    }
    items.sort((a, b) {
      final aTime = a.lastReadAt ?? a.importedAt;
      final bTime = b.lastReadAt ?? b.importedAt;
      return bTime.compareTo(aTime);
    });
    return items;
  }

  @override
  Future<void> saveBook(Book book) async {
    _books[book.id] = book;
  }

  @override
  Future<void> deleteBook(String id) async {
    _books.remove(id);
    _progress.remove(id);
  }

  @override
  Future<void> updateProgress(ReadingProgress progress) async {
    _progress[progress.bookId] = progress;
  }
}
