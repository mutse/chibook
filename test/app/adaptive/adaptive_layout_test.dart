import 'package:chibook/app/adaptive/adaptive_layout.dart';
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
}
