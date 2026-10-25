import 'dart:async';
import 'dart:math';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

/* ---------------- Fortune cookie ---------------- */

class CookieGame extends StatefulWidget {
  const CookieGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<CookieGame> createState() => _CookieGameState();
}

class _CookieGameState extends State<CookieGame> {
  static const _fortunes = [
    'Your lucky place today is {p}.',
    'A good time is waiting for you at {p}.',
    'Adventure calls from {p}. Answer it.',
    'Go to {p}. You won’t regret it.',
    'Great things happen at {p}.',
    'The stars point to {p}.',
    'Something wonderful is about to happen at {p}.',
  ];

  GameArgs get a => widget.args;
  int _taps = 0;
  List<String> _pool = [];
  String? _name;
  String _fortune = '';
  double _wobble = 0;

  void _tap() {
    if (_name != null) return;
    if (_taps == 0) {
      final pool = a.startRound();
      if (pool.length < 2) return;
      _pool = pool;
    }
    setState(() {
      _taps++;
      _wobble = (_taps.isEven ? 1 : -1) * 0.18;
    });
    a.tick();
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _wobble = 0);
    });
    if (_taps >= a.i('taps')) {
      final name = _pool[rng.nextInt(_pool.length)];
      final f = _fortunes[rng.nextInt(_fortunes.length)].replaceFirst('{p}', name);
      setState(() {
        _name = name;
        _fortune = f;
      });
      a.thump();
      a.onPick(name);
    }
  }

  void _reset() => setState(() {
        _taps = 0;
        _name = null;
      });

  @override
  Widget build(BuildContext context) {
    final name = _name;
    final need = a.i('taps');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name == null ? 'Tap the cookie to crack it' : 'Your fortune', style: stageStatus),
        const SizedBox(height: 18),
        SizedBox(
          height: 170,
          child: Center(
            child: name == null
                ? GestureDetector(
                    onTap: _tap,
                    child: AnimatedRotation(
                      turns: _wobble / (2 * pi),
                      duration: const Duration(milliseconds: 120),
                      child: AnimatedScale(
                        scale: _wobble == 0 ? 1.0 : 0.92,
                        duration: const Duration(milliseconds: 120),
                        child: const Text('🥠', style: TextStyle(fontSize: 120)),
                      ),
                    ),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutBack,
                    builder: (context, v, _) => Transform.scale(
                      scaleX: v,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBF0),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Text(
                          a.b('fortunes') ? _fortune : name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF7A2A1E),
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        if (name == null)
          Text('${max(0, need - _taps)} more tap${need - _taps == 1 ? '' : 's'}', style: stageHint)
        else
          GoButton(label: 'New cookie', onPressed: _reset),
      ],
    );
  }
}

/* ---------------- Mystery ball ---------------- */

class MysteryBallGame extends StatefulWidget {
  const MysteryBallGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<MysteryBallGame> createState() => _MysteryBallGameState();
}

class _MysteryBallGameState extends State<MysteryBallGame> {
  GameArgs get a => widget.args;
  Offset _shake = Offset.zero;
  bool _shaking = false;
  String? _answer;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _go() {
    final pool = a.startRound();
    if (pool.length < 2) return;
    final end = DateTime.now().add(Duration(milliseconds: a.ms('seconds')));
    setState(() {
      _shaking = true;
      _answer = null;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 45), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (DateTime.now().isAfter(end)) {
        t.cancel();
        final name = pool[rng.nextInt(pool.length)];
        setState(() {
          _shake = Offset.zero;
          _shaking = false;
          _answer = name;
        });
        a.thump();
        a.onPick(name);
        return;
      }
      setState(() => _shake = Offset((rng.nextDouble() - 0.5) * 22, (rng.nextDouble() - 0.5) * 16));
      if (rng.nextInt(3) == 0) a.tick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final answer = _answer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_shaking ? 'Shaking…' : 'Ask the ball where to go', style: stageStatus),
        const SizedBox(height: 18),
        Transform.translate(
          offset: _shake,
          child: Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.35, -0.45),
                radius: 0.9,
                colors: [Color(0xFF5A5F66), Color(0xFF14171A)],
              ),
              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 10))],
            ),
            child: Center(
              child: Container(
                width: 116,
                height: 116,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0B1230),
                ),
                child: AnimatedOpacity(
                  opacity: answer == null ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeIn,
                  child: CustomPaint(
                    painter: const _TrianglePainter(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 22, 26, 40),
                      child: Center(
                        child: Text(
                          answer ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, height: 1.15),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        GoButton(label: 'Shake', onPressed: _shaking ? null : _go),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.1, h * 0.2)
      ..lineTo(w * 0.9, h * 0.2)
      ..lineTo(w * 0.5, h * 0.88)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF2B48C9));
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => false;
}

/* ---------------- Number draw ---------------- */

class NumberGame extends StatefulWidget {
  const NumberGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<NumberGame> createState() => _NumberGameState();
}

class _NumberGameState extends State<NumberGame> {
  GameArgs get a => widget.args;
  List<String> _names = [];
  int _shown = 1;
  int? _hit;
  bool _rolling = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _names = a.pool;
  }

  @override
  void didUpdateWidget(covariant NumberGame old) {
    super.didUpdateWidget(old);
    if (!_rolling && _hit == null) _names = a.pool;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _roll() {
    final pool = a.startRound();
    if (pool.length < 2) return;
    final n = pool.length;
    final win = rng.nextInt(n);
    final t0 = DateTime.now();
    final dur = a.ms('seconds');
    setState(() {
      _names = pool;
      _hit = null;
      _rolling = true;
    });
    void step() {
      if (!mounted) return;
      final el = DateTime.now().difference(t0).inMilliseconds;
      if (el >= dur) {
        setState(() {
          _shown = win + 1;
          _hit = win;
          _rolling = false;
        });
        a.thump();
        a.onPick(pool[win]);
        return;
      }
      setState(() => _shown = rng.nextInt(n) + 1);
      a.tick();
      final progress = el / dur;
      _timer = Timer(Duration(milliseconds: (40 + 260 * progress * progress).round()), step);
    }

    step();
  }

  @override
  Widget build(BuildContext context) {
    final hit = _hit;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('1 to ${_names.length}', style: stageStatus),
        const SizedBox(height: 14),
        Container(
          width: 190,
          height: 130,
          decoration: BoxDecoration(
            color: const Color(0xFF0E1512),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Felt.gold, width: 4),
          ),
          child: Center(
            child: Text(
              '$_shown',
              style: TextStyle(
                color: _rolling ? Felt.coral : Felt.gold,
                fontSize: 76,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 26,
          child: Text(
            hit != null && hit < _names.length ? _names[hit] : '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Felt.ink, fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        GoButton(label: 'Draw a number', onPressed: _rolling ? null : _roll),
        if (a.b('list')) ...[
          const SizedBox(height: 14),
          PlaceLegend(names: _names, hit: hit, maxHeight: 160),
        ],
      ],
    );
  }
}
