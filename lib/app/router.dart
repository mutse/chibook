import 'package:chibook/features/home/presentation/reading_home_screen.dart';
import 'package:chibook/features/navigation/presentation/app_shell.dart';
import 'package:chibook/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:chibook/features/reader/presentation/reader_screen.dart';
import 'package:chibook/features/settings/presentation/settings_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => '/reading',
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reading',
                builder: (context, state) => const ReadingHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookshelf',
                builder: (context, state) =>
                    const BookshelfScreen(showAppBar: false),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tab-settings',
                builder: (context, state) =>
                    const SettingsScreen(showAppBar: false),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/reader/:bookId',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          return ReaderScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(showAppBar: true),
      ),
    ],
  );
});
