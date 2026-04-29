import 'dart:io';
import 'dart:ui';

import 'package:chibook/services/pdf_chapter_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_chapter_service_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('infers PDF chapters from page headings when bookmarks are absent',
      () async {
    final file = File('${tempDir.path}/sample.pdf');
    final document = PdfDocument();

    _addPage(
      document,
      'Chapter 1 Beginnings\n'
      'This is the first chapter body.',
    );
    _addPage(
      document,
      'More first chapter body text continues here.',
    );
    _addPage(
      document,
      'Chapter 2 Turning Point\n'
      'This is the second chapter body.',
    );
    _addPage(
      document,
      'More second chapter body text continues here.',
    );

    final bytes = await document.save();
    document.dispose();
    await file.writeAsBytes(bytes, flush: true);

    final service = PdfChapterService();
    final toc = await service.listChapters(file.path);

    expect(toc, hasLength(2));
    expect(toc[0].title, 'Chapter 1 Beginnings');
    expect(toc[0].startPage, 1);
    expect(toc[0].endPage, 2);
    expect(toc[1].title, 'Chapter 2 Turning Point');
    expect(toc[1].startPage, 3);
    expect(toc[1].endPage, 4);

    final chapter = await service.resolveCurrentChapter(
      filePath: file.path,
      pageNumber: 4,
    );

    expect(chapter.title, 'Chapter 2 Turning Point');
    expect(chapter.startPage, 3);
    expect(chapter.endPage, 4);
    expect(chapter.text, contains('second chapter body'));
  });
}

void _addPage(PdfDocument document, String text) {
  final page = document.pages.add();
  page.graphics.drawString(
    text,
    PdfStandardFont(PdfFontFamily.helvetica, 20),
    bounds: const Rect.fromLTWH(32, 32, 520, 720),
  );
}
