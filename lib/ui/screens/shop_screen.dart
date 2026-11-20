import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/battle/fighter.dart';
import '../../core/catalog.dart';
import '../../core/ink_fx.dart';
import '../../core/mathx.dart';
import '../../core/rig.dart';
import '../../core/store_catalog.dart';
import '../../render/fighter_painter.dart';
import '../../render/fx.dart';
import '../../render/ink_painter.dart';
import '../../render/palette.dart';
import '../../render/text_fx.dart';
import '../../state/game_controller.dart';
import '../../state/monetization.dart';
import '../theme.dart';
import '../widgets.dart';
import 'store_sheet.dart';

enum ShopTab { hat, cape, glass, ink, fx, taunt }

const Map<ShopTab, String> _tabNames = {
  ShopTab.hat: 'Mũ',
  ShopTab.cape: 'Áo choàng',
  ShopTab.glass: 'Kính',
  ShopTab.ink: 'Màu mực',
  ShopTab.fx: 'Hiệu ứng',
  ShopTab.taunt: 'Ăn mừng',
};

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  ShopTab tab = ShopTab.hat;
  Slot inkSlot = Slot.ink;
  String? sel;
  final _Preview pv = _Preview();

  Slot get slot => switch (tab) {
    ShopTab.hat => Slot.hat,
    ShopTab.cape => Slot.cape,
    ShopTab.glass => Slot.glass,
    ShopTab.ink => inkSlot,
    ShopTab.fx => Slot.fx,
    ShopTab.taunt => Slot.taunt,
  };

  void _select(String id) => setState(() {
    sel = id;
    pv.reset();
  });

  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context), nav = NavScope.of(context), m = MonetizationScope.of(context), s = g.save;
    final items = itemsFor(slot);
    final current = s.eq[slot] ?? defaultEquip[slot]!;
    final selId = sel != null && items.any((i) => i.id == sel) ? sel! : current;
    final it = itemById(selId)!;
    final owned = g.owns(selId), equipped = current == selId;
    final String buyLabel;
    VoidCallback? buy;
    if (equipped) {
      buyLabel = 'Đang dùng';
    } else if (owned) {
      buyLabel = 'Dùng';
      buy = () => g.buyOrEquip(slot, selId);
    } else if (it.exclusive) {
      final p = productForItem(selId);
      if (m.enabled && p != null) {
        buyLabel = 'Có trong ${p.title}';
        buy = () => showStoreSheet(context, highlight: p.id);
      } else {
        buyLabel = 'Chỉ có trên bản app';
      }
    } else if (s.coins >= it.price) {
      buyLabel = 'Mua (${fmtNum(it.price)} xu)';
      buy = () => g.buyOrEquip(slot, selId);
    } else {
      buyLabel = 'Thiếu ${fmtNum(it.price - s.coins)} xu';
    }
    final eq = Map<Slot, String>.of(s.eq)..[slot] = selId;
    String? desc;
    if (slot == Slot.inkW && it.special) {
      desc = it.fx == InkFx.none
          ? 'Mực đặc biệt chỉ để đẹp, không có hiệu ứng đánh.'
          : 'Mực ${inkFxSpec(it.fx).title.toLowerCase()}: ${inkFxSpec(it.fx).desc}';
    }
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ScreenHeader(title: 'Tủ đồ', onBack: nav.home),
              ),
              if (m.enabled) ...[
                SizedBox(
                  width: 104,
                  child: SketchButton(
                    label: 'Cửa hàng',
                    compact: true,
                    primary: true,
                    onTap: () => showStoreSheet(context),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              CoinChip(coins: s.coins),
            ],
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 3.2,
            children: [
              for (final t in ShopTab.values)
                GestureDetector(
                  onTap: () => setState(() {
                    tab = t;
                    sel = null;
                    pv.reset();
                  }),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t == tab ? Pal.ink : Colors.transparent,
                      border: Border.all(color: t == tab ? Pal.ink : Pal.pencil, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_tabNames[t]!, style: T.body(15, t == tab ? Colors.white : Pal.pencil)),
                  ),
                ),
            ],
          ),
          if (tab == ShopTab.ink) ...[
            const SizedBox(height: 6),
            Segmented<Slot>(
              options: const {Slot.ink: 'Người', Slot.inkW: 'Vũ khí', Slot.inkS: 'Khiên'},
              value: inkSlot,
              onChanged: (v) => setState(() {
                inkSlot = v;
                sel = null;
              }),
            ),
          ],
          const SizedBox(height: 6),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              border: Border.all(color: const Color(0x59474B55), width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: Animated(builder: (t, dt) => _PreviewPainter(g, pv, tab, slot, eq, selId, dt)),
          ),
          if (desc != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(desc, style: T.body(14, Pal.ink)),
            ),
          const SizedBox(height: 6),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.6,
              children: [
                for (final i in items)
                  _ItemTile(
                    item: i,
                    bodyInk: inkColor(s.eq[Slot.ink]!),
                    selected: i.id == selId,
                    equipped: current == i.id,
                    owned: g.owns(i.id),
                    onTap: () => _select(i.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SketchButton(label: buyLabel, primary: true, big: true, onTap: buy),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.bodyInk,
    required this.selected,
    required this.equipped,
    required this.owned,
    required this.onTap,
  });

  final Item item;
  final int bodyInk;
  final bool selected, equipped, owned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final swatch = item.color != null || item.id == sameInk;
    Gradient? grad;
    if (item.grad != null) grad = LinearGradient(colors: [for (final c in item.grad!) rgb(c)]);
    if (item.rainbow) {
      grad = const LinearGradient(
        colors: [
          Color(0xFFE53935),
          Color(0xFFFB8C00),
          Color(0xFFFDD835),
          Color(0xFF43A047),
          Color(0xFF1E88E5),
          Color(0xFF8E24AA),
        ],
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF7),
          border: Border.all(color: selected ? Pal.ink : Pal.pencil, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? const [BoxShadow(color: Pal.hl, spreadRadius: 3)] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                if (swatch) ...[
                  Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: grad == null ? rgb(item.color ?? bodyInk) : null,
                      gradient: grad,
                      border: Border.all(color: const Color(0x2E000000), width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(item.name, style: T.display(14), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            Row(
              children: [
                if (!equipped && !owned && !item.exclusive) ...[const CoinIcon(size: 13), const SizedBox(width: 4)],
                Expanded(
                  child: Text(
                    equipped
                        ? 'Đang dùng'
                        : owned
                        ? 'Đã có'
                        : item.exclusive
                        ? 'Độc quyền'
                        : fmtNum(item.price),
                    style: T.body(14, equipped ? Pal.ink : (item.exclusive && !owned ? Pal.red : Pal.pencil)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.fx != InkFx.none) Text(inkFxSpec(item.fx).title, style: T.body(13, Pal.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-screen state of the wardrobe preview (the straw dummy's swing loop and its particles).
class _Preview {
  double t = 0;
  final FxSystem fx = FxSystem();
  final List<P> trail = [];
  bool hitDone = false;

  void reset() {
    t = 0;
    fx.clear();
    trail.clear();
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.g, this.pv, this.tab, this.slot, this.eq, this.selId, this.dt);
  final GameController g;
  final _Preview pv;
  final ShopTab tab;
  final Slot slot;
  final Map<Slot, String> eq;
  final String selId;
  final double dt;

  @override
  void paint(Canvas c, Size size) {
    pv.t += dt;
    pv.fx.update(dt);
    final w = size.width, h = size.height;
    final look = lookFor(eq);
    final close = tab == ShopTab.hat || tab == ShopTab.glass;
    final k = close ? math.min(w / 190, h / 130) : math.min(w / 380, h / 230);
    final gx = close ? w / 2 - 4 * k : w / 2 - 50 * k, gy = close ? h * 0.47 + 99 * k : h - 14;
    c.save();
    c.translate(gx, gy);
    c.scale(k, k);
    if (!close) line(c, -150, 1.5, 290, 1.5, const Color(0x73474B55), 2);
    final f = Fighter(look: look, w: g.pw, wStrokes: g.save.w, sStrokes: g.save.s)..r = slot == Slot.inkS ? 1 : 0;
    final fxId = eq[Slot.fx] ?? 'muc';
    if (tab == ShopTab.fx) {
      line(c, 170, 0, 170, -70, const Color(0xFF8A6D2F), 4);
      final dummy = Path()..addRRect(RRect.fromLTRBR(152, -112, 188, -62, const Radius.circular(14)));
      fillPath(c, dummy, const Color(0xFFEAD39A));
      strokePath(c, dummy, const Color(0xFF8A6D2F), 2);
      final tt = pv.t % 1.4;
      if (tt < 0.4) {
        f.state = FState.windup;
        f.th = thWind * easeOut(tt / 0.4);
        pv.trail.clear();
        pv.hitDone = false;
      } else if (tt < 0.62) {
        f.state = FState.strike;
        f.th = thWind + swingArc * smooth((tt - 0.4) / 0.22);
      } else {
        f.state = FState.recover;
        f.recFrom = thEnd;
        f.th = thEnd * (1 - easeOut(math.min(1, (tt - 0.62) / 0.5)));
      }
      if (tt >= 0.4 && tt < 0.62 && g.pw.pts.isNotEmpty) {
        final hp = strikeHand(f.th), cs = math.cos(f.th), sn = math.sin(f.th), i = g.pw.tip, pts = g.pw.pts;
        final tip = P(hp.x + pts[i] * cs - pts[i + 1] * sn, hp.y + pts[i] * sn + pts[i + 1] * cs);
        pv.trail.add(tip);
        if (pv.trail.length > 10) pv.trail.removeAt(0);
        pv.fx.trailFx(fxId, tip.x, tip.y);
        if (!pv.hitDone && tt > 0.52) {
          pv.hitDone = true;
          pv.fx.hitFx(160, -84, 1, fxId, fxColorOf(look, pv.t), speed: 520);
        }
      }
      drawTrail(c, fxId, fxColorOf(look, pv.t), pv.trail, tt < 0.62 ? 1 : clampD(1 - (tt - 0.62) / 0.15, 0, 1), pv.t);
    } else if (tab == ShopTab.taunt) {
      f.taunting = true;
      f.tauntT = pv.t % 3;
    } else if (tab == ShopTab.cape && pv.t % 4 < 2.4) {
      f.walking = true;
      f.walk = pv.t * 10;
    } else {
      f.th = math.sin(pv.t * 2) * 0.05;
    }
    paintFighter(c, f, pv.t);
    pv.fx.draw(c);
    c.restore();
    if (tab == ShopTab.taunt) drawBubble(c, gx + 10 * k, gy - 150 * k, tauntSay(selId), rgb(look.body), w);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
