import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Eine automatische Sicherung des kompletten Datenbestands.
class Backup {
  Backup(this.date, this.reason, this.data);

  final DateTime date;
  final String reason;
  final String data;

  Map<String, dynamic> toJson() =>
      {'date': date.toIso8601String(), 'reason': reason, 'data': data};

  factory Backup.fromJson(Map<String, dynamic> j) => Backup(
        DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        j['reason'] as String? ?? '',
        j['data'] as String? ?? '',
      );

  /// (Shots, Bohnen); (0, 0), wenn die Sicherung nicht lesbar ist.
  (int, int) get counts {
    try {
      final j = jsonDecode(data) as Map;
      return (
        (j['shots'] as List? ?? []).length,
        (j['beans'] as List? ?? []).length
      );
    } catch (_) {
      return (0, 0);
    }
  }
}

/// Hält alle Daten im Speicher und persistiert sie lokal als JSON.
class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();
  static const _key = 'kaffee_data_v1';
  static const _backupKey = 'kaffee_backups_v1';
  static const _maxBackups = 10;

  List<Bean> beans = [];
  List<Shot> shots = [];
  List<Machine> machines = [Machine('GRAEF Marchesta')];
  List<String> portafilters = ['Original GRAEF'];
  List<String> baskets = ['Einfach', 'Doppelt'];
  Targets targets = Targets();
  Defaults defaults = Defaults();

  /// Eingebauter Shot-Timer; aus, wenn die Waage selbst eine Zeit liefert.
  bool useTimer = true;
  int _seq = 0;

  String newId() => '${DateTime.now().microsecondsSinceEpoch}${_seq++}';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      _fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // Nicht überschreiben lassen: die Rohdaten bleiben als Sicherung erhalten.
      debugPrint('Laden fehlgeschlagen: $e');
      await snapshot('Daten nicht lesbar', raw: raw);
    }
  }

  Future<List<Backup>> backups() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_backupKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Backup.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Legt eine Sicherung an (neueste zuerst), maximal [_maxBackups].
  Future<void> snapshot(String reason, {String? raw}) async {
    final data = raw ?? jsonEncode(toJson());
    final list = await backups();
    if (list.isNotEmpty && list.first.data == data) return;
    list.insert(0, Backup(DateTime.now(), reason, data));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backupKey,
        jsonEncode(list.take(_maxBackups).map((b) => b.toJson()).toList()));
  }

  /// Beim Start: höchstens eine automatische Sicherung pro Tag, nur mit Daten.
  Future<void> autoSnapshot() async {
    if (shots.isEmpty && beans.isEmpty) return;
    final list = await backups();
    final last = list.where((b) => b.reason == 'Automatisch').firstOrNull;
    if (last != null &&
        DateTime.now().difference(last.date) < const Duration(hours: 20)) {
      return;
    }
    await snapshot('Automatisch');
  }

  Future<void> restore(Backup b) async {
    await snapshot('Vor Wiederherstellung');
    await importJson(b.data);
  }

  Map<String, dynamic> toJson() => {
        'app': 'kaffee',
        'version': 1,
        'beans': beans.map((b) => b.toJson()).toList(),
        'shots': shots.map((s) => s.toJson()).toList(),
        'machines': machines.map((m) => m.toJson()).toList(),
        'portafilters': portafilters,
        'baskets': baskets,
        'targets': targets.toJson(),
        'defaults': defaults.toJson(),
        'useTimer': useTimer,
      };

  void _fromJson(Map<String, dynamic> j) {
    beans = (j['beans'] as List? ?? [])
        .map((e) => Bean.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    shots = (j['shots'] as List? ?? [])
        .map((e) => Shot.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final mc = j['machines'];
    if (mc is List) machines = mc.map(Machine.fromJson).toList();
    final pf = j['portafilters'];
    if (pf is List) portafilters = pf.map((e) => e.toString()).toList();
    final bk = j['baskets'];
    if (bk is List) baskets = bk.map((e) => e.toString()).toList();
    final tg = j['targets'];
    if (tg is Map) targets = Targets.fromJson(Map<String, dynamic>.from(tg));
    final df = j['defaults'];
    if (df is Map) defaults = Defaults.fromJson(Map<String, dynamic>.from(df));
    useTimer = j['useTimer'] as bool? ?? true;
    _sort();
  }

  List<String> get machineNames => machines.map((m) => m.name).toList();

  Machine? machineByName(String name) {
    for (final m in machines) {
      if (m.name == name) return m;
    }
    return null;
  }

  /// Temperaturstufen der Maschine; 0 = Gradzahl (auch ohne Maschine).
  int tempLevelsFor(String machine) => machineByName(machine)?.tempLevels ?? 0;

  /// Benennt eine Maschine um und zieht Shots und Standardwert nach.
  void renameMachine(Machine m, String name) {
    for (final s in shots) {
      if (s.machine == m.name) s.machine = name;
    }
    if (defaults.machine == m.name) defaults.machine = name;
    m.name = name;
  }

  /// Benennt Siebträger ('portafilter') oder Sieb ('basket') um und zieht
  /// Shots und Standardwert nach.
  void renameEquipment(String key, String from, String to) {
    for (final s in shots) {
      if (key == 'portafilter' && s.portafilter == from) s.portafilter = to;
      if (key == 'basket' && s.basket == from) s.basket = to;
    }
    if (defaults.text(key) == from) defaults.setText(key, to);
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
    await snapshot('Vor Import');
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

  /// Neuer Shot: Setup des letzten Shots, darüber die angepinnten Standardwerte.
  Shot newShotTemplate() => defaults.applyTo(_baseTemplate());

  Shot _baseTemplate() {
    if (shots.isNotEmpty) return duplicate(shots.first);
    return Shot(
      id: newId(),
      date: DateTime.now(),
      machine: machines.isNotEmpty ? machines.first.name : '',
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
        machine: src.machine,
        grind: src.grind,
        portafilter: src.portafilter,
        basket: src.basket,
        temperature: src.temperature,
        tempLevel: src.tempLevel,
        doseIn: src.doseIn,
      );
}
