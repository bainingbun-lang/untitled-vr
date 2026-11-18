# NEXT_STEPS

Ejecutables en orden. Rutas absolutas desde `$HOME`.

1. **Desbloquear el editor Android**: obtener permiso de instalación; instalar el APK 4.7 oficial ya verificado; comprobar la actividad y la versión instalada de `org.godotengine.editor.v4`.
2. **JDK 17**: instalarlo y validar una exportación Gradle (el actual es OpenJDK 21.0.13; compatibilidad NO VERIFICADA).
3. **R1 (S25 FE)**: instalar el APK de prueba y medir Mobile vs Compatibility. Para Quest falta un dispositivo verificado.
4. **Resolver el conflicto documental** Mobile/Compatibility para XR con los datos de R1.
5. **Protección del núcleo**: diseñar un PCK base y cargarlo antes que los PCK de mods (`replace_files=false` solo protege lo ya cargado desde otro PCK). Referencia: `spikes/m1/`.
6. **ModManager**: definir el esquema del cargador (orden de carga, rutas de PCK, detección de fallo con `load_resource_pack` → `false`, archivos nuevos del mod).
7. **Sandbox de mods en Godot Android**: probar Lua/wasm/gdextension dentro de Godot en el teléfono (M2 solo validó las VMs en Termux).
8. **Esqueleto del juego**: escena principal y controlador FPS.
9. **Rendimiento**: medir hasta el objetivo de 60 FPS en S25 FE (sujeto a medición; N1 es solo tendencia).
10. **Cierre de migración**: verificar hashes y decidir cuándo retirar `/sdcard/Documents/UNTITLED`.
