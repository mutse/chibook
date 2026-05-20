import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Chibook'**
  String get appTitle;

  /// No description provided for @welcomeBrand.
  ///
  /// In en, this message translates to:
  /// **'Chibook'**
  String get welcomeBrand;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Immersive reading for your own library'**
  String get welcomeSubtitle;

  /// No description provided for @welcomeFeatureLine.
  ///
  /// In en, this message translates to:
  /// **'Import · Read · Listen · Keep Notes'**
  String get welcomeFeatureLine;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Import EPUB / PDF into your private library, read with fewer distractions, and switch to natural listening when your eyes need a break.'**
  String get welcomeBody;

  /// No description provided for @welcomeFormatsTitle.
  ///
  /// In en, this message translates to:
  /// **'EPUB / PDF import'**
  String get welcomeFormatsTitle;

  /// No description provided for @welcomeFormatsBody.
  ///
  /// In en, this message translates to:
  /// **'Bring your own books into a private local library.'**
  String get welcomeFormatsBody;

  /// No description provided for @welcomeOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline local narration'**
  String get welcomeOfflineTitle;

  /// No description provided for @welcomeOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Free local TTS works even when you\'re offline.'**
  String get welcomeOfflineBody;

  /// No description provided for @welcomeProTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro cloud voices'**
  String get welcomeProTitle;

  /// No description provided for @welcomeProBody.
  ///
  /// In en, this message translates to:
  /// **'Upgrade later for Azure Speech, OpenAI, ElevenLabs, and chapter caching.'**
  String get welcomeProBody;

  /// No description provided for @welcomePrimaryCta.
  ///
  /// In en, this message translates to:
  /// **'Start Reading'**
  String get welcomePrimaryCta;

  /// No description provided for @welcomeSecondaryCta.
  ///
  /// In en, this message translates to:
  /// **'Go To Library'**
  String get welcomeSecondaryCta;

  /// No description provided for @proTitle.
  ///
  /// In en, this message translates to:
  /// **'Chibook Pro'**
  String get proTitle;

  /// No description provided for @proHeadline.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Chibook into a complete reading and listening workspace'**
  String get proHeadline;

  /// No description provided for @proBody.
  ///
  /// In en, this message translates to:
  /// **'The free tier keeps import, bookshelf, EPUB/PDF reading, local TTS, and basic notes. Pro unlocks cloud narration, chapter caching, richer voices, and advanced reading controls.'**
  String get proBody;

  /// No description provided for @proStatusUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Pro is already unlocked on this device.'**
  String get proStatusUnlocked;

  /// No description provided for @proStatusLocked.
  ///
  /// In en, this message translates to:
  /// **'Pro is available to unlock.'**
  String get proStatusLocked;

  /// No description provided for @proStatusNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Store purchasing is not configured yet. This screen shows the production entry point and entitlement structure.'**
  String get proStatusNotConfigured;

  /// No description provided for @proIncludesTitle.
  ///
  /// In en, this message translates to:
  /// **'Included with Pro'**
  String get proIncludesTitle;

  /// No description provided for @proKeepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Always free'**
  String get proKeepsTitle;

  /// No description provided for @proFeatureCloudTts.
  ///
  /// In en, this message translates to:
  /// **'Cloud TTS with more natural listening voices'**
  String get proFeatureCloudTts;

  /// No description provided for @proFeatureCaching.
  ///
  /// In en, this message translates to:
  /// **'Chapter and page audio caching with download management'**
  String get proFeatureCaching;

  /// No description provided for @proFeatureControls.
  ///
  /// In en, this message translates to:
  /// **'More voice, speed, and reading customization'**
  String get proFeatureControls;

  /// No description provided for @proFeatureUpgrades.
  ///
  /// In en, this message translates to:
  /// **'Priority access to future commercial upgrades'**
  String get proFeatureUpgrades;

  /// No description provided for @freeFeatureImport.
  ///
  /// In en, this message translates to:
  /// **'EPUB / PDF import'**
  String get freeFeatureImport;

  /// No description provided for @freeFeatureShelf.
  ///
  /// In en, this message translates to:
  /// **'Bookshelf and reading progress'**
  String get freeFeatureShelf;

  /// No description provided for @freeFeatureLocalTts.
  ///
  /// In en, this message translates to:
  /// **'Local TTS narration'**
  String get freeFeatureLocalTts;

  /// No description provided for @freeFeatureNotes.
  ///
  /// In en, this message translates to:
  /// **'Basic highlights and notes'**
  String get freeFeatureNotes;

  /// No description provided for @proUnlockCta.
  ///
  /// In en, this message translates to:
  /// **'Unlock Pro'**
  String get proUnlockCta;

  /// No description provided for @proRestoreCta.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get proRestoreCta;

  /// No description provided for @purchasePurchased.
  ///
  /// In en, this message translates to:
  /// **'Pro unlocked.'**
  String get purchasePurchased;

  /// No description provided for @purchaseRestored.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored.'**
  String get purchaseRestored;

  /// No description provided for @purchaseAlreadyUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Pro is already active.'**
  String get purchaseAlreadyUnlocked;

  /// No description provided for @purchaseNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Store purchase is not configured.'**
  String get purchaseNotConfigured;

  /// No description provided for @purchaseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Purchase cancelled.'**
  String get purchaseCancelled;

  /// No description provided for @purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase did not complete. Please try again later.'**
  String get purchaseFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
