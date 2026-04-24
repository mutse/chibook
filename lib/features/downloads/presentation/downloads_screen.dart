import 'package:chibook/app/liquid_ui.dart';
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
            data: (books) => ListView(
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
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (books.isEmpty)
                  const LiquidGlassCard(
                    child: Text('导入书籍后，这里会显示离线缓存、语音片段和预计占用空间。'),
                  )
                else
                  ...books.map((book) {
                    final progress = book.progress <= 0
                        ? 0.26
                        : book.progress.clamp(0.18, 1.0);
                    final sizeMb = ((book.totalLocations > 0
                            ? book.totalLocations / 36
                            : book.title.length * 1.6))
                        .clamp(12, 240)
                        .toStringAsFixed(1);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LiquidGlassCard(
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
                                    '语音缓存 ${progressLabel(book)}',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFFDCE5FF),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$sizeMb MB',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(
                                  Icons.pause_circle_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载下载管理失败: $error')),
          ),
        ),
      ),
    );
  }
}
