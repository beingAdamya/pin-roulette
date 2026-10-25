import 'package:flutter/material.dart';

enum SettingKind { toggle, slider, choice }

/// One setting a game offers. Values are stored under "gameId.key".
class SettingSpec {
  const SettingSpec.toggle(this.key, this.label, bool this.def,
      {this.help, this.showIfKey, this.showIfValue})
      : kind = SettingKind.toggle,
        min = 0,
        max = 1,
        step = 1,
        unit = '',
        options = const [];

  const SettingSpec.slider(
      this.key, this.label, num this.def, this.min, this.max, this.step,
      {this.unit = '', this.help, this.showIfKey, this.showIfValue})
      : kind = SettingKind.slider,
        options = const [];

  const SettingSpec.choice(this.key, this.label, int this.def, this.options,
      {this.help, this.showIfKey, this.showIfValue})
      : kind = SettingKind.choice,
        min = 0,
        max = 0,
        step = 1,
        unit = '';

  final String key;
  final String label;
  final SettingKind kind;
  final Object def;
  final num min;
  final num max;
  final num step;
  final String unit;
  final List<String> options;
  final String? help;
  final String? showIfKey;
  final Object? showIfValue;

  int get divisions => ((max - min) / step).round().clamp(1, 1000);

  String format(num v) {
    final text = step < 0.1
        ? v.toStringAsFixed(2)
        : step < 1
            ? v.toStringAsFixed(1)
            : '${v.round()}';
    return unit.isEmpty ? text : '$text $unit';
  }
}

class GameSpec {
  const GameSpec({
    required this.id,
    required this.name,
    required this.icon,
    required this.blurb,
    this.settings = const [],
  });

  final String id;
  final String name;
  final IconData icon;
  final String blurb;
  final List<SettingSpec> settings;
}

const generalSettings = <SettingSpec>[
  SettingSpec.toggle('removeWinner', 'Take the winner out of play', false,
      help: 'The picked place is switched off when the next round starts. '
          'Turn it back on in Places.'),
  SettingSpec.toggle('haptics', 'Vibration', true,
      help: 'Ticks while spinning, rolling and racing.'),
  SettingSpec.slider('historySize', 'History length', 20, 5, 50, 1),
];

const games = <GameSpec>[
  GameSpec(
    id: 'wheel',
    name: 'Wheel',
    icon: Icons.donut_large_rounded,
    blurb: 'Spin a prize wheel with a slice for every place.',
    settings: [
      SettingSpec.slider('seconds', 'Spin time', 5, 2, 12, 0.5, unit: 's'),
      SettingSpec.slider('turns', 'Minimum full turns', 6, 2, 15, 1),
      SettingSpec.toggle('labels', 'Show names on the wheel', true),
      SettingSpec.choice('palette', 'Colours', 0, ['Table', 'Warm', 'Two-tone']),
    ],
  ),
  GameSpec(
    id: 'dice',
    name: 'Dice',
    icon: Icons.casino_outlined,
    blurb: 'Roll a die with one face per place, or any number of faces.',
    settings: [
      SettingSpec.choice('mode', 'Number of faces', 0, ['One per place', 'Choose n']),
      SettingSpec.slider('faces', 'Faces (n)', 6, 2, 100, 1,
          help: 'Fewer faces than places: a random n places go on the die. '
              'More faces than places: blank faces roll again.',
          showIfKey: 'mode',
          showIfValue: 1),
      SettingSpec.slider('seconds', 'Roll time', 1.4, 0.5, 5, 0.1, unit: 's'),
      SettingSpec.toggle('pips', 'Dots on dice with up to six faces', true),
    ],
  ),
  GameSpec(
    id: 'cards',
    name: 'Cards',
    icon: Icons.style_outlined,
    blurb: 'Places are dealt face down. Flip one.',
    settings: [
      SettingSpec.slider('count', 'Cards dealt', 6, 2, 16, 1,
          help: 'Never more than the places in play.'),
      SettingSpec.toggle('revealAll', 'Show the other cards after a pick', true),
    ],
  ),
  GameSpec(
    id: 'slots',
    name: 'Slots',
    icon: Icons.view_column_outlined,
    blurb: 'Pull the lever and watch the reel stop on a place.',
    settings: [
      SettingSpec.slider('seconds', 'Reel spin time', 3.5, 1.5, 8, 0.5, unit: 's'),
    ],
  ),
  GameSpec(
    id: 'knockout',
    name: 'Knockout',
    icon: Icons.emoji_events_outlined,
    blurb: 'Places drop out one by one until one is left.',
    settings: [
      SettingSpec.slider('ms', 'Time between knockouts', 450, 120, 1500, 10, unit: 'ms'),
      SettingSpec.toggle('suspense', 'Speed up early, slow down at the end', true),
    ],
  ),
  GameSpec(
    id: 'coin',
    name: 'Coin Bracket',
    icon: Icons.monetization_on_outlined,
    blurb: 'A coin-toss tournament. Every match is heads or tails.',
    settings: [
      SettingSpec.slider('seconds', 'Coin flip time', 1, 0.4, 2.5, 0.1, unit: 's'),
    ],
  ),
  GameSpec(
    id: 'rps',
    name: 'Rock Paper Scissors',
    icon: Icons.back_hand_outlined,
    blurb: 'A rock-paper-scissors tournament. Ties play again.',
    settings: [
      SettingSpec.slider('seconds', 'Time per throw', 0.9, 0.4, 2, 0.1, unit: 's'),
    ],
  ),
  GameSpec(
    id: 'plinko',
    name: 'Plinko',
    icon: Icons.blur_on,
    blurb: 'Drop a ball through the pegs into a place’s slot.',
    settings: [
      SettingSpec.slider('rows', 'Rows of pegs', 9, 5, 14, 1),
      SettingSpec.slider('seconds', 'Drop time', 3, 1.5, 7, 0.5, unit: 's'),
    ],
  ),
  GameSpec(
    id: 'bottle',
    name: 'Spin the Bottle',
    icon: Icons.wine_bar_outlined,
    blurb: 'Places sit in a circle. The bottle points to one.',
    settings: [
      SettingSpec.slider('seconds', 'Spin time', 4, 1.5, 10, 0.5, unit: 's'),
      SettingSpec.slider('turns', 'Minimum full turns', 5, 2, 12, 1),
    ],
  ),
  GameSpec(
    id: 'scratch',
    name: 'Scratch Card',
    icon: Icons.confirmation_number_outlined,
    blurb: 'Scratch off the silver to see where you’re going.',
    settings: [
      SettingSpec.slider('brush', 'Coin size', 34, 18, 64, 2, unit: 'px'),
      SettingSpec.slider('reveal', 'Reveal after scratching', 55, 25, 85, 5, unit: '%'),
    ],
  ),
  GameSpec(
    id: 'lottery',
    name: 'Lottery Drum',
    icon: Icons.bubble_chart_outlined,
    blurb: 'Numbered balls tumble in the drum until one drops out.',
    settings: [
      SettingSpec.slider('seconds', 'Mixing time', 3.5, 1.5, 8, 0.5, unit: 's'),
      SettingSpec.slider('speed', 'Ball speed', 1.6, 0.6, 3, 0.1),
    ],
  ),
  GameSpec(
    id: 'shells',
    name: 'Shell Game',
    icon: Icons.local_cafe_outlined,
    blurb: 'Cups hide places. Watch the shuffle, then pick a cup.',
    settings: [
      SettingSpec.slider('cups', 'Cups', 3, 2, 6, 1),
      SettingSpec.slider('swaps', 'Swaps', 10, 3, 25, 1),
      SettingSpec.slider('ms', 'Swap speed', 350, 150, 800, 50, unit: 'ms'),
      SettingSpec.toggle('peek', 'Show what’s under the cups first', true),
    ],
  ),
  GameSpec(
    id: 'cookie',
    name: 'Fortune Cookie',
    icon: Icons.cookie_outlined,
    blurb: 'Tap the cookie until it cracks open.',
    settings: [
      SettingSpec.slider('taps', 'Taps to crack', 3, 1, 6, 1),
      SettingSpec.toggle('fortunes', 'Write it as a fortune', true),
    ],
  ),
  GameSpec(
    id: 'eightball',
    name: 'Mystery Ball',
    icon: Icons.blur_circular,
    blurb: 'Shake the ball and the answer floats up.',
    settings: [
      SettingSpec.slider('seconds', 'Shake time', 1.8, 0.8, 4, 0.1, unit: 's'),
    ],
  ),
  GameSpec(
    id: 'darts',
    name: 'Darts',
    icon: Icons.adjust,
    blurb: 'Throw a dart at a board split into places.',
    settings: [
      SettingSpec.choice('mode', 'Throw', 0, ['Random throw', 'Aim yourself']),
      SettingSpec.slider('wobble', 'Aim wobble speed', 0.8, 0.3, 2, 0.1,
          showIfKey: 'mode', showIfValue: 1),
    ],
  ),
  GameSpec(
    id: 'race',
    name: 'Horse Race',
    icon: Icons.flag_outlined,
    blurb: 'Every place gets a horse. First past the post wins.',
    settings: [
      SettingSpec.slider('seconds', 'Race length', 6, 3, 15, 1, unit: 's'),
      SettingSpec.slider('lanes', 'Most horses', 8, 2, 12, 1,
          help: 'With more places than lanes, a random set races.'),
    ],
  ),
  GameSpec(
    id: 'potato',
    name: 'Hot Potato',
    icon: Icons.local_fire_department_outlined,
    blurb: 'The potato gets passed round. Whoever holds it at the end wins.',
    settings: [
      SettingSpec.slider('min', 'Shortest round', 3, 2, 10, 1, unit: 's'),
      SettingSpec.slider('max', 'Longest round', 9, 4, 20, 1, unit: 's'),
      SettingSpec.toggle('random', 'Pass to anyone (not just the next place)', false),
    ],
  ),
  GameSpec(
    id: 'claw',
    name: 'Claw Machine',
    icon: Icons.precision_manufacturing_outlined,
    blurb: 'Time the drop and grab a prize capsule.',
    settings: [
      SettingSpec.slider('prizes', 'Capsules', 8, 3, 10, 1),
      SettingSpec.slider('speed', 'Claw speed', 0.5, 0.2, 1.2, 0.1),
      SettingSpec.slider('grip', 'Grip strength', 70, 30, 100, 5, unit: '%',
          help: 'Lower grip means the capsule slips more often.'),
    ],
  ),
  GameSpec(
    id: 'straws',
    name: 'Draw Straws',
    icon: Icons.bar_chart,
    blurb: 'Everyone draws a straw. The longest one wins.',
    settings: [
      SettingSpec.slider('count', 'Straws', 6, 2, 12, 1),
      SettingSpec.toggle('shortest', 'Shortest straw wins instead', false),
      SettingSpec.slider('ms', 'Time per straw', 400, 150, 900, 50, unit: 'ms'),
    ],
  ),
  GameSpec(
    id: 'ducks',
    name: 'Duck Pond',
    icon: Icons.water,
    blurb: 'Ducks swim round with places underneath. Catch one.',
    settings: [
      SettingSpec.slider('count', 'Ducks', 6, 2, 12, 1),
      SettingSpec.slider('speed', 'Swim speed', 0.15, 0.05, 0.4, 0.05),
    ],
  ),
  GameSpec(
    id: 'number',
    name: 'Number Draw',
    icon: Icons.numbers,
    blurb: 'Each place gets a number. The counter rolls to one.',
    settings: [
      SettingSpec.slider('seconds', 'Roll time', 2.5, 1, 6, 0.5, unit: 's'),
      SettingSpec.toggle('list', 'Show the numbered list', true),
    ],
  ),
  GameSpec(
    id: 'balloons',
    name: 'Balloon Pop',
    icon: Icons.celebration_outlined,
    blurb: 'Balloons float up with places inside. Pop one.',
    settings: [
      SettingSpec.slider('count', 'Balloons', 7, 2, 12, 1),
      SettingSpec.slider('speed', 'Rise speed', 0.14, 0.05, 0.4, 0.01),
    ],
  ),
];

GameSpec gameById(String id) =>
    games.firstWhere((g) => g.id == id, orElse: () => games.first);

/// Every setting by its stored key, for defaults and validation.
final Map<String, SettingSpec> specIndex = {
  for (final s in generalSettings) 'general.${s.key}': s,
  for (final g in games)
    for (final s in g.settings) '${g.id}.${s.key}': s,
};
