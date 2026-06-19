import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/navigation/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('AppShell adaptive navigation', () {
    testWidgets(
      'shows bottom navigation and switches branches on compact widths',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(const _TestApp());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('app-shell-bottom-nav')), findsOneWidget);
        expect(find.byKey(const Key('app-shell-sidebar')), findsNothing);
        expect(find.text('Home branch'), findsOneWidget);

        await tester.tap(find.text('发现'));
        await tester.pumpAndSettle();

        expect(find.text('Discover branch'), findsOneWidget);
        expect(find.text('Home branch'), findsNothing);
      },
    );

    testWidgets(
      'shows sidebar destinations and switches branches on wide widths',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(const _TestApp());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('app-shell-sidebar')), findsOneWidget);
        expect(find.byKey(const Key('app-shell-bottom-nav')), findsNothing);
        for (final label in _destinationLabels) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('Home branch'), findsOneWidget);

        await tester.tap(find.text('书架'));
        await tester.pumpAndSettle();

        expect(find.text('Bookshelf branch'), findsOneWidget);
        expect(find.text('Home branch'), findsNothing);
      },
    );

    testWidgets('wide widths do not add extra top gutter to branch content', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const _TestApp());
      await tester.pumpAndSettle();

      final branchTopLeft =
          tester.getTopLeft(find.byKey(const Key('branch-0')));

      expect(branchTopLeft.dy, 0);
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return ProviderScope(
              overrides: [
                bookshelfControllerProvider.overrideWith(
                  _TestBookshelfController.new,
                ),
              ],
              child: Builder(
                builder: (context) => AppShell(
                  navigationShell: navigationShell,
                ),
              ),
            );
          },
          branches: List.generate(
            5,
            (index) => StatefulShellBranch(
              routes: [
                GoRoute(
                  path: _locations[index],
                  builder: (context, state) => Scaffold(
                    body: Align(
                      alignment: Alignment.topLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            key: Key('branch-$index'),
                            width: 20,
                            height: 20,
                            color: Colors.amber,
                          ),
                          Text(_branchLabels[index]),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }
}

class _TestBookshelfController extends BookshelfController {
  @override
  Future<List<Book>> build() async => const [];
}

const _locations = [
  '/home',
  '/bookshelf',
  '/player',
  '/discover',
  '/profile',
];

const _destinationLabels = ['首页', '书架', '播放', '发现', '我的'];

const _branchLabels = [
  'Home branch',
  'Bookshelf branch',
  'Player branch',
  'Discover branch',
  'Profile branch',
];
