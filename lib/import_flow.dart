import 'package:flutter/material.dart';

import 'importer.dart';
import 'models.dart';

/// Runs an import with a progress dialog, asks whether to replace or add when
/// the user already has places, and reports the outcome. Returns true when the
/// places were added.
Future<bool> runImport(
  BuildContext context,
  AppState state,
  Future<ImportResult> Function() job,
) async {
  final nav = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3)),
          SizedBox(width: 18),
          Expanded(child: Text('Reading places…')),
        ],
      ),
    ),
  );

  ImportResult r;
  try {
    r = await job();
  } catch (_) {
    r = ImportResult()..notes.add('Something went wrong while reading that.');
  }
  nav.pop();

  if (r.names.isEmpty) {
    messenger.showSnackBar(SnackBar(
      content: Text(r.notes.isEmpty ? 'No places found.' : r.notes.join(' ')),
      duration: const Duration(seconds: 6),
    ));
    return false;
  }

  var replace = false;
  if (state.hasOwnPlaces) {
    if (!context.mounted) return false;
    final inList = r.listName != null ? ' in “${r.listName}”' : '';
    final count = r.names.length;
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Found $count place${count == 1 ? '' : 's'}$inList'),
        content: const Text(
            'Use them instead of your current places, or add them to the list?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, 'add'),
              child: const Text('Add')),
          FilledButton(
              onPressed: () => Navigator.pop(c, 'replace'),
              child: const Text('Replace')),
        ],
      ),
    );
    if (choice == null) return false;
    replace = choice == 'replace';
  }

  final added = state.addNames(r.names, replace: replace);
  final fromList = r.listName != null ? ' from “${r.listName}”' : '';
  final lead = added > 0
      ? 'Added $added place${added == 1 ? '' : 's'}$fromList.'
      : 'Those places are already on your list.';
  messenger.showSnackBar(SnackBar(content: Text([lead, ...r.notes].join(' '))));
  return true;
}
