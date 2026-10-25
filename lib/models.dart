import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_specs.dart';

/// One shared, cryptographically secure source of randomness for every game.
final Random rng = Random.secure();

List<T> shuffled<T>(Iterable<T> items) {
  final list = List<T>.of(items);
  list.shuffle(rng);
  return list;
}

String mapsUrl(String name) =>
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}';

class Place {
  Place(this.name, {this.on = true});

  final String name;
  bool on;

  Map<String, dynamic> toJson() => {'name': name, 'on': on};

  static Place fromJson(Map<String, dynamic> m) =>
      Place(m['name'] as String, on: (m['on'] as bool?) ?? true);
}

class HistoryEntry {
  HistoryEntry(this.name, this.gameId, this.at);

  final String name;
  final String gameId;
  final DateTime at;

  Map<String, dynamic> toJson() =>
      {'name': name, 'game': gameId, 'at': at.toIso8601String()};

  static HistoryEntry fromJson(Map<String, dynamic> m) => HistoryEntry(
        m['name'] as String,
        (m['game'] as String?) ?? 'wheel',
        DateTime.tryParse((m['at'] as String?) ?? '') ?? DateTime.now(),
      );
}

/// All settings, stored as "gameId.key" (or "general.key"). Anything not set
/// falls back to the default in game_specs.dart.
class Settings {
  final Map<String, Object> values = {};

  Object? _get(String key) => values[key] ?? specIndex[key]?.def;

  bool b(String key) {
    final v = _get(key);
    return v is bool ? v : false;
  }

  double d(String key) {
    final v = _get(key);
    return v is num ? v.toDouble() : 0;
  }

  int i(String key) {
    final v = _get(key);
    return v is num ? v.round() : 0;
  }

  void put(String key, Object value) => values[key] = value;

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(values);

  void loadJson(Map<String, dynamic> m) {
    values.clear();
    m.forEach((k, v) {
      final spec = specIndex[k];
      if (spec == null || v == null) return;
      if (spec.kind == SettingKind.toggle && v is bool) values[k] = v;
      if (spec.kind != SettingKind.toggle && v is num) values[k] = v;
    });
  }
}

class AppState extends ChangeNotifier {
  static const examples = [
    'Indian Coffee House, College Street',
    'Victoria Memorial',
    'Flurys, Park Street',
    'Prinsep Ghat',
    'Kumartuli',
    'Mocambo, Park Street',
    'Eco Park, New Town',
    'Dakshineswar Kali Temple',
  ];

  List<Place> places = [];
  bool usingExamples = false;
  final Settings settings = Settings();
  List<HistoryEntry> history = [];
  String gameId = 'wheel';
  String? lastWinner;

  SharedPreferences? _prefs;
  String? _pendingOut;

  List<String> get pool =>
      places.where((p) => p.on).map((p) => p.name).toList();

  bool get hasOwnPlaces => !usingExamples && places.isNotEmpty;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      final p = prefs.getString('places');
      if (p != null) {
        places = (jsonDecode(p) as List)
            .map((e) => Place.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      final s = prefs.getString('settings2');
      if (s != null) {
        settings.loadJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
      }
      final h = prefs.getString('history');
      if (h != null) {
        history = (jsonDecode(h) as List)
            .map((e) =>
                HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      gameId = gameById(prefs.getString('game') ?? 'wheel').id;
    } catch (_) {
      // Start fresh if saved data can't be read.
    }
    if (places.isEmpty) {
      places = examples.map((n) => Place(n)).toList();
      usingExamples = true;
    }
    notifyListeners();
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    if (usingExamples) {
      prefs.remove('places');
    } else {
      prefs.setString(
          'places', jsonEncode(places.map((e) => e.toJson()).toList()));
    }
    prefs.setString('settings2', jsonEncode(settings.toJson()));
    prefs.setString(
        'history', jsonEncode(history.map((e) => e.toJson()).toList()));
    prefs.setString('game', gameId);
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  /// Adds names, skipping ones already on the list. Returns how many were new.
  int addNames(Iterable<String> names, {bool replace = false}) {
    if (usingExamples || replace) {
      places = [];
      usingExamples = false;
      _pendingOut = null;
    }
    final have = places.map((p) => p.name.toLowerCase()).toSet();
    var added = 0;
    for (final raw in names) {
      final n = raw.trim();
      if (n.isEmpty || have.contains(n.toLowerCase())) continue;
      places.add(Place(n));
      have.add(n.toLowerCase());
      added++;
    }
    _changed();
    return added;
  }

  void setOn(Place p, bool on) {
    p.on = on;
    _changed();
  }

  void removePlace(Place p) {
    places.remove(p);
    _changed();
  }

  void clearPlaces() {
    places = [];
    usingExamples = false;
    _pendingOut = null;
    _changed();
  }

  void enableAll() {
    for (final p in places) {
      p.on = true;
    }
    _changed();
  }

  void setGame(String id) {
    gameId = id;
    _changed();
  }

  void recordWin(String name) {
    lastWinner = name;
    history.insert(0, HistoryEntry(name, gameId, DateTime.now()));
    _trimHistory();
    if (settings.b('general.removeWinner')) _pendingOut = name;
    _changed();
  }

  /// Called by a game when a new round begins. Applies "take the winner out of
  /// play" from the previous round and returns the places in play.
  List<String> startRound() {
    final out = _pendingOut;
    if (out != null) {
      _pendingOut = null;
      for (final p in places) {
        if (p.on && p.name == out) {
          p.on = false;
          break;
        }
      }
      _changed();
    }
    return pool;
  }

  void clearHistory() {
    history = [];
    _changed();
  }

  void _trimHistory() {
    final max = settings.i('general.historySize');
    if (history.length > max) history = history.sublist(0, max);
  }

  void putSetting(String key, Object value) {
    settings.put(key, value);
    _trimHistory();
    _changed();
  }

  /// Resets one game's settings ("wheel"), the general ones ("general"), or
  /// everything when [prefix] is null.
  void resetSettings([String? prefix]) {
    if (prefix == null) {
      settings.values.clear();
    } else {
      settings.values.removeWhere((k, _) => k.startsWith('$prefix.'));
    }
    _trimHistory();
    _changed();
  }
}
