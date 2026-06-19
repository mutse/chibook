import 'package:chibook/app/adaptive/adaptive_layout.dart';
import 'package:chibook/app/adaptive/adaptive_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptiveLayoutData.fromWidth', () {
    test('returns compact for phone widths', () {
      final layout = AdaptiveLayoutData.fromWidth(430);

      expect(layout.sizeClass, AdaptiveSizeClass.compact);
      expect(layout.showsSidebar, isFalse);
    });

    test('returns medium for narrow tablet widths', () {
      final layout = AdaptiveLayoutData.fromWidth(900);

      expect(layout.sizeClass, AdaptiveSizeClass.medium);
      expect(layout.showsSidebar, isTrue);
    });

    test('returns expanded for full tablet widths', () {
      final layout = AdaptiveLayoutData.fromWidth(1180);

      expect(layout.sizeClass, AdaptiveSizeClass.expanded);
      expect(layout.contentMaxWidth, 1100);
    });

    test('uses exact breakpoint edges', () {
      expect(
        AdaptiveLayoutData.fromWidth(839).sizeClass,
        AdaptiveSizeClass.compact,
      );
      expect(
        AdaptiveLayoutData.fromWidth(840).sizeClass,
        AdaptiveSizeClass.medium,
      );
      expect(
        AdaptiveLayoutData.fromWidth(1099).sizeClass,
        AdaptiveSizeClass.medium,
      );
      expect(
        AdaptiveLayoutData.fromWidth(1100).sizeClass,
        AdaptiveSizeClass.expanded,
      );
    });
  });

  test('adaptive column count scales with width', () {
    expect(
      AdaptiveLayoutData.fromWidth(430).adaptiveColumns(
        compact: 1,
        medium: 2,
        expanded: 4,
      ),
      1,
    );
    expect(
      AdaptiveLayoutData.fromWidth(900).adaptiveColumns(
        compact: 1,
        medium: 2,
        expanded: 4,
      ),
      2,
    );
    expect(
      AdaptiveLayoutData.fromWidth(1180).adaptiveColumns(
        compact: 1,
        medium: 2,
        expanded: 4,
      ),
      4,
    );
  });

  testWidgets(
    'AdaptiveTwoPane uses local constraints instead of full window width',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Center(
              child: SizedBox(
                width: 430,
                child: AdaptiveTwoPane(
                  primary: const SizedBox(key: Key('primary'), height: 20),
                  secondary: const SizedBox(
                    key: Key('secondary'),
                    height: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Column), findsOneWidget);
      expect(find.byType(Row), findsNothing);
      expect(find.byKey(const Key('primary')), findsOneWidget);
      expect(find.byKey(const Key('secondary')), findsOneWidget);
    },
  );
}
