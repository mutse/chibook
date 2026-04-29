import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/epub_models.dart';
import 'package:chibook/data/models/pdf_chapter_toc_item.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/reader/application/epub_reader_controller.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:chibook/features/settings/application/speech_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  String? _selectedBookId;

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(bookshelfControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        dark: true,
        child: SafeArea(
          child: booksAsync.when(
            data: (books) => _buildBody(context, books),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载播放页失败: $error')),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Book> books) {
    if (books.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlayerTopBar(
              onTimerTap: () => _showTimerSheet(context),
              onSpeedTap: () => _showSpeedSheet(context),
              onChaptersTap: () {},
            ),
            const Spacer(),
            LiquidGlassCard(
              colors: const [Color(0x33FFFFFF), Color(0x14FFFFFF)],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.headphones_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '还没有可播放的书',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '从首页或书架导入一本 EPUB / PDF，就可以在这里直接开启 AI 听书。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('去首页导入'),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      );
    }

    final recentBooks = sortBooksByRecent(books);
    final activeBookId = ref.watch(readerActiveAutoBookIdProvider);
    final effectiveBookId =
        _selectedBookId ?? activeBookId ?? recentBooks.first.id;
    final currentBook = recentBooks.firstWhere(
      (book) => book.id == effectiveBookId,
      orElse: () => recentBooks.first,
    );
    final currentIndex =
        recentBooks.indexWhere((book) => book.id == currentBook.id);
    final speechState = ref.watch(readerSpeechStateProvider);
    final autoSpeech = ref.watch(readerAutoSpeechProvider(currentBook.id));
    final excerpt = ref.watch(readerExcerptProvider(currentBook.id));
    final settings = ref.watch(speechSettingsControllerProvider).valueOrNull;
    final queue = [
      ...recentBooks.skip(currentIndex + 1),
      ...recentBooks.take(currentIndex),
    ].take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        _PlayerTopBar(
          onTimerTap: () => _showTimerSheet(context),
          onSpeedTap: () => _showSpeedSheet(context),
          onChaptersTap: () => _showChapterSheet(context, currentBook),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 300,
            height: 360,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        bookPalette(currentBook).last.withValues(alpha: 0.44),
                        bookPalette(currentBook).first.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 12,
                  child: WaveformLine(
                    color: Colors.white,
                    barCount: 22,
                    barWidth: 3,
                    minHeight: 5,
                    maxHeight: 18,
                    spacing: 3,
                  ),
                ),
                BookCoverArt(
                  book: currentBook,
                  width: 238,
                  height: 320,
                  radius: 32,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          currentBook.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          autoSpeech?.label ??
              '${currentBook.author} · ${estimatedListenLabel(currentBook)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.80),
              ),
        ),
        const SizedBox(height: 18),
        LiquidGlassCard(
          colors: const [Color(0x33FFFFFF), Color(0x14FFFFFF)],
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    '播放进度',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    progressLabel(currentBook),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.74),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: currentBook.progress.clamp(0.04, 1.0),
                  minHeight: 6,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '当前章节',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${(currentBook.progress.clamp(0, 1) * 100).round()}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const WaveformLine(
                color: Colors.white,
                barCount: 18,
                barWidth: 2.6,
                minHeight: 4,
                maxHeight: 14,
                spacing: 2.8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LiquidGlassCard(
          colors: const [Color(0x2EFFFFFF), Color(0x12FFFFFF)],
          radius: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PlayerActionChip(
                icon: Icons.speed_rounded,
                label: '${settings?.speed.toStringAsFixed(1) ?? '1.0'}x',
                onTap: () => _showSpeedSheet(context),
              ),
              IconButton(
                onPressed: currentIndex <= 0
                    ? null
                    : () => setState(() {
                          _selectedBookId = recentBooks[currentIndex - 1].id;
                        }),
                icon: const Icon(
                  Icons.skip_previous_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              _PlayPauseButton(
                book: currentBook,
                speechState: speechState,
              ),
              IconButton(
                onPressed: currentIndex >= recentBooks.length - 1
                    ? null
                    : () => setState(() {
                          _selectedBookId = recentBooks[currentIndex + 1].id;
                        }),
                icon: const Icon(
                  Icons.skip_next_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              _PlayerActionChip(
                icon: Icons.toc_rounded,
                label: '目录',
                onTap: () => _showChapterSheet(context, currentBook),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/reader/${currentBook.id}'),
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('打开原文'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push('/book/${currentBook.id}'),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('书籍详情'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LiquidGlassCard(
          colors: const [Color(0x33FFFFFF), Color(0x14FFFFFF)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '当前朗读内容',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    pseudoCategoryForBook(currentBook),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                excerpt.trim().isEmpty
                    ? '播放会从当前章节或当前页开始。如果你还没有打开原文，系统会从书籍开头自动建立朗读会话。'
                    : excerpt,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.84),
                      height: 1.6,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (queue.isNotEmpty) ...[
          Text(
            '接下来播放',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          ...queue.map(
            (book) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QueueTile(
                book: book,
                onTap: () => setState(() => _selectedBookId = book.id),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showTimerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF2F6FF),
      builder: (context) => const _TimerSheet(),
    );
  }

  void _showSpeedSheet(BuildContext context) {
    final settings = ref.read(speechSettingsControllerProvider).valueOrNull;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF2F6FF),
      builder: (context) => _SpeedSheet(
        currentSpeed: settings?.speed ?? 1.0,
        onSelected: (speed) async {
          final currentSettings =
              ref.read(speechSettingsControllerProvider).valueOrNull;
          if (currentSettings == null) return;
          await ref
              .read(speechSettingsControllerProvider.notifier)
              .save(currentSettings.copyWith(speed: speed));
          if (!mounted) return;
          navigator.pop();
          messenger.showSnackBar(
            SnackBar(content: Text('播放语速已切到 ${speed.toStringAsFixed(1)}x')),
          );
        },
      ),
    );
  }

  void _showChapterSheet(BuildContext context, Book book) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF2F6FF),
      isScrollControlled: true,
      builder: (context) => _ChapterSheet(book: book),
    );
  }
}

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.onTimerTap,
    required this.onSpeedTap,
    required this.onChaptersTap,
  });

  final VoidCallback onTimerTap;
  final VoidCallback onSpeedTap;
  final VoidCallback onChaptersTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '播放页',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '把听书控制收拢到一个更沉浸的入口里',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.74),
                  ),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: onSpeedTap,
          icon: const Icon(Icons.speed_rounded, color: Colors.white),
        ),
        IconButton(
          onPressed: onTimerTap,
          icon: const Icon(Icons.timer_outlined, color: Colors.white),
        ),
        IconButton(
          onPressed: onChaptersTap,
          icon: const Icon(Icons.toc_rounded, color: Colors.white),
        ),
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.tune_rounded, color: Colors.white),
        ),
      ],
    );
  }
}

class _PlayPauseButton extends ConsumerWidget {
  const _PlayPauseButton({
    required this.book,
    required this.speechState,
  });

  final Book book;
  final ReaderSpeechState speechState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(readerControllerProvider);
    final isPlaying = speechState == ReaderSpeechState.playing;

    return GestureDetector(
      onTap: () async {
        if (speechState == ReaderSpeechState.paused) {
          await controller.resumeSpeech();
          return;
        }
        if (speechState == ReaderSpeechState.playing) {
          await controller.pauseSpeech();
          return;
        }
        await controller.playAutoForCurrentBook(book);
      },
      child: Container(
        width: 78,
        height: 78,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF76C3FF), Color(0xFF5A7CFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x2D72A8FF),
              blurRadius: 26,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 44,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _PlayerActionChip extends StatelessWidget {
  const _PlayerActionChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.book,
    required this.onTap,
  });

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      colors: const [Color(0x29FFFFFF), Color(0x10FFFFFF)],
      onTap: onTap,
      child: Row(
        children: [
          BookCoverArt(
            book: book,
            width: 62,
            height: 84,
            radius: 18,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '下一本',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${book.author} · ${estimatedListenLabel(book)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ),
          const Icon(Icons.play_arrow_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

class _TimerSheet extends StatelessWidget {
  const _TimerSheet();

  @override
  Widget build(BuildContext context) {
    const options = ['15 分钟', '30 分钟', '60 分钟', '90 分钟'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '定时关闭',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '先提供一个常用睡眠定时入口，后续可以把它接入真正的播放会话。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < options.length; i++) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(options[i]),
              trailing: i == 1
                  ? const Icon(Icons.check_circle, color: Color(0xFF5D7CFF))
                  : const Icon(Icons.circle_outlined),
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _SpeedSheet extends StatelessWidget {
  const _SpeedSheet({
    required this.currentSpeed,
    required this.onSelected,
  });

  final double currentSpeed;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = [0.8, 1.0, 1.2, 1.5];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '播放语速',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '这一步先做成快速切换入口，真正的语速持久化仍然在朗读设置页里。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: options.map((speed) {
              final selected = (speed - currentSpeed).abs() < 0.01;
              return GestureDetector(
                onTap: () => onSelected(speed),
                child: TagChip(
                  label: '${speed.toStringAsFixed(1)}x',
                  active: selected,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ChapterSheet extends ConsumerWidget {
  const _ChapterSheet({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: book.format == BookFormat.epub
            ? _EpubChapterSheet(book: book)
            : _PdfChapterSheet(book: book),
      ),
    );
  }
}

class _EpubChapterSheet extends ConsumerWidget {
  const _EpubChapterSheet({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epubAsync = ref.watch(epubBookProvider(book.filePath));

    return epubAsync.when(
      data: (epubBook) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '章节目录',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '选一章后会从该章节开始建立新的自动朗读会话。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: epubBook.chapters.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final chapter = epubBook.chapters[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(chapter.title),
                  subtitle: Text('第 ${chapter.index + 1} 章'),
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: () => _playEpubChapter(
                    context: context,
                    ref: ref,
                    chapter: chapter,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('章节加载失败: $error'),
    );
  }

  Future<void> _playEpubChapter({
    required BuildContext context,
    required WidgetRef ref,
    required EpubChapterData chapter,
  }) async {
    ref.read(currentEpubChapterProvider(book.id).notifier).state = chapter;
    await ref.read(readerControllerProvider).playAutoForCurrentBook(book);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    context.go('/player');
  }
}

class _PdfChapterSheet extends ConsumerWidget {
  const _PdfChapterSheet({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tocAsync = ref.watch(pdfChapterTocProvider(book.filePath));

    return tocAsync.when(
      data: (toc) {
        if (toc.isEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '页码跳转',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '这个 PDF 暂时没有识别到章节目录，建议先打开原文后按页继续播放。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '章节目录',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '选中某一节后，播放器会从对应起始页继续自动朗读。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: toc.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = toc[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.title),
                    subtitle: Text(
                      item.isSinglePage
                          ? '第 ${item.startPage} 页'
                          : '${item.startPage}-${item.endPage} 页',
                    ),
                    trailing: const Icon(Icons.play_arrow_rounded),
                    onTap: () => _playPdfChapter(
                      context: context,
                      ref: ref,
                      item: item,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('章节加载失败: $error'),
    );
  }

  Future<void> _playPdfChapter({
    required BuildContext context,
    required WidgetRef ref,
    required PdfChapterTocItem item,
  }) async {
    ref.read(currentPdfPageProvider(book.id).notifier).state = item.startPage;
    ref.read(requestedPdfPageProvider(book.id).notifier).state = item.startPage;
    await ref.read(readerControllerProvider).playAutoForCurrentBook(book);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    context.go('/player');
  }
}
