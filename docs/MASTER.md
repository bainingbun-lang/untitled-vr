# MASTER — estado compacto (actualizado 2026-11-19, ciclo 2)

## Arquitectura de trabajo
Claude = orquestador/verificador. OpenCode (`opencode run`) = programador, agentes en paralelo con archivos disjuntos. Briefs en `UNTITLED/briefs/C2_*.md`, logs en `~/untitled-control/cycle2/`. Launcher: `bash ~/untitled-control/launch.sh <A#_nombre>`.

## Verificado (grun, exit 0, sin SCRIPT ERROR, marcador PASS) — Linux arm64 headless
- `bash tests/run_all.sh` completo: 21 PASS, 0 FAIL (incluye runtimes Lua/WASM vía `run_runtime_tests.sh`).
- Mods: manifest, resolver, registry, api, loader, reloader (con reversión), backup, profile, capabilities, boot.
- Mapas: validator, registry, loader, adapter, catalog (estándar con platforms/tags/players opcionales).
- NPC: núcleo, navegación A*, comportamiento por utilidad. Plataformas: verificación estática (test_platform_compat).
- Android: APK debug exportado y firmado (`~/untitled-control/builds/beta_debug.apk`, v2/v3 OK, arm64, org.untitled.game). **NO probado en dispositivo.**

## Pendiente real
- Instalar/ejecutar el APK en el teléfono (pm install bloqueado; hay que tocar el instalador). Windows, VR (Quest), Android runtime: NO VERIFICADOS.
- Hallazgos graves de PLATFORM_STATUS (ClassDB sin guarda, rutas absolutas en tests): A12 en curso.
- Gradle/AAB, R1 (Mobile vs Compatibility), rendimiento 60 FPS: sin dispositivo.

## Entorno (trampas)
- Godot: SIEMPRE `grun <godot>`. Godot devuelve 0 aunque el script no compile → comprobar `SCRIPT ERROR`/marcador.
- Export Android: dentro de `termux-chroot` (necesita /tmp) y `JAVA_HOME=$PREFIX/lib/jvm/java-17-openjdk`. SDK híbrido en `~/Android/Sdk` (cmdline-tools/platform/build-tools de Google + aapt2/apksigner/zipalign/adb de Termux).
- Scripts con shebang `/usr/bin/env` no funcionan: usar `bash script`. `opencode run` solo lee briefs dentro del proyecto y no admite texto con `--flag` como argumento.

## Decisiones
Núcleo modificable (sin barrera PCK). Extensión nativa solo en el proyecto de pruebas de runtimes, no en el principal. Licencia SDK Android aceptada por autorización explícita del usuario (2026-11-19).
