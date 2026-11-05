import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/shot_card.dart';
import 'shot_editor.dart';

/// Dialog zum Anlegen oder Bearbeiten einer Bohne. Speichert direkt.
Future<Bean?> editBeanDialog(BuildContext context, Bean? existing) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final roaster = TextEditingController(text: existing?.roaster ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(existing == null ? 'Neue Bohne' : 'Bohne bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roaster,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Rösterei'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notizen',
                hintText: 'Herkunft, Röstgrad, Röstdatum …',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Speichern'),
        ),
      ],
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return null;
  final store = Store.instance;
  final b = existing ?? Bean(id: store.newId(), name: '');
  b
    ..name = name.text.trim()
    ..roaster = roaster.text.trim()
    ..notes = notes.text.trim();
  await store.saveBean(b);
  return b;
}

class BeansScreen extends StatefulWidget {
  const BeansScreen({super.key});

  @override
  State<BeansScreen> createState() => _BeansScreenState();
}

class _BeansScreenState extends State<BeansScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final beans = store.beans
            .where((b) => _showArchived || !b.archived)
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return Scaffold(
          appBar: AppBar(
            title: const Text('Bohnen'),
            actions: [
              IconButton(
                tooltip: _showArchived
                    ? 'Archivierte ausblenden'
                    : 'Archivierte zeigen',
                icon: Icon(_showArchived
                    ? Icons.inventory_2
                    : Icons.inventory_2_outlined),
                onPressed: () => setState(() => _showArchived = !_showArchived),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => editBeanDialog(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Bohne'),
          ),
          body: beans.isEmpty
              ? const _Empty()
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 96),
                  itemCount: beans.length,
                  itemBuilder: (context, i) => _BeanTile(bean: beans[i]),
                ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_outlined,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Noch keine Bohnen.', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Lege deine Kaffeesorten an. Pro Bohne entsteht so ein Rezept, das funktioniert.',
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

String recipeLine(Shot s) {
  final parts = <String>[
    '${fmtNum(s.doseIn)} → ${fmtNum(s.yieldOut)} g',
    if (s.timeSec != null) '${fmtSmart(s.timeSec!)} s',
    if (s.grind.isNotEmpty) 'Mahlgrad ${s.grind}',
    if (s.temperature != null) '${fmtSmart(s.temperature!)} °C',
  ];
  return parts.join(', ');
}

class _BeanTile extends StatelessWidget {
  const _BeanTile({required this.bean});
  final Bean bean;

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = store.shotsForBean(bean.id).length;
    final best = store.bestShot(bean.id);
    final muted =
        theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BeanDetailScreen(beanId: bean.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bean.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: bean.archived ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                  ),
                  _BeanMenu(bean: bean),
                ],
              ),
              Text(
                [
                  if (bean.roaster.isNotEmpty) bean.roaster,
                  count == 1 ? '1 Shot' : '$count Shots',
                  if (bean.archived) 'archiviert',
                ].join('  ·  '),
                style: muted,
              ),
              if (best != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 18, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bestes Rezept: ${recipeLine(best)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BeanMenu extends StatelessWidget {
  const _BeanMenu({required this.bean});
  final Bean bean;

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return PopupMenuButton<String>(
      onSelected: (v) async {
        switch (v) {
          case 'edit':
            await editBeanDialog(context, bean);
          case 'archive':
            bean.archived = !bean.archived;
            await store.saveBean(bean);
          case 'delete':
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('"${bean.name}" löschen?'),
                content: const Text(
                    'Die Shots bleiben erhalten, verlieren aber die Zuordnung. Archivieren ist meist die bessere Wahl.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Abbrechen'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Löschen'),
                  ),
                ],
              ),
            );
            if (ok == true) await store.deleteBean(bean);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
        PopupMenuItem(
          value: 'archive',
          child: Text(bean.archived ? 'Reaktivieren' : 'Archivieren'),
        ),
        const PopupMenuItem(value: 'delete', child: Text('Löschen')),
      ],
    );
  }
}

/// Alle Shots einer Bohne, die besten zuerst.
class BeanDetailScreen extends StatelessWidget {
  const BeanDetailScreen({super.key, required this.beanId});
  final String beanId;

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final bean = store.beanById(beanId);
        final shots = store.shotsForBean(beanId)..sort(Store.compareBest);
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(bean?.name ?? 'Bohne')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              final base = shots.isNotEmpty
                  ? store.duplicate(shots.first)
                  : (store.newShotTemplate()..beanId = beanId);
              base.beanId = beanId;
              openShotEditor(context, base, isNew: true);
            },
            icon: const Icon(Icons.add),
            label: const Text('Shot mit dieser Bohne'),
          ),
          body: ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 96),
            children: [
              if (bean != null &&
                  (bean.roaster.isNotEmpty || bean.notes.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    [bean.roaster, bean.notes]
                        .where((e) => e.isNotEmpty)
                        .join('\n'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              if (shots.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Noch keine Shots mit dieser Bohne.')),
                ),
              for (final s in shots) ShotCard(shot: s, showBean: false),
            ],
          ),
        );
      },
    );
  }
}
