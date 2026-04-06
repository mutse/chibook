import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/reader_preferences.dart';
import 'package:chibook/data/models/epub_models.dart';
import 'package:chibook/features/reader/application/epub_reader_controller.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:chibook/features/reader/application/reader_preferences_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EpubReaderView extends ConsumerStatefulWidget {
  const EpubReaderView({
    super.key,
    required this.book,
    this.compact = false,
  });

  final Book book;
  final bool compact;

  @override
  ConsumerState<EpubReaderView> createState() => _EpubReaderViewState();
}

class _EpubReaderViewState extends ConsumerState<EpubReaderView> {
  int _currentChapterIndex = 0;
  int? _lastSyncedChapterIndex;

  @override
  Widget build(BuildContext context) {
    final epubAsync = ref.watch(epubBookProvider(widget.book.filePath));
    final requestedChapter =
        ref.watch(currentEpubChapterProvider(widget.book.id));
    final preferencesAsync = ref.watch(readerPreferencesControllerProvider);
    final preferences = preferencesAsync.value ?? ReaderPreferences.defaults();
    final colors = _themeColors(preferences.themeMode);

    return epubAsync.when(
      data: (epubBook) {
        final chapters = epubBook.chapters;
        if (requestedChapter != null &&
            requestedChapter.index != _currentChapterIndex &&
            requestedChapter.index >= 0 &&
            requestedChapter.index < chapters.length) {
          _currentChapterIndex = requestedChapter.index;
        }
        final boundedIndex = _currentChapterIndex.clamp(0, chapters.length - 1);
        final chapter = chapters[boundedIndex];
        _syncChapterState(chapter, chapters.length);

        return Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, widget.compact ? 8 : 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(widget.compact ? 20 : 28),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    widget.compact ? 12 : 20,
                    16,
                    widget.compact ? 8 : 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '第 ${boundedIndex + 1} / ${chapters.length} 章',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.secondaryText,
                                  ),
                        ),
                      ),
                      Builder(
                        builder: (buttonContext) {
                          return IconButton(
                            tooltip: '目录',
                            onPressed: () {
                              Scaffold.of(buttonContext).openEndDrawer();
                            },
                            icon: Icon(
                              Icons.menu_book_outlined,
                              color: colors.primaryText,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colors.divider),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      widget.compact ? 16 : 20,
                      18,
                      widget.compact ? 16 : 24,
                    ),
                    children: [
                      Text(
                        chapter.title,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.primaryText,
                                ),
                      ),
                      const SizedBox(height: 18),
                      SelectionArea(
                        child: Html(
                          data: chapter.htmlContent,
                          style: {
                            'body': Style(
                              margin: Margins.zero,
                              fontSize: FontSize(preferences.fontSize),
                              lineHeight: LineHeight(preferences.lineHeight),
                              color: colors.primaryText,
                            ),
                            'p': Style(
                              margin: Margins.only(bottom: 18),
                            ),
                            'h1': Style(
                              fontSize: FontSize(preferences.fontSize + 10),
                              color: colors.primaryText,
                            ),
                            'h2': Style(
                              fontSize: FontSize(preferences.fontSize + 6),
                              color: colors.primaryText,
                            ),
                            'h3': Style(
                              fontSize: FontSize(preferences.fontSize + 4),
                              color: colors.primaryText,
                            ),
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    widget.compact ? 8 : 12,
                    16,
                    widget.compact ? 12 : 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: boundedIndex == 0
                              ? null
                              : () {
                                  setState(() => _currentChapterIndex -= 1);
                                },
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('上一章'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: boundedIndex >= chapters.length - 1
                              ? null
                              : () {
                                  setState(() => _currentChapterIndex += 1);
                                },
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('下一章'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to parse EPUB: $error'),
        ),
      ),
    );
  }

  void _syncChapterState(EpubChapterData chapter, int total) {
    if (_lastSyncedChapterIndex == chapter.index) return;
    _lastSyncedChapterIndex = chapter.index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(readerControllerProvider);
      controller.setReaderExcerpt(
          bookId: widget.book.id, text: chapter.plainText);
      ref.read(currentEpubChapterProvider(widget.book.id).notifier).state =
          chapter;
      final percentage = total <= 0 ? 0.0 : (chapter.index + 1) / total;
      controller.updateProgress(
        bookId: widget.book.id,
        location: 'chapter:${chapter.index}',
        percentage: percentage.clamp(0.0, 1.0).toDouble(),
      );
    });
  }

  _ReaderThemeColors _themeColors(ReaderThemeMode mode) {
    return switch (mode) {
      ReaderThemeMode.paper => const _ReaderThemeColors(
          background: Colors.white,
          primaryText: Color(0xFF1E2824),
          secondaryText: Color(0xFF607067),
          divider: Color(0xFFE9E3D8),
        ),
      ReaderThemeMode.sepia => const _ReaderThemeColors(
          background: Color(0xFFF4ECD8),
          primaryText: Color(0xFF3A2F24),
          secondaryText: Color(0xFF7A6A5B),
          divider: Color(0xFFD8CCBA),
        ),
      ReaderThemeMode.night => const _ReaderThemeColors(
          background: Color(0xFF141A18),
          primaryText: Color(0xFFE7ECE9),
          secondaryText: Color(0xFF97A6A0),
          divider: Color(0xFF26312D),
        ),
    };
  }
}

class _ReaderThemeColors {
  const _ReaderThemeColors({
    required this.background,
    required this.primaryText,
    required this.secondaryText,
    required this.divider,
  });

  final Color background;
  final Color primaryText;
  final Color secondaryText;
  final Color divider;
}
