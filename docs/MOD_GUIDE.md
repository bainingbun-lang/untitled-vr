# Guía de creación de mods para UNTITLED

Esta guía explica cómo crear, probar y distribuir mods para UNTITLED. Para la referencia técnica completa, consulta `docs/MOD_SYSTEM.md`.

## Resumen rápido

Un mod es un directorio con:
- `mod.json` - manifiesto obligatorio
- `content/` - archivos JSON de contenido data-driven (opcional)
- `project.godot` + `export_presets.cfg` - para exportar un `.pck` (opcional)
- Script de entrada `.gd` - código del mod (opcional)

```
mi_mod/
  mod.json
  content/
    weapons.json
    items.json
  mi_mod/
    main.gd          # script de entrada
```

## Paso 1: Crear el manifiesto `mod.json`

```json
{
  "schema_version": 1,
  "id": "miusuario.mimod",
  "version": "1.0.0",
  "engine": "4.7",
  "pack": "mi_mod.pck",
  "entry": "res://mi_mod/main.gd",
  "platforms": ["pc", "android", "vr"],
  "permissions": ["read_events", "modify_damage"],
  "priority": 100
}
```

**Campos obligatorios:**
- `schema_version`: siempre `1`
- `id`: formato `autor.nombre` (solo minúsculas, dígitos y guiones)
- `version`: semver `MAJOR.MINOR.PATCH`
- `engine`: versión de Godot como string

**Campos opcionales:**
- `pack`: nombre del archivo `.pck` (sin ruta)
- `entry`: ruta `res://...` al script de entrada
- `platforms`: `["pc"]`, `["android"]`, `["vr"]` o combinaciones
- `permissions`: permisos para hooks (ver sección Hooks)
- `depends`: dependencias de otros mods
- `replaces`: sistemas que sustituye
- `priority`: prioridad de carga (default 100)

## Paso 2: Añadir contenido data-driven (sin código)

Crea archivos JSON en `content/`:

**content/weapons.json:**
```json
{
  "content": [{
    "type": "weapon",
    "id": "miusuario.mimod:mi_pistola",
    "name": "Mi Pistola",
    "damage": 25.0,
    "fire_rate": 0.15,
    "mag_size": 15,
    "ammo_type": "miusuario.mimod:9mm",
    "model": "res://assets/models/weapons/v2/mi_pistola.gltf"
  }]
}
```

**content/ammo.json:**
```json
{
  "content": [{
    "type": "ammo",
    "id": "miusuario.mimod:9mm",
    "name": "9mm Personalizado",
    "damage_mod": 1.0,
    "penetration": 0.5
  }]
}
```

Tipos soportados: `weapon`, `ammo`, `item`, `npc_type`, `surface`, `vehicle`, `sound_bank`, `gore_profile`.

**Reglas importantes:**
- El `id` canónico es `modid:nombre` (ej: `miusuario.mimod:mi_pistola`)
- El id público es solo `nombre` (ej: `mi_pistola`)
- Para sobrescribir contenido base, usa `replaces` en el manifiesto + prioridad mayor

## Paso 3: Crear un script de entrada (con código)

**mi_mod/main.gd:**
```gdscript
extends RefCounted

var _api


func _mod_init(api) -> void:
	_api = api
	
	# Suscribirse a eventos del juego
	api.subscribe("weapon_fired", _on_weapon_fired, 100)
	api.subscribe("damage_dealt", _on_damage_dealt, 100)


func _on_weapon_fired(payload: Dictionary) -> void:
	var weapon_id: String = payload["weapon_id"]
	var damage: float = payload["damage"]
	print("[MiMod] Arma disparada: ", weapon_id, " daño: ", damage)


func _on_damage_dealt(payload: Dictionary) -> void:
	# Modificar daño (requiere permiso "modify_damage")
	if payload.has("amount"):
		payload["amount"] *= 1.5  # Aumentar daño 50%


func _mod_shutdown() -> void:
	# Limpieza opcional
	pass
```

**API disponible en `_mod_init(api)`:**
- `api.module_id` - id de tu mod
- `api.subscribe(evento, handler, prioridad)` - suscribirse a evento
- `api.emit(evento, payload)` - emitir evento
- `api.subscribe_declared()` - para hooks declarativos (ver manifiesto)
- `api.checkpoint()` - llamar periódicamente en handlers largos
- `api.permissions()` - array de permisos concedidos
- `api.manifest()` - tu manifiesto parseado

## Paso 4: Hooks declarativos (sin código en el script)

En `mod.json`, declara hooks directamente:

```json
{
  "permissions": ["read_events", "modify_damage"],
  "hooks": [
    {"event": "weapon_fired", "method": "on_weapon_fired", "priority": 100},
    {"event": "damage_dealt", "method": "on_damage_dealt", "priority": 100}
  ]
}
```

Tu script debe tener los métodos declarados:
```gdscript
func on_weapon_fired(payload: Dictionary) -> void:
	pass

func on_damage_dealt(payload: Dictionary) -> void:
	payload["amount"] *= 1.5
```

## Paso 5: Eventos disponibles

| Evento | Payload clave | Modificable | Permiso necesario |
|---|---|---|---|
| `weapon_fired` | `weapon_id`, `damage`, `origin`, `direction` | `damage` | `modify_damage` |
| `weapon_reloaded` | `weapon_id`, `mag`, `reserve` | — | `read_events` |
| `projectile_hit` | `weapon_id`, `position`, `damage`, `surface` | `damage` | `modify_damage` |
| `damage_dealt` | `target`, `amount`, `weapon_id`, `lethal` | `amount` | `modify_damage` |
| `npc_spawned` | `npc_id`, `npc_type`, `position` | — | `read_events` |
| `npc_died` | `npc_id`, `killer`, `position` | — | `read_events` |
| `item_picked` | `item_id`, `amount`, `position` | — | `inventory` |
| `vehicle_entered` | `vehicle_id`, `player_id` | — | `read_events` |
| `map_loaded` | `map_id`, `map_name`, `seed` | — | `read_events` |
| `wave_started` | `wave`, `mode`, `enemy_count` | — | `read_events` |

**Permisos:**
- `read_events` - suscribirse a cualquier evento
- `modify_damage` - modificar `damage`/`amount` en eventos marcados
- `spawn_entities` - (futuro) spawn de entidades
- `inventory` - (futuro) manipular inventario
- `network` - siempre denegado

## Paso 6: Construir el mod

Si tu mod tiene script de entrada o assets, exporta un `.pck`:

1. Crea `project.godot` y `export_presets.cfg` en la raíz del mod
2. Configura el preset de exportación para "PCK/Zip"
3. Ejecuta:
```bash
bash tools/build_example_mod.sh
```
Genera `build/mods/miusuario.mimod/mi_mod.pck` y copia `mod.json`.

Para mods solo de contenido (JSON en `content/`), **no necesitas construir** - instálalo directamente como directorio.

## Paso 7: Instalar y probar

**Instalación:**
```
mods/
  miusuario.mimod/
    mod.json
    mi_mod.pck        # si tiene pack
    content/          # si es data-driven
```

**Probar en headless:**
```bash
grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path ~/UNTITLED --script res://tests/test_mod_hooks.gd
```

**Probar con el mod de ejemplo:**
```bash
# El mod example.hello está en mods/example.hello/
grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path ~/UNTITLED --script res://tests/test_example_weapon_mod.gd
```

## Paso 8: Recargar en caliente (hot reload)

Desde la consola de debug (F1 en PC, panel VR en muñeca):
```
reload_mods
```

Esto descarga y vuelve a cargar todos los mods manteniendo el contenido registrado.

## Debug Panel - Comandos útiles

| Comando | Descripción |
|---|---|
| `help` | Lista comandos disponibles |
| `spawn <tipo> [nombre]` | Spawnear entidad (npc, item, vehicle) |
| `give <item> [cantidad]` | Dar item al jugador |
| `tp <ubicación>` | Teletransportarse |
| `kill <objetivo>` | Matar entidad |
| `timescale <valor>` | Cambiar velocidad del juego |
| `reload_mods` | Recargar todos los mods |
| `version` | Versión del debug panel |

## Estructura de ejemplo completo

```
mods/miusuario.mi_arma/
  mod.json
  content/
    weapons.json
    ammo.json
  mi_arma/
    main.gd
  # Assets visuales fuera de mods/ (referenciados por ruta res://)
  # ej: assets/models/weapons/v2/mi_pistola.gltf
```

**mod.json:**
```json
{
  "schema_version": 1,
  "id": "miusuario.mi_arma",
  "version": "1.0.0",
  "engine": "4.7",
  "pack": "mi_arma.pck",
  "entry": "res://mi_arma/main.gd",
  "platforms": ["pc", "vr"],
  "permissions": ["read_events", "modify_damage"],
  "hooks": [
    {"event": "weapon_fired", "method": "on_weapon_fired", "priority": 100}
  ]
}
```

**content/weapons.json:**
```json
{
  "content": [{
    "type": "weapon",
    "id": "miusuario.mi_arma:mi_pistola",
    "name": "Mi Pistola",
    "damage": 30.0,
    "fire_rate": 0.1,
    "mag_size": 12,
    "ammo_type": "untitled.base:9mm",
    "model": "res://assets/models/weapons/v2/mi_pistola.gltf"
  }]
}
```

**mi_arma/main.gd:**
```gdscript
extends RefCounted

var _api

func _mod_init(api) -> void:
	_api = api

func on_weapon_fired(payload: Dictionary) -> void:
	if payload["weapon_id"] == "miusuario.mi_arma:mi_pistola":
		payload["damage"] *= 2.0  # Doble daño para mi arma

func _mod_shutdown() -> void:
	pass
```

## Errores comunes y soluciones

| Error | Solución |
|---|---|
| `schema_version: campo obligatorio ausente` | Añade `"schema_version": 1` |
| `id: formato invalido` | Usa `autor.nombre` solo minúsculas/dígitos/guiones |
| `version: formato invalido` | Usa `1.0.0` (tres números) |
| `pack: formato invalido` | Solo nombre de archivo, ej: `mod.pck` |
| `entry: formato invalido` | Usa ruta `res://...` |
| `Conflicto en el sistema` | Cambia `priority` en un mod |
| `id publico ya lo usa` | Cambia el nombre o usa `replaces` con mayor prioridad |
| `no se pudo cargar el pack` | Verifica ruta y que el .pck existe |
| `la entrada no implementa _mod_init` | Añade `func _mod_init(api):` a tu script |
| `evento invalido` | Usa formato `ns.nombre` (minúsculas, dígitos, `_`) |

## Limitaciones actuales

- **Solo verificado en Linux arm64 headless** (Termux, Godot 4.7)
- **No hay sandbox**: mods GDScript tienen acceso total al motor
- **PCK no descargable**: `unload` desactiva el mod pero los recursos quedan en memoria hasta reiniciar
- **Sin firma de paquetes**: cualquiera puede instalar mods
- **Android/PC/VR no verificados**: pueden haber problemas de compatibilidad
- **Dependencias sin prerelease**: solo versiones `X.Y.Z` numéricas

## Recursos adicionales

- `docs/MOD_SYSTEM.md` - Referencia técnica completa
- `mods/example.hello/` - Mod con script de entrada
- `mods/example.weapon/` - Mod solo contenido (data-driven)
- `mods/example.hook/` - Mod con hooks declarativos
- `tools/build_example_mod.sh` - Script de construcción
- `tests/test_mod_hooks.gd` - Pruebas de hooks y eventos
- `tests/test_content_registry.gd` - Pruebas de registro de contenido

## Checklist antes de publicar

- [ ] `mod.json` válido (schema_version=1, id formato correcto, version semver)
- [ ] Permisos declarados coinciden con lo que usa el mod
- [ ] Hooks declarativos tienen métodos correspondientes en el script
- [ ] Assets visuales referenciados con rutas `res://` válidas
- [ ] Probado con `bash tests/run_all.sh`
- [ ] Funciona `reload_mods` sin errores
- [ ] Documentación del mod para usuarios (README)