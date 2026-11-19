#!/usr/bin/env bash
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64}"

mkdir -p "$HERE/.godot"
if [ ! -f "$HERE/.godot/extension_list.cfg" ]; then
	printf 'res://untitled_sandbox.gdextension\n' > "$HERE/.godot/extension_list.cfg"
fi

exec grun "$GODOT" --headless --path "$HERE" --script res://test_lua_sandbox.gd
