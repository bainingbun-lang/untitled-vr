# CHANGELOG

## 2026-11-18

- **G1** — Copia de seguridad verificada: `$HOME/backups/UNTITLED-src-20261118-001845`, 62 archivos, hashes SHA-256 idénticos a `/sdcard/Documents/UNTITLED`. Informe en `$HOME/untitled-control/REPORT_G1.md`.
- **G2** — Migración a `$HOME/UNTITLED`: copia verificada (62 hashes idénticos), `git init` y commit `95d7cda` con 7 archivos versionados; `.godot/` ignorado; hashes de los 7 archivos coinciden con el origen.
- **G3** — Editor Godot Linux arm64 4.7.stable y plantillas 4.7.stable instaladas (SHA-512 verificado). Ejecución en Termux vía `grun` + `proot`. APK Android 4.7 descargado y verificado, no instalado.
- **Migración del repo** — Importada la plantilla Godot 4.7 desde almacenamiento compartido (`95d7cda`): 7 archivos versionados, `.godot/` ignorado. Origen `/sdcard/Documents/UNTITLED` (62 archivos) conservado. Copia en `$HOME/backups/UNTITLED-src-20261118-001845` con hashes idénticos.
- **M1** — Carga de PCK de mod en Linux arm64 headless (Termux, no Android): `load_resource_pack` OK; ruta inexistente devuelve `false`; `replace_files=false` no protege `res://` pero sí archivos ya cargados desde otro PCK; archivos nuevos disponibles; carga 1.6–5.7 ms. Fuentes en `spikes/m1/`.
- **N1** — Benchmark GDScript headless (CPU del teléfono, sin render ni física): ms/tick 10→0.009, 100→0.101, 1000→0.969, 4000→4.393, 8000→10.610. Sin presupuesto superado hasta 8000. Fuente: `spikes/n1/bench.gd`.
- **M2** — Lenguajes de mods solo en VM de Termux: Lua 5.4.9 25.8 ns/llamada, corte de bucle infinito por hook OK, sin límite de memoria nativo; wasmtime 50.0.2 bucle 5M en ~30 ms, límites de fuel y memoria (64 MB) OK. Dentro de Godot en Android: NO PROBADO. Fuente: `spikes/m2/`.
- **T-EXPORT-TRIAGE** — Clasificados los errores del export (OpenCode, `deepseek-v4.1-flash-free`); único error real: autoload `res://mod_manager.gd` por `project.godot` mal copiado, ya corregido.
- **Herramientas** — Editor Godot Linux arm64 4.7.stable verificado (`--version`, `--headless --import`); plantillas de exportación 4.7.stable instaladas con SHA-512 verificado; APK editor Android 4.7 descargado y verificado (no instalado).
- **PARTE 7 (diseño)** — Propuesta de arquitectura de plataforma en `docs/PLATFORM_ARCHITECTURE.md`. Solo diseño: pendiente de aprobación, sin implementación.
- **Aprobación de la arquitectura** — Registradas en `DECISIONS.md` las decisiones aprobadas; libertad tecnológica incorporada a la propuesta como requisito pendiente.
- **Núcleo: validador de `mod.json`** — `core/mod_manifest.gd` (parseo, valores por defecto, campos desconocidos conservados, detección de conflictos por prioridad igual). Implementado con OpenCode (`deepseek-v4.1-flash-free`), revisado y probado: `tests/test_mod_manifest.gd` → `TEST_OK`, código 0. La distinción de propietario `modulo:sistema` se añadió en `08e8abd`.

## 2026-11-19

- **`c85d736` — Checkpoint Fase B** — Fijado en la rama `checkpoint/fase-b-core-manifest`: arquitectura aprobada, validador de `mod.json` y prueba headless.
- **`08e8abd` — Conflictos con propietario** — El validador distingue `sistema` de `modulo:sistema`; gana la prioridad mayor y el empate en la prioridad máxima es conflicto de carga. Añadido `tests/run_all.sh`.
- **`a3bed28` — Dependencias y eventos** — `core/mod_resolver.gd` resuelve rangos, ciclos y orden de carga; `core/event_bus.gd` añade prioridad, snapshot y corte de propagación. Pruebas propias para ambos.
- **`d808b94` — Registro y API** — `core/mod_api.gd` y `core/mod_registry.gd`: escaneo, carga de PCK, `_mod_init`, descarga con `_mod_shutdown` y liberación de suscripciones. Prueba de registro.
- **`de457b2` — Mod de ejemplo** — `untitled.example-hello` empaquetado como PCK de 1336 bytes con `tools/build_example_mod.sh`; la prueba carga el pack, ejecuta el handler de `game.started` y comprueba la desactivación al descargar.
- **Documentación de mods** — Creada `docs/MOD_SYSTEM.md` y actualizados los documentos de estado; contenido contrastado con `core/` y `git log`. `bash tests/run_all.sh` sigue en código 0.
- **Corrección del usuario (2026-11-19)** — No existe una barrera que impida modificar el núcleo: los mods pueden sustituir el núcleo, los sistemas base y el contenido original. Se cancela la propuesta de PCK base. La protección se limita a datos del usuario: copias, restauración, integridad, perfiles, recuperación y confirmación antes de borrar. Registrada en `DECISIONS.md`.
- **M3 — Sustitución de scripts del núcleo** — PCK con `replace_files=true` sustituye un script del núcleo solo si se resuelve por primera vez después de cargar el pack. Script ya cargado, instancia existente y autoload ya instanciado conservan la versión anterior; `CACHE_MODE_IGNORE` devuelve la nueva para cargas nuevas. Carga del pack: 0.342–0.356 ms. Fuente: `spikes/m3/`, `spikes/RESULTS.md`.
- **Copias, perfiles y transparencia** — `core/mod_backup.gd` (snapshot, verificación SHA-256, restauración con copia previa y borrado con confirmación), `core/mod_profile.gd` (perfiles independientes y perfil de último estado bueno) y `core/mod_capabilities.gd` (niveles, estados y flags). Pruebas `test_mod_backup.gd`, `test_mod_profile.gd` y `test_mod_capabilities.gd`. `.gitignore` excluye `spikes/*/out/`. Sin commit todavía.
