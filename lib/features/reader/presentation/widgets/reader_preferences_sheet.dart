import 'package:chibook/data/models/reader_preferences.dart';
import 'package:chibook/features/reader/application/reader_preferences_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderPreferencesSheet extends StatelessWidget {
  const ReaderPreferencesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ReaderPreferencesEditor(
      onApplied: () {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

class ReaderPreferencesEditor extends ConsumerStatefulWidget {
  const ReaderPreferencesEditor({
    super.key,
    this.onApplied,
    this.showTitle = true,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 28),
  });

  final VoidCallback? onApplied;
  final bool showTitle;
  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<ReaderPreferencesEditor> createState() =>
      _ReaderPreferencesEditorState();
}

class _ReaderPreferencesEditorState
    extends ConsumerState<ReaderPreferencesEditor> {
  ReaderThemeMode _themeMode = ReaderThemeMode.paper;
  ReaderFontPreset _fontPreset = ReaderFontPreset.sans;
  ReaderPageTurnMode _pageTurnMode = ReaderPageTurnMode.simulation;
  double _fontSize = 18;
  double _lineHeight = 1.85;
  double _brightness = 0.96;
  bool _initialized = false;

  static const _lineHeightOptions = [1.65, 1.85, 2.05];

  @override
  Widget build(BuildContext context) {
    final preferencesAsync = ref.watch(readerPreferencesControllerProvider);

    return SafeArea(
      child: preferencesAsync.when(
        data: (preferences) {
          if (!_initialized) {
            _applyPreferences(preferences);
          }

          final themeColors = _previewColors(_themeMode);
          return ListView(
            padding: widget.padding,
            shrinkWrap: true,
            children: [
              if (widget.showTitle) ...[
                Text(
                  '阅读设置',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '亮度、字体、主题和翻页方式都会即时保存。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
              ],
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: themeColors.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: themeColors.border),
                ),
                child: Stack(
                  children: [
                    if (_brightness < 0.99)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(
                                alpha: (1 - _brightness) * 0.58,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '阅读预览',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: themeColors.primaryText,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '第一章  人类: 一种也没什么特别的动物',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: themeColors.primaryText,
                                fontWeight: FontWeight.w800,
                                fontFamily: readerFontFamily(_fontPreset),
                                letterSpacing: readerLetterSpacing(_fontPreset),
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '大的五万年间，地球上至少有六种人。我们智人、尼安德特人、丹尼索瓦人，直立人、弗洛勒斯人，以及龙人。',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: themeColors.primaryText,
                                fontSize: _fontSize,
                                height: _lineHeight,
                                fontFamily: readerFontFamily(_fontPreset),
                                letterSpacing: readerLetterSpacing(_fontPreset),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionTitle(
                  title: '亮度', trailing: '${(_brightness * 100).round()}%'),
              Slider(
                value: _brightness,
                min: 0.45,
                max: 1.0,
                divisions: 11,
                onChanged: (value) => setState(() => _brightness = value),
              ),
              const SizedBox(height: 8),
              const _SectionTitle(title: '字体'),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StepperButton(
                    label: 'A-',
                    onTap: () => setState(() {
                      _fontSize = (_fontSize - 1).clamp(14, 28);
                    }),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _fontSize.toStringAsFixed(0),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                  ),
                  _StepperButton(
                    label: 'A+',
                    onTap: () => setState(() {
                      _fontSize = (_fontSize + 1).clamp(14, 28);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ReaderFontPreset>(
                initialValue: _fontPreset,
                decoration: const InputDecoration(labelText: '字体风格'),
                items: ReaderFontPreset.values
                    .map(
                      (preset) => DropdownMenuItem<ReaderFontPreset>(
                        value: preset,
                        child: Text(readerFontPresetLabel(preset)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _fontPreset = value);
                },
              ),
              const SizedBox(height: 20),
              const _SectionTitle(title: '主题'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 12,
                children: ReaderThemeMode.values.map((mode) {
                  final selected = mode == _themeMode;
                  final palette = _previewColors(mode);
                  return GestureDetector(
                    onTap: () => setState(() => _themeMode = mode),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.background,
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF5D7CFF)
                                  : palette.border,
                              width: selected ? 2.4 : 1.2,
                            ),
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: Color(0xFF5D7CFF),
                                )
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          readerThemeLabel(mode),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF66718D),
                                  ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const _SectionTitle(title: '行距'),
              const SizedBox(height: 12),
              Row(
                children: List.generate(_lineHeightOptions.length, (index) {
                  final value = _lineHeightOptions[index];
                  final selected = (_lineHeight - value).abs() < 0.01;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == _lineHeightOptions.length - 1 ? 0 : 10,
                      ),
                      child: ChoiceChip(
                        label: Text(
                          switch (index) {
                            0 => '紧凑',
                            1 => '舒适',
                            _ => '宽松',
                          },
                        ),
                        selected: selected,
                        onSelected: (_) => setState(() => _lineHeight = value),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              const _SectionTitle(title: '翻页方式'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ReaderPageTurnMode.values.map((mode) {
                  return ChoiceChip(
                    label: Text(readerPageTurnModeLabel(mode)),
                    selected: _pageTurnMode == mode,
                    onSelected: (_) => setState(() => _pageTurnMode = mode),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('应用阅读设置'),
                ),
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load reader preferences: $error'),
        ),
      ),
    );
  }

  void _applyPreferences(ReaderPreferences preferences) {
    _initialized = true;
    _themeMode = preferences.themeMode;
    _fontPreset = preferences.fontPreset;
    _pageTurnMode = preferences.pageTurnMode;
    _fontSize = preferences.fontSize;
    _lineHeight = preferences.lineHeight;
    _brightness = preferences.brightness;
  }

  Future<void> _save() async {
    final preferences = ReaderPreferences(
      themeMode: _themeMode,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      brightness: _brightness,
      fontPreset: _fontPreset,
      pageTurnMode: _pageTurnMode,
    );
    await ref
        .read(readerPreferencesControllerProvider.notifier)
        .save(preferences);
    widget.onApplied?.call();
  }

  _PreviewColors _previewColors(ReaderThemeMode mode) {
    return switch (mode) {
      ReaderThemeMode.paper => const _PreviewColors(
          background: Colors.white,
          primaryText: Color(0xFF1E2824),
          border: Color(0xFFE9E3D8),
        ),
      ReaderThemeMode.sepia => const _PreviewColors(
          background: Color(0xFFF4ECD8),
          primaryText: Color(0xFF3A2F24),
          border: Color(0xFFD8CCBA),
        ),
      ReaderThemeMode.night => const _PreviewColors(
          background: Color(0xFF141A18),
          primaryText: Color(0xFFE7ECE9),
          border: Color(0xFF26312D),
        ),
    };
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.trailing,
  });

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 56,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1EAFF)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _PreviewColors {
  const _PreviewColors({
    required this.background,
    required this.primaryText,
    required this.border,
  });

  final Color background;
  final Color primaryText;
  final Color border;
}
