import 'dart:io';
import 'dart:typed_data';

import 'package:chibook/data/models/epub_models.dart';
import 'package:epub_plus/epub_plus.dart';
import 'package:image/image.dart' as img;

class EpubService {
  const EpubService();

  Future<EpubBookData> loadBook(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final book = await EpubReader.openBook(bytes);
    final chapters = await _readReadableChapters(book);

    return EpubBookData(
      title: (book.title ?? '').trim(),
      author: (book.author ?? '').trim(),
      chapters: chapters.isEmpty
          ? const [
              EpubChapterData(
                index: 0,
                title: 'Untitled Chapter',
                htmlContent: '<p>No readable chapter content was found.</p>',
                plainText: 'No readable chapter content was found.',
              ),
            ]
          : chapters,
    );
  }

  Future<(String title, String author)?> loadMetadata(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final book = await EpubReader.openBook(bytes);
    return (
      (book.title ?? '').trim(),
      (book.author ?? '').trim(),
    );
  }

  Future<EpubImportMetadata> loadImportMetadata(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final book = await EpubReader.openBook(bytes);
    final chapters = await _readReadableChapters(book);
    final plainTextLength = chapters.fold<int>(
      0,
      (sum, chapter) => sum + chapter.plainText.runes.length,
    );
    final languageCode =
        book.schema?.package?.metadata?.languages.isNotEmpty == true
            ? book.schema!.package!.metadata!.languages.first.trim()
            : null;

    return EpubImportMetadata(
      title: (book.title ?? '').trim(),
      author: (book.author ?? '').trim(),
      chapterCount: chapters.length,
      totalLocations: plainTextLength,
      languageCode:
          languageCode == null || languageCode.isEmpty ? null : languageCode,
      coverBytes: _encodeCoverImage(await _readCoverImageSafely(book)),
    );
  }

  Future<List<EpubChapterData>> _readReadableChapters(
    EpubBookRef book,
  ) async {
    final chapters = <EpubChapterData>[];
    final navigationPoints = book.schema?.navigation?.navMap?.points;
    if (navigationPoints != null && navigationPoints.isNotEmpty) {
      await _readNavigationPoints(
        book: book,
        input: navigationPoints,
        output: chapters,
      );
    }

    return chapters.isEmpty ? await _readSpineChapters(book) : chapters;
  }

  Future<List<EpubChapterData>> _readSpineChapters(EpubBookRef book) async {
    final package = book.schema?.package;
    final spineItems = package?.spine?.items ?? const [];
    final manifestItems = package?.manifest?.items ?? const [];
    final htmlFiles = book.content?.html ?? const {};
    final chapters = <EpubChapterData>[];

    for (final spineItem in spineItems) {
      final idRef = spineItem.idRef;
      if (idRef == null || idRef.trim().isEmpty) continue;

      String? href;
      for (final manifestItem in manifestItems) {
        if (manifestItem.id?.toLowerCase() == idRef.toLowerCase()) {
          href = manifestItem.href;
          break;
        }
      }
      if (href == null || href.trim().isEmpty) continue;

      final htmlRef = htmlFiles[href] ?? htmlFiles[Uri.decodeFull(href)];
      if (htmlRef == null) continue;

      final html = (await _readHtmlSafely(htmlRef)).trim();
      if (html.isEmpty) continue;

      final plainText = _htmlToPlainText(html);
      if (plainText.isEmpty) continue;

      final index = chapters.length;
      chapters.add(
        EpubChapterData(
          index: index,
          title: _htmlDocumentTitle(html, index),
          htmlContent: html,
          plainText: plainText,
        ),
      );
    }

    return chapters;
  }

  Future<void> _readNavigationPoints({
    required EpubBookRef book,
    required List<EpubNavigationPoint> input,
    required List<EpubChapterData> output,
    int depth = 0,
  }) async {
    for (final point in input) {
      final source = point.content?.source;
      if (source == null || source.trim().isEmpty) continue;

      final fileName = _contentFileNameFromNavigationSource(source);
      final htmlRef = book.content?.html[fileName];
      if (htmlRef != null) {
        final html = (await _readHtmlSafely(htmlRef)).trim();
        if (html.isNotEmpty) {
          final plainText = _htmlToPlainText(html);
          output.add(
            EpubChapterData(
              index: output.length,
              title: _navigationPointTitle(point, output.length),
              htmlContent: html,
              plainText: plainText,
              depth: depth,
            ),
          );
        }
      }

      final children = point.childNavigationPoints;
      if (children.isNotEmpty) {
        await _readNavigationPoints(
          book: book,
          input: children,
          output: output,
          depth: depth + 1,
        );
      }
    }
  }

  String _contentFileNameFromNavigationSource(String source) {
    final anchorIndex = source.indexOf('#');
    final fileName =
        anchorIndex == -1 ? source : source.substring(0, anchorIndex);
    return Uri.decodeFull(fileName);
  }

  String _navigationPointTitle(EpubNavigationPoint point, int index) {
    final label = point.navigationLabels.isEmpty
        ? null
        : point.navigationLabels.first.text;
    final title = label?.trim();
    return title == null || title.isEmpty ? 'Chapter ${index + 1}' : title;
  }

  String _htmlDocumentTitle(String html, int index) {
    final titleMatch = RegExp(
      r'<\s*(?:h1|h2|title)\b[^>]*>(.*?)<\s*/\s*(?:h1|h2|title)\s*>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    final title =
        titleMatch == null ? '' : _htmlToPlainText(titleMatch.group(1) ?? '');
    return title.isEmpty ? 'Chapter ${index + 1}' : title;
  }

  Future<String> _readHtmlSafely(dynamic htmlRef) async {
    try {
      final content = await htmlRef.readContentAsync();
      return content is String ? content : '';
    } catch (_) {
      return '';
    }
  }

  Future<img.Image?> _readCoverImageSafely(EpubBookRef book) async {
    try {
      return await book.readCover();
    } catch (_) {
      return null;
    }
  }

  String _htmlToPlainText(String html) {
    if (html.isEmpty) return '';
    final withBreaks = html
        .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</\s*div\s*>', caseSensitive: false), '\n');
    final stripped = withBreaks.replaceAll(RegExp(r'<[^>]+>'), ' ');
    return stripped
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  Uint8List? _encodeCoverImage(img.Image? image) {
    if (image == null) return null;
    return Uint8List.fromList(img.encodePng(image));
  }
}

class EpubImportMetadata {
  const EpubImportMetadata({
    required this.title,
    required this.author,
    required this.chapterCount,
    required this.totalLocations,
    this.languageCode,
    this.coverBytes,
  });

  final String title;
  final String author;
  final int chapterCount;
  final int totalLocations;
  final String? languageCode;
  final Uint8List? coverBytes;
}
