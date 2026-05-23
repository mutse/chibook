import 'package:chibook/services/entitlement_service.dart';
import 'package:chibook/services/purchase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final entitlementServiceProvider = Provider<EntitlementService>((ref) {
  return EntitlementService();
});

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService(ref.read(entitlementServiceProvider));
});

final proUnlockedProvider = FutureProvider<bool>((ref) async {
  return ref.read(purchaseServiceProvider).isProUnlocked();
});

final proOfferSummaryProvider = FutureProvider<ProOfferSummary?>((ref) async {
  return ref.read(purchaseServiceProvider).loadProOfferSummary();
});
