import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/epub_models.dart';
import 'package:chibook/data/models/pdf_chapter_data.dart';
import 'package:chibook/data/models/pdf_chapter_toc_item.dart';
import 'package:chibook/data/models/reading_progress.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/reader/application/epub_reader_controller.dart';
import 'package:chibook/services/pdf_chapter_service.dart';
import 'package:chibook/services/reader_speech_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ReaderSpeechState { idle, playing, paused, caching }

final readerSpeechServiceProvider = Provider<ReaderSpeechService>((ref) {
  return ReaderSpeechService();
});

final pdfChapterServiceProvider = Provider<PdfChapterService>((ref) {
  return PdfChapterService();
});

final currentBookProvider =
    FutureProvider.family<Book?, String>((ref, bookId) async {
  return ref.read(bookRepositoryProvider).getBook(bookId);
});

class ReaderController {
  ReaderController(this.ref);

  final Ref ref;

  Future<void> speakExcerpt(String text) async {
    ref.read(readerSpeechStateProvider.notifier).state =
        ReaderSpeechState.playing;
    await ref.read(readerSpeechServiceProvider).speak(text);
  }

  Future<void> speakBookSegment({
    required String bookId,
    required String segmentId,
    required String text,
  }) async {
    ref.read(readerSpeechStateProvider.notifier).state =
        ReaderSpeechState.playing;
    await ref.read(readerSpeechServiceProvider).speakCachedSegment(
          bookId: bookId,
          segmentId: segmentId,
          text: text,
        );
  }

  Future<void> cacheBookSegment({
    required String bookId,
    required String segmentId,
    required String text,
  }) async {
    ref.read(readerSpeechStateProvider.notifier).state =
        ReaderSpeechState.caching;
    await ref.read(readerSpeechServiceProvider).cacheSegment(
          bookId: bookId,
          segmentId: segmentId,
          text: text,
        );
    ref.read(readerSpeechStateProvider.notifier).state = ReaderSpeechState.idle;
  }

  Future<bool> hasCachedBookSegment({
    required String bookId,
    required String segmentId,
    required String text,
  }) {
    return ref.read(readerSpeechServiceProvider).hasCachedSegment(
          bookId: bookId,
          segmentId: segmentId,
          text: text,
        );
  }

  Future<void> pauseSpeech() async {
    ref.read(readerSpeechStateProvider.notifier).state =
        ReaderSpeechState.paused;
    await ref.read(readerSpeechServiceProvider).pause();
  }

  Future<void> stopSpeech() async {
    ref.read(readerSpeechStateProvider.notifier).state = ReaderSpeechState.idle;
    await ref.read(readerSpeechServiceProvider).stop();
  }

  Future<void> resumeSpeech() async {
    ref.read(readerSpeechStateProvider.notifier).state =
        ReaderSpeechState.playing;
    await ref.read(readerSpeechServiceProvider).resume();
  }

  Future<void> updateProgress({
    required String bookId,
    required String location,
    required double percentage,
  }) async {
    await ref.read(bookRepositoryProvider).updateProgress(
          ReadingProgress(
            bookId: bookId,
            location: location,
            percentage: percentage,
            updatedAt: DateTime.now(),
          ),
        );
  }

  void setReaderExcerpt({
    required String bookId,
    required String text,
  }) {
    ref.read(readerExcerptProvider(bookId).notifier).state = text;
  }
}

final readerControllerProvider = Provider(ReaderController.new);

final currentEpubChapterProvider =
    StateProvider.family<EpubChapterData?, String>((ref, bookId) => null);

final currentPdfChapterProvider =
    StateProvider.family<PdfChapterData?, String>((ref, bookId) => null);

final requestedPdfPageProvider =
    StateProvider.family<int?, String>((ref, bookId) => null);

final pdfChapterTocProvider =
    FutureProvider.family<List<PdfChapterTocItem>, String>((ref, filePath) {
  return ref.read(pdfChapterServiceProvider).listChapters(filePath);
});

final readerSpeechStateProvider =
    StateProvider<ReaderSpeechState>((ref) => ReaderSpeechState.idle);
