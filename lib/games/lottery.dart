import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// Numbered balls tumble in a drum; one drops out of the chute.
class LotteryGame extends StatefulWidget {
  const LotteryGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<LotteryGame> createState() => _LotteryGameState();
}

class _LotteryGameState extends State<LotteryGame>
    with SingleTickerProviderStateMixin {
  static const maxBalls = 30;

  GameArgs get a => widget.args;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  List<String> _names = [];
  String _poolKey = '';
  List<Offset> _pos = [];
  List<Offset> _vel = [];
  bool _mixing = false;
  double _left = 0;
  int? _winner;
  double _exit = 0;
  Offset _exitFrom = Offset.zero;
  bool _done = false;
  double _bounceTick = 0;

  double get _r => (0.5 / sqrt(max(1, _names.length))).clamp(0.075, 0.16);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _setBalls(a.pool);
  }

  @override
  void didUpdateWidget(covariant LotteryGame old) {
    super.didUpdateWidget(old);
    if (!_mixing && !_done && a.pool.join('\u0000') != _poolKey) _setBalls(a.pool);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _setBalls(List<String> pool) {
    _poolKey = pool.join('\u0000');
    _names = pool.length <= maxBalls ? List<String>.of(pool) : shuffled(pool).take(maxBalls).toList();
    final r = _r;
    // Resting in a heap at the bottom of the drum.
    _pos = List.generate(_names.length, (i) {
      final a = pi * (0.15 + 0.7 * rng.nextDouble());
      final d = (1 - r) * (0.55 + 0.45 * rng.nextDouble());
      return Offset(cos(a) * d * 0.9, sin(a) * d);
    });
    _vel = List.filled(_names.length, Offset.zero);
    _winner = null;
    _done = false;
    _exit = 0;
  }

  void _start() {
    final pool = a.startRound();
    if (pool.length < 2) return;
    if (pool.length > maxBalls || pool.join('\u0000') != _poolKey || _done) _setBalls(pool);
    final speed = a.d('speed');
    setState(() {
      _vel = List.generate(_names.length, (_) {
        final ang = rng.nextDouble() * 2 * pi;
        return Offset(cos(ang), sin(ang)) * speed * (0.7 + rng.nextDouble() * 0.6);
      });
      _mixing = true;
      _left = a.d('seconds');
      _winner = null;
      _exit = 0;
      _done = false;
    });
    _last = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    final r = _r;
    final limit = 1 - r;
    final w = _winner;
    for (var i = 0; i < _pos.length; i++) {
      if (i == w) continue;
      var p = _pos[i] + _vel[i] * dt;
      var v = _vel[i];
      final d = p.distance;
      if (d > limit) {
        final n = p / d;
        final dot = v.dx * n.dx + v.dy * n.dy;
        v = v - n * (2 * dot);
        // A little spin off the wall keeps the mix lively.
        v = Offset(v.dx + (rng.nextDouble() - 0.5) * 0.3, v.dy + (rng.nextDouble() - 0.5) * 0.3);
        p = n * limit;
        _bounceTick += 1;
      }
      if (w != null) v = v * (1 - dt * 1.5); // settle once a ball is out
      _pos[i] = p;
      _vel[i] = v;
    }
    if (_bounceTick > 6) {
      _bounceTick = 0;
      a.tick();
    }

    if (w == null) {
      _left -= dt;
      if (_left <= 0) {
        _winner = rng.nextInt(_names.length);
        _exitFrom = _pos[_winner!];
        _exit = 0;
      }
    } else {
      _exit = min(1.0, _exit + dt / 0.9);
      final chute = Offset(0, 1 + r * 1.6);
      _pos[w] = Offset.lerp(_exitFrom, chute, Curves.easeInOut.transform(_exit))!;
      if (_exit >= 1) {
        _ticker.stop();
        _mixing = false;
        _done = true;
        a.onPick(_names[w]);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final w = _winner;
    return LayoutBuilder(builder: (context, box) {
      final size = min(box.maxWidth, 300.0);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size * 1.18,
            child: CustomPaint(
              painter: _DrumPainter(_pos, _r, w, _done, _last.inMicroseconds),
            ),
          ),
          SizedBox(
            height: 26,
            child: Text(
              _done && w != null ? 'Ball ${w + 1} → ${_names[w]}' : (_mixing ? 'Mixing…' : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Felt.ink, fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          GoButton(label: 'Draw a ball', onPressed: _mixing ? null : _start),
          const SizedBox(height: 10),
          Text(
            a.pool.length > maxBalls
                ? '$maxBalls of ${a.pool.length} places, drawn fresh each time'
                : '${_names.length} numbered balls',
            style: stageHint,
          ),
          const SizedBox(height: 10),
          PlaceLegend(names: _names, hit: _done ? w : null),
        ],
      );
    });
  }
}

class _DrumPainter extends CustomPainter {
  _DrumPainter(this.pos, this.r, this.winner, this.done, this.stamp);

  final List<Offset> pos;
  final double r;
  final int? winner;
  final bool done;
  final int stamp;

  @override
  void paint(Canvas canvas, Size size) {
    final rad = size.width / 2 - 6;
    final c = Offset(size.width / 2, rad + 6);
    // Chute
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: c.translate(0, rad + r * rad * 1.3), width: r * rad * 2.6, height: r * rad * 3),
          const Radius.circular(8)),
      Paint()..color = Felt.ink.withAlpha(50),
    );
    canvas.drawCircle(c, rad, Paint()..color = Colors.white.withAlpha(22));
    canvas.drawCircle(
        c,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Felt.ink);
    for (var i = 0; i < pos.length; i++) {
      final p = c + pos[i] * rad;
      final br = r * rad;
      final color = toyColors[i % toyColors.length];
      final isWin = done && i == winner;
      canvas.drawCircle(p, br, Paint()..color = color);
      if (isWin) {
        canvas.drawCircle(
            p,
            br + 3,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Felt.gold);
      }
      canvas.drawCircle(p, br * 0.58, Paint()..color = Colors.white);
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(color: Felt.text, fontWeight: FontWeight.w900, fontSize: br * 0.75),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_DrumPainter old) => true;
}
