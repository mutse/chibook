import 'dart:convert';

import 'package:chibook/data/models/book_annotation.dart';
import 'package:chibook/data/repositories/book_repository.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final bookAnnotationServiceProvider = Provider<BookAnnotationService>((ref) {
  return BookAnnotationService(ref.read(bookRepositoryProvider));
});

final bookAnnotationsProvider =
    FutureProvider.family<List<BookAnnotation>, String>((ref, bookId) async {
  return ref.read(bookAnnotationServiceProvider).loadBookAnnotations(bookId);
});

class BookAnnotationService {
  BookAnnotationService(this._bookRepository);

  final BookRepository _bookRepository;

  static const _legacyStorageKey = 'book_annotations_v1';
  static const _legacyMigratedKey = 'book_annotations_migrated_v2';

  Future<List<BookAnnotation>> loadBookAnnotations(String bookId) async {
    await _migrateLegacyAnnotationsIfNeeded();
    return _bookRepository.listAnnotations(bookId);
  }

  Future<void> saveAnnotation(BookAnnotation annotation) async {
    await _migrateLegacyAnnotationsIfNeeded();
    await _bookRepository.saveAnnotation(annotation);
  }

  Future<void> removeAnnotation(String annotationId) async {
    await _migrateLegacyAnnotationsIfNeeded();
    await _bookRepository.deleteAnnotation(annotationId);
  }

  Future<void> _migrateLegacyAnnotationsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final migrated = prefs.getBool(_legacyMigratedKey) ?? false;
    if (migrated) return;

    final raw = prefs.getString(_legacyStorageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded.whereType<Map>()) {
          await _bookRepository.saveAnnotation(
            BookAnnotation.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    await prefs.setBool(_legacyMigratedKey, true);
  }
}
