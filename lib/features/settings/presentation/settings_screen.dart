import 'package:chibook/data/models/speech_settings.dart';
import 'package:chibook/features/reader/application/reader_controller.dart';
import 'package:chibook/features/settings/application/speech_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

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
  double _speed = 1.0;
  double _localSpeechRate = 0.45;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController();
    _voiceController = TextEditingController();
    _sampleController = TextEditingController(
      text: '这是 Chibook 的 OpenAI TTS 测试语音。',
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

    ref.listen<AsyncValue<SpeechSettings>>(
      speechSettingsControllerProvider,
      (previous, next) {
        next.whenData((settings) {
          if (_initialized && previous?.value == settings) return;
          _applySettings(settings);
        });
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('朗读设置')),
      body: settingsAsync.when(
        data: (settings) {
          if (!_initialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _applySettings(settings);
            });
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
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
                title: 'OpenAI TTS 配置',
                child: Column(
                  children: [
                    TextField(
                      controller: _endpointController,
                      decoration: const InputDecoration(
                        labelText: 'Endpoint',
                        hintText: 'https://api.openai.com/v1/audio/speech',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        hintText: 'sk-...',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        hintText: 'gpt-4o-mini-tts',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _voiceController,
                      decoration: const InputDecoration(
                        labelText: 'Voice',
                        hintText: 'alloy',
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
                              final scaffoldMessenger =
                                  ScaffoldMessenger.of(context);
                              try {
                                final settings = _buildSettings();
                                await ref
                                    .read(
                                      speechSettingsControllerProvider.notifier,
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
                              await ref.read(readerSpeechServiceProvider).stop();
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Failed to load settings: $error'),
        ),
      ),
    );
  }

  void _applySettings(SpeechSettings settings) {
    _initialized = true;
    _providerMode = settings.providerMode;
    _endpointController.text = settings.endpoint;
    _apiKeyController.text = settings.apiKey;
    _modelController.text = settings.model;
    _voiceController.text = settings.voice;
    _speed = settings.speed;
    _localSpeechRate = settings.localSpeechRate;
    setState(() {});
  }

  SpeechSettings _buildSettings() {
    return SpeechSettings(
      providerMode: _providerMode,
      endpoint: _endpointController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
      voice: _voiceController.text.trim(),
      speed: _speed,
      localSpeechRate: _localSpeechRate,
    );
  }

  String _modeLabel(SpeechProviderMode mode) {
    return switch (mode) {
      SpeechProviderMode.auto => '自动回退',
      SpeechProviderMode.openai => '仅 OpenAI',
      SpeechProviderMode.local => '仅本地 TTS',
    };
  }

  String _modeDescription(SpeechProviderMode mode) {
    return switch (mode) {
      SpeechProviderMode.auto => '优先请求 OpenAI，失败后回退到设备自带 TTS',
      SpeechProviderMode.openai => '只使用云端语音，便于验证音色与配置',
      SpeechProviderMode.local => '完全离线，适合未配置 API Key 的场景',
    };
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
