import 'package:flutter/material.dart';

import '../format.dart';
import '../insights.dart';
import '../models.dart';
import '../store.dart';
import 'shot_editor.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final rated = store.shots.where((s) => s.rating > 0).toList();
        final top =
            sortShots(rated, ShotSort.rating, store.targets).take(5).toList();
        final insights = buildInsights(
          store.shots,
          store.targets,
          (id) => store.beanById(id)?.name ?? 'Ohne Bohne',
        );

        List<Insight> of(InsightKind k) =>
            insights.where((i) => i.kind == k).toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Erkenntnisse')),
          body: rated.isEmpty
              ? const _Empty()
              : ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    const _Header('Bestenliste'),
                    Card(
                      child: Column(
                        children: [
                          for (var i = 0; i < top.length; i++)
                            _RankTile(rank: i + 1, shot: top[i]),
                        ],
                      ),
                    ),
                    _Section(
                      title: 'Nächster Schritt',
                      icon: Icons.lightbulb_outline,
                      items: of(InsightKind.nextStep),
                    ),
                    _Section(
                      title: 'Dein Sweet Spot',
                      icon: Icons.my_location,
                      items: of(InsightKind.sweetSpot),
                    ),
                    _Section(
                      title: 'Was die Bewertung beeinflusst',
                      icon: Icons.insights,
                      items: of(InsightKind.factor),
                    ),
                    _Section(
                      title: 'Vergleiche',
                      icon: Icons.compare_arrows,
                      items: of(InsightKind.compare),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Text(
                        'Das sind Tendenzen aus deinen eigenen Shots, keine '
                        'Gesetze. Je mehr bewertete Shots pro Bohne, desto '
                        'verlässlicher. Zusammenhänge erscheinen ab 5 '
                        'bewerteten Shots einer Bohne.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
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
            Icon(Icons.insights, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Noch nichts zu erkennen.',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Bewerte deine Shots mit Sternen. Dann zeigt dir die App die '
              'besten Shots, deinen Sweet Spot und was dein Ergebnis '
              'beeinflusst.',
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

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<Insight> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(title),
        Card(
          child: Column(
            children: [
              for (final i in items)
                ListTile(
                  leading: Icon(icon, color: scheme.tertiary),
                  title: Text(i.title),
                  subtitle: Text(i.text),
                  isThreeLine: i.text.length > 60,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({required this.rank, required this.shot});

  final int rank;
  final Shot shot;

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final scheme = Theme.of(context).colorScheme;
    final bean = store.beanById(shot.beanId)?.name ?? 'Ohne Bohne';
    final details = <String>[
      '${fmtNum(shot.doseIn)} → ${fmtNum(shot.yieldOut)} g',
      if (shot.timeSec != null) '${fmtSmart(shot.timeSec!)} s',
      if (shot.grind.isNotEmpty) 'Mahlgrad ${shot.grind}',
      if (shot.temperature != null) '${fmtSmart(shot.temperature!)} °C',
    ].join('  ·  ');
    return ListTile(
      onTap: () => openShotEditor(context, shot.clone()),
      leading: CircleAvatar(
        backgroundColor:
            rank == 1 ? Colors.amber.shade700 : scheme.surfaceContainerHighest,
        foregroundColor: rank == 1 ? Colors.white : scheme.onSurface,
        child: Text('$rank'),
      ),
      title: Text(bean, overflow: TextOverflow.ellipsis),
      subtitle: Text(details),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${shot.rating}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Icon(Icons.star_rounded, size: 20, color: Colors.amber.shade700),
        ],
      ),
    );
  }
}
