# iPad Adaptive Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real iPad large-screen support to the core app flows with a sidebar shell on wide layouts and clean compact fallbacks for narrow widths.

**Architecture:** Introduce a shared adaptive layout layer in `lib/app/adaptive/`, switch `AppShell` between compact and wide navigation chrome based on width, and progressively migrate the core screens to use shared spacing, max-width, grid, and split-pane helpers. Keep the existing `GoRouter` branch structure and feature providers intact so the change remains mostly presentational.

**Tech Stack:** Flutter, Material 3, Riverpod, GoRouter, Flutter widget tests

---

## File Map

### New files

- `lib/app/adaptive/adaptive_layout.dart`
  - Central breakpoint model, width classification, adaptive spacing helpers, column-count rules, and a context accessor.
- `lib/app/adaptive/adaptive_content.dart`
  - Shared containers for max-width content, wide page gutters, and reusable split-pane layout.
- `lib/features/navigation/presentation/widgets/app_sidebar.dart`
  - Tablet sidebar navigation UI and mini-player placement for wide shells.
- `lib/features/bookshelf/presentation/widgets/bookshelf_content.dart`
  - Public presentational bookshelf body so adaptive grid behavior can be tested without provider plumbing.
- `test/app/adaptive/adaptive_layout_test.dart`
  - Unit tests for breakpoint classification and column-count rules.
- `test/features/navigation/presentation/app_shell_test.dart`
  - Widget tests for compact vs wide navigation shell behavior.
- `test/features/home/presentation/reading_home_screen_test.dart`
  - Widget test for Home wide-layout pane switching.
- `test/features/bookshelf/presentation/bookshelf_content_test.dart`
  - Widget tests for bookshelf wide-grid behavior.
- `test/features/player/presentation/player_screen_test.dart`
  - Widget test for Player wide-layout pane switching.

### Modified files

- `lib/features/navigation/presentation/app_shell.dart`
  - Delegate shell chrome to compact bottom bar vs wide sidebar layout.
- `lib/features/home/presentation/reading_home_screen.dart`
  - Use adaptive page containers and wide content split.
- `lib/features/bookshelf/presentation/bookshelf_screen.dart`
  - Delegate body rendering to `BookshelfContent`.
- `lib/features/discover/presentation/discover_screen.dart`
  - Use adaptive page containers and multi-column section rhythm.
- `lib/features/player/presentation/player_screen.dart`
  - Use split-pane layout on wide widths.
- `lib/features/reader/presentation/reader_screen.dart`
  - Constrain reading width and improve wide-width accessory layout.

## Task 1: Build the Adaptive Foundation

**Files:**
- Create: `lib/app/adaptive/adaptive_layout.dart`
- Create: `lib/app/adaptive/adaptive_content.dart`
- Test: `test/app/adaptive/adaptive_layout_test.dart`

- [ ] **Step 1: Write the failing adaptive breakpoint tests**

```dart
import 'package:chibook/app/adaptive/adaptive_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptiveLayoutData.fromWidth', () {
    test('returns compact for phone widths', () {
      final layout = AdaptiveLayoutData.fromWidth(430);

      expect(layout.sizeClass, AdaptiveSizeClass.compact);
      expect(layout.showsSidebar, isFalse);
    });

    test('returns medium for narrow tablet widths', () {
      final layout = AdaptiveLayoutData.fromWidth(900);

      expect(layout.sizeClass, AdaptiveSizeClass.medium);
      expect(layout.showsSidebar, isTrue);
    });

    test('returns expanded for full tablet widths', () {
      final layout = AdaptiveLayoutData.fromWidth(1180);

      expect(layout.sizeClass, AdaptiveSizeClass.expanded);
      expect(layout.contentMaxWidth, 1100);
    });
  });

  test('adaptive column count scales with width', () {
    expect(
      AdaptiveLayoutData.fromWidth(430).adaptiveColumns(
        compact: 1,
        medium: 2,
        expanded: 4,
      ),
      1,
    );
    expect(
      AdaptiveLayoutData.fromWidth(900).adaptiveColumns(
        compact: 1,
        medium: 2,
        expanded: 4,
      ),
      2,
    );
    expect(
      AdaptiveLayoutData.fromWidth(1180).adaptiveColumns(
        compact: 1,
        medium: 2,
        expanded: 4,
      ),
      4,
    );
  });
}
```

- [ ] **Step 2: Run the adaptive tests to verify they fail**

Run: `/Users/mutse/development/flutter/bin/flutter test test/app/adaptive/adaptive_layout_test.dart`

Expected: FAIL with import errors because `lib/app/adaptive/adaptive_layout.dart` does not exist yet.

- [ ] **Step 3: Implement the adaptive layout primitives**

```dart
import 'package:flutter/material.dart';

enum AdaptiveSizeClass { compact, medium, expanded }

class AdaptiveLayoutData {
  const AdaptiveLayoutData({
    required this.width,
    required this.sizeClass,
    required this.horizontalPadding,
    required this.contentMaxWidth,
  });

  factory AdaptiveLayoutData.fromWidth(double width) {
    if (width >= 1100) {
      return AdaptiveLayoutData(
        width: width,
        sizeClass: AdaptiveSizeClass.expanded,
        horizontalPadding: 32,
        contentMaxWidth: 1100,
      );
    }
    if (width >= 840) {
      return AdaptiveLayoutData(
        width: width,
        sizeClass: AdaptiveSizeClass.medium,
        horizontalPadding: 24,
        contentMaxWidth: 960,
      );
    }
    return AdaptiveLayoutData(
      width: width,
      sizeClass: AdaptiveSizeClass.compact,
      horizontalPadding: 20,
      contentMaxWidth: 720,
    );
  }

  final double width;
  final AdaptiveSizeClass sizeClass;
  final double horizontalPadding;
  final double contentMaxWidth;

  bool get showsSidebar => sizeClass != AdaptiveSizeClass.compact;
  bool get isCompact => sizeClass == AdaptiveSizeClass.compact;

  int adaptiveColumns({
    required int compact,
    required int medium,
    required int expanded,
  }) {
    return switch (sizeClass) {
      AdaptiveSizeClass.compact => compact,
      AdaptiveSizeClass.medium => medium,
      AdaptiveSizeClass.expanded => expanded,
    };
  }
}

extension AdaptiveLayoutContext on BuildContext {
  AdaptiveLayoutData get adaptiveLayout {
    return AdaptiveLayoutData.fromWidth(MediaQuery.sizeOf(this).width);
  }
}
```

```dart
import 'package:chibook/app/adaptive/adaptive_layout.dart';
import 'package:flutter/material.dart';

class AdaptiveContentContainer extends StatelessWidget {
  const AdaptiveContentContainer({
    super.key,
    required this.child,
    this.maxWidth,
  });

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final layout = context.adaptiveLayout;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? layout.contentMaxWidth,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: layout.horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}

class AdaptiveTwoPane extends StatelessWidget {
  const AdaptiveTwoPane({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryFlex = 3,
    this.secondaryFlex = 2,
    this.spacing = 24,
  });

  final Widget primary;
  final Widget secondary;
  final int primaryFlex;
  final int secondaryFlex;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final layout = context.adaptiveLayout;
    if (layout.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          SizedBox(height: spacing),
          secondary,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: primaryFlex, child: primary),
        SizedBox(width: spacing),
        Expanded(flex: secondaryFlex, child: secondary),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the adaptive tests to verify they pass**

Run: `/Users/mutse/development/flutter/bin/flutter test test/app/adaptive/adaptive_layout_test.dart`

Expected: PASS with 4 passing tests covering size class and adaptive column rules.

- [ ] **Step 5: Commit the adaptive foundation**

```bash
git add lib/app/adaptive/adaptive_layout.dart lib/app/adaptive/adaptive_content.dart test/app/adaptive/adaptive_layout_test.dart
git commit -m "Add adaptive layout foundation"
```

## Task 2: Refactor AppShell for Compact and Wide Navigation

**Files:**
- Modify: `lib/features/navigation/presentation/app_shell.dart`
- Create: `lib/features/navigation/presentation/widgets/app_sidebar.dart`
- Test: `test/features/navigation/presentation/app_shell_test.dart`

- [ ] **Step 1: Write failing shell tests for compact and wide widths**

```dart
Widget _buildShellHarness() {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const Scaffold(body: Text('HOME')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookshelf',
                builder: (_, __) => const Scaffold(body: Text('BOOKSHELF')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/player',
                builder: (_, __) => const Scaffold(body: Text('PLAYER')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (_, __) => const Scaffold(body: Text('DISCOVER')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const Scaffold(body: Text('PROFILE')),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(routerConfig: router),
  );
}

testWidgets('uses bottom navigation in compact layouts', (tester) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_buildShellHarness());
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('app-shell-bottom-nav')), findsOneWidget);
  expect(find.byKey(const Key('app-shell-sidebar')), findsNothing);
});

testWidgets('uses sidebar navigation in wide layouts', (tester) async {
  tester.view.physicalSize = const Size(1024, 1366);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_buildShellHarness());
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('app-shell-sidebar')), findsOneWidget);
  expect(find.byKey(const Key('app-shell-bottom-nav')), findsNothing);
});
```

- [ ] **Step 2: Run the shell tests to verify they fail**

Run: `/Users/mutse/development/flutter/bin/flutter test test/features/navigation/presentation/app_shell_test.dart`

Expected: FAIL because the shell does not expose adaptive keys or a wide sidebar layout yet.

- [ ] **Step 3: Implement the adaptive shell and sidebar**

```dart
return LayoutBuilder(
  builder: (context, constraints) {
    final layout = AdaptiveLayoutData.fromWidth(constraints.maxWidth);
    final shellBody = navigationShell;

    if (!layout.showsSidebar) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: shellBody,
        bottomNavigationBar: SafeArea(
          key: const Key('app-shell-bottom-nav'),
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _CompactBottomBar(
            navigationShell: navigationShell,
            currentBook: currentBook,
            autoSpeechLabel: autoSpeech?.label,
            speechState: speechState,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Row(
          children: [
            AppSidebar(
              key: const Key('app-shell-sidebar'),
              navigationShell: navigationShell,
              currentBook: currentBook,
              autoSpeechLabel: autoSpeech?.label,
              speechState: speechState,
            ),
            Expanded(child: shellBody),
          ],
        ),
      ),
    );
  },
);
```

```dart
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.navigationShell,
    required this.currentBook,
    required this.autoSpeechLabel,
    required this.speechState,
  });

  final StatefulNavigationShell navigationShell;
  final Book? currentBook;
  final String? autoSpeechLabel;
  final ReaderSpeechState speechState;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          children: [
            Expanded(
              child: LiquidGlassCard(
                child: Column(
                  children: [
                    for (var index = 0; index < _destinations.length; index++)
                      _SidebarNavItem(
                        destination: _destinations[index],
                        selected: navigationShell.currentIndex == index,
                        onTap: () => navigationShell.goBranch(index),
                      ),
                  ],
                ),
              ),
            ),
            if (currentBook != null) ...[
              const SizedBox(height: 12),
              _MiniPlayerBar(
                book: currentBook!,
                label: autoSpeechLabel ?? estimatedListenLabel(currentBook!),
                speechState: speechState,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the shell tests to verify they pass**

Run: `/Users/mutse/development/flutter/bin/flutter test test/features/navigation/presentation/app_shell_test.dart`

Expected: PASS with compact and wide navigation shell assertions succeeding.

- [ ] **Step 5: Commit the adaptive shell**

```bash
git add lib/features/navigation/presentation/app_shell.dart lib/features/navigation/presentation/widgets/app_sidebar.dart test/features/navigation/presentation/app_shell_test.dart
git commit -m "Add adaptive iPad app shell"
```

## Task 3: Migrate Home and Discover to Shared Wide Layout Containers

**Files:**
- Modify: `lib/features/home/presentation/reading_home_screen.dart`
- Modify: `lib/features/discover/presentation/discover_screen.dart`
- Test: `test/features/home/presentation/reading_home_screen_test.dart`
- Reuse: `lib/app/adaptive/adaptive_content.dart`

- [ ] **Step 1: Write a failing Home layout test for wide widths**

```dart
class _FakeBookshelfController extends BookshelfController {
  _FakeBookshelfController(this.books);

  final List<Book> books;

  @override
  Future<List<Book>> build() async => books;
}

Book _sampleBook({required String id, required String title}) {
  return Book(
    id: id,
    title: title,
    author: 'Author $id',
    filePath: '/tmp/$id.epub',
    originalFileName: '$title.epub',
    format: BookFormat.epub,
    importedAt: DateTime(2026, 6, 1),
    fileHash: 'hash-$id',
    fileSizeBytes: 1024,
    progress: 0.35,
  );
}

Widget _buildBooksProviderHarness({
  required Widget child,
  required List<Book> books,
}) {
  return ProviderScope(
    overrides: [
      bookshelfControllerProvider.overrideWith(
        () => _FakeBookshelfController(books),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

testWidgets('home uses a two-pane dashboard on wide layouts', (tester) async {
  tester.view.physicalSize = const Size(1024, 1366);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _buildBooksProviderHarness(
      child: const ReadingHomeScreen(),
      books: [_sampleBook(id: '1', title: '深度工作')],
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('home-wide-primary-pane')), findsOneWidget);
  expect(find.byKey(const Key('home-wide-secondary-pane')), findsOneWidget);
});
```

- [ ] **Step 2: Run the Home layout test to verify it fails**

Run: `/Users/mutse/development/flutter/bin/flutter test test/features/home/presentation/reading_home_screen_test.dart`

Expected: FAIL because the home screen does not yet emit adaptive pane keys.

- [ ] **Step 3: Implement wide Home and Discover compositions**

```dart
class _HomeSummaryPanel extends StatelessWidget {
  const _HomeSummaryPanel({required this.summaryBooks});

  final List<Book> summaryBooks;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '阅读摘要',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          for (final book in summaryBooks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('${book.title} · ${progressLabel(book)}'),
            ),
        ],
      ),
    );
  }
}

return CustomScrollView(
  physics: const BouncingScrollPhysics(),
  slivers: [
    SliverToBoxAdapter(
      child: AdaptiveContentContainer(
        child: AdaptiveTwoPane(
          primary: Column(
            key: const Key('home-wide-primary-pane'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeHeader(onImport: () => _importBook(context, ref)),
              const SizedBox(height: 18),
              AppSearchBar(
                hint: '搜索书名 / 作者 / 关键词',
                controller: searchController,
                onChanged: onSearchChanged,
                trailing: hasQuery
                    ? GestureDetector(
                        onTap: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF6F7EA8),
                        ),
                      )
                    : const Icon(
                        Icons.mic_none_rounded,
                        color: Color(0xFF6F7EA8),
                      ),
              ),
              const SizedBox(height: 18),
              _HeroCard(
                book: featured,
                booksCount: books.length,
                onImport: () => _importBook(context, ref),
                onListen: featured == null
                    ? null
                    : () async {
                        await ref
                            .read(readerControllerProvider)
                            .playAutoForCurrentBook(featured);
                        if (!context.mounted) return;
                        context.go('/player');
                      },
              ),
              const SizedBox(height: 18),
              _ContinueListeningCard(book: continueBook!),
            ],
          ),
          secondary: Column(
            key: const Key('home-wide-secondary-pane'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QuickActions(
                featured: featured,
                onImport: () => _importBook(context, ref),
              ),
              const SizedBox(height: 16),
              _HomeSummaryPanel(summaryBooks: summaryBooks),
            ],
          ),
        ),
      ),
    ),
  ],
);
```

```dart
return CustomScrollView(
  physics: const BouncingScrollPhysics(),
  slivers: [
    SliverToBoxAdapter(
      child: AdaptiveContentContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发现',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '基于你的本地书库整理最近导入、在读和已完成内容。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _importBook(context, ref),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 280,
                  child: _MetricTile(label: '本地书籍', value: '${books.length}'),
                ),
                SizedBox(
                  width: 280,
                  child: _MetricTile(
                    label: '在读',
                    value: '${continueReading.length}',
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: _MetricTile(
                    label: '已缓存',
                    value:
                        '${ref.watch(audioCacheEntriesProvider).valueOrNull?.length ?? 0}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ],
);
```

- [ ] **Step 4: Run the Home layout test to verify it passes**

Run: `/Users/mutse/development/flutter/bin/flutter test test/features/home/presentation/reading_home_screen_test.dart`

Expected: PASS with the wide Home pane keys present under tablet-sized widths.

- [ ] **Step 5: Commit the adaptive Home and Discover layouts**

```bash
git add lib/features/home/presentation/reading_home_screen.dart lib/features/discover/presentation/discover_screen.dart test/features/home/presentation/reading_home_screen_test.dart
git commit -m "Adapt home and discover for wide layouts"
```

## Task 4: Extract and Adapt the Bookshelf Wide Grid Layout

**Files:**
- Modify: `lib/features/bookshelf/presentation/bookshelf_screen.dart`
- Create: `lib/features/bookshelf/presentation/widgets/bookshelf_content.dart`
- Test: `test/features/bookshelf/presentation/bookshelf_content_test.dart`

- [ ] **Step 1: Write a failing bookshelf wide-grid widget test**

```dart
Book _book({required String id, required String title}) {
  return Book(
    id: id,
    title: title,
    author: 'Author $id',
    filePath: '/tmp/$id.epub',
    originalFileName: '$title.epub',
    format: BookFormat.epub,
    importedAt: DateTime(2026, 6, 1),
    fileHash: 'hash-$id',
    fileSizeBytes: 1024,
    progress: 0.35,
  );
}

testWidgets('bookshelf uses a multi-column grid on wide layouts', (
  tester,
) async {
  tester.view.physicalSize = const Size(1024, 1366);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: BookshelfContent(
        books: [
          _book(id: '1', title: '深度工作'),
          _book(id: '2', title: '原则'),
          _book(id: '3', title: '刻意练习'),
          _book(id: '4', title: '纳瓦尔宝典'),
        ],
        onImport: () async {},
        onRemoveBook: (_) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('bookshelf-grid-expanded')), findsOneWidget);
});
```

- [ ] **Step 2: Run the bookshelf widget test to verify it fails**

Run: `/Users/mutse/development/flutter/bin/flutter test test/features/bookshelf/presentation/bookshelf_content_test.dart`

Expected: FAIL because `BookshelfContent` does not exist yet.

- [ ] **Step 3: Extract the presentational bookshelf body and add adaptive grid rules**

```dart
class BookshelfContent extends StatefulWidget {
  const BookshelfContent({
    super.key,
    required this.books,
    required this.onImport,
    required this.onRemoveBook,
  });

  final List<Book> books;
  final Future<void> Function() onImport;
  final Future<void> Function(Book book) onRemoveBook;

  @override
  State<BookshelfContent> createState() => _BookshelfContentState();
}
```

```dart
final layout = context.adaptiveLayout;
final columns = layout.adaptiveColumns(compact: 1, medium: 2, expanded: 3);

if (_gridMode || !layout.isCompact) {
  return SliverPadding(
    padding: EdgeInsets.fromLTRB(
      layout.horizontalPadding,
      8,
      layout.horizontalPadding,
      120,
    ),
    sliver: SliverGrid(
      key: const Key('bookshelf-grid-expanded'),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _BookGridTile(book: filteredBooks[index]),
        childCount: filteredBooks.length,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: layout.isCompact ? 1.24 : 0.88,
      ),
    ),
  );
}
```

```dart
child: BookshelfContent(
  books: books,
  onImport: () => _importBook(context, ref),
  onRemoveBook: (book) => _removeBook(context, ref, book),
),
```

- [ ] **Step 4: Run the bookshelf widget test to verify it passes**

Run: `/Users/mutse/development/flutter/bin/flutter test test/features/bookshelf/presentation/bookshelf_content_test.dart`

Expected: PASS with the expanded bookshelf grid rendered at tablet widths.

- [ ] **Step 5: Commit the bookshelf adaptive layout**

```bash
git add lib/features/bookshelf/presentation/bookshelf_screen.dart lib/features/bookshelf/presentation/widgets/bookshelf_content.dart test/features/bookshelf/presentation/bookshelf_content_test.dart
git commit -m "Adapt bookshelf for iPad layouts"
```

## Task 5: Adapt Player and Reader for Wide Screens

**Files:**
- Modify: `lib/features/player/presentation/player_screen.dart`
- Modify: `lib/features/reader/presentation/reader_screen.dart`
- Test: `test/features/player/presentation/player_screen_test.dart`
- Reuse: `lib/app/adaptive/adaptive_content.dart`

- [ ] **Step 1: Write a failing player wide-layout widget test**

```dart
class _FakeBookshelfController extends BookshelfController {
  _FakeBookshelfController(this.books);

  final List<Book> books;

  @override
  Future<List<Book>> build() async => books;
}

Book _sampleBook({required String id, required String title}) {
  return Book(
    id: id,
    title: title,
    author: 'Author $id',
    filePath: '/tmp/$id.epub',
    originalFileName: '$title.epub',
    format: BookFormat.epub,
    importedAt: DateTime(2026, 6, 1),
    fileHash: 'hash-$id',
    fileSizeBytes: 1024,
    progress: 0.35,
  );
}

Widget _buildBooksProviderHarness({
  required Widget child,
  required List<Book> books,
}) {
  return ProviderScope(
    overrides: [
      bookshelfControllerProvider.overrideWith(
        () => _FakeBookshelfController(books),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

testWidgets('player uses split panes on wide layouts', (tester) async {
  tester.view.physicalSize = const Size(1024, 1366);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _buildBooksProviderHarness(
      child: const PlayerScreen(),
      books: [_sampleBook(id: '1', title: '深度工作')],
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('player-primary-pane')), findsOneWidget);
  expect(find.byKey(const Key('player-secondary-pane')), findsOneWidget);
});
```

- [ ] **Step 2: Run the player layout test to verify it fails**

Run: `/Users/mutse/development/flutter/bin/flutter test test/features/player/presentation/player_screen_test.dart`

Expected: FAIL because the player screen is still a single-column layout and the test file does not exist yet.

- [ ] **Step 3: Implement split-pane player layout and constrained reader width**

```dart
return ListView(
  padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
  children: [
    AdaptiveContentContainer(
      maxWidth: 1180,
      child: AdaptiveTwoPane(
        primary: Column(
          key: const Key('player-primary-pane'),
          children: [
            _PlayerTopBar(
              currentBook: currentBook,
              onTimerTap: () => _showTimerSheet(context),
              onSpeedTap: () => _showSpeedSheet(context),
              onChaptersTap: () => _showChapterSheet(context, currentBook),
              onPlaylistTap: () =>
                  context.push('/book/${currentBook.id}/playlist'),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 300,
                height: 360,
                child: BookCoverArt(
                  book: currentBook,
                  width: 238,
                  height: 320,
                  radius: 32,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _NowPlayingSnapshot(
              currentBook: currentBook,
              speechState: speechState,
              locationLabel: locationLabel,
              totalMinutes: totalMinutes,
              remainingMinutes: remainingMinutes,
            ),
          ],
        ),
        secondary: Column(
          key: const Key('player-secondary-pane'),
          children: [
            LiquidGlassCard(
              colors: const [Color(0x33FFFFFF), Color(0x14FFFFFF)],
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('播放进度', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      Text(progressLabel(currentBook)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(value: currentBook.progress.clamp(0.04, 1.0)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LiquidGlassCard(
              colors: const [Color(0x33FFFFFF), Color(0x14FFFFFF)],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('稍后播放', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final queuedBook in queue)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(queuedBook.title),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ],
);
```

```dart
class _ReaderWideAccessoryPanel extends StatelessWidget {
  const _ReaderWideAccessoryPanel({
    required this.book,
    required this.colors,
  });

  final Book book;
  final _ScreenColors colors;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '阅读工具',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push('/reader-settings'),
            icon: const Icon(Icons.palette_outlined),
            label: const Text('阅读设置'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.push('/book/${book.id}/notebook'),
            icon: const Icon(Icons.sticky_note_2_outlined),
            label: const Text('打开笔记'),
          ),
        ],
      ),
    );
  }
}

return AdaptiveContentContainer(
  maxWidth: 980,
  child: Column(
    children: [
      _ReaderHeader(
        book: book,
        colors: screenColors,
        isLandscape: isLandscape,
      ),
      Expanded(
        child: AdaptiveTwoPane(
          primaryFlex: 5,
          secondaryFlex: 2,
          primary: Container(
            key: const Key('reader-primary-surface'),
            child: switch (book.format) {
              BookFormat.pdf => PdfReaderView(book: book, compact: isLandscape),
              BookFormat.epub => EpubReaderView(book: book, compact: isLandscape),
            },
          ),
          secondary: _ReaderWideAccessoryPanel(
            book: book,
            colors: screenColors,
          ),
        ),
      ),
      _SpeechBar(
        book: book,
        colors: screenColors,
        isLandscape: isLandscape,
      ),
    ],
  ),
);
```

- [ ] **Step 4: Run the player layout test and the reader smoke test**

Run: `/Users/mutse/development/flutter/bin/flutter test test/features/player/presentation/player_screen_test.dart`

Expected: PASS with both player pane keys present on wide widths.

Run: `/Users/mutse/development/flutter/bin/flutter test test/widget_test.dart`

Expected: PASS to confirm the app still boots after the shell and reader changes.

- [ ] **Step 5: Commit the adaptive player and reader layout**

```bash
git add lib/features/player/presentation/player_screen.dart lib/features/reader/presentation/reader_screen.dart test/features/player/presentation/player_screen_test.dart test/widget_test.dart
git commit -m "Adapt player and reader for wide screens"
```

## Task 6: Run Full Verification and Clean Up Layout Regressions

**Files:**
- Verify: `lib/app/adaptive/adaptive_layout.dart`
- Verify: `lib/app/adaptive/adaptive_content.dart`
- Verify: `lib/features/navigation/presentation/app_shell.dart`
- Verify: `lib/features/home/presentation/reading_home_screen.dart`
- Verify: `lib/features/bookshelf/presentation/bookshelf_screen.dart`
- Verify: `lib/features/bookshelf/presentation/widgets/bookshelf_content.dart`
- Verify: `lib/features/discover/presentation/discover_screen.dart`
- Verify: `lib/features/player/presentation/player_screen.dart`
- Verify: `lib/features/reader/presentation/reader_screen.dart`

- [ ] **Step 1: Run targeted widget tests for the new adaptive flows**

```bash
/Users/mutse/development/flutter/bin/flutter test \
  test/app/adaptive/adaptive_layout_test.dart \
  test/features/navigation/presentation/app_shell_test.dart \
  test/features/home/presentation/reading_home_screen_test.dart \
  test/features/bookshelf/presentation/bookshelf_content_test.dart \
  test/features/player/presentation/player_screen_test.dart
```

Expected: PASS across the new adaptive test suite.

- [ ] **Step 2: Run the full test suite**

Run: `/Users/mutse/development/flutter/bin/flutter test`

Expected: PASS with existing tests still green.

- [ ] **Step 3: Run static analysis**

Run: `/Users/mutse/development/flutter/bin/flutter analyze`

Expected: PASS with no new analyzer errors.

- [ ] **Step 4: Manually verify width transitions**

```text
1. Launch the app in an iPad simulator or resized desktop test surface.
2. Verify compact widths show the bottom navigation bar.
3. Verify wide widths show the sidebar shell.
4. Verify Bookshelf becomes a multi-column layout.
5. Verify Player becomes a two-pane layout.
6. Verify Reader content stays centered and does not stretch edge to edge.
```

- [ ] **Step 5: Commit any final polish fixes**

```bash
git add lib/app/adaptive lib/features/navigation/presentation lib/features/home/presentation lib/features/bookshelf/presentation lib/features/discover/presentation lib/features/player/presentation lib/features/reader/presentation test
git commit -m "Polish iPad adaptive layout behavior"
```
