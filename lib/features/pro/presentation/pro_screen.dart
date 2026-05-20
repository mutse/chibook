import 'package:chibook/app/liquid_ui.dart';
import 'package:chibook/features/pro/application/providers.dart';
import 'package:chibook/l10n/generated/app_localizations.dart';
import 'package:chibook/services/purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProScreen extends ConsumerWidget {
  const ProScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isUnlockedAsync = ref.watch(proUnlockedProvider);
    final offerSummaryAsync = ref.watch(proOfferSummaryProvider);
    final purchaseService = ref.read(purchaseServiceProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        dark: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.proTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LiquidGlassCard(
                colors: const [Color(0x2EFFFFFF), Color(0x14FFFFFF)],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.proHeadline,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.proBody,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.86),
                            height: 1.6,
                          ),
                    ),
                    const SizedBox(height: 12),
                    offerSummaryAsync.when(
                      data: (offer) {
                        if (offer == null) return const SizedBox.shrink();
                        return Text(
                          '${offer.title} · ${offer.priceLabel}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.92),
                                    fontWeight: FontWeight.w700,
                                  ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (error, stack) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 18),
                    isUnlockedAsync.when(
                      data: (isUnlocked) => _StatusBanner(
                        text: isUnlocked
                            ? l10n.proStatusUnlocked
                            : purchaseService.isConfigured
                                ? l10n.proStatusLocked
                                : l10n.proStatusNotConfigured,
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (error, stack) => Text(
                        '权益状态加载失败: $error',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _FeatureCard(
                title: l10n.proIncludesTitle,
                items: [
                  l10n.proFeatureCloudTts,
                  l10n.proFeatureCaching,
                  l10n.proFeatureControls,
                  l10n.proFeatureUpgrades,
                ],
              ),
              const SizedBox(height: 18),
              _FeatureCard(
                title: l10n.proKeepsTitle,
                items: [
                  l10n.freeFeatureImport,
                  l10n.freeFeatureShelf,
                  l10n.freeFeatureLocalTts,
                  l10n.freeFeatureNotes,
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  final result = await ref
                      .read(purchaseServiceProvider)
                      .purchasePro();
                  ref.invalidate(proUnlockedProvider);
                  ref.invalidate(proOfferSummaryProvider);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_purchaseResultLabel(result, l10n))),
                  );
                },
                child: Text(l10n.proUnlockCta),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final result = await ref
                      .read(purchaseServiceProvider)
                      .restorePurchases();
                  ref.invalidate(proUnlockedProvider);
                  ref.invalidate(proOfferSummaryProvider);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_purchaseResultLabel(result, l10n))),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
                ),
                child: Text(l10n.proRestoreCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      colors: const [Color(0x2EFFFFFF), Color(0x14FFFFFF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.check_circle_rounded,
                      size: 18, color: Color(0xFF89CDFF)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.6,
                        ),
                  ),
                ),
              ],
            ),
            if (item != items.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
      ),
    );
  }
}

String _purchaseResultLabel(PurchaseResult result, AppLocalizations l10n) {
  return switch (result) {
    PurchaseResult.purchased => l10n.purchasePurchased,
    PurchaseResult.restored => l10n.purchaseRestored,
    PurchaseResult.alreadyUnlocked => l10n.purchaseAlreadyUnlocked,
    PurchaseResult.notConfigured => l10n.purchaseNotConfigured,
    PurchaseResult.cancelled => l10n.purchaseCancelled,
    PurchaseResult.failed => l10n.purchaseFailed,
  };
}
