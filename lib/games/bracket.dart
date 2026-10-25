import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'common.dart';

enum BracketKind { coin, rps }

/// A knockout tournament. Each match is settled by a coin toss or by
/// rock-paper-scissors. Byes go through to the next round.
class BracketGame extends StatefulWidget {
  const BracketGame({super.key, required this.args, required this.kind});

  final GameArgs args;
  final BracketKind kind;

  @override
  State<BracketGame> createState() => _BracketGameState();
}

class _BracketGameState extends State<BracketGame>
    with SingleTickerProviderStateMixin {
  static const _throws = ['✊', '✋', '✌️'];
  static const _throwNames = ['Rock', 'Paper', 'Scissors'];

  GameArgs get a => widget.args;
  bool get _coin => widget.kind == BracketKind.coin;

  late final AnimationController _c;
  bool _running = false;
  List<String> _alive = [];
  String? _left;
  String? _right;
  String? _champion;
  int? _matchWinner;
  bool _heads = true;
  int _lt = 0;
  int _rt = 0;
  bool _showThrow = false;
  String _status = '';
  String _detail = '';

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this)..addListener(() => setState(() {}));
    _alive = a.pool;
    _status = '${_alive.length} places in the bracket';
  }

  @override
  void didUpdateWidget(covariant BracketGame old) {
    super.didUpdateWidget(old);
    if (!_running && _left == null && _champion == null) {
      _alive = a.pool;
      _status = '${_alive.length} places in the bracket';
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  String _roundName(int players, int round) {
    if (players == 2) return 'Final';
    if (players <= 4) return 'Semi-final';
    return 'Round $round';
  }

  Future<void> _start() async {
    final pool = a.startRound();
    if (pool.length < 2) return;
    setState(() {
      _running = true;
      _champion = null;
      _alive = shuffled(pool);
    });
    var round = 0;
    while (_alive.length > 1) {
      round++;
      final list = _alive;
      final next = <String>[];
      final label = _roundName(list.length, round);
      for (var i = 0; i < list.length; i += 2) {
        if (!mounted) return;
        if (i + 1 >= list.length) {
          next.add(list[i]); // bye
          continue;
        }
        final w = await _match(list[i], list[i + 1], label);
        if (!mounted) return;
        next.add(w);
      }
      _alive = shuffled(next);
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _champion = _alive.first;
      _left = null;
      _right = null;
      _status = 'Champion';
      _detail = '';
    });
    a.onPick(_alive.first);
  }

  Future<String> _match(String l, String r, String label) async {
    setState(() {
      _left = l;
      _right = r;
      _matchWinner = null;
      _showThrow = false;
      _status = label;
      _detail = _coin ? 'Heads: $l · Tails: $r' : '';
    });
    await _wait(450);
    if (!mounted) return l;
    _c.duration = Duration(milliseconds: a.ms('seconds'));

    if (_coin) {
      final heads = rng.nextBool();
      await _c.forward(from: 0);
      if (!mounted) return l;
      setState(() {
        _heads = heads;
        _matchWinner = heads ? 0 : 1;
      });
      a.tick();
    } else {
      while (true) {
        setState(() => _showThrow = false);
        await _c.forward(from: 0);
        if (!mounted) return l;
        final lt = rng.nextInt(3);
        final rt = rng.nextInt(3);
        a.tick();
        if (lt == rt) {
          setState(() {
            _lt = lt;
            _rt = rt;
            _showThrow = true;
            _detail = 'Both threw ${_throwNames[lt]}. Again!';
          });
          await _wait(800);
          if (!mounted) return l;
          continue;
        }
        // Paper beats rock, scissors beat paper, rock beats scissors.
        final leftWins = (lt - rt + 3) % 3 == 1;
        setState(() {
          _lt = lt;
          _rt = rt;
          _showThrow = true;
          _matchWinner = leftWins ? 0 : 1;
          final w = leftWins ? lt : rt;
          final lo = leftWins ? rt : lt;
          _detail = '${_throwNames[w]} beats ${_throwNames[lo]}';
        });
        break;
      }
    }
    await _wait(900);
    return _matchWinner == 0 ? l : r;
  }

  Widget _side(int i, String name) {
    final won = _matchWinner == i;
    final lost = _matchWinner != null && !won;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_coin) _hand(i),
        if (!_coin) const SizedBox(height: 8),
        NameChip(name, highlight: won, dim: lost, maxWidth: 130, fontSize: 13),
      ],
    );
  }

  Widget _hand(int i) {
    final v = _c.value;
    final bob = _c.isAnimating ? -sin(v * pi * 3).abs() * 18 : 0.0;
    final glyph = _showThrow ? _throws[i == 0 ? _lt : _rt] : '✊';
    return Transform.translate(
      offset: Offset(0, bob),
      child: Transform.flip(
        flipX: i == 1,
        child: Text(glyph, style: const TextStyle(fontSize: 52)),
      ),
    );
  }

  Widget _coinWidget() {
    final v = _c.value;
    const flips = 7;
    final spinning = _c.isAnimating;
    final scaleY = spinning ? cos(v * pi * flips).abs().clamp(0.08, 1.0) : 1.0;
    final face = spinning ? ((v * flips * 2).floor().isEven ? 'H' : 'T') : (_heads ? 'H' : 'T');
    final lift = spinning ? -sin(v * pi) * 30 : 0.0;
    return Transform.translate(
      offset: Offset(0, lift),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(1, scaleY, 1),
        child: Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                colors: [Color(0xFFF2CF63), Felt.gold], center: Alignment(-0.3, -0.4)),
            boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 5))],
          ),
          child: Center(
            child: Text(face,
                style: const TextStyle(
                    color: Color(0xFF6B4C06), fontSize: 36, fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final left = _left;
    final right = _right;
    final champ = _champion;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_status, style: stageStatus),
        const SizedBox(height: 18),
        SizedBox(
          height: _coin ? 130 : 120,
          child: champ != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events, color: Felt.gold, size: 54),
                      const SizedBox(height: 8),
                      NameChip(champ, highlight: true, maxWidth: 260, fontSize: 16),
                    ],
                  ),
                )
              : (left == null || right == null)
                  ? Center(
                      child: Text(
                        _coin
                            ? 'Places are paired up. A coin toss settles each match.'
                            : 'Places are paired up. Rock, paper, scissors settles each match.',
                        textAlign: TextAlign.center,
                        style: stageHint,
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(child: Center(child: _side(0, left))),
                        _coin
                            ? _coinWidget()
                            : const Text('vs',
                                style: TextStyle(
                                    color: Felt.ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18)),
                        Expanded(child: Center(child: _side(1, right))),
                      ],
                    ),
        ),
        SizedBox(
          height: 22,
          child: Text(_detail,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: stageHint),
        ),
        const SizedBox(height: 14),
        GoButton(
            label: champ == null ? 'Start bracket' : 'Play again',
            onPressed: _running ? null : _start),
        const SizedBox(height: 10),
        Text(_running ? '${_alive.length} still in' : '${a.pool.length} places',
            style: stageHint),
      ],
    );
  }
}
