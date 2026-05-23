import 'package:chibook/data/models/audio_cache_entry.dart';
import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/models/book_annotation.dart';
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
    final result = await db.rawQuery(_bookSelectSql(
      whereClause: 'WHERE b.id = ?',
      limitClause: 'LIMIT 1',
    ), [id]);

    if (result.isEmpty) return null;
    return _mapBook(result.first);
  }

  @override
  Future<Book?> getBookByHash(String fileHash) async {
    final db = await _databaseService.database();
    final result = await db.rawQuery(_bookSelectSql(
      whereClause: 'WHERE b.file_hash = ?',
      limitClause: 'LIMIT 1',
    ), [fileHash]);
    if (result.isEmpty) return null;
    return _mapBook(result.first);
  }

  @override
  Future<List<Book>> getBooks() async {
    final db = await _databaseService.database();
    final result = await db.rawQuery(_bookSelectSql(
      orderClause: 'ORDER BY COALESCE(p.updated_at, b.imported_at) DESC',
    ));
    return result.map(_mapBook).toList(growable: false);
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
        'file_hash': book.fileHash,
        'file_size_bytes': book.fileSizeBytes,
        'cover_image_path': book.coverImagePath,
        'total_locations': book.totalLocations,
        'page_count': book.pageCount,
        'chapter_count': book.chapterCount,
        'language_code': book.languageCode,
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
        'annotations',
        where: 'book_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'audio_cache_entries',
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
        'selection_text': progress.selectionText,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<ReadingProgress?> getProgress(String bookId) async {
    final db = await _databaseService.database();
    final rows = await db.query(
      'reading_progress',
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapProgress(rows.first);
  }

  @override
  Future<List<BookAnnotation>> listAnnotations(String bookId) async {
    final db = await _databaseService.database();
    final rows = await db.query(
      'annotations',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_mapAnnotation).toList(growable: false);
  }

  @override
  Future<void> saveAnnotation(BookAnnotation annotation) async {
    final db = await _databaseService.database();
    await db.insert(
      'annotations',
      {
        'id': annotation.id,
        'book_id': annotation.bookId,
        'kind': annotation.kind.name,
        'quote': annotation.quote,
        'note': annotation.note,
        'location_label': annotation.locationLabel,
        'section_title': annotation.sectionTitle,
        'color_value': annotation.colorValue,
        'created_at': annotation.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteAnnotation(String annotationId) async {
    final db = await _databaseService.database();
    await db.delete(
      'annotations',
      where: 'id = ?',
      whereArgs: [annotationId],
    );
  }

  @override
  Future<List<AudioCacheEntry>> listAudioCacheEntries({String? bookId}) async {
    final db = await _databaseService.database();
    final rows = await db.query(
      'audio_cache_entries',
      where: bookId == null ? null : 'book_id = ?',
      whereArgs: bookId == null ? null : [bookId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_mapAudioCacheEntry).toList(growable: false);
  }

  @override
  Future<void> saveAudioCacheEntry(AudioCacheEntry entry) async {
    final db = await _databaseService.database();
    await db.insert(
      'audio_cache_entries',
      {
        'id': entry.id,
        'book_id': entry.bookId,
        'segment_id': entry.segmentId,
        'segment_label': entry.segmentLabel,
        'file_path': entry.filePath,
        'file_size_bytes': entry.fileSizeBytes,
        'provider_name': entry.providerName,
        'created_at': entry.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteAudioCacheEntry(String entryId) async {
    final db = await _databaseService.database();
    await db.delete(
      'audio_cache_entries',
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  String _bookSelectSql({
    String whereClause = '',
    String orderClause = '',
    String limitClause = '',
  }) {
    return '''
      SELECT
        b.id,
        b.title,
        b.author,
        b.file_path,
        b.original_file_name,
        b.format,
        b.imported_at,
        b.file_hash,
        b.file_size_bytes,
        b.cover_image_path AS cover_image_path,
        b.total_locations,
        b.page_count,
        b.chapter_count,
        b.language_code,
        p.location,
        p.percentage,
        p.updated_at
      FROM books b
      LEFT JOIN reading_progress p ON p.book_id = b.id
      $whereClause
      $orderClause
      $limitClause
    ''';
  }

  Book _mapBook(Map<String, Object?> row) {
    final formatValue = row['format'] as String? ?? BookFormat.epub.name;
    return Book(
      id: row['id'] as String,
      title: row['title'] as String,
      author: row['author'] as String,
      filePath: row['file_path'] as String,
      originalFileName: row['original_file_name'] as String,
      format: BookFormat.values.byName(formatValue),
      importedAt: DateTime.parse(row['imported_at'] as String),
      fileHash: row['file_hash'] as String? ?? '',
      fileSizeBytes: (row['file_size_bytes'] as num?)?.toInt() ?? 0,
      coverImagePath: row['cover_image_path'] as String?,
      lastReadAt: row['updated_at'] == null
          ? null
          : DateTime.parse(row['updated_at'] as String),
      lastReadLocation: row['location'] as String?,
      progress: (row['percentage'] as num?)?.toDouble() ?? 0,
      totalLocations: (row['total_locations'] as num?)?.toInt() ?? 0,
      pageCount: (row['page_count'] as num?)?.toInt() ?? 0,
      chapterCount: (row['chapter_count'] as num?)?.toInt() ?? 0,
      languageCode: row['language_code'] as String?,
    );
  }

  ReadingProgress _mapProgress(Map<String, Object?> row) {
    return ReadingProgress(
      bookId: row['book_id'] as String,
      location: row['location'] as String,
      percentage: (row['percentage'] as num).toDouble(),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      selectionText: row['selection_text'] as String?,
    );
  }

  BookAnnotation _mapAnnotation(Map<String, Object?> row) {
    return BookAnnotation(
      id: row['id'] as String,
      bookId: row['book_id'] as String,
      kind: BookAnnotationKind.values.byName(
        row['kind'] as String? ?? BookAnnotationKind.highlight.name,
      ),
      quote: row['quote'] as String,
      note: row['note'] as String? ?? '',
      locationLabel: row['location_label'] as String,
      sectionTitle: row['section_title'] as String?,
      colorValue: (row['color_value'] as num?)?.toInt() ?? 0xFFE8D39A,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  AudioCacheEntry _mapAudioCacheEntry(Map<String, Object?> row) {
    return AudioCacheEntry(
      id: row['id'] as String,
      bookId: row['book_id'] as String,
      segmentId: row['segment_id'] as String,
      segmentLabel: row['segment_label'] as String,
      filePath: row['file_path'] as String,
      fileSizeBytes: (row['file_size_bytes'] as num?)?.toInt() ?? 0,
      providerName: row['provider_name'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
