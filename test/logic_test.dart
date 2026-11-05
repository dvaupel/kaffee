import 'package:flutter_test/flutter_test.dart';
import 'package:kaffee/format.dart';
import 'package:kaffee/insights.dart';
import 'package:kaffee/models.dart';
import 'package:kaffee/updater.dart';

void main() {
  test('Zahlen mit Komma', () {
    expect(parseNum('18,5'), 18.5);
    expect(fmtSmart(25), '25');
    expect(fmtNum(2.5), '2,5');
  });

  test('Ampel', () {
    final t = Targets();
    expect(t.timeLevel(26), Level.ok);
    expect(t.timeLevel(30), Level.near);
    expect(t.timeLevel(15), Level.off);
    expect(t.ratioLevel(45 / 18), Level.ok);
  });

  test('Tipps', () {
    final t = Targets();
    expect(dialInTip(18, 0, 0, t), contains('feiner'));
    expect(dialInTip(35, 0, 0, t), contains('gröber'));
    expect(dialInTip(26, 0, 0, t), isNull);
  });

  Shot shot(String id, int rating, {double? temp, int day = 1, String? bean}) =>
      Shot(
        id: id,
        date: DateTime(2026, 1, day),
        beanId: bean ?? 'b',
        rating: rating,
        temperature: temp,
        doseIn: 18,
        yieldOut: 45,
        timeSec: 26,
      );

  test('Sortierung nach Bewertung', () {
    final l = sortShots(
        [shot('a', 2), shot('b', 5, day: 2), shot('c', 0, day: 3)],
        ShotSort.rating,
        Targets());
    expect(l.map((s) => s.id), ['b', 'a', 'c']);
  });

  test('Zusammenhang Temperatur und Bewertung', () {
    final shots = [
      for (var i = 0; i < 6; i++)
        shot('s$i', 1 + (i * 4 ~/ 5), temp: 90 + i.toDouble(), day: i + 1),
    ];
    final ins = buildInsights(shots, Targets(), (_) => 'Bohne');
    expect(
        ins.where((i) =>
            i.kind == InsightKind.factor && i.title.contains('Temperatur')),
        isNotEmpty);
    expect(ins.any((i) => i.kind == InsightKind.sweetSpot), isTrue);
  });

  test('Standardwerte überschreiben nur angepinnte Felder', () {
    final d = Defaults(temperature: 93, basket: 'Doppelt');
    final s = d.applyTo(Shot(
        id: 'x',
        date: DateTime(2026),
        temperature: 90,
        basket: 'Einfach',
        doseIn: 17));
    expect(s.temperature, 93);
    expect(s.basket, 'Doppelt');
    expect(s.doseIn, 17);
    expect(Defaults.fromJson(d.toJson()).temperature, 93);
  });

  test('Versionsvergleich', () {
    expect(isNewerVersion('v0.3.0', '0.2.0'), isTrue);
    expect(isNewerVersion('v0.10.0', '0.9.5'), isTrue);
    expect(isNewerVersion('v0.2.0', '0.2.0'), isFalse);
    expect(isNewerVersion('v0.1.9', '0.2.0'), isFalse);
    expect(isNewerVersion('nightly', '0.2.0'), isFalse);
  });

  test('Maschine: Stufen im JSON, altes Format bleibt lesbar', () {
    final m = Machine.fromJson(Machine('Gräf', tempLevels: 5).toJson());
    expect(m.name, 'Gräf');
    expect(m.tempLevels, 5);
    expect(Machine.fromJson('Alt').tempLevels, 0);
  });

  test('Temperaturstufe: Text, Standardwert und JSON', () {
    final shot = Shot(id: 'a', date: DateTime(2026), tempLevel: 3);
    expect(shot.tempText, 'Stufe 3');
    expect(Shot.fromJson(shot.toJson()).tempLevel, 3);
    final d = Defaults(tempLevel: 4);
    expect(d.applyTo(Shot(id: 'b', date: DateTime(2026))).tempLevel, 4);
    expect(Defaults.fromJson(d.toJson()).tempLevel, 4);
  });
}
