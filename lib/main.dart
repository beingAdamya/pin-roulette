import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_specs.dart';
import 'games/all_games.dart';
import 'games/common.dart';
import 'games_screen.dart';
import 'history_screen.dart';
import 'import_flow.dart';
import 'importer.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'places_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(PinRouletteApp(state: state));
}

class PinRouletteApp extends StatelessWidget {
  const PinRouletteApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pin Roulette',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomeScreen(state: state),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    NativeBridge.init();
    NativeBridge.onShare = _handleShared;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final text = await NativeBridge.initialShare();
      if (text != null && text.trim().isNotEmpty) _handleShared(text);
    });
  }

  void _handleShared(String text) {
    if (!mounted) return;
    // Close any open screen so the import dialog sits on top of the game.
    Navigator.of(context).popUntil((r) => r.isFirst);
    runImport(context, state, () => importText(text));
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  final Map<String, GlobalKey> _chipKeys = {for (final g in games) g.id: GlobalKey()};

  void _onPick(String name) {
    thump(state.settings.b('general.haptics'));
    state.recordWin(name);
  }

  void _choose(String id) {
    state.setGame(id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chipKeys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.5, duration: const Duration(milliseconds: 300));
      }
    });
  }

  Future<void> _openAllGames() async {
    final id = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => GamesScreen(current: state.gameId)));
    if (id != null) _choose(id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final pool = state.pool;
        final game = gameById(state.gameId);
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Pin Roulette',
                style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                tooltip: 'History',
                icon: const Icon(Icons.history),
                onPressed: () => _open(HistoryScreen(state: state)),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.tune),
                onPressed: () => _open(SettingsScreen(state: state)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _PlacesBar(
                  state: state, onTap: () => _open(PlacesScreen(state: state))),
              const SizedBox(height: 12),
              _GamePicker(
                current: game.id,
                keys: _chipKeys,
                onSelect: _choose,
                onAll: _openAllGames,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: RadialGradient(
                    center: const Alignment(0, -1.2),
                    radius: 1.4,
                    colors: [
                      dark ? Felt.greenDark : Felt.green,
                      dark ? const Color(0xFF10302A) : const Color(0xFF184A39),
                    ],
                  ),
                ),
                constraints: const BoxConstraints(minHeight: 380),
                child: Column(
                  children: [
                    _StageHeader(
                      game: game,
                      onSettings: () => _open(GameSettingsScreen(state: state, game: game)),
                    ),
                    const SizedBox(height: 14),
                    pool.length < 2
                        ? _EmptyStage(
                            hasOne: pool.length == 1,
                            onAdd: () => _open(PlacesScreen(state: state)))
                        : buildGame(GameArgs(
                            id: game.id,
                            pool: pool,
                            settings: state.settings,
                            startRound: state.startRound,
                            onPick: _onPick,
                          )),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, a) => ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1).animate(
                        CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
                    child: FadeTransition(opacity: a, child: child)),
                child: state.lastWinner == null
                    ? const SizedBox.shrink()
                    : Padding(
                        key: ValueKey(state.history.length.toString() +
                            state.lastWinner!),
                        padding: const EdgeInsets.only(top: 14),
                        child: _ResultCard(name: state.lastWinner!),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GamePicker extends StatelessWidget {
  const _GamePicker({
    required this.current,
    required this.keys,
    required this.onSelect,
    required this.onAll,
  });

  final String current;
  final Map<String, GlobalKey> keys;
  final ValueChanged<String> onSelect;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ActionChip(
            avatar: const Icon(Icons.apps, size: 18),
            label: Text('All ${games.length}'),
            onPressed: onAll,
          ),
          const SizedBox(width: 8),
          for (final g in games) ...[
            ChoiceChip(
              key: keys[g.id],
              avatar: Icon(g.icon, size: 18),
              label: Text(g.name),
              selected: g.id == current,
              showCheckmark: false,
              onSelected: (_) => onSelect(g.id),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.game, required this.onSettings});

  final GameSpec game;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 6),
        Icon(game.icon, color: Felt.gold, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            game.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Felt.ink, fontWeight: FontWeight.w800, letterSpacing: 1.3, fontSize: 13),
          ),
        ),
        IconButton(
          tooltip: '${game.name} settings',
          onPressed: onSettings,
          icon: const Icon(Icons.tune, color: Felt.ink),
        ),
      ],
    );
  }
}

class _PlacesBar extends StatelessWidget {
  const _PlacesBar({required this.state, required this.onTap});

  final AppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pool = state.pool;
    final preview = pool.take(3).join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text('${pool.length}',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onPrimaryContainer)),
        ),
        title: Text(state.usingExamples
            ? 'Example places'
            : '${pool.length} place${pool.length == 1 ? '' : 's'} in play'),
        subtitle: Text(
          state.usingExamples
              ? 'Share a list from Google Maps to use yours'
              : (preview.isEmpty ? 'Tap to add places' : preview),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _EmptyStage extends StatelessWidget {
  const _EmptyStage({required this.hasOne, required this.onAdd});

  final bool hasOne;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 336,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.place_outlined, color: Felt.ink, size: 48),
          const SizedBox(height: 12),
          Text(
            hasOne
                ? 'Add or turn on at least one more place to play.'
                : 'Add some places to start.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Felt.ink, fontSize: 16),
          ),
          const SizedBox(height: 16),
          GoButton(label: 'Add places', onPressed: onAdd),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Felt.gold, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CHANCE PICKED',
                style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(name,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    final ok = await NativeBridge.openUrl(mapsUrl(name));
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Couldn’t open Google Maps.')));
                    }
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Open in Google Maps'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: name));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied')));
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
