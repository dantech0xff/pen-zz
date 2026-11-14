import '../core/store_catalog.dart';

sealed class PurchaseOutcome {
  const PurchaseOutcome();
}

/// The purchase went through; [snapshot] is the player's state right after it.
class PurchaseDone extends PurchaseOutcome {
  const PurchaseDone(this.transactionId, this.snapshot);

  final String transactionId;
  final StoreSnapshot snapshot;
}

class PurchaseCancelled extends PurchaseOutcome {
  const PurchaseCancelled();
}

/// The payment is waiting (for example cash at a shop); the store reports it when it clears.
class PurchasePending extends PurchaseOutcome {
  const PurchasePending();
}

class PurchaseFailed extends PurchaseOutcome {
  const PurchaseFailed(this.message);

  final String message;
}

/// In-app purchases as the game sees them. The RevenueCat version runs on Android and iOS;
/// [NoStore] is used on the web build, in tests, and when no RevenueCat key was given.
abstract class StoreService {
  bool get available;

  /// Why the store is not available, in words for the player.
  String get unavailableReason;

  /// Connects to the store. [onUpdate] receives the player's state now and whenever it
  /// changes later (a pending payment clears, a refund, a purchase on another device).
  Future<void> init(void Function(StoreSnapshot snapshot) onUpdate);

  /// Localised prices by product id. Products missing from the store are left out.
  Future<Map<String, String>> prices(List<String> productIds);

  Future<PurchaseOutcome> buy(String productId);

  /// Restores one-time purchases. Returns null when the store could not be reached.
  Future<StoreSnapshot?> restore();
}

class NoStore implements StoreService {
  const NoStore([this.unavailableReason = 'Cửa hàng chỉ có trên bản app Android và iOS.']);

  @override
  final String unavailableReason;

  @override
  bool get available => false;

  @override
  Future<void> init(void Function(StoreSnapshot snapshot) onUpdate) async {}

  @override
  Future<Map<String, String>> prices(List<String> productIds) async => const {};

  @override
  Future<PurchaseOutcome> buy(String productId) async => PurchaseFailed(unavailableReason);

  @override
  Future<StoreSnapshot?> restore() async => null;
}
