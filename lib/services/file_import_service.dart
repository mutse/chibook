import 'dart:io';

import 'package:chibook/data/models/book.dart';
import 'package:chibook/services/epub_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class FileImportService {
  const FileImportService({
    this.epubService = const EpubService(),
  });

  final EpubService epubService;

  Future<Book?> pickAndImportBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['epub', 'pdf'],
    );

    final picked = result?.files.single;
    final sourcePath = picked?.path;
    if (picked == null || sourcePath == null) return null;

    final extension = path.extension(sourcePath).toLowerCase();
    final format = switch (extension) {
      '.epub' => BookFormat.epub,
      '.pdf' => BookFormat.pdf,
      _ => throw UnsupportedError('Unsupported book format: $extension'),
    };

    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(path.join(appDir.path, 'books'));
    if (!booksDir.existsSync()) {
      await booksDir.create(recursive: true);
    }

    final bookId = const Uuid().v4();
    final fileName = '$bookId$extension';
    final targetPath = path.join(booksDir.path, fileName);
    await File(sourcePath).copy(targetPath);

    final rawName = path.basenameWithoutExtension(picked.name);
    var title = rawName;
    var author = 'Unknown Author';

    if (format == BookFormat.epub) {
      final metadata = await epubService.loadMetadata(targetPath);
      if (metadata case (final metaTitle, final metaAuthor)) {
        if (metaTitle.trim().isNotEmpty) {
          title = metaTitle.trim();
        }
        if (metaAuthor.trim().isNotEmpty) {
          author = metaAuthor.trim();
        }
      }
    }

    return Book(
      id: bookId,
      title: title,
      author: author,
      filePath: targetPath,
      originalFileName: picked.name,
      format: format,
      importedAt: DateTime.now(),
    );
  }
}
