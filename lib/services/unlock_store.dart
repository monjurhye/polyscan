import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// The one-time "Remove ads" purchase.
///
/// [AppState] listens to [events] and remembers the unlock in its settings, so the
/// app works offline after buying. "Restore purchase" asks the store again.
abstract class UnlockStore {
  /// The non-consumable product in App Store Connect and Google Play Console.
  static const productId = 'com.pickixo.polyscan.removeads';

  /// Unlocks (bought or restored) and errors, as they arrive from the store.
  Stream<UnlockEvent> get events;

  /// The localized price, such as "$4.99" or "₹199", or null when the store is unavailable.
  Future<String?> price();

  /// Starts the purchase. The result arrives on [events].
  Future<void> buy();

  /// Asks the store for earlier purchases. An unlock arrives on [events] if there is one.
  Future<void> restore();
}

sealed class UnlockEvent {
  const UnlockEvent();
}

class Unlocked extends UnlockEvent {
  const Unlocked();
}

class UnlockFailed extends UnlockEvent {
  const UnlockFailed(this.message);
  final String message;
}

/// [UnlockStore] backed by StoreKit on iOS and Google Play Billing on Android.
class AppStoreUnlock implements UnlockStore {
  AppStoreUnlock({InAppPurchase? iap}) : _iapOverride = iap;

  final InAppPurchase? _iapOverride;
  InAppPurchase get _iap => _iapOverride ?? InAppPurchase.instance;

  final _events = StreamController<UnlockEvent>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _purchases;
  ProductDetails? _product;

  @override
  Stream<UnlockEvent> get events {
    _listen();
    return _events.stream;
  }

  /// Subscribes once. The store must be listening before any purchase or restore,
  /// and iOS replays unfinished transactions as soon as someone listens.
  void _listen() {
    _purchases ??= _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      _events.add(UnlockFailed('$e'));
    });
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != UnlockStore.productId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _events.add(const Unlocked());
        case PurchaseStatus.error:
          _events.add(UnlockFailed(p.error?.message ?? 'The purchase failed.'));
        case PurchaseStatus.canceled:
        case PurchaseStatus.pending:
          break;
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  Future<ProductDetails?> _loadProduct() async {
    if (_product != null) return _product;
    if (!await _iap.isAvailable()) return null;
    final response = await _iap.queryProductDetails({UnlockStore.productId});
    return _product = response.productDetails.isEmpty ? null : response.productDetails.first;
  }

  @override
  Future<String?> price() async => (await _loadProduct())?.price;

  @override
  Future<void> buy() async {
    _listen();
    final product = await _loadProduct();
    if (product == null) {
      _events.add(const UnlockFailed('The App Store is not available right now. Try again later.'));
      return;
    }
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
  }

  @override
  Future<void> restore() async {
    _listen();
    if (!await _iap.isAvailable()) {
      _events.add(const UnlockFailed('The App Store is not available right now. Try again later.'));
      return;
    }
    await _iap.restorePurchases();
  }
}
