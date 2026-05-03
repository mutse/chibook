import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/book.dart';

enum BookshelfSortMode { recent, title, progress }

List<Book> filterBooksByQuery(Iterable<Book> books, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return books.toList();
  }

  return books.where((book) => matchesBookQuery(book, normalized)).toList();
}

bool matchesBookQuery(Book book, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }

  final candidates = [
    book.title,
    book.author,
    book.originalFileName,
    book.formatLabel,
    pseudoCategoryForBook(book),
    progressLabel(book),
  ];

  return candidates.any((value) => value.toLowerCase().contains(normalized));
}

List<Book> sortBooksForShelf(
  Iterable<Book> books,
  BookshelfSortMode sortMode,
) {
  final items = books.toList();
  switch (sortMode) {
    case BookshelfSortMode.recent:
      return sortBooksByRecent(items);
    case BookshelfSortMode.title:
      items.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      return items;
    case BookshelfSortMode.progress:
      items.sort((a, b) {
        final progressOrder = b.progress.compareTo(a.progress);
        if (progressOrder != 0) {
          return progressOrder;
        }

        final aTime = a.lastReadAt ?? a.importedAt;
        final bTime = b.lastReadAt ?? b.importedAt;
        return bTime.compareTo(aTime);
      });
      return items;
  }
}

int estimateBookMinutes(Book book) {
  final units =
      book.totalLocations > 0 ? book.totalLocations : book.title.length * 18;
  return (units / 28).round().clamp(12, 180);
}

int estimateConsumedMinutes(Book book) {
  final progress = book.progress.clamp(0.0, 1.0);
  return (estimateBookMinutes(book) * progress).round();
}

class ReadingInsights {
  const ReadingInsights({
    required this.totalBooks,
    required this.readingBooks,
    required this.finishedBooks,
    required this.importedThisWeek,
    required this.listenedMinutes,
    required this.streakDays,
    required this.completionRate,
    required this.averageProgress,
    required this.favoriteCategory,
  });

  final int totalBooks;
  final int readingBooks;
  final int finishedBooks;
  final int importedThisWeek;
  final int listenedMinutes;
  final int streakDays;
  final int completionRate;
  final double averageProgress;
  final String favoriteCategory;
}

ReadingInsights buildReadingInsights(
  Iterable<Book> books, {
  DateTime? now,
}) {
  final items = books.toList();
  final reference = now ?? DateTime.now();
  final totalBooks = items.length;
  final readingBooks =
      items.where((book) => book.progress > 0 && book.progress < 1).length;
  final finishedBooks = items.where((book) => book.progress >= 1).length;
  final importedThisWeek = items.where((book) {
    return reference.difference(book.importedAt).inDays < 7;
  }).length;
  final listenedMinutes = items.fold<int>(
    0,
    (sum, book) => sum + estimateConsumedMinutes(book),
  );
  final completionRate = totalBooks == 0
      ? 0
      : ((finishedBooks / totalBooks) * 100).round().clamp(0, 100);
  final averageProgress = totalBooks == 0
      ? 0.0
      : items.fold<double>(
            0,
            (sum, book) => sum + book.progress.clamp(0.0, 1.0).toDouble(),
          ) /
          totalBooks;

  final categoryWeights = <String, double>{};
  for (final book in items) {
    final category = pseudoCategoryForBook(book);
    final weight = 1 + book.progress.clamp(0.0, 1.0) * 2;
    categoryWeights.update(category, (value) => value + weight,
        ifAbsent: () => weight);
  }

  String favoriteCategory = '还在形成';
  if (categoryWeights.isNotEmpty) {
    favoriteCategory = categoryWeights.entries
        .reduce((best, current) => current.value > best.value ? current : best)
        .key;
  }

  return ReadingInsights(
    totalBooks: totalBooks,
    readingBooks: readingBooks,
    finishedBooks: finishedBooks,
    importedThisWeek: importedThisWeek,
    listenedMinutes: listenedMinutes,
    streakDays: calculateReadingStreak(items, now: reference),
    completionRate: completionRate,
    averageProgress: averageProgress,
    favoriteCategory: favoriteCategory,
  );
}

int calculateReadingStreak(
  Iterable<Book> books, {
  DateTime? now,
}) {
  final reference = _startOfDay(now ?? DateTime.now());
  final activityDays = books
      .map((book) => _startOfDay(book.lastReadAt ?? book.importedAt))
      .toSet();

  var cursor = reference;
  var streak = 0;
  while (activityDays.contains(cursor)) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

DateTime _startOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
