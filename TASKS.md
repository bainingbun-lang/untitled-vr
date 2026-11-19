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
| 8 | Diseñar y probar la protección del núcleo mediante PCK base | PENDIENTE | spike M1 (hecho) |
| 9 | Diseñar el esquema del cargador ModManager (implementado como `ModRegistry`) | HECHA | `core/mod_registry.gd` (d808b94) |
| 10 | Definir e implementar sandbox de mods en Godot (Lua/WASM/GDExtension) | PENDIENTE | tarea 9; M2 solo probó las VMs fuera de Godot |
| 11 | Crear esqueleto del juego (escena principal, controlador FPS) | PENDIENTE | editor operativo (tarea 3) |
| 12 | Medir rendimiento hasta 60 FPS en S25 FE | PENDIENTE | tarea 11; objetivo sujeto a medición |
| 13 | Decidir ubicación definitiva y retirar el origen `/sdcard` cuando la migración esté confirmada | PENDIENTE | verificación final de hashes |
| 14 | Validar estructura y campos de `mod.json`, incluidos valores por defecto y campos desconocidos | HECHA | `core/mod_manifest.gd` (c85d736) |
| 15 | Validar conflictos de `replaces` con propietario explícito y prioridad | HECHA | `core/mod_manifest.gd` (08e8abd) |
| 16 | Resolver dependencias, rangos semver, ciclos y orden de carga | HECHA | `core/mod_resolver.gd` (a3bed28) |
| 17 | Implementar bus de eventos con prioridad, snapshot y corte de propagación | HECHA | `core/event_bus.gd` (a3bed28) |
| 18 | Implementar registro, API por módulo, carga y descarga | HECHA | `core/mod_api.gd`, `core/mod_registry.gd` (d808b94) |
| 19 | Crear mod de ejemplo PCK y probar handler y desactivación al descargar | HECHA | `mods/example.hello/`, `tools/build_example_mod.sh` (de457b2) |
| 20 | Automatizar las pruebas del núcleo y del ejemplo | HECHA | `tests/run_all.sh` (de457b2) |
| 21 | Actualizar documentos de estado y crear la guía de mods | HECHA | `docs/MOD_SYSTEM.md` (T6) |
