# Sistema de mods

Guía técnica para crear mods de UNTITLED. Todo lo descrito aquí corresponde al código de `core/` en la rama `feature/mod-system` (HEAD `b4cdaa5`; copias, perfiles y transparencia aún sin commit).

Estado de verificación: el sistema se ha ejecutado y probado solo en Linux arm64 headless (Termux, Godot 4.7). En Android, PC y VR no se ha ejecutado: NO VERIFICADO.

## Estructura de un mod

Un mod es un directorio con un `mod.json` y, opcionalmente, un pack `.pck` y un script de entrada:

```
mods/example.hello/
  mod.json                  manifiesto obligatorio
  project.godot             proyecto auxiliar para exportar el pack
  export_presets.cfg        preset de exportación del pack
  example_hello/main.gd     script de entrada (entry)
```

El resultado de construir el ejemplo es un directorio instalable:

```
build/mods/untitled.example-hello/
  mod.json
  example_hello.pck
```

`ModRegistry.scan(root_dir)` recorre solo los subdirectorios inmediatos de `root_dir` y toma cada uno que contenga `mod.json`. El manifiesto se lee del directorio, no del pack. `pack` y `entry` son opcionales: un mod sin `entry` carga su pack pero no instancia script; un mod sin `pack` puede registrar un script de entrada que ya exista en el proyecto.

### Contenido data-driven

`mods/example.weapon/` muestra un mod sin pack ni script:

```
mods/example.weapon/
  mod.json
  content/weapons.json
  content/items.json
  content/ammo.json
```

`ContentRegistry` (`res://core/game/content_registry.gd`) lee los `*.json` de `content/`
y del raíz del mod (excepto `mod.json`). Cada entrada lleva `type` e `id` canónico:

```json
{
  "content": [{
    "type": "weapon",
    "id": "untitled.example-weapon:rust_pistol",
    "name": "Pistola oxidada",
    "damage": 22.0
  }]
}
```

Tipos admitidos: `weapon`, `ammo`, `item`, `npc_type`, `surface`, `vehicle`,
`sound_bank` y `gore_profile`. El contenido base vive en `data/base/*.json` con el
mod virtual `untitled.base` y prioridad `0`; los mods normales usan prioridad `100`.

Reglas del registro:

- El id canónico es `modid:nombre`, en minúsculas. El id público es solo `nombre`,
  por lo que `rust_pistol` sustituye a las APIs actuales `WeaponDb.get_def("rust_pistol")`.
- La validación es estricta: campos desconocidos, tipos incorrectos, rangos fuera de
  límite o ids de otro mod se rechazan. Una entrada inválida no afecta a las demás
  ni al contenido base.
- Para sustituir contenido existente hace falta `replaces` explícito con el id canónico
  previo **y** mayor prioridad. Dos mods con la misma prioridad para el mismo id público
  se rechazan sin alterar el contenido ya cargado.
- `ModRegistry.load_all` y `unload` sincronizan el registro; `ModReloader.reload`
  conserva el contenido del mod tras la recarga.
- Los archivos visuales deben vivir fuera de `mods/` porque `mods/.gdignore` impide que
  Godot genere `.import` allí. El ejemplo referencia
  `res://assets/models/weapons/v2/rust_pistol.gltf` (Quaternius CC0, registrado en
  `assets/CREDITS.md`).

`WeaponDb`, `ItemDb`, `VehicleDb` y `SurfaceMaterialDef` son adaptadores sobre este
registro. Sus APIs estáticas anteriores siguen devolviendo los mismos ids base;
`ItemDb.new()` sigue empezando vacío y `ItemDb.load_content()` registra los items de datos.

## Manifiesto `mod.json`

| Campo | Tipo | Obligatorio | Regla |
|---|---|---|---|
| `schema_version` | int | sí | debe ser `1` |
| `id` | String | sí | `autor.nombre`: `^[a-z0-9-]+\.[a-z0-9-]+$` |
| `version` | String | sí | `MAYOR.MENOR.PARCHE`, solo dígitos |
| `engine` | String | sí | se valida el tipo, no la versión |
| `depends` | Dictionary | no | clave = id de otro mod; valor = rango semver |
| `replaces` | Array | no | `"sistema"` o `"modulo:sistema"` |
| `priority` | int | no | por defecto `100` |
| `platforms` | Array | no | valores permitidos: `android`, `pc`, `vr` |
| `permissions` | Array | no | lista de String; no se aplica todavía |
| `pack` | String | no | nombre de archivo sin ruta, terminado en `.pck` |
| `entry` | String | no | ruta `res://...` terminada en `.gd` |

`depends`, `replaces`, `platforms` y `permissions` se inicializan vacíos si faltan. `priority` se inicializa en `100`. Los campos desconocidos se conservan. Los números JSON de `schema_version` y `priority` se convierten de float a int solo cuando son enteros exactos.

Ejemplo válido (`mods/example.hello/mod.json`):

```json
{
  "schema_version": 1,
  "id": "untitled.example-hello",
  "version": "0.1.0",
  "engine": "4.7",
  "pack": "example_hello.pck",
  "entry": "res://example_hello/main.gd",
  "platforms": ["pc", "android", "vr"],
  "permissions": []
}
```

## `replaces` y prioridad

Formatos aceptados:

- `"sistema"`: sustituye un sistema del núcleo. Se interpreta como `untitled.base:sistema`.
- `"modulo:sistema"`: sustituye un sistema propiedad de otro mod. `modulo` debe cumplir el patrón de id (`autor.nombre`).
- El nombre de sistema cumple `^[a-z0-9_-]+$`.

Reglas de resolución:

- Gana la prioridad numérica mayor.
- Si dos o más módulos válidos declaran el mismo `owner:sistema` con la misma prioridad máxima, es un conflicto.
- Las prioridades menores no generan conflicto mientras haya un único ganador en la prioridad máxima.
- En `ModRegistry.load_all`, un conflicto es error de carga: todos los módulos implicados quedan en `failed` y se devuelve el mensaje del conflicto.
- La prioridad también ordena la carga: entre módulos listos, se carga antes el número menor, con desempate por id ascendente.

`ModManifest.find_conflicts` solo considera manifiestos que pasan la validación. `resolve_replacements` devuelve el ganador único por clave, pero la carga actual no aplica sustituciones por esa tabla: el pack se carga con `replace_files=true`.

## Dependencias y rangos semver

Sintaxis soportada por `ModResolver`:

| Forma | Ejemplo | Significado |
|---|---|---|
| cualquiera | `*` | cualquier versión |
| exacta | `1.2.3` o `=1.2.3` | igual a |
| comparador | `>=1.2.3`, `<=1.2.3`, `>1.2.3`, `<1.2.3` | comparación numérica |
| caret | `^1.2.3` | `>=1.2.3` y `<2.0.0` |
| caret 0.x | `^0.2.3` | `>=0.2.3` y `<0.3.0` |

Varios tokens separados por espacios se evalúan como conjunción: `">=1.0.0 <2.0.0"`.

No hay soporte de prerelease ni de metadatos de compilación (`1.0.0-beta`, `1.0.0+build`). Cada componente debe ser numérico.

La resolución comprueba: ids válidos, ids duplicados, versiones válidas, rangos válidos, dependencias ausentes, versiones incompatibles y ciclos (incluida la autodependencia). Si un módulo falla, sus dependientes se marcan como fallidos y se devuelve el motivo. El orden resultante coloca las dependencias antes que sus dependientes.

Ejemplo de dependencia:

```json
"depends": {
  "untitled.base-lib": "^0.2.0"
}
```

## API del módulo

El script de entrada se instancia con `script.new()` y debe implementar `_mod_init(api)`. `_mod_shutdown()` es opcional.

```gdscript
extends RefCounted

var _api


func _mod_init(api) -> void:
	_api = api
	api.subscribe("game.started", _on_game_started, 100)


func _on_game_started(payload: Dictionary) -> void:
	payload["greeted_by"] = "untitled.example-hello"


func _mod_shutdown() -> void:
	pass
```

`ModApi` expone:

- `module_id`: id del módulo.
- `subscribe(event, handler, priority = 100) -> int`: registra un handler. Devuelve el id de suscripción o `-1` si el evento, el handler o el propietario no son válidos.
- `emit(event, payload = {}) -> Dictionary`: emite un evento y devuelve `{ok, handled, stopped, errors}`.

El propietario de la suscripción es el `module_id`; el mod no puede elegir otro. `ModApi` no ofrece baja individual: al descargar el módulo se retiran todas sus suscripciones. Un handler puede devolver `true` para detener la propagación.

Un mod en GDScript se ejecuta sin sandbox, con el mismo acceso al motor que el código del juego.

## Eventos

Formato `ns.nombre`: al menos dos partes separadas por `.`, y cada parte solo admite `a-z`, `0-9` y `_`. Mayúsculas, guiones y espacios hacen el evento inválido.

- Los handlers con prioridad mayor se ejecutan antes.
- A igual prioridad, se respeta el orden de suscripción.
- `emit` trabaja sobre una copia de las suscripciones; suscribirse o darse de baja durante el evento no altera la emisión en curso.
- El bus no captura excepciones ni errores de script dentro de un handler: un fallo ahí lo detiene el motor.

## Registro y ciclo de vida

`ModRegistry` es el cargador. Se construye con un bus: `ModRegistry.new(bus)`.

| Método | Efecto |
|---|---|
| `scan(root_dir)` | Lee los `mod.json` de los subdirectorios y devuelve `{ok, errors, candidates}` |
| `load_all(candidates)` | Resuelve conflictos y dependencias, carga packs y entradas, y llama a `_mod_init` |
| `unload(module_id)` | Llama a `_mod_shutdown`, retira suscripciones y borra el registro |
| `is_loaded(id)` | Indica si el módulo está cargado |
| `loaded_ids()` | Ids en orden de carga |
| `get_instance(id)` | Instancia del script de entrada, o `null` |

Secuencia de carga de cada módulo: se carga el pack con `ProjectSettings.load_resource_pack(ruta, true)`, se carga la entrada con `load(entry)`, se crea la instancia, se registra y se llama a `_mod_init(api)`. Si el pack o la entrada fallan, el módulo no queda cargado.

`load_all` devuelve `{ok, loaded, failed, errors}`. Un módulo no resuelto por dependencias incompletas también aparece en `failed`.

`unload` no hace cascada: si otro módulo cargado depende del solicitado, devuelve error y no descarga nada. La decisión y el orden quedan en manos del llamador.

## Niveles de modificación

No hay un núcleo cerrado a los mods: cualquier componente puede modificarse o sustituirse. `ModCapabilities.describe(kind, platform)` devuelve `{status, flags, note}` para cada nivel y plataforma; `all_kinds()` y `all_platforms()` listan los valores aceptados.

| `kind` | Qué modifica | Estado en PC | Nota del código |
|---|---|---|---|
| `config` | Configuración | `ALLOWED` | — |
| `resource` | Recursos | `ALLOWED` | verificado M1 |
| `script` | Scripts | `ALLOWED` + `RISK_NO_SANDBOX` | verificado M1 |
| `system` | Sistema completo | `UNVERIFIED` | sin prueba registrada |
| `core_script` | Script del núcleo | `ALLOWED_AFTER_RESTART` + `STABILITY_WARNING` | verificado M3 |
| `autoload` | Autoload | `ALLOWED_AFTER_RESTART` + `STABILITY_WARNING` | verificado M3 |
| `loader` | Cargador de mods | `ALLOWED_AFTER_RESTART` + `STABILITY_WARNING` | reemplazar antes del arranque |
| `native_extension` | Código nativo | `REQUIRES_RECOMPILE` + `NEEDS_PERMISSION` + `RISK_NATIVE_CODE` | NO PROBADO |

En Android y VR todas las combinaciones devuelven `UNVERIFIED` (`native_extension` añade `RISK_NATIVE_CODE`), salvo `UNKNOWN_INPUT` cuando el `kind` o la plataforma no existen.

## Copias de seguridad

`ModBackup` trabaja sobre un directorio raíz configurable (`user://backups` por defecto).

| Método | Efecto |
|---|---|
| `snapshot(source_dir, label)` | Copia el directorio y escribe `manifest.json` con SHA-256 por archivo; devuelve `{ok, errors, id, files}` |
| `verify(id)` | Compara el snapshot con su manifiesto; devuelve `{ok, mismatched, missing, extra, errors}` |
| `restore(id, target_dir)` | Verifica y restaura; si el destino existe, crea antes una copia `pre-restore` y la devuelve en `pre_restore_id` |
| `list()` | Ids de snapshots con `manifest.json` |
| `delete(id, confirm)` | Borra solo con `confirm = true` |

## Perfiles

`ModProfile` guarda perfiles independientes en `user://profiles` (un JSON por perfil). Un perfil es `{name, mods, experimental}` con ids únicos y ordenados.

| Método | Efecto |
|---|---|
| `validate_name(name)` | `[a-z0-9-]{1,40}` |
| `make(name, mods, experimental = false)` | Normaliza y valida sin escribir |
| `diff(loaded, profile)` | Devuelve `{to_load, to_unload}` |
| `save(profile)` / `load_profile(name)` | Escribe o lee un perfil |
| `list()` / `delete(name, confirm)` | Lista o borra (borrado solo con `confirm = true`) |
| `mark_last_good(name)` / `last_good()` | Perfil de último estado bueno para recuperación |

## Integridad

`ModBackup.make_manifest(dir)` y `ModBackup.check_manifest(dir, manifest)` calculan y comparan SHA-256 por archivo. `verify` devuelve las listas `mismatched`, `missing` y `extra`. La verificación es informativa y no impide modificar archivos; `restore` sí se niega a restaurar un snapshot que no verifica.

## Transparencia

`ModCapabilities` usa los estados `ALLOWED`, `ALLOWED_AFTER_RESTART`, `NEEDS_PERMISSION`, `REQUIRES_RECOMPILE`, `IMPOSSIBLE_ON_PLATFORM`, `UNVERIFIED` y `UNKNOWN_INPUT`. `IMPOSSIBLE_ON_PLATFORM` está definido pero no se asigna a ninguna combinación porque no se ha demostrado. Flags: `RISK_NO_SANDBOX`, `RISK_NATIVE_CODE`, `STABILITY_WARNING` y `NEEDS_PERMISSION` (también usado como flag). La tabla no bloquea la carga; solo informa del estado medido o no medido.

## Construir el ejemplo

```bash
bash tools/build_example_mod.sh
```

Genera `build/mods/untitled.example-hello/example_hello.pck` y copia `mod.json` junto al pack. El script usa el editor en `$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64` y termina con `BUILD_OK`. El PCK de referencia mide 1336 bytes. `mods/example.weapon` no necesita construcción: se instala como directorio con sus JSON de contenido.

Tras añadir un asset visual:

```bash
grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path ~/UNTITLED --import
```

El importador puede terminar con un error final conocido de `daemon`/fontconfig en Termux;
lo importante es que aparezca el `.import` junto al archivo fuente.

## Ejecutar las pruebas

```bash
bash tests/run_all.sh
```

El script construye el mod de ejemplo y ejecuta cada `tests/test_*.gd` en headless. Incluye `test_content_registry.gd` (validación, prioridad, reemplazos y APIs base) y `test_example_weapon_mod.gd` (carga, disparo y recarga en caliente del mod de contenido). La prueba del ejemplo carga `example.hello` por `load_resource_pack`, comprueba que el handler de `game.started` se ejecuta y que la descarga lo desactiva.

En el estado D1 todas las pruebas relevantes pasan, incluidas las de mods y contenido. Queda un fallo preexistente y no relacionado: `test_vr_scale.gd` marca `pistol` (0.55 m) y `submachine_gun` (0.64 m) fuera del rango real esperado según `assets/models/weapons/v2/manifest.json`; no fue introducido por el registro de contenido. Por ese fallo, `tests/run_all.sh` termina con código `1` aunque el resto de pruebas den `PASS`.

## Eventos y hooks de juego (D2)

### Implementado

`ModHooks` (`res://core/game/mod_hooks.gd`) publica 14 eventos con payload documentado en `ModHooks.EVENTS`. Los permisos declarados en el manifiesto se comprueban antes de suscribir, modificar o emitir.

| Evento | Payload | Modificable |
|---|---|---|
| `weapon_fired` | `weapon_id`, `origin`, `direction`, `pellets`, `damage`, `ammo`, `projectile` | `damage` |
| `weapon_reloaded` | `weapon_id`, `mag`, `reserve`, `duration` | — |
| `weapon_jammed` | `weapon_id`, `reason` | — |
| `projectile_hit` | `weapon_id`, `hit`, `position`, `damage`, `distance`, `surface` | `damage` |
| `damage_dealt` | `target`, `zone`, `amount`, `point`, `source`, `weapon_id`, `lethal` | `amount` |
| `wound_created` | `target`, `zone`, `severity`, `point`, `amount` | — |
| `limb_severed` | `target`, `limb`, `point`, `severity` | — |
| `npc_spawned` | `npc_id`, `npc_type`, `position`, `faction` | — |
| `npc_died` | `npc_id`, `npc_type`, `killer`, `position` | — |
| `player_died` | `player_id`, `killer`, `position` | — |
| `item_picked` | `item_id`, `amount`, `inventory_owner`, `position` | — |
| `vehicle_entered` | `vehicle_id`, `player_id`, `seats` | — |
| `map_loaded` | `map_id`, `map_name`, `path`, `seed` | — |
| `wave_started` | `wave`, `total_waves`, `mode`, `enemy_count` | — |

Permisos: `read_events` (suscribirse), `modify_damage` (cambiar `damage`/`amount` en los tres eventos marcados), `spawn_entities`, `inventory` y `network`. `network` siempre se deniega. `ModApi.network_request()` devuelve `false`.

`ModApi` amplía su API retrocompatible con `subscribe_declared()`, `bind_target()`, `set_value()`, `request()`, `fail()`, `permissions()`, `manifest()` y `checkpoint()`. Un manifiesto puede declarar hooks sin script:

```json
{
  "permissions": ["read_events", "modify_damage"],
  "hooks": [
    {"event": "weapon_fired", "method": "on_weapon_fired", "priority": 100},
    {"event": "damage_dealt", "method": "on_damage_dealt", "priority": 100}
  ]
}
```

`mods/example.hook/` es el ejemplo funcional: cuenta disparos y multiplica el daño recibido por `1.5`.

`EventBus.emit()` comprueba el payload antes y después de cada handler. Si un mod sin `modify_damage` lo cambia, restaura la copia, reporta la violación y desactiva al mod retirando sus suscripciones. También detecta handlers que devuelven `{ok: false, error: ...}`, exceden el presupuesto de instrucciones (`checkpoint()`) o superan el límite de tiempo. El resultado incluye `modified_by`, `violations` y `elapsed_us`.

`ModHooks.register_manifest()` aplica los hooks declarativos, respeta `depends` mediante `dependency_order()`, y `ModHooks.emit()` permite a los sistemas del juego publicar eventos con payloads completados con valores por defecto. Los emisores conectados están en `weapon_system.gd`, `damageable.gd` y `player.gd`.

### Probado

- `tests/test_mod_hooks.gd`: `PASS (78 assertions)`, `EXIT=0`. Cubre catálogo, payloads, hooks declarativos, permisos denegados, restauración ante modificación ilegal, desactivación por error/timeout/instrucciones, orden por dependencias e integración con `Damageable`.
- Retrocompatibilidad verificada: `test_event_bus`, `test_example_mod`, `test_mod_registry`, `test_mod_reloader`, `test_boot`, `test_weapons`, `test_player` y `test_armed_npc` siguen pasando.
- `bash tests/run_all.sh`: todas las pruebas de mods y juego pasan. Queda el fallo preexistente de `test_vr_scale.gd` por dimensiones de armas, ajeno a D2.

### Verificado

- Godot 4.7 stable, Linux arm64 headless.
- Los errores `ERROR: ModHooks: ... desactivado` en `test_mod_hooks.gd` son esperados: prueban el aislamiento. No hay `SCRIPT ERROR` ni abort.
- No se añadieron assets, por lo que no hubo que importar nada.

### Limitaciones de D2

- GDScript no es un sandbox: no puede interrumpir bucles no cooperativos. La defensa es cooperativa (`checkpoint()`) y depende de que el handler llame a `api.checkpoint()`.
- No se capturan errores internos del motor dentro de un handler; sí se reportan valores de retorno `{ok: false}`.
- `npc_spawned`, `map_loaded` y `wave_started` están definidos y probados en el catálogo, pero aún no tienen emisores en el juego. Conectar `npc_spawned` en `armed_npc.gd` queda pendiente porque el brief prohíbe tocar ese archivo.

## Errores frecuentes

| Mensaje real | Causa | Corrección |
|---|---|---|
| `schema_version: campo obligatorio ausente` | Falta el campo | Añadir `"schema_version": 1` |
| `schema_version: debe ser 1, se recibio N` | Versión de esquema distinta | Usar `1` |
| `id: formato invalido 'x' (se esperaba autor.nombre)` | Id sin punto o con caracteres no permitidos | Usar `autor.nombre` en minúsculas |
| `version: formato invalido 'x' (se esperaba MAJOR.MINOR.PATCH)` | Versión incompleta o con prerelease | Usar tres números, por ejemplo `1.0.0` |
| `engine: campo obligatorio ausente` | Falta `engine` | Añadir la versión del motor como String |
| `replaces: formato invalido 'x' (se esperaba 'sistema' o 'modulo:sistema')` | Prefijo con formato inválido | Corregir el nombre o el id del propietario |
| `pack: formato invalido 'x' (se esperaba un archivo .pck)` | Pack con ruta o extensión distinta | Usar solo el nombre, por ejemplo `mod.pck` |
| `entry: formato invalido 'x' (se esperaba una ruta res://)` | Entrada sin `res://` | Usar una ruta `res://...` |
| `...: JSON invalido en mod.json` | JSON mal formado | Validar el archivo |
| `...: manifiesto invalido: ...` | Uno o más errores de validación | Corregir los mensajes listados |
| `Conflicto en el sistema 's' de 'o': los módulos a, b lo sustituyen con la misma prioridad N` | Dos mods con la misma prioridad máxima | Cambiar prioridad o retirar un mod |
| `id duplicado 'x' (N manifiestos)` | Dos manifiestos con el mismo id | Dejar un solo manifiesto |
| `x requiere y rango, no está instalado` | Falta la dependencia | Instalar el mod requerido |
| `x requiere y rango, instalada v` | Versión instalada fuera del rango | Ajustar el rango o la versión |
| `dependencia circular: a, b` | Ciclo de dependencias | Romper el ciclo |
| `x no se carga porque y no se carga` | La dependencia falló antes | Corregir primero la dependencia |
| `x: no se pudo cargar el pack 'p.pck'` | Ruta o pack inválido | Revisar el archivo y su ubicación |
| `x: la entrada 'res://...' no implementa _mod_init` | El script no define `_mod_init` | Implementar el método |
| `no se puede descargar 'x': los modulos y dependen de el` | Descarga con dependientes cargados | Descargar primero los dependientes |
| `evento invalido: 'x'` | Evento sin `ns.nombre` o con caracteres no permitidos | Usar minúsculas, dígitos y `_` |
| `id: se esperaba 'modid:nombre'` | Entrada de contenido sin namespace | Usar `untitled.base:pistol` o `tumod:arma` |
| `weapon: campo desconocido 'x'` | Campo no permitido por el esquema de contenido | Quitar el campo o ampliar el esquema en `ContentRegistry` |
| `id publico 'x' ya lo usa 'y'` | Dos mods registran el mismo id público sin prioridad/replaces | Cambiar el id o declarar `replaces` con mayor prioridad |

## Limitaciones y compatibilidad

- Verificado solo en Linux arm64 headless. Android, PC y VR: NO VERIFICADO.
- Un script del núcleo ya cargado, una instancia existente o un autoload ya instanciado no cambian al cargar el PCK. La sustitución solo se aplica si el script se resuelve por primera vez después del pack o al reiniciar; `load()` con caché por defecto devuelve la versión antigua y `ResourceLoader.load(..., CACHE_MODE_IGNORE)` la nueva para cargas nuevas (M3).
- El cargador de mods ya está en uso al arrancar; sustituirlo exige reemplazarlo antes del arranque (M3).
- Godot no puede descargar un PCK ya cargado. `unload` desactiva el módulo (shutdown y suscripciones), pero sus recursos siguen en memoria hasta reiniciar el proceso.
- Los conflictos de `replaces` son error de carga, no una sustitución parcial.
- `unload` no descarga dependientes de forma automática.
- El bus no captura errores ni excepciones internas del motor en los handlers. Sí detecta retornos `{ok: false}`, modificaciones ilegales, timeouts y agotamiento de instrucciones en los eventos de `ModHooks`.
- La resolución de dependencias no soporta prerelease ni metadatos semver.
- `platforms` se valida como dato pero no se aplica. `permissions` se aplica a los eventos de `ModHooks` (D2); los eventos heredados `ns.nombre` conservan su comportamiento abierto por retrocompatibilidad.
- `engine` solo se comprueba como String; no se compara con la versión del motor.
- Los mods en GDScript no están aislados: no hay sandbox.
- Lua, WASM, GDExtension y C# no están integrados ni probados dentro de Godot.
- La firma de paquetes no está implementada.
- No hay editor de mods.
