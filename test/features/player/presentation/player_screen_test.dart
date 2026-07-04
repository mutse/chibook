import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/player/presentation/player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps compact layout on compact widths', (tester) async {
    await _pumpPlayer(
      tester,
      windowSize: const Size(430, 900),
    );

    expect(find.byKey(const Key('player-primary-pane')), findsNothing);
    expect(find.byKey(const Key('player-secondary-pane')), findsNothing);
  });

  testWidgets('shows split panes with real content on wide widths',
      (tester) async {
    await _pumpPlayer(
      tester,
      windowSize: const Size(1024, 900),
    );

    final primaryPane = find.byKey(const Key('player-primary-pane'));
    final secondaryPane = find.byKey(const Key('player-secondary-pane'));

    expect(primaryPane, findsOneWidget);
    expect(secondaryPane, findsOneWidget);
    expect(
      find.descendant(
        of: primaryPane,
        matching: find.text('当前朗读内容'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: secondaryPane,
        matching: find.text('播放进度'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: secondaryPane,
        matching: find.text('打开原文'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses local constraints before switching to split panes',
      (tester) async {
    await _pumpPlayer(
      tester,
      windowSize: const Size(1024, 900),
      constrainedWidth: 700,
    );

    expect(find.byKey(const Key('player-primary-pane')), findsNothing);
    expect(find.byKey(const Key('player-secondary-pane')), findsNothing);
  });
}

Future<void> _pumpPlayer(
  WidgetTester tester, {
  required Size windowSize,
  double? constrainedWidth,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = windowSize;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_TestApp(constrainedWidth: constrainedWidth));
  await tester.pumpAndSettle();
}

class _TestApp extends StatelessWidget {
  const _TestApp({this.constrainedWidth});

  final double? constrainedWidth;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        bookshelfControllerProvider.overrideWith(_TestBookshelfController.new),
      ],
      child: MaterialApp(
        home: constrainedWidth == null
            ? const PlayerScreen()
            : Center(
                child: SizedBox(
                  width: constrainedWidth,
                  height: MediaQuery.sizeOf(context).height,
                  child: const PlayerScreen(),
                ),
              ),
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
