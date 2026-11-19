#!/usr/bin/env bash
set -eu

GODOT="$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64"
PROJECT="$HOME/UNTITLED"
MOD_DIR="$PROJECT/mods/example.hello"
OUT_DIR="$PROJECT/build/mods/untitled.example-hello"

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/example_hello.pck"

export TMPDIR="$OUT_DIR/.tmp"
mkdir -p "$TMPDIR"
grun "$GODOT" --headless --path "$MOD_DIR" --export-pack "Mod" "$OUT_DIR/example_hello.pck"
rm -rf "$TMPDIR"
cp "$MOD_DIR/mod.json" "$OUT_DIR/mod.json"

if [ ! -s "$OUT_DIR/example_hello.pck" ]; then
	printf 'BUILD_FAIL: no se genero el PCK\n' >&2
	exit 1
fi

printf 'BUILD_OK\n'
exit 0
