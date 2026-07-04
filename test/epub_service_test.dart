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

  test('loads readable chapters from the spine when navigation is empty',
      () async {
    final directory = await Directory.systemTemp.createTemp('chibook-epub-');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final epubFile = File('${directory.path}/spine-only.epub');
    await epubFile.writeAsBytes(
      _epubWithEmptyNavigationAndReadableSpine(),
      flush: true,
    );

    final metadata = await const EpubService().loadImportMetadata(
      epubFile.path,
    );
    final book = await const EpubService().loadBook(epubFile.path);

    expect(metadata.title, 'Spine Only Book');
    expect(metadata.chapterCount, 2);
    expect(metadata.totalLocations, greaterThan(0));
    expect(book.chapters, hasLength(2));
    expect(book.chapters.first.title, 'First Spine Chapter');
    expect(
      book.chapters.first.plainText,
      contains('This readable chapter is only referenced by the OPF spine.'),
    );
    expect(book.chapters.last.title, 'Second Spine Chapter');
    expect(
      book.chapters.last.plainText,
      contains('The second spine chapter should also be imported.'),
    );
  });
}

List<int> _epubWithMissingCoverPage() {
  return base64Decode(
    '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',
  );
}

List<int> _epubWithEmptyNavigationAndReadableSpine() {
  return base64Decode(
    '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'
    'by54aHRtbFBLBQYAAAAABgAGAIgBAABOBQAAAAA=',
  );
}
