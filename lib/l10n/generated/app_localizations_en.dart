// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Chibook';

  @override
  String get welcomeBrand => 'Chibook';

  @override
  String get welcomeSubtitle => 'Immersive reading for your own library';

  @override
  String get welcomeFeatureLine => 'Import · Read · Listen · Keep Notes';

  @override
  String get welcomeBody =>
      'Import EPUB / PDF into your private library, read with fewer distractions, and switch to natural listening when your eyes need a break.';

  @override
  String get welcomeFormatsTitle => 'EPUB / PDF import';

  @override
  String get welcomeFormatsBody =>
      'Bring your own books into a private local library.';

  @override
  String get welcomeOfflineTitle => 'Offline local narration';

  @override
  String get welcomeOfflineBody =>
      'Free local TTS works even when you\'re offline.';

  @override
  String get welcomeProTitle => 'Pro cloud voices';

  @override
  String get welcomeProBody =>
      'Upgrade later for Azure Speech, OpenAI, ElevenLabs, and chapter caching.';

  @override
  String get welcomePrimaryCta => 'Start Reading';

  @override
  String get welcomeSecondaryCta => 'Go To Library';

  @override
  String get proTitle => 'Chibook Pro';

  @override
  String get proHeadline =>
      'Upgrade Chibook into a complete reading and listening workspace';

  @override
  String get proBody =>
      'The free tier keeps import, bookshelf, EPUB/PDF reading, local TTS, and basic notes. Pro unlocks cloud narration, chapter caching, richer voices, and advanced reading controls.';

  @override
  String get proStatusUnlocked => 'Pro is already unlocked on this device.';

  @override
  String get proStatusLocked => 'Pro is available to unlock.';

  @override
  String get proStatusNotConfigured =>
      'Store purchasing is not configured yet. This screen shows the production entry point and entitlement structure.';

  @override
  String get proIncludesTitle => 'Included with Pro';

  @override
  String get proKeepsTitle => 'Always free';

  @override
  String get proFeatureCloudTts =>
      'Cloud TTS with more natural listening voices';

  @override
  String get proFeatureCaching =>
      'Chapter and page audio caching with download management';

  @override
  String get proFeatureControls =>
      'More voice, speed, and reading customization';

  @override
  String get proFeatureUpgrades =>
      'Priority access to future commercial upgrades';

  @override
  String get freeFeatureImport => 'EPUB / PDF import';

  @override
  String get freeFeatureShelf => 'Bookshelf and reading progress';

  @override
  String get freeFeatureLocalTts => 'Local TTS narration';

  @override
  String get freeFeatureNotes => 'Basic highlights and notes';

  @override
  String get proUnlockCta => 'Unlock Pro';

  @override
  String get proRestoreCta => 'Restore Purchases';

  @override
  String get purchasePurchased => 'Pro unlocked.';

  @override
  String get purchaseRestored => 'Purchases restored.';

  @override
  String get purchaseAlreadyUnlocked => 'Pro is already active.';

  @override
  String get purchaseNotConfigured => 'Store purchase is not configured.';

  @override
  String get purchaseCancelled => 'Purchase cancelled.';

  @override
  String get purchaseFailed =>
      'Purchase did not complete. Please try again later.';
}
