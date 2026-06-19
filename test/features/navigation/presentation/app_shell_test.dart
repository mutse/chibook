import 'package:chibook/data/models/book.dart';
import 'package:chibook/features/bookshelf/application/bookshelf_controller.dart';
import 'package:chibook/features/navigation/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('AppShell adaptive navigation', () {
    testWidgets('shows bottom navigation on compact widths', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_TestApp(width: 430));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('app-shell-bottom-nav')), findsOneWidget);
      expect(find.byKey(const Key('app-shell-sidebar')), findsNothing);
    });

    testWidgets('shows sidebar on wide widths', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_TestApp(width: 1024));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('app-shell-sidebar')), findsOneWidget);
      expect(find.byKey(const Key('app-shell-bottom-nav')), findsNothing);
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return SizedBox(
              width: width,
              child: ProviderScope(
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
                    body: Center(child: Text('Branch $index')),
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
