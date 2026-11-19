# SPIKE RESULTS

Todos los spikes se ejecutaron en Termux (Linux arm64, CPU del teléfono). No en Android dentro de Godot.

## M1 — Carga de PCK (Linux arm64 headless)

| Caso | Resultado |
|---|---|
| `load_resource_pack` de PCK de mod | OK |
| Ruta inexistente | `false` |
| `replace_files=false` | No protege archivos del proyecto en `res://` (el mod sobrescribió `base.gd`). Sí protege archivos ya cargados desde otro PCK (`base.pck` cargado antes → conserva BASE v1) |
| `replace_files=true` | Sobrescribe (MOD v1) |
| Archivos nuevos del mod | `mod_extra.gd` y `mod_scene.tscn` disponibles tras la carga |
| Tiempo de carga (PCK pequeño) | 1.6–5.7 ms (varía entre ejecuciones) |

Incidencia resuelta: el mod incluía el `project.godot` del base por error de copia; corregido y reexportado, sin errores de fontconfig.

Fuentes: `spikes/m1/`. PCKs en `$HOME/spikes/m1/out/` (no versionados).

Reproducir: cargar `$HOME/spikes/m1/out/*.pck` con `ProjectSettings.load_resource_pack()` y repetir con `replace_files` en `false` y `true`.

## N1 — Benchmark GDScript headless

Sin render ni física. Solo tendencia; no representa el juego final.

| Ticks | ms/tick |
|---|---|
| 10 | 0.009 |
| 100 | 0.101 |
| 1000 | 0.969 |
| 4000 | 4.393 |
| 8000 | 10.610 |

Sin presupuesto superado hasta 8000.

Fuente: `spikes/n1/bench.gd`.

Reproducir: ejecutar `bench.gd` con el editor 4.7 Linux arm64 en modo `--headless`.

## M2 — Lenguajes de mods (solo VM de Termux)

| Runtime | Resultado |
|---|---|
| Lua 5.4.9 | 25.8 ns por llamada simulada; corte de bucle infinito por hook de instrucciones OK; sin límite de memoria nativo (crecimiento medido 18 MB sin tope) |
| wasmtime 50.0.2 | Bucle de 5M iteraciones en ~30 ms CPU; `-W fuel` corta bucle infinito OK; `-W max-memory-size=64MB` → `memory.grow` devuelve -1 OK |
| godot-wasm / lua-gdextension / Godot Sandbox dentro de Godot en Android | NO PROBADO |

Fuente: `spikes/m2/`.

## R1 — Mobile vs Compatibility (S25 FE y Quest)

PENDIENTE / BLOQUEADO: sin GPU ni display accesible desde Termux; requiere instalar el APK de prueba en el teléfono y, para Quest, un dispositivo no verificado.

## M3 — Sustitución de scripts del núcleo por PCK

Medido en Termux (Linux arm64, Godot 4.7 headless), un proceso Godot nuevo por caso. PCK del mod exportado con `--export-pack "Mod"` y cargado con `ProjectSettings.load_resource_pack(pck, true)` (`replace_files=true`). Base y mod en `spikes/m3/`; medidas en `spikes/m3/out/m3_medidas.txt`.

| Caso | Resultado |
|---|---|
| A. Base sin pack (`load("res://core_demo.gd").new()`) | `BASE_V1` |
| B. Script cargado antes del pack; tras el pack, `load()` con caché por defecto | `BASE_V1` (la instancia previa ya devolvía `BASE_V1`) |
| C. Primera carga tras el pack (sin carga previa), caché por defecto | `MOD_V1` |
| D. Tras el pack, `ResourceLoader.load(..., ResourceLoader.CACHE_MODE_IGNORE)` | `MOD_V1` |
| E. Instancia creada antes del pack, consultada después | `BASE_V1` (no cambia) |
| F. `class_name CoreDemo` usado antes del pack | antes `BASE_V1` → después `BASE_V1` |
| F. `class_name CoreDemo` usado solo después del pack | `MOD_V1` |
| G. Autoload tras el pack | instancia existente `AUTO_BASE` → `AUTO_BASE`; nueva `load()` `AUTO_MOD` |
| H. Tiempo de carga del pack (`Time.get_ticks_usec()`) | 0.342–0.356 ms (3 ejecuciones) |

Conclusión:
- Un script ya resuelto o cargado antes del pack queda fijado en la caché de `ResourceLoader`: las nuevas `load()` por defecto, las instancias existentes y `CoreDemo.new()` siguen usando la versión base.
- El contenido del PCK solo se usa cuando el script se resuelve por primera vez después de cargar el pack, o cuando se fuerza `CACHE_MODE_IGNORE`.
- Un autoload ya instanciado tampoco se sustituye; el pack solo afecta a una carga nueva de su script.
- Para recargar en caliente un componente del núcleo sustituido por un mod no basta con cargar el PCK: hace falta reiniciar el proceso o forzar la recarga ignorando la caché.

Reproducir: `bash spikes/m3/run.sh`.
