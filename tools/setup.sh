#!/usr/bin/env bash
# Richtet Flutter + Android SDK headless ein (ohne Android Studio).
# Installiert nach ~/Applications, ändert keine Shell-Konfiguration.
# Erneut ausführbar: bereits Installiertes wird übersprungen.
set -euo pipefail

TOOLS="${KAFFEE_TOOLS:-$HOME/Applications}"
FLUTTER_DIR="$TOOLS/flutter"
SDK_DIR="$TOOLS/android-sdk"
JDK_DIR="$TOOLS/jdk-17"
CMDLINE_ZIP="commandlinetools-linux-13114758_latest.zip"

mkdir -p "$TOOLS"
say() { printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }

# 1) JDK 17 (nur falls kein Java >= 17 vorhanden)
java_ok() {
  command -v java >/dev/null 2>&1 || return 1
  local v
  v=$(java -version 2>&1 | awk -F'"' '/version/ {print $2}' | cut -d. -f1)
  [ "${v:-0}" -ge 17 ] 2>/dev/null
}
if [ -x "$JDK_DIR/bin/java" ]; then
  export JAVA_HOME="$JDK_DIR"
elif java_ok; then
  say "System-Java >= 17 gefunden, kein eigenes JDK nötig"
else
  say "Lade JDK 17 (Temurin)"
  tmp=$(mktemp -d)
  curl -fL "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse" -o "$tmp/jdk.tar.gz"
  mkdir -p "$JDK_DIR"
  tar -xzf "$tmp/jdk.tar.gz" -C "$JDK_DIR" --strip-components=1
  rm -rf "$tmp"
  export JAVA_HOME="$JDK_DIR"
fi
[ -n "${JAVA_HOME:-}" ] && export PATH="$JAVA_HOME/bin:$PATH"

# 2) Flutter SDK (stable, flacher Clone)
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  say "Lade Flutter (stable)"
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

# 3) Android Kommandozeilen-Tools
if [ ! -x "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then
  say "Lade Android Command-line Tools"
  tmp=$(mktemp -d)
  curl -fL "https://dl.google.com/android/repository/$CMDLINE_ZIP" -o "$tmp/cmdline.zip"
  mkdir -p "$SDK_DIR/cmdline-tools"
  unzip -q "$tmp/cmdline.zip" -d "$tmp"
  mv "$tmp/cmdline-tools" "$SDK_DIR/cmdline-tools/latest"
  rm -rf "$tmp"
fi
export ANDROID_HOME="$SDK_DIR"
export PATH="$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools:$PATH"

say "Akzeptiere SDK-Lizenzen und installiere platform-tools"
yes | sdkmanager --sdk_root="$SDK_DIR" --licenses >/dev/null || true
sdkmanager --sdk_root="$SDK_DIR" "platform-tools" >/dev/null

# 4) Flutter konfigurieren: nur Android, keine Telemetrie
say "Konfiguriere Flutter"
flutter config --no-analytics >/dev/null
flutter --disable-analytics >/dev/null 2>&1 || true
dart --disable-analytics >/dev/null 2>&1 || true
flutter config --android-sdk "$SDK_DIR" >/dev/null
flutter config --no-enable-web --no-enable-linux-desktop >/dev/null
[ -n "${JAVA_HOME:-}" ] && flutter config --jdk-dir "$JAVA_HOME" >/dev/null
flutter precache --android --no-ios --no-web --no-linux >/dev/null

# 5) Gradle sparsam halten: kein Hintergrund-Daemon, begrenzter Heap
mkdir -p "$HOME/.gradle"
if ! grep -q 'kaffee-setup' "$HOME/.gradle/gradle.properties" 2>/dev/null; then
  cat >> "$HOME/.gradle/gradle.properties" <<'EOF'
# kaffee-setup: RAM schonen
org.gradle.daemon=false
org.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=768m
kotlin.daemon.jvmargs=-Xmx1g
EOF
fi

# 6) Umgebung für das Build-Skript merken
cat > "$TOOLS/kaffee-env.sh" <<EOF
export ANDROID_HOME="$SDK_DIR"
export PATH="$FLUTTER_DIR/bin:$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools:\$PATH"
${JAVA_HOME:+export JAVA_HOME="$JAVA_HOME"; export PATH="\$JAVA_HOME/bin:\$PATH"}
EOF

say "Prüfe Installation"
yes | flutter doctor --android-licenses >/dev/null 2>&1 || true
flutter doctor -v | sed -n '/Flutter/,/Android toolchain/p' | head -40

say "Fertig. Bauen mit: ./tools/build.sh"
