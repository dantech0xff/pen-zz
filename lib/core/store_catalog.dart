/// Real-money products, their RevenueCat entitlements, and the ad pacing rules.
///
/// Product ids must match the in-app products created in Google Play Console (and App Store
/// Connect), and the entitlement ids must match the entitlements in the RevenueCat project.
library;

enum ProductKind { consumable, oneTime }

class StoreProductDef {
  const StoreProductDef(
    this.id,
    this.kind,
    this.title,
    this.desc, {
    this.coins = 0,
    this.entitlement,
    this.items = const [],
  });

  final String id;
  final ProductKind kind;
  final String title, desc;

  /// Coins credited per purchase (coin packs) or once per install (starter pack).
  final int coins;

  /// RevenueCat entitlement unlocked by a one-time product.
  final String? entitlement;

  /// Exclusive wardrobe items the product unlocks.
  final List<String> items;
}

abstract final class Ent {
  static const noAds = 'no_ads';
  static const starter = 'starter_pack';
  static const royal = 'set_royal';
  static const galaxy = 'set_galaxy';
}

const List<StoreProductDef> storeProducts = [
  StoreProductDef(
    'pz_remove_ads',
    ProductKind.oneTime,
    'Gỡ quảng cáo',
    'Tắt banner và quảng cáo chen giữa các trận. Quảng cáo có thưởng vẫn còn, bạn tự chọn xem hay không.',
    entitlement: Ent.noAds,
  ),
  StoreProductDef(
    'pz_starter_pack',
    ProductKind.oneTime,
    'Gói khởi đầu',
    '2.000 xu và mực Nhũ ngọc độc quyền. Mỗi tài khoản mua một lần.',
    coins: 2000,
    entitlement: Ent.starter,
    items: ['nhu-ngoc'],
  ),
  StoreProductDef(
    'pz_set_royal',
    ProductKind.oneTime,
    'Bộ Hoàng gia',
    'Vương miện ngọc, áo choàng hoàng gia và mực vũ khí hoàng kim. Chỉ để trang trí.',
    entitlement: Ent.royal,
    items: ['vuong-mien-ngoc', 'ao-choang-hoang-gia', 'muc-hoang-kim'],
  ),
  StoreProductDef(
    'pz_set_galaxy',
    ProductKind.oneTime,
    'Bộ Ngân hà',
    'Mũ ngân hà, áo choàng ngân hà và mực vũ khí ngân hà. Chỉ để trang trí.',
    entitlement: Ent.galaxy,
    items: ['mu-ngan-ha', 'ao-choang-ngan-ha', 'muc-ngan-ha'],
  ),
  StoreProductDef('pz_coins_1000', ProductKind.consumable, 'Túi xu', '1.000 xu.', coins: 1000),
  StoreProductDef('pz_coins_3500', ProductKind.consumable, 'Hộp xu', '3.500 xu.', coins: 3500),
  StoreProductDef('pz_coins_9000', ProductKind.consumable, 'Rương xu', '9.000 xu.', coins: 9000),
];

StoreProductDef? productById(String id) {
  for (final p in storeProducts) {
    if (p.id == id) return p;
  }
  return null;
}

/// The product that unlocks an exclusive wardrobe item, if any.
StoreProductDef? productForItem(String itemId) {
  for (final p in storeProducts) {
    if (p.items.contains(itemId)) return p;
  }
  return null;
}

/// How often ads appear. Rewarded ads are always the player's choice.
abstract final class AdRules {
  /// Rewarded "free coins" views per calendar day.
  static const int freeCoinsPerDay = 3;

  /// An interstitial may show after this many finished matches...
  static const int interstitialEvery = 3;

  /// ...at least this long after the previous one...
  static const Duration interstitialGap = Duration(seconds: 150);

  /// ...and only once the player has cleared this many stages.
  static const int interstitialFromStage = 3;

  /// Coins for one rewarded "free coins" view: about three quarters of a normal stage.
  static int freeCoins(int stage) => 60 + 6 * stage;
}

/// Local calendar day as yyyymmdd, used to reset the daily free-coin views.
int dayKey(DateTime t) => t.year * 10000 + t.month * 100 + t.day;

/// One store transaction for a one-time or consumable product.
class StoreTx {
  const StoreTx(this.id, this.productId, this.time);

  final String id, productId;

  /// Purchase time from the store; null when it could not be read.
  final DateTime? time;
}

/// What the store reports about the player: active entitlements and past purchases.
class StoreSnapshot {
  const StoreSnapshot(this.entitlements, [this.transactions = const []]);

  final Set<String> entitlements;
  final List<StoreTx> transactions;
}
