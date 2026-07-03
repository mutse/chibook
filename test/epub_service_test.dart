import 'dart:convert';
import 'dart:io';

import 'package:chibook/services/epub_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'loads import metadata when EPUB navigation references a missing cover page',
    () async {
      final directory = await Directory.systemTemp.createTemp('chibook-epub-');
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final epubFile = File('${directory.path}/missing-cover-page.epub');
      await epubFile.writeAsBytes(
        _epubWithMissingCoverPage(),
        flush: true,
      );

      final metadata = await const EpubService().loadImportMetadata(
        epubFile.path,
      );
      final book = await const EpubService().loadBook(epubFile.path);

      expect(metadata.title, 'Broken Cover Reference');
      expect(metadata.author, 'Test Author');
      expect(metadata.chapterCount, 1);
      expect(metadata.totalLocations, greaterThan(0));
      expect(metadata.languageCode, 'en');
      expect(book.chapters, hasLength(1));
      expect(book.chapters.single.title, 'Readable Chapter');
      expect(
        book.chapters.single.plainText,
        contains('This chapter should still be imported.'),
      );
    },
  );
}

List<int> _epubWithMissingCoverPage() {
  return base64Decode(
    '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',
  );
}
