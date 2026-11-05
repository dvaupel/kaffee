#!/usr/bin/env bash
# Baut eine sideloadbare APK nach dist/.
# Nutzung: ./tools/build.sh          (arm64, klein, für aktuelle Handys)
#          ./tools/build.sh --all    (universelle APK, größer)
set -euo pipefail

cd "$(dirname "$0")/.."
TOOLS="${KAFFEE_TOOLS:-$HOME/Applications}"
if [ -f "$TOOLS/kaffee-env.sh" ]; then
  # shellcheck disable=SC1091
  source "$TOOLS/kaffee-env.sh"
fi
command -v flutter >/dev/null || { echo "Flutter fehlt: erst ./tools/setup.sh ausführen"; exit 1; }

# Android-Projekt beim ersten Mal erzeugen (bestehende Dateien bleiben unangetastet)
if [ ! -d android ]; then
  echo "==> Erzeuge Android-Projekt"
  flutter create --project-name kaffee --org de.vaupel --platforms android . >/dev/null
  sed -i 's/android:label="kaffee"/android:label="Kaffee-Tagebuch"/' android/app/src/main/AndroidManifest.xml
  # Template setzt sehr viel Gradle-Heap; auf moderate Werte begrenzen
  sed -i 's/^org.gradle.jvmargs=.*/org.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=768m/' android/gradle.properties
  rm -f test/widget_test.dart
fi

flutter pub get >/dev/null

VERSION=$(awk '/^version:/ {print $2}' pubspec.yaml | cut -d+ -f1)
BUILD_NO=$(git rev-list --count HEAD 2>/dev/null || echo 1)

mkdir -p dist
if [ "${1:-}" = "--all" ]; then
  flutter build apk --release --build-number "$BUILD_NO"
  cp build/app/outputs/flutter-apk/app-release.apk "dist/kaffee-$VERSION-$BUILD_NO.apk"
else
  flutter build apk --release --split-per-abi --target-platform android-arm64 --build-number "$BUILD_NO"
  cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "dist/kaffee-$VERSION-$BUILD_NO.apk"
fi

echo
echo "APK: $(pwd)/dist/kaffee-$VERSION-$BUILD_NO.apk ($(du -h "dist/kaffee-$VERSION-$BUILD_NO.apk" | cut -f1))"
