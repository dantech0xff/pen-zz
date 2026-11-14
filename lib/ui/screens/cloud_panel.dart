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
      'Tài khoản Google này đã có tiến trình nên đã chuyển sang và gộp với máy này: '
          'màn ${g.save.stage}, cấp ${g.save.lvl}.',
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

class _CloudPanelState extends State<CloudPanel> {
  String? _msg;
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    try {
      final msg = await action();
      if (mounted && msg != null) setState(() => _msg = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
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
    return await sync.deleteAccount()
        ? 'Đã xoá tài khoản và dữ liệu trên mây.'
        : 'Chưa xoá được. Kiểm tra mạng rồi thử lại.';
  }

  @override
  Widget build(BuildContext context) {
    final sync = CloudScope.of(context);
    if (!sync.enabled) return const SizedBox.shrink();
    final status = !sync.synced
        ? 'Chưa kết nối được máy chủ. Tiến trình vẫn lưu trên máy này và sẽ lên mây khi có mạng.'
        : sync.linked
        ? 'Đã liên kết Google${sync.accountName == null ? '' : ' (${sync.accountName})'}. Tiến trình được lưu trên mây.'
        : 'Tiến trình đang được sao lưu ẩn danh. Liên kết Google để giữ khi cài lại app hoặc đổi máy.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Lưu trên mây', style: T.display(18)),
        Text(status, style: T.body(15)),
        const SizedBox(height: 6),
        if (!sync.linked) ...[
          SketchButton(
            label: _busy ? 'Đang liên kết…' : 'Liên kết Google',
            primary: true,
            onTap: _busy ? null : () => _run(() => linkGoogleAccount(context)),
          ),
          const SizedBox(height: 8),
        ],
        if (_msg != null) ...[Text(_msg!, style: T.body(15, Pal.ink)), const SizedBox(height: 8)],
        SketchButton(
          label: 'Xoá tài khoản và dữ liệu trên mây',
          color: Pal.red,
          onTap: _busy || sync.cloud.uid == null ? null : () => _run(_delete),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
