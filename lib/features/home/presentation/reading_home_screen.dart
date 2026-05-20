import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_insights.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ReadingHomeScreen extends ConsumerStatefulWidget {
  const ReadingHomeScreen({super.key});

  @override
  ConsumerState<ReadingHomeScreen> createState() => _ReadingHomeScreenState();
}

class _ReadingHomeScreenState extends ConsumerState<ReadingHomeScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = '全部';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(bookshelfControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: booksAsync.when(
            data: (books) => _HomeBody(
              books: books,
              searchController: _searchController,
              searchQuery: _searchQuery,
              onSearchChanged: (query) {
                setState(() => _searchQuery = query);
              },
              selectedCategory: _selectedCategory,
              onSelectCategory: (category) {
                setState(() => _selectedCategory = category);
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载首页失败: $error')),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({
    required this.books,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedCategory,
    required this.onSelectCategory,
  });

  final List<Book> books;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String selectedCategory;
  final ValueChanged<String> onSelectCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentBooks = sortBooksByRecent(books);
    final queryMatchedBooks = filterBooksByQuery(recentBooks, searchQuery);
    final recentCutoff = DateTime.now().subtract(const Duration(days: 14));
    final categories = [
      '全部',
      '最近导入',
      '在读',
      '已读完',
      'EPUB',
      'PDF',
    ];
    final filteredBooks = queryMatchedBooks.where((book) {
      return switch (selectedCategory) {
        '全部' => true,
        '最近导入' => book.importedAt.isAfter(recentCutoff),
        '在读' => book.progress > 0 && book.progress < 1,
        '已读完' => book.progress >= 1,
        'EPUB' => book.format == BookFormat.epub,
        'PDF' => book.format == BookFormat.pdf,
        _ => true,
      };
    }).toList();
    final hasQuery = searchQuery.trim().isNotEmpty;
    final featured = filteredBooks.isNotEmpty ? filteredBooks.first : null;
    final continueCandidates = hasQuery ? filteredBooks : recentBooks;
    final continueBook = continueCandidates
        .where((book) => book.progress > 0 && book.progress < 1)
        .cast<Book?>()
        .firstWhere((book) => book != null, orElse: () => featured);
    final recommendations = filteredBooks.take(3).toList();
    final shelfPreview = filteredBooks.take(4).toList();
    final summaryBooks = sortBooksForShelf(
      filteredBooks,
      BookshelfSortMode.progress,
    ).take(2).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
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
                if (hasQuery) ...[
                  const SizedBox(height: 12),
                  Text(
                    '“$searchQuery” 匹配到 ${filteredBooks.length} 本',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF647196),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
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
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return GestureDetector(
                        onTap: () => onSelectCategory(category),
                        child: TagChip(
                          label: category,
                          active: selectedCategory == category,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                _QuickActions(
                  featured: featured,
                  onImport: () => _importBook(context, ref),
                ),
              ],
            ),
          ),
        ),
        if (hasQuery && filteredBooks.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              child: LiquidGlassCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.manage_search_rounded,
                      size: 48,
                      color: Color(0xFF5D7CFF),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '没有找到匹配内容',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '可以试试作者名、格式筛选，或者先去导入更多书籍。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          if (continueBook != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: _ContinueListeningCard(book: continueBook),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: SectionHeader(
                title: hasQuery ? '搜索结果' : '推荐继续阅读',
                actionLabel: '去发现',
                onTap: () => context.go('/discover'),
              ),
            ),
          ),
          if (recommendations.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: LiquidGlassCard(
                  child: Text('导入几本书后，这里会根据最近导入和阅读进度生成真实入口。'),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: recommendations.length,
              itemBuilder: (context, index) {
                final book = recommendations[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _RecommendationTile(book: book),
                );
              },
            ),
          if (summaryBooks.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: SectionHeader(title: '今日速览'),
              ),
            ),
          if (summaryBooks.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 198,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: summaryBooks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final book = summaryBooks[index];
                    return _InsightCard(book: book);
                  },
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: SectionHeader(
                title: hasQuery ? '匹配书架' : '最近加入书架',
                actionLabel: '查看全部',
                onTap: () => context.go('/bookshelf'),
              ),
            ),
          ),
          if (shelfPreview.isEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 120))
          else
            SliverToBoxAdapter(
              child: SizedBox(
                height: 248,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final book = shelfPreview[index];
                    return GestureDetector(
                      onTap: () => context.push('/book/${book.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BookCoverArt(
                            book: book,
                            width: 152,
                            height: 192,
                            radius: 26,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 152,
                            child: Text(
                              book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 152,
                            child: Text(
                              '${book.author} · ${book.formatLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemCount: shelfPreview.length,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _importBook(BuildContext context, WidgetRef ref) async {
    try {
      final book =
          await ref.read(bookshelfControllerProvider.notifier).importBook();
      if (book != null && context.mounted) {
        context.push('/book/${book.id}');
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败，请重试: $error')),
      );
    }
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onImport});

  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            gradient: LinearGradient(
              colors: [Color(0xFF76C7FF), Color(0xFF7E7BFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.graphic_eq_rounded,
              color: Colors.white, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chibook',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '沉浸式阅读与听书，从本地书库直接开始',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () async => onImport(),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.book,
    required this.booksCount,
    required this.onImport,
    this.onListen,
  });

  final Book? book;
  final int booksCount;
  final Future<void> Function() onImport;
  final VoidCallback? onListen;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 34,
      colors: const [
        Color(0xFF7B92FF),
        Color(0xFF8CC8FF),
      ],
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -28,
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
            Positioned(
              left: 26,
              bottom: -18,
              child: Container(
                width: 160,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '本地导入 · EPUB / PDF',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$booksCount 本在库',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  book?.title ?? '先导入一本书',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  book == null
                      ? '导入后这里会优先展示最近阅读、在读内容和可继续朗读的书籍。'
                      : '${book!.author} · ${book!.formatLabel} · ${estimatedListenLabel(book!)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    FilledButton(
                      onPressed: book == null ? null : onListen,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF5067DA),
                      ),
                      child: const Text('立即朗读'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () async => onImport(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(book == null ? '导入书籍' : '继续扩充书架'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: WaveformLine(
                        color: Colors.white,
                        barCount: 20,
                        barWidth: 3,
                        minHeight: 6,
                        maxHeight: 20,
                        spacing: 3,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '本地朗读已就绪',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onImport,
    required this.featured,
  });

  final Future<void> Function() onImport;
  final Book? featured;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        '继续阅读',
        Icons.menu_book_rounded,
        featured == null
            ? null
            : () => context.push('/book/${featured!.id}'),
      ),
      (
        '播放列表',
        Icons.queue_music_rounded,
        featured == null
            ? null
            : () => context.push('/book/${featured!.id}/playlist'),
      ),
      ('发现', Icons.explore_outlined, () => context.go('/discover')),
      ('书架', Icons.menu_book_outlined, () => context.go('/bookshelf')),
      ('导入', Icons.add_box_outlined, () async => onImport()),
    ];

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return LiquidGlassCard(
            radius: 24,
            colors: index == 0
                ? const [Color(0xD7FFFFFF), Color(0x9FCDEEFF)]
                : null,
            onTap: item.$3,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D7CFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.$2, color: const Color(0xFF5D7CFF)),
                ),
                const SizedBox(height: 8),
                Text(
                  item.$1,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ContinueListeningCard extends ConsumerWidget {
  const _ContinueListeningCard({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiquidGlassCard(
      radius: 30,
      colors: const [Color(0xE3FFFFFF), Color(0x97DDF2FF)],
      onTap: () async {
        await ref.read(readerControllerProvider).playAutoForCurrentBook(book);
        if (!context.mounted) return;
        context.go('/player');
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '继续收听',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${book.author} · ${progressLabel(book)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: book.progress.clamp(0.04, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFDCE5FF),
                  ),
                ),
                const SizedBox(height: 12),
                const WaveformLine(
                  color: Color(0xFF5D7CFF),
                  barCount: 14,
                  barWidth: 2.6,
                  minHeight: 4,
                  maxHeight: 14,
                  spacing: 2.4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF84C9FF), Color(0xFF5D7CFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _RecommendationTile extends ConsumerWidget {
  const _RecommendationTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiquidGlassCard(
      radius: 26,
      onTap: () => context.push('/book/${book.id}'),
      child: Row(
        children: [
          BookCoverArt(
            book: book,
            width: 78,
            height: 108,
            radius: 18,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${book.author} · ${book.formatLabel}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  estimatedListenLabel(book),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF5D7CFF),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await ref
                  .read(readerControllerProvider)
                  .playAutoForCurrentBook(book);
              if (!context.mounted) return;
              context.go('/player');
            },
            icon: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF7BC6FF), Color(0xFF5D7CFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 28,
      colors: const [Color(0xDFFFFFFF), Color(0xA2EEF5FF)],
      onTap: () => context.push('/book/${book.id}'),
      child: SizedBox(
        width: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D7CFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    book.formatLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF5D7CFF),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const Spacer(),
                Text(
                  progressLabel(book),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _insightDescription(book),
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
            const Spacer(),
            Text(
              '打开书籍',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF5D7CFF),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _insightDescription(Book book) {
  final progress = (book.progress.clamp(0, 1) * 100).round();
  if (book.chapterCount > 0) {
    return '共 ${book.chapterCount} 章，当前进度 $progress%，适合从最近一次阅读位置继续。';
  }
  if (book.pageCount > 0) {
    return '共 ${book.pageCount} 页，当前进度 $progress%，可以直接继续阅读或朗读当前内容。';
  }
  return '${estimatedListenLabel(book)}，当前进度 $progress%，适合继续阅读或加入播放列表。';
}
