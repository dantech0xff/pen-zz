import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/gear.dart';
import '../../core/levels.dart';
import '../../state/game_controller.dart';
import '../theme.dart';
import '../widgets.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context), nav = NavScope.of(context), s = g.save;
    final p = s.pts;
    final rows = [
      (Stat.pow, 'Sức mạnh', p.pow, 'công ×${mulAtk(p).toStringAsFixed(2)}', '+5% công mỗi điểm, giảm dần sau 20 điểm'),
      (Stat.def, 'Phòng thủ', p.def, 'thủ ×${mulDef(p).toStringAsFixed(2)}', '+5% thủ mỗi điểm, giảm dần sau 20 điểm'),
      (
        Stat.spd,
        'Tốc độ',
        p.spd,
        'thời gian ×${mulTime(p).toStringAsFixed(2)} · chạy ×${mulWalk(p).toStringAsFixed(2)}',
        'ra đòn, giơ khiên nhanh hơn',
      ),
    ];
    return ScreenFrame(
      scroll: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ScreenHeader(title: 'Nâng cấp', onBack: nav.home),
              ),
              CoinChip(coins: s.coins),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s.free > 0
                ? 'Bạn có ${s.free} điểm để cộng. Mỗi lần lên cấp được thêm 3 điểm.'
                : 'Hết điểm. Còn ${xpNeed(s.lvl) - s.xp} kinh nghiệm nữa lên cấp ${s.lvl + 1}, được thêm 3 điểm.',
            style: T.body(16),
          ),
          const SizedBox(height: 8),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SketchCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r.$2} · ${r.$3} điểm', style: T.display(18)),
                          Text('${r.$4} (${r.$5})', style: T.body(14)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: SketchButton(
                        label: '+1',
                        primary: true,
                        onTap: s.free > 0 ? () => g.addPoint(r.$1) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x80474B55), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Bộ đồ hiện tại sau khi cộng điểm: công ${g.pw.atk.round()} · thủ ${g.ps.def.round()} · '
              'thi triển ${g.pw.cast.toStringAsFixed(2)} s · giơ khiên ${(g.ps.raise * 1000).round()} ms. '
              'Độ lì ×${toughness(p).toStringAsFixed(2)}: cấp càng cao càng khó bị đánh văng.',
              style: T.body(15),
            ),
          ),
          const SizedBox(height: 10),
          SketchButton(
            label: 'Tẩy điểm để cộng lại (${GameController.respecCost} xu)',
            onTap: p.total > 0 && s.coins >= GameController.respecCost ? g.respec : null,
          ),
        ],
      ),
    );
  }
}
