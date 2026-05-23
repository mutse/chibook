import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  Database? _database;
  static const _databaseVersion = 3;

  Future<Database> database() async {
    final existing = _database;
    if (existing != null) return existing;

    final documentsDir = await getApplicationDocumentsDirectory();
    final databasePath = path.join(documentsDir.path, 'chibook.db');

    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _migrateSchema(db, oldVersion, newVersion);
      },
    );

    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE books(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        file_path TEXT NOT NULL,
        original_file_name TEXT NOT NULL,
        format TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        file_hash TEXT NOT NULL DEFAULT '',
        file_size_bytes INTEGER NOT NULL DEFAULT 0,
        cover_image_path TEXT,
        total_locations INTEGER NOT NULL DEFAULT 0,
        page_count INTEGER NOT NULL DEFAULT 0,
        chapter_count INTEGER NOT NULL DEFAULT 0,
        language_code TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE reading_progress(
        book_id TEXT PRIMARY KEY,
        location TEXT NOT NULL,
        percentage REAL NOT NULL,
        updated_at TEXT NOT NULL,
        selection_text TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE annotations(
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        quote TEXT NOT NULL,
        note TEXT NOT NULL,
        location_label TEXT NOT NULL,
        section_title TEXT,
        color_value INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE audio_cache_entries(
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        segment_id TEXT NOT NULL,
        segment_label TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_size_bytes INTEGER NOT NULL,
        provider_name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _migrateSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE books ADD COLUMN file_hash TEXT NOT NULL DEFAULT ""',
      );
      await db.execute(
        'ALTER TABLE books ADD COLUMN file_size_bytes INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE books ADD COLUMN cover_image_path TEXT',
      );
      await db.execute(
        'ALTER TABLE books ADD COLUMN total_locations INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE books ADD COLUMN page_count INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE books ADD COLUMN chapter_count INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE books ADD COLUMN language_code TEXT',
      );
      await db.execute(
        'ALTER TABLE reading_progress ADD COLUMN selection_text TEXT',
      );
      await db.execute('''
        CREATE TABLE annotations(
          id TEXT PRIMARY KEY,
          book_id TEXT NOT NULL,
          kind TEXT NOT NULL,
          quote TEXT NOT NULL,
          note TEXT NOT NULL,
          location_label TEXT NOT NULL,
          section_title TEXT,
          color_value INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE audio_cache_entries(
          id TEXT PRIMARY KEY,
          book_id TEXT NOT NULL,
          segment_id TEXT NOT NULL,
          segment_label TEXT NOT NULL,
          file_path TEXT NOT NULL,
          file_size_bytes INTEGER NOT NULL,
          provider_name TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion == 1) {
      final columns = await db.rawQuery('PRAGMA table_info(books)');
      final hasLegacyCover = columns.any(
        (row) => row['name']?.toString() == 'cover_path',
      );
      if (hasLegacyCover) {
        await db.execute('''
          UPDATE books
          SET cover_image_path = cover_path
          WHERE cover_image_path IS NULL AND cover_path IS NOT NULL
        ''');
      }
    }

    if (newVersion > _databaseVersion) {
      throw StateError('Unsupported database version: $newVersion');
    }
  }
}
