#!/usr/bin/env bash
# Runner de pruebas de runtimes nativos (Lua, WASM).
# Crea un proyecto aislado en build/runtime_project con la extensión nativa
# registrada. El proyecto principal NO carga la extensión (decisión de Fase B).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64}"
RT="$ROOT/build/runtime_project"

run_godot() {  # envoltorio grun + código de salida real del proceso de Godot
	grun "$GODOT" "$@" > "$LOG" 2>&1
	return $?
}

rm -rf "$RT"
mkdir -p "$RT/.godot" "$RT/native/untitled_sandbox/bin"
cp -r "$ROOT/core" "$ROOT/tests" "$RT/"
cp "$ROOT/project.godot" "$RT/"
cp "$ROOT/untitled_sandbox.gdextension.txt" "$RT/untitled_sandbox.gdextension"
cp "$ROOT/native/untitled_sandbox/bin/"*.so "$RT/native/untitled_sandbox/bin/"
printf 'res://untitled_sandbox.gdextension\n' > "$RT/.godot/extension_list.cfg"

# 1) Importar para construir la caché de clases (class_name). El abort de cierre
#    de --import es conocido; se verifica por la caché, no por el código de salida.
LOG="$RT/import.log"
run_godot --headless --path "$RT" --import
if ! grep -q '"class": &"RuntimeLua"' "$RT/.godot/global_script_class_cache.cfg" 2>/dev/null; then
	echo "ERROR: la caché de clases no contiene RuntimeLua tras --import"
	exit 2
fi

status=0
for t in "$RT"/tests/test_runtime_*.gd; do
	name="$(basename "$t")"
	LOG="$RT/last_$name.log"
	timeout 170 grun "$GODOT" --headless --path "$RT" --script "res://tests/$name" > "$LOG" 2>&1
	code=$?
	if [ $code -eq 0 ] && ! grep -a -q "FAIL" "$LOG" && ! grep -a -q "SCRIPT ERROR" "$LOG"; then
		echo "PASS $name (código 0)"
	else
		echo "FAIL $name (código $code)"
		status=1
	fi
done
exit $status
