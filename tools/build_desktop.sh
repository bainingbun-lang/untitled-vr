#!/usr/bin/env bash
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build/desktop_project"
GODOT_REL="~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64"
TEMPLATES="$HOME/.local/share/godot/export_templates/4.7.stable"
OUT_DIR="$HOME/untitled-control/builds"
LOG_DIR="$HOME/untitled-control/cycle2"

mkdir -p "$OUT_DIR" "$LOG_DIR"

for template in windows_release_x86_64.exe linux_release.x86_64; do
	if [ ! -f "$TEMPLATES/$template" ]; then
		printf 'BUILD_FAIL: falta la plantilla %s\n' "$template" >&2
		exit 1
	fi
done

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cp -a "$ROOT/core" "$ROOT/scenes" "$ROOT/assets" "$ROOT/mods" \
	"$ROOT/project.godot" "$ROOT/export_presets.cfg" \
	"$ROOT/icon.svg" "$ROOT/icon.svg.import" "$BUILD_DIR/"

cd "$ROOT"

termux-chroot "bash -c \"grun $GODOT_REL --headless --path build/desktop_project --editor --quit\"" >"$LOG_DIR/A20_import.log" 2>&1

export_preset() {
	preset="$1"
	output="$2"
	log="$3"
	inner="ld.so $GODOT_REL --headless --path build/desktop_project --export-release '$preset' ~/untitled-control/builds/$output"
	termux-chroot "bash -c \"grun -s \\\"$inner\\\"\"" >"$LOG_DIR/$log" 2>&1
	if grep -q 'SCRIPT ERROR\|ERROR: Invalid export preset\|ERROR: Export template' "$LOG_DIR/$log"; then
		printf 'BUILD_FAIL: error de exportacion en %s (ver %s)\n' "$preset" "$LOG_DIR/$log" >&2
		exit 1
	fi
}

export_preset "Windows Desktop" "untitled_win.exe" "A20_win_export.log"
export_preset "Linux x86_64" "untitled_linux_x86_64" "A20_linux_export.log"

verify_artifact() {
	path="$1"
	pattern_a="$2"
	pattern_b="$3"
	if [ ! -s "$path" ]; then
		printf 'BUILD_FAIL: artefacto ausente o vacio: %s\n' "$path" >&2
		exit 1
	fi
	info="$(file -b "$path")"
	case "$info" in
		*$pattern_a*) ;;
		*)
			printf 'BUILD_FAIL: formato inesperado en %s: %s\n' "$path" "$info" >&2
			exit 1
			;;
	esac
	case "$info" in
		*$pattern_b*) ;;
		*)
			printf 'BUILD_FAIL: arquitectura inesperada en %s: %s\n' "$path" "$info" >&2
			exit 1
			;;
	esac
	stat -c '%n %s bytes' "$path"
	sha256sum "$path"
}

verify_artifact "$OUT_DIR/untitled_win.exe" "PE32+" "x86-64"
verify_artifact "$OUT_DIR/untitled_linux_x86_64" "ELF 64-bit LSB executable" "x86-64"

sha256sum "$OUT_DIR/untitled_win.exe" "$OUT_DIR/untitled_linux_x86_64" >"$OUT_DIR/desktop_sha256.txt"
printf 'BUILD_OK\n'
