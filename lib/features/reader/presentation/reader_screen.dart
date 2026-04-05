import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/reader_preferences.dart';
import 'package:chibook/features/reader/application/epub_reader_controller.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:chibook/features/reader/application/reader_preferences_controller.dart';
import 'package:chibook/features/reader/presentation/widgets/epub_reader_view.dart';
import 'package:chibook/features/reader/presentation/widgets/pdf_reader_view.dart';
import 'package:chibook/features/reader/presentation/widgets/reader_preferences_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({
    super.key,
    required this.bookId,
  });

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(currentBookProvider(bookId));
    final preferences =
        ref.watch(readerPreferencesControllerProvider).value ??
            ReaderPreferences.defaults();
    final screenColors = _screenColors(preferences.themeMode);

    return Scaffold(
      backgroundColor: screenColors.background,
      endDrawer: bookAsync.valueOrNull?.format == BookFormat.epub
          ? _EpubTocDrawer(book: bookAsync.valueOrNull!)
          : null,
      body: SafeArea(
        child: bookAsync.when(
          data: (book) {
            if (book == null) {
              return const Center(child: Text('Book not found'));
            }

            return Column(
              children: [
                _ReaderHeader(
                  book: book,
                  colors: screenColors,
                ),
                Expanded(
                  child: switch (book.format) {
                    BookFormat.pdf => PdfReaderView(book: book),
                    BookFormat.epub => EpubReaderView(book: book),
                  },
                ),
                _SpeechBar(
                  book: book,
                  colors: screenColors,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Failed to open book: $error'),
          ),
        ),
      ),
    );
  }
}

class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader({
    required this.book,
    required this.colors,
  });

  final Book book;
  final _ScreenColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (context) => const ReaderPreferencesSheet(),
              );
            },
            icon: Icon(Icons.palette_outlined, color: colors.foreground),
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: Icon(Icons.tune, color: colors.foreground),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.foreground,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${book.author} · ${book.formatLabel}',
                  style: TextStyle(color: colors.secondaryForeground),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: colors.foreground),
          ),
        ],
      ),
    );
  }
}

class _SpeechBar extends ConsumerWidget {
  const _SpeechBar({
    required this.book,
    required this.colors,
  });

  final Book book;
  final _ScreenColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(readerControllerProvider);
    final excerpt = ref.watch(readerExcerptProvider(book.id));
    final chapter = ref.watch(currentEpubChapterProvider(book.id));
    final speechState = ref.watch(readerSpeechStateProvider);
    final speechText = excerpt.trim().isEmpty
        ? '现在开始朗读 ${book.title}。请在设置页完成 OpenAI TTS 配置，或者切换到本地 TTS。'
        : excerpt;
    final canCacheChapter = chapter != null && speechText.trim().isNotEmpty;
    final cacheStatusAsync = canCacheChapter
        ? ref.watch(
            _chapterCacheStatusProvider(
              _ChapterCacheRequest(
                bookId: book.id,
                segmentId: 'epub-chapter-${chapter.index}',
                text: speechText,
              ),
            ),
          )
        : const AsyncData(false);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI 语音朗读',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.foreground,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _speechStateLabel(speechState, cacheStatusAsync.valueOrNull ?? false),
                  style: TextStyle(
                    color: colors.secondaryForeground,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              if (chapter != null) {
                controller.speakBookSegment(
                  bookId: book.id,
                  segmentId: 'epub-chapter-${chapter.index}',
                  text: speechText,
                );
                return;
              }
              controller.speakBookSegment(
                bookId: book.id,
                segmentId: 'default',
                text: speechText,
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('播放'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '暂停',
            onPressed: speechState == ReaderSpeechState.playing
                ? controller.pauseSpeech
                : null,
            icon: const Icon(Icons.pause_circle_outline),
          ),
          IconButton(
            tooltip: '继续',
            onPressed: speechState == ReaderSpeechState.paused
                ? controller.resumeSpeech
                : null,
            icon: const Icon(Icons.play_circle_outline),
          ),
          if (canCacheChapter) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: '缓存本章',
              onPressed: speechState == ReaderSpeechState.caching
                  ? null
                  : () async {
                      await controller.cacheBookSegment(
                        bookId: book.id,
                        segmentId: 'epub-chapter-${chapter.index}',
                        text: speechText,
                      );
                      ref.invalidate(
                        _chapterCacheStatusProvider(
                          _ChapterCacheRequest(
                            bookId: book.id,
                            segmentId: 'epub-chapter-${chapter.index}',
                            text: speechText,
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.download_for_offline_outlined),
            ),
          ],
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: controller.stopSpeech,
            icon: const Icon(Icons.stop),
            label: const Text('停止'),
          ),
        ],
      ),
    );
  }
}

String _speechStateLabel(ReaderSpeechState state, bool cached) {
  final stateLabel = switch (state) {
    ReaderSpeechState.idle => '待机',
    ReaderSpeechState.playing => '播放中',
    ReaderSpeechState.paused => '已暂停',
    ReaderSpeechState.caching => '缓存章节音频中',
  };
  return cached ? '$stateLabel · 本章已缓存' : stateLabel;
}

class _ChapterCacheRequest {
  const _ChapterCacheRequest({
    required this.bookId,
    required this.segmentId,
    required this.text,
  });

  final String bookId;
  final String segmentId;
  final String text;

  @override
  bool operator ==(Object other) {
    return other is _ChapterCacheRequest &&
        other.bookId == bookId &&
        other.segmentId == segmentId &&
        other.text == text;
  }

  @override
  int get hashCode => Object.hash(bookId, segmentId, text);
}

final _chapterCacheStatusProvider =
    FutureProvider.family<bool, _ChapterCacheRequest>((ref, request) {
  return ref.read(readerControllerProvider).hasCachedBookSegment(
        bookId: request.bookId,
        segmentId: request.segmentId,
        text: request.text,
      );
});

class _EpubTocDrawer extends ConsumerWidget {
  const _EpubTocDrawer({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epubAsync = ref.watch(epubBookProvider(book.filePath));
    final currentChapter = ref.watch(currentEpubChapterProvider(book.id));

    return Drawer(
      child: epubAsync.when(
        data: (epub) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              Text(
                '目录',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              ...epub.chapters.map((chapter) {
                final selected = currentChapter?.index == chapter.index;
                return ListTile(
                  contentPadding: EdgeInsets.only(
                    left: 8 + (chapter.depth * 14),
                    right: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  selected: selected,
                  selectedTileColor: const Color(0xFFE7F2EE),
                  title: Text(
                    chapter.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    ref.read(currentEpubChapterProvider(book.id).notifier).state =
                        chapter;
                    Navigator.of(context).pop(chapter.index);
                  },
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('目录加载失败: $error')),
      ),
    );
  }
}

_ScreenColors _screenColors(ReaderThemeMode mode) {
  return switch (mode) {
    ReaderThemeMode.paper => const _ScreenColors(
        background: Color(0xFFF6F1E7),
        surface: Colors.white,
        foreground: Color(0xFF18211D),
        secondaryForeground: Color(0xFF607067),
        border: Color(0xFFE8E0D4),
      ),
    ReaderThemeMode.sepia => const _ScreenColors(
        background: Color(0xFFEFE4CD),
        surface: Color(0xFFF4ECD8),
        foreground: Color(0xFF3A2F24),
        secondaryForeground: Color(0xFF7A6A5B),
        border: Color(0xFFD8CCBA),
      ),
    ReaderThemeMode.night => const _ScreenColors(
        background: Color(0xFF0F1412),
        surface: Color(0xFF141A18),
        foreground: Color(0xFFE7ECE9),
        secondaryForeground: Color(0xFF97A6A0),
        border: Color(0xFF26312D),
      ),
  };
}

class _ScreenColors {
  const _ScreenColors({
    required this.background,
    required this.surface,
    required this.foreground,
    required this.secondaryForeground,
    required this.border,
  });

  final Color background;
  final Color surface;
  final Color foreground;
  final Color secondaryForeground;
  final Color border;
}
