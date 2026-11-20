#!/usr/bin/env bash
# Compila el APK de VR (Quest) en CI (Linux x86_64). Requiere: godot, JDK17, Android SDK, plantillas de exportacion 4.7.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; P="$ROOT/build/vr_project"; OUT="${1:-$ROOT/build/untitled_vr_debug.apk}"
GODOT="${GODOT:-godot}"; PRESET="Quest VR"
VENDOR_VERSION="5.2.0-stable"
VENDOR_SHA256="2a3958fff0de2dbdc4f1a036b5e4cfcea12ae7e45f8deebf4b45e5e9718c4e35"
VENDOR_URL="https://github.com/GodotVR/godot_openxr_vendors/releases/download/${VENDOR_VERSION}/godotopenxrvendorsaddon.zip"
TEMPLATE_ZIP="$HOME/.local/share/godot/export_templates/4.7.stable/android_source.zip"
KEYSTORE="${KEYSTORE:-$HOME/.android/debug.keystore}"
rm -rf "$P"; mkdir -p "$P/addons" "$P/android/build" "$(dirname "$OUT")"
for d in core scenes assets mods maps; do [ -d "$ROOT/$d" ] && cp -r "$ROOT/$d" "$P/"; done
cp "$ROOT/project.godot" "$ROOT/export_presets.cfg" "$ROOT/icon.svg" "$P/"; [ -f "$ROOT/icon.svg.import" ] && cp "$ROOT/icon.svg.import" "$P/"
[ -f "$ROOT/openxr_action_map.tres" ] && cp "$ROOT/openxr_action_map.tres" "$P/"
T="$(mktemp -d)"; curl -fsSL "$VENDOR_URL" -o "$T/v.zip"; echo "$VENDOR_SHA256  $T/v.zip" | sha256sum -c -
unzip -q "$T/v.zip" -d "$T/u"; A="$(find "$T/u" -type d -name godotopenxrvendors | head -1)"; [ -n "$A" ] || { echo "sin addon"; exit 1; }
cp -r "$A" "$P/addons/"
unzip -q "$TEMPLATE_ZIP" -d "$P/android/build"; touch "$P/android/.gdignore"; find "$P/android" -name '*.import' -type f -delete
printf '4.7.stable' > "$P/android/.build_version"
printf '\norg.gradle.daemon=false\norg.gradle.jvmargs=-Xmx3g\n' >> "$P/android/build/gradle.properties"
python3 "$ROOT/tools/vr_project_settings.py" "$P/project.godot"
sed -i "s#/data/data/com.termux/files/home/untitled-control/keys/debug.keystore#$KEYSTORE#g" "$P/export_presets.cfg"
"$GODOT" --headless --path "$P" --import || true
"$GODOT" --headless --path "$P" --export-debug "$PRESET" "$OUT"
test -s "$OUT" && echo "APK_OK $(stat -c%s "$OUT") $(sha256sum "$OUT" | cut -c1-16)"
