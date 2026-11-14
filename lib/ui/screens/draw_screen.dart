import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/battle/ai.dart';
import '../../core/battle/fighter.dart';
import '../../core/bots.dart';
import '../../core/catalog.dart';
import '../../core/gear.dart';
import '../../core/levels.dart';
import '../../core/mathx.dart';
import '../../core/rig.dart';
import '../../core/strokes.dart';
import '../../core/templates.dart';
import '../../render/fighter_painter.dart';
import '../../render/ink_painter.dart';
import '../../render/palette.dart';
import '../../render/text_fx.dart';
import '../../state/game_controller.dart';
import '../theme.dart';
import '../widgets.dart';

/// Ids that can become blueprints: starters plus every boss and mini-boss unlock.
List<GearTemplate> blueprintTemplates(GearKind kind) {
  final unlockable = {for (final c in chapters) ...[c.bossWeapon, c.miniShield]};
  final list = kind == GearKind.weapon ? weaponTemplates : shieldTemplates;
  return [for (final t in list) if (t.starter || unlockable.contains(t.id)) t];
}

String unlockHint(String id) {
  for (final c in chapters) {
    if (c.bossWeapon == id) return 'Hạ ${c.boss}';
    if (c.miniShield == id) return 'Hạ ${c.miniBoss}';
  }
  return '';
}

class DrawScreen extends StatefulWidget {
  const DrawScreen({super.key, required this.from, required this.initialMode});
  final DrawFrom from;
  final DrawMode initialMode;

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  late DrawMode mode = widget.initialMode;
  late Strokes w;
  late Strokes s;
  Stroke? _drawing;
  int? _pointer;
  int _flash = 0;
  String? _warn;
  late WeaponStats eW;
  late ShieldStats eS;
  double _dK = 1;
  late final GameController g = AppScope.read(context);

  bool get weapon => mode == DrawMode.weapon;
  bool get first => widget.from == DrawFrom.first;
  Strokes get cur => weapon ? w : s;
  P get origin => weapon ? P(feet.x + hand0.x, feet.y + hand0.y) : P(feet.x + shRaised.x, feet.y + shRaised.y);
  double get inkLeft => inkMax - inkOf(w) - inkOf(s);

  @override
  void initState() {
    super.initState();
    w = cloneSt(g.save.w);
    s = cloneSt(g.save.s);
    _recalc();
  }

  void _recalc() {
    eW = boostW(weaponStats(w), g.save.pts, inkFxOf(g.save.eq[Slot.inkW] ?? sameInk));
    eS = boostS(shieldStats(s), g.save.pts);
  }

  void _changed() => setState(_recalc);

  void _flashInk() => _flash++;

  P _toLocal(Offset pos) => P(pos.dx / _dK - origin.x, pos.dy / _dK - origin.y);
  bool _inZone(P p) => weapon || hypot(p.x, p.y) <= shZone;

  void _begin(P p) {
    if (inkLeft < 1) {
      _flashInk();
      _drawing = null;
      return;
    }
    if (!_inZone(p)) {
      _drawing = null;
      return;
    }
    _drawing = [p.x, p.y];
    cur.add(_drawing!);
    _warn = null;
    _changed();
  }

  void _move(P p) {
    if (!_inZone(p)) {
      _drawing = null;
      return;
    }
    final d0 = _drawing;
    if (d0 == null) {
      _begin(p);
      return;
    }
    final lx = d0[d0.length - 2], ly = d0[d0.length - 1];
    final d = hypot(p.x - lx, p.y - ly);
    if (d < 2.5) return;
    final left = inkLeft;
    if (left <= 0.5) {
      _drawing = null;
      _flashInk();
      setState(() {});
      return;
    }
    if (d > left) {
      final k = left / d;
      d0.addAll([lx + (p.x - lx) * k, ly + (p.y - ly) * k]);
      _drawing = null;
      _flashInk();
      _changed();
      return;
    }
    d0.addAll([p.x, p.y]);
    _changed();
  }

  void _setMode(DrawMode m) => setState(() {
        mode = m;
        _warn = null;
      });

  void _done() {
    final nav = NavScope.read(context);
    if (weaponStats(w).ink < 20) {
      setState(() {
        mode = DrawMode.weapon;
        _warn = 'Vũ khí còn ngắn quá, vẽ thêm chút nữa.';
      });
      return;
    }
    if (first && weapon) {
      _setMode(DrawMode.shield);
      return;
    }
    g.saveGear(w, s);
    if (first) {
      nav.openStage(g.save.stage + 1);
    } else if (widget.from == DrawFrom.pre) {
      nav.go(Scr.pre);
    } else {
      nav.home();
    }
  }

  void _back() {
    final nav = NavScope.read(context);
    if (first && !weapon) {
      _setMode(DrawMode.weapon);
    } else if (widget.from == DrawFrom.pre) {
      nav.go(Scr.pre);
    } else {
      nav.home();
    }
  }

  Future<void> _pickBlueprint() async {
    final kind = weapon ? GearKind.weapon : GearKind.shield;
    final look = lookFor(g.save.eq);
    final picked = await showModalBottomSheet<GearTemplate>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.62,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(weapon ? 'Mẫu vũ khí' : 'Mẫu khiên', style: T.display(21)),
              Text('Chọn mẫu để vẽ sẵn vào khung rồi sửa tiếp. Hạ trùm để mở thêm mẫu.', style: T.body(15)),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.85,
                  children: [
                    for (final t in blueprintTemplates(kind))
                      _BlueprintTile(
                        t: t,
                        unlocked: g.save.blueprints.contains(t.id),
                        color: rgb(weapon ? look.weaponInk.color : look.shieldInk),
                        onTap: () => Navigator.pop(ctx, t),
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final other = weapon ? s : w;
    final st = stampBlueprint(picked, inkMax - inkOf(other));
    setState(() {
      if (weapon) {
        w = st;
      } else {
        s = st;
      }
      _drawing = null;
      _recalc();
    });
  }

  String _blockHint(ShieldStats sh, OppSpec o) {
    if (!sh.has) return '';
    final tc = o.w.windup * botWindMul(o.aiL) + o.w.strike * 0.45, rs = sh.raise;
    return rs + 0.25 <= tc
        ? ' Khiên giơ hẳn mất ${rs.toStringAsFixed(2)} s, đòn của nó tới sau ${tc.toStringAsFixed(2)} s: thấy vung mới đỡ vẫn kịp.'
        : ' Khiên giơ hẳn mất ${rs.toStringAsFixed(2)} s, đòn của nó tới sau ${tc.toStringAsFixed(2)} s: phải giơ sẵn hoặc lùi né.';
  }

  String? _matchup(OppSpec? o) {
    if (weapon || widget.from != DrawFrom.pre || o == null) return null;
    final bAtk = o.w.atk.round(), def = eS.def.round();
    final diff = (bAtk - def).abs() * kBlock;
    final String text;
    if (!eS.has) {
      text = 'Chưa có khiên: đòn công $bAtk của ${o.name} trúng là văng.';
    } else if (def > bAtk + 4) {
      text = 'Thủ $def > công $bAtk của ${o.name}: bạn đỡ thì đứng vững, nó bị dội lại ${(diff / toughness(o.pts)).round()} px.';
    } else if (def < bAtk - 4) {
      text = 'Thủ $def < công $bAtk của ${o.name}: mỗi lần đỡ bạn vẫn bị ép lùi ${(diff / toughness(g.save.pts)).round()} px.';
    } else {
      text = 'Thủ $def ngang công $bAtk của ${o.name}: đỡ thì cả hai đứng yên.';
    }
    return text + _blockHint(eS, o);
  }

  @override
  Widget build(BuildContext context) {
    final nav = NavScope.of(context);
    final o = nav.opp;
    final pts = g.save.pts;
    final ok = eW.ink > 0;
    final gw = gearWalk(eW, eS) * mulWalk(pts);
    final items = weapon
        ? [
            StatItem('Tấn công', ok ? '${eW.atk.round()}' : '-', eW.atk / 600),
            StatItem('Thi triển', ok ? '${eW.cast.toStringAsFixed(2)} s' : '-', ok ? (1.5 - eW.cast) / 1.3 : 0),
            StatItem('Tầm đánh', ok ? '${eW.reach.round()} · ${eW.cls}' : '-', eW.reach / 300),
            StatItem('Dài × rộng', ok ? '${eW.len.round()} × ${eW.wid.round()}' : '-', (eW.len + eW.wid) / 420),
          ]
        : [
            StatItem('Phòng thủ', eS.has ? '${eS.def.round()}' : '-', eS.def / 600),
            StatItem('Giơ khiên', eS.has ? '${(eS.raise * 1000).round()} ms' : '-', eS.has ? 1 - (eS.raise - 0.08) / 0.6 : 0),
            StatItem('Độ phủ', '${(eS.coverage * 100).round()}%', eS.coverage),
            StatItem('Cao × rộng', eS.has ? '${eS.h.round()} × ${eS.w.round()}' : '-', (eS.h + eS.w) / 320),
          ];
    items.add(StatItem(
        'Đi lại',
        ok ? '×${gw.toStringAsFixed(2)} · vũ khí ×${walkW(eW).toStringAsFixed(2)}, khiên ×${walkS(eS).toStringAsFixed(2)}' : '-',
        (gw - 0.5) / 0.75,
        wide: true));
    final boosted = pts.total > 0;
    final matchup = _matchup(o);
    final tip = _warn ??
        (weapon
            ? 'Đặt bút từ bàn tay. Mực càng nhiều thì công càng cao. Càng dài thì với càng xa, nhưng ra đòn chậm hơn và đi lại cũng chậm hơn.'
            : 'Vẽ trong vòng nét đứt quanh tay khiên. Mực càng nhiều thì thủ càng cao. Khiên càng cao thì giơ càng chậm, đi lại càng chậm, và chỉ chặn được khi đã giơ hẳn lên.');
    final left = math.max(0.0, inkLeft);
    final reserved = weapon ? inkOf(s) : inkOf(w);
    return ScreenFrame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ScreenHeader(
          title: first ? (weapon ? 'Vẽ vũ khí' : 'Vẽ khiên') : 'Sửa đồ',
          onBack: _back,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (!first)
              Segmented<DrawMode>(
                options: const {DrawMode.weapon: 'Vũ khí', DrawMode.shield: 'Khiên'},
                value: mode,
                onChanged: _setMode,
              ),
            const SizedBox(width: 6),
            SketchButton(label: 'Mẫu', compact: true, onTap: _pickBlueprint),
          ]),
        ),
        Text(tip, style: T.body(15, _warn != null ? Pal.red : Pal.pencil)),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final side = math.min(c.maxWidth, math.min(440.0, c.maxHeight));
            _dK = side / drawW;
            return Center(
              child: SizedBox(
                width: side,
                height: side,
                child: Stack(children: [
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) {
                        if (_pointer != null) return;
                        _pointer = e.pointer;
                        _begin(_toLocal(e.localPosition));
                      },
                      onPointerMove: (e) {
                        if (e.pointer == _pointer) _move(_toLocal(e.localPosition));
                      },
                      onPointerUp: (e) {
                        if (e.pointer != _pointer) return;
                        _pointer = null;
                        _drawing = null;
                        _changed();
                      },
                      onPointerCancel: (e) {
                        if (e.pointer != _pointer) return;
                        _pointer = null;
                        _drawing = null;
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.4),
                          borderRadius: cardRadius,
                          border: Border.all(color: const Color(0x59474B55), width: 2),
                        ),
                        child: CustomPaint(
                          painter: _EditorPainter(w: w, s: s, weapon: weapon, look: lookFor(g.save.eq), eW: eW, dK: _dK),
                        ),
                      ),
                    ),
                  ),
                  if (!weapon && widget.from == DrawFrom.pre && o != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      width: 96,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xEBFFFDF7),
                          border: Border.all(color: Pal.red, width: 1.5),
                          borderRadius: sketchRadius,
                        ),
                        child: Column(children: [
                          SizedBox(
                            width: 86,
                            height: 86,
                            child: CustomPaint(
                              painter: _ThumbPainter(
                                Fighter(look: lookFor(o.eq, versus: g.save.eq), wStrokes: o.wStrokes),
                                gearBox([o.wStrokes]),
                                true,
                              ),
                            ),
                          ),
                          Text('${o.name}: công ${o.w.atk.round()}',
                              textAlign: TextAlign.center, style: T.body(13, Pal.red), maxLines: 2),
                        ]),
                      ),
                    ),
                ]),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        InkTube(left: left / inkMax, reserved: reserved / inkMax, label: 'còn ${left.round()}', flash: _flash),
        const SizedBox(height: 6),
        StatGrid(items: items),
        if (boosted)
          Text(
            'Đã tính điểm nâng cấp: công ×${mulAtk(pts).toStringAsFixed(2)}, thủ ×${mulDef(pts).toStringAsFixed(2)}, thời gian ×${mulTime(pts).toStringAsFixed(2)}.',
            style: T.body(14),
          ),
        if (matchup != null)
          Text(matchup, style: T.body(15, !eS.has || eS.def < (o?.w.atk ?? 0) - 4 ? Pal.red : Pal.pencil)),
        const SizedBox(height: 6),
        Row(children: [
          SketchButton(
            label: 'Hoàn tác',
            onTap: cur.isEmpty
                ? null
                : () {
                    cur.removeLast();
                    _drawing = null;
                    _changed();
                  },
          ),
          const SizedBox(width: 8),
          SketchButton(
            label: 'Xóa hết',
            onTap: cur.isEmpty
                ? null
                : () {
                    cur.clear();
                    _drawing = null;
                    _changed();
                  },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SketchButton(
              label: first ? (weapon ? 'Tiếp: vẽ khiên' : 'Xong, vào màn ${g.save.stage + 1}') : 'Lưu đồ',
              primary: true,
              onTap: _done,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _BlueprintTile extends StatelessWidget {
  const _BlueprintTile({required this.t, required this.unlocked, required this.color, required this.onTap});
  final GearTemplate t;
  final bool unlocked;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: unlocked ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: unlocked ? const Color(0xFFFFFDF7) : const Color(0x14474B55),
            border: Border.all(color: unlocked ? Pal.ink : const Color(0x66474B55), width: 2),
            borderRadius: sketchRadius,
          ),
          child: Column(children: [
            Expanded(
              child: unlocked
                  ? CustomPaint(painter: _StrokesPainter(t.strokes, color), size: Size.infinite)
                  : Center(child: Text('?', style: T.display(30, const Color(0x66474B55)))),
            ),
            Text(t.name, textAlign: TextAlign.center, style: T.display(13), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (!unlocked) Text(unlockHint(t.id), textAlign: TextAlign.center, style: T.body(11), maxLines: 2),
          ]),
        ),
      );
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter(this.st, this.color);
  final Strokes st;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => paintStrokesFit(canvas, size, st, color);

  @override
  bool shouldRepaint(covariant _StrokesPainter old) => old.st != st || old.color != color;
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.f, this.box, this.mirror);
  final Fighter f;
  final List<double> box;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) => paintThumb(canvas, size, f, box, mirror: mirror);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _EditorPainter extends CustomPainter {
  _EditorPainter({required this.w, required this.s, required this.weapon, required this.look, required this.eW, required this.dK});
  final Strokes w, s;
  final bool weapon;
  final Look look;
  final WeaponStats eW;
  final double dK;

  void _label(Canvas c, String text, double x, double y, Color col, {double size = 14, bool right = false, bool center = false}) {
    final tp = textPainter(text, size, col);
    final dx = center
        ? x - tp.width / 2
        : right
            ? x - tp.width
            : x;
    tp.paint(c, Offset(dx, y - tp.height / 2));
  }

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(dK, dK);
    final o = weapon ? P(feet.x + hand0.x, feet.y + hand0.y) : P(feet.x + shRaised.x, feet.y + shRaised.y);
    line(c, 8, feet.y + 1.5, drawW - 8, feet.y + 1.5, const Color(0x80474B55), 2);
    if (!weapon) dashedCircle(c, o.x, o.y, shZone, withAlpha(Pal.ink, 0.35), 1.5, 3, 7);
    final cur = weapon ? w : s;
    if (cur.isEmpty) {
      const hint = Color(0x66474B55);
      if (weapon) {
        dashedLine(c, o.x, o.y + 10, o.x + 4, o.y - 120, hint, 3, 5, 7);
        dashedLine(c, o.x - 18, o.y - 10, o.x + 20, o.y - 13, hint, 3, 5, 7);
        _label(c, 'ví dụ: thanh kiếm', o.x + 14, o.y - 100, const Color(0x99474B55), size: 15);
      } else {
        dashedCircle(c, o.x + 10, o.y - 4, 40, hint, 3, 5, 7);
        _label(c, 'ví dụ: khiên tròn', o.x + 54, o.y - 40, const Color(0x99474B55), size: 15);
      }
    }
    c.save();
    c.translate(feet.x, feet.y);
    final f = Fighter(look: look, wStrokes: w, sStrokes: s)..r = weapon ? 0 : 1;
    paintFighter(c, f, 0, editing: true);
    c.restore();
    dashedCircle(c, o.x, o.y, 10, Pal.red, 1.8, 3, 4);
    _label(c, weapon ? 'tay cầm' : 'tay khiên', o.x + 14, o.y + 20, Pal.red);
    if (weapon && eW.ink > 0) {
      final x = math.min(drawW - 6, feet.x + eW.reach);
      dashedLine(c, x, feet.y - 118, x, feet.y, Pal.red, 2, 6, 5);
      _label(c, 'tầm đánh${feet.x + eW.reach > drawW ? ' →' : ''} (${eW.cls})', x, feet.y - 126, Pal.red,
          right: x > drawW - 80, center: x <= drawW - 80);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
