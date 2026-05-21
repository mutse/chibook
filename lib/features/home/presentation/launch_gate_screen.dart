import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chibook/services/onboarding_service.dart';

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
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _route() async {
    final completed = await ref.read(onboardingServiceProvider).isCompleted();
    if (!mounted) return;
    context.go(completed ? '/home' : '/welcome');
  }
}
