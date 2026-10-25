import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

class SlotsGame extends StatefulWidget {
  const SlotsGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<SlotsGame> createState() => _SlotsGameState();
}

class _SlotsGameState extends State<SlotsGame>
    with SingleTickerProviderStateMixin {
  static const _row = 56.0;

  late final AnimationController _c;
  List<String> _items = [];
  double _offset = 0; // index of the top visible row
  double _from = 0;
  double _to = 0;
  int _last = 0;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this)..addListener(_onFrame);
    final s = shuffled(widget.args.pool);
    _items = [s.last, ...s];
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onFrame() {
    setState(() => _offset =
        _from + (_to - _from) * Curves.easeOutQuart.transform(_c.value));
    final i = _offset.floor();
    if (i != _last) {
      _last = i;
      tick(widget.args.haptics);
    }
  }

  Future<void> _spin() async {
    final pool = widget.args.startRound();
    if (pool.length < 2) return;
    final win = pool[rng.nextInt(pool.length)];
    final top = _offset.round().clamp(0, _items.length - 3);
    // Keep the rows on screen now, then build a long reel ending on the winner.
    final next = <String>[_items[top], _items[top + 1], _items[top + 2]];
    while (next.length < 42) {
      next.addAll(shuffled(pool));
    }
    final items = next.sublist(0, 42);
    items[39] = win; // centre row when the top row is 38
    setState(() {
      _items = items;
      _offset = 0;
      _spinning = true;
    });
    _from = 0;
    _to = 38;
    _last = 0;
    _c.duration =
        Duration(milliseconds: (widget.args.d('seconds') * 1000).round());
    await _c.forward(from: 0);
    if (!mounted) return;
    setState(() => _spinning = false);
    widget.args.onPick(win);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = min(box.maxWidth, 360.0);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: w,
            height: _row * 3 + 12,
            decoration: BoxDecoration(
              color: Felt.ink,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Felt.gold, width: 6),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 8)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  top: -_offset * _row,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final name in _items)
                        SizedBox(
                          height: _row,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Felt.text,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: _row,
                  left: 0,
                  right: 0,
                  height: _row,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Felt.coral.withAlpha(24),
                        border: const Border.symmetric(
                            horizontal: BorderSide(color: Felt.coral, width: 2)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GoButton(label: 'Pull', onPressed: _spinning ? null : _spin),
          const SizedBox(height: 10),
          Text('${widget.args.pool.length} places on the reel', style: stageHint),
        ],
      );
    });
  }
}
