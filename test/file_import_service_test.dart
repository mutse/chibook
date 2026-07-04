import 'dart:io';

import 'package:chibook/data/models/book.dart';
import 'package:chibook/data/repositories/in_memory_book_repository.dart';
import 'package:chibook/services/epub_service.dart';
import 'package:chibook/services/file_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory documentsDir;
  late Directory sourceDir;
  late FilePicker? originalFilePicker;
  late bool hadOriginalFilePicker;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp('chibook-documents-');
    sourceDir = await Directory.systemTemp.createTemp('chibook-source-');

    try {
      originalFilePicker = FilePicker.platform;
      hadOriginalFilePicker = true;
    } catch (_) {
      originalFilePicker = null;
      hadOriginalFilePicker = false;
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return documentsDir.path;
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (hadOriginalFilePicker && originalFilePicker != null) {
      FilePicker.platform = originalFilePicker!;
    }
    if (await documentsDir.exists()) {
      await documentsDir.delete(recursive: true);
    }
    if (await sourceDir.exists()) {
      await sourceDir.delete(recursive: true);
    }
  });

  test(
    'imports EPUB when cached picker path extension differs from picked file name',
    () async {
      const sourceBytes = <int>[1, 2, 3, 4];
      final sourceFile =
          File(path.join(sourceDir.path, 'zlibrary-download.sk'));
      await sourceFile.writeAsBytes(sourceBytes, flush: true);

      final fakePicker = _FakeFilePicker();
      fakePicker.result = FilePickerResult([
        PlatformFile(
          path: sourceFile.path,
          name: 'Deep Work.epub',
          size: sourceBytes.length,
        ),
      ]);
      FilePicker.platform = fakePicker;

      final service = FileImportService(
        bookRepository: InMemoryBookRepository(),
        epubService: const _FakeEpubService(),
      );

      final book = await service.pickAndImportBook();

      expect(book, isNotNull);
      expect(book!.format, BookFormat.epub);
      expect(book.originalFileName, 'Deep Work.epub');
      expect(path.extension(book.filePath), '.epub');
      expect(book.title, 'Imported EPUB');
      expect(book.author, 'Test Author');
      expect(await File(book.filePath).exists(), isTrue);
      expect(fakePicker.clearTemporaryFilesCalled, isTrue);
    },
  );

  test(
    'imports EPUB from picker cache files that only expose an .sk extension',
    () async {
      const sourceBytes = <int>[0x50, 0x4B, 0x03, 0x04, 1, 2, 3, 4];
      final sourceFile =
          File(path.join(sourceDir.path, 'wechat-cache-file.sk'));
      await sourceFile.writeAsBytes(sourceBytes, flush: true);

      final fakePicker = _FakeFilePicker();
      fakePicker.result = FilePickerResult([
        PlatformFile(
          path: sourceFile.path,
          name: 'wechat-cache-file.sk',
          size: sourceBytes.length,
        ),
      ]);
      FilePicker.platform = fakePicker;

      final service = FileImportService(
        bookRepository: InMemoryBookRepository(),
        epubService: const _FakeEpubService(),
      );

      final book = await service.pickAndImportBook();

      expect(book, isNotNull);
      expect(book!.format, BookFormat.epub);
      expect(path.extension(book.filePath), '.epub');
      expect(book.originalFileName, 'wechat-cache-file.sk');
      expect(book.title, 'Imported EPUB');
    },
  );

  test(
    'imports PDF from picker cache files that only expose an .sk extension',
    () async {
      const sourceBytes = <int>[0x25, 0x50, 0x44, 0x46, 1, 2, 3, 4];
      final sourceFile = File(path.join(sourceDir.path, 'wechat-pdf-cache.sk'));
      await sourceFile.writeAsBytes(sourceBytes, flush: true);

      final fakePicker = _FakeFilePicker();
      fakePicker.result = FilePickerResult([
        PlatformFile(
          path: sourceFile.path,
          name: 'wechat-pdf-cache.sk',
          size: sourceBytes.length,
        ),
      ]);
      FilePicker.platform = fakePicker;

      final service = FileImportService(
        bookRepository: InMemoryBookRepository(),
        epubService: const _FakeEpubService(),
      );

      final book = await service.pickAndImportBook();

      expect(book, isNotNull);
      expect(book!.format, BookFormat.pdf);
      expect(path.extension(book.filePath), '.pdf');
      expect(book.originalFileName, 'wechat-pdf-cache.sk');
    },
  );
}

class _FakeEpubService extends EpubService {
  const _FakeEpubService();

  @override
  Future<EpubImportMetadata> loadImportMetadata(String filePath) async {
    return const EpubImportMetadata(
      title: 'Imported EPUB',
      author: 'Test Author',
      chapterCount: 12,
      totalLocations: 3456,
      languageCode: 'en',
    );
  }
}

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker();

  FilePickerResult? result;
  bool clearTemporaryFilesCalled = false;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return result;
  }

  @override
  Future<bool?> clearTemporaryFiles() async {
    clearTemporaryFilesCalled = true;
    return true;
  }
}
