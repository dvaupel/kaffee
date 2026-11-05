import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../store.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final t = store.targets;
        return Scaffold(
          appBar: AppBar(title: const Text('Setup')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const _Header('Ausrüstung'),
              _ListEditor(
                label: 'Siebträger',
                items: store.portafilters,
                onChanged: (l) {
                  store.portafilters = l;
                  store.save();
                },
              ),
              _ListEditor(
                label: 'Siebe',
                items: store.baskets,
                onChanged: (l) {
                  store.baskets = l;
                  store.save();
                },
              ),
              const _Header('Zielwerte'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text('Durchlaufzeit'),
                      subtitle: Text(
                          '${fmtSmart(t.timeMin)} bis ${fmtSmart(t.timeMax)} s'),
                      onTap: () => _editTargets(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.balance),
                      title: const Text('Verhältnis Bohnen : Espresso'),
                      subtitle: Text('1 : ${fmtNum(t.ratio)}'),
                      onTap: () => _editTargets(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.speed),
                      title: const Text('Druck'),
                      subtitle: Text(
                          '${fmtSmart(t.pressureMin)} bis ${fmtSmart(t.pressureMax)} bar'),
                      onTap: () => _editTargets(context),
                    ),
                  ],
                ),
              ),
              const _Header('Daten'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.upload_outlined),
                      title: const Text('Exportieren'),
                      subtitle: const Text('Alle Daten als Text kopieren'),
                      onTap: () async {
                        await Clipboard.setData(
                            ClipboardData(text: store.exportJson()));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('In die Zwischenablage kopiert')),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text('Importieren'),
                      subtitle: const Text('Ersetzt alle aktuellen Daten'),
                      onTap: () => _import(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  '${store.shots.length} Shots, ${store.beans.length} Bohnen. '
                  'Die Daten liegen nur auf diesem Gerät.\n\n'
                  'Kaffee-Tagebuch 0.1',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editTargets(BuildContext context) async {
    final store = Store.instance;
    final t = store.targets;
    final c = {
      'timeMin': TextEditingController(text: fmtSmart(t.timeMin)),
      'timeMax': TextEditingController(text: fmtSmart(t.timeMax)),
      'ratio': TextEditingController(text: fmtNum(t.ratio)),
      'pressureMin': TextEditingController(text: fmtSmart(t.pressureMin)),
      'pressureMax': TextEditingController(text: fmtSmart(t.pressureMax)),
    };
    Widget field(String key, String label, String suffix) => Expanded(
          child: TextField(
            controller: c[key],
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label, suffixText: suffix),
          ),
        );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zielwerte'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                field('timeMin', 'Zeit von', 's'),
                const SizedBox(width: 8),
                field('timeMax', 'bis', 's'),
              ]),
              const SizedBox(height: 12),
              Row(children: [field('ratio', 'Verhältnis 1 :', '')]),
              const SizedBox(height: 12),
              Row(children: [
                field('pressureMin', 'Druck von', 'bar'),
                const SizedBox(width: 8),
                field('pressureMax', 'bis', 'bar'),
              ]),
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
    if (ok != true) return;
    t.timeMin = parseNum(c['timeMin']!.text) ?? t.timeMin;
    t.timeMax = parseNum(c['timeMax']!.text) ?? t.timeMax;
    t.ratio = parseNum(c['ratio']!.text) ?? t.ratio;
    t.pressureMin = parseNum(c['pressureMin']!.text) ?? t.pressureMin;
    t.pressureMax = parseNum(c['pressureMax']!.text) ?? t.pressureMax;
    await store.save();
  }

  Future<void> _import(BuildContext context) async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!context.mounted) return;
    final c = TextEditingController(text: clip?.text ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daten importieren'),
        content: TextField(
          controller: c,
          minLines: 4,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Exportierten Text hier einfügen',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importieren'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Store.instance.importJson(c.text);
      messenger.showSnackBar(const SnackBar(content: Text('Import erfolgreich')));
    } catch (e) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Import fehlgeschlagen: ungültiges Format')));
    }
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

class _ListEditor extends StatelessWidget {
  const _ListEditor({
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final List<String> items;
  final ValueChanged<List<String>> onChanged;

  Future<void> _add(BuildContext context) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label hinzufügen'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Bezeichnung'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    final v = name?.trim() ?? '';
    if (v.isEmpty || items.contains(v)) return;
    onChanged([...items, v]);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final item in items)
                  InputChip(
                    label: Text(item),
                    onDeleted: () =>
                        onChanged(items.where((e) => e != item).toList()),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Neu'),
                  onPressed: () => _add(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
