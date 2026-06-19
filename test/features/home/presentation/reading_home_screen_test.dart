import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/home/presentation/reading_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows split home panes on wide widths', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _TestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-wide-primary-pane')), findsOneWidget);
    expect(find.byKey(const Key('home-wide-secondary-pane')), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        bookshelfControllerProvider.overrideWith(_TestBookshelfController.new),
      ],
      child: const MaterialApp(
        home: ReadingHomeScreen(),
      ),
    );
  }
}

class _TestBookshelfController extends BookshelfController {
  @override
  Future<List<Book>> build() async => [_testBook];
}

final _testBook = Book(
  id: 'book-1',
  title: 'Wide Layout Handbook',
  author: 'Layout Team',
  filePath: '/tmp/wide-layout.epub',
  originalFileName: 'wide-layout.epub',
  format: BookFormat.epub,
  importedAt: DateTime(2026, 6, 1),
  fileHash: 'hash-1',
  fileSizeBytes: 2048,
  progress: 0.35,
  chapterCount: 12,
  totalLocations: 240,
  lastReadLocation: 'Chapter 4',
  pageCount: 180,
  lastReadAt: DateTime(2026, 6, 18),
);
