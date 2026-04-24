import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookshelfControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: booksAsync.when(
            data: (books) => _DownloadsBody(books: books),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载下载管理失败: $error')),
          ),
        ),
      ),
    );
  }
}

class _DownloadsBody extends StatelessWidget {
  const _DownloadsBody({required this.books});

  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    final sortedBooks = sortBooksByRecent(books);
    final totalMb = sortedBooks.fold<double>(
      0,
      (sum, book) => sum + _sizeForBook(book),
    );
    final activeCount = sortedBooks.where((book) => book.progress < 1).length;

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
              '下载管理',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _StorageHero(
          bookCount: sortedBooks.length,
          totalMb: totalMb,
          activeCount: activeCount,
        ),
        const SizedBox(height: 18),
        if (sortedBooks.isEmpty)
          const _DownloadEmptyState()
        else ...[
          SectionHeader(
            title: '缓存队列',
            actionLabel: '${sortedBooks.length} 项',
          ),
          const SizedBox(height: 8),
          ...sortedBooks.map((book) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DownloadRow(
                book: book,
                sizeMb: _sizeForBook(book),
              ),
            );
          }),
        ],
      ],
    );
  }

  double _sizeForBook(Book book) {
    return (book.totalLocations > 0
            ? book.totalLocations / 36
            : book.title.length * 1.6)
        .clamp(12, 240)
        .toDouble();
  }
}

class _StorageHero extends StatelessWidget {
  const _StorageHero({
    required this.bookCount,
    required this.totalMb,
    required this.activeCount,
  });

  final int bookCount;
  final double totalMb;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 32,
      colors: const [
        Color(0xFFEAF2FF),
        Color(0xD9FFFFFF),
        Color(0xFFDDEAFF),
      ],
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C92FF).withValues(alpha: 0.16),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5C7CFF), Color(0xFF7FD8FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.cloud_done_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '离线听书缓存',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bookCount == 0
                              ? '还没有离线缓存'
                              : '$activeCount 项正在保持可随时播放',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: const Color(0xFF647196)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: _StorageStat(
                      label: '可用空间',
                      value: '23.4',
                      unit: 'GB',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StorageStat(
                      label: '已缓存',
                      value: totalMb.toStringAsFixed(1),
                      unit: 'MB',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StorageStat(
                      label: '书籍',
                      value: '$bookCount',
                      unit: '本',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StorageStat extends StatelessWidget {
  const _StorageStat({
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: unit,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({
    required this.book,
    required this.sizeMb,
  });

  final Book book;
  final double sizeMb;

  @override
  Widget build(BuildContext context) {
    final progress =
        book.progress <= 0 ? 0.26 : book.progress.clamp(0.18, 1.0).toDouble();
    final palette = bookPalette(book);

    return LiquidGlassCard(
      radius: 28,
      child: Row(
        children: [
          BookCoverArt(
            book: book,
            width: 66,
            height: 92,
            radius: 18,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TagChip(
                      label: book.progress >= 1 ? '已下载' : '下载中',
                      active: book.progress < 1,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${sizeMb.toStringAsFixed(1)} MB',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF647196),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                  '语音缓存 ${progressLabel(book)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: palette.first,
                    backgroundColor: const Color(0xFFDCE5FF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () {},
            icon: Icon(
              book.progress >= 1 ? Icons.check_rounded : Icons.pause_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadEmptyState extends StatelessWidget {
  const _DownloadEmptyState();

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 30,
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF5D7CFF).withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.download_for_offline_outlined,
              color: Color(0xFF5D7CFF),
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有可管理的下载',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '导入书籍后，这里会显示离线缓存、语音片段和预计占用空间。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
