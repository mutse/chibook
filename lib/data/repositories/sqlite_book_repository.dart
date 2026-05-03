import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/reading_progress.dart';
import 'package:chibook/data/repositories/book_repository.dart';
import 'package:chibook/services/database_service.dart';
import 'package:sqflite/sqflite.dart';

class SqliteBookRepository implements BookRepository {
  SqliteBookRepository(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<Book?> getBook(String id) async {
    final db = await _databaseService.database();
    final result = await db.rawQuery('''
      SELECT
        b.id,
        b.title,
        b.author,
        b.file_path,
        b.original_file_name,
        b.format,
        b.imported_at,
        b.cover_path,
        p.location,
        p.percentage,
        p.updated_at
      FROM books b
      LEFT JOIN reading_progress p ON p.book_id = b.id
      WHERE b.id = ?
      LIMIT 1
    ''', [id]);

    if (result.isEmpty) return null;
    return _mapBook(result.first);
  }

  @override
  Future<List<Book>> getBooks() async {
    final db = await _databaseService.database();
    final result = await db.rawQuery('''
      SELECT
        b.id,
        b.title,
        b.author,
        b.file_path,
        b.original_file_name,
        b.format,
        b.imported_at,
        b.cover_path,
        p.location,
        p.percentage,
        p.updated_at
      FROM books b
      LEFT JOIN reading_progress p ON p.book_id = b.id
      ORDER BY COALESCE(p.updated_at, b.imported_at) DESC
    ''');

    return result.map(_mapBook).toList();
  }

  @override
  Future<void> saveBook(Book book) async {
    final db = await _databaseService.database();
    await db.insert(
      'books',
      {
        'id': book.id,
        'title': book.title,
        'author': book.author,
        'file_path': book.filePath,
        'original_file_name': book.originalFileName,
        'format': book.format.name,
        'imported_at': book.importedAt.toIso8601String(),
        'cover_path': book.coverPath,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteBook(String id) async {
    final db = await _databaseService.database();
    await db.transaction((txn) async {
      await txn.delete(
        'reading_progress',
        where: 'book_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'books',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  @override
  Future<void> updateProgress(ReadingProgress progress) async {
    final db = await _databaseService.database();
    await db.insert(
      'reading_progress',
      {
        'book_id': progress.bookId,
        'location': progress.location,
        'percentage': progress.percentage,
        'updated_at': progress.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Book _mapBook(Map<String, Object?> row) {
    final formatValue = row['format'] as String? ?? 'epub';
    return Book(
      id: row['id'] as String,
      title: row['title'] as String,
      author: row['author'] as String,
      filePath: row['file_path'] as String,
      originalFileName: row['original_file_name'] as String,
      format: BookFormat.values.byName(formatValue),
      importedAt: DateTime.parse(row['imported_at'] as String),
      coverPath: row['cover_path'] as String?,
      lastReadAt: row['updated_at'] == null
          ? null
          : DateTime.parse(row['updated_at'] as String),
      progress: (row['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}
