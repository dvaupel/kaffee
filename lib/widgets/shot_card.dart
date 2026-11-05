import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../screens/shot_editor.dart';
import '../store.dart';

class ShotCard extends StatelessWidget {
  const ShotCard({super.key, required this.shot, this.showBean = true});

  final Shot shot;
  final bool showBean;

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final t = store.targets;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bean = store.beanById(shot.beanId);
    final tip = dialInTip(shot.timeSec, shot.acidity, shot.bitterness, t);
    final muted =
        theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    final subtitle = <String>[
      if (showBean) fmtDateRel(shot.date),
      if (shot.machine.isNotEmpty && store.machines.length > 1) shot.machine,
      if (shot.grind.isNotEmpty) 'Mahlgrad ${shot.grind}',
      if (shot.basket.isNotEmpty) shot.basket,
    ].join('  ·  ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openShotEditor(context, shot.clone()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      showBean
                          ? (bean?.name ?? 'Ohne Bohne')
                          : fmtDateRel(shot.date),
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (shot.favorite)
                    Icon(Icons.favorite, size: 18, color: scheme.primary),
                  _ShotMenu(shot: shot),
                ],
              ),
              if (subtitle.isNotEmpty) Text(subtitle, style: muted),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  MetricChip(
                    icon: Icons.scale_outlined,
                    text: '${fmtNum(shot.doseIn)} → ${fmtNum(shot.yieldOut)} g',
                    level: Level.none,
                  ),
                  MetricChip(
                    icon: Icons.balance,
                    text: shot.ratio == null
                        ? '1:–'
                        : '1:${fmtNum(shot.ratio, digits: 2)}',
                    level: t.ratioLevel(shot.ratio),
                  ),
                  MetricChip(
                    icon: Icons.timer_outlined,
                    text: shot.timeSec == null
                        ? '– s'
                        : '${fmtSmart(shot.timeSec!)} s',
                    level: t.timeLevel(shot.timeSec),
                  ),
                  if (shot.pressure != null)
                    MetricChip(
                      icon: Icons.speed,
                      text: '${fmtSmart(shot.pressure!)} bar',
                      level: t.pressureLevel(shot.pressure),
                    ),
                  if (shot.temperature != null)
                    MetricChip(
                      icon: Icons.thermostat,
                      text: '${fmtSmart(shot.temperature!)} °C',
                      level: Level.none,
                    ),
                ],
              ),
              if (shot.rating > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Icon(
                        i <= shot.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 18,
                        color: Colors.amber.shade700,
                      ),
                  ],
                ),
              ],
              if (shot.notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    shot.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
              if (tip != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 16, color: scheme.tertiary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(tip, style: muted)),
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

class _ShotMenu extends StatelessWidget {
  const _ShotMenu({required this.shot});
  final Shot shot;

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (v) async {
        switch (v) {
          case 'dup':
            openShotEditor(context, store.duplicate(shot), isNew: true);
          case 'fav':
            final s = shot.clone()..favorite = !shot.favorite;
            await store.saveShot(s);
          case 'del':
            final messenger = ScaffoldMessenger.of(context);
            final backup = shot.clone();
            await store.deleteShot(shot);
            messenger.showSnackBar(
              SnackBar(
                content: const Text('Shot gelöscht'),
                action: SnackBarAction(
                  label: 'Rückgängig',
                  onPressed: () => store.saveShot(backup),
                ),
              ),
            );
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'dup',
          child: ListTile(
            leading: Icon(Icons.copy),
            title: Text('Mit diesem Setup neu'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'fav',
          child: ListTile(
            leading:
                Icon(shot.favorite ? Icons.favorite_border : Icons.favorite),
            title: Text(shot.favorite ? 'Kein Favorit mehr' : 'Favorit'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'del',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Löschen'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class MetricChip extends StatelessWidget {
  const MetricChip({
    super.key,
    required this.icon,
    required this.text,
    required this.level,
  });

  final IconData icon;
  final String text;
  final Level level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = levelColor(level, scheme);
    final none = level == Level.none;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: none
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: none ? scheme.onSurfaceVariant : c),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: none ? scheme.onSurface : c,
            ),
          ),
        ],
      ),
    );
  }
}
