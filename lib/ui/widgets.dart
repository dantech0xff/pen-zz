import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/sfx.dart';
import '../render/palette.dart';
import 'theme.dart';

/// Notebook paper: grid, fine lines and the red margin, like the web page background.
class PaperPainter extends CustomPainter {
  const PaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Pal.paper);
    final fine = Paint()
      ..color = const Color(0x80D3DBF1)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), fine);
    }
    final grid = Paint()
      ..color = Pal.grid
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    canvas.drawRect(const Rect.fromLTWH(26, 0, 2, 100000), Paint()..color = Pal.margin);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: const PaperPainter(), child: child);
}

/// Pen-drawn button. Primary is filled with ink; tiles show a title and a hint line.
class SketchButton extends StatefulWidget {
  const SketchButton({
    super.key,
    required this.label,
    this.onTap,
    this.primary = false,
    this.big = false,
    this.subtitle,
    this.alert = false,
    this.color,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary, big, alert, compact;
  final String? subtitle;
  final Color? color;

  @override
  State<SketchButton> createState() => _SketchButtonState();
}

class _SketchButtonState extends State<SketchButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final ink = widget.color ?? (widget.primary ? Pal.ink : Pal.pencil);
    final fg = widget.primary ? Colors.white : ink;
    final pad = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
        : widget.big
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 9);
    Widget content = widget.subtitle == null
        ? Text(
            widget.label,
            textAlign: TextAlign.center,
            style: widget.big ? T.display(21, fg) : T.body(widget.compact ? 17 : 19, fg),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label, style: T.display(17, widget.primary ? Colors.white : Pal.ink)),
              Text(
                widget.subtitle!,
                style: T.body(13, fg.withValues(alpha: 0.85)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
    if (widget.alert) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          const Positioned(right: -4, top: 0, child: CircleAvatar(radius: 5.5, backgroundColor: Pal.red)),
        ],
      );
    }
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled
            ? () {
                Sfx.instance.play('tap', volume: 0.5);
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 60),
          child: Container(
            padding: pad,
            decoration: BoxDecoration(
              color: widget.primary ? ink : Colors.white.withValues(alpha: 0.6),
              border: Border.all(color: ink, width: 2),
              borderRadius: sketchRadius,
            ),
            alignment: widget.subtitle == null ? Alignment.center : Alignment.centerLeft,
            child: content,
          ),
        ),
      ),
    );
  }
}

class SketchCard extends StatelessWidget {
  const SketchCard({
    super.key,
    required this.child,
    this.color = Pal.ink,
    this.rotate = 0,
    this.padding = const EdgeInsets.all(10),
  });
  final Widget child;
  final Color color;
  final double rotate;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: rotate,
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xD9FFFDF7),
        border: Border.all(color: color, width: 2),
        borderRadius: cardRadius,
      ),
      child: child,
    ),
  );
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 15});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF9A7400), width: 1.5),
      gradient: const RadialGradient(
        center: Alignment(-0.3, -0.3),
        colors: [Color(0xFFFFF6C4), Pal.hl, Color(0xFFE0A800)],
        stops: [0.18, 0.58, 1],
      ),
    ),
  );
}

/// Coin counter that bumps when the amount changes.
class CoinChip extends StatefulWidget {
  const CoinChip({super.key, required this.coins});
  final int coins;

  @override
  State<CoinChip> createState() => _CoinChipState();
}

class _CoinChipState extends State<CoinChip> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void didUpdateWidget(CoinChip old) {
    super.didUpdateWidget(old);
    if (old.coins != widget.coins) _a.forward(from: 0);
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (context, child) => Transform.scale(
      scale: 1 + 0.2 * (1 - (_a.value - 0.4).abs() / 0.6).clamp(0, 1) * (_a.isAnimating ? 1 : 0),
      child: child,
    ),
    child: Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
        border: Border.all(color: Pal.pencil, width: 2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(),
          const SizedBox(width: 5),
          Text(fmtNum(widget.coins), style: T.body(17).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    ),
  );
}

String fmtNum(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

/// Thin bar with an ink fill, used for XP and stat bars.
class InkBar extends StatelessWidget {
  const InkBar({super.key, required this.value, this.height = 8, this.color = Pal.ink, this.border = true});
  final double value, height;
  final Color color;
  final bool border;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: border ? Colors.white : const Color(0x21474B55),
      border: border ? Border.all(color: color, width: 1.5) : null,
      borderRadius: BorderRadius.circular(6),
    ),
    clipBehavior: Clip.antiAlias,
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: value.clamp(0, 1).toDouble(),
      child: Container(color: color),
    ),
  );
}

/// Ink left for drawing; the striped part is reserved by the other piece of gear.
class InkTube extends StatefulWidget {
  const InkTube({super.key, required this.left, required this.reserved, required this.label, required this.flash});
  final double left, reserved;
  final String label;
  final int flash;

  @override
  State<InkTube> createState() => _InkTubeState();
}

class _InkTubeState extends State<InkTube> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

  @override
  void didUpdateWidget(InkTube old) {
    super.didUpdateWidget(old);
    if (old.flash != widget.flash) _a.forward(from: 0);
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text('Mực', style: T.body(16)),
      const SizedBox(width: 8),
      Expanded(
        child: AnimatedBuilder(
          animation: _a,
          builder: (context, child) => Transform.translate(
            offset: Offset(_a.isAnimating ? (4 * (1 - 2 * ((_a.value * 2) % 1))) : 0, 0),
            child: child,
          ),
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Pal.ink, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: c.maxWidth * widget.left.clamp(0, 1),
                    child: Container(color: Pal.ink),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: c.maxWidth * widget.reserved.clamp(0, 1),
                    child: CustomPaint(painter: _StripePainter()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 70,
        child: Text(widget.label, textAlign: TextAlign.right, style: T.body(16)),
      ),
    ],
  );
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x66474B55)
      ..strokeWidth = 3;
    for (var x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StatItem {
  const StatItem(this.label, this.value, this.bar, {this.wide = false});
  final String label, value;
  final double bar;
  final bool wide;
}

class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.items});
  final List<StatItem> items;

  @override
  Widget build(BuildContext context) {
    Widget cell(StatItem it) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(it.label, style: T.body(15))),
            Text(it.value, style: T.body(15).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
        const SizedBox(height: 2),
        InkBar(value: it.bar, height: 6, color: Pal.pencil, border: false),
      ],
    );
    final rows = <Widget>[];
    final narrow = items.where((i) => !i.wide).toList();
    for (var i = 0; i < narrow.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: cell(narrow[i])),
            const SizedBox(width: 16),
            Expanded(child: i + 1 < narrow.length ? cell(narrow[i + 1]) : const SizedBox()),
          ],
        ),
      );
    }
    for (final w in items.where((i) => i.wide)) {
      rows.add(cell(w));
    }
    return Column(
      children: [for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 6), child: r)],
    );
  }
}

class Segmented<V> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});
  final Map<V, String> options;
  final V value;
  final ValueChanged<V> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: Pal.ink, width: 2),
      borderRadius: BorderRadius.circular(10),
    ),
    clipBehavior: Clip.antiAlias,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in options.entries)
          GestureDetector(
            onTap: () {
              Sfx.instance.play('tap', volume: 0.4);
              onChanged(e.key);
            },
            child: Container(
              color: e.key == value ? Pal.ink : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(e.value, style: T.body(15, e.key == value ? Colors.white : Pal.ink)),
            ),
          ),
      ],
    ),
  );
}

/// Star drawn with the bundled Material icon font (the hand-drawn fonts have no star glyph).
class StarIcon extends StatelessWidget {
  const StarIcon({
    super.key,
    required this.on,
    this.size = 16,
    this.color = const Color(0xFFE0A800),
    this.offColor = const Color(0x40474B55),
  });
  final bool on;
  final double size;
  final Color color, offColor;

  @override
  Widget build(BuildContext context) =>
      Icon(on ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: on ? color : offColor);
}

class BackChip extends StatelessWidget {
  const BackChip({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SketchButton(label: '‹', compact: true, onTap: onTap);
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.onBack, this.trailing});
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: Row(
      children: [
        if (onBack != null) ...[BackChip(onTap: onBack!), const SizedBox(width: 8)],
        Expanded(
          child: Text(title, style: T.display(22), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Repaints every frame while mounted (hero, wardrobe preview); gives the painter elapsed seconds.
class Animated extends StatefulWidget {
  const Animated({super.key, required this.builder});
  final CustomPainter Function(double t, double dt) builder;

  @override
  State<Animated> createState() => _AnimatedState();
}

class _AnimatedState extends State<Animated> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0, _dt = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0, 0.05);
      _last = elapsed;
      _t += _dt;
      setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: widget.builder(_t, _dt), size: Size.infinite);
}

/// Wraps a screen: paper, safe area, phone-width column on tablets and the web.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({super.key, required this.child, this.scroll = false});
  final Widget child;
  final bool scroll;

  @override
  Widget build(BuildContext context) => PaperBackground(
    child: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(38, 8, 16, 12),
            child: scroll ? SingleChildScrollView(child: child) : child,
          ),
        ),
      ),
    ),
  );
}
