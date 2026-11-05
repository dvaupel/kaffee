# Kaffee-Tagebuch

Espresso-Tagebuch für die Siebträgermaschine (GRAEF Marchesta): Shots erfassen,
Parameter vergleichen, pro Bohne das beste Rezept finden.

## Funktionen (v0.1)

- Shot erfassen: Bohne, Mahlgrad, Siebträger, Sieb, Temperatur, Dosis, Ausbeute, Zeit, Druck
- Shot-Timer mit Ampel gegen die Zielwerte (25 bis 28 s, 1:2,5, 9 bis 11 bar, anpassbar)
- Geschmack: Säure, Bitterkeit, Gesamteindruck, Notizen
- Einstellhilfe ("feiner mahlen", "gröber mahlen", ...)
- Neuer Shot übernimmt das Setup des letzten Shots
- Bohnen mit "bestem Rezept", Favoriten
- Export/Import über die Zwischenablage, Daten bleiben lokal auf dem Gerät

## Einrichtung (einmalig, ohne Android Studio)

```bash
./tools/setup.sh
```

Installiert JDK 17 (falls nötig), Flutter und die Android-Kommandozeilen-Tools nach
`~/Applications`. Shell-Konfiguration bleibt unverändert. Gradle läuft ohne
Hintergrund-Daemon und mit 2 GB Heap.

## APK bauen

```bash
./tools/build.sh         # arm64, für aktuelle Android-Handys
./tools/build.sh --all   # universelle APK
```

Die APK landet in `dist/`. Zum Installieren aufs Handy kopieren und
"Installation aus unbekannten Quellen" erlauben.

Signiert wird vorerst mit dem lokalen Debug-Schlüssel (`~/.android/debug.keystore`).
Updates lassen sich installieren, solange vom selben Rechner gebaut wird.
Vor einer Veröffentlichung wird ein eigener Release-Schlüssel eingerichtet.
