import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/bookshelf/presentation/widgets/bookshelf_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BookshelfScreen extends ConsumerWidget {
  const BookshelfScreen({
    super.key,
    this.showAppBar = true,
  });

  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookshelfControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: showAppBar ? AppBar(title: const Text('书架')) : null,
      body: LiquidBackground(
        child: SafeArea(
          top: !showAppBar,
          child: booksAsync.when(
            data: (books) => BookshelfContent(
              books: books,
              onImport: () => _importBook(context, ref),
              onRemoveBook: (book) => _removeBook(context, ref, book),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('加载书架失败: $error')),
          ),
        ),
      ),
    );
  }

  Future<void> _importBook(BuildContext context, WidgetRef ref) async {
    try {
      final book =
          await ref.read(bookshelfControllerProvider.notifier).importBook();
      if (book != null && context.mounted) {
        context.push('/book/${book.id}');
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败，请重试: $error')),
      );
    }
  }

  Future<void> _removeBook(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从书架移除'),
        content: Text('确认移除《${book.title}》吗？当前阅读进度也会一起清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(bookshelfControllerProvider.notifier).removeBook(book.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已从书架移除《${book.title}》')),
    );
  }
}
