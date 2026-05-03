import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_insights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('filterBooksByQuery', () {
    test('matches title, author, format and category keywords', () {
      final books = [
        _book(
          id: '1',
          title: '深度工作',
          author: 'Cal Newport',
          format: BookFormat.epub,
        ),
        _book(
          id: '2',
          title: '人类简史',
          author: 'Yuval Noah Harari',
          format: BookFormat.pdf,
        ),
      ];

      expect(filterBooksByQuery(books, '深度').map((book) => book.id), ['1']);
      expect(filterBooksByQuery(books, 'yuval').map((book) => book.id), ['2']);
      expect(filterBooksByQuery(books, 'pdf').map((book) => book.id), ['2']);
    });
  });

  group('buildReadingInsights', () {
    test('aggregates progress, streak and weekly imports', () {
      final now = DateTime(2026, 5, 3, 9);
      final books = [
        _book(
          id: '1',
          title: '高效能人士的七个习惯',
          author: 'Stephen Covey',
          progress: 1,
          importedAt: now.subtract(const Duration(days: 2)),
          lastReadAt: now,
        ),
        _book(
          id: '2',
          title: '刻意练习',
          author: 'Anders Ericsson',
          progress: 0.5,
          importedAt: now.subtract(const Duration(days: 1)),
          lastReadAt: now.subtract(const Duration(days: 1)),
        ),
        _book(
          id: '3',
          title: '原则',
          author: 'Ray Dalio',
          progress: 0,
          importedAt: now.subtract(const Duration(days: 10)),
        ),
      ];

      final insights = buildReadingInsights(books, now: now);

      expect(insights.totalBooks, 3);
      expect(insights.readingBooks, 1);
      expect(insights.finishedBooks, 1);
      expect(insights.importedThisWeek, 2);
      expect(insights.completionRate, 33);
      expect(insights.averageProgress, closeTo(0.5, 0.001));
      expect(insights.streakDays, 2);
    });
  });
}

Book _book({
  required String id,
  required String title,
  required String author,
  BookFormat format = BookFormat.epub,
  DateTime? importedAt,
  DateTime? lastReadAt,
  double progress = 0,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    filePath: '/tmp/$id',
    originalFileName: '$title.epub',
    format: format,
    importedAt: importedAt ?? DateTime(2026, 5, 1),
    lastReadAt: lastReadAt,
    progress: progress,
  );
}
