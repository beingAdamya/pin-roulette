import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// Draw straws. Every place pulls one; the longest (or shortest) wins.
class StrawsGame extends StatefulWidget {
  const StrawsGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<StrawsGame> createState() => _StrawsGameState();
}

class _StrawsGameState extends State<StrawsGame> {
  GameArgs get a => widget.args;
  List<String> _names = [];
  List<double> _len = [];
  final Set<int> _pulled = {};
  int? _winner;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _deal(a.pool);
  }

  @override
  void didUpdateWidget(covariant StrawsGame old) {
    super.didUpdateWidget(old);
    if (!_running && _winner == null && _pulled.isEmpty) {
      final k = min(a.i('count'), a.pool.length);
      if (k != _names.length || !_names.every(a.pool.contains)) _deal(a.pool);
    }
  }

  void _deal(List<String> pool) {
    final k = min(a.i('count'), pool.length);
    _names = shuffled(pool).take(k).toList();
    // Evenly spread lengths, shuffled, so there's never a tie.
    final steps = List<double>.generate(k, (i) => 0.3 + 0.7 * (i + 0.5) / k);
    _len = shuffled(steps);
    _pulled.clear();
    _winner = null;
  }

  Future<void> _go() async {
    final pool = a.startRound();
    if (pool.length < 2) return;
    setState(() {
      _deal(pool);
      _running = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 400));
    for (var i = 0; i < _names.length; i++) {
      if (!mounted) return;
      setState(() => _pulled.add(i));
      a.tick();
      await Future<void>.delayed(Duration(milliseconds: a.i('ms')));
    }
    if (!mounted) return;
    final shortest = a.b('shortest');
    var best = 0;
    for (var i = 1; i < _len.length; i++) {
      if (shortest ? _len[i] < _len[best] : _len[i] > _len[best]) best = i;
    }
    setState(() {
      _winner = best;
      _running = false;
    });
    a.thump();
    a.onPick(_names[best]);
  }

  @override
  Widget build(BuildContext context) {
    const maxH = 170.0;
    final shortest = a.b('shortest');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(shortest ? 'Shortest straw wins' : 'Longest straw wins', style: stageStatus),
        const SizedBox(height: 14),
        Container(
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE7B98F),
            borderRadius: BorderRadius.circular(13),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
          ),
        ),
        SizedBox(
          height: maxH + 100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _names.length; i++)
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutBack,
                        width: 10,
                        height: (_pulled.contains(i) ? _len[i] : 0.12) * maxH,
                        decoration: BoxDecoration(
                          color: i == _winner ? Felt.gold : const Color(0xFFF2E6B8),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                          border: Border.all(color: Colors.black26),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: Text(
                            _names[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: i == _winner ? Felt.gold : Felt.ink,
                              fontWeight: i == _winner ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GoButton(label: _winner == null ? 'Draw straws' : 'Draw again', onPressed: _running ? null : _go),
        const SizedBox(height: 10),
        Text(
          a.pool.length > _names.length
              ? '${_names.length} of ${a.pool.length} places draw, picked fresh each time'
              : '${_names.length} straws',
          style: stageHint,
        ),
      ],
    );
  }
}
