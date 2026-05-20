import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/features/home/presentation/launch_gate_screen.dart';
import 'package:chibook/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              children: [
                const Spacer(),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF8EC8FF).withValues(alpha: 0.50),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 168,
                      height: 168,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.72),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1C4F6DFF),
                            blurRadius: 40,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF7CBFFF), Color(0xFF5B74FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          l10n.welcomeBrand,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.welcomeSubtitle,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: const Color(0xFF53647D),
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 42),
                Text(
                  l10n.welcomeFeatureLine,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF5D7CFF),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.welcomeBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.7,
                      ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _WelcomeInfoCard(
                        title: l10n.welcomeFormatsTitle,
                        body: l10n.welcomeFormatsBody,
                        icon: Icons.library_books_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _WelcomeInfoCard(
                        title: l10n.welcomeOfflineTitle,
                        body: l10n.welcomeOfflineBody,
                        icon: Icons.wifi_off_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _WelcomeInfoCard(
                  title: l10n.welcomeProTitle,
                  body: l10n.welcomeProBody,
                  icon: Icons.workspace_premium_outlined,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await ref.read(onboardingServiceProvider).complete();
                      if (!context.mounted) return;
                      context.go('/home');
                    },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(l10n.welcomePrimaryCta),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await ref.read(onboardingServiceProvider).complete();
                    if (!context.mounted) return;
                    context.go('/bookshelf');
                  },
                  child: Text(l10n.welcomeSecondaryCta),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeInfoCard extends StatelessWidget {
  const _WelcomeInfoCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF5D7CFF)),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
