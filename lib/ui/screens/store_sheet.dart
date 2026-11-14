import 'package:flutter/material.dart';

import '../../core/battle/fighter.dart';
import '../../core/catalog.dart';
import '../../core/store_catalog.dart';
import '../../core/templates.dart';
import '../../render/fighter_painter.dart';
import '../../render/palette.dart';
import '../../state/cloud_sync.dart';
import '../../state/game_controller.dart';
import '../../state/monetization.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cloud_panel.dart';

/// The store: free coins for a rewarded ad, one-time packs, outfits and coin packs.
/// [highlight] marks the product that unlocks an item the player tapped in the wardrobe.
Future<void> showStoreSheet(BuildContext context, {String? highlight}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _StoreSheet(highlight: highlight),
);

/// The wardrobe slot an item is worn in.
Slot slotOfItem(String id) {
  for (final slot in [Slot.hat, Slot.cape, Slot.glass, Slot.ink, Slot.inkW, Slot.fx, Slot.taunt]) {
    if (fitsSlot(slot, id)) return slot;
  }
  return Slot.hat;
}

class _StoreSheet extends StatefulWidget {
  const _StoreSheet({this.highlight});
  final String? highlight;

  @override
  State<_StoreSheet> createState() => _StoreSheetState();
}

class _StoreSheetState extends State<_StoreSheet> {
  String? _msg;

  /// The player has paid for something, so losing the save would cost real money.
  static bool _boughtSomething(GameController g) =>
      g.save.noAds || g.save.creditedPacks.isNotEmpty || g.save.creditedTx.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Prices may be missing if the game started offline; ask the store again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) MonetizationScope.read(context).refreshPrices();
    });
  }

  Future<void> _run(Future<String?> Function() action) async {
    final msg = await action();
    if (mounted && msg != null) setState(() => _msg = msg);
  }

  @override
  Widget build(BuildContext context) {
    final m = MonetizationScope.of(context), g = AppScope.of(context), cloud = CloudScope.of(context);
    List<StoreProductDef> pick(bool Function(StoreProductDef p) test) => [
      for (final p in storeProducts)
        if (test(p)) p,
    ];
    final packs = pick((p) => p.kind == ProductKind.oneTime && p.items.isEmpty);
    final starter = pick((p) => p.kind == ProductKind.oneTime && p.coins > 0);
    final outfits = pick((p) => p.kind == ProductKind.oneTime && p.coins == 0 && p.items.isNotEmpty);
    final coins = pick((p) => p.kind == ProductKind.consumable);
    Widget card(StoreProductDef p) =>
        _ProductCard(p: p, highlight: p.id == widget.highlight, onBuy: () => _run(() => m.buy(p)));
    final left = m.freeCoinsLeft;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.84,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Cửa hàng', style: T.display(22))),
                  CoinChip(coins: g.save.coins),
                ],
              ),
              if (!m.storeReady || !m.pricesLoaded)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    m.storeReady ? 'Chưa tải được giá. Kiểm tra mạng rồi mở lại cửa hàng.' : m.storeUnavailableReason,
                    style: T.body(15, Pal.red),
                  ),
                ),
              if (_msg != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_msg!, style: T.body(15, Pal.ink)),
                ),
              if (cloud.enabled && !cloud.linked && _boughtSomething(g))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SketchCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Liên kết Google để không mất đồ đã mua khi cài lại app hoặc đổi máy.',
                            style: T.body(15),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 112,
                          child: SketchButton(
                            label: 'Liên kết',
                            compact: true,
                            primary: true,
                            onTap: () => _run(() => linkGoogleAccount(context)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  children: [
                    if (m.ads.available) ...[
                      _Section('Xu miễn phí'),
                      SketchCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Xem một quảng cáo để nhận ${fmtNum(m.freeCoinsAmount)} xu. Còn $left/${AdRules.freeCoinsPerDay} lượt hôm nay.',
                                style: T.body(15),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 112,
                              child: SketchButton(
                                label: left == 0 ? 'Mai quay lại' : (m.ads.rewardedReady ? 'Xem' : 'Đang tải…'),
                                compact: true,
                                primary: left > 0 && m.ads.rewardedReady,
                                onTap: left > 0 && m.ads.rewardedReady
                                    ? () => _run(() async {
                                        final got = await m.claimFreeCoins();
                                        return got > 0 ? 'Đã nhận ${fmtNum(got)} xu.' : null;
                                      })
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    _Section('Gỡ quảng cáo'),
                    for (final p in packs) card(p),
                    _Section('Gói khởi đầu'),
                    for (final p in starter) card(p),
                    _Section('Bộ trang phục độc quyền'),
                    for (final p in outfits) card(p),
                    _Section('Xu'),
                    for (final p in coins) card(p),
                    const SizedBox(height: 8),
                    Text(
                      'Thanh toán qua Google Play hoặc App Store. Đồ trang trí không làm nhân vật mạnh hơn.',
                      style: T.body(13, Pal.pencil),
                    ),
                  ],
                ),
              ),
              if (m.storeReady)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SketchButton(
                    label: m.busy == 'restore' ? 'Đang khôi phục…' : 'Khôi phục giao dịch',
                    compact: true,
                    onTap: m.busy != null ? null : () => _run(m.restore),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 4),
    child: Text(title, style: T.display(17)),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.p, required this.highlight, required this.onBuy});
  final StoreProductDef p;
  final bool highlight;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final m = MonetizationScope.of(context), g = AppScope.of(context);
    final owned = m.owned(p), price = m.priceOf(p), busy = m.busy == p.id;
    final String label;
    VoidCallback? tap;
    if (owned) {
      label = 'Đã mua';
    } else if (busy) {
      label = 'Đang mua…';
    } else if (!m.storeReady) {
      label = 'Chưa mở';
    } else if (price == null) {
      label = m.pricesLoaded ? 'Chưa bán' : 'Chưa có giá';
    } else {
      label = price;
      tap = m.busy == null ? onBuy : null;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: highlight
            ? const BoxDecoration(
                borderRadius: cardRadius,
                boxShadow: [BoxShadow(color: Pal.hl, spreadRadius: 4)],
              )
            : null,
        child: SketchCard(
          child: Row(
            children: [
              if (p.items.isNotEmpty) ...[
                SizedBox(width: 64, height: 74, child: CustomPaint(painter: _OutfitThumb(g, p.items))),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: T.display(17)),
                    Text(p.desc, style: T.body(14)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 112,
                child: SketchButton(label: label, compact: true, primary: tap != null, onTap: tap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The player's figure wearing an outfit, with their own weapon (or a sword if none yet).
class _OutfitThumb extends CustomPainter {
  _OutfitThumb(this.g, this.items);
  final GameController g;
  final List<String> items;

  @override
  void paint(Canvas canvas, Size size) {
    final eq = Map<Slot, String>.of(g.save.eq);
    for (final id in items) {
      eq[slotOfItem(id)] = id;
    }
    final w = g.save.w.isNotEmpty ? g.save.w : templateOf('kiem').strokes;
    paintThumb(canvas, size, Fighter(look: lookFor(eq), wStrokes: w), gearBox([w]));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
