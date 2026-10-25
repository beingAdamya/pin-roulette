import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// Shared base for games where moving things hide places and you tap one:
/// the duck pond and balloon pop.
abstract class _FloaterState<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin<T> {
  GameArgs get a;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double clock = 0;
  List<String> names = [];
  List<double> seed = [];
  int? picked;
  String _poolKey = '';

  int get wanted;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = min(0.05, (elapsed - _last).inMicroseconds / 1e6);
      _last = elapsed;
      clock += dt;
      advance(dt);
      setState(() {});
    });
    fill(a.pool);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void advance(double dt) {}

  void fill(List<String> pool) {
    _poolKey = pool.join('\u0000');
    final k = min(wanted, pool.length);
    names = shuffled(pool).take(k).toList();
    seed = List<double>.generate(k, (_) => rng.nextDouble());
    picked = null;
  }

  void tapItem(int i) {
    if (picked != null) return;
    final pool = a.startRound();
    if (pool.length < 2) return;
    if (pool.join('\u0000') != _poolKey) {
      // The list changed since this round was set up; set up a fresh one.
      setState(() => fill(pool));
      return;
    }
    setState(() => picked = i);
    _ticker.stop();
    a.thump();
    a.onPick(names[i]);
  }

  void again() {
    final pool = a.startRound();
    if (pool.length < 2) return;
    setState(() => fill(pool));
    _last = Duration.zero;
    _ticker.start();
  }
}

/* ---------------- Duck pond ---------------- */

class DucksGame extends StatefulWidget {
  const DucksGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<DucksGame> createState() => _DucksGameState();
}

class _DucksGameState extends _FloaterState<DucksGame> {
  @override
  GameArgs get a => widget.args;

  @override
  int get wanted => a.i('count');

  double _angle = 0;

  @override
  void advance(double dt) => _angle += dt * a.d('speed') * 2 * pi;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = min(box.maxWidth, 360.0);
      final h = w * 0.72;
      final n = names.length;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(picked == null ? 'Tap a duck to see what’s underneath' : 'Lucky duck!', style: stageStatus),
          const SizedBox(height: 12),
          SizedBox(
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.elliptical(w / 2, h / 2)),
                      gradient: const RadialGradient(colors: [Color(0xFF5DB7E0), Color(0xFF2B7FB0)]),
                      border: Border.all(color: const Color(0xFF8C6239), width: 6),
                    ),
                  ),
                ),
                for (var i = 0; i < n; i++)
                  Builder(builder: (_) {
                    final ang = _angle + i * 2 * pi / n;
                    final bob = sin(clock * 3 + seed[i] * 6) * 3;
                    final x = w / 2 + cos(ang) * w * 0.33;
                    final y = h / 2 + sin(ang) * h * 0.28 + bob;
                    final isPick = picked == i;
                    return Positioned(
                      left: x - 40,
                      top: y - 26,
                      width: 80,
                      child: GestureDetector(
                        onTap: () => tapItem(i),
                        child: Center(
                          child: isPick
                              ? NameChip(names[i], highlight: true, maxWidth: 150, fontSize: 12)
                              : Opacity(
                                  opacity: picked == null ? 1.0 : 0.6,
                                  child: Transform.flip(
                                    flipX: cos(ang) < 0,
                                    child: const Text('🦆', style: TextStyle(fontSize: 40)),
                                  ),
                                ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GoButton(label: 'New pond', onPressed: picked == null ? null : again),
          const SizedBox(height: 10),
          Text(
            a.pool.length > n ? '$n of ${a.pool.length} places are on ducks' : '$n ducks',
            style: stageHint,
          ),
        ],
      );
    });
  }
}

/* ---------------- Balloon pop ---------------- */

class BalloonsGame extends StatefulWidget {
  const BalloonsGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<BalloonsGame> createState() => _BalloonsGameState();
}

class _BalloonsGameState extends _FloaterState<BalloonsGame> {
  @override
  GameArgs get a => widget.args;

  @override
  int get wanted => a.i('count');

  List<double> _y = [];

  @override
  void fill(List<String> pool) {
    super.fill(pool);
    _y = List<double>.generate(names.length, (i) => 0.25 + rng.nextDouble() * 0.85);
  }

  @override
  void advance(double dt) {
    final speed = a.d('speed');
    for (var i = 0; i < _y.length; i++) {
      _y[i] -= dt * speed * (0.75 + seed[i] * 0.5);
      if (_y[i] < -0.3) _y[i] = 1.1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = min(box.maxWidth, 360.0);
      const h = 300.0;
      final n = names.length;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(picked == null ? 'Pop a balloon' : 'Pop!', style: stageStatus),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: w,
              height: h,
              color: Colors.black.withAlpha(30),
              child: Stack(
                children: [
                  for (var i = 0; i < n; i++)
                    Builder(builder: (_) {
                      final x = (i + 0.5) / n * w + sin(clock * 1.4 + seed[i] * 6) * 8;
                      final y = (i < _y.length ? _y[i] : 0.5) * h;
                      final isPick = picked == i;
                      return Positioned(
                        left: x - 40,
                        top: y - 30,
                        width: 80,
                        child: GestureDetector(
                          onTap: () => tapItem(i),
                          child: Center(
                            child: isPick
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('💥', style: TextStyle(fontSize: 30)),
                                      NameChip(names[i], highlight: true, maxWidth: 150, fontSize: 12),
                                    ],
                                  )
                                : Opacity(
                                    opacity: picked == null ? 1.0 : 0.5,
                                    child: _Balloon(color: toyColors[i % toyColors.length]),
                                  ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GoButton(label: 'More balloons', onPressed: picked == null ? null : again),
          const SizedBox(height: 10),
          Text(
            a.pool.length > n ? '$n of ${a.pool.length} places are in balloons' : '$n balloons',
            style: stageHint,
          ),
        ],
      );
    });
  }
}

class _Balloon extends StatelessWidget {
  const _Balloon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 54,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(Radius.elliptical(22, 27)),
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.45),
              radius: 0.9,
              colors: [Color.lerp(color, Colors.white, 0.45)!, color],
            ),
          ),
        ),
        Container(width: 1.5, height: 26, color: Felt.ink.withAlpha(180)),
      ],
    );
  }
}
