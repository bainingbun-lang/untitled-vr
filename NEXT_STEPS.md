# NEXT_STEPS

Ejecutables en orden. Rutas absolutas desde `$HOME`.

## No bloqueadas

1. **Commit de los cambios actuales** — revisar `git status` y `git diff`; incluye `core/mod_backup.gd`, `core/mod_profile.gd`, `core/mod_capabilities.gd`, `spikes/m3/`, `.gitignore`, las pruebas nuevas y los documentos de esta sesión. Nada de esto tiene commit todavía.
2. **Decidir el mecanismo de recarga (tareas 24 y 25)** — elegir entre reinicio del proceso, `CACHE_MODE_IGNORE` para cargas nuevas o reemplazo del cargador antes del arranque. Documentar la decisión en `DECISIONS.md` y reflejarla en `TASKS.md`.
3. **Sandbox de mods dentro de Godot (tarea 10, parte Linux)** — integrar una prueba mínima de Lua o WASM como módulo del motor en Linux arm64 headless, medir el coste y verificar el corte de bucles. La ejecución en Android queda para cuando haya dispositivo.
4. **Integración del cargador en el arranque** — definir el directorio de mods por plataforma (`user://` u otra ruta), crear el autoload que construye `ModEventBus` + `ModRegistry` y ejecutar `scan`/`load_all` al iniciar. No requiere escenas de juego.
5. **Cierre de la migración (tarea 13)** — verificar de nuevo los hashes contra `$HOME/untitled-control/manifest-src.sha256` y decidir la retirada de `/sdcard/Documents/UNTITLED`.

## Bloqueadas

6. **Editor Android**: obtener permiso de instalación, instalar el APK 4.7 oficial ya verificado y comprobar la actividad y la versión real de `org.godotengine.editor.v4` (tareas 1–3).
7. **JDK 17**: instalarlo y validar una exportación Gradle; el actual es OpenJDK 21.0.13 y la compatibilidad no está verificada (tarea 4).
8. **Esqueleto del juego**: escena principal y controlador FPS; depende del editor operativo (tarea 11).
9. **R1**: medir Mobile vs Compatibility en S25 FE y, si hay dispositivo verificado, en Quest; después resolver el conflicto documental para XR (tareas 5–7).
10. **Rendimiento**: medir hasta 60 FPS en S25 FE sobre el esqueleto del juego (tarea 12).
11. **Sandbox en Android**: repetir la prueba de Lua/WASM/GDExtension en el teléfono cuando el editor y la instalación estén disponibles (resto de la tarea 10).
12. **Sistema de mods en Android**: ejecutar las pruebas del núcleo y del ejemplo en el teléfono; depende de dispositivo y permisos (tarea 27).
