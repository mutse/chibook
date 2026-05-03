import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/reading_progress.dart';

abstract class BookRepository {
  Future<List<Book>> getBooks();
  Future<Book?> getBook(String id);
  Future<void> saveBook(Book book);
  Future<void> deleteBook(String id);
  Future<void> updateProgress(ReadingProgress progress);
}
