import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/bookshelf/presentation/widgets/book_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BookshelfScreen extends ConsumerWidget {
  const BookshelfScreen({
    super.key,
    this.showAppBar = true,
  });

  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookshelfControllerProvider);

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: const Text('书架'),
              actions: [
                IconButton(
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.tune),
                  tooltip: 'Speech settings',
                ),
                IconButton(
                  onPressed: () async {
                    final book = await ref
                        .read(bookshelfControllerProvider.notifier)
                        .importBook();
                    if (book != null && context.mounted) {
                      context.push('/reader/${book.id}');
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Import book',
                ),
              ],
            )
          : null,
      body: SafeArea(
        top: !showAppBar,
        child: booksAsync.when(
          data: (books) => _BookshelfBody(books: books),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Failed to load bookshelf: $error'),
          ),
        ),
      ),
    );
  }
}

class _BookshelfBody extends StatelessWidget {
  const _BookshelfBody({
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
    final activeBooks = recentBooks.where((book) => book.progress > 0).toList();
    final spotlight = activeBooks.isNotEmpty ? activeBooks.first : null;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '书架',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '把最近在读和收藏的书放在最顺手的位置。',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF5D645F),
                      ),
                ),
                const SizedBox(height: 18),
                _ShelfSummary(
                  booksCount: books.length,
                  activeCount: activeBooks.length,
                ),
                const SizedBox(height: 18),
                const _ShelfFilters(),
              ],
            ),
          ),
        ),
        if (spotlight != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: _ContinueReadingBanner(book: spotlight),
            ),
          ),
        if (books.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _EmptyShelf(),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                children: [
                  Text(
                    '全部藏书',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '按最近阅读排序',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF69706B),
                        ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final book = recentBooks[index];
                return BookCard(
                  book: book,
                  onTap: () => context.push('/reader/${book.id}'),
                );
              }, childCount: recentBooks.length),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.67,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShelfSummary extends StatelessWidget {
  const _ShelfSummary({
    required this.booksCount,
    required this.activeCount,
  });

  final int booksCount;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: '藏书',
            value: '$booksCount',
            hint: '本',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: '在读',
            value: '$activeCount',
            hint: '本',
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: _SummaryCard(
            label: '习惯',
            value: '夜读',
            hint: '更沉浸',
          ),
        ),
      ],
    );
  }
}

class _ShelfFilters extends StatelessWidget {
  const _ShelfFilters();

  @override
  Widget build(BuildContext context) {
    final filters = <String>['全部', '在读', '未读', 'EPUB', 'PDF'];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final active = index == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF18211D)
                  : Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              filters[index],
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: active ? Colors.white : const Color(0xFF58605B),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          );
        },
      ),
    );
  }
}

class _ContinueReadingBanner extends StatelessWidget {
  const _ContinueReadingBanner({
    required this.book,
  });

  final Book book;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/reader/${book.id}'),
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                width: 74,
                height: 104,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(colors: _coverColors(book)),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.12),
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '继续阅读',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF64706A),
                          ),
                    ),
                    const SizedBox(height: 6),
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
                      '${book.author} · 已读 ${_percent(book.progress)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF64706A),
                          ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: book.progress.clamp(0.02, 1.0),
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE5E1D8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF69706B),
                ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1A211D),
                    fontWeight: FontWeight.w800,
                  ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: '  $hint',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF69706B),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf();

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
            '你的书架还是空的',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            '导入 EPUB 或 PDF 后，就可以开始阅读、记录进度，并使用 AI 语音朗读。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('请从阅读页右下角导入图书'),
          ),
        ],
      ),
    );
  }
}

List<Color> _coverColors(Book book) {
  return book.format == BookFormat.epub
      ? const [Color(0xFF215447), Color(0xFFA6CFBE)]
      : const [Color(0xFF445789), Color(0xFFD1DCF7)];
}

String _percent(double progress) {
  final normalized = progress.clamp(0, 1);
  return '${(normalized * 100).round()}%';
}
