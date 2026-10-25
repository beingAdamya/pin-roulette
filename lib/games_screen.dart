import 'package:flutter/material.dart';

import 'game_specs.dart';

/// A grid of every game. Returns the chosen game's id.
class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key, required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('All ${games.length} games')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemCount: games.length,
        itemBuilder: (context, i) {
          final g = games[i];
          final selected = g.id == current;
          return Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            color: selected ? theme.colorScheme.primaryContainer : null,
            child: InkWell(
              onTap: () => Navigator.pop(context, g.id),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(g.icon, size: 30, color: theme.colorScheme.primary),
                    const SizedBox(height: 10),
                    Text(g.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        g.blurb,
                        overflow: TextOverflow.fade,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
