import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/bookshelf/presentation/widgets/book_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BookshelfScreen extends ConsumerWidget {
  const BookshelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bookshelfControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chibook'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.tune),
            tooltip: 'Speech settings',
          ),
          IconButton(
            onPressed: () async {
              final book =
                  await ref.read(bookshelfControllerProvider.notifier).importBook();
              if (book != null && context.mounted) {
                context.push('/reader/${book.id}');
              }
            },
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Import book',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: booksAsync.when(
          data: (books) {
            if (books.isEmpty) {
              return const _EmptyShelf();
            }

            return GridView.builder(
              itemCount: books.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.68,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                final book = books[index];
                return BookCard(
                  book: book,
                  onTap: () => context.push('/reader/${book.id}'),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Failed to load bookshelf: $error'),
          ),
        ),
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '你的书架还是空的',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  '导入 EPUB 或 PDF 后，就可以开始阅读、记录进度，并使用 AI 语音朗读。',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('点击右上角导入图书'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
