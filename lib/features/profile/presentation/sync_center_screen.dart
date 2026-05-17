import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SyncCenterScreen extends ConsumerWidget {
  const SyncCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookshelfControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: booksAsync.when(
            data: (books) => _SyncBody(books: books),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载同步中心失败: $error')),
          ),
        ),
      ),
    );
  }
}

class _SyncBody extends ConsumerWidget {
  const _SyncBody({required this.books});

  final List<Book> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentBooks = sortBooksByRecent(books);
    final latestTime = recentBooks.isEmpty
        ? null
        : (recentBooks.first.lastReadAt ?? recentBooks.first.importedAt);
    final activeBooks = recentBooks.where((book) => book.progress > 0).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
            const SizedBox(width: 8),
            Text(
              '云端同步',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 18),
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
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5C7CFF), Color(0xFF8FD7FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.cloud_done_rounded,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '跨端同步中心',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          latestTime == null
                              ? '当前还没有可同步内容'
                              : '最近活动 ${recencyLabel(latestTime)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '当前项目里已经把同步中心入口和状态页补齐，但真实账户体系与远端存储还没有接入。现在这里更像是跨设备能力的预留面板。',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _SyncStat(
                      label: '书籍',
                      value: '${recentBooks.length}',
                      unit: '本',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SyncStat(
                      label: '在读',
                      value: '$activeBooks',
                      unit: '本',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SyncStat(
                      label: '状态',
                      value: recentBooks.isEmpty ? '待启用' : '已准备',
                      unit: '',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionHeader(title: '支持设备'),
        const SizedBox(height: 8),
        const Row(
          children: [
            Expanded(
                child: _DeviceCard(
                    icon: Icons.phone_iphone_rounded, label: 'iOS')),
            SizedBox(width: 12),
            Expanded(
                child:
                    _DeviceCard(icon: Icons.android_rounded, label: 'Android')),
            SizedBox(width: 12),
            Expanded(
                child: _DeviceCard(icon: Icons.language_rounded, label: 'Web')),
          ],
        ),
        const SizedBox(height: 18),
        LiquidGlassCard(
          child: Column(
            children: [
              _SyncActionTile(
                icon: Icons.download_rounded,
                title: '下载管理',
                subtitle: '查看离线缓存和占用空间',
                onTap: () => context.push('/downloads'),
              ),
              const Divider(height: 1),
              _SyncActionTile(
                icon: Icons.history_rounded,
                title: '阅读历史',
                subtitle: '回看最近打开的书和进度轨迹',
                onTap: () => context.push('/history'),
              ),
              const Divider(height: 1),
              _SyncActionTile(
                icon: Icons.file_upload_outlined,
                title: '继续导入',
                subtitle: '补齐本地 EPUB / PDF 内容源',
                onTap: () async {
                  try {
                    final book = await ref
                        .read(bookshelfControllerProvider.notifier)
                        .importBook();
                    if (book != null && context.mounted) {
                      context.push('/book/${book.id}');
                    }
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('导入失败，请重试: $error')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SyncStat extends StatelessWidget {
  const _SyncStat({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              children: [
                TextSpan(text: value),
                if (unit.isNotEmpty)
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

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF5D7CFF)),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _SyncActionTile extends StatelessWidget {
  const _SyncActionTile({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.24),
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
