import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// The shell game: places hide under cups, the cups shuffle, you pick one.
class ShellsGame extends StatefulWidget {
  const ShellsGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<ShellsGame> createState() => _ShellsGameState();
}

enum _Phase { idle, peek, shuffle, choose, done }

class _ShellsGameState extends State<ShellsGame> {
  GameArgs get a => widget.args;
  List<String> _under = [];
  List<int> _slot = [];
  Set<int> _lifted = {};
  int? _chosen;
  _Phase _phase = _Phase.idle;

  int get _cups => _under.isNotEmpty ? _under.length : min(a.i('cups'), a.pool.length);

  Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> _start() async {
    final pool = a.startRound();
    if (pool.length < 2) return;
    final k = min(a.i('cups'), pool.length);
    setState(() {
      _under = shuffled(pool).take(k).toList();
      _slot = List<int>.generate(k, (i) => i);
      _chosen = null;
      _lifted = {};
      _phase = _Phase.peek;
    });
    if (a.b('peek')) {
      await _wait(250);
      if (!mounted) return;
      setState(() => _lifted = Set<int>.of(List<int>.generate(k, (i) => i)));
      await _wait(1500);
      if (!mounted) return;
      setState(() => _lifted = {});
      await _wait(450);
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.shuffle);
    final speed = a.i('ms');
    for (var s = 0; s < a.i('swaps'); s++) {
      final i = rng.nextInt(k);
      var j = rng.nextInt(k - 1);
      if (j >= i) j++;
      setState(() {
        final t = _slot[i];
        _slot[i] = _slot[j];
        _slot[j] = t;
      });
      a.tick();
      await _wait(speed + 30);
      if (!mounted) return;
    }
    setState(() => _phase = _Phase.choose);
  }

  Future<void> _pick(int cup) async {
    if (_phase != _Phase.choose) return;
    setState(() {
      _chosen = cup;
      _lifted = {cup};
      _phase = _Phase.done;
    });
    a.thump();
    await _wait(500);
    if (!mounted) return;
    a.onPick(_under[cup]);
    await _wait(700);
    if (!mounted) return;
    setState(() => _lifted = Set<int>.of(List<int>.generate(_under.length, (i) => i)));
  }

  String get _status {
    switch (_phase) {
      case _Phase.idle:
        return 'Places hide under the cups';
      case _Phase.peek:
        return 'Watch closely…';
      case _Phase.shuffle:
        return 'Shuffling…';
      case _Phase.choose:
        return 'Tap a cup';
      case _Phase.done:
        return 'You found it';
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = max(2, _cups);
    return LayoutBuilder(builder: (context, box) {
      final w = min(box.maxWidth, 380.0);
      final slotW = w / k;
      final cupW = min(slotW * 0.82, 96.0);
      final cupH = cupW * 1.05;
      final speed = Duration(milliseconds: _phase == _Phase.shuffle ? a.i('ms') : 280);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_status, style: stageStatus),
          const SizedBox(height: 16),
          SizedBox(
            width: w,
            height: cupH + 90,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Table line
                Positioned(
                  left: 0,
                  right: 0,
                  top: cupH + 56,
                  child: Container(height: 3, color: Felt.ink.withAlpha(50)),
                ),
                for (var c = 0; c < k; c++)
                  AnimatedPositioned(
                    duration: speed,
                    curve: Curves.easeInOut,
                    left: (c < _slot.length ? _slot[c] : c) * slotW,
                    top: cupH + 24,
                    width: slotW,
                    child: AnimatedOpacity(
                      opacity: _lifted.contains(c) && c < _under.length ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: NameChip(
                          c < _under.length ? _under[c] : '',
                          highlight: c == _chosen,
                          maxWidth: max(70.0, slotW - 6),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                for (var c = 0; c < k; c++)
                  AnimatedPositioned(
                    duration: _lifted.contains(c) ? const Duration(milliseconds: 280) : speed,
                    curve: Curves.easeInOut,
                    left: (c < _slot.length ? _slot[c] : c) * slotW + (slotW - cupW) / 2,
                    top: _lifted.contains(c) ? 0 : 58,
                    child: GestureDetector(
                      onTap: () => _pick(c),
                      child: CustomPaint(
                        size: Size(cupW, cupH),
                        painter: _CupPainter(glow: _phase == _Phase.choose),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GoButton(
            label: _phase == _Phase.idle ? 'Hide & shuffle' : 'Play again',
            onPressed: (_phase == _Phase.idle || _phase == _Phase.done) ? _start : null,
          ),
          const SizedBox(height: 10),
          Text('$k cups, ${a.i('swaps')} swaps', style: stageHint),
        ],
      );
    });
  }
}

class _CupPainter extends CustomPainter {
  _CupPainter({required this.glow});

  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Path()
      ..moveTo(w * 0.2, 0)
      ..lineTo(w * 0.8, 0)
      ..lineTo(w, h * 0.92)
      ..quadraticBezierTo(w * 0.5, h * 1.02, 0, h * 0.92)
      ..close();
    if (glow) {
      canvas.drawPath(
          body,
          Paint()
            ..color = Felt.gold.withAlpha(150)
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8));
    }
    canvas.drawShadow(body, Colors.black, 6, false);
    canvas.drawPath(body, Paint()..color = Felt.coral);
    canvas.drawRect(Rect.fromLTWH(w * 0.08, h * 0.6, w * 0.84, h * 0.09),
        Paint()..color = Felt.ink.withAlpha(200));
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.24, h * 0.1, w * 0.08, h * 0.42), const Radius.circular(4)),
        Paint()..color = Colors.white.withAlpha(70));
  }

  @override
  bool shouldRepaint(_CupPainter old) => old.glow != glow;
}
