import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

enum _Claw { move, down, up, done }

/// A claw machine. The claw slides back and forth; tap Drop to grab the
/// capsule beneath it. Lower grip means it slips more often.
class ClawGame extends StatefulWidget {
  const ClawGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<ClawGame> createState() => _ClawGameState();
}

class _ClawGameState extends State<ClawGame> with SingleTickerProviderStateMixin {
  static const _boxH = 270.0;
  static const _capR = 22.0;
  static const _topY = 46.0;
  static const _restY = _boxH - _capR - 12;

  /// Where the claw's tip is for a given drop depth.
  static double _tip(double y) => _topY + y * (_restY - _capR - _topY);

  GameArgs get a => widget.args;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _clock = 0;
  double _x = 0.5;
  double _y = 0; // 0 at the top, 1 down at the capsules
  _Claw _phase = _Claw.move;
  List<String> _names = [];
  List<double> _capX = [];
  final Map<int, double> _fall = {}; // capsule centre y while falling back
  int? _held;
  bool _willHold = false;
  int? _won;
  String _msg = '';
  String _poolKey = '';

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _fill(a.pool);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _fill(List<String> pool) {
    _poolKey = pool.join('\u0000');
    final k = min(a.i('prizes'), pool.length);
    _names = shuffled(pool).take(k).toList();
    _capX = List<double>.generate(k, (i) {
      final base = (i + 0.5) / k;
      return (base + (rng.nextDouble() - 0.5) * 0.4 / k).clamp(0.06, 0.94);
    });
    _fall.clear();
    _held = null;
    _won = null;
  }

  void _onTick(Duration elapsed) {
    final dt = min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    _clock += dt;
    switch (_phase) {
      case _Claw.move:
        _x = 0.5 + 0.44 * sin(_clock * a.d('speed') * 2 * pi);
        break;
      case _Claw.down:
        _y += dt / 0.75;
        if (_y >= 1) {
          _y = 1;
          var best = 0;
          for (var i = 1; i < _capX.length; i++) {
            if ((_capX[i] - _x).abs() < (_capX[best] - _x).abs()) best = i;
          }
          _held = best;
          _fall.remove(best);
          _willHold = rng.nextDouble() * 100 < a.d('grip');
          _phase = _Claw.up;
          a.tick();
        }
        break;
      case _Claw.up:
        _y -= dt / 0.9;
        final h = _held;
        if (!_willHold && h != null && _y < 0.5) {
          _fall[h] = _tip(_y) + _capR;
          _held = null;
          _msg = 'It slipped! Try again.';
          a.tick();
        }
        if (_y <= 0) {
          _y = 0;
          final got = _held;
          if (got != null) {
            _phase = _Claw.done;
            _won = got;
            _msg = 'You got it!';
            a.thump();
            a.onPick(_names[got]);
          } else {
            _phase = _Claw.move;
          }
        }
        break;
      case _Claw.done:
        break;
    }
    // Slipped capsules fall back down.
    for (final k in _fall.keys.toList()) {
      final v = _fall[k]! + dt * 520;
      if (v >= _restY) {
        _fall.remove(k);
      } else {
        _fall[k] = v;
      }
    }
    setState(() {});
  }

  void _drop() {
    if (_phase == _Claw.done) {
      final pool = a.startRound();
      if (pool.length < 2) return;
      _fill(pool);
      setState(() {
        _phase = _Claw.move;
        _msg = '';
      });
      return;
    }
    if (_phase != _Claw.move) return;
    final pool = a.startRound();
    if (pool.length < 2) return;
    if (pool.join('\u0000') != _poolKey) _fill(pool);
    setState(() {
      _phase = _Claw.down;
      _msg = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = min(box.maxWidth, 340.0);
      final tipY = _tip(_y);
      final clawX = _x * w;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: w,
            height: _boxH,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Felt.ink, width: 3),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 12,
                  child: Container(height: 5, color: Felt.ink.withAlpha(160)),
                ),
                for (var i = 0; i < _names.length; i++)
                  Builder(builder: (_) {
                    final held = _held == i;
                    final cy = held ? tipY + _capR : (_fall[i] ?? _restY);
                    final cx = held ? clawX : _capX[i] * w;
                    return Positioned(
                      left: cx - _capR,
                      top: cy - _capR,
                      child: _Capsule(
                        color: toyColors[i % toyColors.length],
                        won: _won == i,
                      ),
                    );
                  }),
                Positioned(
                  left: clawX - 1.5,
                  top: 14,
                  child: Container(width: 3, height: max(0.0, tipY - 14), color: Felt.ink),
                ),
                Positioned(
                  left: clawX - 24,
                  top: tipY - 6,
                  child: CustomPaint(
                    size: const Size(48, 34),
                    painter: _ClawPainter(open: _phase == _Claw.move || _phase == _Claw.down),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: Center(
              child: _won != null
                  ? NameChip(_names[_won!], highlight: true, maxWidth: 280, fontSize: 15)
                  : Text(_msg, style: stageStatus),
            ),
          ),
          GoButton(
            label: _phase == _Claw.done ? 'Play again' : 'Drop',
            onPressed: (_phase == _Claw.move || _phase == _Claw.done) ? _drop : null,
          ),
          const SizedBox(height: 10),
          Text('${_names.length} capsules · grip ${a.i('grip')}%', style: stageHint),
        ],
      );
    });
  }
}

class _Capsule extends StatelessWidget {
  const _Capsule({required this.color, required this.won});

  final Color color;
  final bool won;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _ClawGameState._capR * 2,
      height: _ClawGameState._capR * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.5, 0.5],
          colors: [Colors.white.withAlpha(220), color],
        ),
        border: Border.all(color: won ? Felt.gold : Colors.black26, width: won ? 3 : 1),
      ),
      child: const Center(
        child: Text('?', style: TextStyle(color: Felt.text, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    );
  }
}

class _ClawPainter extends CustomPainter {
  _ClawPainter({required this.open});

  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pen = Paint()
      ..color = const Color(0xFFC9CED3)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.32, 0, w * 0.36, 10), const Radius.circular(3)),
        Paint()..color = const Color(0xFFC9CED3));
    final spread = open ? 0.45 : 0.25;
    final left = Path()
      ..moveTo(w * 0.4, 8)
      ..quadraticBezierTo(w * (0.5 - spread - 0.08), h * 0.55, w * (0.5 - spread * 0.55), h);
    final right = Path()
      ..moveTo(w * 0.6, 8)
      ..quadraticBezierTo(w * (0.5 + spread + 0.08), h * 0.55, w * (0.5 + spread * 0.55), h);
    canvas.drawPath(left, pen);
    canvas.drawPath(right, pen);
  }

  @override
  bool shouldRepaint(_ClawPainter old) => old.open != open;
}
