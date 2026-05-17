import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/book_ai.dart';
import 'package:chibook/data/models/book_annotation.dart';
import 'package:chibook/features/bookshelf/presentation/widgets/book_annotation_sheet.dart';
import 'package:chibook/features/reader/application/epub_reader_controller.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:chibook/services/book_ai_service.dart';
import 'package:chibook/services/book_annotation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookNotebookScreen extends ConsumerStatefulWidget {
  const BookNotebookScreen({
    super.key,
    required this.bookId,
  });

  final String bookId;

  @override
  ConsumerState<BookNotebookScreen> createState() => _BookNotebookScreenState();
}

class _BookNotebookScreenState extends ConsumerState<BookNotebookScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(currentBookProvider(widget.bookId));
    final annotationsAsync = ref.watch(bookAnnotationsProvider(widget.bookId));
    final currentExcerpt = ref.watch(readerExcerptProvider(widget.bookId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: bookAsync.when(
            data: (book) {
              if (book == null) {
                return const Center(child: Text('找不到这本书'));
              }
              final bundleAsync = ref.watch(
                bookAiBundleProvider(BookAiRequest.fromBook(book)),
              );
              return annotationsAsync.when(
                data: (annotations) => bundleAsync.when(
                  data: (bundle) => Column(
                    children: [
                      _NotebookHeader(
                        title: book.title,
                        highlightCount: annotations
                            .where(
                              (item) =>
                                  item.kind == BookAnnotationKind.highlight,
                            )
                            .length,
                        noteCount: annotations
                            .where(
                              (item) =>
                                  item.kind == BookAnnotationKind.note ||
                                  item.hasNote,
                            )
                            .length,
                        onBack: () => Navigator.of(context).pop(),
                        onAddFromCurrent: currentExcerpt.trim().isEmpty
                            ? null
                            : () => showBookAnnotationComposer(
                                  context: context,
                                  ref: ref,
                                  bookId: book.id,
                                  quote: currentExcerpt,
                                  locationLabel: '当前段落',
                                  sectionTitle: '阅读器当前位置',
                                  initialKind: BookAnnotationKind.highlight,
                                ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(text: '划线'),
                            Tab(text: '笔记'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _AnnotationList(
                              book: book,
                              annotations: annotations
                                  .where(
                                    (item) =>
                                        item.kind ==
                                        BookAnnotationKind.highlight,
                                  )
                                  .toList(),
                              emptyQuotes: bundle.quoteCandidates,
                              emptyTitle: '还没有保存划线',
                              emptyHint: '可以从阅读页当前段落直接加入，也可以先从 AI 摘要里挑几句。',
                            ),
                            _AnnotationList(
                              book: book,
                              annotations: annotations
                                  .where(
                                    (item) =>
                                        item.kind == BookAnnotationKind.note ||
                                        item.hasNote,
                                  )
                                  .toList(),
                              emptyQuotes:
                                  bundle.quoteCandidates.skip(1).toList(),
                              emptyTitle: '还没有写下笔记',
                              emptyHint: '在阅读器或 PDF 选区里保存时补一句想法，这里会慢慢积累成你的笔记流。',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      Center(child: Text('生成推荐内容失败: $error')),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('加载笔记失败: $error')),
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

class _NotebookHeader extends StatelessWidget {
  const _NotebookHeader({
    required this.title,
    required this.highlightCount,
    required this.noteCount,
    required this.onBack,
    this.onAddFromCurrent,
  });

  final String title;
  final int highlightCount;
  final int noteCount;
  final VoidCallback onBack;
  final VoidCallback? onAddFromCurrent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '划线与笔记',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: LiquidGlassCard(
                    radius: 22,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('划线',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Text(
                          '$highlightCount',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LiquidGlassCard(
                    radius: 22,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('笔记',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Text(
                          '$noteCount',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onAddFromCurrent != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAddFromCurrent,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('从当前段落加入'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnnotationList extends ConsumerWidget {
  const _AnnotationList({
    required this.book,
    required this.annotations,
    required this.emptyQuotes,
    required this.emptyTitle,
    required this.emptyHint,
  });

  final Book book;
  final List<BookAnnotation> annotations;
  final List<String> emptyQuotes;
  final String emptyTitle;
  final String emptyHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (annotations.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          LiquidGlassCard(
            child: Column(
              children: [
                const Icon(
                  Icons.sticky_note_2_outlined,
                  size: 46,
                  color: Color(0xFF5D7CFF),
                ),
                const SizedBox(height: 14),
                Text(
                  emptyTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  emptyHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                ),
              ],
            ),
          ),
          if (emptyQuotes.isNotEmpty) ...[
            const SizedBox(height: 14),
            const SectionHeader(title: '推荐先收下的句子'),
            const SizedBox(height: 12),
            ...emptyQuotes.take(3).map(
                  (quote) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LiquidGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quote,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      height: 1.6,
                                    ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: () => showBookAnnotationComposer(
                              context: context,
                              ref: ref,
                              bookId: book.id,
                              quote: quote,
                              locationLabel: 'AI 推荐摘录',
                              sectionTitle: book.title,
                              initialKind: BookAnnotationKind.highlight,
                            ),
                            icon: const Icon(Icons.bookmark_add_outlined),
                            label: const Text('加入划线'),
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      itemCount: annotations.length,
      itemBuilder: (context, index) {
        final item = annotations[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LiquidGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(item.colorValue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.sectionTitle == null
                            ? item.locationLabel
                            : '${item.sectionTitle} · ${item.locationLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await ref
                            .read(bookAnnotationServiceProvider)
                            .removeAnnotation(item.id);
                        ref.invalidate(bookAnnotationsProvider(book.id));
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.quote,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                ),
                if (item.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.48),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      item.note,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF42506A),
                            height: 1.6,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
