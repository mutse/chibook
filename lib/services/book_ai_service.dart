import 'dart:math' as math;

import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/book_ai.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:chibook/features/reader/application/epub_reader_controller.dart';
import 'package:chibook/services/epub_service.dart';
import 'package:chibook/services/pdf_chapter_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bookAiServiceProvider = Provider<BookAiService>((ref) {
  return BookAiService(
    epubService: ref.read(epubServiceProvider),
    pdfChapterService: ref.read(pdfChapterServiceProvider),
  );
});

final bookAiBundleProvider =
    FutureProvider.family<BookAiBundle, BookAiRequest>((ref, request) {
  return ref.read(bookAiServiceProvider).buildBundle(request);
});

class BookAiService {
  const BookAiService({
    required this.epubService,
    required this.pdfChapterService,
  });

  final EpubService epubService;
  final PdfChapterService pdfChapterService;

  Future<BookAiBundle> buildBundle(BookAiRequest request) async {
    final sections = await _loadSections(request);
    final effectiveSections = sections.isEmpty
        ? [
            BookContentSection(
              id: 'fallback',
              title: request.title,
              locationLabel:
                  request.format == BookFormat.epub ? '第 1 章' : '第 1 页',
              text: '导入后还没有识别到稳定文本，可以先从阅读器打开原文，再回到这里生成总结和思维导图。',
              estimatedMinutes: 6,
              chapterIndex: request.format == BookFormat.epub ? 0 : null,
              pageNumber: request.format == BookFormat.pdf ? 1 : null,
            ),
          ]
        : sections;
    final progressPercent = (request.progress.clamp(0, 1) * 100).round();
    final first = effectiveSections.first;
    final last = effectiveSections.last;
    final overview = '《${request.title}》更适合用“先总览，再按章节听，最后回到原文”的方式进入。'
        '当前内容从 ${first.title} 展开，最终会推进到 ${last.title}。';
    final summaryPoints = [
      '这本书当前最清晰的主线是“${_clip(first.title, 18)} -> ${_clip(last.title, 18)}”，先抓大结构会比直接细读更轻松。',
      progressPercent > 0
          ? '你已经读到 $progressPercent% 左右，下一次最适合从最近一节继续，而不是重新从开头进入。'
          : '还没有开始阅读，建议先从第一节听 8 到 12 分钟，建立节奏以后再决定是否深读。',
      '先看 AI 总结和思维导图，再用播放列表挑章节进入，会更接近参考图里那种“判断 -> 沉浸 -> 回看”的体验。',
    ];
    final readingAdvice =
        '如果想快速判断值不值得投入时间，先看《${first.title}》和《${effectiveSections[math.min(1, effectiveSections.length - 1)].title}》；'
        '如果已经确定要读，直接从播放列表开始连续收听即可。';
    final quoteCandidates = _quoteCandidates(effectiveSections);
    final mindMapBranches = effectiveSections
        .take(4)
        .map(
          (section) => BookMindMapBranch(
            title: _clip(section.title, 16),
            leaves: _sentenceLeaves(section.text),
          ),
        )
        .toList();
    final keywords = _keywords(request, effectiveSections);

    return BookAiBundle(
      overview: overview,
      summaryPoints: summaryPoints,
      readingAdvice: readingAdvice,
      quoteCandidates: quoteCandidates,
      askSuggestions: const [
        '这本书最值得先听的部分是什么？',
        '它更适合哪类读者？',
        '如果只有 20 分钟，应该从哪里开始？',
        '这本书现在的主线可以怎么理解？',
      ],
      mindMapBranches: mindMapBranches,
      sections: effectiveSections,
      keywords: keywords,
    );
  }

  String answerQuestion({
    required Book book,
    required BookAiBundle bundle,
    required String question,
  }) {
    final normalized = question.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '可以直接问我这本书讲了什么、适合谁，或者从哪里开始更高效。';
    }

    if (_matches(normalized, const ['适合', '谁', '读者'])) {
      return '这本书更适合已经对“${bundle.keywords.take(2).join(' / ')}”有兴趣、'
          '但又不想一上来就陷进细节的人。先看总结，再选一节进入，会更容易形成自己的判断。';
    }

    if (_matches(normalized, const ['重点', '核心', '主线', '讲了什么'])) {
      return [
        '这本书可以先抓 3 个重点：',
        ...bundle.summaryPoints.map((item) => '1. $item'),
      ].join('\n');
    }

    if (_matches(normalized, const ['怎么', '开始', '20', '二十', '顺序'])) {
      return '${bundle.readingAdvice}\n\n如果只留 20 分钟，优先听：'
          '${bundle.sections.take(2).map((item) => item.title).join('、')}。';
    }

    final matchedSection =
        bundle.sections.cast<BookContentSection?>().firstWhere(
              (section) =>
                  section != null &&
                  normalized.contains(section.title.toLowerCase()),
              orElse: () => null,
            );
    if (matchedSection != null) {
      return '和“${matchedSection.title}”最相关的一段内容是：'
          '${_clip(_firstSentence(matchedSection.text), 80)}。'
          '你可以直接去 ${matchedSection.locationLabel} 打开原文或开始收听。';
    }

    return '${bundle.overview}\n\n如果你现在想更快进入，建议直接去播放列表挑一节，'
        '或者继续追问“适合谁”“重点是什么”“应该从哪里开始”。';
  }

  Future<List<BookContentSection>> _loadSections(BookAiRequest request) async {
    if (request.format == BookFormat.epub) {
      final epubBook = await epubService.loadBook(request.filePath);
      return epubBook.chapters.take(10).map((chapter) {
        final text = _normalizeText(chapter.plainText);
        return BookContentSection(
          id: 'epub-${chapter.index}',
          title: chapter.title.trim().isEmpty
              ? '第 ${chapter.index + 1} 章'
              : chapter.title,
          locationLabel: '第 ${chapter.index + 1} 章',
          text: _clip(text, 1200),
          estimatedMinutes: _estimateMinutes(text),
          chapterIndex: chapter.index,
        );
      }).toList();
    }

    final toc = await pdfChapterService.listChapters(request.filePath);
    if (toc.isNotEmpty) {
      final sections = <BookContentSection>[];
      for (final item in toc.take(8)) {
        final chapter = await pdfChapterService.resolveCurrentChapter(
          filePath: request.filePath,
          pageNumber: item.startPage,
        );
        final text = _normalizeText(chapter.text);
        sections.add(
          BookContentSection(
            id: 'pdf-${chapter.startPage}-${chapter.endPage}',
            title: chapter.title.trim().isEmpty
                ? (chapter.isSinglePage
                    ? '第 ${chapter.startPage} 页'
                    : '第 ${chapter.startPage}-${chapter.endPage} 页')
                : chapter.title,
            locationLabel: chapter.isSinglePage
                ? '第 ${chapter.startPage} 页'
                : '第 ${chapter.startPage}-${chapter.endPage} 页',
            text: _clip(text, 1200),
            estimatedMinutes: _estimateMinutes(text),
            pageNumber: chapter.startPage,
          ),
        );
      }
      return sections;
    }

    final pageCount = await pdfChapterService.pageCount(request.filePath);
    final sections = <BookContentSection>[];
    for (var page = 1; page <= math.min(pageCount, 6); page++) {
      final data = await pdfChapterService.extractPage(
        filePath: request.filePath,
        pageNumber: page,
      );
      final text = _normalizeText(data.text);
      sections.add(
        BookContentSection(
          id: 'pdf-page-$page',
          title: '第 $page 页',
          locationLabel: '第 $page 页',
          text: _clip(text, 1000),
          estimatedMinutes: _estimateMinutes(text),
          pageNumber: page,
        ),
      );
    }
    return sections;
  }

  List<String> _quoteCandidates(List<BookContentSection> sections) {
    return sections
        .expand((section) => _splitSentences(section.text))
        .map((item) => item.trim())
        .where((item) => item.length >= 18)
        .take(6)
        .map((item) => _clip(item, 88))
        .toList();
  }

  List<String> _sentenceLeaves(String text) {
    final sentences = _splitSentences(text)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(2)
        .map((item) => _clip(item, 22))
        .toList();
    if (sentences.isEmpty) {
      return const ['提炼核心观点', '回到原文定位细节'];
    }
    if (sentences.length == 1) {
      return [sentences.first, '回到原文定位细节'];
    }
    return sentences;
  }

  List<String> _keywords(
      BookAiRequest request, List<BookContentSection> sections) {
    final raw = <String>[
      request.title,
      ...sections.map((item) => item.title),
    ];
    final result = <String>[];
    for (final item in raw) {
      final cleaned =
          item.replaceAll(RegExp(r'[^\u4e00-\u9fa5A-Za-z0-9 ]'), ' ').trim();
      if (cleaned.isEmpty) continue;
      final parts = cleaned
          .split(RegExp(r'\s+'))
          .where((part) => part.length >= 2)
          .take(2);
      for (final part in parts) {
        if (result.contains(part)) continue;
        result.add(part);
        if (result.length >= 6) return result;
      }
    }
    return result.isEmpty ? ['结构', '章节', '重点'] : result;
  }

  bool _matches(String input, List<String> keys) {
    return keys.any((key) => input.contains(key));
  }

  String _normalizeText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').replaceAll('\u0000', '').trim();
  }

  List<String> _splitSentences(String text) {
    return text
        .split(RegExp(r'(?<=[。！？!?])'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _firstSentence(String text) {
    final sentences = _splitSentences(text);
    return sentences.isEmpty ? text.trim() : sentences.first;
  }

  int _estimateMinutes(String text) {
    final length = text.trim().length;
    return math.max(6, (length / 180).round());
  }

  String _clip(String text, int maxLength) {
    final trimmed = text.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength).trim()}...';
  }
}
