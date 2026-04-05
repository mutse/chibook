import 'package:chibook/data/models/reader_preferences.dart';
import 'package:chibook/features/reader/application/reader_preferences_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderPreferencesSheet extends ConsumerStatefulWidget {
  const ReaderPreferencesSheet({super.key});

  @override
  ConsumerState<ReaderPreferencesSheet> createState() =>
      _ReaderPreferencesSheetState();
}

class _ReaderPreferencesSheetState
    extends ConsumerState<ReaderPreferencesSheet> {
  ReaderThemeMode _themeMode = ReaderThemeMode.paper;
  double _fontSize = 18;
  double _lineHeight = 1.85;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final preferencesAsync = ref.watch(readerPreferencesControllerProvider);

    return SafeArea(
      child: preferencesAsync.when(
        data: (preferences) {
          if (!_initialized) {
            _themeMode = preferences.themeMode;
            _fontSize = preferences.fontSize;
            _lineHeight = preferences.lineHeight;
            _initialized = true;
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '阅读偏好',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 18),
                Text(
                  '主题',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ReaderThemeMode.values.map((mode) {
                    final selected = mode == _themeMode;
                    return ChoiceChip(
                      label: Text(_themeLabel(mode)),
                      selected: selected,
                      onSelected: (_) => setState(() => _themeMode = mode),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text(
                  '字号 ${_fontSize.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  value: _fontSize,
                  min: 14,
                  max: 28,
                  divisions: 14,
                  onChanged: (value) => setState(() => _fontSize = value),
                ),
                Text(
                  '行高 ${_lineHeight.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  value: _lineHeight,
                  min: 1.4,
                  max: 2.2,
                  divisions: 8,
                  onChanged: (value) => setState(() => _lineHeight = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final preferences = ReaderPreferences(
                        themeMode: _themeMode,
                        fontSize: _fontSize,
                        lineHeight: _lineHeight,
                      );
                      await ref
                          .read(readerPreferencesControllerProvider.notifier)
                          .save(preferences);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: const Text('应用阅读设置'),
                  ),
                ),
              ],
            ),
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

  String _themeLabel(ReaderThemeMode mode) {
    return switch (mode) {
      ReaderThemeMode.paper => '纸白',
      ReaderThemeMode.sepia => '护眼',
      ReaderThemeMode.night => '夜间',
    };
  }
}
