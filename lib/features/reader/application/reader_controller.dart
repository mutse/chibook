import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/epub_models.dart';
import 'package:chibook/data/models/pdf_chapter_data.dart';
import 'package:chibook/data/models/pdf_chapter_toc_item.dart';
import 'package:chibook/data/models/pdf_page_data.dart';
import 'package:chibook/data/models/reading_progress.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/reader/application/epub_reader_controller.dart';
import 'package:chibook/features/reader/application/reader_speech_segments.dart';
import 'package:chibook/services/pdf_chapter_service.dart';
import 'package:chibook/services/reader_speech_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ReaderSpeechState { idle, playing, paused, caching }

enum ReaderAutoSpeechMode { epub, pdf }

class ReaderAutoSpeechState {
  const ReaderAutoSpeechState({
    required this.mode,
    required this.currentText,
    this.chapterIndex,
    this.segmentIndex,
    this.pageNumber,
    this.highlightQuery,
    this.label,
  });

  final ReaderAutoSpeechMode mode;
  final String currentText;
  final int? chapterIndex;
  final int? segmentIndex;
  final int? pageNumber;
  final String? highlightQuery;
  final String? label;
}

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
  int _sessionSerial = 0;

  Future<void> speakExcerpt(String text) async {
    _cancelAutoSession();
    ref.read(readerSpeechStateProvider.notifier).state =
        ReaderSpeechState.playing;
    await ref.read(readerSpeechServiceProvider).speak(text);
  }

  Future<void> speakBookSegment({
    required String bookId,
    required String segmentId,
    required String text,
  }) async {
    _cancelAutoSession();
    await _speakBookSegmentInternal(
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
    _cancelAutoSession();
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

  Future<void> playAutoForCurrentBook(Book book) async {
    _cancelAutoSession();
    final sessionId = ++_sessionSerial;
    ref.read(readerActiveAutoBookIdProvider.notifier).state = book.id;
    ref.read(readerSpeechStateProvider.notifier).state =
        ReaderSpeechState.playing;

    try {
      switch (book.format) {
        case BookFormat.epub:
          await _playEpubAuto(book, sessionId);
        case BookFormat.pdf:
          await _playPdfAuto(book, sessionId);
      }
    } finally {
      if (_isSessionActive(sessionId)) {
        ref.read(readerSpeechStateProvider.notifier).state =
            ReaderSpeechState.idle;
        _clearAutoSpeechState(book.id);
        ref.read(readerActiveAutoBookIdProvider.notifier).state = null;
      }
    }
  }

  Future<void> _playEpubAuto(Book book, int sessionId) async {
    final epubBook = await ref.read(epubBookProvider(book.filePath).future);
    final currentChapter = ref.read(currentEpubChapterProvider(book.id));
    final chapters = epubBook.chapters;
    if (chapters.isEmpty) return;

    final startChapterIndex = (currentChapter?.index ?? 0).clamp(
      0,
      chapters.length - 1,
    );

    for (var chapterIndex = startChapterIndex;
        chapterIndex < chapters.length && _isSessionActive(sessionId);
        chapterIndex++) {
      final chapter = chapters[chapterIndex];
      ref.read(currentEpubChapterProvider(book.id).notifier).state = chapter;

      final segments = buildReaderSpeechSegments(chapter.plainText);
      if (segments.isEmpty) {
        continue;
      }

      for (var segmentIndex = 0;
          segmentIndex < segments.length && _isSessionActive(sessionId);
          segmentIndex++) {
        final segmentText = segments[segmentIndex];
        _setAutoSpeechState(
          book.id,
          ReaderAutoSpeechState(
            mode: ReaderAutoSpeechMode.epub,
            chapterIndex: chapter.index,
            segmentIndex: segmentIndex,
            currentText: segmentText,
            label: chapter.title,
          ),
        );
        setReaderExcerpt(bookId: book.id, text: segmentText);
        await _speakBookSegmentInternal(
          bookId: book.id,
          segmentId: 'epub-chapter-${chapter.index}-segment-$segmentIndex',
          text: segmentText,
        );
      }
    }
  }

  Future<void> _playPdfAuto(Book book, int sessionId) async {
    final pdfService = ref.read(pdfChapterServiceProvider);
    final toc = await pdfService.listChapters(book.filePath);
    final currentPage = ref.read(currentPdfPageProvider(book.id));

    if (toc.isEmpty) {
      final totalPages = await pdfService.pageCount(book.filePath);
      await _playPdfPageRange(
        book: book,
        sessionId: sessionId,
        startPage: currentPage.clamp(1, totalPages).toInt(),
        endPage: totalPages,
      );
      return;
    }

    var tocIndex = toc.indexWhere(
      (item) => currentPage >= item.startPage && currentPage <= item.endPage,
    );
    tocIndex = tocIndex >= 0
        ? tocIndex
        : toc.indexWhere((item) => item.startPage >= currentPage);
    if (tocIndex < 0) {
      tocIndex = toc.length - 1;
    }

    for (var index = tocIndex;
        index < toc.length && _isSessionActive(sessionId);
        index++) {
      final item = toc[index];
      final startPage = index == tocIndex
          ? currentPage.clamp(item.startPage, item.endPage).toInt()
          : item.startPage;
      await _playPdfPageRange(
        book: book,
        sessionId: sessionId,
        startPage: startPage,
        endPage: item.endPage,
        title: item.title,
      );
    }
  }

  Future<void> _playPdfPageRange({
    required Book book,
    required int sessionId,
    required int startPage,
    required int endPage,
    String? title,
  }) async {
    final pdfService = ref.read(pdfChapterServiceProvider);
    for (var pageNumber = startPage;
        pageNumber <= endPage && _isSessionActive(sessionId);
        pageNumber++) {
      final pageData = await pdfService.extractPage(
        filePath: book.filePath,
        pageNumber: pageNumber,
      );
      await _playPdfPage(
        book: book,
        sessionId: sessionId,
        pageData: pageData,
        title: title,
        startPage: startPage,
        endPage: endPage,
      );
    }
  }

  Future<void> _playPdfPage({
    required Book book,
    required int sessionId,
    required PdfPageData pageData,
    required int startPage,
    required int endPage,
    String? title,
  }) async {
    if (!_isSessionActive(sessionId)) return;

    final displayTitle = (title ?? '').trim().isEmpty
        ? '第 ${pageData.pageNumber} 页'
        : title!.trim();
    ref.read(requestedPdfPageProvider(book.id).notifier).state =
        pageData.pageNumber;
    ref.read(currentPdfChapterProvider(book.id).notifier).state =
        PdfChapterData(
      title: displayTitle,
      startPage: startPage,
      endPage: endPage,
      text: pageData.text,
    );
    _setAutoSpeechState(
      book.id,
      ReaderAutoSpeechState(
        mode: ReaderAutoSpeechMode.pdf,
        pageNumber: pageData.pageNumber,
        currentText: pageData.text,
        highlightQuery: buildPdfHighlightQuery(pageData.text),
        label: displayTitle,
      ),
    );
    ref.read(currentPdfPageProvider(book.id).notifier).state =
        pageData.pageNumber;
    setReaderExcerpt(
      bookId: book.id,
      text: pageData.text.isEmpty ? '$displayTitle 暂无可朗读文本。' : pageData.text,
    );
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!_isSessionActive(sessionId) || pageData.text.trim().isEmpty) {
      return;
    }
    await _speakBookSegmentInternal(
      bookId: book.id,
      segmentId: pageData.segmentId,
      text: pageData.text,
    );
  }

  Future<void> _speakBookSegmentInternal({
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

  void _setAutoSpeechState(String bookId, ReaderAutoSpeechState state) {
    ref.read(readerAutoSpeechProvider(bookId).notifier).state = state;
  }

  void _clearAutoSpeechState(String bookId) {
    ref.read(readerAutoSpeechProvider(bookId).notifier).state = null;
  }

  void _cancelAutoSession() {
    _sessionSerial++;
    final activeBookId = ref.read(readerActiveAutoBookIdProvider);
    if (activeBookId != null) {
      _clearAutoSpeechState(activeBookId);
    }
    ref.read(readerActiveAutoBookIdProvider.notifier).state = null;
  }

  bool _isSessionActive(int sessionId) => _sessionSerial == sessionId;
}

final readerControllerProvider = Provider(ReaderController.new);

final currentEpubChapterProvider =
    StateProvider.family<EpubChapterData?, String>((ref, bookId) => null);

final currentPdfChapterProvider =
    StateProvider.family<PdfChapterData?, String>((ref, bookId) => null);

final requestedPdfPageProvider =
    StateProvider.family<int?, String>((ref, bookId) => null);

final currentPdfPageProvider =
    StateProvider.family<int, String>((ref, bookId) => 1);

final readerAutoSpeechProvider =
    StateProvider.family<ReaderAutoSpeechState?, String>((ref, bookId) => null);

final readerActiveAutoBookIdProvider = StateProvider<String?>((ref) => null);

final pdfChapterTocProvider =
    FutureProvider.family<List<PdfChapterTocItem>, String>((ref, filePath) {
  return ref.read(pdfChapterServiceProvider).listChapters(filePath);
});

final readerSpeechStateProvider =
    StateProvider<ReaderSpeechState>((ref) => ReaderSpeechState.idle);
