import 'dart:io';

import 'package:chibook/data/models/epub_models.dart';
import 'package:epub_plus/epub_plus.dart';

class EpubService {
  const EpubService();

  Future<EpubBookData> loadBook(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final book = await EpubReader.readBook(bytes);
    final chapters = <EpubChapterData>[];
    final rootChapters = book.chapters;

    _flattenChapters(rootChapters, chapters);

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
    final book = await EpubReader.readBook(bytes);
    return (
      (book.title ?? '').trim(),
      (book.author ?? '').trim(),
    );
  }

  void _flattenChapters(
    List<EpubChapter> input,
    List<EpubChapterData> output,
    [int depth = 0]
  ) {
    for (final chapter in input) {
      final html = (chapter.htmlContent ?? '').trim();
      final plainText = _htmlToPlainText(html);

      if (html.isNotEmpty || plainText.isNotEmpty) {
        output.add(
          EpubChapterData(
            index: output.length,
            title: (chapter.title ?? '').trim().isEmpty
                ? 'Chapter ${output.length + 1}'
                : chapter.title!.trim(),
            htmlContent: html.isEmpty ? '<p>${plainText.trim()}</p>' : html,
            plainText: plainText,
            depth: depth,
          ),
        );
      }

      final children = chapter.subChapters;
      if (children.isNotEmpty) {
        _flattenChapters(children, output, depth + 1);
      }
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
}
