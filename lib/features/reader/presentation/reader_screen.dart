import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/reader_preferences.dart';
import 'package:chibook/data/models/speech_settings.dart';
import 'package:chibook/features/reader/application/epub_reader_controller.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:chibook/features/reader/application/reader_preferences_controller.dart';
import 'package:chibook/features/reader/presentation/widgets/epub_reader_view.dart';
import 'package:chibook/features/reader/presentation/widgets/pdf_reader_view.dart';
import 'package:chibook/features/reader/presentation/widgets/reader_preferences_sheet.dart';
import 'package:chibook/features/settings/application/speech_settings_controller.dart';
import 'package:chibook/services/reader_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(currentBookProvider(bookId));
    final preferences = ref.watch(readerPreferencesControllerProvider).value ??
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

            return LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape =
                    constraints.maxWidth > constraints.maxHeight;
                return Column(
                  children: [
                    _ReaderHeader(
                      book: book,
                      colors: screenColors,
                      isLandscape: isLandscape,
                    ),
                    Expanded(
                      child: switch (book.format) {
                        BookFormat.pdf => PdfReaderView(
                            book: book,
                            compact: isLandscape,
                          ),
                        BookFormat.epub => EpubReaderView(
                            book: book,
                            compact: isLandscape,
                          ),
                      },
                    ),
                    _SpeechBar(
                      book: book,
                      colors: screenColors,
                      isLandscape: isLandscape,
                    ),
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text('Failed to open book: $error')),
        ),
      ),
    );
  }
}

class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader({
    required this.book,
    required this.colors,
    required this.isLandscape,
  });

  final Book book;
  final _ScreenColors colors;
  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          12, isLandscape ? 6 : 12, 12, isLandscape ? 6 : 12),
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
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(Icons.palette_outlined, color: colors.foreground),
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(Icons.tune, color: colors.foreground),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  book.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.foreground,
                        fontSize: isLandscape ? 18 : null,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isLandscape ? 2 : 4),
                Text(
                  '${book.author} · ${book.formatLabel}',
                  style: TextStyle(color: colors.secondaryForeground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
    required this.isLandscape,
  });

  final Book book;
  final _ScreenColors colors;
  final bool isLandscape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(readerControllerProvider);
    final excerpt = ref.watch(readerExcerptProvider(book.id));
    final chapter = ref.watch(currentEpubChapterProvider(book.id));
    final speechState = ref.watch(readerSpeechStateProvider);
    final speechText = chapter != null
        ? chapter.plainText
        : (excerpt.trim().isEmpty
            ? '现在开始朗读 ${book.title}。请在设置页完成 OpenAI TTS 配置，或者切换到本地 TTS。'
            : excerpt);
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
      padding: EdgeInsets.fromLTRB(
          12, isLandscape ? 8 : 12, 12, isLandscape ? 10 : 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: isLandscape ? 0 : 120,
                maxWidth: isLandscape ? 220 : 180,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AI语音朗读',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.foreground,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _speechStateLabel(
                      speechState,
                      cacheStatusAsync.valueOrNull ?? false,
                    ),
                    style: TextStyle(
                      color: colors.secondaryForeground,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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
              label: Text(chapter != null ? '朗读本章' : '播放'),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: '声音',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (context) => const _VoiceQuickSheet(),
                );
              },
              icon: const Icon(Icons.record_voice_over_outlined),
            ),
            IconButton(
              tooltip: '暂停',
              visualDensity: VisualDensity.compact,
              onPressed: speechState == ReaderSpeechState.playing
                  ? controller.pauseSpeech
                  : null,
              icon: const Icon(Icons.pause_circle_outline),
            ),
            IconButton(
              tooltip: '继续',
              visualDensity: VisualDensity.compact,
              onPressed: speechState == ReaderSpeechState.paused
                  ? controller.resumeSpeech
                  : null,
              icon: const Icon(Icons.play_circle_outline),
            ),
            if (canCacheChapter)
              IconButton(
                tooltip: '缓存本章',
                visualDensity: VisualDensity.compact,
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
            const SizedBox(width: 4),
            OutlinedButton.icon(
              onPressed: controller.stopSpeech,
              icon: const Icon(Icons.stop),
              label: const Text('停止'),
            ),
          ],
        ),
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
                    ref
                        .read(currentEpubChapterProvider(book.id).notifier)
                        .state = chapter;
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

class _VoiceQuickSheet extends ConsumerStatefulWidget {
  const _VoiceQuickSheet();

  @override
  ConsumerState<_VoiceQuickSheet> createState() => _VoiceQuickSheetState();
}

class _VoiceQuickSheetState extends ConsumerState<_VoiceQuickSheet> {
  late final TextEditingController _customVoiceController;
  String _selectedOpenAiVoice = ReaderSpeechService.openAiVoices.first;
  String _localVoiceId = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _customVoiceController = TextEditingController();
  }

  @override
  void dispose() {
    _customVoiceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(speechSettingsControllerProvider);

    ref.listen<AsyncValue<SpeechSettings>>(speechSettingsControllerProvider, (
      previous,
      next,
    ) {
      next.whenData((settings) {
        if (_initialized && previous?.value == settings) return;
        _applySettings(settings);
      });
    });

    return settingsAsync.when(
      data: (settings) {
        if (!_initialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _applySettings(settings);
          });
        }
        final localVoicesAsync = ref.watch(localVoiceOptionsProvider);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                '快速声音切换',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '保存后，下次播放立即生效。',
                style: Theme.of(
                  context,
                )
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: const Color(0xFF5D645F)),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: ReaderSpeechService.openAiVoices.contains(
                  _selectedOpenAiVoice,
                )
                    ? _selectedOpenAiVoice
                    : null,
                decoration: const InputDecoration(labelText: 'OpenAI 声音'),
                items: ReaderSpeechService.openAiVoices
                    .map(
                      (voice) => DropdownMenuItem<String>(
                        value: voice,
                        child: Text(voice),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedOpenAiVoice = value;
                    _customVoiceController.text = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customVoiceController,
                decoration: const InputDecoration(
                  labelText: '自定义 OpenAI Voice（可选）',
                  hintText: '例如: alloy',
                ),
              ),
              const SizedBox(height: 12),
              localVoicesAsync.when(
                data: (voices) {
                  final hasCurrentSelection = _localVoiceId.isNotEmpty &&
                      voices.any((voice) => voice.id == _localVoiceId);
                  final effectiveValue = hasCurrentSelection
                      ? _localVoiceId
                      : (_localVoiceId.isEmpty ? '' : null);
                  return DropdownButtonFormField<String>(
                    initialValue: effectiveValue,
                    decoration: const InputDecoration(labelText: '设备 TTS 声音'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('系统默认'),
                      ),
                      ...voices.map(
                        (voice) => DropdownMenuItem<String>(
                          value: voice.id,
                          child: Text(
                            voice.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _localVoiceId = value ?? '';
                      });
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => Text('读取本地声音失败: $error'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  final voice = _customVoiceController.text.trim();
                  final messenger = ScaffoldMessenger.of(context);
                  await ref
                      .read(speechSettingsControllerProvider.notifier)
                      .save(
                        settings.copyWith(
                          voice: voice.isEmpty ? _selectedOpenAiVoice : voice,
                          localVoiceId: _localVoiceId,
                        ),
                      );
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  messenger
                      .showSnackBar(const SnackBar(content: Text('声音设置已保存')));
                },
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('加载声音设置失败: $error'),
      ),
    );
  }

  void _applySettings(SpeechSettings settings) {
    _initialized = true;
    _selectedOpenAiVoice = ReaderSpeechService.openAiVoices.contains(
      settings.voice,
    )
        ? settings.voice
        : ReaderSpeechService.openAiVoices.first;
    _customVoiceController.text = settings.voice;
    _localVoiceId = settings.localVoiceId;
    setState(() {});
  }
}
