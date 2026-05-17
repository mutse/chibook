import 'dart:convert';

import 'package:chibook/data/models/book_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final bookAnnotationServiceProvider = Provider<BookAnnotationService>((ref) {
  return const BookAnnotationService();
});

final bookAnnotationsProvider =
    FutureProvider.family<List<BookAnnotation>, String>((ref, bookId) {
  return ref.read(bookAnnotationServiceProvider).loadBookAnnotations(bookId);
});

class BookAnnotationService {
  const BookAnnotationService();

  static const _storageKey = 'book_annotations_v1';

  Future<List<BookAnnotation>> loadBookAnnotations(String bookId) async {
    final annotations = await _loadAllAnnotations();
    final result = annotations.where((item) => item.bookId == bookId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<void> saveAnnotation(BookAnnotation annotation) async {
    final prefs = await SharedPreferences.getInstance();
    final annotations = await _loadAllAnnotations();
    final index = annotations.indexWhere((item) => item.id == annotation.id);
    if (index >= 0) {
      annotations[index] = annotation;
    } else {
      annotations.add(annotation);
    }
    await prefs.setString(
      _storageKey,
      jsonEncode(annotations.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> removeAnnotation(String annotationId) async {
    final prefs = await SharedPreferences.getInstance();
    final annotations = await _loadAllAnnotations();
    annotations.removeWhere((item) => item.id == annotationId);
    await prefs.setString(
      _storageKey,
      jsonEncode(annotations.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<BookAnnotation>> _loadAllAnnotations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return <BookAnnotation>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <BookAnnotation>[];

    return decoded
        .whereType<Map>()
        .map(
          (item) => BookAnnotation.fromJson(
            item.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList();
  }
}
