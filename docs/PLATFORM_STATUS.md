# PLATFORM_STATUS — verificacion estatica de compatibilidad

Actualizado: 2026-11-19. Informe de la tarea A9. No se ha modificado `core/`.

## Alcance y metodo

- Se analizan dinamicamente **todos** los archivos `.gd` bajo `core/` y `tests/` (66 en esta ejecucion), recursivamente.
- Herramientas: `tools/check_platform_compat.sh` y `tests/test_platform_compat.gd`. Ambas recorren el arbol en tiempo de ejecucion, no usan una lista fija de archivos.
- Detectores: `RUTA_ABSOLUTA`, `PROCESO_EXTERNO`, `CLASSDB_SIN_GUARDA`, `SO_SIN_FALLBACK`, `RUTA_MAYUSCULAS`, `CASO_INCONSISTENTE` y `BACKSLASH`.
- Salida: `archivo:linea`. Severidad `GRAVE` = bloquea la compatibilidad Android/VR; `ADVISORY` = requiere revision de contexto.
- Contrato de salida: código `0` solo si no hay hallazgos graves. El script devuelve `1` mientras existan los graves documentados abajo.
- Los escapes de cadena (`\t`, `\n`), las continuaciones de línea y las comprobaciones defensivas con `contains()` no se cuentan como separadores de ruta.

## Matriz por plataforma

| Plataforma | VERIFICADO | VERIFICACION ESTATICA | NO VERIFICADO |
|---|---|---|---|
| Linux PC | Pruebas del núcleo ejecutadas en Linux arm64 headless (`PROJECT_STATUS.md`); este test A9: `PASS (24 assertions)`, `EXIT=0`, sin `SCRIPT ERROR`. | 66 archivos `.gd` analizados; 5 hallazgos graves y 1 informativo. Sin dependencias `.so` en GDScript, sin rutas con mayúsculas inconsistentes. | Ejecución con renderizado/ventana, distribución y rendimiento reales. |
| Windows PC | Ninguno. | 0 hallazgos de `RUTA_MAYUSCULAS` / `CASO_INCONSISTENTE`. 1 `BACKSLASH` informativo en `tests/test_mod_manifest.gd:357` (literal inválido intencional, no ruta de producción). Las 2 rutas absolutas detectadas son incompatibles también con Windows. | Ejecución real en Windows; comportamiento de la capitalización del sistema de archivos; generación del PCK con la herramienta actual. |
| Android | Ninguno: no hay APK instalado ni ejecución en dispositivo. | 5 hallazgos graves: 2 `RUTA_ABSOLUTA`, 1 `PROCESO_EXTERNO`, 2 `CLASSDB_SIN_GUARDA`. `export_presets.cfg` declara solo `arm64-v8a`. | Carga de PCK en Android, registro de GDExtension por ABI, permisos de escritura, carga de mods y 60 FPS. |
| VR | Ninguno. | Los mismos 5 graves aplican a Quest (es Android). No hay preset de exportación VR en `export_presets.cfg`; solo `Android`. | Renderizador XR (R1 bloqueado), `XRController3D` en dispositivo, rendimiento con renderizado activo. |

Las etiquetas siguen la leyenda de `docs/PLATFORM_ARCHITECTURE.md`: **VERIFICADO** exige prueba real; **VERIFICACION ESTATICA** es solo análisis de código; **NO VERIFICADO** no se presenta como capacidad.

## Hallazgos

| Código | Severidad | Archivo:linea | Detalle |
|---|---|---|---|
| `CLASSDB_SIN_GUARDA` | GRAVE | `core/runtime_lua.gd:14` | `ClassDB.instantiate` de `LuaSandbox` sin comprobar `ClassDB.class_exists` antes; en Android/VR la extensión puede no estar registrada. |
| `CLASSDB_SIN_GUARDA` | GRAVE | `core/runtime_wasm.gd:16` | Igual para `WasmSandbox`. |
| `PROCESO_EXTERNO` | GRAVE | `tests/test_example_mod.gd:76` | `OS.execute` invoca `bash` para generar el PCK; no disponible desde la app en Android/VR. Es código de test de escritorio, debe separarse del flujo de runtime. |
| `RUTA_ABSOLUTA` | GRAVE | `tests/test_runtime_lua.gd:5` | `"/data/data/com.termux/files/home/UNTITLED/tests/fixtures/lua/"`; debe ser `res://tests/fixtures/lua/`. |
| `RUTA_ABSOLUTA` | GRAVE | `tests/test_runtime_wasm.gd:12` | `"/data/data/com.termux/files/home/UNTITLED/tests/fixtures/wasm/"`; debe ser `res://tests/fixtures/wasm/`. |
| `BACKSLASH` | ADVISORY | `tests/test_mod_manifest.gd:357` | `"pack": "sub\\contenido.pck"` es un literal inválido usado a propósito para verificar que el validador rechaza backslashes; no es una ruta de producción. |

Sin hallazgos: `SO_SIN_FALLBACK`, `RUTA_MAYUSCULAS`, `CASO_INCONSISTENTE`.

Nota fuera del alcance del analizador (no es código GDScript): `export_presets.cfg:9` contiene una ruta absoluta de keystore fuera del proyecto. Afecta a la exportación, no al runtime, y debe revisarse al configurar JDK 17 / Gradle.

## Comandos y códigos de salida

```bash
bash tools/check_platform_compat.sh
# 6 hallazgos (5 graves, 1 informativo); RESULTADO: NO APTO; EXIT=1

grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless \
  --path ~/UNTITLED --script res://tests/test_platform_compat.gd
# PASS (24 assertions); EXIT=0; sin SCRIPT ERROR
```

El test valida los detectores con controles positivos y negativos, comprueba la cobertura de `core/` y `tests/`, exige el formato `archivo:linea`, verifica que se detecten los 6 hallazgos reales y que el analizador no se auto-flague. Por eso el test pasa aunque el código analizado contenga incompatibilidades: éstas se reportan, no se corrigen en esta tarea.

## Pendientes

- Corregir los 5 hallazgos graves (fuera del alcance de A9: no se modifica `core/`, y los hallazgos de `tests/` solo se reportan).
- Decidir si se conserva el literal con backslash de `tests/test_mod_manifest.gd:357` al portar las pruebas a Windows.
- Verificar en dispositivo Android y VR todo lo marcado como NO VERIFICADO.
- Reejecutar ambos comandos después de cualquier cambio en `core/` o `tests/`; el análisis es dinámico y el informe es una instantánea.
