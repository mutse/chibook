import 'dart:io';

import 'package:chibook/data/models/pdf_chapter_data.dart';
import 'package:chibook/data/models/pdf_page_data.dart';
import 'package:chibook/data/models/pdf_chapter_toc_item.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfChapterService {
  final Map<String, _PdfChapterMeta> _metaCache = {};
  final Map<String, PdfChapterData> _chapterCache = {};
  final Map<String, PdfPageData> _pageCache = {};

  Future<PdfChapterData> resolveCurrentChapter({
    required String filePath,
    required int pageNumber,
  }) async {
    final meta = await _loadMeta(filePath);
    final page = pageNumber.clamp(1, meta.pageCount).toInt();
    final outline = _findOutlineForPage(meta.outlines, page);
    if (outline == null) {
      return _extractChapter(
        filePath: filePath,
        title: '第 $page 页',
        startPage: page,
        endPage: page,
      );
    }

    return _extractChapter(
      filePath: filePath,
      title: outline.title,
      startPage: outline.startPage,
      endPage: outline.endPage,
    );
  }

  Future<List<PdfChapterTocItem>> listChapters(String filePath) async {
    final meta = await _loadMeta(filePath);
    return meta.outlines
        .map(
          (outline) => PdfChapterTocItem(
            title: outline.title,
            startPage: outline.startPage,
            endPage: outline.endPage,
          ),
        )
        .toList(growable: false);
  }

  Future<int> pageCount(String filePath) async {
    final meta = await _loadMeta(filePath);
    return meta.pageCount;
  }

  Future<PdfPageData> extractPage({
    required String filePath,
    required int pageNumber,
  }) async {
    final meta = await _loadMeta(filePath);
    final page = pageNumber.clamp(1, meta.pageCount).toInt();
    final cacheKey = '$filePath|page|$page';
    final cached = _pageCache[cacheKey];
    if (cached != null) return cached;

    final bytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final text = PdfTextExtractor(document).extractText(
        startPageIndex: page - 1,
        endPageIndex: page - 1,
      );
      final pageData = PdfPageData(
        pageNumber: page,
        text: _normalizeText(text),
      );
      _pageCache[cacheKey] = pageData;
      return pageData;
    } finally {
      document.dispose();
    }
  }

  Future<_PdfChapterMeta> _loadMeta(String filePath) async {
    final cached = _metaCache[filePath];
    if (cached != null) return cached;

    final bytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final pageCount = document.pages.count;
      final outlines = <_PdfOutlineEntry>[];
      _flattenBookmarks(
        root: document.bookmarks,
        document: document,
        output: outlines,
      );
      outlines.sort((a, b) => a.startPage.compareTo(b.startPage));
      final resolved = _resolveOutlineRanges(outlines, pageCount);
      final meta = _PdfChapterMeta(pageCount: pageCount, outlines: resolved);
      _metaCache[filePath] = meta;
      return meta;
    } finally {
      document.dispose();
    }
  }

  void _flattenBookmarks({
    required PdfBookmarkBase root,
    required PdfDocument document,
    required List<_PdfOutlineEntry> output,
  }) {
    for (var i = 0; i < root.count; i++) {
      final bookmark = root[i];
      final title = bookmark.title.trim();
      final page = _bookmarkPageNumber(bookmark, document);
      if (title.isNotEmpty && page != null) {
        output.add(_PdfOutlineEntry(title: title, startPage: page));
      }
      if (bookmark.count > 0) {
        _flattenBookmarks(root: bookmark, document: document, output: output);
      }
    }
  }

  int? _bookmarkPageNumber(PdfBookmark bookmark, PdfDocument document) {
    final namedDestination = bookmark.namedDestination?.destination;
    final destination = bookmark.destination ?? namedDestination;
    if (destination == null) return null;
    final pageIndex = document.pages.indexOf(destination.page);
    if (pageIndex < 0) return null;
    return pageIndex + 1;
  }

  List<_PdfOutlineEntry> _resolveOutlineRanges(
    List<_PdfOutlineEntry> outlines,
    int pageCount,
  ) {
    if (outlines.isEmpty) return const [];
    final resolved = <_PdfOutlineEntry>[];
    for (var i = 0; i < outlines.length; i++) {
      final current = outlines[i];
      final next = i + 1 < outlines.length ? outlines[i + 1] : null;
      final endPage = next == null
          ? pageCount
          : (next.startPage - 1).clamp(current.startPage, pageCount);
      resolved.add(
        _PdfOutlineEntry(
          title: current.title,
          startPage: current.startPage,
          endPageInclusive: endPage,
        ),
      );
    }
    return resolved;
  }

  _PdfOutlineEntry? _findOutlineForPage(
    List<_PdfOutlineEntry> outlines,
    int pageNumber,
  ) {
    _PdfOutlineEntry? candidate;
    for (final outline in outlines) {
      if (outline.startPage > pageNumber) break;
      if (pageNumber >= outline.startPage && pageNumber <= outline.endPage) {
        candidate = outline;
      }
    }
    return candidate;
  }

  Future<PdfChapterData> _extractChapter({
    required String filePath,
    required String title,
    required int startPage,
    required int endPage,
  }) async {
    final cacheKey = '$filePath|$startPage|$endPage|$title';
    final cached = _chapterCache[cacheKey];
    if (cached != null) return cached;

    final bytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final text = PdfTextExtractor(document).extractText(
        startPageIndex: startPage - 1,
        endPageIndex: endPage - 1,
      );
      final chapter = PdfChapterData(
        title: title,
        startPage: startPage,
        endPage: endPage,
        text: _normalizeText(text),
      );
      _chapterCache[cacheKey] = chapter;
      return chapter;
    } finally {
      document.dispose();
    }
  }

  String _normalizeText(String input) {
    final lines = input
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines.join('\n');
  }
}

class _PdfChapterMeta {
  const _PdfChapterMeta({
    required this.pageCount,
    required this.outlines,
  });

  final int pageCount;
  final List<_PdfOutlineEntry> outlines;
}

class _PdfOutlineEntry {
  const _PdfOutlineEntry({
    required this.title,
    required this.startPage,
    this.endPageInclusive,
  });

  final String title;
  final int startPage;
  final int? endPageInclusive;

  int get endPage => endPageInclusive ?? startPage;
}
