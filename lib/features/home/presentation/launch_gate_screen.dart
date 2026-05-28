import 'package:chibook/app/app_logo.dart';
import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/l10n/generated/app_localizations.dart';
import 'package:chibook/services/onboarding_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LaunchGateScreen extends ConsumerStatefulWidget {
  const LaunchGateScreen({super.key});

  @override
  ConsumerState<LaunchGateScreen> createState() => _LaunchGateScreenState();
}

class _LaunchGateScreenState extends ConsumerState<LaunchGateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _route();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(
                    size: 104,
                    radius: 32,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.appTitle,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '正在准备你的阅读空间',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF5C6C90),
                        ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _route() async {
    final completed = await ref.read(onboardingServiceProvider).isCompleted();
    if (!mounted) return;
    context.go(completed ? '/home' : '/welcome');
  }
}
