import 'package:flutter/material.dart';

import '../../app.dart';
import '../../render/palette.dart';
import '../../state/game_controller.dart';
import '../theme.dart';
import '../widgets.dart';

Future<void> showSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(context: context, builder: (ctx) => const _SettingsSheet());

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context);
    final s = g.save;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cài đặt', style: T.display(22)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Âm thanh', style: T.body(18)),
              value: s.sound,
              activeTrackColor: Pal.ink,
              onChanged: g.setSound,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Rung khi trúng đòn', style: T.body(18)),
              value: s.haptics,
              activeTrackColor: Pal.ink,
              onChanged: g.setHaptics,
            ),
            Text('Thắng ${s.wins} trận · thua ${s.losses} trận · qua ${s.stage}/120 màn', style: T.body(15)),
            const SizedBox(height: 12),
            SketchButton(
              label: 'Giấy phép phông chữ và thư viện',
              onTap: () => showLicensePage(context: context, applicationName: 'Bút Chiến'),
            ),
            const SizedBox(height: 8),
            SketchButton(
              label: 'Xoá tiến trình',
              color: Pal.red,
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Xoá toàn bộ tiến trình?', style: T.display(19)),
                    content: Text(
                      'Xu, cấp, đồ đã mua, màn đã qua và đồ đã vẽ sẽ mất hết. Không hoàn tác được.',
                      style: T.body(16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Thôi', style: T.body(17)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Xoá', style: T.body(17, Pal.red)),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await g.resetProgress();
                  if (!context.mounted) return;
                  NavScope.read(context).home();
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
