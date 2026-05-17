import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ReadingHistoryScreen extends ConsumerWidget {
  const ReadingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookshelfControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: booksAsync.when(
            data: (books) => _HistoryBody(books: books),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载阅读历史失败: $error')),
          ),
        ),
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.books});

  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    final recentBooks = sortBooksByRecent(books);
    final activeBooks = recentBooks.where((book) => book.progress > 0).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
            const SizedBox(width: 8),
            Text(
              '阅读历史',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LiquidGlassCard(
          radius: 32,
          colors: const [
            Color(0xFFEFF5FF),
            Color(0xD9FFFFFF),
            Color(0xFFE2EBFF),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '最近足迹',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                recentBooks.isEmpty
                    ? '还没有形成阅读历史，导入一本书开始吧。'
                    : '最近 ${activeBooks.length} 本留下了阅读或收听记录，适合从最近停下的位置继续。',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _HistoryStat(
                      label: '最近记录',
                      value: '${recentBooks.length}',
                      unit: '本',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HistoryStat(
                      label: '继续在读',
                      value:
                          '${activeBooks.where((book) => book.progress < 1).length}',
                      unit: '本',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HistoryStat(
                      label: '已完成',
                      value:
                          '${recentBooks.where((book) => book.progress >= 1).length}',
                      unit: '本',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (recentBooks.isEmpty)
          LiquidGlassCard(
            child: Column(
              children: [
                const Icon(
                  Icons.history_toggle_off_rounded,
                  size: 46,
                  color: Color(0xFF5D7CFF),
                ),
                const SizedBox(height: 14),
                Text(
                  '还没有历史记录',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  '导入 EPUB / PDF 后，阅读页、播放页和书籍详情都会在这里留下最近轨迹。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                ),
              ],
            ),
          )
        else ...[
          const SectionHeader(title: '最近打开'),
          const SizedBox(height: 8),
          ...recentBooks.map(
            (book) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LiquidGlassCard(
                radius: 26,
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
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
                                : '最近打开 ${recencyLabel(book.lastReadAt)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: const Color(0xFF6A7694)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: book.progress <= 0
                                        ? 0.08
                                        : book.progress.clamp(0.08, 1.0),
                                    minHeight: 6,
                                    backgroundColor: const Color(0xFFDDE5FF),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                progressLabel(book),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: const Color(0xFF5D7CFF),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF7080A8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryStat extends StatelessWidget {
  const _HistoryStat({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

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
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: unit,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
