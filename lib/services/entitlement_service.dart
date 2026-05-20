import 'package:chibook/services/secure_settings_service.dart';

class EntitlementService {
  EntitlementService({
    SecureSettingsService? secureSettingsService,
  }) : _secureSettingsService =
            secureSettingsService ?? SecureSettingsService();

  final SecureSettingsService _secureSettingsService;

  static const proUnlockedKey = 'entitlement_pro_unlocked';

  Future<bool> isProUnlocked() async {
    return _secureSettingsService.readBool(proUnlockedKey);
  }

  Future<void> setProUnlocked(bool value) async {
    await _secureSettingsService.writeBool(proUnlockedKey, value);
  }
}
