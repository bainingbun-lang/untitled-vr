# SANDBOX_PLAN — Sandbox de mods Lua/WASM en Godot

Estado: PLAN APROBADO por el usuario (2026-11-19). Implementación por etapas. Ninguna etapa está terminada hasta tener prueba registrada en `NEXT_STEPS.md` y `CHANGELOG.md`.

## 1. Objetivo y requisitos

- Ejecutar mods en Lua y WASM dentro de Godot 4.7 (Linux arm64 headless primero; Android después).
- Los mods autorizados pueden reemplazar sistemas originales, componentes internos y el núcleo. El sandbox aísla la **ejecución** (bucles, memoria); no limita **qué** puede tocar el mod.
- Permisos configurables por el usuario, separados del aislamiento de ejecución.
- APIs de host versionadas, con migración entre versiones.
- Interfaces documentadas.

## 2. Arquitectura actual (base reutilizada)

- `core/mod_registry.gd`: escaneo, carga (conflictos → resolver → PCK → `_mod_init`) y descarga.
- `core/mod_api.gd`: API entregada a cada módulo en `_mod_init(api)`.
- `core/event_bus.gd`: bus de eventos con prioridad.
- `core/mod_manifest.gd`: validación de `mod.json`.
- Carga de mods como PCK con `ProjectSettings.load_resource_pack`. Verificado en M1 y M3.

Medidas previas (`spikes/RESULTS.md`), solo en VM de Termux, fuera de Godot:
- Lua 5.4.9: hook de instrucciones corta bucles; no hay límite de memoria nativo.
- wasmtime 50.0.2: `fuel` corta bucles; `max-memory-size` limita memoria.

## 3. Decisión técnica: cómo entra Lua/WASM en Godot

Godot 4.7 no incluye Lua ni WASM. Hay que integrarlos mediante **GDExtension** con godot-cpp.

- godot-cpp: no hay tag `godot-4.7-stable` en el remoto en el momento de este plan; se usa `godot-4.5-stable` (la API de GDExtension es compatible hacia adelante). Riesgo: verificar la carga en 4.7 en la etapa S1.
- Lua: cabeceras y biblioteca de Lua 5.4 ya instaladas en Termux (`/data/data/com.termux/files/usr/include`, `liblua5.4.so`). Enlazar contra ellas en Linux; para Android hará falta compilar Lua desde fuente.
- WASM: wasmtime tiene binario pero no cabeceras C. Hay que obtener la biblioteca C (release de GitHub) y verificarla en la etapa S3.

## 4. Etapas

| Etapa | Contenido | Criterio de aceptación |
|---|---|---|
| S1 | godot-cpp compilado para Linux arm64 + extensión mínima `untitled_sandbox` con una clase `Probe` (devuelve versión). Carga desde Godot 4.7 headless. | Script de prueba GDScript imprime la versión y sale con código 0. |
| S2 | Clase `LuaSandbox`: `load(source)`, `call(fn, args)`, límite de instrucciones por llamada (hook), límite de memoria (allocator propio), `register_host(name, Callable)`. | Pruebas: bucle infinito cortado; memoria por encima del límite denegada; llamada a host devuelve valor; error de Lua no tumba Godot. |
| S3 | Clase `WasmSandbox` sobre wasmtime C: fuel, límite de memoria, host imports. | Mismas pruebas que S2 con WASM. |
| S4 | Integración en el registro: `mod.json` declara `runtime` (`gdscript` \| `lua` \| `wasm`) y `entry`; `mod_api` expone una API de host versionada; permisos configurables en `mod.json` y en un archivo de usuario. | Prueba end-to-end: mod Lua de ejemplo reemplaza un comportamiento del ejemplo base y se descarga limpiamente. |
| S5 | Documentación: `docs/MOD_SYSTEM.md` (interfaces de host y permisos) y `docs/PLATFORM_ARCHITECTURE.md` (estado por plataforma). Migración de versiones de API. | Revisión por Claude; sin afirmaciones sin prueba. |

Recarga del núcleo: reinicio del proceso (decisión del usuario). Cualquier cambio de un script del núcleo se aplica al reiniciar. Documentado en S5.

## 5. Riesgos y dependencias

- **godot-cpp 4.5 vs Godot 4.7**: posible incompatibilidad. Mitigación: S1 la prueba antes de nada más.
- **Android**: compilar la GDExtension para `android-arm64` requiere NDK; bloqueado por dispositivo y permisos. Las etapas S1–S5 se verifican solo en Linux arm64. Android queda registrado como NO VERIFICADO.
- **Lua sin límite de memoria nativo**: se resuelve con allocator propio en S2.
- **WASM**: la biblioteca C de wasmtime debe obtenerse y verificarse por hash antes de usarla (S3).
- **Seguridad**: los mods pueden tocar el núcleo por diseño. Se acepta por decisión del usuario; el aviso y la verificación de firma quedan en la lista de pendientes de `DECISIONS.md`.

## 6. Reparto de trabajo

Claude planifica, divide, revisa y autoriza cada etapa. OpenCode implementa cada etapa con el modelo `opencode/deepseek-v4.1-flash-free`. Claude solo edita código si OpenCode falla tras un diagnóstico razonable.
