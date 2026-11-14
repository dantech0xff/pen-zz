import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../audio/sfx.dart';
import '../../core/battle/battle.dart';
import '../../core/bots.dart';
import '../../core/levels.dart';
import '../../game/battle_game.dart';
import '../../render/fighter_painter.dart';
import '../../render/palette.dart';
import '../../state/game_controller.dart';
import '../theme.dart';
import '../widgets.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late final GameController g = AppScope.read(context);
  late final Nav nav = NavScope.read(context);
  late final OppSpec o = nav.opp!;
  late final Battle battle;
  late final BattleGame game;
  MatchReward? _reward;
  bool _tip = false;

  @override
  void initState() {
    super.initState();
    battle = g.startBattle(o, nav.arena);
    game = BattleGame(battle: battle, arena: nav.arena, onMatchEnd: _onEnd);
    _tip = !g.save.tutorialDone;
    if (_tip) game.held.value = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    game.reduceMotion = MediaQuery.of(context).disableAnimations;
  }

  void _onEnd(bool won) {
    Future.microtask(() {
      if (!mounted) return;
      g.markTutorialDone();
      setState(() => _reward = g.finishMatch(o, won, battle.stats));
    });
  }

  void _pause() {
    if (_reward != null || battle.finished) return;
    game.held.value = true;
  }

  void _resume() => game.held.value = false;

  @override
  void dispose() {
    game.held.dispose();
    game.hud.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = battle.p, b = battle.b;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (_reward != null) {
          nav.home();
        } else if (game.held.value && !_tip) {
          _resume();
        } else {
          _pause();
        }
      },
      child: PaperBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(38, 6, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<HudState>(
                      valueListenable: game.hud,
                      builder: (context, h, _) => Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _Side(
                              name: 'Bạn',
                              pct: h.pctP,
                              wins: h.winsP,
                              of: battle.roundsToWin,
                              color: rgb(p.look.body),
                              ad: 'công ${p.w.atk.round()} · thủ ${p.s.def.round()}',
                              right: false,
                            ),
                          ),
                          Column(
                            children: [
                              IconButton(
                                tooltip: 'Tạm dừng',
                                onPressed: _pause,
                                icon: const Icon(Icons.pause_circle_outline, color: Pal.pencil),
                              ),
                              Text('Hiệp ${h.round}', style: T.body(14)),
                            ],
                          ),
                          Expanded(
                            child: _Side(
                              name: o.name,
                              pct: h.pctB,
                              wins: h.winsB,
                              of: battle.roundsToWin,
                              color: rgb(b.look.body),
                              ad: 'công ${b.w.atk.round()} · thủ ${b.s.def.round()}',
                              right: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: GameWidget(game: game, autofocus: true),
                            ),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: game.held,
                            builder: (context, held, _) =>
                                held && !_tip && _reward == null ? _pauseMenu() : const SizedBox(),
                          ),
                          if (_tip) _tutorial(),
                          if (_reward != null) _result(_reward!),
                        ],
                      ),
                    ),
                    Text(
                      'Vạch xanh: tầm của bạn, vạch đỏ: tầm đối thủ. % càng cao càng văng xa.${kIsWeb ? ' Phím A D đi, J đánh, K đỡ.' : ''}',
                      textAlign: TextAlign.center,
                      style: T.body(14),
                    ),
                    const SizedBox(height: 6),
                    ValueListenableBuilder<bool>(
                      valueListenable: game.held,
                      builder: (context, held, pads) => IgnorePointer(ignoring: held, child: pads),
                      child: ValueListenableBuilder<HudState>(
                        valueListenable: game.hud,
                        builder: (context, h, _) => Row(
                          children: [
                            Expanded(
                              flex: 78,
                              child: _Pad(
                                label: '',
                                icon: Icons.arrow_left_rounded,
                                sub: 'lùi',
                                move: true,
                                onDown: () => game.pad(back: true),
                                onUp: () => game.pad(back: false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 78,
                              child: _Pad(
                                label: '',
                                icon: Icons.arrow_right_rounded,
                                sub: 'tới',
                                move: true,
                                onDown: () => game.pad(fwd: true),
                                onUp: () => game.pad(fwd: false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 100,
                              child: _Pad(
                                label: 'ĐỠ',
                                sub: h.blockReady ? 'giữ để đỡ' : 'không khiên',
                                enabled: h.blockReady,
                                onDown: () => game.pad(block: true),
                                onUp: () => game.pad(block: false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 118,
                              child: _Pad(
                                label: 'ĐÁNH',
                                sub: 'chạm để vung',
                                attack: true,
                                ready: h.atkReady,
                                onDown: game.attack,
                                onUp: () {},
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(String title, List<Widget> body, List<Widget> buttons) => Container(
    color: const Color(0x80FBFAF3),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(12),
    child: SingleChildScrollView(
      child: Transform.rotate(
        angle: -0.017,
        child: Container(
          width: 330,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Pal.paper,
            border: Border.all(color: Pal.ink, width: 2.5),
            borderRadius: cardRadius,
            boxShadow: const [BoxShadow(color: Color(0x291D3AA8), offset: Offset(4, 5))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, textAlign: TextAlign.center, style: T.display(22)),
              const SizedBox(height: 8),
              ...body,
              const SizedBox(height: 10),
              for (final b in buttons) Padding(padding: const EdgeInsets.only(top: 8), child: b),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _pauseMenu() => _card(
    'Tạm dừng',
    [Text('Trận đang dừng. Vào lại khi bạn sẵn sàng.', textAlign: TextAlign.center, style: T.body(16))],
    [
      SketchButton(label: 'Tiếp tục', primary: true, onTap: _resume),
      SketchButton(label: 'Đấu lại từ đầu', onTap: nav.startBattle),
      SketchButton(
        label: 'Bỏ trận',
        onTap: () {
          o.resetShield();
          nav.go(Scr.pre);
        },
      ),
    ],
  );

  Widget _tutorial() => _card(
    'Cách chơi',
    [
      for (final line in const [
        'Hai nút mũi tên để lùi, tới. Vạch dưới chân là tầm đánh của bạn.',
        'ĐÁNH: chạm để vung. Vung khi vạch tầm chạm đối thủ.',
        'ĐỠ: giữ để giơ khiên. Khiên chỉ chặn khi đã giơ hẳn; giơ đúng lúc đòn tới là đỡ chuẩn.',
        'Trúng đòn cộng %, % càng cao càng văng xa. Đánh văng đối thủ khỏi sàn để thắng hiệp, thắng 2 hiệp là thắng trận.',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('• $line', style: T.body(16)),
        ),
    ],
    [
      SketchButton(
        label: 'Đã hiểu, vào trận',
        primary: true,
        onTap: () {
          setState(() => _tip = false);
          _resume();
        },
      ),
    ],
  );

  Widget _result(MatchReward r) {
    final st = battle.stats;
    final lv = o.kind == OppKind.stage ? LevelDef(o.stage) : null;
    final title = r.won ? (lv != null && lv.boss ? 'Hạ trùm rồi!' : 'Thắng!') : 'Thua rồi';
    final body = <Widget>[
      Text(
        'Tỉ số ${battle.winsP}-${battle.winsB} · trúng ${st.hits} đòn · chặn ${st.blocks} · đỡ chuẩn ${st.parries}',
        textAlign: TextAlign.center,
        style: T.body(16),
      ),
      const SizedBox(height: 4),
      Text('+${r.coins} xu · +${r.xp} kinh nghiệm', textAlign: TextAlign.center, style: T.body(19, Pal.ink)),
      if (lv != null && r.won) ...[
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final bit in [starWin, starFlawless, starGoal])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: StarIcon(
                  on: r.starBits & bit != 0,
                  size: 34,
                  color: r.newStarBits & bit != 0 ? const Color(0xFFE0A800) : const Color(0xFFB58500),
                  offColor: Pal.pencil,
                ),
              ),
          ],
        ),
        for (final (bit, label) in [(starFlawless, 'Thắng 2-0'), (starGoal, lv.goal.text)])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StarIcon(on: r.starBits & bit != 0, size: 15, offColor: Pal.pencil),
              const SizedBox(width: 3),
              Flexible(child: Text(label, style: T.body(14))),
            ],
          ),
      ],
      if (r.levelsGained > 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Lên cấp ${g.save.lvl}! +${3 * r.levelsGained} điểm nâng cấp',
            textAlign: TextAlign.center,
            style: T.display(19).copyWith(backgroundColor: Pal.hl),
          ),
        ),
      if (r.unlocked != null) ...[
        const SizedBox(height: 8),
        Text('Mở khoá mẫu: ${r.unlocked!.name}', textAlign: TextAlign.center, style: T.display(17)),
        SizedBox(height: 70, child: CustomPaint(painter: _Strokes(r.unlocked!.strokes))),
      ],
    ];
    final buttons = <Widget>[];
    if (lv != null) {
      if (r.won) {
        buttons.add(
          o.stage < levelCount
              ? SketchButton(label: 'Màn ${o.stage + 1}', primary: true, onTap: () => nav.openStage(o.stage + 1))
              : SketchButton(label: 'Đã qua cả 120 màn!', primary: true, onTap: nav.home),
        );
      } else {
        buttons.add(
          SketchButton(
            label: 'Đấu lại',
            primary: true,
            onTap: () {
              o.resetShield();
              nav.go(Scr.pre);
            },
          ),
        );
      }
    } else {
      buttons.add(SketchButton(label: 'Đấu lại', primary: true, onTap: nav.startBattle));
      buttons.add(SketchButton(label: 'Về luyện tập', onTap: () => nav.go(Scr.practice)));
    }
    if (g.save.free > 0) {
      buttons.add(SketchButton(label: 'Cộng ${g.save.free} điểm nâng cấp', onTap: () => nav.go(Scr.upgrade)));
    }
    if (!r.won) {
      buttons.add(
        SketchButton(
          label: 'Sửa đồ',
          onTap: () {
            o.resetShield();
            nav.openEditor(DrawMode.weapon, DrawFrom.pre);
          },
        ),
      );
    }
    buttons.add(SketchButton(label: 'Về sảnh', onTap: nav.home));
    return _card(title, body, buttons);
  }
}

class _Strokes extends CustomPainter {
  _Strokes(this.st);
  final List<List<double>> st;

  @override
  void paint(Canvas canvas, Size size) => paintStrokesFit(canvas, size, st, Pal.ink);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Side extends StatelessWidget {
  const _Side({
    required this.name,
    required this.pct,
    required this.wins,
    required this.of,
    required this.color,
    required this.ad,
    required this.right,
  });
  final String name, ad;
  final int pct, wins, of;
  final Color color;
  final bool right;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(name, style: T.body(15, color), maxLines: 1, overflow: TextOverflow.ellipsis),
      Text('$pct%', style: T.display(30, color).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
      Text(ad, style: T.body(13, color), maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < of; i++)
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < wins ? color : Colors.transparent,
                border: Border.all(color: color, width: 2),
              ),
            ),
        ],
      ),
    ],
  );
}

/// Touch pad. Uses raw pointer events so holding ĐỠ and the forward arrow at once works (multi-touch).
class _Pad extends StatefulWidget {
  const _Pad({
    required this.label,
    required this.sub,
    required this.onDown,
    required this.onUp,
    this.move = false,
    this.attack = false,
    this.ready = false,
    this.enabled = true,
    this.icon,
  });

  final String label, sub;
  final IconData? icon;
  final VoidCallback onDown, onUp;
  final bool move, attack, ready, enabled;

  @override
  State<_Pad> createState() => _PadState();
}

class _PadState extends State<_Pad> {
  final Set<int> _pointers = {};

  void _down(int id) {
    if (!widget.enabled) return;
    if (_pointers.isEmpty) {
      widget.onDown();
      if (widget.attack) Sfx.instance.play('tap', volume: 0.2);
    }
    setState(() => _pointers.add(id));
    if (widget.attack) {
      Future.delayed(const Duration(milliseconds: 110), () {
        if (mounted) setState(() => _pointers.remove(id));
      });
    }
  }

  void _up(int id) {
    if (!_pointers.contains(id) && !widget.attack) return;
    setState(() => _pointers.remove(id));
    if (_pointers.isEmpty) widget.onUp();
  }

  @override
  Widget build(BuildContext context) {
    final held = _pointers.isNotEmpty;
    final color = widget.move ? Pal.pencil : Pal.ink;
    return Opacity(
      opacity: widget.enabled ? 1 : 0.35,
      child: Listener(
        onPointerDown: (e) => _down(e.pointer),
        onPointerUp: (e) => _up(e.pointer),
        onPointerCancel: (e) => _up(e.pointer),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          height: 78,
          transform: held ? (Matrix4.identity()..translateByDouble(0, 2, 0, 1)) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: widget.attack ? Pal.hl : const Color(0xFFFFFDF7),
            border: Border.all(color: color, width: 3),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.elliptical(18, 12),
              topRight: Radius.elliptical(10, 20),
              bottomRight: Radius.elliptical(20, 10),
              bottomLeft: Radius.elliptical(12, 18),
            ),
            boxShadow: [
              if (widget.ready) const BoxShadow(color: Pal.hl, spreadRadius: 3),
              if (widget.ready) const BoxShadow(color: Pal.ink, spreadRadius: 5),
              if (held)
                const BoxShadow(color: Color(0x1F000000), offset: Offset(0, -2), blurRadius: 0, spreadRadius: -2),
            ],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null)
                Icon(widget.icon, size: 40, color: color)
              else
                Text(widget.label, style: T.display(22, color)),
              Text(
                widget.sub,
                style: T.body(13, color.withValues(alpha: 0.75)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
