# S4 — Implementación: Fase A (extensión nativa unificada)

Estado: Fase A verificada. Fase B NO iniciada.

## 1. Compilación
- Build: `native/untitled_sandbox/SConstruct`, `scons platform=linux arch=arm64 target=template_debug`.
- Fuentes: `native/untitled_sandbox/src/register_types.cpp` (nuevo). Las clases se compilan desde `spikes/s1_sandbox/src`, `spikes/s2_lua/src` y `spikes/s3_wasm/src` (referenciadas, no copiadas). Vendor: `spikes/s2_lua/vendor` y `spikes/s3_wasm/vendor`.
- Artefacto: `native/untitled_sandbox/bin/libuntitled_sandbox.linux.template_debug.arm64.so`.
- Dependencias del .so: libc.so.6, libm.so.6 (verificado con readelf).

## 2. Registro de las tres clases
- `register_types.cpp` registra `Probe`, `LuaSandbox` y `WasmSandbox` en un único entry point (`untitled_sandbox_library_init`).
- Verificado: script `combined.gd` instancia las tres en el mismo proceso Godot 4.7 headless. Resultado: `COMBINED instances probe=s1 lua=true wasm=true`.

## 3. Prueba conjunta
- En el mismo proceso: `Probe.get_version()` = `s1`; `LuaSandbox` carga un bucle infinito y `call` lo corta con `instruction_limit`; `WasmSandbox` carga un bucle WASM y `call` lo corta con `fuel_limit`.
- Resultado: `COMBINED RESULT PASS failures=0`, código de salida 0.

## 4. Regresiones S1–S3 (contra el .so unificado)
| Prueba | Resultado | Código |
|---|---|---|
| S1 `test_probe` | PASS test_probe | 0 |
| S2 `test_lua_sandbox` | 20 PASS, 0 FAIL | 0 |
| S3 `test_wasm_sandbox` | CHECKS 20 FAILURES 0, ALL PASS | 0 |

Los scripts de prueba son los de cada spike, sin modificar. Ejecutados en `~/untitled-control/verify_faseA/` con `grun`. Logs: `~/untitled-control/briefs/faseA_reg_*.txt`.

Incidencias de validación (no de la extensión):
- Primer intento: sin `.godot/extension_list.cfg` las clases no se registraban (`Identifier "Probe" not declared`).
- Script combinado: llamaba `is_loaded()` en `LuaSandbox`, que no existe en la API. Corregido usando la API real.
- Script combinado con error de `_init` no llamaba a `quit()` y quedó colgado. Se detuvo el proceso y se corrigió el script.

## 5. Archivos
- Nuevos: `native/untitled_sandbox/` (SConstruct, src/register_types.cpp, README.md, untitled_sandbox.gdextension), `untitled_sandbox.gdextension` (raíz del proyecto), `docs/S4_PLAN.md`, `docs/S4_IMPLEMENTATION.md`.
- Artefactos de build (no versionados): `native/untitled_sandbox/bin/`, `src/*.os`.
- Sin cambios en `core/` ni `mods/` (solo archivos `.uid` generados por Godot, sin cambios de código).
- Spikes: intactos.

## 6. Configuración: `.godot/extension_list.cfg`
- Función: Godot 4.7 lee este archivo para saber qué extensiones cargar al iniciar. Sin él, las clases GDExtension no se registran aunque el .so exista.
- Contenido: `res://untitled_sandbox.gdextension` (una línea).
- Lo genera `run_test.sh` de cada spike y el script de verificación si no existe.

## 7. Riesgos y pendientes
- **Android: no verificado.** Ni la extensión ni los tres runtimes se han compilado ni probado para Android (requiere NDK y dispositivo).
- **Proyecto principal:** `untitled_sandbox.gdextension` en la raíz hace que el proyecto principal cargue la extensión si está en `extension_list.cfg`. Hay que decidir si se activa ahora o solo en S4 Fase B.
- **Dependencia de spikes:** el build de `native/` lee fuentes y vendor de `spikes/`. Si se mueven los spikes hay que actualizar `SConstruct`.
- **Límite de la API:** `LuaSandbox` no tiene `is_loaded()`. Es esperado, no un fallo; el código de integración debe usar el valor de retorno de `load()`.
- **Kind de error de Lua:** es el texto del error (ya documentado en S2). No usar para decisiones de seguridad.
- **Solo build debug:** `template_debug`. Falta el build de release.

## 8. Fase B: Adaptadores de Runtime y Aislamiento\n\nImplementación de la arquitectura de adaptadores para soportar múltiples lenguajes.\n\n### Componentes\n- `RuntimeAdapter`: Interfaz base para todos los runtimes.\n- `RuntimeGDScript`: Adaptador para GDScript (mantiene compatibilidad total).\n- `RuntimeLua`: Integración con `LuaSandbox`.\n- `RuntimeWasm`: Integración con `WasmSandbox`.\n- `ModManifest`: Soporte para el campo `runtime` (default: `gdscript`).\n- `ModRegistry`: Delegación de carga e inicialización al adaptador seleccionado.\n- `ModApi`: Proxy de permisos basado en el campo `permissions` del manifiesto.\n\n### Límites de Seguridad\nSe documenta que los módulos GDScript no pueden ser aislados completamente mediante el proxy de `ModApi`, ya que un script de GDScript puede acceder directamente a la API de Godot y al núcleo del motor, saltándose el proxy. Este es un límite conocido del lenguaje en el contexto de Godot y no se considera un fallo de implementación de la Fase B.\n\n## 9. Siguiente fase recomendada\n- Fase C: Implementación de `user://permissions.json` y desactivación automática de módulos por errores repetidos.\n