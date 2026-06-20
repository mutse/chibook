import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/player/presentation/player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows split panes on wide widths', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _TestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('player-primary-pane')), findsOneWidget);
    expect(find.byKey(const Key('player-secondary-pane')), findsOneWidget);
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
        home: PlayerScreen(),
      ),
    );
  }
}

class _TestBookshelfController extends BookshelfController {
  @override
  Future<List<Book>> build() async => [_testBook];
}

final _testBook = Book(
  id: 'player-book-1',
  title: 'Wide Player Patterns',
  author: 'Adaptive Team',
  filePath: '/tmp/wide-player.epub',
  originalFileName: 'wide-player.epub',
  format: BookFormat.epub,
  importedAt: DateTime(2026, 6, 1),
  fileHash: 'player-hash-1',
  fileSizeBytes: 4096,
  progress: 0.4,
  chapterCount: 18,
  totalLocations: 360,
  lastReadLocation: 'Chapter 6',
  pageCount: 240,
  lastReadAt: DateTime(2026, 6, 19),
);
