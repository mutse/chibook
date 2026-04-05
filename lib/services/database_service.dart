import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  Database? _database;

  Future<Database> database() async {
    final existing = _database;
    if (existing != null) return existing;

    final documentsDir = await getApplicationDocumentsDirectory();
    final databasePath = path.join(documentsDir.path, 'chibook.db');

    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE books(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            author TEXT NOT NULL,
            file_path TEXT NOT NULL,
            original_file_name TEXT NOT NULL,
            format TEXT NOT NULL,
            imported_at TEXT NOT NULL,
            cover_path TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE reading_progress(
            book_id TEXT PRIMARY KEY,
            location TEXT NOT NULL,
            percentage REAL NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }
}
