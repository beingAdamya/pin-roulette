import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

class CardsGame extends StatefulWidget {
  const CardsGame({super.key, required this.args});

  final GameArgs args;

  @override
  State<CardsGame> createState() => _CardsGameState();
}

class _CardsGameState extends State<CardsGame> {
  List<String> _hand = [];
  int? _picked;
  bool _reveal = false;
  int _deal = 0;

  List<String> _dealFrom(List<String> pool) =>
      shuffled(pool).take(min(widget.args.i('count'), pool.length)).toList();

  @override
  void initState() {
    super.initState();
    _hand = _dealFrom(widget.args.pool);
  }

  void _newDeal() {
    final pool = widget.args.startRound();
    if (pool.length < 2) return;
    setState(() {
      _hand = _dealFrom(pool);
      _picked = null;
      _reveal = false;
      _deal++;
    });
  }

  void _tap(int i) {
    if (_picked != null) return;
    setState(() => _picked = i);
    thump(widget.args.haptics);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() => _reveal = widget.args.b('revealAll'));
      widget.args.onPick(_hand[i]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final cols = _hand.length <= 4 ? max(2, _hand.length) : (w >= 420 ? 4 : 3);
      final cw = min(120.0, (w - (cols - 1) * 10) / cols);
      final ch = cw * 1.4;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _picked == null
                ? '${_hand.length} cards face down. Tap one.'
                : 'Your card',
            style: stageHint,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < _hand.length; i++)
                SizedBox(
                  width: cw,
                  height: ch,
                  child: _DealIn(
                    key: ValueKey('$_deal-$i'),
                    index: i,
                    child: GestureDetector(
                      onTap: () => _tap(i),
                      child: _FlipCard(
                        name: _hand[i],
                        flipped: _picked == i || _reveal,
                        winner: _picked == i,
                        dim: _reveal && _picked != i,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          GoButton(label: 'Shuffle & deal', onPressed: _newDeal),
        ],
      );
    });
  }
}

class _DealIn extends StatefulWidget {
  const _DealIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_DealIn> createState() => _DealInState();
}

class _DealInState extends State<_DealIn> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 40 + widget.index * 70), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, -0.6),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: _shown ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: widget.child,
      ),
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.name,
    required this.flipped,
    required this.winner,
    required this.dim,
  });

  final String name;
  final bool flipped;
  final bool winner;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: flipped ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, v, _) {
        final front = v > 0.5;
        return Opacity(
          opacity: dim ? 0.5 : 1.0,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(v * pi),
            child: front
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(pi),
                    child: _face(),
                  )
                : _back(),
          ),
        );
      },
    );
  }

  Widget _back() => Container(
        decoration: BoxDecoration(
          color: Felt.coral,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Felt.ink, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: const Center(child: Icon(Icons.place, color: Felt.ink, size: 34)),
      );

  Widget _face() => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Felt.ink,
          borderRadius: BorderRadius.circular(12),
          border: winner ? Border.all(color: Felt.gold, width: 3) : null,
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Felt.text, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      );
}
