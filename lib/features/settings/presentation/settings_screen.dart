import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/data/models/speech_settings.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:chibook/features/settings/application/speech_settings_controller.dart';
import 'package:chibook/services/reader_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _endpointController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _voiceController;
  late final TextEditingController _sampleController;
  SpeechProviderMode _providerMode = SpeechProviderMode.auto;
  CloudTtsProvider _cloudProvider = CloudTtsProvider.openai;
  double _speed = 1.0;
  double _localSpeechRate = 0.45;
  String _selectedOpenAiVoice = ReaderSpeechService.openAiVoices.first;
  String _selectedEdgeVoice = ReaderSpeechService.edgePreviewVoices.first;
  String _localVoiceId = '';
  List<CloudVoiceOption> _edgeVoices = const [];
  bool _loadingEdgeVoices = false;
  String? _edgeVoicesError;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController();
    _voiceController = TextEditingController();
    _sampleController = TextEditingController(
      text: '这是 Chibook 的 AI 听书测试语音。',
    );
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _voiceController.dispose();
    _sampleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(speechSettingsControllerProvider);

    ref.listen<AsyncValue<SpeechSettings>>(speechSettingsControllerProvider, (
      previous,
      next,
    ) {
      next.whenData((settings) {
        if (_initialized && previous?.value == settings) return;
        _applySettings(settings);
      });
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('AI 朗读设置'),
            )
          : null,
      body: LiquidBackground(
        child: settingsAsync.when(
          data: (settings) {
            if (!_initialized) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _applySettings(settings);
              });
            }

            return SafeArea(
              top: !widget.showAppBar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  if (!widget.showAppBar)
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI 朗读设置',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  LiquidGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前配置',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_modeLabel(_providerMode)} · ${_cloudProviderLabel(_cloudProvider)} · ${_voiceController.text.trim().isEmpty ? '系统默认音色' : _voiceController.text.trim()}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.6),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStat(
                                label: '云端语速',
                                value: '${_speed.toStringAsFixed(1)}x',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MiniStat(
                                label: '本地语速',
                                value: _localSpeechRate.toStringAsFixed(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MiniStat(
                                label: '缓存状态',
                                value: _cloudProvider ==
                                        CloudTtsProvider.microsoftEdge
                                    ? '直连'
                                    : 'API',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: '音色选择',
                    subtitle: '先决定语音来源，再决定云端服务商。',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: SpeechProviderMode.values.map((mode) {
                            return ChoiceChip(
                              label: Text(_modeLabel(mode)),
                              selected: _providerMode == mode,
                              onSelected: (_) =>
                                  setState(() => _providerMode = mode),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _uiCloudProviders.map((provider) {
                            return ChoiceChip(
                              label: Text(_cloudProviderLabel(provider)),
                              selected: _cloudProvider == provider,
                              onSelected: (_) {
                                setState(() {
                                  _applyCloudProviderPreset(provider);
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _modeDescription(_providerMode),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: '朗读音色',
                    subtitle: '快速切换常用音色，也支持手动填写 voice 标识。',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children:
                              _quickVoiceOptions(_cloudProvider).map((voice) {
                            final selected =
                                voice == _voiceController.text.trim();
                            return ChoiceChip(
                              label: Text(voice),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  _voiceController.text = voice;
                                  if (_cloudProvider ==
                                      CloudTtsProvider.openai) {
                                    _selectedOpenAiVoice = voice;
                                  } else {
                                    _selectedEdgeVoice = voice;
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        if (_cloudProvider == CloudTtsProvider.openai)
                          DropdownButtonFormField<String>(
                            initialValue:
                                ReaderSpeechService.openAiVoices.contains(
                              _selectedOpenAiVoice,
                            )
                                    ? _selectedOpenAiVoice
                                    : ReaderSpeechService.openAiVoices.first,
                            decoration: const InputDecoration(
                              labelText: 'OpenAI 预设音色',
                            ),
                            items: ReaderSpeechService.openAiVoices
                                .map(
                                  (voice) => DropdownMenuItem<String>(
                                    value: voice,
                                    child: Text(voice),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedOpenAiVoice = value;
                                _voiceController.text = value;
                              });
                            },
                          ),
                        if (_cloudProvider ==
                            CloudTtsProvider.microsoftEdge) ...[
                          DropdownButtonFormField<String>(
                            initialValue: ReaderSpeechService.edgePreviewVoices
                                    .contains(
                              _selectedEdgeVoice,
                            )
                                ? _selectedEdgeVoice
                                : ReaderSpeechService.edgePreviewVoices.first,
                            decoration: const InputDecoration(
                              labelText: '常用 Edge 音色',
                            ),
                            items: ReaderSpeechService.edgePreviewVoices
                                .map(
                                  (voice) => DropdownMenuItem<String>(
                                    value: voice,
                                    child: Text(voice),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedEdgeVoice = value;
                                _voiceController.text = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _loadingEdgeVoices
                                      ? null
                                      : _loadEdgeVoices,
                                  icon: _loadingEdgeVoices
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(
                                          Icons.cloud_download_outlined),
                                  label: Text(
                                    _edgeVoices.isEmpty
                                        ? '加载更多 Edge 音色'
                                        : '刷新 Edge 音色',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_edgeVoicesError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _edgeVoicesError!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          ],
                          if (_edgeVoices.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _edgeVoices.any(
                                (voice) =>
                                    voice.id == _voiceController.text.trim(),
                              )
                                  ? _voiceController.text.trim()
                                  : null,
                              decoration: const InputDecoration(
                                labelText: '更多 Edge Voice',
                              ),
                              items: _edgeVoices
                                  .map(
                                    (voice) => DropdownMenuItem<String>(
                                      value: voice.id,
                                      child: Text(
                                        voice.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedEdgeVoice = value;
                                  _voiceController.text = value;
                                });
                              },
                            ),
                          ],
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: _voiceController,
                          decoration: InputDecoration(
                            labelText: _voiceLabel(_cloudProvider),
                            hintText: _voiceHint(_cloudProvider),
                            helperText: _voiceHelperText(_cloudProvider),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: '语速与参数',
                    subtitle: '图里的滑杆结构保留了下来，但底层还是接你现在这套 TTS 配置。',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '云端语速 ${_speed.toStringAsFixed(2)}x',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Slider(
                          value: _speed,
                          min: 0.5,
                          max: 1.5,
                          divisions: 10,
                          label: _speed.toStringAsFixed(2),
                          onChanged: (value) => setState(() => _speed = value),
                        ),
                        Text(
                          '本地 TTS 语速 ${_localSpeechRate.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Slider(
                          value: _localSpeechRate,
                          min: 0.2,
                          max: 0.8,
                          divisions: 12,
                          label: _localSpeechRate.toStringAsFixed(2),
                          onChanged: (value) =>
                              setState(() => _localSpeechRate = value),
                        ),
                        const SizedBox(height: 8),
                        Consumer(
                          builder: (context, ref, _) {
                            final localVoicesAsync =
                                ref.watch(localVoiceOptionsProvider);
                            return localVoicesAsync.when(
                              data: (voices) {
                                final hasCurrentSelection = _localVoiceId
                                        .isNotEmpty &&
                                    voices.any(
                                        (voice) => voice.id == _localVoiceId);
                                final effectiveValue = hasCurrentSelection
                                    ? _localVoiceId
                                    : (_localVoiceId.isEmpty ? '' : null);
                                return DropdownButtonFormField<String>(
                                  initialValue: effectiveValue,
                                  decoration: const InputDecoration(
                                    labelText: '设备 TTS 声音',
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: '',
                                      child: Text('系统默认'),
                                    ),
                                    ...voices.map(
                                      (voice) => DropdownMenuItem<String>(
                                        value: voice.id,
                                        child: Text(
                                          voice.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _localVoiceId = value ?? '';
                                    });
                                  },
                                );
                              },
                              loading: () => const LinearProgressIndicator(),
                              error: (error, stack) => Text('读取本地声音失败: $error'),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: '云端连接',
                    subtitle: '需要的时候再展开填写，日常更像一个轻量控制面板。',
                    child: Column(
                      children: [
                        if (_cloudProvider == CloudTtsProvider.openai)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: _apiKeyController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'API Key',
                                hintText: _apiKeyHint(_cloudProvider),
                                helperText: _apiKeyHelperText(_cloudProvider),
                              ),
                            ),
                          ),
                        TextField(
                          controller: _endpointController,
                          decoration: InputDecoration(
                            labelText: 'Endpoint',
                            hintText: _endpointHint(_cloudProvider),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _modelController,
                          decoration: InputDecoration(
                            labelText: _modelLabel(_cloudProvider),
                            hintText: _modelHint(_cloudProvider),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: '试听',
                    subtitle: '保存后直接播放测试文案，方便检查音色和参数是否符合预期。',
                    child: Column(
                      children: [
                        TextField(
                          controller: _sampleController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: '测试文案',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _previewAndSave,
                                child: const Text('保存并试听'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saveOnly,
                                child: const Text('仅保存'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('加载设置失败: $error')),
        ),
      ),
    );
  }

  Future<void> _previewAndSave() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final settings = _buildSettings();
      await ref.read(speechSettingsControllerProvider.notifier).save(settings);
      await ref.read(readerSpeechServiceProvider).speak(_sampleController.text);
    } catch (error) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('试听失败: $error')));
      return;
    }

    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('已保存并开始试听')));
  }

  Future<void> _saveOnly() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(speechSettingsControllerProvider.notifier)
          .save(_buildSettings());
    } catch (error) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('保存失败: $error')));
      return;
    }

    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('设置已保存')));
  }

  List<String> _quickVoiceOptions(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai =>
        ReaderSpeechService.openAiVoices.take(4).toList(),
      CloudTtsProvider.microsoftEdge =>
        ReaderSpeechService.edgePreviewVoices.take(4).toList(),
      CloudTtsProvider.elevenlabs => const [],
    };
  }

  void _applySettings(SpeechSettings settings) {
    final isHiddenProvider =
        settings.cloudProvider == CloudTtsProvider.elevenlabs;
    final effectiveProvider =
        isHiddenProvider ? CloudTtsProvider.openai : settings.cloudProvider;
    final effectiveVoice = settings.voice.isEmpty
        ? SpeechSettings.defaultVoiceFor(effectiveProvider)
        : settings.voice;

    _initialized = true;
    _providerMode = settings.providerMode;
    _cloudProvider = effectiveProvider;
    _endpointController.text = isHiddenProvider
        ? SpeechSettings.defaultEndpointFor(effectiveProvider)
        : SpeechSettings.normalizeEndpointFor(
            effectiveProvider,
            settings.endpoint,
          );
    _apiKeyController.text = isHiddenProvider ? '' : settings.apiKey;
    _modelController.text = isHiddenProvider
        ? SpeechSettings.defaultModelFor(effectiveProvider)
        : settings.model;
    _voiceController.text = isHiddenProvider ? effectiveVoice : settings.voice;
    _selectedOpenAiVoice =
        ReaderSpeechService.openAiVoices.contains(_voiceController.text)
            ? _voiceController.text
            : ReaderSpeechService.openAiVoices.first;
    _selectedEdgeVoice = _voiceController.text.trim().isEmpty
        ? SpeechSettings.defaultVoiceFor(CloudTtsProvider.microsoftEdge)
        : _voiceController.text.trim();
    _localVoiceId = settings.localVoiceId;
    _speed = settings.speed;
    _localSpeechRate = settings.localSpeechRate;
    setState(() {});
  }

  SpeechSettings _buildSettings() {
    final voice = _voiceController.text.trim();
    return SpeechSettings(
      providerMode: _providerMode,
      cloudProvider: _cloudProvider,
      endpoint: SpeechSettings.normalizeEndpointFor(
        _cloudProvider,
        _endpointController.text.trim(),
      ),
      apiKey: _cloudProvider == CloudTtsProvider.microsoftEdge
          ? ''
          : _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
      voice: _cloudProvider == CloudTtsProvider.openai
          ? (voice.isEmpty ? _selectedOpenAiVoice : voice)
          : _cloudProvider == CloudTtsProvider.microsoftEdge
              ? (voice.isEmpty ? _selectedEdgeVoice : voice)
              : voice,
      localVoiceId: _localVoiceId,
      speed: _speed,
      localSpeechRate: _localSpeechRate,
    );
  }

  String _modeLabel(SpeechProviderMode mode) {
    return switch (mode) {
      SpeechProviderMode.auto => '自动回退',
      SpeechProviderMode.cloud => '仅云端',
      SpeechProviderMode.local => '仅本地',
    };
  }

  List<CloudTtsProvider> get _uiCloudProviders => const [
        CloudTtsProvider.openai,
        CloudTtsProvider.microsoftEdge,
      ];

  String _modeDescription(SpeechProviderMode mode) {
    return switch (mode) {
      SpeechProviderMode.auto => '优先走云端 TTS，失败后再回退到设备自带语音。',
      SpeechProviderMode.cloud => '只用云端音色，适合需要稳定还原音色的场景。',
      SpeechProviderMode.local => '完全离线，不依赖任何外部服务。',
    };
  }

  String _cloudProviderLabel(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => 'OpenAI',
      CloudTtsProvider.microsoftEdge => 'Microsoft Edge',
      CloudTtsProvider.elevenlabs => 'ElevenLabs',
    };
  }

  String _endpointHint(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => 'https://api.openai.com/v1/audio/speech',
      CloudTtsProvider.microsoftEdge =>
        'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1',
      CloudTtsProvider.elevenlabs =>
        'https://api.elevenlabs.io/v1/text-to-speech',
    };
  }

  String _apiKeyHint(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => 'sk-...',
      CloudTtsProvider.microsoftEdge => '',
      CloudTtsProvider.elevenlabs => 'xi-api-key',
    };
  }

  String? _apiKeyHelperText(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => null,
      CloudTtsProvider.microsoftEdge => null,
      CloudTtsProvider.elevenlabs => '支持纯 key，也支持 xi-api-key 前缀。',
    };
  }

  String _modelLabel(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => 'Model',
      CloudTtsProvider.microsoftEdge => 'Output Format',
      CloudTtsProvider.elevenlabs => 'Model ID',
    };
  }

  String _modelHint(CloudTtsProvider provider) {
    return SpeechSettings.defaultModelFor(provider);
  }

  String _voiceLabel(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => '自定义 OpenAI Voice',
      CloudTtsProvider.microsoftEdge => 'Microsoft Edge Voice',
      CloudTtsProvider.elevenlabs => 'ElevenLabs Voice ID',
    };
  }

  String _voiceHint(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => '例如 alloy',
      CloudTtsProvider.microsoftEdge => '例如 zh-CN-XiaoxiaoNeural',
      CloudTtsProvider.elevenlabs => '例如 EXAVITQu4vr4xnSDxMaL',
    };
  }

  String? _voiceHelperText(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => '可填写任一 OpenAI voice 名称。',
      CloudTtsProvider.microsoftEdge => '建议填写完整 Edge voice 名称。',
      CloudTtsProvider.elevenlabs => '支持填写 Voice ID。',
    };
  }

  void _applyCloudProviderPreset(CloudTtsProvider nextProvider) {
    _cloudProvider = nextProvider;
    _endpointController.text = SpeechSettings.defaultEndpointFor(nextProvider);
    _modelController.text = SpeechSettings.defaultModelFor(nextProvider);
    _voiceController.text = SpeechSettings.defaultVoiceFor(nextProvider);
    if (nextProvider == CloudTtsProvider.microsoftEdge) {
      _apiKeyController.clear();
    }
    if (nextProvider == CloudTtsProvider.openai) {
      _selectedOpenAiVoice = ReaderSpeechService.openAiVoices.contains(
        _voiceController.text.trim(),
      )
          ? _voiceController.text.trim()
          : ReaderSpeechService.openAiVoices.first;
    }
    if (nextProvider == CloudTtsProvider.microsoftEdge) {
      _selectedEdgeVoice = _voiceController.text.trim().isEmpty
          ? SpeechSettings.defaultVoiceFor(CloudTtsProvider.microsoftEdge)
          : _voiceController.text.trim();
    }
  }

  Future<void> _loadEdgeVoices() async {
    setState(() {
      _loadingEdgeVoices = true;
      _edgeVoicesError = null;
    });

    try {
      final voices = await ref.read(readerSpeechServiceProvider).listEdgeVoices(
            endpoint: _endpointController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _edgeVoices = voices;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _edgeVoices = const [];
        _edgeVoicesError = '加载 Microsoft Edge voices 失败: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingEdgeVoices = false;
        });
      }
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
