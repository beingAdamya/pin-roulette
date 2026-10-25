import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// Drops a ball through pegs into one of the places' slots. The slot is
/// chosen fairly first; the bounces are drawn to land there.
class PlinkoGame extends StatefulWidget {
  const PlinkoGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<PlinkoGame> createState() => _PlinkoGameState();
}

class _PlinkoGameState extends State<PlinkoGame>
    with SingleTickerProviderStateMixin {
  static const maxSlots = 12;

  GameArgs get a => widget.args;
  late final AnimationController _c;
  List<String> _slots = [];
  String _poolKey = '';
  List<Offset> _path = [];
  int? _hit;
  int _lastSeg = -1;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this)..addListener(_frame);
    _setSlots(a.pool);
  }

  @override
  void didUpdateWidget(covariant PlinkoGame old) {
    super.didUpdateWidget(old);
    if (!_running && _hit == null && a.pool.join('\u0000') != _poolKey) {
      _setSlots(a.pool);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _setSlots(List<String> pool) {
    _poolKey = pool.join('\u0000');
    _slots = pool.length <= maxSlots
        ? List<String>.of(pool)
        : shuffled(pool).take(maxSlots).toList();
  }

  void _frame() {
    setState(() {});
    final seg = (_c.value * (_path.length - 1)).floor();
    if (seg != _lastSeg) {
      _lastSeg = seg;
      if (seg > 0) a.tick();
    }
  }

  Future<void> _drop() async {
    final pool = a.startRound();
    if (pool.length < 2) return;
    if (pool.length > maxSlots || pool.join('\u0000') != _poolKey) {
      _setSlots(pool);
    }
    final n = _slots.length;
    final win = rng.nextInt(n);
    final rows = a.i('rows');
    final target = (win + 0.5) / n;
    var x = 0.5 + (rng.nextDouble() - 0.5) * 0.1;
    final pts = <Offset>[Offset(x, 0.02)];
    for (var j = 0; j < rows; j++) {
      final t = (j + 1) / (rows + 1);
      final want = x + (target - x) * (1 / (rows - j + 1));
      final jitter = (rng.nextBool() ? 1 : -1) * (0.5 / (rows + 2)) * rng.nextDouble();
      x = (want + jitter * (1 - t)).clamp(0.04, 0.96);
      pts.add(Offset(x, _rowY(j, rows) - 0.03));
    }
    pts.add(Offset(target, 0.9));
    setState(() {
      _path = pts;
      _hit = null;
      _running = true;
      _lastSeg = -1;
    });
    _c.duration = Duration(milliseconds: a.ms('seconds'));
    await _c.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _hit = win;
      _running = false;
    });
    a.onPick(_slots[win]);
  }

  static double _rowY(int j, int rows) => 0.1 + j * (0.7 / rows);

  Offset? _ball() {
    if (_path.length < 2 || (!_running && _hit == null)) return null;
    final v = _c.value * (_path.length - 1);
    final k = v.floor().clamp(0, _path.length - 2);
    final f = v - k;
    final p = Offset.lerp(_path[k], _path[k + 1], f)!;
    return p.translate(0, -sin(f * pi) * 0.012);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = min(box.maxWidth, 360.0);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: w,
            height: w * 1.1,
            child: CustomPaint(
              painter: _PlinkoPainter(
                  rows: a.i('rows'), slots: _slots.length, hit: _hit, ball: _ball()),
            ),
          ),
          const SizedBox(height: 14),
          GoButton(label: 'Drop', onPressed: _running ? null : _drop),
          const SizedBox(height: 10),
          Text(
            a.pool.length > maxSlots
                ? '$maxSlots of ${a.pool.length} places, drawn fresh each drop'
                : '${_slots.length} slots, one per place',
            style: stageHint,
          ),
          const SizedBox(height: 10),
          PlaceLegend(names: _slots, hit: _hit),
        ],
      );
    });
  }
}

class _PlinkoPainter extends CustomPainter {
  _PlinkoPainter({required this.rows, required this.slots, this.hit, this.ball});

  final int rows;
  final int slots;
  final int? hit;
  final Offset? ball;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final peg = Paint()..color = Felt.ink.withAlpha(200);
    final cols = max(slots, 7);
    for (var j = 0; j < rows; j++) {
      final y = _PlinkoGameState._rowY(j, rows) * h;
      final shift = j.isEven ? 0.5 : 0.0;
      for (var k = 0; k <= cols; k++) {
        final x = (k + shift) / cols * w;
        if (x < 6 || x > w - 6) continue;
        canvas.drawCircle(Offset(x, y), max(2.5, w / 110), peg);
      }
    }

    final top = h * 0.84;
    final slotW = w / slots;
    for (var s = 0; s < slots; s++) {
      final rect = Rect.fromLTWH(s * slotW + 2, top, slotW - 4, h - top - 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = s == hit ? Felt.gold : Felt.ink.withAlpha(36),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${s + 1}',
          style: TextStyle(
            color: s == hit ? Felt.text : Felt.ink,
            fontWeight: FontWeight.w800,
            fontSize: min(16.0, slotW * 0.5),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
    }

    final b = ball;
    if (b != null) {
      final c = Offset(b.dx * w, b.dy * h);
      canvas.drawCircle(c.translate(0, 3), w / 34, Paint()..color = Colors.black26);
      canvas.drawCircle(c, w / 34, Paint()..color = Felt.coral);
      canvas.drawCircle(c.translate(-w / 110, -w / 110), w / 110,
          Paint()..color = Colors.white54);
    }
  }

  @override
  bool shouldRepaint(_PlinkoPainter old) =>
      old.ball != ball || old.hit != hit || old.rows != rows || old.slots != slots;
}
