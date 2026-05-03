import 'dart:ui';

import 'package:chibook/data/models/book.dart';
import 'package:flutter/material.dart';

List<Book> sortBooksByRecent(Iterable<Book> books) {
  final sorted = books.toList()
    ..sort((a, b) {
      final aTime = a.lastReadAt ?? a.importedAt;
      final bTime = b.lastReadAt ?? b.importedAt;
      return bTime.compareTo(aTime);
    });
  return sorted;
}

List<Color> bookPalette(Book book) {
  const palettes = <List<Color>>[
    [Color(0xFF4F6DFF), Color(0xFF9ED8FF)],
    [Color(0xFF3764B4), Color(0xFF9CC7FF)],
    [Color(0xFF5B72FF), Color(0xFFBCAFFF)],
    [Color(0xFF2E8CBF), Color(0xFF88E0FF)],
    [Color(0xFF3B5FE1), Color(0xFF9FB9FF)],
    [Color(0xFF5A7CE2), Color(0xFFB9E4FF)],
  ];

  final seed = book.title.runes.fold<int>(0, (sum, rune) => sum + rune);
  return palettes[seed % palettes.length];
}

String progressLabel(Book book) {
  if (book.progress <= 0) return '未开始';
  return '已读 ${(book.progress.clamp(0, 1) * 100).round()}%';
}

String recencyLabel(DateTime? dateTime) {
  if (dateTime == null) return '刚刚导入';

  final delta = DateTime.now().difference(dateTime);
  if (delta.inDays >= 30) return '${(delta.inDays / 30).floor()} 个月前';
  if (delta.inDays >= 1) return '${delta.inDays} 天前';
  if (delta.inHours >= 1) return '${delta.inHours} 小时前';
  return '刚刚';
}

String estimatedListenLabel(Book book) {
  final units =
      book.totalLocations > 0 ? book.totalLocations : book.title.length * 18;
  final minutes = (units / 28).round().clamp(12, 180);
  return '$minutes 分钟可听完当前段落';
}

String pseudoCategoryForBook(Book book) {
  const categories = ['个人成长', '心理学', '管理', '历史', '经济', '小说'];
  final seed = book.title.runes.fold<int>(0, (sum, rune) => sum + rune);
  return categories[seed % categories.length];
}

class LiquidBackground extends StatelessWidget {
  const LiquidBackground({
    super.key,
    required this.child,
    this.dark = false,
  });

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final background = dark
        ? const [Color(0xFF0A2445), Color(0xFF143F75), Color(0xFF0F1D3A)]
        : const [Color(0xFFF4F7FF), Color(0xFFE8F0FF), Color(0xFFF8FBFF)];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: background,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            left: -40,
            child: _GlowOrb(
              size: 220,
              colors: dark
                  ? const [Color(0xFF60A7FF), Color(0x00377CFF)]
                  : const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
            ),
          ),
          Positioned(
            right: -70,
            top: 90,
            child: _GlowOrb(
              size: 260,
              colors: dark
                  ? const [Color(0x334CD6FF), Color(0x004CD6FF)]
                  : const [Color(0x99FFFFFF), Color(0x00FFFFFF)],
            ),
          ),
          Positioned(
            bottom: -80,
            left: 30,
            child: _GlowOrb(
              size: 240,
              colors: dark
                  ? const [Color(0x2257B8FF), Color(0x0057B8FF)]
                  : const [Color(0x66DDEBFF), Color(0x00DDEBFF)],
            ),
          ),
          Positioned(
            top: -10,
            left: 70,
            child: Transform.rotate(
              angle: -0.78,
              child: Container(
                width: 220,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dark
                        ? const [
                            Color(0x00FFFFFF),
                            Color(0x44FFFFFF),
                            Color(0x00FFFFFF),
                          ]
                        : const [
                            Color(0x00FFFFFF),
                            Color(0xCCFFFFFF),
                            Color(0x00FFFFFF),
                          ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -10,
            child: Transform.rotate(
              angle: -0.78,
              child: Container(
                width: 260,
                height: 1.6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dark
                        ? const [
                            Color(0x00FFFFFF),
                            Color(0x33A8D7FF),
                            Color(0x00FFFFFF),
                          ]
                        : const [
                            Color(0x00FFFFFF),
                            Color(0x99FFFFFF),
                            Color(0x00FFFFFF),
                          ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 28,
    this.onTap,
    this.alignment,
    this.colors,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final AlignmentGeometry? alignment;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors ??
                  [
                    Colors.white.withValues(alpha: 0.74),
                    Colors.white.withValues(alpha: 0.40),
                  ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.72),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140C1A3B),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 14,
                right: 14,
                top: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.78),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -20,
                right: -8,
                child: IgnorePointer(
                  child: Container(
                    width: 120,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(999),
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.26),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(radius),
                  child: Container(
                    alignment: alignment,
                    padding: padding,
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return content;
  }
}

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.trailing,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: Color(0xFF6F7EA8)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF7F8EB1),
                    ),
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF52617F),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class BookCoverArt extends StatelessWidget {
  const BookCoverArt({
    super.key,
    required this.book,
    this.height = 180,
    this.width = 130,
    this.radius = 26,
    this.showMeta = true,
  });

  final Book book;
  final double height;
  final double width;
  final double radius;
  final bool showMeta;

  @override
  Widget build(BuildContext context) {
    final palette = bookPalette(book);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x240F295A),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 14,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(radius),
                ),
              ),
            ),
          ),
          Positioned(
            right: -18,
            top: -18,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
          ),
          if (showMeta)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      book.formatLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    book.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const Spacer(),
        if (actionLabel != null)
          TextButton(
            onPressed: onTap,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.active = false,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: active
            ? const Color(0xFF5C7CFF)
            : Colors.white.withValues(alpha: 0.62),
        border: Border.all(
          color: active
              ? const Color(0xFF5C7CFF)
              : Colors.white.withValues(alpha: 0.8),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: active ? Colors.white : const Color(0xFF5D6B90),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class WaveformLine extends StatelessWidget {
  const WaveformLine({
    super.key,
    this.color = Colors.white,
    this.barCount = 24,
    this.barWidth = 3,
    this.minHeight = 6,
    this.maxHeight = 24,
    this.spacing = 3,
  });

  final Color color;
  final int barCount;
  final double barWidth;
  final double minHeight;
  final double maxHeight;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(barCount, (index) {
        final normalized = (index % 8) / 7;
        final height =
            lerpDouble(minHeight, maxHeight, normalized) ?? minHeight;
        return Container(
          width: barWidth,
          height: height,
          margin: EdgeInsets.only(right: index == barCount - 1 ? 0 : spacing),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                color.withValues(alpha: 0.30),
                color.withValues(alpha: 0.95),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }
}
