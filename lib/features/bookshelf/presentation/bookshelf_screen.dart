import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_insights.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _ShelfFilter { all, reading, finished, epub, pdf }

enum _ShelfBookAction { remove }

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
      backgroundColor: Colors.transparent,
      appBar: showAppBar ? AppBar(title: const Text('书架')) : null,
      body: LiquidBackground(
        child: SafeArea(
          top: !showAppBar,
          child: booksAsync.when(
            data: (books) => _BookshelfBody(
              books: books,
              onImport: () => _importBook(context, ref),
              onRemoveBook: (book) => _removeBook(context, ref, book),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载书架失败: $error')),
          ),
        ),
      ),
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

  Future<void> _removeBook(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从书架移除'),
        content: Text('确认移除《${book.title}》吗？当前阅读进度也会一起清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(bookshelfControllerProvider.notifier).removeBook(book.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已从书架移除《${book.title}》')),
    );
  }
}

class _BookshelfBody extends StatefulWidget {
  const _BookshelfBody({
    required this.books,
    required this.onImport,
    required this.onRemoveBook,
  });

  final List<Book> books;
  final Future<void> Function() onImport;
  final Future<void> Function(Book book) onRemoveBook;

  @override
  State<_BookshelfBody> createState() => _BookshelfBodyState();
}

class _BookshelfBodyState extends State<_BookshelfBody> {
  final _searchController = TextEditingController();
  _ShelfFilter _selectedFilter = _ShelfFilter.all;
  BookshelfSortMode _selectedSort = BookshelfSortMode.recent;
  bool _gridMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentBooks = sortBooksByRecent(widget.books);
    final insights = buildReadingInsights(widget.books);
    final searchedBooks =
        filterBooksByQuery(recentBooks, _searchController.text.trim());
    final filteredBooks = sortBooksForShelf(
      searchedBooks.where(_matchesFilter),
      _selectedSort,
    );
    final activeBooks = recentBooks.where((book) => book.progress > 0).toList();
    final spotlight = activeBooks.isNotEmpty ? activeBooks.first : null;
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                            '我的书架',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '把在读、收藏和最近加入的书放到更顺手的位置。',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _gridMode = !_gridMode),
                      icon: Icon(
                        _gridMode
                            ? Icons.view_agenda_outlined
                            : Icons.grid_view_rounded,
                      ),
                    ),
                    IconButton(
                      onPressed: () async => widget.onImport(),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: '本周新增',
                        value: '${insights.importedThisWeek} 本',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: '在听',
                        value: '${insights.readingBooks} 本',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: '完成率',
                        value: '${insights.completionRate}%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AppSearchBar(
                  hint: '搜索书名 / 作者 / 关键词',
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  trailing: PopupMenuButton<BookshelfSortMode>(
                    tooltip: '排序',
                    initialValue: _selectedSort,
                    onSelected: (value) {
                      setState(() => _selectedSort = value);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: BookshelfSortMode.recent,
                        child: Text('按最近阅读'),
                      ),
                      PopupMenuItem(
                        value: BookshelfSortMode.progress,
                        child: Text('按阅读进度'),
                      ),
                      PopupMenuItem(
                        value: BookshelfSortMode.title,
                        child: Text('按书名'),
                      ),
                    ],
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFF6F7EA8),
                    ),
                  ),
                ),
                if (hasQuery) ...[
                  const SizedBox(height: 12),
                  Text(
                    '“${_searchController.text.trim()}” 匹配到 ${filteredBooks.length} 本',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF647196),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in _ShelfFilter.values) ...[
                        GestureDetector(
                          onTap: () => setState(() => _selectedFilter = filter),
                          child: TagChip(
                            label: _filterLabel(filter),
                            active: _selectedFilter == filter,
                          ),
                        ),
                        if (filter != _ShelfFilter.values.last)
                          const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _ShelfHeroCard(
                  booksCount: widget.books.length,
                  activeCount: activeBooks.length,
                  finishedCount: insights.finishedBooks,
                ),
              ],
            ),
          ),
        ),
        if (!hasQuery &&
            spotlight != null &&
            _selectedFilter == _ShelfFilter.all)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _ContinueListeningBanner(book: spotlight),
            ),
          ),
        if (filteredBooks.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: LiquidGlassCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.auto_stories_outlined,
                      size: 52,
                      color: Color(0xFF5D7CFF),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _emptyTitle(),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _emptyHint(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () async => widget.onImport(),
                      child: const Text('导入书籍'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_gridMode)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ShelfGridCard(
                  book: filteredBooks[index],
                  onRemove: () => widget.onRemoveBook(filteredBooks[index]),
                ),
                childCount: filteredBooks.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.70,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: filteredBooks.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    '共 ${filteredBooks.length} 本 · ${_sortLabel(_selectedSort)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }
              final book = filteredBooks[index - 1];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _ShelfRow(
                  book: book,
                  onRemove: () => widget.onRemoveBook(book),
                ),
              );
            },
          ),
      ],
    );
  }

  bool _matchesFilter(Book book) {
    return switch (_selectedFilter) {
      _ShelfFilter.all => true,
      _ShelfFilter.reading => book.progress > 0 && book.progress < 1,
      _ShelfFilter.finished => book.progress >= 1,
      _ShelfFilter.epub => book.format == BookFormat.epub,
      _ShelfFilter.pdf => book.format == BookFormat.pdf,
    };
  }

  String _filterLabel(_ShelfFilter filter) {
    return switch (filter) {
      _ShelfFilter.all => '全部',
      _ShelfFilter.reading => '在听',
      _ShelfFilter.finished => '已听完',
      _ShelfFilter.epub => 'EPUB',
      _ShelfFilter.pdf => 'PDF',
    };
  }

  String _emptyTitle() {
    return switch (_selectedFilter) {
      _ShelfFilter.all => '你的书架还是空的',
      _ShelfFilter.reading => '还没有在听中的书',
      _ShelfFilter.finished => '还没有听完的书',
      _ShelfFilter.epub => '还没有 EPUB 书籍',
      _ShelfFilter.pdf => '还没有 PDF 书籍',
    };
  }

  String _emptyHint() {
    if (_searchController.text.trim().isNotEmpty) {
      return '可以换个关键词、作者名或分类试试，书架会即时重新筛选。';
    }

    return switch (_selectedFilter) {
      _ShelfFilter.all => '导入 EPUB 或 PDF 后，首页、播放页和详情页都会自动跟着充实起来。',
      _ShelfFilter.reading => '先从首页或详情页点一次“立即收听”，这里就会变成你的在听列表。',
      _ShelfFilter.finished => '等一本书完整听完后，这里会自然沉淀成你的已完成书单。',
      _ShelfFilter.epub => '导入一本 EPUB 后，这里会更适合做章节式边听边读。',
      _ShelfFilter.pdf => '导入一本 PDF 后，这里会支持按页与目录继续收听。',
    };
  }

  String _sortLabel(BookshelfSortMode sortMode) {
    return switch (sortMode) {
      BookshelfSortMode.recent => '最近阅读',
      BookshelfSortMode.progress => '阅读进度',
      BookshelfSortMode.title => '书名排序',
    };
  }
}

class _ContinueListeningBanner extends StatelessWidget {
  const _ContinueListeningBanner({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 30,
      colors: const [Color(0xE0FFFFFF), Color(0xA9DDF7FF)],
      onTap: () => context.push('/book/${book.id}'),
      child: Row(
        children: [
          BookCoverArt(
            book: book,
            width: 92,
            height: 128,
            radius: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D7CFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '继续收听',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF5D7CFF),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
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
                  barWidth: 2.4,
                  minHeight: 4,
                  maxHeight: 12,
                  spacing: 2.4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF5D7CFF)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 22,
      colors: const [Color(0xE8FFFFFF), Color(0xAEEAF5FF)],
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ShelfHeroCard extends StatelessWidget {
  const _ShelfHeroCard({
    required this.booksCount,
    required this.activeCount,
    required this.finishedCount,
  });

  final int booksCount;
  final int activeCount;
  final int finishedCount;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 32,
      colors: const [Color(0xFFE8F0FF), Color(0xFFBFD7FF)],
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -18,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '我的听书空间',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF4E67D6),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '持续积累中',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '把值得反复听的内容，放到最顺手的位置。',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                '书架不只是列表，更像你的长期内容仓库：想继续听的、已经听完的、还没开始的，都能一眼分层。',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _HeroMetric(
                      label: '全部藏书',
                      value: '$booksCount',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HeroMetric(
                      label: '正在听',
                      value: '$activeCount',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HeroMetric(
                      label: '已完成',
                      value: '$finishedCount',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const WaveformLine(
                color: Color(0xFF5D7CFF),
                barCount: 18,
                barWidth: 2.6,
                minHeight: 4,
                maxHeight: 14,
                spacing: 2.8,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ShelfRow extends StatelessWidget {
  const _ShelfRow({
    required this.book,
    required this.onRemove,
  });

  final Book book;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 28,
      colors: const [Color(0xE5FFFFFF), Color(0xAFEDF6FF)],
      onTap: () => context.push('/book/${book.id}'),
      child: Row(
        children: [
          BookCoverArt(
            book: book,
            width: 82,
            height: 116,
            radius: 20,
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
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value:
                        book.progress <= 0 ? 0.04 : book.progress.clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFDCE5FF),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${progressLabel(book)} · ${recencyLabel(book.lastReadAt ?? book.importedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                const WaveformLine(
                  color: Color(0xFF5D7CFF),
                  barCount: 12,
                  barWidth: 2.2,
                  minHeight: 4,
                  maxHeight: 10,
                  spacing: 2.2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              _ShelfBookMenu(onRemove: onRemove),
              const SizedBox(height: 12),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF7280A7)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShelfGridCard extends StatelessWidget {
  const _ShelfGridCard({
    required this.book,
    required this.onRemove,
  });

  final Book book;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 28,
      colors: const [Color(0xE8FFFFFF), Color(0xA7E7F4FF)],
      onTap: () => context.push('/book/${book.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: BookCoverArt(
              book: book,
              width: 132,
              height: 174,
              radius: 24,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _ShelfBookMenu(onRemove: onRemove),
          ),
          const SizedBox(height: 6),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: book.progress.clamp(0.04, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFFDCE5FF),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progressLabel(book),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ShelfBookMenu extends StatelessWidget {
  const _ShelfBookMenu({required this.onRemove});

  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ShelfBookAction>(
      tooltip: '管理书籍',
      onSelected: (action) async {
        if (action == _ShelfBookAction.remove) {
          await onRemove();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _ShelfBookAction.remove,
          child: Text('从书架移除'),
        ),
      ],
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          size: 18,
          color: Color(0xFF647196),
        ),
      ),
    );
  }
}
