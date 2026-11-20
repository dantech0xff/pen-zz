import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../audio/sfx.dart';
import '../../core/battle/fighter.dart';
import '../../core/catalog.dart';
import '../../core/levels.dart';
import '../../render/fighter_painter.dart';
import '../../render/palette.dart';
import '../../render/text_fx.dart';
import '../../state/game_controller.dart';
import '../../state/monetization.dart';
import '../theme.dart';
import '../widgets.dart';
import 'settings_sheet.dart';
import 'store_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _tauntAt = -1;

  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context), nav = NavScope.of(context), m = MonetizationScope.of(context), s = g.save;
    final next = g.nextStage;
    var sel = nav.selStage ?? next;
    if (sel > next || sel < 1) sel = next;
    // Picking the next stage again goes back to following progress.
    void pick(int st) => setState(() => nav.selStage = st == next ? null : st);
    final ch = (sel - 1) ~/ levelsPerChapter, lastCh = (next - 1) ~/ levelsPerChapter;
    final chapter = chapters[ch];
    final chStars = [for (var i = 0; i < 10; i++) starCount(s.stars[ch * 10 + i])].fold(0, (a, b) => a + b);
    final need = xpNeed(s.lvl);
    final selLv = LevelDef(sel);
    final frame = ScreenFrame(
      // Fills the screen when there is room. On short screens (a small phone, a banner below,
      // large text) the hero keeps a minimum size and the lobby scrolls instead of overflowing.
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Transform.rotate(
                            angle: -2 * math.pi / 180,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.transparent, Pal.hl, Pal.hl, Colors.transparent],
                                  stops: [0, 0.54, 0.54, 0.92, 0.92],
                                ),
                              ),
                              child: Text('Bút Chiến', style: T.display(25)),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: m.enabled && g.hasGear ? () => showStoreSheet(context) : null,
                        child: CoinChip(coins: s.coins),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Cài đặt',
                        onPressed: () => showSettingsSheet(context),
                        icon: const Icon(Icons.settings_outlined, color: Pal.pencil),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(color: Pal.ink, borderRadius: BorderRadius.circular(999)),
                        child: Text('Cấp ${s.lvl}', style: T.display(17, Colors.white)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkBar(value: s.xp / need),
                            const SizedBox(height: 2),
                            Text('${s.xp}/$need kinh nghiệm', style: T.body(13)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const StarIcon(on: true, size: 18),
                      Text(' ${s.totalStars}/${levelCount * 3}', style: T.body(15, Pal.ink)),
                    ],
                  ),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 140),
                      child: GestureDetector(
                        onTap: () {
                          if (s.w.isEmpty) return;
                          Sfx.instance.play('tap', volume: 0.4);
                          setState(() => _tauntAt = 0);
                        },
                        child: Animated(
                          builder: (t, dt) {
                            if (_tauntAt >= 0) {
                              _tauntAt += dt;
                              if (_tauntAt > 2.6) _tauntAt = -1;
                            }
                            return _HeroPainter(g, t, _tauntAt);
                          },
                        ),
                      ),
                    ),
                  ),
                  Text(
                    g.hasGear ? 'Chạm vào nhân vật để xem ăn mừng.' : 'Vẽ vũ khí và khiên của bạn để bắt đầu.',
                    textAlign: TextAlign.center,
                    style: T.body(13, const Color(0xFF6B7080)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _MiniBtn('‹', ch > 0 ? () => pick((ch - 1) * 10 + 1) : null),
                      Expanded(
                        child: Column(
                          children: [
                            Text(chapter.name, style: T.display(17)),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              children: [
                                Text('Sân ${chapter.arena.name}', style: T.body(13)),
                                Text('Qua ${(s.stage - ch * 10).clamp(0, 10)}/10 màn', style: T.body(13)),
                                Semantics(
                                  label: '$chStars trên 30 sao',
                                  excludeSemantics: true,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      StarIcon(on: chStars > 0, size: 14, offColor: Pal.pencil),
                                      const SizedBox(width: 2),
                                      Text('$chStars/30', style: T.body(13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _MiniBtn('›', ch < lastCh ? () => pick(math.min(next, (ch + 1) * 10 + 1)) : null),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Two rows of five stages (plain rows, so the lobby can measure its own height).
                  for (final row in [0, 5]) ...[
                    if (row > 0) const SizedBox(height: 4),
                    Row(
                      children: [
                        for (var i = row + 1; i <= row + 5; i++) ...[
                          if (i > row + 1) const SizedBox(width: 6),
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1.15,
                              child: _Node(
                                stage: ch * 10 + i,
                                done: ch * 10 + i <= s.stage,
                                current: ch * 10 + i == next,
                                selected: ch * 10 + i == sel,
                                enabled: ch * 10 + i <= next,
                                stars: s.stars[ch * 10 + i - 1],
                                onTap: () => pick(ch * 10 + i),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  Text(chapter.arena.ruleText, textAlign: TextAlign.center, style: T.body(13, const Color(0xFF6B7080))),
                  const SizedBox(height: 6),
                  SketchButton(
                    label: !g.hasGear ? 'Vẽ đồ đầu tiên' : 'Đánh màn $sel${selLv.boss ? ' (trùm)' : ''}',
                    primary: true,
                    big: true,
                    onTap: () => g.hasGear ? nav.openStage(sel) : nav.openEditor(DrawMode.weapon, DrawFrom.first),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SketchButton(
                          label: 'Luyện tập',
                          subtitle: 'bot, bóng ma, chọn sân',
                          onTap: g.hasGear ? () => nav.go(Scr.practice) : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SketchButton(
                          label: 'Nâng cấp',
                          subtitle: s.free > 0 ? '${s.free} điểm chưa cộng' : 'sức mạnh, thủ, tốc độ',
                          alert: s.free > 0,
                          onTap: g.hasGear ? () => nav.go(Scr.upgrade) : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SketchButton(
                          label: 'Tủ đồ',
                          subtitle: 'mũ, áo choàng, kính, mực',
                          onTap: g.hasGear ? () => nav.go(Scr.shop) : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SketchButton(
                          label: 'Sửa đồ',
                          subtitle: 'vẽ lại vũ khí, khiên',
                          onTap: g.hasGear ? () => nav.openEditor(DrawMode.weapon, DrawFrom.home) : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!m.showBanner) return frame;
    // The banner sits under the lobby; the lobby gives up its bottom inset to it.
    return Column(
      children: [
        Expanded(
          child: MediaQuery.removePadding(context: context, removeBottom: true, child: frame),
        ),
        ColoredBox(
          color: Pal.paper,
          child: SafeArea(top: false, child: Center(child: m.ads.banner())),
        ),
      ],
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn(this.label, this.onTap);
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    child: Text(label, style: T.display(22, onTap == null ? const Color(0x40474B55) : Pal.ink)),
  );
}

class _Node extends StatelessWidget {
  const _Node({
    required this.stage,
    required this.done,
    required this.current,
    required this.selected,
    required this.enabled,
    required this.stars,
    required this.onTap,
  });

  final int stage, stars;
  final bool done, current, selected, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final boss = stage % 5 == 0;
    final fg = done ? Colors.white : Pal.pencil;
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Column(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: done ? Pal.ink : const Color(0xFFFFFDF7),
                    shape: boss ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: boss ? BorderRadius.circular(7) : null,
                    border: Border.all(
                      color: selected ? Pal.red : (done ? Pal.ink : Pal.pencil),
                      width: selected ? 2.6 : 2,
                    ),
                    boxShadow: current ? const [BoxShadow(color: Pal.hl, spreadRadius: 3)] : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(boss ? 'T' : '$stage', style: boss ? T.display(14, fg) : T.body(14, fg)),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final bit in [starWin, starFlawless, starGoal]) StarIcon(on: stars & bit != 0, size: 11),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  _HeroPainter(this.g, this.t, this.tauntAt);
  final GameController g;
  final double t, tauntAt;

  @override
  void paint(Canvas c, Size size) {
    final s = g.save;
    if (size.width < 10 || size.height < 10) return;
    final box = buildBox(s.w, s.s);
    final bw = box[2] - box[0], bh = box[3] - box[1];
    final k = math.min(size.width / bw, size.height / bh) * 0.94;
    final tx = size.width / 2 - (box[0] + box[2]) / 2 * k, ty = size.height - 6 - box[3] * k;
    c.save();
    c.translate(tx, ty);
    c.scale(k, k);
    c.drawLine(
      Offset(box[0], 1.5),
      Offset(box[2], 1.5),
      Paint()
        ..color = const Color(0x73474B55)
        ..strokeWidth = 2.4,
    );
    final f = Fighter(look: lookFor(s.eq), wStrokes: s.w, sStrokes: s.s)
      ..th = math.sin(t * 2) * 0.05
      ..taunting = tauntAt >= 0
      ..tauntT = math.max(0, tauntAt);
    paintFighter(c, f, t);
    c.restore();
    if (tauntAt >= 0) {
      drawBubble(
        c,
        tx + 10 * k,
        ty - 150 * k,
        tauntSay(s.eq[Slot.taunt] ?? 'vay-tay'),
        rgb(inkColor(s.eq[Slot.ink]!)),
        size.width,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
