import 'package:chibook/data/models/speech_settings.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:chibook/features/settings/application/speech_settings_controller.dart';
import 'package:chibook/services/reader_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      text: '这是 Chibook 的 AI TTS 测试语音。',
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
      appBar: widget.showAppBar ? AppBar(title: const Text('朗读设置')) : null,
      body: settingsAsync.when(
        data: (settings) {
          if (!_initialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _applySettings(settings);
            });
          }

          return SafeArea(
            top: !widget.showAppBar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                if (!widget.showAppBar) ...[
                  Text(
                    '设置',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '管理语音朗读、云端 TTS 和试听参数。',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF5D645F),
                        ),
                  ),
                  const SizedBox(height: 20),
                ],
                _SectionCard(
                  title: '语音提供方式',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<SpeechProviderMode>(
                        segments: SpeechProviderMode.values.map((mode) {
                          return ButtonSegment<SpeechProviderMode>(
                            value: mode,
                            label: Text(_modeLabel(mode)),
                          );
                        }).toList(),
                        selected: {_providerMode},
                        onSelectionChanged: (selection) {
                          setState(() => _providerMode = selection.first);
                        },
                      ),
                      const SizedBox(height: 16),
                      ...SpeechProviderMode.values.map((mode) {
                        final active = mode == _providerMode;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFFE7F2EE)
                                  : const Color(0xFFF7F4EE),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: active
                                    ? const Color(0xFF136B5C)
                                    : const Color(0xFFE5DED2),
                              ),
                            ),
                            child: Text(_modeDescription(mode)),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '云端 TTS 配置',
                  child: Column(
                    children: [
                      DropdownButtonFormField<CloudTtsProvider>(
                        initialValue: _cloudProvider,
                        decoration: const InputDecoration(
                          labelText: '云端提供商',
                        ),
                        items: _uiCloudProviders
                            .map(
                              (provider) => DropdownMenuItem<CloudTtsProvider>(
                                value: provider,
                                child: Text(_cloudProviderLabel(provider)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _applyCloudProviderPreset(value);
                          });
                        },
                      ),
                      if (_cloudProvider == CloudTtsProvider.microsoftEdge) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Microsoft Edge Read Aloud 当前无需 API Key。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                      if (_cloudProvider == CloudTtsProvider.openai) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _apiKeyController,
                          decoration: InputDecoration(
                            labelText: 'API Key',
                            hintText: _apiKeyHint(_cloudProvider),
                            helperText: _apiKeyHelperText(_cloudProvider),
                          ),
                          obscureText: true,
                        ),
                      ],
                      const SizedBox(height: 12),
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
                      if (_cloudProvider == CloudTtsProvider.openai) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue:
                              ReaderSpeechService.openAiVoices.contains(
                            _selectedOpenAiVoice,
                          )
                                  ? _selectedOpenAiVoice
                                  : null,
                          decoration: const InputDecoration(
                            labelText: 'OpenAI 声音',
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
                      ],
                      if (_cloudProvider == CloudTtsProvider.microsoftEdge) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue:
                              ReaderSpeechService.edgePreviewVoices.contains(
                            _selectedEdgeVoice,
                          )
                                  ? _selectedEdgeVoice
                                  : null,
                          decoration: const InputDecoration(
                            labelText: '常用 Microsoft Edge 声音',
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
                                onPressed:
                                    _loadingEdgeVoices ? null : _loadEdgeVoices,
                                icon: _loadingEdgeVoices
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.cloud_download_outlined),
                                label: Text(
                                  _edgeVoices.isEmpty
                                      ? '加载 Microsoft Edge Voices'
                                      : '刷新 Microsoft Edge Voices',
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_edgeVoicesError != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _edgeVoicesError!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
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
                              labelText: '选择 Microsoft Edge Voice',
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
                      const SizedBox(height: 16),
                      Text(
                        '云端语速 ${_speed.toStringAsFixed(2)}x',
                        style: Theme.of(context).textTheme.titleSmall,
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
                        style: Theme.of(context).textTheme.titleSmall,
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
                      const SizedBox(height: 6),
                      Text(
                        '本地声音',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, _) {
                          final localVoicesAsync = ref.watch(
                            localVoiceOptionsProvider,
                          );
                          return localVoicesAsync.when(
                            data: (voices) {
                              final hasCurrentSelection =
                                  _localVoiceId.isNotEmpty &&
                                      voices.any(
                                        (voice) => voice.id == _localVoiceId,
                                      );
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
                            error: (error, stack) => Text(
                              '读取本地声音失败: $error',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '试听',
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
                              onPressed: () async {
                                final scaffoldMessenger = ScaffoldMessenger.of(
                                  context,
                                );
                                try {
                                  final settings = _buildSettings();
                                  await ref
                                      .read(
                                        speechSettingsControllerProvider
                                            .notifier,
                                      )
                                      .save(settings);
                                  await ref
                                      .read(readerSpeechServiceProvider)
                                      .speak(_sampleController.text);
                                } catch (error) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(content: Text('试听失败: $error')),
                                  );
                                  return;
                                }
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(content: Text('已保存并开始试听')),
                                );
                              },
                              child: const Text('保存并试听'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await ref
                                    .read(readerSpeechServiceProvider)
                                    .stop();
                              },
                              child: const Text('停止'),
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
        error: (error, stack) =>
            Center(child: Text('Failed to load settings: $error')),
      ),
    );
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
        : settings.endpoint;
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
      endpoint: _endpointController.text.trim(),
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
      SpeechProviderMode.cloud => '仅云端 TTS',
      SpeechProviderMode.local => '仅本地 TTS',
    };
  }

  List<CloudTtsProvider> get _uiCloudProviders => const [
        CloudTtsProvider.openai,
        CloudTtsProvider.microsoftEdge,
      ];

  String _modeDescription(SpeechProviderMode mode) {
    return switch (mode) {
      SpeechProviderMode.auto => '优先请求当前云端 TTS，失败后回退到设备自带 TTS',
      SpeechProviderMode.cloud => '只使用当前云端语音，便于验证音色与配置',
      SpeechProviderMode.local => '完全离线，适合未配置云端服务的场景',
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
      CloudTtsProvider.microsoftEdge => 'Microsoft Edge 不需要 API Key。',
      CloudTtsProvider.elevenlabs => '支持直接粘贴纯 key，或带 xi-api-key: 前缀的整段内容。',
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
      CloudTtsProvider.openai => '自定义 OpenAI Voice（可选）',
      CloudTtsProvider.microsoftEdge => 'Microsoft Edge Voice',
      CloudTtsProvider.elevenlabs => 'ElevenLabs Voice ID',
    };
  }

  String _voiceHint(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => '例如: alloy',
      CloudTtsProvider.microsoftEdge => '例如: zh-CN-XiaoxiaoNeural',
      CloudTtsProvider.elevenlabs => '例如: EXAVITQu4vr4xnSDxMaL',
    };
  }

  String? _voiceHelperText(CloudTtsProvider provider) {
    return switch (provider) {
      CloudTtsProvider.openai => null,
      CloudTtsProvider.microsoftEdge =>
        '可填写完整 Voice 名称，例如 zh-CN-XiaoxiaoNeural。',
      CloudTtsProvider.elevenlabs =>
        '可填写 Voice ID，Endpoint 也支持使用 {voice_id} 占位符。',
    };
  }

  void _applyCloudProviderPreset(CloudTtsProvider nextProvider) {
    final previousProvider = _cloudProvider;
    _cloudProvider = nextProvider;

    if (_endpointController.text.trim().isEmpty ||
        _endpointController.text.trim() ==
            SpeechSettings.defaultEndpointFor(previousProvider)) {
      _endpointController.text =
          SpeechSettings.defaultEndpointFor(nextProvider);
    }
    if (_modelController.text.trim().isEmpty ||
        _modelController.text.trim() ==
            SpeechSettings.defaultModelFor(previousProvider)) {
      _modelController.text = SpeechSettings.defaultModelFor(nextProvider);
    }
    if (_voiceController.text.trim().isEmpty ||
        _voiceController.text.trim() ==
            SpeechSettings.defaultVoiceFor(previousProvider)) {
      _voiceController.text = SpeechSettings.defaultVoiceFor(nextProvider);
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
