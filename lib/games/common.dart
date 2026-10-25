import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart' as theme;

/// Starts a round and returns the places in play for it.
typedef StartRound = List<String> Function();

/// Reports the place chance picked.
typedef OnPick = void Function(String name);

/// Everything a game gets from the home screen.
class GameArgs {
  GameArgs({
    required this.id,
    required this.pool,
    required this.settings,
    required this.startRound,
    required this.onPick,
  });

  final String id;
  final List<String> pool;
  final Settings settings;
  final StartRound startRound;
  final OnPick onPick;

  /// This game's own settings.
  bool b(String key) => settings.b('$id.$key');
  double d(String key) => settings.d('$id.$key');
  int i(String key) => settings.i('$id.$key');
  int ms(String key) => (settings.d('$id.$key') * 1000).round();

  bool get haptics => settings.b('general.haptics');
  void tick() => theme.tick(haptics);
  void thump() => theme.thump(haptics);
}

/// Colours for balls, balloons, capsules and so on.
const toyColors = <Color>[
  Color(0xFFE0533D),
  Color(0xFFD9A521),
  Color(0xFF3E7CB1),
  Color(0xFF7A4E9C),
  Color(0xFF2F9C86),
  Color(0xFFE07A9B),
  Color(0xFF6BA34A),
  Color(0xFFF08A3C),
];

/// A numbered key of places, with one highlighted.
class PlaceLegend extends StatelessWidget {
  const PlaceLegend({super.key, required this.names, this.hit, this.maxHeight = 130});

  final List<String> names;
  final int? hit;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (var i = 0; i < names.length; i++)
              SizedBox(
                width: 140,
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text('${i + 1}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: theme.Felt.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        names[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: i == hit ? theme.Felt.gold : theme.Felt.ink,
                          fontWeight: i == hit ? FontWeight.w700 : FontWeight.w400,
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
    );
  }
}

/// A light pill showing a place name on the felt.
class NameChip extends StatelessWidget {
  const NameChip(this.name,
      {super.key, this.highlight = false, this.dim = false, this.maxWidth = 120, this.fontSize = 12});

  final String name;
  final bool highlight;
  final bool dim;
  final double maxWidth;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: dim ? 0.35 : 1.0,
      duration: const Duration(milliseconds: 250),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: highlight ? theme.Felt.gold : theme.Felt.ink,
          borderRadius: BorderRadius.circular(999),
          boxShadow: highlight
              ? const [BoxShadow(color: Colors.black38, blurRadius: 8)]
              : null,
        ),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: theme.Felt.text,
              fontWeight: FontWeight.w700,
              fontSize: fontSize),
        ),
      ),
    );
  }
}

/// A secondary outlined button that reads well on the felt.
class FeltButton extends StatelessWidget {
  const FeltButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.Felt.ink,
        side: const BorderSide(color: theme.Felt.ink),
        shape: const StadiumBorder(),
      ),
      child: Text(label),
    );
  }
}
