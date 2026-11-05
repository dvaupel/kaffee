/// Datenmodell: Bohnen, Shots, Zielwerte.
library;

enum Level { ok, near, off, none }

double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

class Bean {
  final String id;
  String name;
  String roaster;
  String notes;
  bool archived;

  Bean({
    required this.id,
    required this.name,
    this.roaster = '',
    this.notes = '',
    this.archived = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'roaster': roaster,
        'notes': notes,
        'archived': archived,
      };

  factory Bean.fromJson(Map<String, dynamic> j) => Bean(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        roaster: j['roaster'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        archived: j['archived'] as bool? ?? false,
      );
}

class Shot {
  final String id;
  DateTime date;
  String? beanId;
  String grind;
  String portafilter;
  String basket;
  double? temperature;
  double? doseIn;
  double? yieldOut;
  double? timeSec;
  double? pressure;

  /// -2 .. 2, 0 = ausgewogen
  int acidity;

  /// -2 .. 2, 0 = angenehm
  int bitterness;

  /// 0 = unbewertet, sonst 1 .. 5
  int rating;
  String notes;
  bool favorite;

  Shot({
    required this.id,
    required this.date,
    this.beanId,
    this.grind = '',
    this.portafilter = '',
    this.basket = '',
    this.temperature,
    this.doseIn,
    this.yieldOut,
    this.timeSec,
    this.pressure,
    this.acidity = 0,
    this.bitterness = 0,
    this.rating = 0,
    this.notes = '',
    this.favorite = false,
  });

  double? get ratio => ratioOf(doseIn, yieldOut);

  Shot clone() => Shot.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'beanId': beanId,
        'grind': grind,
        'portafilter': portafilter,
        'basket': basket,
        'temperature': temperature,
        'doseIn': doseIn,
        'yieldOut': yieldOut,
        'timeSec': timeSec,
        'pressure': pressure,
        'acidity': acidity,
        'bitterness': bitterness,
        'rating': rating,
        'notes': notes,
        'favorite': favorite,
      };

  factory Shot.fromJson(Map<String, dynamic> j) => Shot(
        id: j['id'] as String,
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        beanId: j['beanId'] as String?,
        grind: j['grind'] as String? ?? '',
        portafilter: j['portafilter'] as String? ?? '',
        basket: j['basket'] as String? ?? '',
        temperature: _d(j['temperature']),
        doseIn: _d(j['doseIn']),
        yieldOut: _d(j['yieldOut']),
        timeSec: _d(j['timeSec']),
        pressure: _d(j['pressure']),
        acidity: (j['acidity'] as num?)?.toInt() ?? 0,
        bitterness: (j['bitterness'] as num?)?.toInt() ?? 0,
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        notes: j['notes'] as String? ?? '',
        favorite: j['favorite'] as bool? ?? false,
      );
}

double? ratioOf(double? doseIn, double? yieldOut) {
  if (doseIn == null || yieldOut == null || doseIn <= 0) return null;
  return yieldOut / doseIn;
}

class Targets {
  double timeMin;
  double timeMax;
  double ratio;
  double pressureMin;
  double pressureMax;

  Targets({
    this.timeMin = 25,
    this.timeMax = 28,
    this.ratio = 2.5,
    this.pressureMin = 9,
    this.pressureMax = 11,
  });

  Level timeLevel(double? t) {
    if (t == null) return Level.none;
    if (t >= timeMin && t <= timeMax) return Level.ok;
    if (t >= timeMin - 3 && t <= timeMax + 3) return Level.near;
    return Level.off;
  }

  Level ratioLevel(double? r) {
    if (r == null) return Level.none;
    final d = (r - ratio).abs();
    if (d <= 0.15) return Level.ok;
    if (d <= 0.4) return Level.near;
    return Level.off;
  }

  Level pressureLevel(double? p) {
    if (p == null) return Level.none;
    if (p >= pressureMin && p <= pressureMax) return Level.ok;
    if (p >= pressureMin - 1 && p <= pressureMax + 1) return Level.near;
    return Level.off;
  }

  Map<String, dynamic> toJson() => {
        'timeMin': timeMin,
        'timeMax': timeMax,
        'ratio': ratio,
        'pressureMin': pressureMin,
        'pressureMax': pressureMax,
      };

  factory Targets.fromJson(Map<String, dynamic> j) => Targets(
        timeMin: _d(j['timeMin']) ?? 25,
        timeMax: _d(j['timeMax']) ?? 28,
        ratio: _d(j['ratio']) ?? 2.5,
        pressureMin: _d(j['pressureMin']) ?? 9,
        pressureMax: _d(j['pressureMax']) ?? 11,
      );
}

/// Einfache Einstellhilfe aus Durchlaufzeit und Geschmack.
String? dialInTip(double? timeSec, int acidity, int bitterness, Targets t) {
  final tooFast = timeSec != null && timeSec < t.timeMin;
  final tooSlow = timeSec != null && timeSec > t.timeMax;
  final sour = acidity >= 1;
  final bitter = bitterness >= 1;
  if (sour && bitter) {
    return 'Sauer und bitter zugleich: Verteilung und Tampen prüfen, vermutlich Channeling.';
  }
  if (tooFast && !bitter) return 'Lief zu schnell: etwas feiner mahlen.';
  if (tooSlow && !sour) return 'Lief zu langsam: etwas gröber mahlen.';
  if (sour) return 'Zu sauer: feiner mahlen oder Temperatur erhöhen.';
  if (bitter) return 'Zu bitter: gröber mahlen oder Temperatur senken.';
  return null;
}
