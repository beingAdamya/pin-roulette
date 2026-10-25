import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

class DiceGame extends StatefulWidget {
  const DiceGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<DiceGame> createState() => _DiceGameState();
}

class _DiceGameState extends State<DiceGame> {
  List<String?> _faces = [];
  String _key = '';
  int _value = 1;
  int? _hit;
  String? _label;
  bool _rolling = false;
  double _shake = 0;
  Timer? _timer;
  DateTime _t0 = DateTime.now();

  String _keyFor(List<String> pool) =>
      '${widget.args.i('mode') == 0}|${widget.args.i('faces')}|${pool.join('\u0000')}';

  /// One face per place, or n faces: fewer than the places means a random n go
  /// on the die; more means the spare faces are blank and roll again.
  void _buildFaces(List<String> pool) {
    final a = widget.args;
    final n = a.i('mode') == 0 ? pool.length : max(2, a.i('faces'));
    _faces = n >= pool.length
        ? List<String?>.generate(n, (i) => i < pool.length ? pool[i] : null)
        : List<String?>.of(shuffled(pool).take(n));
    _key = _keyFor(pool);
    _value = 1;
    _hit = null;
    _label = null;
  }

  @override
  void initState() {
    super.initState();
    _buildFaces(widget.args.pool);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _roll() {
    final pool = widget.args.startRound();
    if (pool.length < 2) return;
    if (_key != _keyFor(pool)) _buildFaces(pool);
    _go();
  }

  void _go() {
    setState(() {
      _rolling = true;
      _hit = null;
      _label = 'Rolling…';
    });
    _t0 = DateTime.now();
    _step();
  }

  void _step() {
    if (!mounted) return;
    final elapsed = DateTime.now().difference(_t0).inMilliseconds;
    final dur = (widget.args.d('seconds') * 1000).round();
    final n = _faces.length;
    if (elapsed < dur) {
      setState(() {
        _value = rng.nextInt(n) + 1;
        _shake = (rng.nextDouble() - 0.5) * 0.35;
      });
      tick(widget.args.haptics);
      _timer = Timer(Duration(milliseconds: 70 + elapsed ~/ 12), _step);
      return;
    }
    final v = rng.nextInt(n);
    final name = _faces[v];
    setState(() {
      _value = v + 1;
      _shake = 0;
      _hit = v;
      _label = name == null
          ? '${v + 1} · blank face, rolling again'
          : '${v + 1} → $name';
    });
    if (name == null) {
      _timer = Timer(const Duration(milliseconds: 700), _go);
      return;
    }
    setState(() => _rolling = false);
    widget.args.onPick(name);
  }

  @override
  Widget build(BuildContext context) {
    if (!_rolling && _hit == null && _key != _keyFor(widget.args.pool)) {
      _buildFaces(widget.args.pool);
    }
    final n = _faces.length;
    final hasBlank = _faces.contains(null);
    final subset = !hasBlank && n < widget.args.pool.length;
    final hint = hasBlank
        ? '$n-sided die · blank faces roll again'
        : subset
            ? '$n-sided die · $n of ${widget.args.pool.length} places on its faces'
            : '$n-sided die · one face per place';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        Transform.rotate(
          angle: _shake,
          child: _Die(value: _value, sides: n, pips: widget.args.b('pips')),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 26,
          child: Text(
            _label ?? 'd$n',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Felt.ink, fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GoButton(label: 'Roll', onPressed: _rolling ? null : _roll),
            if (subset)
              OutlinedButton(
                onPressed: _rolling
                    ? null
                    : () => setState(() => _buildFaces(widget.args.pool)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Felt.ink,
                  side: const BorderSide(color: Felt.ink),
                  shape: const StadiumBorder(),
                ),
                child: const Text('New faces'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(hint, style: stageHint, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 150),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                for (var i = 0; i < n; i++)
                  SizedBox(
                    width: 140,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text('${i + 1}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: Felt.gold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _faces[i] ?? '— roll again',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: i == _hit ? Felt.gold : Felt.ink,
                              fontWeight:
                                  i == _hit ? FontWeight.w700 : FontWeight.w400,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

const _pipLayout = <int, List<int>>{
  1: [4],
  2: [0, 8],
  3: [0, 4, 8],
  4: [0, 2, 6, 8],
  5: [0, 2, 4, 6, 8],
  6: [0, 2, 3, 5, 6, 8],
};

class _Die extends StatelessWidget {
  const _Die({required this.value, required this.sides, required this.pips});

  final int value;
  final int sides;
  final bool pips;

  @override
  Widget build(BuildContext context) {
    final dots = pips && sides <= 6 ? _pipLayout[value] : null;
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: Felt.ink,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: dots == null
          ? Center(
              child: Text(
                '$value',
                style: TextStyle(
                  color: Felt.text,
                  fontSize: value > 99 ? 46 : 60,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  for (var row = 0; row < 3; row++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var col = 0; col < 3; col++)
                            Expanded(
                              child: Center(
                                child: dots.contains(row * 3 + col)
                                    ? Container(
                                        width: 22,
                                        height: 22,
                                        decoration: const BoxDecoration(
                                            color: Felt.text,
                                            shape: BoxShape.circle),
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
