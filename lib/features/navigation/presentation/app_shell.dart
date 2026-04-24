import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const destinations = [
      _ShellDestination(
        label: '首页',
        icon: Icons.home_rounded,
      ),
      _ShellDestination(
        label: '书架',
        icon: Icons.menu_book_rounded,
      ),
      _ShellDestination(
        label: '播放',
        icon: Icons.play_arrow_rounded,
        emphasized: true,
      ),
      _ShellDestination(
        label: '发现',
        icon: Icons.explore_rounded,
      ),
      _ShellDestination(
        label: '我的',
        icon: Icons.person_rounded,
      ),
    ];
    final books =
        ref.watch(bookshelfControllerProvider).valueOrNull ?? const [];
    final recentBooks = sortBooksByRecent(books);
    final activeBookId = ref.watch(readerActiveAutoBookIdProvider);
    final currentBook = activeBookId == null
        ? recentBooks.cast<Book?>().firstOrNull
        : recentBooks.cast<Book?>().firstWhere(
              (book) => book?.id == activeBookId,
              orElse: () => recentBooks.cast<Book?>().firstOrNull,
            );
    final speechState = ref.watch(readerSpeechStateProvider);
    final autoSpeech = currentBook == null
        ? null
        : ref.watch(readerAutoSpeechProvider(currentBook.id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentBook != null && navigationShell.currentIndex != 2) ...[
              _MiniPlayerBar(
                book: currentBook,
                label: autoSpeech?.label ?? estimatedListenLabel(currentBook),
                speechState: speechState,
              ),
              const SizedBox(height: 12),
            ],
            LiquidGlassCard(
              radius: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  for (var index = 0; index < destinations.length; index++)
                    Expanded(
                      child: _NavItem(
                        destination: destinations[index],
                        selected: navigationShell.currentIndex == index,
                        onTap: () {
                          navigationShell.goBranch(
                            index,
                            initialLocation:
                                index == navigationShell.currentIndex,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPlayerBar extends ConsumerWidget {
  const _MiniPlayerBar({
    required this.book,
    required this.label,
    required this.speechState,
  });

  final Book book;
  final String label;
  final ReaderSpeechState speechState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(readerControllerProvider);
    final isPlaying = speechState == ReaderSpeechState.playing;

    return LiquidGlassCard(
      radius: 28,
      onTap: () => context.go('/player'),
      colors: const [
        Color(0xD8FFFFFF),
        Color(0x8CEAF2FF),
      ],
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: bookPalette(book),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D7CFF).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '正在播放',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF5D7CFF),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlayingPulse(active: isPlaying),
              const SizedBox(height: 6),
              const WaveformLine(
                color: Color(0xFF5D7CFF),
                barCount: 10,
                barWidth: 2.4,
                minHeight: 4,
                maxHeight: 12,
                spacing: 2,
              ),
            ],
          ),
          const SizedBox(width: 10),
          GestureDetector(
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
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF84C9FF), Color(0xFF5D7CFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayingPulse extends StatelessWidget {
  const _PlayingPulse({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        final height = active ? (10 + index * 4).toDouble() : 8.0;
        return Padding(
          padding: EdgeInsets.only(right: index == 2 ? 0 : 3),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 220 + index * 60),
            width: 4,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: active ? const Color(0xFF5D7CFF) : const Color(0xFFB3C0E5),
            ),
          ),
        );
      }),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? Colors.white : const Color(0xFF7280A7);
    final labelColor =
        selected ? const Color(0xFF4D63D6) : const Color(0xFF7280A7);

    if (destination.emphasized) {
      return InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF5E7EFF), Color(0xFF7EC2FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x285E7EFF),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(destination.icon, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              destination.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(destination.icon, color: iconColor),
            const SizedBox(height: 6),
            Text(
              destination.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final bool emphasized;
}

extension<T> on List<T?> {
  T? get firstOrNull => isEmpty ? null : first;
}
