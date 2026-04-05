import 'package:chibook/data/models/epub_models.dart';
import 'package:chibook/services/epub_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final epubServiceProvider = Provider<EpubService>((ref) {
  return const EpubService();
});

final epubBookProvider =
    FutureProvider.family<EpubBookData, String>((ref, filePath) async {
  return ref.read(epubServiceProvider).loadBook(filePath);
});

final readerExcerptProvider =
    StateProvider.family<String, String>((ref, bookId) => '');
