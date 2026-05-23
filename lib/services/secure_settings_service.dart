import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSettingsService {
  SecureSettingsService({
    FlutterSecureStorage? storage,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<bool> readBool(String key, {bool fallback = false}) async {
    final value = await read(key);
    if (value == null) return fallback;
    return value == 'true';
  }

  Future<void> writeBool(String key, bool value) => write(key, '$value');
}
