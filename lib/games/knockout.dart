import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

class KnockoutGame extends StatefulWidget {
  const KnockoutGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<KnockoutGame> createState() => _KnockoutGameState();
}

class _KnockoutGameState extends State<KnockoutGame> {
  List<String> _names = [];
  final Set<int> _out = {};
  int? _last;
  bool _running = false;
  Timer? _timer;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _names = widget.args.pool;
    _status = '${_names.length} contenders';
  }

  @override
  void didUpdateWidget(KnockoutGame old) {
    super.didUpdateWidget(old);
    if (!_running && _last == null) {
      _names = widget.args.pool;
      _status = '${_names.length} contenders';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    final pool = widget.args.startRound();
    if (pool.length < 2) return;
    setState(() {
      _names = pool;
      _out.clear();
      _last = null;
      _running = true;
      _status = '${pool.length} contenders';
    });
    _timer = Timer(Duration(milliseconds: widget.args.i('ms')), _step);
  }

  void _step() {
    if (!mounted) return;
    final alive = [
      for (var i = 0; i < _names.length; i++)
        if (!_out.contains(i)) i
    ];
    if (alive.length <= 1) {
      setState(() {
        _last = alive.first;
        _running = false;
        _status = 'Last one standing';
      });
      widget.args.onPick(_names[alive.first]);
      return;
    }
    final gone = alive[rng.nextInt(alive.length)];
    final left = alive.length - 1;
    setState(() {
      _out.add(gone);
      _status = '$left left';
    });
    tick(widget.args.haptics);

    final base = widget.args.i('ms').toDouble();
    var delay = base;
    if (widget.args.b('suspense') && left > 1) {
      // Quick while the field is big, slower for the final few.
      delay = max(120.0, base * min(1.0, (left + 2) / 8) * (left > 3 ? 0.6 : 1.6));
    }
    _timer = Timer(Duration(milliseconds: delay.round()), _step);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_status, style: stageStatus),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _names.length; i++)
              AnimatedScale(
                scale: i == _last ? 1.15 : (_out.contains(i) ? 0.9 : 1.0),
                duration: const Duration(milliseconds: 300),
                child: AnimatedOpacity(
                  opacity: _out.contains(i) ? 0.25 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: i == _last ? Felt.gold : Felt.ink,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _names[i],
                      style: TextStyle(
                        color: Felt.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        decoration: _out.contains(i)
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        GoButton(label: 'Start knockout', onPressed: _running ? null : _start),
        const SizedBox(height: 10),
        const Text('Places drop out at random until one is left.',
            style: stageHint, textAlign: TextAlign.center),
      ],
    );
  }
}
