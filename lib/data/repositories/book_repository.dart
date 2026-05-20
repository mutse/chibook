import 'package:chibook/data/models/audio_cache_entry.dart';
import 'package:chibook/data/models/book_annotation.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/reading_progress.dart';

abstract class BookRepository {
  Future<List<Book>> getBooks();
  Future<Book?> getBook(String id);
  Future<Book?> getBookByHash(String fileHash);
  Future<void> saveBook(Book book);
  Future<void> deleteBook(String id);
  Future<void> updateProgress(ReadingProgress progress);
  Future<ReadingProgress?> getProgress(String bookId);
  Future<List<BookAnnotation>> listAnnotations(String bookId);
  Future<void> saveAnnotation(BookAnnotation annotation);
  Future<void> deleteAnnotation(String annotationId);
  Future<List<AudioCacheEntry>> listAudioCacheEntries({String? bookId});
  Future<void> saveAudioCacheEntry(AudioCacheEntry entry);
  Future<void> deleteAudioCacheEntry(String entryId);
}
