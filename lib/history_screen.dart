import 'package:flutter/material.dart';

import 'game_specs.dart';
import 'models.dart';
import 'native_bridge.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.state});

  final AppState state;

  String _time(DateTime t) {
    final now = DateTime.now();
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? hm : '${t.day}/${t.month} $hm';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          actions: [
            if (state.history.isNotEmpty)
              TextButton(
                  onPressed: state.clearHistory, child: const Text('Clear')),
          ],
        ),
        body: state.history.isEmpty
            ? const Center(child: Text('Your picks will show up here.'))
            : ListView.separated(
                itemCount: state.history.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final h = state.history[i];
                  return ListTile(
                    title: Text(h.name),
                    subtitle: Text('${gameById(h.gameId).name} · ${_time(h.at)}'),
                    trailing: const Icon(Icons.map_outlined),
                    onTap: () => NativeBridge.openUrl(mapsUrl(h.name)),
                  );
                },
              ),
      ),
    );
  }
}
