import 'package:flutter/material.dart';

import '../../monetize/cloud_service.dart';
import '../../render/palette.dart';
import '../../state/cloud_sync.dart';
import '../../state/game_controller.dart';
import '../theme.dart';
import '../widgets.dart';

/// Links a Google account and returns a message for the player, or null if they cancelled.
Future<String?> linkGoogleAccount(BuildContext context) async {
  final sync = CloudScope.read(context), g = AppScope.read(context);
  return switch (await sync.linkGoogle()) {
    LinkedSame() => 'Đã liên kết Google. Cài lại hay đổi máy, liên kết lại tài khoản này là có tiến trình.',
    LinkedSwitched() =>
      sync.synced
          ? 'Tài khoản Google này đã có tiến trình nên đã chuyển sang và gộp với máy này: '
                'màn ${g.save.stage}, cấp ${g.save.lvl}.'
          : 'Đã chuyển sang tài khoản Google này. Game sẽ gộp tiến trình khi có mạng.',
    LinkCancelled() => null,
    LinkFailed(:final message) => message,
  };
}

/// "Lưu trên mây" in the settings sheet. Empty when this build has no cloud save.
class CloudPanel extends StatefulWidget {
  const CloudPanel({super.key});

  @override
  State<CloudPanel> createState() => _CloudPanelState();
}

enum _Action { link, delete }

class _CloudPanelState extends State<CloudPanel> {
  String? _msg;
  _Action? _busy;

  Future<void> _run(_Action action, Future<String?> Function() run) async {
    setState(() => _busy = action);
    try {
      final msg = await run();
      if (mounted && msg != null) setState(() => _msg = msg);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<String?> _delete() async {
    final sync = CloudScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xoá tài khoản và dữ liệu trên mây?', style: T.display(19)),
        content: Text(
          'Bản lưu trên mây và tài khoản (cả liên kết Google) sẽ bị xoá. Tiến trình trên máy này vẫn còn '
          'và được sao lưu dưới một tài khoản ẩn danh mới. Muốn xoá cả tiến trình trên máy, dùng "Xoá tiến trình".',
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
    if (ok != true) return null;
    return switch (await sync.deleteAccount()) {
      DeleteResult.deleted => 'Đã xoá tài khoản và dữ liệu trên mây.',
      DeleteResult.cancelled => null,
      DeleteResult.failed => 'Chưa xoá được. Kiểm tra mạng rồi thử lại.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final sync = CloudScope.of(context);
    if (!sync.enabled) return const SizedBox.shrink();
    final String status;
    if (!sync.synced) {
      status = 'Chưa kết nối được máy chủ. Tiến trình vẫn lưu trên máy này và sẽ lên mây khi có mạng.';
    } else if (sync.linked) {
      final name = sync.accountName;
      status = 'Đã liên kết Google${name == null ? '' : ' ($name)'}. Tiến trình được lưu trên mây.';
    } else {
      status = sync.canLink
          ? 'Tiến trình đang được sao lưu ẩn danh. Liên kết Google để giữ khi cài lại app hoặc đổi máy.'
          : 'Tiến trình đang được sao lưu ẩn danh trên mây.';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Lưu trên mây', style: T.display(18)),
        Text(status, style: T.body(15)),
        const SizedBox(height: 6),
        if (sync.canLink && !sync.linked) ...[
          SketchButton(
            label: _busy == _Action.link ? 'Đang liên kết…' : 'Liên kết Google',
            primary: true,
            onTap: _busy != null ? null : () => _run(_Action.link, () => linkGoogleAccount(context)),
          ),
          const SizedBox(height: 8),
        ],
        if (_msg != null) ...[Text(_msg!, style: T.body(15, Pal.ink)), const SizedBox(height: 8)],
        SketchButton(
          label: _busy == _Action.delete ? 'Đang xoá…' : 'Xoá tài khoản và dữ liệu trên mây',
          color: Pal.red,
          onTap: _busy != null || sync.cloud.uid == null ? null : () => _run(_Action.delete, _delete),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
