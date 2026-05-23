import 'dart:async';

import 'package:chibook/features/home/presentation/welcome_screen.dart';
import 'package:chibook/l10n/generated/app_localizations.dart';
import 'package:chibook/services/onboarding_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _DelayedOnboardingService extends OnboardingService {
  _DelayedOnboardingService(this._completer);

  final Completer<void> _completer;

  @override
  Future<void> complete() {
    return _completer.future;
  }

  @override
  Future<bool> isCompleted() async {
    return false;
  }
}

void main() {
  testWidgets('start reading navigates immediately while onboarding persists', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final completer = Completer<void>();
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingServiceProvider.overrideWithValue(
            _DelayedOnboardingService(completer),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('zh'),
          routerConfig: router,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始阅读'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();
  });
}
