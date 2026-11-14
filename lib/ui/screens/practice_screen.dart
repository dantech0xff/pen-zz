import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/arenas.dart';
import '../../core/bots.dart';
import '../../core/levels.dart';
import '../../render/palette.dart';
import '../../state/game_controller.dart';
import '../theme.dart';
import '../widgets.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  ArenaDef? _arena;

  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context), nav = NavScope.of(context), s = g.save;
    final open = [for (var c = 0; c < g.chaptersOpen; c++) chapters[c].arena];
    final arena = _arena ?? (open.contains(nav.arena) ? nav.arena : open.last);
    return ScreenFrame(
      scroll: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: ScreenHeader(title: 'Luyện tập', onBack: nav.home)),
          CoinChip(coins: s.coins),
        ]),
        Text('Luyện tập không tính màn. Thắng được 20 xu và 30 kinh nghiệm, thua được 5 xu và 10 kinh nghiệm.',
            style: T.body(16)),
        const SizedBox(height: 10),
        Text('Chọn sân (mở thêm khi tới quyển vở mới)', style: T.display(17)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in open)
            GestureDetector(
              onTap: () => setState(() => _arena = a),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: a == arena ? Pal.ink : const Color(0xFFFFFDF7),
                  border: Border.all(color: Pal.ink, width: 2),
                  borderRadius: sketchRadius,
                ),
                child: Text(a.name, style: T.body(16, a == arena ? Colors.white : Pal.ink)),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Text(arena.ruleText, style: T.body(15)),
        const SizedBox(height: 14),
        SketchButton(
          label: 'Đấu bot luyện tập',
          primary: true,
          big: true,
          onTap: () => nav.openOpponent(practiceOpponent(s.stage.clamp(1, levelCount)), arena),
        ),
        const SizedBox(height: 8),
        SketchButton(
          label: 'Đấu bóng ma của chính bạn',
          onTap: () => nav.openOpponent(ghostOpponent(w: s.w, s: s.s, lvl: s.lvl, pts: s.pts, eq: s.eq), arena),
        ),
        const SizedBox(height: 14),
        Text('Đã thắng ${s.wins} trận, thua ${s.losses} trận.', style: T.body(15)),
      ]),
    );
  }
}
