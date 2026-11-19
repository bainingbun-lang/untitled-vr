#!/usr/bin/env bash
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64}"
LOG="${LOG:-$HOME/untitled-control/briefs/s3_wasm_test.log}"

mkdir -p "$HERE/.godot" "$(dirname "$LOG")"
if [ ! -f "$HERE/.godot/extension_list.cfg" ]; then
	printf 'res://untitled_sandbox.gdextension\n' > "$HERE/.godot/extension_list.cfg"
fi

set +e
grun "$GODOT" --headless --path "$HERE" --script res://test_wasm_sandbox.gd 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
set -e
exit "$rc"
