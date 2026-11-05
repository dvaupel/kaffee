import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../updater.dart';
import 'update_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final t = store.targets;
        final d = store.defaults;
        return Scaffold(
          appBar: AppBar(title: const Text('Setup')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const _Header('Ausrüstung'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  'Tipp: Einen Eintrag gedrückt halten, um ihn als Standard '
                  'für neue Shots anzupinnen.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              _ListEditor(
                label: 'Maschine',
                items: store.machines,
                pinned: d.machine,
                onChanged: (l) {
                  store.machines = l;
                  _keepPin(d, 'machine', l);
                  store.save();
                },
                onPin: (v) {
                  d.machine = v;
                  store.save();
                },
              ),
              _ListEditor(
                label: 'Siebträger',
                items: store.portafilters,
                pinned: d.portafilter,
                onChanged: (l) {
                  store.portafilters = l;
                  _keepPin(d, 'portafilter', l);
                  store.save();
                },
                onPin: (v) {
                  d.portafilter = v;
                  store.save();
                },
              ),
              _ListEditor(
                label: 'Siebe',
                items: store.baskets,
                pinned: d.basket,
                onChanged: (l) {
                  store.baskets = l;
                  _keepPin(d, 'basket', l);
                  store.save();
                },
                onPin: (v) {
                  d.basket = v;
                  store.save();
                },
              ),
              const _Header('Standard-Experiment'),
              _DefaultsCard(
                defaults: d,
                onChanged: store.save,
              ),
              const _Header('Bezug'),
              Card(
                child: SwitchListTile(
                  secondary: const Icon(Icons.timer_outlined),
                  title: const Text('Shot-Timer in der App'),
                  subtitle: const Text(
                      'Aus, wenn deine Waage selbst eine Zeit misst. Die '
                      'Durchlaufzeit trägst du dann von Hand ein.'),
                  value: store.useTimer,
                  onChanged: (v) {
                    store.useTimer = v;
                    store.save();
                  },
                ),
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
              const _Header('App'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.system_update_outlined),
                  title: const Text('Nach Update suchen'),
                  subtitle: FutureBuilder<String>(
                    future: currentVersion(),
                    builder: (_, snap) =>
                        Text('Installiert: ${snap.data ?? '…'}'),
                  ),
                  onTap: () => runUpdateCheck(context, silent: false),
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
                  'Kaffee-Tagebuch',
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

  /// Entfernt einen Pin, dessen Eintrag gelöscht wurde.
  void _keepPin(Defaults d, String key, List<String> items) {
    final v = d.text(key);
    if (v != null && !items.contains(v)) d.setText(key, null);
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      messenger
          .showSnackBar(const SnackBar(content: Text('Import erfolgreich')));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Import fehlgeschlagen: ungültiges Format')));
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
    required this.pinned,
    required this.onPin,
  });

  final String label;
  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  final String? pinned;
  final ValueChanged<String?> onPin;

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
                  GestureDetector(
                    onLongPress: () {
                      HapticFeedback.heavyImpact();
                      onPin(item == pinned ? null : item);
                    },
                    child: InputChip(
                      avatar: item == pinned
                          ? const Icon(Icons.push_pin, size: 18)
                          : null,
                      label: Text(item),
                      selected: item == pinned,
                      showCheckmark: false,
                      onPressed: () {},
                      onDeleted: () =>
                          onChanged(items.where((e) => e != item).toList()),
                    ),
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

/// Übersicht der angepinnten Standardwerte. Tippen ändert Zahlen und Mahlgrad,
/// gedrückt halten löst den Pin.
class _DefaultsCard extends StatelessWidget {
  const _DefaultsCard({required this.defaults, required this.onChanged});

  final Defaults defaults;
  final Future<void> Function() onChanged;

  Future<void> _edit(BuildContext context, String key, String label,
      String suffix, bool numeric) async {
    final current = numeric
        ? (defaults.number(key) == null ? '' : fmtSmart(defaults.number(key)!))
        : (defaults.text(key) ?? '');
    final c = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label als Standard'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(labelText: label, suffixText: suffix),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Anpinnen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (numeric) {
      defaults.setNumber(key, parseNum(c.text));
    } else {
      defaults.setText(key, c.text.trim());
    }
    await onChanged();
  }

  Widget _tile(BuildContext context, IconData icon, String label, String? value,
      {required VoidCallback? onTap, required VoidCallback onClear}) {
    final pinned = value != null;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(pinned ? value : 'wie beim letzten Shot'),
      trailing: Icon(
        pinned ? Icons.push_pin : Icons.push_pin_outlined,
        color: pinned ? scheme.primary : scheme.outline,
      ),
      onTap: onTap,
      onLongPress: pinned
          ? () {
              HapticFeedback.heavyImpact();
              onClear();
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = defaults;
    Future<void> clear(String key, {bool numeric = false}) {
      if (numeric) {
        d.setNumber(key, null);
      } else {
        d.setText(key, null);
      }
      return onChanged();
    }

    return Card(
      child: Column(
        children: [
          _tile(context, Icons.coffee_maker_outlined, 'Maschine', d.machine,
              onTap: null, onClear: () => clear('machine')),
          _tile(context, Icons.hardware_outlined, 'Siebträger', d.portafilter,
              onTap: null, onClear: () => clear('portafilter')),
          _tile(context, Icons.filter_alt_outlined, 'Sieb', d.basket,
              onTap: null, onClear: () => clear('basket')),
          _tile(
            context,
            Icons.thermostat,
            'Temperatur',
            d.temperature == null ? null : '${fmtSmart(d.temperature!)} °C',
            onTap: () =>
                _edit(context, 'temperature', 'Temperatur', '°C', true),
            onClear: () => clear('temperature', numeric: true),
          ),
          _tile(
            context,
            Icons.scale_outlined,
            'Bohnen-Dosis',
            d.doseIn == null ? null : '${fmtSmart(d.doseIn!)} g',
            onTap: () => _edit(context, 'doseIn', 'Dosis', 'g', true),
            onClear: () => clear('doseIn', numeric: true),
          ),
          _tile(
            context,
            Icons.tune,
            'Mahlgrad',
            d.grind,
            onTap: () => _edit(context, 'grind', 'Mahlgrad', '', false),
            onClear: () => clear('grind'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Angepinnte Werte gelten für jeden neuen Shot. Alles andere '
              'übernimmst du vom letzten Shot, so bleibt nur die Variable, '
              'die du gerade testest. Gedrückt halten löst den Pin.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
