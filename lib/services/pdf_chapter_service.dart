import 'dart:io';

import 'package:chibook/data/models/pdf_chapter_data.dart';
import 'package:chibook/data/models/pdf_page_data.dart';
import 'package:chibook/data/models/pdf_chapter_toc_item.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfChapterService {
  static final RegExp _contentsPattern = RegExp(
    r'^(contents?|table of contents|目录)$',
    caseSensitive: false,
  );
  static final RegExp _chapterPrefixPattern = RegExp(
    r'^第\s*[0-9零一二三四五六七八九十百千万两〇IVXLCDM]+\s*[章节卷部篇回集]$',
    caseSensitive: false,
  );
  static final RegExp _chapterTitlePattern = RegExp(
    r'^第\s*[0-9零一二三四五六七八九十百千万两〇IVXLCDM]+\s*[章节卷部篇回集](?:\s*[:：\-—.．、]\s*|\s+).+$',
    caseSensitive: false,
  );
  static final RegExp _specialChapterPattern = RegExp(
    r'^(序章|楔子|前言|引言|后记|附录)(?:\s*[:：\-—.．、]\s*|\s+.*)?$',
    caseSensitive: false,
  );
  static final RegExp _englishChapterPrefixPattern = RegExp(
    r'^(chapter|part|section)\s+[0-9ivxlcdm]+$',
    caseSensitive: false,
  );
  static final RegExp _englishChapterTitlePattern = RegExp(
    r'^(chapter|part|section)\s+[0-9ivxlcdm]+\b(?:\s*[:：\-—.．]\s*|\s+).+$',
    caseSensitive: false,
  );
  static final RegExp _englishSpecialChapterPattern = RegExp(
    r'^(prologue|epilogue|preface|introduction|appendix)\b.*$',
    caseSensitive: false,
  );
  static final RegExp _tocTrailingPagePattern = RegExp(
    r'(\.{2,}|…{2,})\s*\d+\s*$',
  );
  static final RegExp _pageOnlyPattern = RegExp(r'^\d+$');

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
    final bytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      return _extractPageFromDocument(
        filePath: filePath,
        document: document,
        pageNumber: page,
      );
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
      if (outlines.isEmpty) {
        outlines.addAll(
          await _inferOutlinesFromPageHeadings(
            filePath: filePath,
            document: document,
            pageCount: pageCount,
          ),
        );
      }
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

  Future<List<_PdfOutlineEntry>> _inferOutlinesFromPageHeadings({
    required String filePath,
    required PdfDocument document,
    required int pageCount,
  }) async {
    final outlines = <_PdfOutlineEntry>[];
    String? lastAcceptedKey;
    var lastAcceptedPage = 0;

    for (var pageNumber = 1; pageNumber <= pageCount; pageNumber++) {
      final pageData = _extractPageFromDocument(
        filePath: filePath,
        document: document,
        pageNumber: pageNumber,
      );
      final heading = _detectHeading(pageData.text);
      if (heading == null) continue;

      final normalizedKey = _headingDedupKey(heading);
      final isNearDuplicate = normalizedKey == lastAcceptedKey &&
          pageNumber - lastAcceptedPage <= 2;
      if (isNearDuplicate) {
        continue;
      }

      outlines.add(
        _PdfOutlineEntry(
          title: heading,
          startPage: pageNumber,
        ),
      );
      lastAcceptedKey = normalizedKey;
      lastAcceptedPage = pageNumber;
    }

    return outlines;
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
    return _nonEmptyLines(input).join('\n');
  }

  PdfPageData _extractPageFromDocument({
    required String filePath,
    required PdfDocument document,
    required int pageNumber,
  }) {
    final cacheKey = '$filePath|page|$pageNumber';
    final cached = _pageCache[cacheKey];
    if (cached != null) return cached;

    final text = PdfTextExtractor(document).extractText(
      startPageIndex: pageNumber - 1,
      endPageIndex: pageNumber - 1,
    );
    final pageData = PdfPageData(
      pageNumber: pageNumber,
      text: _normalizeText(text),
    );
    _pageCache[cacheKey] = pageData;
    return pageData;
  }

  String? _detectHeading(String pageText) {
    final lines = _nonEmptyLines(pageText);
    if (lines.isEmpty) return null;

    final topLines = lines.take(8).toList(growable: false);
    final leadingLines = topLines.take(3);
    if (leadingLines.any((line) => _contentsPattern.hasMatch(line))) {
      return null;
    }

    for (var index = 0; index < topLines.length; index++) {
      final line = topLines[index];
      final nextLine = index + 1 < topLines.length ? topLines[index + 1] : null;
      final candidate = _headingCandidate(line, nextLine);
      if (candidate != null) {
        return candidate;
      }
    }

    return null;
  }

  String? _headingCandidate(String line, String? nextLine) {
    final normalized = _normalizeInlineWhitespace(line);
    if (!_isPotentialHeadingLine(normalized)) {
      return null;
    }

    if (_chapterTitlePattern.hasMatch(normalized) ||
        _specialChapterPattern.hasMatch(normalized) ||
        _englishChapterTitlePattern.hasMatch(normalized) ||
        _englishSpecialChapterPattern.hasMatch(normalized)) {
      return normalized;
    }

    if ((_chapterPrefixPattern.hasMatch(normalized) ||
            _englishChapterPrefixPattern.hasMatch(normalized)) &&
        nextLine != null) {
      final subtitle = _normalizeInlineWhitespace(nextLine);
      if (_isPotentialSubtitleLine(subtitle)) {
        return '$normalized $subtitle';
      }
      return normalized;
    }

    return null;
  }

  List<String> _nonEmptyLines(String input) {
    return input
        .split('\n')
        .map(_normalizeInlineWhitespace)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  String _normalizeInlineWhitespace(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isPotentialHeadingLine(String line) {
    if (line.isEmpty || line.length > 60) return false;
    if (_pageOnlyPattern.hasMatch(line)) return false;
    if (_tocTrailingPagePattern.hasMatch(line)) return false;
    if (line.endsWith('。') || line.endsWith('！') || line.endsWith('？')) {
      return false;
    }
    return true;
  }

  bool _isPotentialSubtitleLine(String line) {
    if (line.isEmpty || line.length > 36) return false;
    if (_pageOnlyPattern.hasMatch(line)) return false;
    if (_contentsPattern.hasMatch(line)) return false;
    if (_tocTrailingPagePattern.hasMatch(line)) return false;
    if (_chapterPrefixPattern.hasMatch(line) ||
        _chapterTitlePattern.hasMatch(line) ||
        _englishChapterPrefixPattern.hasMatch(line) ||
        _englishChapterTitlePattern.hasMatch(line)) {
      return false;
    }
    return true;
  }

  String _headingDedupKey(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'\s+'), '');
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
