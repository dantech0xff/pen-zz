import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../core/store_catalog.dart';
import 'store_service.dart';

/// In-app purchases through RevenueCat, which also checks every receipt with Google Play or
/// the App Store. Without an API key the store stays unavailable and the game runs as usual.
class RevenueCatStore implements StoreService {
  RevenueCatStore(this.apiKey);

  final String apiKey;
  bool _ready = false, _offline = false;

  @override
  bool get available => _ready;

  @override
  String get unavailableReason {
    if (apiKey.isEmpty) return 'Cửa hàng chưa sẵn sàng: bản build này chưa có khoá RevenueCat.';
    if (_offline) return 'Chưa kết nối được cửa hàng. Kiểm tra mạng rồi mở lại game.';
    return 'Cửa hàng đang kết nối.';
  }

  static StoreSnapshot _snapshot(CustomerInfo info) => StoreSnapshot(info.entitlements.active.keys.toSet(), [
    for (final t in info.nonSubscriptionTransactions)
      StoreTx(t.transactionIdentifier, t.productIdentifier, DateTime.tryParse(t.purchaseDate)),
  ]);

  @override
  Future<void> init(void Function(StoreSnapshot snapshot) onUpdate) async {
    if (apiKey.isEmpty || _ready) return;
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      await Purchases.configure(PurchasesConfiguration(apiKey));
      _ready = true;
      Purchases.addCustomerInfoUpdateListener((info) => onUpdate(_snapshot(info)));
      onUpdate(_snapshot(await Purchases.getCustomerInfo()));
    } on PlatformException {
      // Offline or misconfigured: purchases already cached on the device still apply.
      _offline = !_ready;
    }
  }

  @override
  Future<Map<String, String>> prices(List<String> productIds) async {
    if (!_ready) return const {};
    try {
      final products = await Purchases.getProducts(productIds, productCategory: ProductCategory.nonSubscription);
      return {for (final p in products) p.identifier: p.priceString};
    } on PlatformException {
      return const {};
    }
  }

  @override
  Future<PurchaseOutcome> buy(String productId) async {
    if (!_ready) return PurchaseFailed(unavailableReason);
    try {
      final products = await Purchases.getProducts([productId], productCategory: ProductCategory.nonSubscription);
      if (products.isEmpty) return const PurchaseFailed('Món này chưa có trên cửa hàng.');
      final r = await Purchases.purchase(PurchaseParams.storeProduct(products.first));
      final tx = r.storeTransaction;
      final snap = _snapshot(r.customerInfo);
      // Make sure the finished purchase is in the list even if the history lags behind.
      final txs = [
        ...snap.transactions.where((t) => t.id != tx.transactionIdentifier),
        StoreTx(tx.transactionIdentifier, tx.productIdentifier, DateTime.tryParse(tx.purchaseDate) ?? DateTime.now()),
      ];
      return PurchaseDone(tx.transactionIdentifier, StoreSnapshot(snap.entitlements, txs));
    } on PlatformException catch (e) {
      return switch (PurchasesErrorHelper.getErrorCode(e)) {
        PurchasesErrorCode.purchaseCancelledError => const PurchaseCancelled(),
        PurchasesErrorCode.paymentPendingError => const PurchasePending(),
        PurchasesErrorCode.productAlreadyPurchasedError => const PurchaseFailed(
          'Bạn đã mua món này. Bấm "Khôi phục giao dịch" để nhận lại.',
        ),
        PurchasesErrorCode.networkError => const PurchaseFailed('Không có mạng. Thử lại sau nhé.'),
        PurchasesErrorCode.purchaseNotAllowedError => const PurchaseFailed('Thiết bị này không cho phép mua hàng.'),
        PurchasesErrorCode.productNotAvailableForPurchaseError => const PurchaseFailed('Món này tạm thời chưa bán.'),
        PurchasesErrorCode.operationAlreadyInProgressError => const PurchaseFailed('Đang xử lý một giao dịch khác.'),
        final code => PurchaseFailed('Mua không thành công (${code.name}). Thử lại sau nhé.'),
      };
    }
  }

  @override
  Future<StoreSnapshot?> restore() async {
    if (!_ready) return null;
    try {
      return _snapshot(await Purchases.restorePurchases());
    } on PlatformException {
      return null;
    }
  }
}
