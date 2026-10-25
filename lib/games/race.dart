import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// A horse race. Every horse runs the same random rules, so each has the same
/// chance of winning.
class RaceGame extends StatefulWidget {
  const RaceGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<RaceGame> createState() => _RaceGameState();
}

class _RaceGameState extends State<RaceGame> with SingleTickerProviderStateMixin {
  GameArgs get a => widget.args;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  List<String> _names = [];
  String _poolKey = '';
  List<double> _pos = [];
  List<double> _pace = [];
  int? _winner;
  bool _running = false;
  double _tickAcc = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _setField(a.pool);
  }

  @override
  void didUpdateWidget(covariant RaceGame old) {
    super.didUpdateWidget(old);
    if (!_running && _winner == null && a.pool.join('\u0000') != _poolKey) _setField(a.pool);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _setField(List<String> pool) {
    _poolKey = pool.join('\u0000');
    final lanes = a.i('lanes');
    _names = pool.length <= lanes ? List<String>.of(pool) : shuffled(pool).take(lanes).toList();
    _pos = List<double>.filled(_names.length, 0);
    _pace = List<double>.filled(_names.length, 1);
  }

  void _start() {
    final pool = a.startRound();
    if (pool.length < 2) return;
    _setField(pool);
    setState(() {
      _winner = null;
      _running = true;
    });
    _last = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    final base = 1 / a.d('seconds');
    int? leader;
    for (var i = 0; i < _pos.length; i++) {
      // Each horse's pace drifts at random; occasional bursts and stumbles.
      _pace[i] = (_pace[i] + (rng.nextDouble() - 0.5) * 0.9 * dt * 6).clamp(0.55, 1.5);
      if (rng.nextDouble() < dt * 0.6) _pace[i] = 1.25 + rng.nextDouble() * 0.3;
      if (rng.nextDouble() < dt * 0.4) _pace[i] = 0.6;
      _pos[i] += base * _pace[i] * dt;
      if (_pos[i] >= 1 && (leader == null || _pos[i] > _pos[leader])) leader = i;
    }
    _tickAcc += dt;
    if (_tickAcc > 0.16) {
      _tickAcc = 0;
      a.tick();
    }
    if (leader != null) {
      _ticker.stop();
      _pos[leader] = 1;
      setState(() {
        _winner = leader;
        _running = false;
      });
      a.thump();
      a.onPick(_names[leader]);
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_winner != null ? 'Photo finish!' : (_running ? 'And they’re off!' : 'Horses to the gate'),
            style: stageStatus),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF8C6239).withAlpha(90),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _names.length; i++) _lane(i),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GoButton(label: _winner == null ? 'Start race' : 'Race again', onPressed: _running ? null : _start),
        const SizedBox(height: 10),
        Text(
          a.pool.length > _names.length
              ? '${_names.length} of ${a.pool.length} places race, drawn fresh each race'
              : '${_names.length} horses',
          style: stageHint,
        ),
      ],
    );
  }

  Widget _lane(int i) {
    final won = _winner == i;
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: Text(
                _names[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: won ? Felt.gold : Felt.ink,
                  fontWeight: won ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final track = box.maxWidth - 34;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 6,
                    top: 16,
                    child: Container(height: 1, color: Felt.ink.withAlpha(50)),
                  ),
                  Positioned(
                    right: 6,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 3, color: Felt.ink.withAlpha(won ? 255 : 150)),
                  ),
                  Positioned(
                    left: (_pos.length > i ? _pos[i] : 0) * track,
                    top: 2,
                    child: Transform.flip(
                      flipX: true,
                      child: Text('🏇', style: TextStyle(fontSize: won ? 26 : 22)),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
