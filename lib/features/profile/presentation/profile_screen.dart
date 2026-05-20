import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_insights.dart';
import 'package:chibook/features/pro/application/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookshelfControllerProvider);
    final proAsync = ref.watch(proUnlockedProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: booksAsync.when(
            data: (books) {
              final insights = buildReadingInsights(books);
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
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
                              ),
                              child: const Icon(
                                Icons.auto_stories_rounded,
                                size: 34,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Chibook',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Your private reading and listening workspace',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () => context.push('/pro'),
                              child: proAsync.valueOrNull == true
                                  ? const Text('Pro')
                                  : const Text('Upgrade'),
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
                                  width: 50,
                                  height: 70,
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
                                        '最近打开',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: const Color(0xFF5D7CFF),
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
                                  onPressed: () => context.push('/book/${recentBook.id}'),
                                  icon: const Icon(Icons.chevron_right_rounded),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: '书籍',
                          value: '${insights.totalBooks}',
                          unit: '本',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: '在读',
                          value: '${insights.readingBooks}',
                          unit: '本',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: '完成率',
                          value: '${insights.completionRate}',
                          unit: '%',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LiquidGlassCard(
                    child: Column(
                      children: [
                        _ActionTile(
                          icon: Icons.workspace_premium_outlined,
                          title: 'Chibook Pro',
                          subtitle: '解锁云端朗读、离线缓存和更多高级能力',
                          onTap: () => context.push('/pro'),
                        ),
                        const Divider(height: 1),
                        _ActionTile(
                          icon: Icons.download_rounded,
                          title: '下载管理',
                          subtitle: '管理真实的章节 / 页面音频缓存',
                          onTap: () => context.push('/downloads'),
                        ),
                        const Divider(height: 1),
                        _ActionTile(
                          icon: Icons.history_rounded,
                          title: '阅读历史',
                          subtitle: '回看最近打开的书和阅读进度',
                          onTap: () => context.push('/history'),
                        ),
                        const Divider(height: 1),
                        _ActionTile(
                          icon: Icons.settings_outlined,
                          title: '朗读与偏好设置',
                          subtitle: '调整本地 TTS、云端音色和阅读体验',
                          onTap: () => context.push('/settings'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  LiquidGlassCard(
                    child: Text(
                      '首发版本专注本地 EPUB / PDF 阅读、听书、笔记和离线缓存，不包含账号、云同步、书城或社交能力。',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.6),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载个人页失败: $error')),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF5D7CFF)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
