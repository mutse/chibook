import 'dart:io';

import 'package:chibook/data/models/audio_cache_entry.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/repositories/book_repository.dart';
import 'package:chibook/data/repositories/sqlite_book_repository.dart';
import 'package:chibook/features/reader/application/epub_reader_controller.dart';
import 'package:chibook/services/book_annotation_service.dart';
import 'package:chibook/services/database_service.dart';
import 'package:chibook/services/file_import_service.dart';
import 'package:chibook/services/speech_cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return SqliteBookRepository(ref.read(databaseServiceProvider));
});

final fileImportServiceProvider = Provider<FileImportService>((ref) {
  return FileImportService(
    bookRepository: ref.read(bookRepositoryProvider),
    epubService: ref.read(epubServiceProvider),
  );
});

final speechCacheServiceProvider = Provider<SpeechCacheService>((ref) {
  return SpeechCacheService(ref.read(bookRepositoryProvider));
});

final audioCacheEntriesProvider =
    FutureProvider<List<AudioCacheEntry>>((ref) async {
  return ref.read(speechCacheServiceProvider).listEntries();
});

final bookshelfControllerProvider =
    AsyncNotifierProvider<BookshelfController, List<Book>>(
  BookshelfController.new,
);

class BookshelfController extends AsyncNotifier<List<Book>> {
  bool _isImporting = false;

  @override
  Future<List<Book>> build() async {
    return ref.read(bookRepositoryProvider).getBooks();
  }

  Future<Book?> importBook() async {
    if (_isImporting) return null;

    _isImporting = true;
    try {
      final imported =
          await ref.read(fileImportServiceProvider).pickAndImportBook();
      if (imported == null) return null;

      await ref.read(bookRepositoryProvider).saveBook(imported);
      state = AsyncData(await ref.read(bookRepositoryProvider).getBooks());
      return imported;
    } finally {
      _isImporting = false;
    }
  }

  Future<void> removeBook(String bookId) async {
    final book = await ref.read(bookRepositoryProvider).getBook(bookId);
    await ref.read(bookRepositoryProvider).deleteBook(bookId);
    if (book != null) {
      await ref.read(speechCacheServiceProvider).deleteEntriesForBook(bookId);
      await _deleteFileIfExists(book.filePath);
      await _deleteFileIfExists(book.coverImagePath);
    }
    ref.invalidate(bookAnnotationsProvider(bookId));
    ref.invalidate(audioCacheEntriesProvider);
    state = AsyncData(await ref.read(bookRepositoryProvider).getBooks());
  }

  Future<void> _deleteFileIfExists(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) return;
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
