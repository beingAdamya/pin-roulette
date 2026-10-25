import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

class WheelGame extends StatefulWidget {
  const WheelGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<WheelGame> createState() => _WheelGameState();
}

class _WheelGameState extends State<WheelGame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late List<String> _names;
  double _rot = 0;
  double _from = 0;
  double _to = 0;
  int _lastIdx = -1;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _names = widget.args.pool;
    _c = AnimationController(vsync: this)..addListener(_onFrame);
  }

  @override
  void didUpdateWidget(WheelGame old) {
    super.didUpdateWidget(old);
    if (!_spinning) _names = widget.args.pool;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int _indexAt(double rot) {
    final n = _names.length;
    final seg = 2 * pi / n;
    final a = (-rot) % (2 * pi);
    return (a / seg).floor().clamp(0, n - 1);
  }

  void _onFrame() {
    final t = Curves.easeOutQuart.transform(_c.value);
    setState(() => _rot = _from + (_to - _from) * t);
    final idx = _indexAt(_rot);
    if (idx != _lastIdx) {
      _lastIdx = idx;
      tick(widget.args.haptics);
    }
  }

  Future<void> _spin() async {
    final names = widget.args.startRound();
    if (names.length < 2) return;
    setState(() {
      _names = names;
      _spinning = true;
    });
    final n = names.length;
    final seg = 2 * pi / n;
    final win = rng.nextInt(n);
    final jitter = (rng.nextDouble() * 0.7 - 0.35) * seg;
    final target = -((win + 0.5) * seg + jitter);
    _from = _rot;
    _to = target +
        2 * pi * ((_from - target) / (2 * pi)).ceil() +
        2 * pi * widget.args.i('turns');
    _c.duration =
        Duration(milliseconds: (widget.args.d('seconds') * 1000).round());
    await _c.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _rot = _to % (2 * pi);
      _spinning = false;
    });
    widget.args.onPick(names[win]);
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Felt.palettes[widget.args.i('palette').clamp(0, Felt.palettes.length - 1)];
    return LayoutBuilder(builder: (context, box) {
      final size = min(box.maxWidth, 340.0);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _WheelPainter(
                        _names, _rot, palette, widget.args.b('labels')),
                  ),
                ),
                Positioned(
                  top: -8,
                  left: size / 2 - 15,
                  child: const CustomPaint(
                      size: Size(30, 30), painter: _PointerPainter()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GoButton(label: 'Spin', onPressed: _spinning ? null : _spin),
          const SizedBox(height: 10),
          Text('${_names.length} places on the wheel', style: stageHint),
        ],
      );
    });
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.names, this.rot, this.colors, this.labels);

  final List<String> names;
  final double rot;
  final List<Color> colors;
  final bool labels;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final n = names.length;
    if (n == 0) return;
    final seg = 2 * pi / n;
    final rect = Rect.fromCircle(center: center, radius: r * 0.96);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..color = Felt.ink
      ..strokeWidth = size.width / 220;

    for (var i = 0; i < n; i++) {
      var color = colors[i % colors.length];
      // Avoid two neighbours of the same colour where the wheel wraps round.
      if (n > 1 && n % colors.length == 1 && i == n - 1) {
        color = colors[1 % colors.length];
      }
      final start = -pi / 2 + i * seg + rot;
      canvas.drawArc(rect, start, seg, true, Paint()..color = color);
      canvas.drawArc(rect, start, seg, true, edge);

      if (labels) {
        canvas.save();
        canvas.translate(r, r);
        canvas.rotate(start + seg / 2);
        final fontSize = min(size.width / 22, max(size.width / 40, seg * r * 0.38));
        final tp = TextPainter(
          text: TextSpan(
            text: names[i],
            style: TextStyle(
              color: color.computeLuminance() > 0.5 ? Felt.text : Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: r * 0.68);
        tp.paint(canvas, Offset(r * 0.88 - tp.width, -tp.height / 2));
        canvas.restore();
      }
    }

    canvas.drawCircle(
        center,
        r * 0.96,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width / 60
          ..color = Felt.ink);
    canvas.drawCircle(center, r * 0.1, Paint()..color = Felt.ink);
    canvas.drawCircle(center, r * 0.05, Paint()..color = Felt.coral);
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.rot != rot ||
      old.names != names ||
      old.colors != colors ||
      old.labels != labels;
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height * 0.92)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = Felt.gold);
  }

  @override
  bool shouldRepaint(_PointerPainter old) => false;
}
