# Pin Roulette

An Android app that picks a place for you by chance. Give it a Google Maps link
or one of your saved lists, then let one of 22 games of chance decide where
you go.

## What it does

- **Share from Google Maps.** In Google Maps, share a place, a set of
  directions or one of your saved lists and choose *Pin Roulette*. Short
  `maps.app.goo.gl` links are opened automatically.
- **Paste a link or type names**, one per line, on the Places screen.
- **Import a Google Takeout file** (`.csv` per saved list, or
  `Saved Places.json` for starred places).
- **22 games**, each with its own settings (tap the sliders icon on the game table):
  | Game | How it picks | Settings |
  |---|---|---|
  | Wheel | Spin a prize wheel | spin time, turns, names, colours |
  | Dice | Roll a die with a face per place, or any n | faces, roll time, dots |
  | Cards | Flip one of the face-down cards | cards dealt, reveal the rest |
  | Slots | Pull the lever, the reel stops on a place | spin time |
  | Knockout | Places drop out until one is left | speed, suspense |
  | Coin Bracket | Coin-toss tournament | flip time |
  | Rock Paper Scissors | Rock-paper-scissors tournament | throw time |
  | Plinko | Ball bounces through pegs into a slot | rows, drop time |
  | Spin the Bottle | Bottle points at a place in the circle | spin time, turns |
  | Scratch Card | Scratch off the silver | coin size, reveal point |
  | Lottery Drum | Numbered balls mix, one drops out | mixing time, ball speed |
  | Shell Game | Watch the cups shuffle, pick one | cups, swaps, speed, peek |
  | Fortune Cookie | Tap until it cracks | taps, fortune wording |
  | Mystery Ball | Shake for an answer | shake time |
  | Darts | Throw at a board split into places | random or aim yourself, wobble |
  | Horse Race | First horse past the post | race length, lanes |
  | Hot Potato | Whoever holds it at time-up | shortest/longest round, pass style |
  | Claw Machine | Time the drop, grab a capsule | capsules, claw speed, grip |
  | Draw Straws | Longest (or shortest) straw | straws, shortest wins, speed |
  | Duck Pond | Catch a swimming duck | ducks, swim speed |
  | Number Draw | Counter rolls to a number | roll time, numbered list |
  | Balloon Pop | Pop a rising balloon | balloons, rise speed |

  Games with a fixed number of spots (darts, plinko, race, cups and so on)
  draw a fresh random set of places each round when you have more places than
  spots, so every place still gets its chance.
- **General settings**: take each winner out of play, vibration, history length.
- **Open in Google Maps** and **Copy** on every result, plus a pick history.

## Download

Get **pin-roulette.apk** from the [latest release](../../releases/latest) and open
it on your Android phone. The first time, Android asks you to allow installs
from your browser or Files app.

The APK is signed with a debug key, which is fine for installing yourself but
not for the Play Store.

## Releasing a new version

Every push to `main` builds a test APK (open the run under **Actions** and
download it from *Artifacts*). To publish a release, push a version tag:

```bash
git tag v1.0.1
git push origin v1.0.1
```

The workflow builds the APK and attaches it to a new GitHub Release.

## Build it on your computer

You need Flutter (3.24 or newer) and Android Studio's SDK.

```bash
cd pin_roulette
flutter create --org com.pinroulette --project-name pin_roulette --platforms android .
dart tool/setup_android.dart
flutter pub get
flutter run            # with your phone connected, or
flutter build apk      # APK in build/app/outputs/flutter-apk/
```

`flutter create` only adds the missing Android files; it leaves `lib/` alone.
`tool/setup_android.dart` then adds the share-menu entry, internet access, the
app name and the native code in `MainActivity.kt`.

## How the code is laid out

```
lib/
  main.dart            Home screen: places bar, game table, result card
  models.dart          Places, settings, history, saving (shared_preferences)
  importer.dart        Reads links, short links, shared lists and Takeout files
  import_flow.dart     Progress dialog, "replace or add?", result message
  native_bridge.dart   Talks to MainActivity.kt
  places_screen.dart   Add, import, switch places on/off, delete
  game_specs.dart      The list of games and every game's settings
  settings_screen.dart General settings and each game's settings page
  games_screen.dart    The "All games" grid
  history_screen.dart  Past picks
  games/               One file per game (or per family of games);
                       all_games.dart maps a game id to its widget
tool/
  setup_android.dart   Patches the generated Android project
  MainActivity.kt.txt  Share intent, file picker, open in Maps
```

## Good to know

- **Saved lists** are read the same way the Google Maps website loads them.
  Google has no official API for this, so it only works for lists with link
  sharing on, and could break if Google changes things. The Takeout import
  always works.
- Randomness comes from `Random.secure()`.

## Adding a game

1. Add a `GameSpec` with its settings to `games` in `lib/game_specs.dart`.
2. Write the widget in `lib/games/`. It gets a `GameArgs`: call
   `args.startRound()` when a round starts and `args.onPick(name)` with the
   winner. Read your settings with `args.d('key')`, `args.i('key')`,
   `args.b('key')`.
3. Add a `case` for its id in `lib/games/all_games.dart`.

The settings page, the game picker and history pick it up automatically.
