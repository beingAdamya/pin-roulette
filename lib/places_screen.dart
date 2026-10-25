import 'package:flutter/material.dart';

import 'import_flow.dart';
import 'importer.dart';
import 'models.dart';
import 'native_bridge.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key, required this.state});

  final AppState state;

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    final ok = await runImport(context, widget.state, () => importText(text));
    if (ok) _input.clear();
  }

  Future<void> _pickFile() async {
    final files = await NativeBridge.pickFiles();
    if (files.isEmpty || !mounted) return;
    await runImport(context, widget.state, () async {
      final r = ImportResult();
      for (final f in files) {
        final names = namesFromFile(f.text, f.name);
        if (names.isEmpty) {
          r.notes.add('No places found in ${f.name}. Pick the .csv of a list '
              'from the Takeout “Saved” folder.');
        }
        r.names.addAll(names);
      }
      return r;
    });
  }

  Future<void> _confirmClear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear all places?'),
        content: const Text('This removes every place from the list.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Clear all')),
        ],
      ),
    );
    if (yes == true) widget.state.clearPlaces();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Places'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'all') state.enableAll();
                if (v == 'clear') _confirmClear();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'all', child: Text('Turn all on')),
                PopupMenuItem(value: 'clear', child: Text('Clear all')),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextField(
              controller: _input,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText:
                    'Paste a Google Maps link, or type place names one per line',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    label: const Text('Add')),
                OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import Takeout file')),
              ],
            ),
            const SizedBox(height: 12),
            const _SavedListHelp(),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('${state.pool.length} of ${state.places.length} in play',
                    style: theme.textTheme.titleSmall),
                if (state.usingExamples) ...[
                  const SizedBox(width: 8),
                  const Chip(
                    label: Text('Examples'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            if (state.places.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No places yet. Share a place or a saved list from Google Maps, '
                  'or paste a link above.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            for (final p in state.places)
              Dismissible(
                key: ObjectKey(p),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: theme.colorScheme.errorContainer,
                  child: Icon(Icons.delete_outline,
                      color: theme.colorScheme.onErrorContainer),
                ),
                onDismissed: (_) => state.removePlace(p),
                child: CheckboxListTile(
                  value: p.on,
                  onChanged: (v) => state.setOn(p, v ?? false),
                  title: Text(p.name),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            if (state.places.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Untick a place to leave it out. Swipe left to delete.',
                    style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _SavedListHelp extends StatelessWidget {
  const _SavedListHelp();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget step(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(s, style: t.bodyMedium),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(Icons.bookmarks_outlined),
        title: const Text('Use a list you saved in Google Maps'),
        shape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Share it from Google Maps', style: t.titleSmall),
          const SizedBox(height: 6),
          step('1. Open Google Maps and go to the You tab (Saved on older versions).'),
          step('2. Open your list and tap Share. Allow link sharing if Maps asks.'),
          step('3. Pick Pin Roulette from the share menu.'),
          const SizedBox(height: 12),
          Text('If that doesn’t work: Google Takeout', style: t.titleSmall),
          const SizedBox(height: 6),
          step('1. Go to takeout.google.com, tap Deselect all, then tick Saved.'),
          step('2. Create the export and download the .zip from the email.'),
          step('3. Unzip it. Each list in the Saved folder is a .csv file. '
              'Tap Import Takeout file and choose it.'),
        ],
      ),
    );
  }
}
