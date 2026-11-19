# RESUME_CONTEXT — Contexto para retomar UNTITLED

Documento para otra sesión de Claude Code u OpenCode. Léelo antes de tocar nada. Todo lo marcado como VERIFICADO tiene prueba registrada; lo marcado como NO VERIFICADO o NO PROBADO no debe presentarse como funcional.

Fecha de cierre de este documento: 2026-11-19. Ver `CHANGELOG.md` para el historial.

## 1. Qué es UNTITLED

Proyecto en Godot 4.7 para una plataforma de creación de experiencias y videojuegos. El juego base es un módulo más. La meta no es un juego con mods de contenido, sino una base en la que los creadores puedan transformar o sustituir prácticamente cualquier sistema, incluido el núcleo.

Entorno de trabajo: Termux en Android ARM64. Godot se ejecuta con `grun` y `proot`.

## 2. Objetivos y plataformas

- Plataformas prioritarias, en este orden: Android, VR (Quest), PC.
- Objetivo de rendimiento: 60 FPS en Samsung S25 FE (NO MEDIDO; pendiente).
- Compartir núcleo común con experiencias por plataforma.
- Clasificación objetivo 18+ (decisión de diseño de Parte 5; la clasificación final debe verificarse por territorio y tienda).

## 3. Decisiones aprobadas (resumen; fuente completa: `DECISIONS.md`)

- Tres capas: núcleo mínimo, módulos y experiencia.
- `mod.json` como formato inicial, versionado y extensible.
- Error de carga si dos módulos sustituyen el mismo sistema sin prioridad explícita.
- GDScript como lenguaje base de mods. Lua y WASM: por investigar, sin integrar hasta verificarlos en Android, PC y VR.
- Etapas E0–E7, orden reorganizable con razón técnica documentada.
- Firma de paquetes: investigar; permitir instalación manual de mods no verificados con advertencia.
- Todas las plataformas modificables.
- Sin límite de lenguaje para mods (decisión del usuario).
- Compatibilidad Quest desde el diseño.
- Día sin Claude: domingo.

## 4. Cambio de diseño reciente (decisión del usuario, 2026-11-19)

**No existe núcleo protegido.** Los mods pueden modificar o sustituir el núcleo, los sistemas base y el contenido original. La propuesta de "PCK base" como barrera está CANCELADA (TASKS 8).

La protección se limita a datos del usuario: copias de seguridad, restauración, integridad, perfiles independientes, recuperación y confirmación antes de borrar.

Hecho técnico que condiciona el diseño (spike M3, VERIFICADO en Linux arm64 headless):
- Un PCK con `replace_files=true` sustituye un script del núcleo solo si ese script se resuelve por primera vez después de cargar el pack.
- Un script ya cargado, una instancia existente y un autoload ya instanciado conservan la versión anterior.
- `ResourceLoader.load` con caché por defecto devuelve la versión antigua si ya se cargó; con `CACHE_MODE_IGNORE` devuelve la nueva para cargas nuevas.
- Consecuencia: modificar componentes del núcleo requiere reinicio o recarga explícita de nuevas instancias. El cargador de mods ya está en uso al arrancar; sustituirlo exige reemplazarlo antes del arranque.

Esto es una limitación técnica, no una protección. Ver `spikes/RESULTS.md`, sección M3.

## 5. Arquitectura actual

Carpetas:
- `core/` — código del sistema de mods (GDScript, probado):
  - `mod_manifest.gd`: validador de `mod.json` y conflictos (`owner:sistema`, prioridad).
  - `mod_resolver.gd`: rangos semver, orden topológico, ciclos, duplicados.
  - `event_bus.gd`: bus de eventos con prioridad, snapshot y corte de propagación.
  - `mod_api.gd`: API entregada a cada módulo en `_mod_init(api)`.
  - `mod_registry.gd`: escaneo, carga (conflictos → resolver → PCK → `_mod_init`) y descarga (`_mod_shutdown` + retirar suscripciones).
  - `mod_backup.gd`: copias con manifiesto sha256, verificación, restauración con copia previa, borrado con confirmación.
  - `mod_profile.gd`: perfiles independientes, diff de carga, último estado bueno.
  - `mod_capabilities.gd`: tabla de transparencia por tipo de modificación y plataforma.
- `mods/example.hello/` — primer mod de ejemplo (`untitled.example-hello`), proyecto Godot propio, se empaqueta como PCK.
- `tools/build_example_mod.sh` — exporta el PCK del ejemplo a `build/mods/untitled.example-hello/` (ignorado en Git).
- `tests/` — pruebas headless en GDScript; `tests/run_all.sh` ejecuta todas.
- `spikes/` — spikes de medición: `m1` (carga de PCK), `n1` (benchmark GDScript), `m2` (Lua/WASM en VM de Termux), `m3` (sustitución de scripts por PCK). Resultados en `spikes/RESULTS.md`. Los PCK de salida (`spikes/*/out/`) están ignorados.
- `docs/` — `PLATFORM_ARCHITECTURE.md` (arquitectura y transparencia), `MOD_SYSTEM.md` (guía para creadores), `RESUME_CONTEXT.md` (este archivo).
- Raíz: `project.godot`, `DECISIONS.md`, `TASKS.md`, `NEXT_STEPS.md`, `ERRORS.md`, `TOKEN_BUDGET.md`, `CHANGELOG.md`, `PROJECT_STATUS.md`.
- `mods/.gdignore` evita que el proyecto raíz importe el código de `mods/`.
- No existe todavía escena de juego, controlador FPS, mundo, NPC ni menú.

## 6. Sistemas implementados y probados

Probado en Linux arm64 headless (Termux). NO probado en Android, PC real con GPU ni VR:
- Validador de `mod.json` y de conflictos.
- Resolver de dependencias.
- Bus de eventos.
- Registro, carga y descarga de mods (usa `ProjectSettings.load_resource_pack` real).
- Mod de ejemplo como PCK: carga, handler ejecutado, descarga efectiva.
- Copias, restauración, integridad, perfiles y tabla de transparencia.
- Spike M1 (carga de PCK), N1 (benchmark CPU), M2 (Lua y wasmtime en VM de Termux), M3 (sustitución de scripts).

Pruebas: `bash tests/run_all.sh` → 8 pruebas PASS, código 0 (`test_event_bus`, `test_example_mod`, `test_mod_backup`, `test_mod_capabilities`, `test_mod_manifest`, `test_mod_profile`, `test_mod_registry`, `test_mod_resolver`).

## 7. Sistemas no probados o no integrados

- Sistema de mods en Android, PC real y VR: NO VERIFICADO.
- Lua, WASM (wasmtime), GDExtension y C# dentro de Godot: NO INTEGRADOS NI PROBADOS. Lua y WASM solo están probados como VM en Termux, fuera de Godot.
- Carga de PCK en Android: NO VERIFICADO.
- Exportación APK/Gradle: el JDK actual es OpenJDK 21.0.13; Godot Android requiere JDK 17 (NO VERIFICADO).
- Editor Android 4.7 oficial: NO INSTALADO; `pm install` denegado por permisos. Se detectó una instalación previa de `org.godotengine.editor.v4` de versión no verificada.
- Renderizador XR (Mobile vs Compatibility): R1 BLOQUEADO (sin dispositivo ni display accesible).
- Firma de paquetes: NO IMPLEMENTADA.
- Editor de mods, sandbox de mods y esqueleto del juego: NO IMPLEMENTADOS.
- Medición de 60 FPS: NO MEDIDO.

## 8. Tecnologías investigadas

| Tecnología | Estado | Dato verificado |
|---|---|---|
| GDScript | Usado; base de mods | Mods en PCK ejecutan scripts (M1, ejemplo) |
| PCK (`load_resource_pack`) | Verificado en Linux | 1.6–5.7 ms (M1); 0.34–0.36 ms (M3) |
| Lua 5.4.9 | VM en Termux | 25.8 ns por llamada; corte por hook OK (M2) |
| WebAssembly (wasmtime 50.0.2) | VM en Termux | 5M iteraciones ≈ 30 ms; fuel y límite de memoria OK (M2) |
| GDExtension | No probado | — |
| C# (Godot Mono) | No probado | — |
| Procesos externos (Python, Java, JS) | No evaluado | — |

Sobre la libertad tecnológica: la tabla por plataforma está en `docs/PLATFORM_ARCHITECTURE.md`. Cualquier tecnología que no aparezca como VERIFICADA debe tratarse como pendiente.

## 9. Ramas y commits

- `main` — `628563e` (checkpoint Fase 0). No modificada desde entonces. Decisión del usuario: no fusionar todavía.
- `checkpoint/fase-b-core-manifest` — `c85d736` (arquitectura aprobada + validador inicial). Mantener como checkpoint independiente.
- `feature/mod-system` — rama de trabajo actual. HEAD: `455d7d2`.

Historial de `feature/mod-system`:
- `08e8abd` validador con propietario explícito (opción A)
- `a3bed28` resolver y bus de eventos
- `d808b94` registro, carga, descarga y API
- `de457b2` mod de ejemplo PCK
- `b4cdaa5` documentación de estado y guía de mods
- `455d7d2` copias, perfiles, transparencia y spike M3 (corrección de núcleo modificable)

Commits de autor: identidad `Claude Code <noreply@anthropic.com>`, usada solo en esos commits. La configuración global de Git no se ha modificado y no hay identidad personal configurada.

Git: no se ha hecho push a ningún remoto. Ninguna rama ni checkpoint se ha eliminado.

## 10. Decisiones de diseño abiertas

- Mecanismo de recarga en caliente de componentes del núcleo (reinicio, `CACHE_MODE_IGNORE` o ambos). Pendiente de decisión del usuario.
- Cargador de arranque reemplazable: cómo y dónde se reemplaza el cargador de mods antes del arranque. Pendiente de decisión del usuario.
- Fusionar `feature/mod-system` en `main`: pendiente de decisión del usuario.
- Siguiente prioridad: sandbox de mods (Lua/WASM dentro de Godot) o esqueleto del juego. Recomendación en `NEXT_STEPS.md`.

## 11. Problemas de OpenCode

Problemas registrados en `ERRORS.md`:
- `opencode run` interpreta como opciones los `--flags` del mensaje, y `--title` con mensaje largo provoca `t.includes is not a function`. Solución verificada: mensaje corto como argumento posicional, detalle en archivo con `-f` colocado DESPUÉS del mensaje.
- Ejecutar `bash tests/run_all.sh` desde Termux requiere `bash` explícito: `/bin/bash` no existe.
- El `opencode run` con `--auto` aprueba permisos automáticamente. Uso autorizado: tareas acotadas dentro de `$HOME/UNTITLED`, sin operaciones destructivas, publicación, gastos ni cambios fuera del proyecto.

Estado de sesiones: `opencode session list` muestra 13 sesiones, incluidas las de las tareas T1–T9 (títulos "Creación de ModManifest…", "Event bus…", "Registro y carga…", "Mod de ejemplo…", "Spike M3…", "Copias de seguridad…", "Documentación del sistema de mods…"). La base de datos está en `~/.local/share/opencode/opencode.db`.

## 12. Modelos y costes

- Modelo usado en todas las delegaciones: `opencode/deepseek-v4.1-flash-free`.
- Catálogo de OpenCode (`opencode models --verbose`): coste declarado 0 en input y output para los 12 modelos (11 `-free` + `opencode/big-pickle`). Esto es lo que declara el catálogo, NO una verificación contra facturación.
- `opencode/big-pickle`: NO USAR hasta verificar coste (instrucción del usuario).
- Cuota semanal y consumo real de Claude: DESCONOCIDOS. No hay datos.
- Límites de uso de los modelos `-free`: DESCONOCIDOS.
- Tareas delegadas: T1–T9 con `deepseek-v4.1-flash-free`. Detalle en `TOKEN_BUDGET.md`.

## 13. Tareas terminadas

Ver `TASKS.md` como fuente principal. Resumen:
- Recuperación y documentación de Fase 0/A.
- Validador `mod.json`, validador de conflictos con propietario, resolver, bus, registro con carga y descarga, mod de ejemplo, pruebas automatizadas.
- Spikes M1, N1, M2 y M3.
- Copias, perfiles y transparencia.
- Guía de mods (`docs/MOD_SYSTEM.md`).

## 14. Tareas pendientes

Ver `TASKS.md` y `NEXT_STEPS.md`. Resumen:
- Decidir mecanismo de recarga del núcleo (requiere usuario).
- Decidir cargador de arranque reemplazable (requiere usuario).
- Sandbox de mods Lua/WASM dentro de Godot, probado en Android (requiere dispositivo).
- Esqueleto del juego: escena principal y controlador FPS.
- Medición de 60 FPS en S25 FE (requiere dispositivo).
- Android: instalar editor 4.7 oficial, verificar JDK 17, exportación Gradle (requiere dispositivo y permisos).
- R1 Mobile vs Compatibility en S25 FE y Quest (requiere dispositivo).
- Cierre de migración: retirar `/sdcard/Documents/UNTITLED` solo con autorización.

## 15. Siguiente tarea recomendada

Decidir con el usuario el mecanismo de recarga de componentes del núcleo (ver sección 10). Mientras tanto, la tarea independiente y sin bloqueo es el esqueleto del juego (escena principal y controlador FPS) o el sandbox de mods en Godot, según prioridad del usuario.

## 16. Comandos para recuperar el entorno

```bash
cd $HOME/UNTITLED
git status
git branch --show-current          # feature/mod-system
git log --oneline -n 8

# Pruebas (sin Internet)
bash tests/run_all.sh              # debe devolver código 0 con 8 PASS

# Editor Godot (sin Internet)
grun $HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --version

# Construir el mod de ejemplo (sin Internet)
bash tools/build_example_mod.sh    # BUILD_OK

# Sesiones de OpenCode (sin Internet, listado local)
opencode session list
```

Nota: `grun` muestra un aviso `libfontconfig.so.1` que no afecta al resultado.

## 17. Qué funciona sin Internet

- Git: todas las operaciones locales.
- Godot 4.7 headless (`grun`): versión, importación, pruebas y spikes.
- `bash tests/run_all.sh`, `bash tools/build_example_mod.sh`, `bash spikes/m3/run.sh`.
- Lectura de documentos y archivos del proyecto.
- `opencode session list` (lectura local de la base de datos).

## 18. Qué necesita Internet o dispositivos

- Cualquier llamada a un modelo de OpenCode o de Claude (los modelos se ejecutan remotamente): NO COMPROBADO sin conexión.
- `opencode models --refresh` (actualizar catálogo desde models.dev).
- Descargas de paquetes, plantillas o APK (ya están descargados y verificados por SHA-512; no requieren Internet para usarse).
- Pruebas en Android, PC con GPU y VR: requieren dispositivos físicos.

## 19. Qué no se ha guardado

- Credenciales, tokens y claves: no se incluyen en Git ni en documentos. El backup excluye la configuración de OpenCode que pueda contenerlas (ver `UNTITLED` backup manifest).
- Archivos grandes de herramientas (`~/tools/godot-4.7-stable/`, APK y plantillas de exportación): viven fuera del proyecto y no se copian en el backup del proyecto. Se verifican por SHA-512 en `~/tools/godot-4.7-stable/SHA512-SUMS.txt`.
