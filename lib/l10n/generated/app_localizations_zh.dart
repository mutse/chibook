// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Chibook';

  @override
  String get welcomeBrand => 'Chibook';

  @override
  String get welcomeSubtitle => '为你的私人书库打造的沉浸式阅读体验';

  @override
  String get welcomeFeatureLine => '导入 · 阅读 · 朗读 · 笔记';

  @override
  String get welcomeBody => '把 EPUB / PDF 导入你的私人书库，在更少打扰的界面里阅读，需要休息时随时切到自然朗读。';

  @override
  String get welcomeFormatsTitle => '支持 EPUB / PDF 导入';

  @override
  String get welcomeFormatsBody => '把你自己的电子书带进本地私人书库。';

  @override
  String get welcomeOfflineTitle => '离线本地朗读';

  @override
  String get welcomeOfflineBody => '免费版的本地 TTS 在无网络时也能使用。';

  @override
  String get welcomeProTitle => 'Pro 云端音色';

  @override
  String get welcomeProBody => '后续可升级启用 Azure Speech、OpenAI、ElevenLabs 和章节缓存。';

  @override
  String get welcomePrimaryCta => '开始阅读';

  @override
  String get welcomeSecondaryCta => '进入书库';

  @override
  String get proTitle => 'Chibook Pro';

  @override
  String get proHeadline => '把 Chibook 升级成完整的阅读与听书工作台';

  @override
  String get proBody =>
      '免费版保留导入、书架、EPUB/PDF 阅读、本地 TTS 和基础笔记。Pro 解锁云端朗读、章节缓存、更多音色与高级阅读控制。';

  @override
  String get proStatusUnlocked => '当前设备已解锁 Pro。';

  @override
  String get proStatusLocked => '当前尚未解锁 Pro。';

  @override
  String get proStatusNotConfigured => '商店购买尚未配置，当前展示的是正式产品入口和权益结构。';

  @override
  String get proIncludesTitle => 'Pro 包含';

  @override
  String get proKeepsTitle => '免费版保留';

  @override
  String get proFeatureCloudTts => '云端 TTS 与更自然的听书音色';

  @override
  String get proFeatureCaching => '章节 / 页面音频缓存和下载管理';

  @override
  String get proFeatureControls => '更多音色、语速与阅读自定义选项';

  @override
  String get proFeatureUpgrades => '后续商业版升级的优先承接';

  @override
  String get freeFeatureImport => 'EPUB / PDF 导入';

  @override
  String get freeFeatureShelf => '书架与阅读进度';

  @override
  String get freeFeatureLocalTts => '本地 TTS 朗读';

  @override
  String get freeFeatureNotes => '基础划线与笔记';

  @override
  String get proUnlockCta => '解锁 Pro';

  @override
  String get proRestoreCta => '恢复购买';

  @override
  String get purchasePurchased => 'Pro 已解锁';

  @override
  String get purchaseRestored => '已恢复购买记录';

  @override
  String get purchaseAlreadyUnlocked => '当前已经是 Pro';

  @override
  String get purchaseNotConfigured => '商店购买尚未配置';

  @override
  String get purchaseCancelled => '已取消购买';

  @override
  String get purchaseFailed => '购买暂未完成，请稍后重试';
}
