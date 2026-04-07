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

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(readerControllerProvider);
    ref.listen<int?>(requestedPdfPageProvider(widget.book.id), (_, nextPage) {
      if (nextPage == null || nextPage == _activePageNumber) return;
      _pdfViewerController.jumpToPage(nextPage);
      ref.read(requestedPdfPageProvider(widget.book.id).notifier).state = null;
    });

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
              onDocumentLoaded: (_) {
                _syncCurrentChapter(1);
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
    ref.read(currentPdfChapterProvider(widget.book.id).notifier).state =
        chapter;
    ref.read(readerControllerProvider).setReaderExcerpt(
          bookId: widget.book.id,
          text: chapter.text.isEmpty
              ? '${widget.book.title} 当前页暂无可朗读文本。'
              : chapter.text,
        );
  }
}
