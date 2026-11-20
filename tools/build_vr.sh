#!/usr/bin/env bash
# Compila el APK debug de Quest/OpenXR desde una copia aislada del proyecto.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P="$ROOT/build/vr_project"
APK="${1:-$HOME/untitled-control/builds/untitled_vr_debug.apk}"
GODOT="$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64"
VENDOR_VERSION="5.2.0-stable"
VENDOR_SHA256="2a3958fff0de2dbdc4f1a036b5e4cfcea12ae7e45f8deebf4b45e5e9718c4e35"
VENDOR_LICENSE_SHA256="6133abb9ee2e3752675df201d5a5c0942a0762558b35d2471ebfae72cad82b61"
VENDOR_URL="https://github.com/GodotVR/godot_openxr_vendors/releases/download/${VENDOR_VERSION}/godotopenxrvendorsaddon.zip"
VENDOR_LICENSE_URL="https://raw.githubusercontent.com/GodotVR/godot_openxr_vendors/master/LICENSE"
VENDOR_CACHE="$HOME/untitled-control/vendor/godotopenxrvendors-${VENDOR_VERSION}"
TEMPLATE_ZIP="$HOME/.local/share/godot/export_templates/4.7.stable/android_source.zip"
CONTROL="$HOME/untitled-control"
LOG="$CONTROL/cycle2/v1_vr_export_last.log"
IMPORT_LOG="$CONTROL/cycle2/v1_vr_import_last.log"
AAPT2_OVERRIDE="$HOME/Android/Sdk/build-tools/34.0.0/aapt2"
PRESET="Quest VR"

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
JAVA_HOME="$PREFIX/lib/jvm/java-17-openjdk"
ANDROID_HOME="$HOME/Android/Sdk"
ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME ANDROID_HOME ANDROID_SDK_ROOT

fail() {
	echo "FAIL: $*"
	exit 1
}

[ -x "$GODOT" ] || fail "falta Godot: $GODOT"
[ -f "$TEMPLATE_ZIP" ] || fail "falta plantilla Android: $TEMPLATE_ZIP"
[ -x "$AAPT2_OVERRIDE" ] || fail "falta aapt2 nativo: $AAPT2_OVERRIDE"
command -v unzip >/dev/null 2>&1 || fail "falta unzip"
command -v termux-chroot >/dev/null 2>&1 || fail "falta termux-chroot"

if [ ! -f "$VENDOR_CACHE/addons/godotopenxrvendors/plugin.gdextension" ]; then
	STAGE="$(mktemp -d "$CONTROL/v1_vendor_stage.XXXXXX")" || fail "no se pudo crear staging"
	curl -fsSL --retry 2 --max-time 300 -o "$STAGE/addon.zip" "$VENDOR_URL" || fail "download del addon"
	curl -fsSL --retry 2 --max-time 60 -o "$STAGE/LICENSE" "$VENDOR_LICENSE_URL" || fail "download de LICENSE"
	ADDON_SHA="$(sha256sum "$STAGE/addon.zip" | cut -d' ' -f1)"
	LICENSE_SHA="$(sha256sum "$STAGE/LICENSE" | cut -d' ' -f1)"
	[ "$ADDON_SHA" = "$VENDOR_SHA256" ] || fail "sha256 del addon incorrecto: $ADDON_SHA"
	[ "$LICENSE_SHA" = "$VENDOR_LICENSE_SHA256" ] || fail "sha256 de LICENSE incorrecto: $LICENSE_SHA"
	mkdir -p "$STAGE/unpacked" || fail "no se pudo crear staging/unpacked"
	unzip -q "$STAGE/addon.zip" -d "$STAGE/unpacked" || fail "unzip del addon"
	[ -f "$STAGE/unpacked/asset/addons/godotopenxrvendors/plugin.gdextension" ] || fail "ZIP sin plugin.gdextension"
	mkdir -p "$VENDOR_CACHE" || fail "no se pudo crear cache de vendor"
	cp -r "$STAGE/unpacked/asset/addons" "$VENDOR_CACHE/" || fail "copia del addon a cache"
	cp "$STAGE/LICENSE" "$VENDOR_CACHE/LICENSE" || fail "copia de LICENSE a cache"
	echo "VENDOR_STAGED=$STAGE"
fi

rm -rf "$P"
mkdir -p "$P" "$P/addons" "$P/android/build" "$(dirname "$APK")" "$CONTROL/cycle2" || fail "no se pudo crear $P"
for d in core scenes assets mods maps; do
	[ -d "$ROOT/$d" ] && cp -r "$ROOT/$d" "$P/"
done
cp "$ROOT/project.godot" "$ROOT/export_presets.cfg" "$ROOT/icon.svg" "$ROOT/icon.svg.import" "$P/" || fail "copia de archivos base"

cp -r "$VENDOR_CACHE/addons/godotopenxrvendors" "$P/addons/" || fail "copia del addon a vr_project"
cp "$VENDOR_CACHE/LICENSE" "$P/addons/godotopenxrvendors/LICENSE-MIT.txt" || fail "copia de LICENSE-MIT"

unzip -q "$TEMPLATE_ZIP" -d "$P/android/build" || fail "instalacion de plantilla Gradle"
printf '4.7.stable' > "$P/android/.build_version"
cat >> "$P/android/build/gradle.properties" <<EOF

# Memoria limitada para Termux aarch64 (7 GB, sin daemon).
org.gradle.daemon=false
org.gradle.jvmargs=-Xmx1200m -XX:MaxMetaspaceSize=384m
org.gradle.workers.max=2
org.gradle.parallel=false
kotlin.daemon.jvm.options=-Xmx512m
android.aapt2FromMavenOverride=$AAPT2_OVERRIDE
doNotStrip=true
EOF

python3 - "$P/project.godot" <<'PY' || fail "configuracion VR del proyecto copiado"
import sys

path = sys.argv[1]
updates = {
    "application": {
        "run/main_scene": '"res://scenes/menu/main_menu.tscn"',
    },
    "rendering": {
        "renderer/rendering_method": '"mobile"',
        "renderer/rendering_method.mobile": '"mobile"',
    },
    "xr": {
        "openxr/enabled": "true",
        "shaders/enabled": "true",
        "openxr/form_factor": "0",
        "openxr/view_configuration": "1",
        "openxr/reference_space": "1",
        "openxr/environment_blend_mode": "0",
        "openxr/startup_alert": "false",
        "openxr/foveation_level": "3",
        "openxr/foveation_dynamic": "false",
        "openxr/foveation_eye_tracked": "false",
        "openxr/foveation_with_subsampled_images": "false",
        "openxr/extensions/hand_tracking": "false",
        "openxr/extensions/eye_gaze_interaction": "false",
    },
}

with open(path, "r", encoding="utf-8") as handle:
    lines = handle.read().splitlines()

sections = {}
order = []
current = None
for line in lines:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        current = stripped[1:-1]
        if current not in sections:
            sections[current] = []
            order.append(current)
    elif current is not None:
        sections[current].append(line)

for section, values in updates.items():
    if section not in sections:
        sections[section] = []
        order.append(section)
    body = sections[section]
    for key, value in values.items():
        for index, line in enumerate(body):
            if line.split("=", 1)[0].strip() == key:
                body[index] = f"{key}={value}"
                break
        else:
            body.append(f"{key}={value}")

with open(path, "w", encoding="utf-8") as handle:
    for section in order:
        handle.write(f"[{section}]\n")
        for line in sections[section]:
            handle.write(line + "\n")
        handle.write("\n")
PY

grun "$GODOT" --headless --path "$P" --import > "$IMPORT_LOG" 2>&1
import_code=$?
import_errors=$(grep -v fontconfig "$IMPORT_LOG" | grep -cE 'SCRIPT ERROR|Parse Error')
import_count=$(find "$P" -name '*.import' -type f | wc -l)
echo "IMPORT_EXIT=$import_code IMPORT_ERRORS=$import_errors IMPORT_FILES=$import_count"
[ "$import_errors" -eq 0 ] || fail "errores de script al importar"
[ "$import_count" -gt 0 ] || fail "no se generaron archivos .import"

INNER="$(mktemp "$CONTROL/cycle2/v1_vr_inner.XXXXXX.sh")" || fail "no se pudo crear script interno"
cat > "$INNER" <<EOF
#!/usr/bin/env bash
export JAVA_HOME="$JAVA_HOME"
export ANDROID_HOME="$ANDROID_HOME"
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH"
grun -s "ld.so $GODOT --headless --path $P --export-debug '$PRESET' $APK"
EOF
chmod +x "$INNER"

rm -f "$APK" "$APK.idsig"
termux-chroot bash "$INNER" > "$LOG" 2>&1
code=$?
errs=$(grep -v fontconfig "$LOG" | grep -cE 'ERROR|Parse Error|SCRIPT ERROR')
echo "EXPORT_EXIT=$code ERRORS=$errs"
[ "$code" -eq 0 ] && [ -f "$APK" ] || { echo "--- log ---"; tail -60 "$LOG"; fail "sin APK VR"; }
[ "$errs" -eq 0 ] || { echo "--- log ---"; tail -60 "$LOG"; fail "errores en la exportacion"; }

apksigner verify "$APK" >/dev/null 2>&1 && echo SIG_OK || fail "firma invalida"
UNZIP_LIST="$(unzip -l "$APK")"
printf '%s\n' "$UNZIP_LIST" | grep -q 'lib/arm64-v8a/libgodot_android.so' && echo GODOT_LIB_OK || fail "falta libgodot_android.so"
printf '%s\n' "$UNZIP_LIST" | grep -qE 'lib/arm64-v8a/lib(openxr_loader|openxr_meta|godotopenxrvendors)' && echo OPENXR_LIB_OK || fail "faltan librerias OpenXR"
aapt2 dump badging "$APK" 2>/dev/null | grep -q 'android.hardware.vr.headtracking' && echo VR_FEATURE_OK || fail "sin uses-feature VR"
printf 'sha256=%s size=%s\n' "$(sha256sum "$APK" | cut -d' ' -f1)" "$(stat -c%s "$APK")"
echo "BUILD_OK $APK"
