#!/usr/bin/env bash
# Exporta el APK debug desde una copia limpia, lo verifica y lo copia a Descargas.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P="$ROOT/build/android_project"
APK="${1:-$HOME/untitled-control/builds/beta_debug.apk}"
GODOT="$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64"
export JAVA_HOME="$PREFIX/lib/jvm/java-17-openjdk"
rm -rf "$P"; mkdir -p "$P" "$(dirname "$APK")"
for d in core scenes assets mods maps; do [ -d "$ROOT/$d" ] && cp -r "$ROOT/$d" "$P/"; done
cp "$ROOT/project.godot" "$ROOT/export_presets.cfg" "$ROOT/icon.svg" "$P/"
grun "$GODOT" --headless --path "$P" --import >/dev/null 2>&1
rm -f "$APK" "$APK.idsig"
LOG="$HOME/untitled-control/cycle2/android_export_last.log"
termux-chroot bash -c "export JAVA_HOME=$JAVA_HOME; grun $GODOT --headless --path $P --export-debug Android $APK" > "$LOG" 2>&1
code=$?
errs=$(grep -v fontconfig "$LOG" | grep -cE 'ERROR|Parse Error|SCRIPT ERROR')
echo "EXPORT_EXIT=$code ERRORS=$errs"
[ "$code" -eq 0 ] && [ -f "$APK" ] || { echo "FAIL: sin APK"; exit 1; }
apksigner verify "$APK" >/dev/null 2>&1 && echo SIG_OK || { echo "FAIL: firma"; exit 1; }
unzip -l "$APK" | grep -qE 'classes.dex' && unzip -l "$APK" | grep -q 'lib/arm64-v8a/libgodot_android.so' && echo STRUCT_OK
echo "sha256=$(sha256sum "$APK" | cut -c1-16) size=$(stat -c%s "$APK")"
cp "$APK" /sdcard/Download/untitled_beta_debug.apk && echo COPIED
[ "$errs" -eq 0 ]
