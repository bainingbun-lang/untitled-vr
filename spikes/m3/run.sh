#!/usr/bin/env bash
# Spike M3: exporta el mod como PCK y mide cada caso en un proceso Godot nuevo.
set -uo pipefail

ROOT="$HOME/UNTITLED"
M3="$ROOT/spikes/m3"
BASE="$M3/base"
MOD="$M3/mod"
OUT="$M3/out"
GODOT="$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64"
GRUN="$(command -v grun || true)"

export TMPDIR="$HOME/tmp"
mkdir -p "$OUT" "$TMPDIR"

run_godot() {
	if [ -n "$GRUN" ]; then
		"$GRUN" "$GODOT" "$@"
	else
		"$GODOT" "$@"
	fi
}

echo "== importar proyectos =="
run_godot --headless --path "$BASE" --import >/dev/null 2>&1
run_godot --headless --path "$MOD" --import >/dev/null 2>&1

echo "== exportar mod.pck =="
rm -f "$OUT/mod.pck"
run_godot --headless --path "$MOD" --export-pack "Mod" "$OUT/mod.pck" >/dev/null 2>&1
if [ ! -f "$OUT/mod.pck" ]; then
	echo "ERROR: no se generó $OUT/mod.pck"
	exit 1
fi

LINES="$OUT/m3_medidas.txt"
: > "$LINES"

fail=0
for c in A B C D E F_antes F_despues G H; do
	raw="$(run_godot --headless --path "$BASE" -- --case="$c" --pack="$OUT/mod.pck" 2>&1)"
	code=$?
	m3="$(printf '%s\n' "$raw" | grep -E '^M3 ' || true)"
	if [ -z "$m3" ]; then
		m3="M3 $c=NO_MEDIDO (godot exit $code)"
		fail=1
	fi
	printf '%s\n' "$m3" | tee -a "$LINES"
done

echo "== medidas registradas en $LINES =="
exit "$fail"
