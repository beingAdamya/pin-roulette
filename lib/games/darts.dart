import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// A dartboard split into one numbered sector per place.
class DartsGame extends StatefulWidget {
  const DartsGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<DartsGame> createState() => _DartsGameState();
}

class _DartsGameState extends State<DartsGame> with TickerProviderStateMixin {
  static const maxSectors = 16;

  GameArgs get a => widget.args;
  late final AnimationController _fly;
  late final Ticker _aim;
  double _clock = 0;
  Duration _last = Duration.zero;
  List<String> _names = [];
  String _poolKey = '';
  Offset? _dart; // where the dart lands, -1..1
  Offset _cross = Offset.zero;
  int? _hit;
  bool _busy = false;
  String _msg = '';

  bool get _aimMode => a.i('mode') == 1;

  @override
  void initState() {
    super.initState();
    _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
      ..addListener(() => setState(() {}));
    _aim = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      _clock += dt * a.d('wobble');
      setState(() => _cross = Offset(0.78 * sin(_clock * 2.3), 0.78 * sin(_clock * 3.1 + 1.3)));
    });
    _setNames(a.pool);
    if (_aimMode) _aim.start();
  }

  @override
  void didUpdateWidget(covariant DartsGame old) {
    super.didUpdateWidget(old);
    if (!_busy && _hit == null && a.pool.join('\u0000') != _poolKey) _setNames(a.pool);
    if (_aimMode && !_aim.isActive && !_busy && _hit == null) {
      _last = Duration.zero;
      _aim.start();
    } else if (!_aimMode && _aim.isActive) {
      _aim.stop();
    }
  }

  @override
  void dispose() {
    _fly.dispose();
    _aim.dispose();
    super.dispose();
  }

  void _setNames(List<String> pool) {
    _poolKey = pool.join('\u0000');
    _names = pool.length <= maxSectors ? List<String>.of(pool) : shuffled(pool).take(maxSectors).toList();
  }

  int _sectorAt(Offset p) {
    final n = _names.length;
    final seg = 2 * pi / n;
    final angle = (atan2(p.dy, p.dx) + pi / 2) % (2 * pi);
    return (angle / seg).floor().clamp(0, n - 1);
  }

  Future<void> _throw() async {
    if (_hit != null) {
      // Next round.
      final pool = a.startRound();
      if (pool.length < 2) return;
      _setNames(pool);
      setState(() {
        _hit = null;
        _dart = null;
        _msg = '';
      });
      if (_aimMode) {
        _last = Duration.zero;
        _aim.start();
      }
      return;
    }
    final pool = a.startRound();
    if (pool.length < 2) return;
    if (pool.length > maxSectors || pool.join('\u0000') != _poolKey) _setNames(pool);

    Offset target;
    if (_aimMode) {
      _aim.stop();
      target = _cross;
    } else {
      final n = _names.length;
      final seg = 2 * pi / n;
      final s = rng.nextInt(n);
      final ang = -pi / 2 + (s + 0.12 + rng.nextDouble() * 0.76) * seg;
      final rad = 0.22 + rng.nextDouble() * 0.68;
      target = Offset(cos(ang) * rad, sin(ang) * rad);
    }
    setState(() {
      _busy = true;
      _dart = target;
      _msg = '';
    });
    await _fly.forward(from: 0);
    if (!mounted) return;
    a.thump();
    if (target.distance > 0.97) {
      setState(() {
        _busy = false;
        _dart = null;
        _msg = 'Missed the board! Throw again.';
      });
      if (_aimMode) {
        _last = Duration.zero;
        _aim.start();
      }
      return;
    }
    final s = _sectorAt(target);
    setState(() {
      _hit = s;
      _busy = false;
      _msg = '${s + 1} → ${_names[s]}';
    });
    a.onPick(_names[s]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = min(box.maxWidth, 320.0);
      final v = Curves.easeIn.transform(_fly.value);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _BoardPainter(
                n: _names.length,
                hit: _hit,
                dart: _dart,
                flight: _busy ? v : 1.0,
                cross: _aimMode && _hit == null && !_busy ? _cross : null,
              ),
            ),
          ),
          SizedBox(
            height: 28,
            child: Center(
              child: Text(_msg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Felt.ink, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 6),
          GoButton(label: _hit == null ? 'Throw' : 'Next dart', onPressed: _busy ? null : _throw),
          const SizedBox(height: 10),
          Text(
            _aimMode ? 'Tap Throw when the crosshair is where you want.' : 'The dart lands at random.',
            style: stageHint,
          ),
          const SizedBox(height: 10),
          PlaceLegend(names: _names, hit: _hit),
        ],
      );
    });
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({required this.n, this.hit, this.dart, required this.flight, this.cross});

  final int n;
  final int? hit;
  final Offset? dart;
  final double flight;
  final Offset? cross;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF1B1B1B));
    final board = r * 0.9;
    final rect = Rect.fromCircle(center: c, radius: board);
    final seg = 2 * pi / max(1, n);
    const dark = Color(0xFF232323);
    const light = Color(0xFFEFE3C4);
    for (var i = 0; i < n; i++) {
      final start = -pi / 2 + i * seg;
      final base = i.isEven ? dark : light;
      canvas.drawArc(rect, start, seg, true, Paint()..color = i == hit ? Felt.gold : base);
      // Double ring in red/green like a real board
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = board * 0.07
        ..color = i.isEven ? Felt.coral : const Color(0xFF2E8B57);
      canvas.drawArc(Rect.fromCircle(center: c, radius: board * 0.96), start, seg, false, ring);
      canvas.drawArc(Rect.fromCircle(center: c, radius: board * 0.6), start, seg, false, ring);
      // Number outside the board
      final mid = start + seg / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
              color: i == hit ? Felt.gold : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: min(15.0, r * 0.11)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = c + Offset(cos(mid), sin(mid)) * (r * 0.955);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
    canvas.drawCircle(c, board * 0.09, Paint()..color = const Color(0xFF2E8B57));
    canvas.drawCircle(c, board * 0.04, Paint()..color = Felt.coral);

    final x = cross;
    if (x != null) {
      final p = c + x * board;
      final pen = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(p, 12, pen);
      canvas.drawLine(p.translate(-18, 0), p.translate(18, 0), pen);
      canvas.drawLine(p.translate(0, -18), p.translate(0, 18), pen);
    }

    final d = dart;
    if (d != null) {
      final end = c + d * board;
      final start = Offset(r, size.height * 1.6);
      final p = Offset.lerp(start, end, flight)!;
      final scale = 2.2 - 1.2 * flight;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.scale(scale);
      canvas.drawCircle(Offset.zero, 3.5, Paint()..color = Colors.white);
      canvas.drawLine(const Offset(0, 0), const Offset(10, 18),
          Paint()
            ..color = const Color(0xFF9AA3AB)
            ..strokeWidth = 3);
      final flightPath = Path()
        ..moveTo(10, 18)
        ..lineTo(4, 30)
        ..lineTo(16, 26)
        ..close();
      canvas.drawPath(flightPath, Paint()..color = Felt.coral);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}
