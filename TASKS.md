# TASKS

Orden de ejecución. Estado: `PENDIENTE` / `BLOQUEADA` / `HECHA`.

| # | Tarea | Estado | Dependencia |
|---|---|---|---|
| 1 | Verificar editor Android instalado (`org.godotengine.editor.v4`) y su versión real | BLOQUEADA | `pm install` denegado por permisos |
| 2 | Instalar APK editor Android 4.7 oficial (ya descargado y con SHA-512 verificado) | BLOQUEADA | permisos de instalación en el teléfono |
| 3 | Confirmar arranque del editor Android (actividad) | BLOQUEADA | tareas 1–2 |
| 4 | Validar exportación Gradle con JDK 17 | PENDIENTE | JDK 17 (actual: OpenJDK 21.0.13) |
| 5 | Ejecutar R1: Mobile vs Compatibility en S25 FE | BLOQUEADA | APK de prueba instalado en el teléfono |
| 6 | Ejecutar R1 en Quest | BLOQUEADA | dispositivo Quest no verificado |
| 7 | Resolver el conflicto documental Mobile/Compatibility para XR | PENDIENTE | tarea 5 (R1) |
| 8 | Diseñar protección del núcleo mediante PCK base | PENDIENTE | spike M1 (hecho) |
| 9 | Diseñar esquema del cargador ModManager | PENDIENTE | tarea 8 |
| 10 | Definir e implementar sandbox de mods en Godot Android (Lua/wasm/gdextension) | PENDIENTE | tarea 9; M2 solo probó las VMs fuera de Godot |
| 11 | Crear esqueleto del juego (escena principal, controlador FPS) | PENDIENTE | editor operativo (tarea 3) |
| 12 | Medir rendimiento hasta 60 FPS en S25 FE | PENDIENTE | tarea 11; objetivo sujeto a medición |
| 13 | Decidir ubicación definitiva y retirar el origen `/sdcard` cuando la migración esté confirmada | PENDIENTE | verificación final de hashes |
