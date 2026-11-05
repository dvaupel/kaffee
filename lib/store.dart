import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Hält alle Daten im Speicher und persistiert sie lokal als JSON.
class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();
  static const _key = 'kaffee_data_v1';

  List<Bean> beans = [];
  List<Shot> shots = [];
  List<String> portafilters = ['Original GRAEF'];
  List<String> baskets = ['Einfach', 'Doppelt'];
  Targets targets = Targets();
  int _seq = 0;

  String newId() => '${DateTime.now().microsecondsSinceEpoch}${_seq++}';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      _fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Laden fehlgeschlagen: $e');
    }
  }

  Map<String, dynamic> toJson() => {
        'app': 'kaffee',
        'version': 1,
        'beans': beans.map((b) => b.toJson()).toList(),
        'shots': shots.map((s) => s.toJson()).toList(),
        'portafilters': portafilters,
        'baskets': baskets,
        'targets': targets.toJson(),
      };

  void _fromJson(Map<String, dynamic> j) {
    beans = (j['beans'] as List? ?? [])
        .map((e) => Bean.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    shots = (j['shots'] as List? ?? [])
        .map((e) => Shot.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final pf = j['portafilters'];
    if (pf is List) portafilters = pf.map((e) => e.toString()).toList();
    final bk = j['baskets'];
    if (bk is List) baskets = bk.map((e) => e.toString()).toList();
    final tg = j['targets'];
    if (tg is Map) targets = Targets.fromJson(Map<String, dynamic>.from(tg));
    _sort();
  }

  void _sort() => shots.sort((a, b) => b.date.compareTo(a.date));

  Future<void> save() async {
    _sort();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  Future<void> importJson(String raw) async {
    final j = jsonDecode(raw);
    if (j is! Map) throw const FormatException('Kein gültiger Export');
    _fromJson(Map<String, dynamic>.from(j));
    await save();
  }

  Bean? beanById(String? id) {
    if (id == null) return null;
    for (final b in beans) {
      if (b.id == id) return b;
    }
    return null;
  }

  List<Shot> shotsForBean(String beanId) =>
      shots.where((s) => s.beanId == beanId).toList();

  /// Bester Shot einer Bohne: Favorit vor Bewertung vor Datum.
  Shot? bestShot(String beanId) {
    final list = shotsForBean(beanId);
    if (list.isEmpty) return null;
    list.sort(compareBest);
    final top = list.first;
    return (top.favorite || top.rating > 0) ? top : null;
  }

  static int compareBest(Shot a, Shot b) {
    if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
    if (a.rating != b.rating) return b.rating.compareTo(a.rating);
    return b.date.compareTo(a.date);
  }

  Future<void> saveShot(Shot s) async {
    final i = shots.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      shots[i] = s;
    } else {
      shots.add(s);
    }
    await save();
  }

  Future<void> deleteShot(Shot s) async {
    shots.removeWhere((x) => x.id == s.id);
    await save();
  }

  Future<void> saveBean(Bean b) async {
    final i = beans.indexWhere((x) => x.id == b.id);
    if (i >= 0) {
      beans[i] = b;
    } else {
      beans.add(b);
    }
    await save();
  }

  Future<void> deleteBean(Bean b) async {
    beans.removeWhere((x) => x.id == b.id);
    await save();
  }

  /// Neuer Shot mit dem Setup des letzten Shots vorbelegt.
  Shot newShotTemplate() {
    if (shots.isNotEmpty) return duplicate(shots.first);
    return Shot(
      id: newId(),
      date: DateTime.now(),
      portafilter: portafilters.isNotEmpty ? portafilters.first : '',
      basket: baskets.length > 1
          ? baskets[1]
          : (baskets.isNotEmpty ? baskets.first : ''),
      doseIn: 18,
    );
  }

  /// Übernimmt Setup und Dosis, Ergebnis und Bewertung bleiben leer.
  Shot duplicate(Shot src) => Shot(
        id: newId(),
        date: DateTime.now(),
        beanId: src.beanId,
        grind: src.grind,
        portafilter: src.portafilter,
        basket: src.basket,
        temperature: src.temperature,
        doseIn: src.doseIn,
      );
}
