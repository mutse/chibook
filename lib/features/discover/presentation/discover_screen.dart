import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_insights.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _DiscoverFilter { all, recent, reading, finished, epub, pdf }

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();
  _DiscoverFilter _selectedFilter = _DiscoverFilter.all;

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
            data: (books) => _DiscoverBody(
              books: books,
              searchController: _searchController,
              searchQuery: _searchController.text,
              onSearchChanged: (_) {
                setState(() {});
              },
              selectedFilter: _selectedFilter,
              onFilterChanged: (filter) {
                setState(() => _selectedFilter = filter);
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载发现页失败: $error')),
          ),
        ),
      ),
    );
  }
}

class _DiscoverBody extends ConsumerWidget {
  const _DiscoverBody({
    required this.books,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final List<Book> books;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final _DiscoverFilter selectedFilter;
  final ValueChanged<_DiscoverFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentBooks = sortBooksByRecent(books);
    final query = searchQuery.trim();
    final searched = filterBooksByQuery(recentBooks, query);
    final filtered = searched.where((book) {
      return switch (selectedFilter) {
        _DiscoverFilter.all => true,
        _DiscoverFilter.recent => true,
        _DiscoverFilter.reading => book.progress > 0 && book.progress < 1,
        _DiscoverFilter.finished => book.progress >= 1,
        _DiscoverFilter.epub => book.format == BookFormat.epub,
        _DiscoverFilter.pdf => book.format == BookFormat.pdf,
      };
    }).toList(growable: false);

    final recentlyImported = List<Book>.from(filtered)
      ..sort((a, b) => b.importedAt.compareTo(a.importedAt));
    final continueReading = filtered
        .where((book) => book.progress > 0 && book.progress < 1)
        .toList(growable: false);
    final completed = filtered
        .where((book) => book.progress >= 1)
        .toList(growable: false);

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
                const SizedBox(height: 16),
                AppSearchBar(
                  hint: '搜索书名 / 作者 / 文件名',
                  controller: searchController,
                  onChanged: onSearchChanged,
                  trailing: query.isEmpty
                      ? const Icon(
                          Icons.library_books_outlined,
                          color: Color(0xFF6F7EA8),
                        )
                      : GestureDetector(
                          onTap: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF6F7EA8),
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in _DiscoverFilter.values) ...[
                        GestureDetector(
                          onTap: () => onFilterChanged(filter),
                          child: TagChip(
                            label: _filterLabel(filter),
                            active: selectedFilter == filter,
                          ),
                        ),
                        if (filter != _DiscoverFilter.values.last)
                          const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                LiquidGlassCard(
                  radius: 32,
                  colors: const [
                    Color(0xFFEFF5FF),
                    Color(0xD9FFFFFF),
                    Color(0xFFE1ECFF),
                  ],
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: '本地书籍',
                          value: '${books.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          label: '在读',
                          value: '${continueReading.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          label: '已缓存',
                          value:
                              '${ref.watch(audioCacheEntriesProvider).valueOrNull?.length ?? 0}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (recentlyImported.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: LiquidGlassCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.file_upload_outlined,
                      size: 48,
                      color: Color(0xFF5D7CFF),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '先导入第一本书',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '导入 EPUB / PDF 后，这里会自动整理最近加入、在读和已完成内容。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _importBook(context, ref),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('导入书籍'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          _section(
            context: context,
            title: '最近导入',
            books: recentlyImported.take(4).toList(growable: false),
          ),
          _section(
            context: context,
            title: '继续阅读',
            books: continueReading.take(4).toList(growable: false),
            emptyText: '还没有在读内容，打开一本书开始吧。',
          ),
          _section(
            context: context,
            title: '已读完',
            books: completed.take(4).toList(growable: false),
            emptyText: '还没有已完成的书。',
          ),
        ],
      ],
    );
  }

  SliverToBoxAdapter _section({
    required BuildContext context,
    required String title,
    required List<Book> books,
    String? emptyText,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          children: [
            SectionHeader(title: title, actionLabel: '${books.length} 本'),
            const SizedBox(height: 10),
            if (books.isEmpty)
              LiquidGlassCard(
                child: Text(
                  emptyText ?? '暂无内容',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )
            else
              ...books.map(
                (book) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BookRow(book: book),
                ),
              ),
          ],
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
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
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
        color: Colors.white.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(18),
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

class _BookRow extends ConsumerWidget {
  const _BookRow({
    required this.book,
  });

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiquidGlassCard(
      onTap: () => context.push('/book/${book.id}'),
      child: Row(
        children: [
          BookCoverArt(
            book: book,
            width: 72,
            height: 100,
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
                  book.lastReadAt == null
                      ? '导入于 ${recencyLabel(book.importedAt)}'
                      : '最近阅读 ${recencyLabel(book.lastReadAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6A7694),
                      ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: book.progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFDDE5FF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () async {
              await ref.read(readerControllerProvider).playAutoForCurrentBook(
                    book,
                  );
              if (!context.mounted) return;
              context.go('/player');
            },
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }
}

String _filterLabel(_DiscoverFilter filter) {
  return switch (filter) {
    _DiscoverFilter.all => '全部',
    _DiscoverFilter.recent => '最近导入',
    _DiscoverFilter.reading => '在读',
    _DiscoverFilter.finished => '已读完',
    _DiscoverFilter.epub => 'EPUB',
    _DiscoverFilter.pdf => 'PDF',
  };
}
