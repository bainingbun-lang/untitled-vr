# PROJECT_STATUS

Actualizado: 2026-11-19. Repo: `$HOME/UNTITLED`. Rama de trabajo: `feature/mod-system`, HEAD `b4cdaa5`. `main` sigue en `628563e` y no se ha tocado. Archivos versionados en HEAD: 52. Los cambios de copias, perfiles, transparencia y spike M3 no tienen commit todavía.

## Estado del juego

**NO EMPEZADO.** No hay escenas de juego, controlador FPS, mundo, NPC ni menú. El sistema de mods base sí existe en `core/` como código probado en Linux arm64 headless. El mod de ejemplo `untitled.example-hello` se empaqueta como PCK y se carga y descarga en las pruebas.

## Clasificación

| Estado | Elementos |
|---|---|
| TERMINADO Y PROBADO | Migración del repo y copia verificada; editor Godot Linux arm64 4.7; plantillas de exportación 4.7.stable; APK editor Android 4.7 descargado y verificado (no instalado); ejecución con glibc-runner + proot; spikes M1 (PCK), N1 (GDScript), M2 (Lua/wasmtime fuera de Godot) y M3 (sustitución de scripts del núcleo); núcleo de mods: validador de `mod.json`, validador de conflictos con propietario, resolver de dependencias, bus de eventos, registro con carga/descarga y API por módulo; copias e integridad (`core/mod_backup.gd`); perfiles (`core/mod_profile.gd`); transparencia (`core/mod_capabilities.gd`); mod de ejemplo PCK; pruebas automatizadas; guía `docs/MOD_SYSTEM.md` contrastada con el código. Todo lo anterior, solo en Linux arm64 headless |
| IMPLEMENTADO PERO NO PROBADO | Sistema de mods en Android, PC y VR (solo ejecutado en Linux arm64 headless); exportación APK/Gradle con JDK 17 (JDK actual 21.0.13); Lua, WASM, GDExtension y C# dentro de Godot (no integrados); ejecución del editor Android instalado |
| EN DESARROLLO | Nada |
| PENDIENTE | Recarga en caliente de componentes del núcleo; cargador de arranque reemplazable; sandbox de mods; esqueleto del juego; medición de 60 FPS; firma de paquetes; editor de mods; spike R1 (S25 FE y Quest); instalación del APK editor Android 4.7; verificación del editor Android instalado; cierre de la migración y retirada de `/sdcard` |

## Datos clave

| Elemento | Ruta / valor |
|---|---|
| Rama / HEAD | `feature/mod-system` / `b4cdaa5` |
| `main` | `628563e` (sin cambios) |
| Ramas de checkpoint | `checkpoint/fase-b-core-manifest` |
| Archivos versionados | 52 |
| Núcleo | `core/mod_manifest.gd`, `core/mod_resolver.gd`, `core/event_bus.gd`, `core/mod_api.gd`, `core/mod_registry.gd`, `core/mod_backup.gd`, `core/mod_profile.gd`, `core/mod_capabilities.gd` (los tres últimos sin commit) |
| Spike M3 | `spikes/m3/`; resultados en `spikes/RESULTS.md` |
| Mod de ejemplo | `mods/example.hello/` |
| PCK del ejemplo | `build/mods/untitled.example-hello/example_hello.pck` (1336 bytes) |
| Script de construcción | `tools/build_example_mod.sh` |
| Guía de mods | `docs/MOD_SYSTEM.md` |
| Editor Godot | `$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64` |
| Plantillas export | `$HOME/.local/share/godot/export_templates/4.7.stable/` |

## Comandos de prueba

```bash
# Construir el mod de ejemplo
bash tools/build_example_mod.sh

# Validar todo el núcleo y el ejemplo (código 0 en PASS)
bash tests/run_all.sh

# Versión del editor
$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --version
```

Resultado actual de `bash tests/run_all.sh`: 8 pruebas PASS (`test_event_bus.gd`, `test_example_mod.gd`, `test_mod_backup.gd`, `test_mod_capabilities.gd`, `test_mod_manifest.gd`, `test_mod_profile.gd`, `test_mod_registry.gd`, `test_mod_resolver.gd`); código 0.

## Pendiente de verificación

- Ejecución del sistema de mods en Android, PC y VR: NO VERIFICADO.
- Lua, WASM, GDExtension y C# dentro de Godot: NO INTEGRADOS NI PROBADOS.
- Firma de paquetes y editor de mods: NO IMPLEMENTADOS.
- Instalación y ejecución del editor Android 4.7 oficial: NO VERIFICADO (`pm install` denegado por permisos; la versión instalada de `org.godotengine.editor.v4` no coincide con el APK 4.7).
- Exportación Gradle con JDK 17: NO VERIFICADO.
- R1 (Mobile vs Compatibility en S25 FE y Quest): BLOQUEADO sin GPU/display accesible desde Termux y sin dispositivo Quest verificado.
