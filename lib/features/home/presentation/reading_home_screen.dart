import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
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
  String _selectedCategory = '全部';

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
    required this.selectedCategory,
    required this.onSelectCategory,
  });

  final List<Book> books;
  final String selectedCategory;
  final ValueChanged<String> onSelectCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentBooks = sortBooksByRecent(books);
    final categories = [
      '全部',
      '个人成长',
      '心理学',
      '管理',
      '历史',
      '经济',
      '小说',
    ];
    final filteredBooks = selectedCategory == '全部'
        ? recentBooks
        : recentBooks
            .where((book) => pseudoCategoryForBook(book) == selectedCategory)
            .toList();
    final featured = filteredBooks.isNotEmpty ? filteredBooks.first : null;
    final continueBook = recentBooks
        .where((book) => book.progress > 0 && book.progress < 1)
        .cast<Book?>()
        .firstWhere((book) => book != null, orElse: () => featured);
    final recommendations = filteredBooks.take(3).toList();
    final shelfPreview = recentBooks.take(4).toList();
    final summaryBooks = recentBooks.take(2).toList();

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
                const AppSearchBar(
                  hint: '搜索书名 / 作者 / 关键词',
                  trailing:
                      Icon(Icons.mic_none_rounded, color: Color(0xFF6F7EA8)),
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
              title: '为你推荐',
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
                child: Text('导入几本书后，这里会根据最近阅读自动生成推荐卡片。'),
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
              title: '最近加入书架',
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
                            '${book.author} · ${pseudoCategoryForBook(book)}',
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
                'AI 听书',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '让知识随时被听见，也更容易开始',
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
                        '每天 15 分钟听一个重点',
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
                      ? '首页会优先展示当前最值得继续听的内容，播放器、目录和 AI 摘要也会跟着联动。'
                      : '${book!.author} · ${pseudoCategoryForBook(book!)} · ${estimatedListenLabel(book!)}',
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
                      child: const Text('立即收听'),
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
                        'AI 语音中',
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
        'AI 摘要',
        Icons.auto_awesome_rounded,
        featured == null
            ? null
            : () => context.push('/book/${featured!.id}?tab=summary'),
      ),
      (
        '目录速览',
        Icons.toc_rounded,
        featured == null
            ? null
            : () => context.push('/book/${featured!.id}?tab=toc'),
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
                  '${book.author} · ${pseudoCategoryForBook(book)}',
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
      onTap: () => context.push('/book/${book.id}?tab=summary'),
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
                    'AI 摘要',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF5D7CFF),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const Spacer(),
                Text(
                  pseudoCategoryForBook(book),
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
              '适合先看 3 条摘要，再决定要不要进入完整目录或直接播放。',
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
            const Spacer(),
            Text(
              '打开摘要',
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
