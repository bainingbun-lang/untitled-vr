# Sistema de mods

Guía técnica para crear mods de UNTITLED. Todo lo descrito aquí corresponde al código de `core/` en la rama `feature/mod-system` (HEAD `de457b2`).

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

## Construir el ejemplo

```bash
bash tools/build_example_mod.sh
```

Genera `build/mods/untitled.example-hello/example_hello.pck` y copia `mod.json` junto al pack. El script usa el editor en `$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64` y termina con `BUILD_OK`. El PCK de referencia mide 1336 bytes.

## Ejecutar las pruebas

```bash
bash tests/run_all.sh
```

El script construye el mod de ejemplo y ejecuta cada `tests/test_*.gd` en headless. Resultado esperado en esta rama:

```
PASS test_event_bus.gd
PASS test_example_mod.gd
PASS test_mod_manifest.gd
PASS test_mod_registry.gd
PASS test_mod_resolver.gd
```

Código de salida `0`. La prueba del ejemplo carga el mod por `load_resource_pack`, comprueba que el handler de `game.started` se ejecuta y que la descarga lo desactiva.

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

## Limitaciones y compatibilidad

- Verificado solo en Linux arm64 headless. Android, PC y VR: NO VERIFICADO.
- Godot no puede descargar un PCK ya cargado. `unload` desactiva el módulo (shutdown y suscripciones), pero sus recursos siguen en memoria hasta reiniciar el proceso.
- Los conflictos de `replaces` son error de carga, no una sustitución parcial.
- `unload` no descarga dependientes de forma automática.
- El bus no captura errores ni excepciones de los handlers.
- La resolución de dependencias no soporta prerelease ni metadatos semver.
- `platforms` y `permissions` se validan como datos, pero no se aplican ni se hacen cumplir.
- `engine` solo se comprueba como String; no se compara con la versión del motor.
- Los mods en GDScript no están aislados: no hay sandbox.
- Lua, WASM, GDExtension y C# no están integrados ni probados dentro de Godot.
- La firma de paquetes no está implementada.
- No hay editor de mods.
