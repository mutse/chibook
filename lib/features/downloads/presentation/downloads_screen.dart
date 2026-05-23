import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/audio_cache_entry.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookshelfControllerProvider);
    final cacheAsync = ref.watch(audioCacheEntriesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: booksAsync.when(
            data: (books) => cacheAsync.when(
              data: (entries) => _DownloadsBody(
                books: books,
                entries: entries,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  Center(child: Text('加载缓存失败: $error')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载书籍失败: $error')),
          ),
        ),
      ),
    );
  }
}

class _DownloadsBody extends ConsumerWidget {
  const _DownloadsBody({
    required this.books,
    required this.entries,
  });

  final List<Book> books;
  final List<AudioCacheEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookMap = {for (final book in books) book.id: book};
    final totalBytes = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.fileSizeBytes,
    );

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
            Expanded(
              child: Text(
                '下载管理',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (entries.isNotEmpty)
              TextButton(
                onPressed: () => _clearAll(context, ref, entries),
                child: const Text('清空缓存'),
              ),
          ],
        ),
        const SizedBox(height: 18),
        LiquidGlassCard(
          radius: 32,
          colors: const [
            Color(0xFFEAF2FF),
            Color(0xD9FFFFFF),
            Color(0xFFDDEAFF),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '离线音频缓存',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                entries.isEmpty
                    ? '当前还没有生成可离线播放的章节或页面音频。升级到 Pro 并启用云端朗读后，缓存会显示在这里。'
                    : '这里展示已经落盘的章节/页面音频缓存，删除后会在下次播放时重新生成。',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _StorageStat(
                      label: '缓存文件',
                      value: '${entries.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StorageStat(
                      label: '占用空间',
                      value: _formatBytes(totalBytes),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (entries.isEmpty)
          LiquidGlassCard(
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 46,
                  color: Color(0xFF5D7CFF),
                ),
                const SizedBox(height: 14),
                Text(
                  '还没有离线缓存',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  '免费版可以直接本地朗读，Pro 用户启用云端朗读并缓存后，这里会出现真实的离线文件。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                ),
              ],
            ),
          )
        else ...[
          SectionHeader(
            title: '缓存列表',
            actionLabel: '${entries.length} 项',
          ),
          const SizedBox(height: 8),
          ...entries.map((entry) {
            final book = bookMap[entry.bookId];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LiquidGlassCard(
                child: Row(
                  children: [
                    if (book != null)
                      BookCoverArt(
                        book: book,
                        width: 62,
                        height: 86,
                        radius: 18,
                        showMeta: false,
                      )
                    else
                      Container(
                        width: 62,
                        height: 86,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: const Color(0xFFE1E8FF),
                        ),
                        child: const Icon(Icons.audio_file_rounded),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book?.title ?? '未知书籍',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.segmentLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${entry.providerName} · ${entry.formattedSizeLabel}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF667394),
                                    ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            recencyLabel(entry.createdAt),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF667394),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '删除缓存',
                      onPressed: () => _deleteEntry(context, ref, entry),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                    if (book != null)
                      IconButton(
                        tooltip: '打开书籍',
                        onPressed: () => context.push('/book/${book.id}'),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    AudioCacheEntry entry,
  ) async {
    await ref.read(speechCacheServiceProvider).deleteEntry(entry);
    ref.invalidate(audioCacheEntriesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除缓存文件')),
    );
  }

  Future<void> _clearAll(
    BuildContext context,
    WidgetRef ref,
    List<AudioCacheEntry> entries,
  ) async {
    for (final entry in entries) {
      await ref.read(speechCacheServiceProvider).deleteEntry(entry);
    }
    ref.invalidate(audioCacheEntriesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清空缓存')),
    );
  }
}

class _StorageStat extends StatelessWidget {
  const _StorageStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

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
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}
