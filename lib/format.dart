import 'package:flutter/material.dart';

import 'models.dart';

String fmtNum(double? v, {int digits = 1}) {
  if (v == null) return '–';
  return v.toStringAsFixed(digits).replaceAll('.', ',');
}

/// Ganze Zahlen ohne Nachkommastelle, sonst eine Stelle.
String fmtSmart(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1).replaceAll('.', ',');
}

double? parseNum(String s) {
  final t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

String _two(int n) => n.toString().padLeft(2, '0');

String fmtDateRel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final time = '${_two(d.hour)}:${_two(d.minute)}';
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Heute, $time';
  if (diff == 1) return 'Gestern, $time';
  return '${_two(d.day)}.${_two(d.month)}.${d.year}, $time';
}

const okColor = Color(0xFF2E7D32);
const nearColor = Color(0xFFD08700);
const offColor = Color(0xFFC62828);

Color levelColor(Level l, ColorScheme s) => switch (l) {
      Level.ok => okColor,
      Level.near => nearColor,
      Level.off => offColor,
      Level.none => s.outline,
    };
