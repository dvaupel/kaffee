import 'package:flutter/material.dart';

import '../insights.dart';
import '../widgets/shot_card.dart';
import '../store.dart';
import 'shot_editor.dart';

class ShotsScreen extends StatefulWidget {
  const ShotsScreen({super.key});

  @override
  State<ShotsScreen> createState() => _ShotsScreenState();
}

class _ShotsScreenState extends State<ShotsScreen> {
  bool _favOnly = false;
  ShotSort _sort = ShotSort.newest;

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final shots = sortShots(
          _favOnly
              ? store.shots.where((s) => s.favorite).toList()
              : store.shots,
          _sort,
          store.targets,
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('Kaffee-Tagebuch'),
            actions: [
              PopupMenuButton<ShotSort>(
                tooltip: 'Sortieren',
                icon: const Icon(Icons.sort),
                initialValue: _sort,
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => [
                  for (final o in ShotSort.values)
                    PopupMenuItem(value: o, child: Text(o.label)),
                ],
              ),
              IconButton(
                tooltip: _favOnly ? 'Alle Shots' : 'Nur Favoriten',
                icon: Icon(_favOnly ? Icons.favorite : Icons.favorite_border),
                onPressed: () => setState(() => _favOnly = !_favOnly),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => openShotEditor(
              context,
              store.newShotTemplate(),
              isNew: true,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Neuer Shot'),
          ),
          body: shots.isEmpty
              ? _EmptyState(favOnly: _favOnly)
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 96),
                  itemCount: shots.length,
                  itemBuilder: (context, i) => ShotCard(shot: shots[i]),
                ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.favOnly});
  final bool favOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.coffee_maker_outlined,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              favOnly ? 'Noch keine Favoriten.' : 'Noch keine Shots.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              favOnly
                  ? 'Markiere gelungene Shots mit dem Herz.'
                  : 'Zeit für den ersten Espresso!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
