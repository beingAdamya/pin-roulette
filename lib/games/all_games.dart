import 'package:flutter/material.dart';

import 'bracket.dart';
import 'cards.dart';
import 'circle.dart';
import 'claw.dart';
import 'common.dart';
import 'darts.dart';
import 'dice.dart';
import 'floaters.dart';
import 'knockout.dart';
import 'lottery.dart';
import 'oracles.dart';
import 'plinko.dart';
import 'race.dart';
import 'scratch.dart';
import 'shells.dart';
import 'slots.dart';
import 'straws.dart';
import 'wheel.dart';

/// Builds the game with this id (ids are listed in game_specs.dart).
Widget buildGame(GameArgs args) {
  final key = ValueKey(args.id);
  switch (args.id) {
    case 'dice':
      return DiceGame(key: key, args: args);
    case 'cards':
      return CardsGame(key: key, args: args);
    case 'slots':
      return SlotsGame(key: key, args: args);
    case 'knockout':
      return KnockoutGame(key: key, args: args);
    case 'coin':
      return BracketGame(key: key, args: args, kind: BracketKind.coin);
    case 'rps':
      return BracketGame(key: key, args: args, kind: BracketKind.rps);
    case 'plinko':
      return PlinkoGame(key: key, args: args);
    case 'bottle':
      return BottleGame(key: key, args: args);
    case 'scratch':
      return ScratchGame(key: key, args: args);
    case 'lottery':
      return LotteryGame(key: key, args: args);
    case 'shells':
      return ShellsGame(key: key, args: args);
    case 'cookie':
      return CookieGame(key: key, args: args);
    case 'eightball':
      return MysteryBallGame(key: key, args: args);
    case 'darts':
      return DartsGame(key: key, args: args);
    case 'race':
      return RaceGame(key: key, args: args);
    case 'potato':
      return PotatoGame(key: key, args: args);
    case 'claw':
      return ClawGame(key: key, args: args);
    case 'straws':
      return StrawsGame(key: key, args: args);
    case 'ducks':
      return DucksGame(key: key, args: args);
    case 'number':
      return NumberGame(key: key, args: args);
    case 'balloons':
      return BalloonsGame(key: key, args: args);
    case 'wheel':
    default:
      return WheelGame(key: key, args: args);
  }
}
