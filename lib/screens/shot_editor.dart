import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'beans_screen.dart';

Future<void> openShotEditor(BuildContext context, Shot shot,
    {bool isNew = false}) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ShotEditor(initial: shot, isNew: isNew)),
  );
}

class ShotEditor extends StatefulWidget {
  const ShotEditor({super.key, required this.initial, this.isNew = false});

  final Shot initial;
  final bool isNew;

  @override
  State<ShotEditor> createState() => _ShotEditorState();
}

class _ShotEditorState extends State<ShotEditor> {
  late Shot s;
  late final TextEditingController _grind;
  late final TextEditingController _temp;
  late final TextEditingController _dose;
  late final TextEditingController _yield;
  late final TextEditingController _time;
  late final TextEditingController _pressure;
  late final TextEditingController _notes;

  final Stopwatch _sw = Stopwatch();
  Timer? _ticker;
  bool _dirty = false;

  static const _acidityLabels = [
    'zu flach',
    'etwas flach',
    'ausgewogen',
    'etwas sauer',
    'zu sauer',
  ];
  static const _bitternessLabels = [
    'kaum',
    'leicht',
    'angenehm',
    'deutlich',
    'zu bitter',
  ];

  String _n(double? v) => v == null ? '' : fmtSmart(v);

  @override
  void initState() {
    super.initState();
    s = widget.initial;
    final machines = Store.instance.machines;
    if (s.machine.isEmpty && machines.length == 1) s.machine = machines.first;
    _dirty = widget.isNew;
    _grind = TextEditingController(text: s.grind);
    _temp = TextEditingController(text: _n(s.temperature));
    _dose = TextEditingController(text: _n(s.doseIn));
    _yield = TextEditingController(text: _n(s.yieldOut));
    _time = TextEditingController(text: _n(s.timeSec));
    _pressure = TextEditingController(text: _n(s.pressure));
    _notes = TextEditingController(text: s.notes);
    for (final c in [_grind, _temp, _dose, _yield, _time, _pressure, _notes]) {
      c.addListener(_onEdit);
    }
  }

  void _onEdit() {
    if (!mounted) return;
    setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in [_grind, _temp, _dose, _yield, _time, _pressure, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleTimer() {
    HapticFeedback.mediumImpact();
    if (_sw.isRunning) {
      _sw.stop();
      _ticker?.cancel();
      final secs = (_sw.elapsedMilliseconds / 1000).toStringAsFixed(1);
      _time.text = secs.replaceAll('.', ',');
    } else {
      _sw
        ..reset()
        ..start();
      _ticker = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) {
          if (mounted) setState(() {});
        },
      );
      setState(() {});
    }
  }

  void _apply() {
    s.grind = _grind.text.trim();
    s.temperature = parseNum(_temp.text);
    s.doseIn = parseNum(_dose.text);
    s.yieldOut = parseNum(_yield.text);
    s.timeSec = parseNum(_time.text);
    s.pressure = parseNum(_pressure.text);
    s.notes = _notes.text.trim();
  }

  Future<void> _save() async {
    if (_sw.isRunning) _toggleTimer();
    _apply();
    await Store.instance.saveShot(s);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscard() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Änderungen verwerfen?'),
        content: const Text('Der Shot wurde noch nicht gespeichert.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Weiter bearbeiten'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verwerfen'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  void _mark(VoidCallback f) => setState(() {
        f();
        _dirty = true;
      });

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final t = store.targets;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final dose = parseNum(_dose.text);
    final out = parseNum(_yield.text);
    final time =
        _sw.isRunning ? _sw.elapsedMilliseconds / 1000 : parseNum(_time.text);
    final pressure = parseNum(_pressure.text);
    final ratio = ratioOf(dose, out);
    final tip =
        dialInTip(_sw.isRunning ? null : time, s.acidity, s.bitterness, t);

    const gap = SizedBox(height: 12);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew ? 'Neuer Shot' : 'Shot bearbeiten'),
          actions: [
            IconButton(
              tooltip: 'Favorit',
              icon: Icon(s.favorite ? Icons.favorite : Icons.favorite_border),
              onPressed: () => _mark(() => s.favorite = !s.favorite),
            ),
            IconButton(
              tooltip: 'Setup als Standard anpinnen',
              icon: const Icon(Icons.push_pin_outlined),
              onPressed: _pinAll,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _save,
                child: const Text('Speichern'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            _section('Setup'),
            _beanPicker(store),
            gap,
            Row(
              children: [
                Expanded(
                    child: _field(_grind, 'Mahlgrad',
                        text: true, pinKey: 'grind')),
                const SizedBox(width: 12),
                Expanded(
                    child: _field(_temp, 'Temperatur',
                        suffix: '°C', pinKey: 'temperature')),
              ],
            ),
            gap,
            if (store.machines.length > 1 || s.machine.isNotEmpty) ...[
              _choice('Maschine', store.machines, s.machine,
                  (v) => s.machine = v, 'machine'),
              gap,
            ],
            _choice('Siebträger', store.portafilters, s.portafilter,
                (v) => s.portafilter = v, 'portafilter'),
            gap,
            _choice(
                'Sieb', store.baskets, s.basket, (v) => s.basket = v, 'basket'),
            _section('Bezug'),
            if (store.useTimer) ...[
              _timerCard(scheme, theme, time, t),
              gap,
            ],
            Row(
              children: [
                Expanded(
                    child:
                        _field(_dose, 'Bohnen', suffix: 'g', pinKey: 'doseIn')),
                const SizedBox(width: 12),
                Expanded(child: _field(_yield, 'Espresso', suffix: 'g')),
              ],
            ),
            gap,
            Row(
              children: [
                Expanded(child: _field(_time, 'Durchlaufzeit', suffix: 's')),
                const SizedBox(width: 12),
                Expanded(child: _field(_pressure, 'Druck', suffix: 'bar')),
              ],
            ),
            gap,
            _statusCard(theme, t, dose, ratio, time, pressure),
            _section('Geschmack'),
            _scale('Säure', s.acidity, _acidityLabels, (v) => s.acidity = v,
                scheme),
            _scale('Bitterkeit', s.bitterness, _bitternessLabels,
                (v) => s.bitterness = v, scheme),
            _stars(theme),
            gap,
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notizen',
                hintText: 'Crema, Aroma, Auffälligkeiten …',
              ),
            ),
            if (tip != null) ...[
              gap,
              Card(
                margin: EdgeInsets.zero,
                color: scheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: scheme.onTertiaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tip,
                          style: TextStyle(color: scheme.onTertiaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  Widget _field(TextEditingController c, String label,
      {String? suffix, bool text = false, String? pinKey}) {
    final d = Store.instance.defaults;
    var pinned = false;
    String? helper;
    if (pinKey != null) {
      final pin = text ? d.text(pinKey) : d.number(pinKey);
      if (pin != null) {
        final shown = pin is double ? fmtSmart(pin) : pin.toString();
        final now = text ? c.text.trim() : _n(parseNum(c.text));
        pinned = now == shown;
        if (!pinned) helper = 'Standard: $shown';
      }
    }
    final hasPin =
        pinKey != null && (text ? d.text(pinKey) : d.number(pinKey)) != null;
    return TextField(
      controller: c,
      keyboardType: text
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        helperText: helper,
        suffixIcon: pinKey == null
            ? null
            : IconButton(
                tooltip: hasPin ? 'Pin lösen' : 'Als Standard anpinnen',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  hasPin ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 20,
                  color: pinned ? Theme.of(context).colorScheme.primary : null,
                ),
                onPressed: () => _togglePin(pinKey, c, text),
              ),
      ),
    );
  }

  void _togglePin(String key, TextEditingController c, bool text) {
    final d = Store.instance.defaults;
    HapticFeedback.mediumImpact();
    setState(() {
      if (text) {
        d.setText(key, d.text(key) != null ? null : c.text.trim());
      } else {
        d.setNumber(key, d.number(key) != null ? null : parseNum(c.text));
      }
    });
    Store.instance.save();
  }

  void _pinChoice(String key, String value) {
    final d = Store.instance.defaults;
    HapticFeedback.heavyImpact();
    setState(() => d.setText(key, d.text(key) == value ? null : value));
    Store.instance.save();
  }

  /// Übernimmt das komplette Setup dieses Shots als neuen Standard.
  void _pinAll() {
    _apply();
    final d = Store.instance.defaults;
    HapticFeedback.heavyImpact();
    setState(() {
      d.setText('machine', s.machine);
      d.setText('portafilter', s.portafilter);
      d.setText('basket', s.basket);
      d.setText('grind', s.grind);
      d.temperature = s.temperature;
      d.doseIn = s.doseIn;
    });
    Store.instance.save();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Setup als Standard für neue Shots angepinnt')));
  }

  Future<void> _addBean() async {
    final b = await editBeanDialog(context, null);
    if (b != null) _mark(() => s.beanId = b.id);
  }

  Widget _beanPicker(Store store) {
    final options =
        store.beans.where((b) => !b.archived || b.id == s.beanId).toList();
    if (options.isEmpty) {
      return OutlinedButton.icon(
        onPressed: _addBean,
        icon: const Icon(Icons.add),
        label: const Text('Erste Bohne anlegen'),
      );
    }
    final value = options.any((b) => b.id == s.beanId) ? s.beanId : null;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String?>(
            key: ValueKey('bean-$value-${options.length}'),
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Bohne'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Keine Angabe'),
              ),
              for (final b in options)
                DropdownMenuItem<String?>(
                  value: b.id,
                  child: Text(b.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => _mark(() => s.beanId = v),
          ),
        ),
        IconButton(
          tooltip: 'Neue Bohne',
          icon: const Icon(Icons.add),
          onPressed: _addBean,
        ),
      ],
    );
  }

  Widget _choice(String label, List<String> options, String current,
      void Function(String) set, String pinKey) {
    final opts = [...options];
    if (current.isNotEmpty && !opts.contains(current)) opts.add(current);
    if (opts.isEmpty) return const SizedBox.shrink();
    final pinned = Store.instance.defaults.text(pinKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final o in opts)
              GestureDetector(
                onLongPress: () => _pinChoice(pinKey, o),
                child: ChoiceChip(
                  avatar:
                      o == pinned ? const Icon(Icons.push_pin, size: 16) : null,
                  label: Text(o),
                  selected: o == current,
                  onSelected: (_) => _mark(() => set(o)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _timerCard(
      ColorScheme scheme, ThemeData theme, double? time, Targets t) {
    final running = _sw.isRunning;
    final secs = time ?? 0;
    final level = t.timeLevel(time);
    final color =
        level == Level.none ? scheme.onSurface : levelColor(level, scheme);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggleTimer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: running ? scheme.error : scheme.primary,
                ),
                child: Icon(
                  running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 38,
                  color: running ? scheme.onError : scheme.onPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      running
                          ? 'Läuft. Tippen zum Stoppen.'
                          : 'Starten, sobald die Pumpe anläuft',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    Text(
                      '${secs.toStringAsFixed(1).replaceAll('.', ',')} s',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard(ThemeData theme, Targets t, double? dose, double? ratio,
      double? time, double? pressure) {
    final scheme = theme.colorScheme;
    final targetOut = dose == null ? null : dose * t.ratio;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Row(
              children: [
                _stat(
                    theme,
                    'Verhältnis',
                    ratio == null ? '–' : '1:${fmtNum(ratio, digits: 2)}',
                    t.ratioLevel(ratio),
                    'Ziel 1:${fmtNum(t.ratio)}'),
                _stat(
                    theme,
                    'Zeit',
                    time == null ? '–' : '${fmtNum(time)} s',
                    t.timeLevel(time),
                    'Ziel ${fmtSmart(t.timeMin)}–${fmtSmart(t.timeMax)} s'),
                _stat(
                    theme,
                    'Druck',
                    pressure == null ? '–' : '${fmtSmart(pressure)} bar',
                    t.pressureLevel(pressure),
                    'Ziel ${fmtSmart(t.pressureMin)}–${fmtSmart(t.pressureMax)}'),
              ],
            ),
            if (targetOut != null) ...[
              const SizedBox(height: 10),
              Text(
                'Bei ${fmtSmart(dose!)} g Bohnen: ${fmtNum(targetOut)} g in die Tasse',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(
      ThemeData theme, String label, String value, Level level, String hint) {
    final scheme = theme.colorScheme;
    final color =
        level == Level.none ? scheme.onSurface : levelColor(level, scheme);
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
          Text(hint,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _scale(String label, int value, List<String> labels,
      void Function(int) set, ColorScheme scheme) {
    final v = value.clamp(-2, 2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Text(
              labels[v + 2],
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: v.toDouble(),
          min: -2,
          max: 2,
          divisions: 4,
          onChanged: (x) => _mark(() => set(x.round())),
        ),
      ],
    );
  }

  Widget _stars(ThemeData theme) {
    return Row(
      children: [
        Text('Gesamteindruck', style: theme.textTheme.labelLarge),
        const Spacer(),
        for (var i = 1; i <= 5; i++)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _mark(() => s.rating = s.rating == i ? 0 : i),
            icon: Icon(
              i <= s.rating ? Icons.star_rounded : Icons.star_outline_rounded,
              color: Colors.amber.shade700,
              size: 30,
            ),
          ),
      ],
    );
  }
}
