import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/battle/ai.dart';
import '../../core/battle/fighter.dart';
import '../../core/bots.dart';
import '../../core/catalog.dart';
import '../../core/gear.dart';
import '../../core/ink_fx.dart';
import '../../core/levels.dart';
import '../../render/fighter_painter.dart';
import '../../render/palette.dart';
import '../../state/game_controller.dart';
import '../theme.dart';
import '../widgets.dart';

String statLines(WeaponStats w, ShieldStats? s, Points pts) =>
    'Công ${w.atk.round()}\nTầm ${w.reach.round()} (${w.cls})\nThi triển ${w.cast.toStringAsFixed(2)} s\n'
    'Đi lại ×${(gearWalk(w, s) * mulWalk(pts)).toStringAsFixed(2)}';

class PreMatchScreen extends StatelessWidget {
  const PreMatchScreen({super.key});

  String _blockHint(ShieldStats ps, OppSpec o) {
    if (!ps.has) return '';
    final tc = o.w.windup * botWindMul(o.aiL) + o.w.strike * 0.45, rs = ps.raise;
    return rs + 0.25 <= tc
        ? ' Khiên của bạn giơ hẳn mất ${rs.toStringAsFixed(2)} s, đòn của nó tới sau ${tc.toStringAsFixed(2)} s: thấy vung mới đỡ vẫn kịp.'
        : ' Khiên của bạn giơ hẳn mất ${rs.toStringAsFixed(2)} s, đòn của nó tới sau ${tc.toStringAsFixed(2)} s: phải giơ sẵn hoặc lùi né.';
  }

  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context), nav = NavScope.of(context);
    final o = nav.opp;
    if (o == null) return const SizedBox();
    final s = g.save;
    final lv = o.kind == OppKind.stage ? LevelDef(o.stage) : null;
    final title = switch (o.kind) {
      OppKind.stage => 'Màn ${o.stage}',
      OppKind.ghost => 'Bóng ma của bạn',
      OppKind.practice => 'Luyện tập',
    };
    final ps = g.ps, pw = g.pw;
    final def = ps.def.round(), oAtk = o.w.atk.round();
    final push = ((oAtk - def).abs() * kBlock / toughness(s.pts)).round();
    final shieldTxt = !ps.has
        ? 'Bạn chưa có khiên.'
        : def > oAtk + 4
        ? 'Khiên của bạn thủ $def > công $oAtk: đỡ thì đứng vững.'
        : def < oAtk - 4
        ? 'Khiên của bạn thủ $def < công $oAtk: đỡ vẫn bị ép lùi $push px.'
        : 'Khiên của bạn thủ ngang công của đối thủ.';
    final fx = inkFxOf(o.eq[Slot.inkW] ?? sameInk);
    final fxTxt = fx == InkFx.none
        ? ''
        : ' Vũ khí của nó dùng mực ${inkFxSpec(fx).title.toLowerCase()}: ${inkFxSpec(fx).desc}';
    final note = switch (o.kind) {
      OppKind.stage =>
        '${o.name} cầm ${o.wName}, công $oAtk. $shieldTxt${_blockHint(ps, o)} Nó vẽ khiên sau khi thấy vũ khí của bạn.$fxTxt',
      OppKind.ghost => 'Bóng ma dùng đúng bộ đồ và điểm của bạn, máy điều khiển. Không tính màn.',
      OppKind.practice => 'Bot luyện tập, không tính màn. $shieldTxt${_blockHint(ps, o)}$fxTxt',
    };
    final String reward;
    if (lv != null) {
      final first = o.stage > s.stage;
      reward = first
          ? 'Thắng lần đầu: +${lv.coins} xu, +${lv.xp} kinh nghiệm'
          : 'Đánh lại: +${(lv.coins * 0.4).round()} xu, +${(lv.xp * 0.5).round()} kinh nghiệm';
    } else {
      reward = 'Thắng: +20 xu, +30 kinh nghiệm';
    }
    final myLook = lookFor(s.eq), opLook = lookFor(o.eq, versus: s.eq);
    final box = gearBox([s.w, o.wStrokes]);
    final bits = lv == null ? 0 : s.stars[o.stage - 1];
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            title: title,
            onBack: nav.back,
            badge: lv != null && o.boss ? const Pill('TRÙM', color: Pal.red, filled: true) : null,
            subtitle: lv?.chapter.name,
          ),
          Text('Sân ${nav.arena.name}: ${nav.arena.ruleText}', style: T.body(15, Pal.ink)),
          const SizedBox(height: 4),
          Text(note, style: T.body(15)),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _Card(
                    color: rgb(myLook.body),
                    name: 'Bạn',
                    level: s.lvl,
                    stats: statLines(pw, ps, s.pts),
                    painter: _Thumb(Fighter(look: myLook, wStrokes: s.w), box, false),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('vs', style: T.display(24, Pal.pencil)),
                ),
                Expanded(
                  child: _Card(
                    color: rgb(opLook.body),
                    name: o.name,
                    level: o.lvl,
                    stats: statLines(o.w, o.s, o.pts),
                    painter: _Thumb(Fighter(look: opLook, wStrokes: o.wStrokes), box, true),
                    rotate: 0.02,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(reward, textAlign: TextAlign.center, style: T.body(16)),
          if (lv != null) ...[
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              children: [
                _Goal('Thắng', bits & starWin != 0),
                _Goal('Thắng 2-0', bits & starFlawless != 0),
                _Goal(lv.goal.text, bits & starGoal != 0),
              ],
            ),
            if (lv.unlocks != null)
              Text(
                'Hạ trùm để mở mẫu ${lv.miniBoss ? 'khiên' : 'vũ khí'} của nó.',
                textAlign: TextAlign.center,
                style: T.body(14, Pal.ink),
              ),
          ],
          const SizedBox(height: 8),
          SketchButton(label: 'Vào trận', primary: true, big: true, onTap: nav.startBattle),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SketchButton(label: 'Sửa khiên', onTap: () => nav.openEditor(DrawMode.shield, DrawFrom.pre)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SketchButton(label: 'Sửa vũ khí', onTap: () => nav.openEditor(DrawMode.weapon, DrawFrom.pre)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Goal extends StatelessWidget {
  const _Goal(this.text, this.done);
  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      StarIcon(on: done, size: 16, offColor: Pal.pencil),
      const SizedBox(width: 2),
      Text(text, style: T.body(14, done ? const Color(0xFFB58500) : Pal.pencil)),
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({
    required this.color,
    required this.name,
    required this.level,
    required this.stats,
    required this.painter,
    this.rotate = 0,
  });
  final Color color;
  final String name, stats;
  final int level;
  final CustomPainter painter;
  final double rotate;

  @override
  Widget build(BuildContext context) => SketchCard(
    color: color,
    rotate: rotate,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The drawing gives up height first, so the name, level and stats always fit.
        Flexible(
          child: AspectRatio(
            aspectRatio: 1 / 1.15,
            child: CustomPaint(painter: painter),
          ),
        ),
        Text(name, textAlign: TextAlign.center, style: T.display(15, color), maxLines: 2),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Pill('Cấp $level', color: color),
        ),
        Text(stats, textAlign: TextAlign.center, style: T.body(14)),
      ],
    ),
  );
}

class _Thumb extends CustomPainter {
  _Thumb(this.f, this.box, this.mirror);
  final Fighter f;
  final List<double> box;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) => paintThumb(canvas, size, f, box, mirror: mirror);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
