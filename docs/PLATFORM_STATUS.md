# PLATFORM_STATUS — verificacion estatica de compatibilidad

Actualizado: 2026-11-20. Informe actualizado en la tarea A12 (platform fix). No se ha modificado `core/` fuera de `runtime_lua.gd` y `runtime_wasm.gd`.

## Alcance y metodo

- Se analizan dinamicamente **todos** los archivos `.gd` bajo `core/` y `tests/` (73 en esta ejecucion), recursivamente.
- Herramientas: `tools/check_platform_compat.sh` y `tests/test_platform_compat.gd`. Ambas recorren el arbol en tiempo de ejecucion, no usan una lista fija de archivos.
- Detectores: `RUTA_ABSOLUTA`, `PROCESO_EXTERNO`, `CLASSDB_SIN_GUARDA`, `SO_SIN_FALLBACK`, `RUTA_MAYUSCULAS`, `CASO_INCONSISTENTE` y `BACKSLASH`.
- Salida: `archivo:linea`. Severidad `GRAVE` = bloquea la compatibilidad Android/VR; `ADVISORY` = requiere revision de contexto.
- Contrato de salida: codigo `0` solo si no hay hallazgos graves. El script devuelve `1` mientras existan graves.
- Los escapes de cadena (`\t`, `\n`), las continuaciones de linea y las comprobaciones defensivas con `contains()` no se cuentan como separadores de ruta.

## Matriz por plataforma

| Plataforma | VERIFICADO | VERIFICACION ESTATICA | NO VERIFICADO |
|---|---|---|---|
| Linux PC | Pruebas del nucleo previas en Linux arm64 headless (`PROJECT_STATUS.md`); runtimes nativos Lua/WASM ejecutados de verdad con extension en proyecto aislado via `bash tests/run_runtime_tests.sh` (PASS, `EXIT=0`); tests modificados (`test_runtime_lua.gd`, `test_runtime_wasm.gd`, `test_example_mod.gd`) ejecutados individualmente en headless sin `SCRIPT ERROR` (`EXIT=0`). | 73 archivos `.gd` analizados; 1 hallazgo grave y 1 informativo (ambos fuera del alcance A12). Runtimes ya comprueban disponibilidad de extension y devuelven error controlado si falta. Sin dependencias `.so` en GDScript, sin rutas con mayusculas inconsistentes. | Ejecucion con renderizado/ventana, distribucion y rendimiento reales. |
| Windows PC | Ninguno. | 0 hallazgos de `RUTA_MAYUSCULAS` / `CASO_INCONSISTENTE`. 1 `BACKSLASH` informativo en `tests/test_mod_manifest.gd:357` (literal invalido intencional, no ruta de produccion). `tests/test_example_mod.gd` ya no usa `OS.execute`; usa `PCKPacker` o `SKIP` explicito si no puede generar artefactos. | Ejecucion real en Windows; comportamiento de la capitalizacion del sistema de archivos. |
| Android | Ninguno: no hay APK instalado ni ejecucion en dispositivo. | Corregidos los graves previos de runtime/tests del alcance A12: `runtime_lua/wasm` hacen guarda `ClassDB.class_exists` antes de instanciar; `tests/test_runtime_lua/wasm` usan `res://`; `tests/test_example_mod.gd` sin `OS.execute` (generacion de PCK via `PCKPacker` o `SKIP`). Persiste 1 `RUTA_ABSOLUTA` grave fuera de alcance en `tests/test_mod_lint.gd:110`. `export_presets.cfg` declara solo `arm64-v8a`. | Carga de PCK en Android, registro de GDExtension por ABI, permisos de escritura, carga de mods y 60 FPS. |
| VR | Ninguno. | Los mismos puntos aplican a Quest (es Android). No hay preset de exportacion VR en `export_presets.cfg`; solo `Android`. | Renderizador XR (R1 bloqueado), `XRController3D` en dispositivo, rendimiento con renderizado activo. |

Las etiquetas siguen la leyenda de `docs/PLATFORM_ARCHITECTURE.md`: **VERIFICADO** exige prueba real; **VERIFICACION ESTATICA** es solo analisis de codigo; **NO VERIFICADO** no se presenta como capacidad.

## Hallazgos (estado actual)

| Codigo | Severidad | Archivo:linea | Detalle |
|---|---|---|---|
| `RUTA_ABSOLUTA` | GRAVE | `tests/test_mod_lint.gd:110` | Ruta absoluta de sistema (`"/tmp/mod"` usada como caso de prueba). Requiere correccion fuera del alcance A12 (archivo no modificable en esta tarea). |
| `BACKSLASH` | ADVISORY | `tests/test_mod_manifest.gd:357` | `"pack": "sub\\contenido.pck"` es un literal invalido usado a proposito para verificar que el validador rechaza backslashes; no es una ruta de produccion. |

Sin hallazgos: `CLASSDB_SIN_GUARDA`, `PROCESO_EXTERNO`, `SO_SIN_FALLBACK`, `RUTA_MAYUSCULAS`, `CASO_INCONSISTENTE`.

Nota fuera del alcance del analizador (no es codigo GDScript): `export_presets.cfg:9` contiene una ruta absoluta de keystore fuera del proyecto. Afecta a la exportacion, no al runtime.

## Cambios A12 (resumen)

- `core/runtime_lua.gd`, `core/runtime_wasm.gd`: comprobacion `ClassDB.class_exists(...)` antes de `ClassDB.instantiate(...)`; devuelve error controlado `"LuaSandbox extension not available"` / `"WasmSandbox extension not available"` si la extension no esta registrada (sin crash).
- `tests/test_runtime_lua.gd`, `tests/test_runtime_wasm.gd`: rutas `res://tests/fixtures/lua/` y `res://tests/fixtures/wasm/`; prueba de camino extension ausente (error controlado, sandbox `null`) con `SKIP` explicito de las pruebas reales si no hay extension.
- `tests/test_example_mod.gd`: eliminado `OS.execute`/bash para generar PCK; usa `PCKPacker` para empaquetar `mods/example.hello` en `build/mods/untitled.example-hello` y copia `mod.json` si faltan artefactos. Si las fuentes no estan disponibles o `PCKPacker` no puede generar, el test termina con `SKIP` explicito (sin invocar procesos externos).

## Comandos y codigos de salida (A12)

```bash
bash tools/check_platform_compat.sh
# 2 hallazgos (1 grave, 1 informativo); RESULTADO: NO APTO; EXIT=1
# (grave restante fuera de alcance: tests/test_mod_lint.gd:110 RUTA_ABSOLUTA)

bash tests/run_runtime_tests.sh
# PASS test_runtime_lua.gd (código 0)
# PASS test_runtime_wasm.gd (código 0)
# EXIT=0 (runtimes Lua y WASM ejecutados DE VERDAD con extension en build/runtime_project)

grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path ~/UNTITLED --script res://tests/test_runtime_lua.gd ; echo EXIT=$?
# Test 0: Extension absent -> PASS (error controlado), SKIP real tests; ALL TESTS PASSED; EXIT=0; sin SCRIPT ERROR

grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path ~/UNTITLED --script res://tests/test_runtime_wasm.gd ; echo EXIT=$?
# Test 0: Extension absent -> PASS (error controlado), SKIP real tests; EXIT=0; sin SCRIPT ERROR

grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path ~/UNTITLED --script res://tests/test_example_mod.gd ; echo EXIT=$?
# TEST_OK; EXIT=0; sin SCRIPT ERROR
```

## Pendientes

- Corregir `tests/test_mod_lint.gd:110` (`RUTA_ABSOLUTA`) fuera del alcance A12.
- Decidir si se conserva el literal con backslash de `tests/test_mod_manifest.gd:357`.
- Verificar en dispositivo Android y VR todo lo marcado como NO VERIFICADO.
- Reejecutar ambos comandos y los tests modificados despues de cualquier cambio relevante; el analisis es dinamico y el informe es una instantanea.
