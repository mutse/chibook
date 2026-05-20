import 'package:chibook/data/models/audio_cache_entry.dart';
import 'package:chibook/data/models/book_annotation.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/reading_progress.dart';
import 'package:chibook/data/repositories/book_repository.dart';

class InMemoryBookRepository implements BookRepository {
  final Map<String, Book> _books = {};
  final Map<String, ReadingProgress> _progress = {};
  final Map<String, BookAnnotation> _annotations = {};
  final Map<String, AudioCacheEntry> _audioCaches = {};

  @override
  Future<Book?> getBook(String id) async {
    final book = _books[id];
    final progress = _progress[id];
    if (book == null) return null;
    if (progress == null) return book;
    return book.copyWith(
      progress: progress.percentage,
      lastReadAt: progress.updatedAt,
      lastReadLocation: progress.location,
    );
  }

  @override
  Future<Book?> getBookByHash(String fileHash) async {
    for (final book in _books.values) {
      if (book.fileHash == fileHash) {
        return getBook(book.id);
      }
    }
    return null;
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
          lastReadLocation: progress?.location ?? book.lastReadLocation,
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
    _annotations.removeWhere((_, value) => value.bookId == id);
    _audioCaches.removeWhere((_, value) => value.bookId == id);
  }

  @override
  Future<void> updateProgress(ReadingProgress progress) async {
    _progress[progress.bookId] = progress;
  }

  @override
  Future<ReadingProgress?> getProgress(String bookId) async => _progress[bookId];

  @override
  Future<List<BookAnnotation>> listAnnotations(String bookId) async {
    final items = _annotations.values
        .where((item) => item.bookId == bookId)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<void> saveAnnotation(BookAnnotation annotation) async {
    _annotations[annotation.id] = annotation;
  }

  @override
  Future<void> deleteAnnotation(String annotationId) async {
    _annotations.remove(annotationId);
  }

  @override
  Future<List<AudioCacheEntry>> listAudioCacheEntries({String? bookId}) async {
    final items = _audioCaches.values
        .where((item) => bookId == null || item.bookId == bookId)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<void> saveAudioCacheEntry(AudioCacheEntry entry) async {
    _audioCaches[entry.id] = entry;
  }

  @override
  Future<void> deleteAudioCacheEntry(String entryId) async {
    _audioCaches.remove(entryId);
  }
}
