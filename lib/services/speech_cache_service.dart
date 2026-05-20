import 'dart:io';

import 'package:chibook/data/models/audio_cache_entry.dart';
import 'package:chibook/data/repositories/book_repository.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class SpeechCacheService {
  SpeechCacheService(this._bookRepository);

  final BookRepository _bookRepository;

  Future<Directory> cacheRootDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(path.join(baseDir.path, 'audio_cache'));
    if (!cacheDir.existsSync()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<File> cachedFile({
    required String bookId,
    required String fileName,
  }) async {
    final root = await cacheRootDirectory();
    final bookDir = Directory(path.join(root.path, bookId));
    if (!bookDir.existsSync()) {
      await bookDir.create(recursive: true);
    }
    return File(path.join(bookDir.path, fileName));
  }

  Future<void> registerCacheFile({
    required String bookId,
    required String segmentId,
    required String segmentLabel,
    required String providerName,
    required File file,
  }) async {
    if (!await file.exists()) return;
    final stat = await file.stat();
    final existingEntries =
        await _bookRepository.listAudioCacheEntries(bookId: bookId);
    final existing = existingEntries.cast<AudioCacheEntry?>().firstWhere(
          (entry) => entry?.filePath == file.path,
          orElse: () => null,
        );
    await _bookRepository.saveAudioCacheEntry(
      AudioCacheEntry(
        id: existing?.id ?? const Uuid().v4(),
        bookId: bookId,
        segmentId: segmentId,
        segmentLabel: segmentLabel,
        filePath: file.path,
        fileSizeBytes: stat.size,
        providerName: providerName,
        createdAt: existing?.createdAt ?? DateTime.now(),
      ),
    );
  }

  Future<List<AudioCacheEntry>> listEntries({String? bookId}) async {
    final entries = await _bookRepository.listAudioCacheEntries(bookId: bookId);
    final retained = <AudioCacheEntry>[];
    for (final entry in entries) {
      if (await File(entry.filePath).exists()) {
        retained.add(entry);
      } else {
        await _bookRepository.deleteAudioCacheEntry(entry.id);
      }
    }
    return retained;
  }

  Future<int> totalBytes({String? bookId}) async {
    final entries = await listEntries(bookId: bookId);
    return entries.fold<int>(0, (sum, entry) => sum + entry.fileSizeBytes);
  }

  Future<void> deleteEntry(AudioCacheEntry entry) async {
    final file = File(entry.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    await _bookRepository.deleteAudioCacheEntry(entry.id);
  }

  Future<void> deleteEntriesForBook(String bookId) async {
    final entries = await listEntries(bookId: bookId);
    for (final entry in entries) {
      await deleteEntry(entry);
    }
    final root = await cacheRootDirectory();
    final bookDir = Directory(path.join(root.path, bookId));
    if (await bookDir.exists()) {
      await bookDir.delete(recursive: true);
    }
  }
}
