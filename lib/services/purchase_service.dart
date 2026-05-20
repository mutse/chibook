import 'dart:async';
import 'dart:io';

import 'package:chibook/services/entitlement_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/errors.dart' as revenuecat_errors;
import 'package:purchases_flutter/purchases_flutter.dart' as revenuecat;

enum PurchaseResult {
  purchased,
  restored,
  alreadyUnlocked,
  notConfigured,
  cancelled,
  failed,
}

class ProOfferSummary {
  const ProOfferSummary({
    required this.title,
    required this.priceLabel,
    this.description,
  });

  final String title;
  final String priceLabel;
  final String? description;
}

class PurchaseService {
  PurchaseService(this._entitlementService);

  final EntitlementService _entitlementService;

  static const _appleApiKey =
      String.fromEnvironment('REVENUECAT_APPLE_API_KEY');
  static const _googleApiKey =
      String.fromEnvironment('REVENUECAT_GOOGLE_API_KEY');
  static const _proEntitlementId =
      String.fromEnvironment('REVENUECAT_PRO_ENTITLEMENT_ID', defaultValue: 'pro');
  static const _offeringId = String.fromEnvironment('REVENUECAT_OFFERING_ID');
  static const _packageId =
      String.fromEnvironment('REVENUECAT_PRO_PACKAGE_ID', defaultValue: r'$rc_lifetime');

  Future<void>? _configureFuture;
  bool _listenerRegistered = false;

  bool get isSupportedPlatform => Platform.isIOS || Platform.isAndroid;

  bool get isConfigured => isSupportedPlatform && _apiKey.trim().isNotEmpty;

  Future<bool> isProUnlocked() async {
    if (!isConfigured) {
      return _entitlementService.isProUnlocked();
    }
    try {
      await _ensureConfigured();
      final customerInfo = await revenuecat.Purchases.getCustomerInfo();
      return _syncEntitlements(customerInfo);
    } catch (_) {
      return _entitlementService.isProUnlocked();
    }
  }

  Future<ProOfferSummary?> loadProOfferSummary() async {
    if (!isConfigured) return null;
    try {
      await _ensureConfigured();
      final package = await _selectPackage();
      if (package == null) return null;
      return ProOfferSummary(
        title: package.storeProduct.title.trim().isEmpty
            ? 'Chibook Pro'
            : package.storeProduct.title.trim(),
        priceLabel: package.storeProduct.priceString,
        description: package.storeProduct.description.trim().isEmpty
            ? null
            : package.storeProduct.description.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<PurchaseResult> purchasePro() async {
    if (await _entitlementService.isProUnlocked()) {
      return PurchaseResult.alreadyUnlocked;
    }
    if (!isConfigured) {
      return PurchaseResult.notConfigured;
    }

    try {
      await _ensureConfigured();
      final package = await _selectPackage();
      if (package == null) {
        return PurchaseResult.failed;
      }

      final result = await revenuecat.Purchases.purchase(
        revenuecat.PurchaseParams.package(package),
      );
      final unlocked = await _syncEntitlements(result.customerInfo);
      return unlocked ? PurchaseResult.purchased : PurchaseResult.failed;
    } on PlatformException catch (error) {
      final code = revenuecat_errors.PurchasesErrorHelper.getErrorCode(error);
      if (code == revenuecat_errors.PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult.cancelled;
      }
      return PurchaseResult.failed;
    } catch (_) {
      return PurchaseResult.failed;
    }
  }

  Future<PurchaseResult> restorePurchases() async {
    if (!isConfigured) {
      return await _entitlementService.isProUnlocked()
          ? PurchaseResult.restored
          : PurchaseResult.notConfigured;
    }

    try {
      await _ensureConfigured();
      final customerInfo = await revenuecat.Purchases.restorePurchases();
      final unlocked = await _syncEntitlements(customerInfo);
      return unlocked ? PurchaseResult.restored : PurchaseResult.failed;
    } on PlatformException catch (error) {
      final code = revenuecat_errors.PurchasesErrorHelper.getErrorCode(error);
      if (code == revenuecat_errors.PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult.cancelled;
      }
      return PurchaseResult.failed;
    } catch (_) {
      return PurchaseResult.failed;
    }
  }

  Future<void> _ensureConfigured() async {
    if (!isConfigured) return;
    _configureFuture ??= _configure();
    await _configureFuture;
  }

  Future<void> _configure() async {
    await revenuecat.Purchases.setLogLevel(
      kDebugMode ? revenuecat.LogLevel.debug : revenuecat.LogLevel.warn,
    );
    final configuration = revenuecat.PurchasesConfiguration(_apiKey)
      ..shouldShowInAppMessagesAutomatically = false;
    await revenuecat.Purchases.configure(configuration);

    if (!_listenerRegistered) {
      revenuecat.Purchases.addCustomerInfoUpdateListener(
        _handleCustomerInfoUpdated,
      );
      _listenerRegistered = true;
    }

    final customerInfo = await revenuecat.Purchases.getCustomerInfo();
    await _syncEntitlements(customerInfo);
  }

  void _handleCustomerInfoUpdated(revenuecat.CustomerInfo customerInfo) {
    unawaited(_syncEntitlements(customerInfo));
  }

  Future<bool> _syncEntitlements(revenuecat.CustomerInfo customerInfo) async {
    final isUnlocked = customerInfo.entitlements.active.containsKey(
      _proEntitlementId,
    );
    await _entitlementService.setProUnlocked(isUnlocked);
    return isUnlocked;
  }

  Future<revenuecat.Package?> _selectPackage() async {
    final offering = await _selectOffering();
    if (offering == null) return null;

    if (_packageId.trim().isNotEmpty) {
      final configured = offering.getPackage(_packageId.trim());
      if (configured != null) return configured;
    }

    return offering.lifetime ??
        offering.annual ??
        offering.monthly ??
        offering.availablePackages.firstOrNull;
  }

  Future<revenuecat.Offering?> _selectOffering() async {
    final offerings = await revenuecat.Purchases.getOfferings();
    if (_offeringId.trim().isNotEmpty) {
      return offerings.getOffering(_offeringId.trim()) ?? offerings.current;
    }
    return offerings.current;
  }

  String get _apiKey {
    if (Platform.isIOS) return _appleApiKey;
    if (Platform.isAndroid) return _googleApiKey;
    return '';
  }
}

extension on List<revenuecat.Package> {
  revenuecat.Package? get firstOrNull => isEmpty ? null : first;
}
