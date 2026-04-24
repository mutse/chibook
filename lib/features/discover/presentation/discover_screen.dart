import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _selectedCategory = '全部';

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
              selectedCategory: _selectedCategory,
              onSelectCategory: (category) {
                setState(() => _selectedCategory = category);
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

class _DiscoverBody extends StatelessWidget {
  const _DiscoverBody({
    required this.books,
    required this.selectedCategory,
    required this.onSelectCategory,
  });

  final List<Book> books;
  final String selectedCategory;
  final ValueChanged<String> onSelectCategory;

  @override
  Widget build(BuildContext context) {
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
    final featured = filteredBooks.take(3).toList();
    final smartMix = filteredBooks.reversed.take(4).toList();

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
                  '发现',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                const AppSearchBar(hint: '搜索书名 / 作者 / 关键词'),
                const SizedBox(height: 20),
                LiquidGlassCard(
                  radius: 30,
                  colors: const [Color(0xFFEEF4FF), Color(0xB9FFFFFF)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '为你整理的今日推荐',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        books.isEmpty
                            ? '先导入几本书，我会按你的书库气质把发现页补成真正可逛的推荐流。'
                            : '根据你最近导入和收听的书，先把更适合“现在开始听”的内容提到前面。',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: categories.map((category) {
                          return GestureDetector(
                            onTap: () => onSelectCategory(category),
                            child: TagChip(
                              label: category,
                              active: selectedCategory == category,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (featured.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: SectionHeader(
                title: '热门书单',
                actionLabel: '${filteredBooks.length} 本',
              ),
            ),
          ),
        if (featured.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 250,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                scrollDirection: Axis.horizontal,
                itemCount: featured.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) =>
                    _FeaturedCard(book: featured[index]),
              ),
            ),
          ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: SectionHeader(title: '热门分类'),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: categories
                  .where((category) => category != '全部')
                  .map(
                    (category) => _CategoryCard(
                      title: category,
                      count: recentBooks
                          .where(
                              (book) => pseudoCategoryForBook(book) == category)
                          .length,
                      active: selectedCategory == category,
                      onTap: () => onSelectCategory(category),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        if (smartMix.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: SectionHeader(
                title: '猜你喜欢',
                actionLabel: '换一组',
                onTap: () {},
              ),
            ),
          ),
          SliverList.builder(
            itemCount: smartMix.length,
            itemBuilder: (context, index) {
              final book = smartMix[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _RecommendationRow(book: book),
              );
            },
          ),
        ] else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
              child: LiquidGlassCard(
                child: Text(
                  selectedCategory == '全部'
                      ? '导入几本书后，这里会出现更贴近你的推荐流。'
                      : '当前分类下还没有匹配内容，先切回“全部”看看。',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.6),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 30,
      onTap: () => context.push('/book/${book.id}'),
      colors: bookPalette(book),
      child: SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pseudoCategoryForBook(book),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${book.author} · ${estimatedListenLabel(book)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '打开书籍',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String title;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 24,
      onTap: onTap,
      colors: active ? const [Color(0xFF5D7CFF), Color(0xFF84C9FF)] : null,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.18)
                  : const Color(0xFF5D7CFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _categoryIcon(title),
              color: active ? Colors.white : const Color(0xFF5D7CFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : null,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${count == 0 ? 1 : count} 本',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: active
                            ? Colors.white.withValues(alpha: 0.82)
                            : null,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      '个人成长' => Icons.person_rounded,
      '心理学' => Icons.psychology_rounded,
      '管理' => Icons.workspaces_rounded,
      '历史' => Icons.history_edu_rounded,
      '经济' => Icons.trending_up_rounded,
      '小说' => Icons.auto_stories_rounded,
      _ => Icons.grid_view_rounded,
    };
  }
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 26,
      onTap: () => context.push('/book/${book.id}'),
      child: Row(
        children: [
          BookCoverArt(
            book: book,
            width: 76,
            height: 104,
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
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF7080A8)),
        ],
      ),
    );
  }
}
