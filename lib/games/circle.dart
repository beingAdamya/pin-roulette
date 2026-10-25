import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

const _maxSeats = 12;

List<String> _seat(List<String> pool) =>
    pool.length <= _maxSeats ? List<String>.of(pool) : shuffled(pool).take(_maxSeats).toList();

/// Places sitting round a circle, used by Spin the Bottle and Hot Potato.
class _Circle extends StatelessWidget {
  const _Circle({
    required this.size,
    required this.names,
    this.highlight,
    this.center,
    this.overlay,
  });

  final double size;
  final List<String> names;
  final int? highlight;
  final Widget? center;
  final Widget? overlay;

  static Offset seatOffset(int i, int n, double radius) {
    final angle = i * 2 * pi / n;
    return Offset(sin(angle) * radius, -cos(angle) * radius);
  }

  @override
  Widget build(BuildContext context) {
    final r = size / 2 - 48;
    final c = size / 2;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                width: r * 2,
                height: r * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Felt.ink.withAlpha(60), width: 2),
                ),
              ),
            ),
          ),
          if (center != null) Positioned.fill(child: Center(child: center)),
          for (var i = 0; i < names.length; i++)
            Builder(builder: (_) {
              final o = seatOffset(i, names.length, r + 18);
              return Positioned(
                left: c + o.dx - 46,
                top: c + o.dy - 14,
                width: 92,
                child: Center(
                  child: NameChip(names[i],
                      highlight: i == highlight, maxWidth: 92, fontSize: 11),
                ),
              );
            }),
          if (overlay != null) overlay!,
        ],
      ),
    );
  }
}

class BottleGame extends StatefulWidget {
  const BottleGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<BottleGame> createState() => _BottleGameState();
}

class _BottleGameState extends State<BottleGame>
    with SingleTickerProviderStateMixin {
  GameArgs get a => widget.args;
  late final AnimationController _c;
  List<String> _names = [];
  double _rot = 0;
  double _from = 0;
  double _to = 0;
  int? _hit;
  int _lastSeat = -1;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _names = _seat(a.pool);
    _c = AnimationController(vsync: this)..addListener(_frame);
  }

  @override
  void didUpdateWidget(covariant BottleGame old) {
    super.didUpdateWidget(old);
    if (!_spinning && _hit == null && a.pool.length <= _maxSeats) _names = a.pool;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _frame() {
    setState(() => _rot = _from + (_to - _from) * Curves.easeOutCubic.transform(_c.value));
    final n = _names.length;
    final seg = 2 * pi / n;
    final seat = (((_rot % (2 * pi)) + seg / 2) / seg).floor() % n;
    if (seat != _lastSeat) {
      _lastSeat = seat;
      a.tick();
    }
  }

  Future<void> _spin() async {
    final pool = a.startRound();
    if (pool.length < 2) return;
    final names = _seat(pool);
    final n = names.length;
    final seg = 2 * pi / n;
    final win = rng.nextInt(n);
    final jitter = (rng.nextDouble() - 0.5) * seg * 0.5;
    final target = win * seg + jitter;
    final base = _rot % (2 * pi);
    setState(() {
      _names = names;
      _hit = null;
      _spinning = true;
    });
    _from = base;
    _to = target + 2 * pi * (a.i('turns') + ((base - target) > 0 ? 1 : 0));
    _c.duration = Duration(milliseconds: a.ms('seconds'));
    await _c.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _hit = win;
      _spinning = false;
    });
    a.onPick(names[win]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = min(box.maxWidth, 340.0);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Circle(
            size: size,
            names: _names,
            highlight: _hit,
            center: Transform.rotate(
              angle: _rot,
              child: CustomPaint(
                  size: Size(size * 0.18, size * 0.5), painter: const _BottlePainter()),
            ),
          ),
          const SizedBox(height: 14),
          GoButton(label: 'Spin', onPressed: _spinning ? null : _spin),
          const SizedBox(height: 10),
          Text(
            a.pool.length > _maxSeats
                ? '$_maxSeats of ${a.pool.length} places sit in, drawn fresh each spin'
                : '${_names.length} places in the circle',
            style: stageHint,
          ),
        ],
      );
    });
  }
}

class _BottlePainter extends CustomPainter {
  const _BottlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final glass = Paint()..color = const Color(0xFF3FA36B);
    final shine = Paint()..color = Colors.white.withAlpha(90);
    // Body
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, h * 0.42, w, h * 0.58), Radius.circular(w * 0.35)),
        glass);
    // Shoulders and neck
    final neck = Path()
      ..moveTo(0, h * 0.5)
      ..quadraticBezierTo(0, h * 0.3, w * 0.35, h * 0.22)
      ..lineTo(w * 0.35, h * 0.04)
      ..lineTo(w * 0.65, h * 0.04)
      ..lineTo(w * 0.65, h * 0.22)
      ..quadraticBezierTo(w, h * 0.3, w, h * 0.5)
      ..close();
    canvas.drawPath(neck, glass);
    // Cap points the way
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.3, 0, w * 0.4, h * 0.07), const Radius.circular(3)),
        Paint()..color = Felt.coral);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.18, h * 0.5, w * 0.14, h * 0.4), Radius.circular(w)),
        shine);
  }

  @override
  bool shouldRepaint(_BottlePainter old) => false;
}

class PotatoGame extends StatefulWidget {
  const PotatoGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<PotatoGame> createState() => _PotatoGameState();
}

class _PotatoGameState extends State<PotatoGame> {
  GameArgs get a => widget.args;
  List<String> _names = [];
  int _holder = 0;
  int? _hit;
  bool _running = false;
  String _status = 'Pass the potato!';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _names = _seat(a.pool);
  }

  @override
  void didUpdateWidget(covariant PotatoGame old) {
    super.didUpdateWidget(old);
    if (!_running && _hit == null && a.pool.length <= _maxSeats) _names = a.pool;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    final pool = a.startRound();
    if (pool.length < 2) return;
    final names = _seat(pool);
    final lo = a.d('min');
    final hi = max(lo, a.d('max'));
    final seconds = lo + rng.nextDouble() * (hi - lo);
    final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
    // The winner is picked fairly; the potato keeps moving until it reaches them.
    final win = rng.nextInt(names.length);
    setState(() {
      _names = names;
      _hit = null;
      _running = true;
      _holder = rng.nextInt(names.length);
      _status = 'Passing…';
    });

    void pass() {
      if (!mounted) return;
      final timeUp = DateTime.now().isAfter(end);
      if (timeUp && _holder == win) {
        setState(() {
          _hit = win;
          _running = false;
          _status = 'Time’s up!';
        });
        a.thump();
        a.onPick(names[win]);
        return;
      }
      setState(() {
        if (timeUp && a.b('random')) {
          _holder = win;
        } else if (a.b('random')) {
          var next = rng.nextInt(names.length - 1);
          if (next >= _holder) next++;
          _holder = next;
        } else {
          _holder = (_holder + 1) % names.length;
        }
      });
      a.tick();
      _timer = Timer(Duration(milliseconds: timeUp ? 320 : 200), pass);
    }

    _timer = Timer(const Duration(milliseconds: 300), pass);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = min(box.maxWidth, 340.0);
      final r = size / 2 - 48 - 26;
      final o = _Circle.seatOffset(_holder, max(1, _names.length), r);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_status, style: stageStatus),
          const SizedBox(height: 6),
          _Circle(
            size: size,
            names: _names,
            highlight: _hit ?? (_running ? _holder : null),
            overlay: AnimatedPositioned(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOut,
              left: size / 2 + o.dx - 20,
              top: size / 2 + o.dy - 20,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Center(child: Text('🥔', style: TextStyle(fontSize: 30))),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GoButton(label: 'Start passing', onPressed: _running ? null : _start),
          const SizedBox(height: 10),
          Text('Whoever holds the potato when time runs out wins.',
              textAlign: TextAlign.center, style: stageHint),
        ],
      );
    });
  }
}
