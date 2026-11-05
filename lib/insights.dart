/// Auswertung der Shots: Sortierung, Empfehlungen, Zusammenhänge.
library;

import 'dart:math' as math;

import 'format.dart';
import 'models.dart';
import 'store.dart';

enum ShotSort { newest, rating, targets }

extension ShotSortLabel on ShotSort {
  String get label => switch (this) {
        ShotSort.newest => 'Neueste zuerst',
        ShotSort.rating => 'Beste Bewertung',
        ShotSort.targets => 'Meiste Zielwerte getroffen',
      };
}

/// Wie viele der drei Zielwerte (Zeit, Verhältnis, Druck) im grünen Bereich liegen.
int targetScore(Shot s, Targets t) => [
      t.timeLevel(s.timeSec),
      t.ratioLevel(s.ratio),
      t.pressureLevel(s.pressure),
    ].where((l) => l == Level.ok).length;

List<Shot> sortShots(List<Shot> shots, ShotSort sort, Targets t) {
  int byDate(Shot a, Shot b) => b.date.compareTo(a.date);
  int byRating(Shot a, Shot b) => b.rating.compareTo(a.rating);
  final list = [...shots];
  switch (sort) {
    case ShotSort.newest:
      list.sort(byDate);
    case ShotSort.rating:
      list.sort((a, b) => byRating(a, b) != 0 ? byRating(a, b) : byDate(a, b));
    case ShotSort.targets:
      list.sort((a, b) {
        final c = targetScore(b, t).compareTo(targetScore(a, t));
        if (c != 0) return c;
        return byRating(a, b) != 0 ? byRating(a, b) : byDate(a, b);
      });
  }
  return list;
}

enum InsightKind { nextStep, sweetSpot, factor, compare }

class Insight {
  const Insight(this.kind, this.title, this.text);
  final InsightKind kind;
  final String title;
  final String text;
}

/// Pearson-Korrelation, `null` bei zu wenig Streuung.
double? pearson(List<double> x, List<double> y) {
  final n = x.length;
  if (n < 3 || y.length != n) return null;
  final mx = x.reduce((a, b) => a + b) / n;
  final my = y.reduce((a, b) => a + b) / n;
  var sxy = 0.0, sxx = 0.0, syy = 0.0;
  for (var i = 0; i < n; i++) {
    sxy += (x[i] - mx) * (y[i] - my);
    sxx += (x[i] - mx) * (x[i] - mx);
    syy += (y[i] - my) * (y[i] - my);
  }
  if (sxx < 1e-9 || syy < 1e-9) return null;
  return sxy / math.sqrt(sxx * syy);
}

double _avg(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;

class _Factor {
  const _Factor(this.name, this.unit, this.get);
  final String name;
  final String unit;
  final double? Function(Shot) get;
}

final _factors = <_Factor>[
  _Factor('Temperatur', ' °C', (s) => s.temperature),
  _Factor('Dosis', ' g', (s) => s.doseIn),
  _Factor('Verhältnis', '', (s) => s.ratio),
  _Factor('Durchlaufzeit', ' s', (s) => s.timeSec),
  _Factor('Druck', ' bar', (s) => s.pressure),
  _Factor('Mahlgrad', '', (s) => parseNum(s.grind)),
];

String _fmtFactor(_Factor f, double v) => f.name == 'Verhältnis'
    ? '1:${fmtNum(v, digits: 2)}'
    : '${fmtSmart(double.parse(v.toStringAsFixed(1)))}${f.unit}';

/// Leitet aus den bewerteten Shots Empfehlungen ab.
List<Insight> buildInsights(
  List<Shot> shots,
  Targets t,
  String Function(String? beanId) beanName,
) {
  final nextSteps = <Insight>[];
  final sweet = <Insight>[];
  final factors = <Insight>[];

  final byBean = <String?, List<Shot>>{};
  for (final s in shots) {
    byBean.putIfAbsent(s.beanId, () => []).add(s);
  }

  for (final e in byBean.entries) {
    final name = beanName(e.key);
    final group = sortShots(e.value, ShotSort.newest, t);

    // Nächster Schritt: letzter Shot war noch nicht gut.
    final latest = group.first;
    if (latest.rating < 4) {
      final tip =
          dialInTip(latest.timeSec, latest.acidity, latest.bitterness, t);
      if (tip != null) nextSteps.add(Insight(InsightKind.nextStep, name, tip));
    }

    // Sweet Spot: Durchschnitt der guten Shots (4 Sterne und mehr).
    final good = group.where((s) => s.rating >= 4).toList();
    if (good.isNotEmpty) {
      final parts = <String>[];
      for (final f in _factors) {
        final v = good.map(f.get).whereType<double>();
        if (v.isNotEmpty) parts.add('${f.name} ${_fmtFactor(f, _avg(v))}');
      }
      if (parts.isNotEmpty) {
        final basis = good.length == 1
            ? 'Dein guter Shot'
            : 'Ø aus ${good.length} Shots mit 4+ Sternen';
        sweet.add(Insight(
            InsightKind.sweetSpot, name, '$basis: ${parts.join(' · ')}'));
      }
    }

    // Zusammenhänge zwischen Parameter und Bewertung (nur innerhalb einer Bohne).
    final rated = group.where((s) => s.rating > 0).toList();
    if (rated.length >= 5) {
      for (final f in _factors) {
        final pairs = rated.where((s) => f.get(s) != null).toList();
        if (pairs.length < 5) continue;
        final xs = pairs.map((s) => f.get(s)!).toList();
        if (xs.toSet().length < 3) continue;
        final r = pearson(xs, pairs.map((s) => s.rating.toDouble()).toList());
        if (r == null || r.abs() < 0.5) continue;
        final best = ([...pairs]..sort(Store.compareBest)).first;
        factors.add(Insight(
          InsightKind.factor,
          '$name · ${f.name}',
          '${r > 0 ? 'Höhere' : 'Niedrigere'} Werte wurden besser bewertet '
              '(${pairs.length} Shots, ${r.abs() >= 0.7 ? 'starker' : 'mittlerer'} '
              'Zusammenhang). Bester Shot: ${_fmtFactor(f, f.get(best)!)}.',
        ));
      }
    }
  }

  return [
    ...nextSteps,
    ...sweet,
    ...factors,
    ..._compareInsights(shots, t),
  ];
}

List<Insight> _compareInsights(List<Shot> shots, Targets t) {
  final out = <Insight>[];
  final rated = shots.where((s) => s.rating > 0).toList();

  // Ausrüstung: Durchschnittsbewertung je Maschine, Siebträger, Sieb.
  void equipment(String title, String Function(Shot) get) {
    final groups = <String, List<int>>{};
    for (final s in rated) {
      final k = get(s);
      if (k.isNotEmpty) groups.putIfAbsent(k, () => []).add(s.rating);
    }
    final valid = groups.entries.where((e) => e.value.length >= 2).toList();
    if (valid.length < 2) return;
    valid.sort((a, b) => _avg(b.value.map((e) => e.toDouble()))
        .compareTo(_avg(a.value.map((e) => e.toDouble()))));
    final best = valid.first, worst = valid.last;
    final ab = _avg(best.value.map((e) => e.toDouble()));
    final aw = _avg(worst.value.map((e) => e.toDouble()));
    if (ab - aw < 0.5) return;
    out.add(Insight(
      InsightKind.compare,
      title,
      '„${best.key}“ schneidet besser ab: Ø ${fmtNum(ab)} Sterne '
      '(${best.value.length} Shots) gegenüber Ø ${fmtNum(aw)} '
      'mit „${worst.key}“ (${worst.value.length} Shots).',
    ));
  }

  equipment('Maschine', (s) => s.machine);
  equipment('Siebträger', (s) => s.portafilter);
  equipment('Sieb', (s) => s.basket);

  // Passen die Zielwerte zum eigenen Geschmack?
  void target(String title, String range, Level Function(Shot) level) {
    final inside = rated.where((s) => level(s) == Level.ok).toList();
    final outside = rated
        .where((s) => level(s) != Level.ok && level(s) != Level.none)
        .toList();
    if (inside.length < 3 || outside.length < 3) return;
    final ai = _avg(inside.map((s) => s.rating.toDouble()));
    final ao = _avg(outside.map((s) => s.rating.toDouble()));
    if ((ai - ao).abs() < 0.5) return;
    out.add(Insight(
      InsightKind.compare,
      title,
      ai > ao
          ? 'Im Zielbereich ($range) bewertest du besser: Ø ${fmtNum(ai)} '
              'gegenüber Ø ${fmtNum(ao)} außerhalb. Die Zielwerte passen zu dir.'
          : 'Außerhalb des Zielbereichs ($range) schmeckt es dir besser: '
              'Ø ${fmtNum(ao)} gegenüber Ø ${fmtNum(ai)} im Ziel. '
              'Eventuell den Zielwert im Setup anpassen.',
    ));
  }

  target('Durchlaufzeit', '${fmtSmart(t.timeMin)}–${fmtSmart(t.timeMax)} s',
      (s) => t.timeLevel(s.timeSec));
  target('Verhältnis', '1:${fmtNum(t.ratio)}', (s) => t.ratioLevel(s.ratio));
  return out;
}
