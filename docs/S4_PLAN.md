# Plan de Implementación S4: Integración de Runtimes y Sandbox

## 1. Archivos
### Modificaciones
- `core/mod_registry.gd`: Implementar selector de runtime y delegar carga/ejecución a adaptadores.
- `core/mod_manifest.gd`: Añadir campo `runtime` y validación de valores (`gdscript`, `lua`, `wasm`).
- `core/mod_api.gd`: Versionar la API y adaptar la exposición de métodos según el runtime.

### Archivos Nuevos
- `core/runtime_adapter.gd`: Interfaz base (estilo clase abstracta) para adaptadores.
- `core/runtime_gdscript.gd`: Adaptador para GDScript (actual).
- `core/runtime_lua.gd`: Adaptador para Lua (puente con `spikes/s2_lua`).
- `core/runtime_wasm.gd`: Adaptador para WASM (puente con `spikes/s3_wasm`).
- `core/api_version_manager.gd`: Gestión de versiones y compatibilidad de la API de host.

## 2. Esquema de mod.json (v2)
- `runtime` (Obligatorio): `gdscript` | `lua` | `wasm`. Default: `gdscript`.
- `entry` (Obligatorio si runtime != gdscript): Ruta al script/binario de entrada.
- `api_version` (Obligatorio): Versión mínima de la API requerida (ej. `"1.0.0"`).
- `permissions` (Opcional): Lista de capacidades solicitadas. Default: `[]`.

## 3. Interfaz Común de Runtimes
Cada adaptador implementa:
- `load(manifest, dir)`: Carga el binario/script en la VM.
- `init(api)`: Llama a `_mod_init` en el runtime.
- `handle_event(event, payload)`: Ejecuta el handler del mod.
- `unload()`: Libera recursos de la VM.
Ubicación: `core/runtime_*.gd`.

## 4. API de Host Versionada
- El `ApiVersionManager` mapea la versión solicitada en `mod.json` a un set de funciones disponibles.
- Para Lua/WASM, se expone un objeto "proxy" que valida la versión antes de ejecutar llamadas al núcleo.
- Compatibilidad: Versiones mayores rompen API; menores son aditivas.

## 5. Permisos y Capacidades
- **Modelo**: Lista blanca de capacidades (ej. `file.read`, `network.send`, `core.replace`).
- **Configuración**: 
  1. `mod.json`: Declaración de intención.
  2. `user://permissions.json`: Aprobación explícita del usuario.
- **Aplicación**: El adaptador de runtime intercepta las llamadas a la API y verifica el permiso antes de delegar al núcleo.

## 6. Ciclo de Vida y Errores
- **Aislamiento**: Cada mod corre en su propia instancia de VM (Lua/WASM).
- **Control**: Uso de `pcall` (Lua) y `traps` (WASM) para capturar errores.
- **Recuperación**: Si un mod falla repetidamente, `ModRegistry` lo marca como `disabled` y emite un evento de error.

## 7. Riesgos Técnicos
- Overhead de rendimiento en la comunicación Host <-> VM.
- Complejidad de sincronizar tipos de datos entre GDScript y Lua/WASM.
- Gestión de memoria en Android (límites más estrictos).

## 8. Pruebas de Aceptación
- [ ] Registro: Mod con `runtime: lua` se identifica correctamente.
- [ ] Runtime: Selección automática de adaptador según `mod.json`.
- [ ] Manifiesto: Error si `api_version` es incompatible.
- [ ] API: Mod WASM accede a funciones de API v1.0.
- [ ] Permisos: Bloqueo de acceso a archivos si no hay permiso.
- [ ] Errores: Crash en Lua no tumba Godot.
- [ ] S1-S3: Los tests de los spikes pasan integrados.
- [ ] Docs: `docs/S4_IMPLEMENTATION.md` actualizado.

## 9. Compatibilidad de Plataforma
- **Linux arm64**: Verificación completa de todos los runtimes y permisos.
- **Android**: Pendiente validación de carga de librerías nativas para WASM/Lua.

## 10. Estrategia de Integración S1-S3
Los spikes se integran mediante los adaptadores:
- `s2_lua` -> `core/runtime_lua.gd`
- `s3_wasm` -> `core/runtime_wasm.gd`
Justificación: Mantiene el núcleo limpio y permite actualizar runtimes independientemente.

## 11. Reparto de Tareas
1. **Implementador**: `core/runtime_adapter.gd` $\rightarrow$ Adaptadores $\rightarrow$ `ModRegistry` update.
2. **Auditor**: Definición de `api_version` y matriz de permisos.
3. **Tester**: Suite de pruebas S4 y validación cross-platform.

## 12. Decisiones del coordinador (revisión del plan)
- **D1, una sola extensión nativa.** Se crea `native/untitled_sandbox/` con `SConstruct` propio que compila `Probe`, `LuaSandbox` y `WasmSandbox` en un único `.so`. Las fuentes de `spikes/s1_sandbox`, `spikes/s2_lua` y `spikes/s3_wasm` se referencian, no se mueven ni se borran. Los spikes siguen siendo la referencia de sus pruebas.
- **D2, permisos para todos los runtimes.** Todos los runtimes reciben la misma API proxy. Un mod GDScript también llama a través del proxy y pasa por la misma verificación de permisos. Llamadas directas al núcleo desde GDScript quedan fuera del control y se documentan como límite conocido.
- **D3, umbral de desactivación.** Tres errores en una ventana de 60 s desactivan el mod. El umbral y la ventana son configurables en `mod.json` (`max_errors`, `error_window_s`) y tienen estos valores por defecto.
- **D4, documento.** El documento final de S4 es `docs/S4_IMPLEMENTATION.md`. Este plan queda como referencia de diseño.
- **D5, Android fuera de S4.** La extensión se compila solo para Linux arm64. Android se marca como pendiente hasta tener NDK y dispositivo verificados.

## 13. Fases de ejecución
- **Fase A (implementador):** crear `native/untitled_sandbox/` con las tres clases. Verificar que cargan en Godot headless y que `test_probe`, `test_lua_sandbox` y `test_wasm_sandbox` siguen pasando.
- **Fase B (implementador):** `core/runtime_adapter.gd`, `core/runtime_lua.gd`, `core/runtime_wasm.gd`, `core/runtime_gdscript.gd`, y la selección por `runtime` en `core/mod_registry.gd` y `core/mod_manifest.gd`.
- **Fase C (implementador):** `core/api_version_manager.gd` y el proxy de API con permisos.
- **Fase D (tester, en paralelo con el auditor):** pruebas de aceptación de la sección 8, cada una ejecutable con un solo comando, sin modificar la implementación.
- **Fase E (auditor):** revisión de seguridad y de compatibilidad, sin modificar archivos.

Ninguna fase avanza si la anterior no tiene salida real de prueba.
