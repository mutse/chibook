import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_insights.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/settings/application/speech_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookshelfControllerProvider);
    final settings = ref.watch(speechSettingsControllerProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: booksAsync.when(
            data: (books) {
              final insights = buildReadingInsights(books);
              final listenedHours = insights.listenedMinutes == 0
                  ? '0.0'
                  : insights.listenedMinutes >= 60
                      ? (insights.listenedMinutes / 60).toStringAsFixed(1)
                      : '0.${(insights.listenedMinutes / 6).round().clamp(1, 9)}';
              final recentBooks = sortBooksByRecent(books);
              final recentBook = recentBooks.isEmpty ? null : recentBooks.first;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  LiquidGlassCard(
                    radius: 32,
                    colors: const [
                      Color(0xFFEFF5FF),
                      Color(0xD9FFFFFF),
                      Color(0xFFE1ECFF),
                    ],
                    child: Stack(
                      children: [
                        Positioned(
                          right: -46,
                          top: -46,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF78B7FF)
                                  .withValues(alpha: 0.16),
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF80CBFF),
                                        Color(0xFF6C7FFF),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x336C7FFF),
                                        blurRadius: 24,
                                        offset: Offset(0, 14),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    size: 38,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '阅读爱好者',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ),
                                          const _VipBadge(),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '当前音色: ${settings?.voice.isNotEmpty == true ? settings!.voice : '系统默认'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xFF647196),
                                            ),
                                      ),
                                      const SizedBox(height: 14),
                                      WaveformLine(
                                        color: const Color(0xFF5D7CFF)
                                            .withValues(alpha: 0.58),
                                        barCount: 28,
                                        maxHeight: 22,
                                        minHeight: 5,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (recentBook != null) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.48),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Row(
                                  children: [
                                    BookCoverArt(
                                      book: recentBook,
                                      width: 48,
                                      height: 66,
                                      radius: 14,
                                      showMeta: false,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '最近在听',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color:
                                                      const Color(0xFF5D7CFF),
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            recentBook.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            progressLabel(recentBook),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton.filled(
                                      onPressed: () => context.go('/player'),
                                      icon:
                                          const Icon(Icons.play_arrow_rounded),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricCard(
                                    icon: Icons.graphic_eq_rounded,
                                    label: '累计听书',
                                    value: listenedHours,
                                    unit: '小时',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _MetricCard(
                                    icon: Icons.headphones_rounded,
                                    label: '连续活跃',
                                    value: '${insights.streakDays}',
                                    unit: '天',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _MetricCard(
                                    icon: Icons.verified_rounded,
                                    label: '本周新增',
                                    value: '${insights.importedThisWeek}',
                                    unit: '本',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  LiquidGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '阅读报告',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '根据书架和阅读进度自动生成你的当前画像。',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF647196),
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                icon: Icons.headphones_rounded,
                                label: '在听书籍',
                                value: '${insights.readingBooks}',
                                unit: '本',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                icon: Icons.verified_rounded,
                                label: '已听完',
                                value: '${insights.finishedBooks}',
                                unit: '本',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                icon: Icons.percent_rounded,
                                label: '完成率',
                                value: '${insights.completionRate}',
                                unit: '%',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                icon: Icons.category_rounded,
                                label: '偏爱类别',
                                value: insights.favoriteCategory,
                                unit: '',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          recentBook == null
                              ? '先导入一本到两本书，阅读报告就会逐渐形成你的偏好画像。'
                              : '最近最活跃的是《${recentBook.title}》，继续保持会让推荐更贴近你的阅读习惯。',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  LiquidGlassCard(
                    child: Column(
                      children: [
                        _ProfileTile(
                          icon: Icons.auto_awesome_rounded,
                          title: 'AI 朗读设置',
                          subtitle: '调整音色、语速和试听参数',
                          onTap: () => context.push('/settings'),
                        ),
                        const Divider(height: 1),
                        _ProfileTile(
                          icon: Icons.menu_book_rounded,
                          title: '管理书架',
                          subtitle: '查看在读、完成和最近导入的全部书籍',
                          onTap: () => context.go('/bookshelf'),
                        ),
                        const Divider(height: 1),
                        _ProfileTile(
                          icon: Icons.explore_rounded,
                          title: '发现推荐',
                          subtitle: '按分类和偏好继续找下一本想读的书',
                          onTap: () => context.go('/discover'),
                        ),
                        const Divider(height: 1),
                        _ProfileTile(
                          icon: Icons.download_rounded,
                          title: '下载管理',
                          subtitle: '查看离线缓存与占用空间',
                          onTap: () => context.push('/downloads'),
                        ),
                        const Divider(height: 1),
                        _ProfileTile(
                          icon: Icons.play_circle_outline_rounded,
                          title: '继续播放',
                          subtitle: '回到播放器继续当前会话',
                          onTap: () => context.go('/player'),
                        ),
                        const Divider(height: 1),
                        _ProfileTile(
                          icon: Icons.settings_outlined,
                          title: '帮助与反馈',
                          subtitle: '先放到设置页统一承接',
                          onTap: () => context.push('/settings'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载我的页面失败: $error')),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF5D7CFF)),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: unit,
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

class _VipBadge extends StatelessWidget {
  const _VipBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF5D7CFF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
        ),
      ),
      child: Text(
        'VIP 体验',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF5D7CFF),
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF5D7CFF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: const Color(0xFF5D7CFF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF647196),
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF7080A8)),
            ],
          ),
        ),
      ),
    );
  }
}
