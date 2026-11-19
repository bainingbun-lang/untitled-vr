# Auditoría de permisos de ModApi (solo lectura, no aplicada)

## Hallazgo principal
core/mod_api.gd, subscribe() y emit():
    if not _has_permission(x) and not _permissions.is_empty(): deny
Efecto: si la lista de permisos está VACÍA, se permite todo. Un mod que no declara permisos tiene acceso completo a subscribe y emit. Esto contradice D-P1 (denegar por defecto).

## Puntos de construcción de ModApi
- core/mod_registry.gd:146: ModApiScript.new(id, _bus, permissions). Único punto real de producción. Pasa los permisos del manifest.
- Tests: tests/test_runtime_wasm.gd, tests/test_runtime_lua.gd, tests/test_mod_registry.gd, tests/test_event_bus.gd construyen ModApi con [] o sin permisos.

## Permisos declarados
- mods/example.hello/mod.json: "permissions": []. Pero su main.gd llama api.subscribe("game.started", ...). Con denegación por defecto dejaría de funcionar.
- tests/test_mod_manifest.gd:120: permisos de ejemplo ["red", "archivos"]. Son nombres sin uso en ModApi: no hay validación de nombres.

## Impacto de denegación por defecto
1. mods/example.hello debe declarar "subscribe" (migración D-P3). Su copia en build/mods también.
2. Tests que suscriben sin declarar permiso (test_mod_registry, test_event_bus) deben declarar "subscribe" o "emit" según uso. Es migración, no relajación de expectativas.
3. Lua y WASM: su adaptador ya deniega por defecto (sin permiso no registra host). No cambia.
4. GDScript: depende de ModApi. Sí cambia.

## Riesgos
- Permisos desconocidos ("red", "archivos") se aceptan sin error: falta validación de nombres contra una lista cerrada.
- Un mod GDScript puede acceder al núcleo directamente sin pasar por ModApi (límite ya documentado en S4).

## Cambio propuesto (NO aplicado)
- _has_permission debe denegar siempre si el permiso no está declarado. Quitar la excepción de lista vacía.
- Validar nombres de permiso contra una lista cerrada: subscribe, emit, y las que se definan.
- Error claro: "permiso 'X' no declarado para el mod Y".
- Migrar mods/example.hello y tests que lo requieran, con docs/MOD_MIGRATION.md.
