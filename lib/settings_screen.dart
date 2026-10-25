import 'package:flutter/material.dart';

import 'game_specs.dart';
import 'models.dart';

/// General settings plus a link to every game's own settings.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _Header('General'),
          SettingsList(state: state, prefix: 'general', specs: generalSettings),
          const _Header('Games'),
          for (final g in games)
            ListTile(
              leading: Icon(g.icon, color: theme.colorScheme.primary),
              title: Text(g.name),
              subtitle: Text('${g.settings.length} setting${g.settings.length == 1 ? '' : 's'}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => GameSettingsScreen(state: state, game: g))),
            ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Reset every setting?'),
                    content: const Text('General and game settings go back to their defaults.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
                    ],
                  ),
                );
                if (yes == true) state.resetSettings();
              },
              child: const Text('Reset all settings'),
            ),
          ),
        ],
      ),
    );
  }
}

class GameSettingsScreen extends StatelessWidget {
  const GameSettingsScreen({super.key, required this.state, required this.game});

  final AppState state;
  final GameSpec game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${game.name} settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(game.blurb, style: Theme.of(context).textTheme.bodyMedium),
          ),
          SettingsList(state: state, prefix: game.id, specs: game.settings),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => state.resetSettings(game.id),
              child: Text('Reset ${game.name} settings'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a list of [SettingSpec]s and writes changes back to the app state.
class SettingsList extends StatelessWidget {
  const SettingsList({super.key, required this.state, required this.prefix, required this.specs});

  final AppState state;
  final String prefix;
  final List<SettingSpec> specs;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = state.settings;
        String k(String key) => '$prefix.$key';
        bool visible(SettingSpec spec) {
          final dep = spec.showIfKey;
          if (dep == null) return true;
          final depSpec = specIndex[k(dep)];
          if (depSpec == null) return true;
          final value = depSpec.kind == SettingKind.toggle ? s.b(k(dep)) : s.i(k(dep));
          return value == spec.showIfValue;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final spec in specs.where(visible))
              switch (spec.kind) {
                SettingKind.toggle => SwitchListTile(
                    title: Text(spec.label),
                    subtitle: spec.help == null ? null : Text(spec.help!),
                    value: s.b(k(spec.key)),
                    onChanged: (v) => state.putSetting(k(spec.key), v),
                  ),
                SettingKind.slider => _SliderTile(
                    spec: spec,
                    value: s.d(k(spec.key)),
                    onChanged: (v) => state.putSetting(
                        k(spec.key), spec.step >= 1 ? v.round() : double.parse(v.toStringAsFixed(2))),
                  ),
                SettingKind.choice => _ChoiceTile(
                    label: spec.label,
                    help: spec.help,
                    options: spec.options,
                    selected: s.i(k(spec.key)),
                    onSelected: (i) => state.putSetting(k(spec.key), i),
                  ),
              },
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({required this.spec, required this.value, required this.onChanged});

  final SettingSpec spec;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final min = spec.min.toDouble();
    final max = spec.max.toDouble();
    final v = value.clamp(min, max);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(spec.label, style: theme.textTheme.bodyLarge)),
              Text(spec.format(v),
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
            ],
          ),
          Slider(
            value: v,
            min: min,
            max: max,
            divisions: spec.divisions,
            label: spec.format(v),
            onChanged: onChanged,
          ),
          if (spec.help != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(spec.help!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.help,
  });

  final String label;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelected;
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < options.length; i++)
                ChoiceChip(
                  label: Text(options[i]),
                  selected: i == selected,
                  onSelected: (_) => onSelected(i),
                ),
            ],
          ),
          if (help != null) ...[
            const SizedBox(height: 6),
            Text(help!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
