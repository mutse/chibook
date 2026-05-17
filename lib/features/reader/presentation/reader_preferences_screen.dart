import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/features/reader/presentation/widgets/reader_preferences_sheet.dart';
import 'package:flutter/material.dart';

class ReaderPreferencesScreen extends StatelessWidget {
  const ReaderPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '阅读设置',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '亮度、字体、主题、行距、翻页方式',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: ReaderPreferencesEditor(
                  showTitle: false,
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
