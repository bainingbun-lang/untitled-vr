# PROJECT_STATUS

Actualizado: 2026-11-18. Repo: `$HOME/UNTITLED`, rama `main`, commit `95d7cda`.

## Estado del juego

**NO EMPEZADO.** No hay escenas, scripts de juego, controlador FPS, mundo, NPC, menú, mods ni editor dentro del proyecto.

## Clasificación

| Estado | Elementos |
|---|---|
| TERMINADO Y PROBADO | Migración del repo (7 archivos versionados; `.godot/` ignorado); copia de seguridad con hashes idénticos; editor Godot Linux arm64 4.7 (`--version`, `--headless --import`); plantillas de exportación 4.7.stable instaladas y SHA-512 verificado; APK editor Android 4.7 descargado y SHA-512 verificado; Ejecución con glibc-runner (grun) + proot con bind de `$HOME/tmp` a `/tmp`; OpenCode 1.19.5; spike M1 (carga de PCK, Linux arm64 headless); spike N1 (benchmark GDScript); spike M2 (Lua y wasmtime en VM de Termux); T-EXPORT-TRIAGE |
| IMPLEMENTADO PERO NO PROBADO | exportación APK/Gradle con OpenJDK 21.0.13 (Godot Android requiere JDK 17: NO VERIFICADO); mods T2 con GDScript (decisión, sin implementación); integración de Lua/wasm dentro de Godot en Android (NO PROBADO) |
| EN DESARROLLO | Nada |
| PENDIENTE | Spike R1 (renderizador Mobile vs Compatibility en S25 FE y Quest); esquema del cargador ModManager; protección del núcleo mediante PCK base; instalación del APK editor Android 4.7 oficial (no instalado); verificación del editor Android instalado (`org.godotengine.editor.v4`) |

## Datos clave

| Elemento | Ruta / valor |
|---|---|
| Repo | `$HOME/UNTITLED` (7 archivos versionados) |
| Origen intacto | `/sdcard/Documents/UNTITLED` (62 archivos) |
| Copia de seguridad | `$HOME/backups/UNTITLED-src-20261118-001845` (62 archivos) |
| Manifiestos | `$HOME/untitled-control/manifest-{src,backup,dest}.sha256` |
| Editor Godot | `$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64` |
| Plantillas export | `$HOME/.local/share/godot/export_templates/4.7.stable/` (`version.txt` = `4.7.stable`) |
| PCKs del spike M1 | `$HOME/spikes/m1/out/` (no versionados) |

## Comandos de prueba

```bash
# Versión del editor
$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --version

# Importación headless del proyecto
$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --import

# Verificar copia de seguridad
cd $HOME/backups/UNTITLED-src-20261118-001845 && find . -type f -print0 | sort -z | xargs -0 sha256sum | diff - $HOME/untitled-control/manifest-src.sha256 && echo COPIA_OK

# Benchmark N1
# fuente: spikes/n1/bench.gd
```

## Pendiente de verificación

- Instalación y ejecución del editor Android 4.7 oficial: NO VERIFICADO (instalado `org.godotengine.editor.v4` con versión no coincidente con el APK 4.7 oficial).
- `pm install` denegado por permisos.
- Exportación Gradle con JDK 17: NO VERIFICADO.
- R1: bloqueado sin GPU/display accesible desde Termux.
