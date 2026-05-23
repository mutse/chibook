import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/book_ai.dart';
import 'package:chibook/features/reader/application/epub_reader_controller.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:chibook/services/book_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BookPlaylistScreen extends ConsumerWidget {
  const BookPlaylistScreen({
    super.key,
    required this.bookId,
  });

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(currentBookProvider(bookId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        dark: true,
        child: SafeArea(
          child: bookAsync.when(
            data: (book) {
              if (book == null) {
                return const Center(child: Text('找不到这本书'));
              }
              final bundleAsync = ref.watch(
                bookAiBundleProvider(BookAiRequest.fromBook(book)),
              );
              return bundleAsync.when(
                data: (bundle) => _PlaylistBody(book: book, bundle: bundle),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    Center(child: Text('生成播放列表失败: $error')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载书籍失败: $error')),
          ),
        ),
      ),
    );
  }
}

class _PlaylistBody extends ConsumerWidget {
  const _PlaylistBody({
    required this.book,
    required this.bundle,
  });

  final Book book;
  final BookAiBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentChapter = ref.watch(currentEpubChapterProvider(book.id));
    final currentPage = ref.watch(currentPdfPageProvider(book.id));
    final totalMinutes = bundle.sections.fold<int>(
      0,
      (sum, item) => sum + item.estimatedMinutes,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '播放列表',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LiquidGlassCard(
          colors: const [Color(0x2EFFFFFF), Color(0x14FFFFFF)],
          child: Row(
            children: [
              BookCoverArt(
                book: book,
                width: 86,
                height: 118,
                radius: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${bundle.sections.length} 个播放段落',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '预计总时长 $totalMinutes 分钟 · ${book.formatLabel}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        await _openSection(
                          ref: ref,
                          book: book,
                          section: bundle.sections.first,
                          play: true,
                        );
                        if (!context.mounted) return;
                        context.go('/player');
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('从头播放'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...bundle.sections.asMap().entries.map((entry) {
          final index = entry.key;
          final section = entry.value;
          final selected = book.format == BookFormat.epub
              ? section.chapterIndex == currentChapter?.index
              : section.pageNumber == currentPage;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LiquidGlassCard(
              colors: selected
                  ? const [Color(0x3DFFFFFF), Color(0x22B6D8FF)]
                  : const [Color(0x26FFFFFF), Color(0x12FFFFFF)],
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? const Color(0xFF80C8FF)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${section.locationLabel} · ${section.estimatedMinutes} 分钟',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.76),
                                  ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          section.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    height: 1.6,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                await _openSection(
                                  ref: ref,
                                  book: book,
                                  section: section,
                                  play: true,
                                );
                                if (!context.mounted) return;
                                context.go('/player');
                              },
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(selected ? '继续播放' : '播放'),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await _openSection(
                                  ref: ref,
                                  book: book,
                                  section: section,
                                  play: false,
                                );
                                if (!context.mounted) return;
                                context.push('/reader/${book.id}');
                              },
                              icon: const Icon(Icons.menu_book_rounded),
                              label: const Text('原文'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.30),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _openSection({
    required WidgetRef ref,
    required Book book,
    required BookContentSection section,
    required bool play,
  }) async {
    if (book.format == BookFormat.epub) {
      final epub = await ref.read(epubBookProvider(book.filePath).future);
      final chapter = epub.chapters.firstWhere(
        (item) => item.index == (section.chapterIndex ?? 0),
        orElse: () => epub.chapters.first,
      );
      ref.read(currentEpubChapterProvider(book.id).notifier).state = chapter;
    } else {
      final page = section.pageNumber ?? 1;
      ref.read(currentPdfPageProvider(book.id).notifier).state = page;
      ref.read(requestedPdfPageProvider(book.id).notifier).state = page;
    }
    if (play) {
      await ref.read(readerControllerProvider).playAutoForCurrentBook(book);
    }
  }
}
