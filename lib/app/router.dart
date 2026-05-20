import 'package:chibook/features/bookshelf/presentation/book_detail_screen.dart';
import 'package:chibook/features/bookshelf/presentation/book_notebook_screen.dart';
import 'package:chibook/features/bookshelf/presentation/book_playlist_screen.dart';
import 'package:chibook/features/home/presentation/reading_home_screen.dart';
import 'package:chibook/features/home/presentation/launch_gate_screen.dart';
import 'package:chibook/features/home/presentation/welcome_screen.dart';
import 'package:chibook/features/navigation/presentation/app_shell.dart';
import 'package:chibook/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:chibook/features/discover/presentation/discover_screen.dart';
import 'package:chibook/features/downloads/presentation/downloads_screen.dart';
import 'package:chibook/features/player/presentation/player_screen.dart';
import 'package:chibook/features/profile/presentation/profile_screen.dart';
import 'package:chibook/features/profile/presentation/reading_history_screen.dart';
import 'package:chibook/features/reader/presentation/reader_screen.dart';
import 'package:chibook/features/reader/presentation/reader_preferences_screen.dart';
import 'package:chibook/features/settings/presentation/settings_screen.dart';
import 'package:chibook/features/pro/presentation/pro_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    observers: [SentryNavigatorObserver()],
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LaunchGateScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
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
                path: '/player',
                builder: (context, state) => const PlayerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (context, state) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/book/:bookId',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final tab = state.uri.queryParameters['tab'];
          return BookDetailScreen(
            bookId: bookId,
            initialTabIndex: switch (tab) {
              'toc' => 1,
              'summary' => 2,
              _ => 0,
            },
          );
        },
      ),
      GoRoute(
        path: '/reader-settings',
        builder: (context, state) => const ReaderPreferencesScreen(),
      ),
      GoRoute(
        path: '/reader/:bookId',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          return ReaderScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/book/:bookId/notebook',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          return BookNotebookScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/book/:bookId/playlist',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          return BookPlaylistScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/downloads',
        builder: (context, state) => const DownloadsScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const ReadingHistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(showAppBar: true),
      ),
      GoRoute(
        path: '/pro',
        builder: (context, state) => const ProScreen(),
      ),
    ],
  );
});
