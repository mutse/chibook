import 'dart:io';
import 'dart:typed_data';

import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/repositories/book_repository.dart';
import 'package:chibook/services/epub_service.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

class FileImportService {
  FileImportService({
    required BookRepository bookRepository,
    this.epubService = const EpubService(),
  }) : _bookRepository = bookRepository;

  final BookRepository _bookRepository;
  final EpubService epubService;

  Future<Book?> pickAndImportBook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['epub', 'pdf'],
      );

      final picked = result?.files.single;
      final sourcePath = picked?.path;
      if (picked == null || sourcePath == null) return null;

      final sourceFile = File(sourcePath);
      final sourceBytes = await sourceFile.readAsBytes();
      final fileHash = sha256.convert(sourceBytes).toString();
      final existing = await _bookRepository.getBookByHash(fileHash);
      if (existing != null) {
        await _restoreMissingBookFileIfNeeded(
          existing: existing,
          sourceFile: sourceFile,
        );
        return existing;
      }

      final extension = _resolveSupportedExtension(
        pickedName: picked.name,
        sourcePath: sourcePath,
        sourceBytes: sourceBytes,
      );
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
      final targetPath = path.join(booksDir.path, '$bookId$extension');
      await sourceFile.copy(targetPath);

      final rawName = path.basenameWithoutExtension(picked.name).trim();
      var title = rawName.isEmpty ? 'Untitled Book' : rawName;
      var author = 'Unknown Author';
      var totalLocations = 0;
      var pageCount = 0;
      var chapterCount = 0;
      String? languageCode;
      String? coverImagePath;

      if (format == BookFormat.epub) {
        final metadata = await epubService.loadImportMetadata(targetPath);
        if (metadata.title.trim().isNotEmpty) {
          title = metadata.title.trim();
        }
        if (metadata.author.trim().isNotEmpty) {
          author = metadata.author.trim();
        }
        totalLocations = metadata.totalLocations;
        chapterCount = metadata.chapterCount;
        languageCode = metadata.languageCode ?? _detectLanguageCode(title);
        coverImagePath = await _saveCoverImage(
          bookId: bookId,
          bytes: metadata.coverBytes,
        );
      } else {
        final metadata = await _loadPdfMetadata(targetPath);
        if (metadata.title.trim().isNotEmpty) {
          title = metadata.title.trim();
        }
        if (metadata.author.trim().isNotEmpty) {
          author = metadata.author.trim();
        }
        totalLocations = metadata.totalLocations;
        pageCount = metadata.pageCount;
        languageCode = metadata.languageCode ?? _detectLanguageCode(title);
      }

      return Book(
        id: bookId,
        title: title,
        author: author,
        filePath: targetPath,
        originalFileName: picked.name,
        format: format,
        importedAt: DateTime.now(),
        fileHash: fileHash,
        fileSizeBytes: sourceBytes.length,
        coverImagePath: coverImagePath,
        totalLocations: totalLocations,
        pageCount: pageCount,
        chapterCount: chapterCount,
        languageCode: languageCode,
      );
    } finally {
      await _clearTemporaryFilesSafely();
    }
  }

  Future<void> _restoreMissingBookFileIfNeeded({
    required Book existing,
    required File sourceFile,
  }) async {
    final targetFile = File(existing.filePath);
    if (await targetFile.exists()) return;
    await targetFile.parent.create(recursive: true);
    await sourceFile.copy(targetFile.path);
  }

  Future<String?> _saveCoverImage({
    required String bookId,
    required Uint8List? bytes,
  }) async {
    if (bytes == null || bytes.isEmpty) return null;
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(path.join(appDir.path, 'covers'));
    if (!coversDir.existsSync()) {
      await coversDir.create(recursive: true);
    }
    final file = File(path.join(coversDir.path, '$bookId.png'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _clearTemporaryFilesSafely() async {
    try {
      await FilePicker.platform.clearTemporaryFiles();
    } catch (_) {
      // Only supported on mobile platforms. Import should still succeed
      // when cache cleanup is unavailable.
    }
  }

  String _resolveSupportedExtension({
    required String pickedName,
    required String sourcePath,
    required List<int> sourceBytes,
  }) {
    final nameExtension = path.extension(pickedName).toLowerCase();
    if (nameExtension == '.epub' || nameExtension == '.pdf') {
      return nameExtension;
    }

    final sourceExtension = path.extension(sourcePath).toLowerCase();
    if (sourceExtension == '.epub' || sourceExtension == '.pdf') {
      return sourceExtension;
    }

    final contentExtension = _detectSupportedExtensionFromBytes(sourceBytes);
    if (contentExtension != null) {
      return contentExtension;
    }

    return nameExtension.isNotEmpty ? nameExtension : sourceExtension;
  }

  String? _detectSupportedExtensionFromBytes(List<int> bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return '.pdf';
    }

    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07) &&
        (bytes[3] == 0x04 || bytes[3] == 0x06 || bytes[3] == 0x08)) {
      return '.epub';
    }

    return null;
  }

  Future<_PdfImportMetadata> _loadPdfMetadata(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      try {
        final info = document.documentInformation;
        final extractedTitle = info.title.replaceAll('\u0000', '').trim();
        final extractedAuthor = info.author.replaceAll('\u0000', '').trim();
        final pageCount = document.pages.count;
        final firstPageText = pageCount > 0
            ? PdfTextExtractor(document).extractText(
                startPageIndex: 0,
                endPageIndex: 0,
              )
            : '';
        final totalLocations = firstPageText.trim().isEmpty
            ? pageCount
            : pageCount * firstPageText.runes.length;
        return _PdfImportMetadata(
          title: extractedTitle,
          author: extractedAuthor,
          pageCount: pageCount,
          totalLocations: totalLocations,
          languageCode: _detectLanguageCode('$extractedTitle $firstPageText'),
        );
      } finally {
        document.dispose();
      }
    } catch (_) {
      return const _PdfImportMetadata(
        title: '',
        author: '',
        pageCount: 0,
        totalLocations: 0,
      );
    }
  }

  String? _detectLanguageCode(String input) {
    final sample = input.trim();
    if (sample.isEmpty) return null;
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(sample)) {
      return 'zh';
    }
    if (RegExp(r'[A-Za-z]').hasMatch(sample)) {
      return 'en';
    }
    return null;
  }
}

class _PdfImportMetadata {
  const _PdfImportMetadata({
    required this.title,
    required this.author,
    required this.pageCount,
    required this.totalLocations,
    this.languageCode,
  });

  final String title;
  final String author;
  final int pageCount;
  final int totalLocations;
  final String? languageCode;
}
