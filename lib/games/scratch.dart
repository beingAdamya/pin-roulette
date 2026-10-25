import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// A scratch card. The place underneath is drawn when you start scratching.
class ScratchGame extends StatefulWidget {
  const ScratchGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<ScratchGame> createState() => _ScratchGameState();
}

class _ScratchGameState extends State<ScratchGame> {
  static const _gx = 24;
  static const _gy = 12;

  GameArgs get a => widget.args;
  String? _prize;
  final List<List<Offset>> _strokes = [];
  final Set<int> _cells = {};
  bool _revealed = false;
  Size _size = Size.zero;

  void _begin(Offset p) {
    if (_revealed) return;
    if (_prize == null) {
      final pool = a.startRound();
      if (pool.length < 2) return;
      _prize = pool[rng.nextInt(pool.length)];
    }
    setState(() => _strokes.add([p]));
    _mark(p);
  }

  void _move(Offset p) {
    if (_revealed || _prize == null || _strokes.isEmpty) return;
    setState(() => _strokes.last.add(p));
    _mark(p);
  }

  void _mark(Offset p) {
    if (_size.isEmpty) return;
    final brush = a.d('brush') / 2;
    final cw = _size.width / _gx;
    final ch = _size.height / _gy;
    var newCells = false;
    for (var gx = 0; gx < _gx; gx++) {
      for (var gy = 0; gy < _gy; gy++) {
        final c = Offset((gx + 0.5) * cw, (gy + 0.5) * ch);
        if ((c - p).distance <= brush + min(cw, ch) / 2) {
          if (_cells.add(gy * _gx + gx)) newCells = true;
        }
      }
    }
    if (newCells && _cells.length % 6 == 0) a.tick();
    if (_cells.length >= _gx * _gy * a.d('reveal') / 100) {
      setState(() => _revealed = true);
      a.onPick(_prize!);
    }
  }

  void _newCard() {
    setState(() {
      _prize = null;
      _strokes.clear();
      _cells.clear();
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = min(box.maxWidth, 340.0);
      final h = w * 0.62;
      _size = Size(w, h);
      final prize = _prize;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_revealed ? 'Winner!' : 'Scratch the silver with your finger', style: stageStatus),
          const SizedBox(height: 14),
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Felt.gold, width: 4),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 6)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: Felt.ink,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('YOU’RE GOING TO',
                              style: TextStyle(
                                  color: Felt.coral,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  fontSize: 12)),
                          const SizedBox(height: 8),
                          Text(
                            prize ?? '',
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Felt.text, fontWeight: FontWeight.w900, fontSize: 24),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _revealed ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 400),
                      child: GestureDetector(
                        onVerticalDragStart: (d) => _begin(d.localPosition),
                        onVerticalDragUpdate: (d) => _move(d.localPosition),
                        onHorizontalDragStart: (d) => _begin(d.localPosition),
                        onHorizontalDragUpdate: (d) => _move(d.localPosition),
                        onTapDown: (d) => _begin(d.localPosition),
                        child: CustomPaint(
                          size: Size(w, h),
                          painter: _FoilPainter(_strokes, a.d('brush'), _strokes.fold<int>(0, (s, e) => s + e.length)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          GoButton(label: 'New card', onPressed: _prize == null ? null : _newCard),
        ],
      );
    });
  }
}

class _FoilPainter extends CustomPainter {
  _FoilPainter(this.strokes, this.brush, this.points);

  final List<List<Offset>> strokes;
  final double brush;
  final int points;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFB8BEC4), Color(0xFFE6E9EC), Color(0xFF9EA5AC), Color(0xFFD5D9DD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: 'SCRATCH HERE',
        style: TextStyle(
            color: Color(0x99566069), fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 3),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));

    final eraser = Paint()
      ..blendMode = BlendMode.clear
      ..strokeWidth = brush
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawCircle(s.first, brush / 2, Paint()..blendMode = BlendMode.clear);
      } else {
        final path = Path()..moveTo(s.first.dx, s.first.dy);
        for (final p in s.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, eraser);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FoilPainter old) => old.points != points || old.brush != brush;
}
