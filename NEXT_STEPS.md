# NEXT_STEPS

Ejecutables en orden. Rutas absolutas desde `$HOME`.

## No bloqueadas

1. **Protección del núcleo con PCK base (tarea 8)** — primera tarea no bloqueada. Construir un PCK base con los archivos críticos, cargarlo antes que cualquier pack de mod y comprobar con el arnés de `spikes/m1/` que un mod no puede sobrescribirlo. Documentar el resultado y añadir una prueba automatizada.
2. **Sandbox de mods dentro de Godot (tarea 10, parte Linux)** — integrar una prueba mínima de Lua o WASM como módulo del motor en Linux arm64 headless, medir el coste y verificar el corte de bucles. La ejecución en Android queda para cuando haya dispositivo.
3. **Integración del cargador en el arranque** — definir el directorio de mods por plataforma (`user://` u otra ruta), crear el autoload que construye `ModEventBus` + `ModRegistry` y ejecutar `scan`/`load_all` al iniciar. No requiere escenas de juego.
4. **Cierre de la migración (tarea 13)** — verificar de nuevo los hashes contra `$HOME/untitled-control/manifest-src.sha256` y decidir la retirada de `/sdcard/Documents/UNTITLED`.

## Bloqueadas

5. **Editor Android**: obtener permiso de instalación, instalar el APK 4.7 oficial ya verificado y comprobar la actividad y la versión real de `org.godotengine.editor.v4` (tareas 1–3).
6. **JDK 17**: instalarlo y validar una exportación Gradle; el actual es OpenJDK 21.0.13 y la compatibilidad no está verificada (tarea 4).
7. **Esqueleto del juego**: escena principal y controlador FPS; depende del editor operativo (tarea 11).
8. **R1**: medir Mobile vs Compatibility en S25 FE y, si hay dispositivo verificado, en Quest; después resolver el conflicto documental para XR (tareas 5–7).
9. **Rendimiento**: medir hasta 60 FPS en S25 FE sobre el esqueleto del juego (tarea 12).
10. **Sandbox en Android**: repetir la prueba de Lua/WASM/GDExtension en el teléfono cuando el editor y la instalación estén disponibles (resto de la tarea 10).
