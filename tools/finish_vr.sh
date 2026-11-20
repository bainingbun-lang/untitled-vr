#!/usr/bin/env bash
# Un solo comando: comprueba que todo compila, compila el APK de VR, lo verifica y lo copia a Descargas.
# Ejecutar SOLO cuando ningun agente edite archivos (pgrep -f 'title C2_[A-Z]' vacio).
set -u; R="$(cd "$(dirname "$0")/.." && pwd)"; G="$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64"
pgrep -f 'title C2_[A-Z]' >/dev/null && { echo "ABORTA: hay agentes OpenCode activos"; exit 1; }
for t in test_game_flow test_player test_weapons test_vr_bootstrap test_vr_game_mode test_vehicles test_themed_maps; do
  o=$(grun "$G" --headless --path "$R" --script res://tests/$t.gd 2>&1); echo "$o" | grep -q 'SCRIPT ERROR' && { echo "FALLA $t (SCRIPT ERROR)"; exit 1; }
  echo "$o" | grep -qE '^PASS' && echo "ok $t" || { echo "FALLA $t"; exit 1; }
done
bash "$R/tools/build_vr.sh" || { echo "FALLA build_vr"; exit 1; }
A="$HOME/untitled-control/builds/untitled_vr_debug.apk"
apksigner verify "$A" >/dev/null 2>&1 || { echo "FALLA firma"; exit 1; }
grun "$G" --headless --path "$R/build/vr_project" --script "$R/tools/check_compile.gd" 2>&1 | grep -q 'bad=0' || { echo "FALLA compilacion en copia VR"; exit 1; }
cp "$A" /sdcard/Download/untitled_vr_debug.apk && echo "LISTO: /sdcard/Download/untitled_vr_debug.apk sha=$(sha256sum "$A" | cut -c1-16)"
