import 'dart:io';

import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:chibook/features/reader/presentation/widgets/pdf_selection_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfReaderView extends ConsumerStatefulWidget {
  const PdfReaderView({
    super.key,
    required this.book,
    this.compact = false,
  });

  final Book book;
  final bool compact;

  @override
  ConsumerState<PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends ConsumerState<PdfReaderView> {
  late final PdfViewerController _pdfViewerController;
  String _selectedText = '';
  int _activePageNumber = 1;
  PdfTextSearchResult? _searchResult;
  String _lastHighlightQuery = '';
  int? _lastHighlightPage;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  @override
  void dispose() {
    _searchResult?.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(readerControllerProvider);
    final autoSpeech = ref.watch(readerAutoSpeechProvider(widget.book.id));
    ref.listen<int?>(requestedPdfPageProvider(widget.book.id), (_, nextPage) {
      if (nextPage == null || nextPage == _activePageNumber) return;
      _pdfViewerController.jumpToPage(nextPage);
      ref.read(requestedPdfPageProvider(widget.book.id).notifier).state = null;
    });
    ref.listen<ReaderAutoSpeechState?>(
      readerAutoSpeechProvider(widget.book.id),
      (_, next) {
        if (next == null || next.mode != ReaderAutoSpeechMode.pdf) {
          _clearAutoHighlight();
          return;
        }
        final targetPage = next.pageNumber;
        if (targetPage != null && targetPage != _activePageNumber) {
          _pdfViewerController.jumpToPage(targetPage);
        }
        final query = next.highlightQuery?.trim() ?? '';
        if (query.isEmpty ||
            (query == _lastHighlightQuery &&
                targetPage == _lastHighlightPage)) {
          return;
        }
        _lastHighlightQuery = query;
        _lastHighlightPage = targetPage;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || query.isEmpty) return;
          _applyAutoHighlight(query);
        });
      },
    );

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.compact ? 20 : 28),
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, widget.compact ? 8 : 12),
            child: SfPdfViewer.file(
              File(widget.book.filePath),
              controller: _pdfViewerController,
              interactionMode: PdfInteractionMode.selection,
              enableTextSelection: true,
              canShowTextSelectionMenu: true,
              onDocumentLoaded: (details) {
                final currentPage =
                    ref.read(currentPdfPageProvider(widget.book.id));
                final requestedPage =
                    ref.read(requestedPdfPageProvider(widget.book.id));
                final targetPage = requestedPage ?? currentPage;
                final initialPage =
                    targetPage.clamp(1, details.document.pages.count).toInt();
                _activePageNumber = initialPage;
                ref
                    .read(currentPdfPageProvider(widget.book.id).notifier)
                    .state = initialPage;
                if (initialPage != 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _pdfViewerController.jumpToPage(initialPage);
                    ref
                        .read(requestedPdfPageProvider(widget.book.id).notifier)
                        .state = null;
                  });
                }
                _syncCurrentChapter(initialPage);
              },
              onTextSelectionChanged: (details) {
                final nextText = details.selectedText?.trim() ?? '';
                setState(() {
                  _selectedText = nextText;
                });
                if (_selectedText.isNotEmpty) {
                  controller.setReaderExcerpt(
                    bookId: widget.book.id,
                    text: _selectedText,
                  );
                } else {
                  _syncCurrentChapter(_activePageNumber);
                }
              },
              onTap: (_) {
                if (_selectedText.isEmpty) return;
                setState(() => _selectedText = '');
                _syncCurrentChapter(_activePageNumber);
              },
              onPageChanged: (details) {
                _activePageNumber = details.newPageNumber;
                ref
                    .read(currentPdfPageProvider(widget.book.id).notifier)
                    .state = details.newPageNumber;
                final totalPages = _pdfViewerController.pageCount;
                final percentage = totalPages <= 0
                    ? 0.0
                    : (details.newPageNumber / totalPages)
                        .clamp(0.0, 1.0)
                        .toDouble();
                controller.updateProgress(
                  bookId: widget.book.id,
                  location: 'page:${details.newPageNumber}',
                  percentage: percentage,
                );
                if (_selectedText.isEmpty) {
                  _syncCurrentChapter(details.newPageNumber);
                }
              },
            ),
          ),
        ),
        if (autoSpeech?.mode == ReaderAutoSpeechMode.pdf &&
            (autoSpeech?.label?.isNotEmpty ?? false))
          Positioned(
            top: 20,
            right: 20,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xCC18211D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      '自动朗读中：${autoSpeech!.label}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_selectedText.isNotEmpty)
          Align(
            alignment: Alignment.bottomCenter,
            child: PdfSelectionToolbar(
              selectedText: _selectedText,
              onReadAloud: () {
                controller.speakBookSegment(
                  bookId: widget.book.id,
                  segmentId: 'pdf-selection',
                  text: _selectedText,
                );
              },
              onClear: () {
                setState(() => _selectedText = '');
                _syncCurrentChapter(_activePageNumber);
              },
            ),
          ),
      ],
    );
  }

  Future<void> _syncCurrentChapter(int pageNumber) async {
    final requestPageNumber = pageNumber;
    final chapter =
        await ref.read(pdfChapterServiceProvider).resolveCurrentChapter(
              filePath: widget.book.filePath,
              pageNumber: pageNumber,
            );
    if (!mounted || requestPageNumber != _activePageNumber) return;
    final autoSpeech = ref.read(readerAutoSpeechProvider(widget.book.id));
    ref.read(currentPdfChapterProvider(widget.book.id).notifier).state =
        chapter;
    ref.read(readerControllerProvider).setReaderExcerpt(
          bookId: widget.book.id,
          text: autoSpeech?.mode == ReaderAutoSpeechMode.pdf &&
                  autoSpeech?.pageNumber == pageNumber &&
                  autoSpeech?.currentText.trim().isNotEmpty == true
              ? autoSpeech!.currentText
              : chapter.text.isEmpty
                  ? '${widget.book.title} 当前页暂无可朗读文本。'
                  : chapter.text,
        );
  }

  void _applyAutoHighlight(String query) {
    _searchResult?.clear();
    _searchResult = _pdfViewerController.searchText(query);
  }

  void _clearAutoHighlight() {
    _lastHighlightQuery = '';
    _lastHighlightPage = null;
    _searchResult?.clear();
    _searchResult = null;
  }
}
