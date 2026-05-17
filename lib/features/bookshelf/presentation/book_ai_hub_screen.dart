import 'dart:math' as math;

import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/book_ai.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:chibook/services/book_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookAiHubScreen extends ConsumerStatefulWidget {
  const BookAiHubScreen({
    super.key,
    required this.bookId,
    this.initialTabIndex = 0,
  });

  final String bookId;
  final int initialTabIndex;

  @override
  ConsumerState<BookAiHubScreen> createState() => _BookAiHubScreenState();
}

class _BookAiHubScreenState extends ConsumerState<BookAiHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _questionController = TextEditingController();
  final List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void didUpdateWidget(covariant BookAiHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = widget.initialTabIndex.clamp(0, 2);
    if (nextIndex != _tabController.index) {
      _tabController.index = nextIndex;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionController.dispose();
    super.dispose();
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
              final bundleAsync = ref.watch(
                bookAiBundleProvider(BookAiRequest.fromBook(book)),
              );
              return bundleAsync.when(
                data: (bundle) => Column(
                  children: [
                    _Header(
                      title: 'AI 阅读助手',
                      subtitle: book.title,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: LiquidGlassCard(
                        radius: 26,
                        padding: const EdgeInsets.all(10),
                        colors: const [Color(0xEEFFFFFF), Color(0xB7EAF6FF)],
                        child: Column(
                          children: [
                            Row(
                              children: [
                                BookCoverArt(
                                  book: book,
                                  width: 74,
                                  height: 102,
                                  radius: 20,
                                  showMeta: false,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        book.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${book.author} · ${pseudoCategoryForBook(book)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          TagChip(label: book.formatLabel),
                                          TagChip(label: progressLabel(book)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.50),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                bundle.overview,
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'AI 总结'),
                          Tab(text: '思维导图'),
                          Tab(text: 'AI 问书'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _SummaryTab(book: book, bundle: bundle),
                          _MindMapTab(book: book, bundle: bundle),
                          _AskBookTab(
                            book: book,
                            bundle: bundle,
                            controller: _questionController,
                            messages: _messages,
                            onSend: (question) =>
                                _handleQuestion(book, bundle, question),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    Center(child: Text('生成 AI 内容失败: $error')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载书籍失败: $error')),
          ),
        ),
      ),
    );
  }

  void _handleQuestion(Book book, BookAiBundle bundle, String question) {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return;
    final answer = ref.read(bookAiServiceProvider).answerQuestion(
          book: book,
          bundle: bundle,
          question: trimmed,
        );
    setState(() {
      _messages.add(_ChatMessage(role: _ChatRole.user, text: trimmed));
      _messages.add(_ChatMessage(role: _ChatRole.assistant, text: answer));
    });
    _questionController.clear();
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 20, 0),
      child: Row(
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
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.book,
    required this.bundle,
  });

  final Book book;
  final BookAiBundle bundle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        LiquidGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '三句话总结',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < bundle.summaryPoints.length; i++) ...[
                _NumberedPoint(index: i + 1, text: bundle.summaryPoints[i]),
                if (i != bundle.summaryPoints.length - 1)
                  const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        LiquidGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '推荐切入点',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                bundle.readingAdvice,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: bundle.sections
                    .take(3)
                    .map(
                      (section) => TagChip(
                        label:
                            '${section.title} · ${section.estimatedMinutes} 分钟',
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LiquidGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '可直接拿来做划线的句子',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              for (final quote in bundle.quoteCandidates.take(4)) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9EE),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    quote,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberedPoint extends StatelessWidget {
  const _NumberedPoint({
    required this.index,
    required this.text,
  });

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF5D7CFF),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                ),
          ),
        ),
      ],
    );
  }
}

class _MindMapTab extends StatelessWidget {
  const _MindMapTab({
    required this.book,
    required this.bundle,
  });

  final Book book;
  final BookAiBundle bundle;

  @override
  Widget build(BuildContext context) {
    final branches = bundle.mindMapBranches;
    final positions = _branchPositions(branches.length);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        LiquidGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI 思维导图',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '把章节和核心句压成一张结构图，适合先看全貌，再返回目录挑章节。',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 520,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final center = Offset(
                      constraints.maxWidth / 2,
                      constraints.maxHeight / 2,
                    );
                    final branchOffsets = positions
                        .map(
                          (point) => Offset(
                            constraints.maxWidth * point.dx,
                            constraints.maxHeight * point.dy,
                          ),
                        )
                        .toList();
                    return Stack(
                      children: [
                        CustomPaint(
                          size:
                              Size(constraints.maxWidth, constraints.maxHeight),
                          painter: _MindMapPainter(
                            center: center,
                            branchOffsets: branchOffsets,
                          ),
                        ),
                        Positioned(
                          left: center.dx - 62,
                          top: center.dy - 62,
                          child: _CenterBubble(title: book.title),
                        ),
                        for (var i = 0; i < branches.length; i++)
                          Positioned(
                            left: math.max(
                              8,
                              math.min(
                                constraints.maxWidth - 156,
                                branchOffsets[i].dx - 72,
                              ),
                            ),
                            top: math.max(
                              8,
                              math.min(
                                constraints.maxHeight - 160,
                                branchOffsets[i].dy - 48,
                              ),
                            ),
                            child: _BranchBubble(branch: branches[i]),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Offset> _branchPositions(int count) {
    if (count <= 1) return const [Offset(0.78, 0.26)];
    if (count == 2) return const [Offset(0.20, 0.28), Offset(0.80, 0.70)];
    if (count == 3) {
      return const [
        Offset(0.18, 0.28),
        Offset(0.82, 0.26),
        Offset(0.50, 0.78),
      ];
    }
    return const [
      Offset(0.18, 0.24),
      Offset(0.82, 0.24),
      Offset(0.18, 0.74),
      Offset(0.82, 0.74),
    ];
  }
}

class _CenterBubble extends StatelessWidget {
  const _CenterBubble({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 124,
      height: 124,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F4F6DFF),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
        border: Border.all(color: const Color(0xFFE1EAFF)),
      ),
      alignment: Alignment.center,
      child: Text(
        title,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _BranchBubble extends StatelessWidget {
  const _BranchBubble({required this.branch});

  final BookMindMapBranch branch;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 148),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDDE7FF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              branch.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            ...branch.leaves.map(
              (leaf) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• $leaf',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF56647D),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MindMapPainter extends CustomPainter {
  const _MindMapPainter({
    required this.center,
    required this.branchOffsets,
  });

  final Offset center;
  final List<Offset> branchOffsets;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFADC7FF)
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke;
    for (final offset in branchOffsets) {
      final control = Offset((center.dx + offset.dx) / 2, offset.dy);
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(control.dx, control.dy, offset.dx, offset.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MindMapPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.branchOffsets != branchOffsets;
  }
}

enum _ChatRole { user, assistant }

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.text,
  });

  final _ChatRole role;
  final String text;
}

class _AskBookTab extends StatelessWidget {
  const _AskBookTab({
    required this.book,
    required this.bundle,
    required this.controller,
    required this.messages,
    required this.onSend,
  });

  final Book book;
  final BookAiBundle bundle;
  final TextEditingController controller;
  final List<_ChatMessage> messages;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final effectiveMessages = messages.isEmpty
        ? [
            _ChatMessage(
              role: _ChatRole.assistant,
              text: '可以围绕《${book.title}》继续问我：它适合谁、重点是什么、应该从哪里开始。',
            ),
          ]
        : messages;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: bundle.askSuggestions
                  .map(
                    (question) => ActionChip(
                      label: Text(question),
                      onPressed: () => onSend(question),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              itemCount: effectiveMessages.length,
              itemBuilder: (context, index) {
                final message = effectiveMessages[index];
                final isUser = message.role == _ChatRole.user;
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF5D7CFF)
                          : Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      message.text,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color:
                                isUser ? Colors.white : const Color(0xFF24314D),
                          ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          LiquidGlassCard(
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: onSend,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: '继续问这本书……',
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: () => onSend(controller.text),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
