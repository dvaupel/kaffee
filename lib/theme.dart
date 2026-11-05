import 'package:flutter/material.dart';

const _espresso = Color(0xFF7B4B2A);
const _cream = Color(0xFFFBF6F0);

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final scheme =
      ColorScheme.fromSeed(seedColor: _espresso, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: light ? _cream : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: light ? _cream : scheme.surface,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: light ? Colors.white : scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: light ? Colors.white : scheme.surfaceContainerHigh,
    ),
  );
}
