import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chibook/app/chibook_app.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ChibookApp()));
    await tester.pump();

    expect(find.byType(ChibookApp), findsOneWidget);
  });
}
