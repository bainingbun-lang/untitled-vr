# S4 Fase B.1 — Auditoría de APIs nativas (verificada en cabeceras y fuentes)

Fuentes: spikes/s2_lua/src/lua_sandbox.h, lua_sandbox.cpp; spikes/s3_wasm/src/wasm_sandbox.h, wasm_sandbox.cpp. No se inventa ninguna interfaz.

## LuaSandbox (RefCounted)
| Método | Retorno real | Notas |
|---|---|---|
| load(source: String) | `true` si OK; `Dictionary{kind,message}` si error | Compila el chunk; no ejecuta. |
| call(fn_name: String, args: Array) | valor de Lua, o `Dictionary{kind,message}` si error | Ambigüedad: un valor de retorno puede ser un Dictionary. Comprobar SIEMPRE con get_last_error_kind(). |
| register_host(name: String, callable: Callable) | void | Expone un Callable de Godot como función global de Lua. |
| reset() | void | Libera el estado Lua. |
| set_memory_limit(bytes) / get_memory_limit() | — | Límite de memoria del allocator propio. |
| set_instruction_limit(n) / get_instruction_limit() | — | Corta bucles por hook de instrucciones. |
| get_memory_used / get_memory_peak | int | Medición. |
| get_last_error() / get_last_error_kind() | String | Último error. kind: p.ej. instruction_limit. |

Tipos que cruzan la frontera: los de Variant convertibles (números, String, Array, Dictionary). Funciones Lua devueltas a GDScript se convierten en null (limitación documentada en S2).

## WasmSandbox (RefCounted)
| Método | Retorno real | Notas |
|---|---|---|
| load(bytes: PackedByteArray) | `true` si OK; error `Dictionary` si falla | Compila e instancia el módulo. |
| call(fn_name: String, args: Array) | valor, o error `Dictionary` | Mismo problema de ambigüedad: usar get_last_error_kind(). |
| register_host(name: String, callable: Callable) | void | Import de host. |
| reset() | void | |
| set_memory_limit / get_memory_limit | — | Límite de memoria lineal. |
| set_fuel_limit / get_fuel_limit | — | Corta bucles por fuel. |
| get_last_error() / get_last_error_kind() | String | kinds: fuel_limit, not_loaded, export_not_found, load, … |
| is_loaded() | bool | Único método de estado; LuaSandbox NO lo tiene. |

Tipos de host en WASM: solo numéricos (i32, i64, f32, f64). Strings y Dictionary NO cruzan la frontera de imports de host (limitación real de wasm_sandbox.cpp: variant_to_val). Un mod WASM solo puede pasar números al host.

## Diferencias que el adaptador debe respetar
1. No existe `init`, `shutdown` ni `handle_event` en las clases nativas. El primer intento de runtime_lua.gd/runtime_wasm.gd llamaba a métodos inexistentes.
2. Para detectar error, usar get_last_error_kind() != "" tras load/call, no el tipo del retorno.
3. LuaSandbox no tiene is_loaded(): usar el retorno true de load().
4. WASM: los mods deben exportar las funciones que el adaptador llama; los imports de host solo numéricos.

## Contrato que deben implementar los adaptadores
- load(manifest, dir) -> String: lee `entry` (Lua: texto; WASM: bytes), llama sandbox.load(); "" si OK, texto de error si falla.
- init(api) -> String: registra en el sandbox solo las funciones de host permitidas por `permissions`; si el mod exporta `_mod_init`, lo llama con call(). "" si OK.
- handle_event(event, payload) -> Variant: call("handle_event", [event, payload]); comprueba get_last_error_kind().
- get_instance() -> Object: null (no hay instancia GDScript).
- unload(): reset() y limpia referencias.
- Errores: nunca propagar excepciones; cada fallo deja el mod en failed sin afectar a otros.

## Pendiente de verificar en ejecución (no en lectura)
- Que el registro de host con permisos se aplique (un mod sin permiso debe fallar al llamar).
- Fixtures reales: un mod Lua (.lua) y un mod WASM (.wasm exportando _mod_init y handle_event). Hay que confirmar cómo generar el .wasm sin wat2wasm.
