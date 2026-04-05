import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ReadingHomeScreen extends ConsumerWidget {
  const ReadingHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookshelfControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: booksAsync.when(
          data: (books) => _ReadingHomeBody(books: books),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('加载阅读页失败: $error'),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final book =
              await ref.read(bookshelfControllerProvider.notifier).importBook();
          if (book != null && context.mounted) {
            context.push('/reader/${book.id}');
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('导入书籍'),
      ),
    );
  }
}

class _ReadingHomeBody extends StatelessWidget {
  const _ReadingHomeBody({
    required this.books,
  });

  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    final recentBooks = [...books]..sort((a, b) {
        final aTime = a.lastReadAt ?? a.importedAt;
        final bTime = b.lastReadAt ?? b.importedAt;
        return bTime.compareTo(aTime);
      });
    final continueBook = recentBooks.isNotEmpty ? recentBooks.first : null;
    final recommendations = recentBooks.take(4).toList();
    final recentShelf = recentBooks.take(6).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TopBar(),
                const SizedBox(height: 18),
                const _CategoryPills(),
                const SizedBox(height: 20),
                _HeroCard(book: continueBook, booksCount: books.length),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: '最近阅读',
                  actionLabel: recentShelf.isEmpty ? '暂无记录' : '继续你的节奏',
                ),
              ],
            ),
          ),
        ),
        if (recentShelf.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _EmptyReadingState(),
            ),
          )
        else
          SliverToBoxAdapter(
            child: SizedBox(
              height: 242,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                scrollDirection: Axis.horizontal,
                itemCount: recentShelf.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final book = recentShelf[index];
                  return _RecentBookCard(book: book);
                },
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: _SectionHeader(
              title: '为你推荐',
              actionLabel: '${books.length} 本藏书',
            ),
          ),
        ),
        if (recommendations.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _RecommendationPlaceholder(),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final book = recommendations[index];
                  return _RecommendationCard(book: book);
                },
                childCount: recommendations.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            child: _ReadingStatsCard(
              booksCount: books.length,
              continueBook: continueBook,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '阅读',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '今天也从书里拿回一点专注。',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF626863),
                    ),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _CategoryPills extends StatelessWidget {
  const _CategoryPills();

  @override
  Widget build(BuildContext context) {
    final items = <String>['推荐', '小说', '社科', '成长', '历史'];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final active = index == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF18211D)
                  : Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              items[index],
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: active ? Colors.white : const Color(0xFF4F5752),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.book,
    required this.booksCount,
  });

  final Book? book;
  final int booksCount;

  @override
  Widget build(BuildContext context) {
    final hasBook = book != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF183E38), Color(0xFF78A796)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '继续阅读',
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
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            hasBook ? book!.title : '导入第一本 EPUB 或 PDF',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            hasBook
                ? '${book!.author} · ${_formatReadingStatus(book!)}'
                : '像微信读书一样把常读内容放在入口，一打开就能继续。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
          ),
          const SizedBox(height: 16),
          if (hasBook)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: book!.progress.clamp(0.02, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF16463F),
                ),
                onPressed:
                    hasBook ? () => context.push('/reader/${book!.id}') : null,
                child: Text(hasBook ? '继续阅读' : '导入后可阅读'),
              ),
              const SizedBox(width: 12),
              if (hasBook)
                Text(
                  _relativeReadLabel(book!),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentBookCard extends StatelessWidget {
  const _RecentBookCard({
    required this.book,
  });

  final Book book;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/reader/${book.id}'),
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        width: 152,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _coverColors(book),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          color: Colors.black.withValues(alpha: 0.12),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.formatLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              book.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatReadingStatus(book),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF666D68),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.book,
  });

  final Book book;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () => context.push('/reader/${book.id}'),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: _coverColors(book),
                    ),
                  ),
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          book.formatLabel,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5B625E),
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '阅读进度 ${_percent(book.progress)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5B625E),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingStatsCard extends StatelessWidget {
  const _ReadingStatsCard({
    required this.booksCount,
    required this.continueBook,
  });

  final int booksCount;
  final Book? continueBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '阅读概览',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricItem(
                  label: '藏书数',
                  value: '$booksCount',
                ),
              ),
              Expanded(
                child: _MetricItem(
                  label: '当前重点',
                  value: continueBook == null
                      ? '待开始'
                      : _percent(continueBook!.progress),
                ),
              ),
              const Expanded(
                child: _MetricItem(
                  label: '推荐节奏',
                  value: '30 分钟',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6A716D),
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
  });

  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const Spacer(),
        Text(
          actionLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6D746F),
              ),
        ),
      ],
    );
  }
}

class _EmptyReadingState extends StatelessWidget {
  const _EmptyReadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '还没有阅读记录',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '先导入几本书，阅读页会优先展示最近读过的内容和你的继续阅读入口。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _RecommendationPlaceholder extends StatelessWidget {
  const _RecommendationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(
        '导入书籍后，这里会优先根据最近阅读展示推荐内容。',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

List<Color> _coverColors(Book book) {
  return book.format == BookFormat.epub
      ? const [Color(0xFF2A6458), Color(0xFF9DC4B1)]
      : const [Color(0xFF485B8F), Color(0xFFC9D5F7)];
}

String _percent(double progress) {
  final normalized = progress.clamp(0, 1);
  return '${(normalized * 100).round()}%';
}

String _formatReadingStatus(Book book) {
  if (book.progress > 0) {
    return '已读 ${_percent(book.progress)}';
  }
  return '尚未开始';
}

String _relativeReadLabel(Book book) {
  final lastTime = book.lastReadAt ?? book.importedAt;
  final now = DateTime.now();
  final difference = now.difference(lastTime);

  if (difference.inDays >= 1) {
    return '${difference.inDays} 天前阅读';
  }
  if (difference.inHours >= 1) {
    return '${difference.inHours} 小时前阅读';
  }
  return '刚刚同步';
}
