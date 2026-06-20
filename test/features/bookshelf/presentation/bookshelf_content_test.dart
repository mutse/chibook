import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/presentation/widgets/bookshelf_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows expanded grid on wide widths', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookshelfContent(
            books: List.generate(4, _buildBook),
            onImport: () async {},
            onRemoveBook: (_) async {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(find.byKey(const Key('bookshelf-grid-expanded')), findsOneWidget);
    expect(delegate.crossAxisCount, 3);
  });

  testWidgets('keeps compact widths on the list path by default', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookshelfContent(
            books: List.generate(4, _buildBook),
            onImport: () async {},
            onRemoveBook: (_) async {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bookshelf-grid-expanded')), findsNothing);
    expect(find.byType(SliverGrid), findsNothing);
    expect(find.byType(SliverList), findsWidgets);
  });
}

Book _buildBook(int index) => Book(
      id: 'book-$index',
      title: 'Wide Layout Handbook $index',
      author: 'Layout Team',
      filePath: '/tmp/wide-layout-$index.epub',
      originalFileName: 'wide-layout-$index.epub',
      format: BookFormat.epub,
      importedAt: DateTime(2026, 6, 1),
      fileHash: 'hash-$index',
      fileSizeBytes: 2048,
      progress: 0.35,
      chapterCount: 12,
      totalLocations: 240,
      lastReadLocation: 'Chapter 4',
      pageCount: 180,
      lastReadAt: DateTime(2026, 6, 18),
    );
