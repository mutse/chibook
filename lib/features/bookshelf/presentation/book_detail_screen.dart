import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/pdf_chapter_toc_item.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_insights.dart';
import 'package:chibook/features/reader/application/epub_reader_controller.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  const BookDetailScreen({
    super.key,
    required this.bookId,
    this.initialTabIndex = 0,
  });

  final String bookId;
  final int initialTabIndex;

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  late int _selectedTab = widget.initialTabIndex;

  @override
  void didUpdateWidget(covariant BookDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex &&
        widget.initialTabIndex != _selectedTab) {
      _selectedTab = widget.initialTabIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(currentBookProvider(widget.bookId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: bookAsync.when(
            data: (book) {
              if (book == null) {
                return const Center(child: Text('找不到这本书'));
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () =>
                            context.push('/book/${book.id}?tab=toc'),
                        icon: const Icon(Icons.toc_rounded),
                      ),
                      IconButton(
                        onPressed: () =>
                            context.push('/book/${book.id}?tab=summary'),
                        icon: const Icon(Icons.auto_awesome_rounded),
                      ),
                      IconButton(
                        onPressed: () => _showBookActions(book),
                        icon: const Icon(Icons.more_horiz_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _BookHero(
                    book: book,
                    onListen: () async {
                      await ref
                          .read(readerControllerProvider)
                          .playAutoForCurrentBook(book);
                      if (!context.mounted) return;
                      context.go('/player');
                    },
                  ),
                  const SizedBox(height: 16),
                  _SegmentRail(
                    selectedTab: _selectedTab,
                    onSelected: (index) => setState(() => _selectedTab = index),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: switch (_selectedTab) {
                      0 => _BookOverview(
                          key: const ValueKey('overview'),
                          book: book,
                        ),
                      1 => _BookToc(
                          key: const ValueKey('toc'),
                          book: book,
                        ),
                      _ => _BookSummary(
                          key: const ValueKey('summary'),
                          book: book,
                        ),
                    },
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载书籍详情失败: $error')),
          ),
        ),
      ),
    );
  }

  Future<void> _showBookActions(Book book) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: const Text('打开原文'),
                subtitle: const Text('回到沉浸式阅读界面'),
                onTap: () {
                  Navigator.of(context).pop();
                  this.context.push('/reader/${book.id}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('从书架移除'),
                subtitle: const Text('删除本地书籍记录和阅读进度'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _deleteBook(book);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBook(Book book) async {
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
    if (confirmed != true || !mounted) return;

    await ref.read(bookshelfControllerProvider.notifier).removeBook(book.id);
    if (!mounted) return;
    context.pop();
  }
}

class _BookHero extends StatelessWidget {
  const _BookHero({
    required this.book,
    required this.onListen,
  });

  final Book book;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final infoItems = [
      ('在听人数', '${book.title.length * 1100}'),
      ('当前进度', progressLabel(book)),
      ('阅读格式', book.formatLabel),
    ];

    return LiquidGlassCard(
      colors: const [Color(0xFFE8F1FF), Color(0xFFBDD6FF)],
      child: Column(
        children: [
          SizedBox(
            width: 280,
            height: 310,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        bookPalette(book).last.withValues(alpha: 0.36),
                        bookPalette(book).first.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 8,
                  child: WaveformLine(
                    color: Color(0xFF5D7CFF),
                    barCount: 20,
                    barWidth: 2.8,
                    minHeight: 5,
                    maxHeight: 16,
                    spacing: 2.8,
                  ),
                ),
                BookCoverArt(
                  book: book,
                  width: 166,
                  height: 224,
                  radius: 28,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            book.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${book.author} · ${pseudoCategoryForBook(book)}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              TagChip(label: book.formatLabel),
              TagChip(label: pseudoCategoryForBook(book)),
              TagChip(label: book.progress > 0 ? '继续收听' : '适合开听'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '适合先判断，再沉浸，再回到原文。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < infoItems.length; i++) ...[
                Expanded(
                  child: _InfoBadge(
                    label: infoItems[i].$1,
                    value: infoItems[i].$2,
                  ),
                ),
                if (i != infoItems.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/reader/${book.id}'),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('打开原文'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onListen,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('立即收听'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentRail extends StatelessWidget {
  const _SegmentRail({
    required this.selectedTab,
    required this.onSelected,
  });

  final int selectedTab;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('简介', '先判断值不值得听'),
      ('目录', '快速挑章节'),
      ('AI 摘要', '3 个重点先看'),
    ];

    return LiquidGlassCard(
      padding: const EdgeInsets.all(10),
      colors: const [Color(0xE8FFFFFF), Color(0xB7E7F5FF)],
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: selectedTab == i
                        ? const Color(0xFF5D7CFF)
                        : Colors.transparent,
                  ),
                  child: Column(
                    children: [
                      Text(
                        items[i].$1,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: selectedTab == i
                                  ? Colors.white
                                  : const Color(0xFF68789E),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].$2,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: selectedTab == i
                                  ? Colors.white.withValues(alpha: 0.88)
                                  : const Color(0xFF7D89A8),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
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
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _BookOverview extends StatelessWidget {
  const _BookOverview({
    super.key,
    required this.book,
  });

  final Book book;

  @override
  Widget build(BuildContext context) {
    final remainingMinutes =
        (estimateBookMinutes(book) * (1 - book.progress.clamp(0.0, 1.0)))
            .round();

    return Column(
      children: [
        LiquidGlassCard(
          colors: const [Color(0xEFFFFFFF), Color(0xB1ECF6FF)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '内容概览',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                '《${book.title}》被整理进新的听书体验之后，详情页承担的是“先帮你判断，再帮你进入”的角色。你可以先看简介和 AI 摘要，如果已经明确想读，再直接跳到目录或立即收听。',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.7),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  TagChip(label: book.formatLabel),
                  TagChip(label: pseudoCategoryForBook(book)),
                  const TagChip(label: 'AI 朗读'),
                  const TagChip(label: '沉浸式听书'),
                ],
              ),
              const SizedBox(height: 16),
              const WaveformLine(
                color: Color(0xFF5D7CFF),
                barCount: 16,
                barWidth: 2.4,
                minHeight: 4,
                maxHeight: 12,
                spacing: 2.4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LiquidGlassCard(
          colors: const [Color(0xECFFFFFF), Color(0xB9E7F5FF)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '阅读状态',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InfoBadge(
                      label: '最近阅读',
                      value: book.lastReadAt == null
                          ? '未开始'
                          : recencyLabel(book.lastReadAt),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InfoBadge(
                      label: '剩余时长',
                      value: remainingMinutes <= 0
                          ? '已完成'
                          : '$remainingMinutes 分钟',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                book.progress > 0
                    ? '已经进入 ${progressLabel(book)}，现在最适合从上次停下的位置继续。'
                    : '还没开始阅读，先看摘要或目录，再决定从哪里进入会更轻松。',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LiquidGlassCard(
          colors: const [Color(0xE7FFFFFF), Color(0xA6EEF6FF)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '适合谁先听',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              ...[
                '想先快速知道这本书值不值得投入完整时间的人',
                '希望用目录定位章节，再从感兴趣的部分开始听的人',
                '已经在读，希望把碎片时间转成连续输入的人',
              ].map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF5D7CFF),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookToc extends ConsumerWidget {
  const _BookToc({
    super.key,
    required this.book,
  });

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (book.format == BookFormat.epub) {
      final epubAsync = ref.watch(epubBookProvider(book.filePath));
      return epubAsync.when(
        data: (epubBook) => _TocCard(
          book: book,
          rows: epubBook.chapters
              .map(
                (chapter) => _TocData(
                  title: chapter.title,
                  trailing: '第 ${chapter.index + 1} 章',
                  onPlay: (context) async {
                    ref
                        .read(currentEpubChapterProvider(book.id).notifier)
                        .state = chapter;
                    await ref
                        .read(readerControllerProvider)
                        .playAutoForCurrentBook(book);
                    if (!context.mounted) return;
                    context.go('/player');
                  },
                  onOpen: (context) async {
                    ref
                        .read(currentEpubChapterProvider(book.id).notifier)
                        .state = chapter;
                    if (!context.mounted) return;
                    context.push('/reader/${book.id}');
                  },
                ),
              )
              .toList(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => LiquidGlassCard(
          child: Text('目录加载失败: $error'),
        ),
      );
    }

    final tocAsync = ref.watch(pdfChapterTocProvider(book.filePath));
    return tocAsync.when(
      data: (toc) => _PdfTocContent(book: book, toc: toc),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => LiquidGlassCard(
        child: Text('目录加载失败: $error'),
      ),
    );
  }
}

class _PdfTocContent extends ConsumerWidget {
  const _PdfTocContent({
    required this.book,
    required this.toc,
  });

  final Book book;
  final List<PdfChapterTocItem> toc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (toc.isEmpty) {
      return LiquidGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '目录',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '这个 PDF 暂时没有识别到章节目录，阅读器里会按页继续播放。',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return _TocCard(
      book: book,
      rows: toc
          .map(
            (item) => _TocData(
              title: item.title,
              trailing: item.isSinglePage
                  ? '第 ${item.startPage} 页'
                  : '${item.startPage}-${item.endPage} 页',
              onPlay: (context) async {
                ref.read(currentPdfPageProvider(book.id).notifier).state =
                    item.startPage;
                ref.read(requestedPdfPageProvider(book.id).notifier).state =
                    item.startPage;
                await ref
                    .read(readerControllerProvider)
                    .playAutoForCurrentBook(book);
                if (!context.mounted) return;
                context.go('/player');
              },
              onOpen: (context) async {
                ref.read(currentPdfPageProvider(book.id).notifier).state =
                    item.startPage;
                ref.read(requestedPdfPageProvider(book.id).notifier).state =
                    item.startPage;
                if (!context.mounted) return;
                context.push('/reader/${book.id}');
              },
            ),
          )
          .toList(),
    );
  }
}

class _TocCard extends StatelessWidget {
  const _TocCard({
    required this.book,
    required this.rows,
  });

  final Book book;
  final List<_TocData> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LiquidGlassCard(
          colors: const [Color(0xEEFFFFFF), Color(0xBCEAF7FF)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '目录',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${rows.length} 节',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '先从你最感兴趣的一章开始听，会比从头硬扛更容易进入状态。',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LiquidGlassCard(
          colors: const [Color(0xEFFFFFFF), Color(0xA8EAF7FF)],
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                _TocRow(
                  title: rows[i].title,
                  trailing: rows[i].trailing,
                  onPlay: () => rows[i].onPlay(context),
                  onOpen: () => rows[i].onOpen(context),
                ),
                if (i != rows.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TocRow extends StatelessWidget {
  const _TocRow({
    required this.title,
    required this.trailing,
    required this.onPlay,
    required this.onOpen,
  });

  final String title;
  final String trailing;
  final VoidCallback onPlay;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  trailing,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6F7EA8),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _TocActionButton(
                label: '播放',
                icon: Icons.play_arrow_rounded,
                filled: true,
                onPressed: onPlay,
              ),
              const SizedBox(height: 8),
              _TocActionButton(
                label: '原文',
                icon: Icons.menu_book_rounded,
                onPressed: onOpen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TocActionButton extends StatelessWidget {
  const _TocActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : const Color(0xFF4968E8);
    final background = filled ? const Color(0xFF5D7CFF) : Colors.white;
    final borderColor =
        filled ? const Color(0xFF5D7CFF) : const Color(0xFFD9E4FF);

    return SizedBox(
      width: 92,
      height: 36,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: background,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(color: borderColor),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _BookSummary extends StatelessWidget {
  const _BookSummary({
    super.key,
    required this.book,
  });

  final Book book;

  List<String> _summaryPoints(Book book) {
    final progress = (book.progress.clamp(0, 1) * 100).round();
    return [
      '这本书最适合被放进“详情判断 -> 播放沉浸 -> 原文深读”的三段式流程里。',
      progress > 0
          ? '你已经听到 $progress% 左右，下一次回到播放器时可以直接从当前章节继续。'
          : '你还没有开始听这本书，建议先从第一章用 1.0x 的标准语速建立节奏。',
      '如果需要快速决策，优先看 AI 摘要和目录；如果已经确定要读，就直接进入原文或立即收听。',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final points = _summaryPoints(book);

    return Column(
      children: [
        LiquidGlassCard(
          colors: const [Color(0xEDFFFFFF), Color(0xB8ECF7FF)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'AI 摘要',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '基于书名、格式与当前进度整理',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '这本书现在更像一段可连续消费的内容流。新的 app 结构把它放进“详情 -> 播放 -> 原文”的链路里，先帮助你判断，再帮助你沉浸。',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LiquidGlassCard(
          colors: const [Color(0xEFFFFFFF), Color(0xA7E9F7FF)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '3 个核心观点',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < points.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF5D7CFF),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        points[i],
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
                if (i != points.length - 1) const SizedBox(height: 14),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        LiquidGlassCard(
          colors: const [Color(0xEEFFFFFF), Color(0xB3EAF7FF)],
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/book/${book.id}?tab=toc'),
                  icon: const Icon(Icons.toc_rounded),
                  label: const Text('去看目录'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push('/reader/${book.id}'),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('进入原文'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TocData {
  const _TocData({
    required this.title,
    required this.trailing,
    required this.onPlay,
    required this.onOpen,
  });

  final String title;
  final String trailing;
  final Future<void> Function(BuildContext context) onPlay;
  final Future<void> Function(BuildContext context) onOpen;
}
