# S2 — `LuaSandbox` en la extensión `untitled_sandbox`

Spike aislado de la etapa S2 de `docs/SANDBOX_PLAN.md` (sección 4). Reutiliza la
configuración de build de S1 (`spikes/s1_sandbox/`) y añade la clase
`LuaSandbox`. No modifica `core/` ni `mods/`.

## Resultado

- 20 comprobaciones, 20 PASS, 0 FAIL.
- Script de prueba termina con código **0**.
- Bucle infinito cortado por límite de instrucciones.
- Crecimiento de memoria por encima del tope denegado (Lua devuelve
  `not enough memory`).
- Llamada a función de host registrada devuelve el valor esperado.
- Error de sintaxis y error de ejecución en Lua se capturan sin tumbar Godot.

## API

```gdscript
var s := LuaSandbox.new()
s.set_memory_limit(1024 * 1024)        # bytes; 0 = sin tope. Por defecto 16 MiB.
s.set_instruction_limit(200000)        # instrucciones por llamada; 0 = sin tope. Por defecto 1e6.
s.register_host("host_add", func(a, b): return a + b)
var ok = s.load("function f(x) return host_add(x, 41) end")   # true o Dictionary de error
var value = s.call("f", [1])                                  # valor Lua o Dictionary de error
```

- `load(source: String) -> Variant`: `true` si compila y ejecuta el chunk; si no,
  `Dictionary { "kind": String, "message": String }`.
- `call(fn_name: String, args: Array) -> Variant`: valor devuelto convertido a
  Variant; si no, `Dictionary` de error. El contador de instrucciones se reinicia
  en cada llamada.
- `register_host(name, callable)`: expone el `Callable` como global Lua. Si se
  registra después de `load`, se instala de inmediato.
- `get_last_error()`, `get_last_error_kind()`: último error (`""` si no hubo).
- `get_memory_used()`, `get_memory_peak()`, `get_memory_limit()`,
  `get_instruction_limit()`, `reset()`.

Tipos de error (`kind`): `instruction_limit`, `memory_limit`, `syntax`, `runtime`.

Conversión: `nil`↔`null`, boolean, integer, float, string, Array↔tabla
secuencial, Dictionary↔tabla con claves no secuenciales, Callable→función Lua.
Funciones/threads/userdata de Lua se convierten a `null`.

Librerías abiertas: `base`, `string`, `table`, `math`, `utf8`, `coroutine`.
No se abren `io`, `os`, `package`, `debug`; `dofile` y `loadfile` se eliminan.

## Fuente de Lua

- Versión: **Lua 5.4.9** (comprobado en `src/lua.h`: `LUA_VERSION_RELEASE "9"`).
- Fuente: `https://www.lua.org/ftp/lua-5.4.9.tar.gz` (repositorio oficial,
  descargado el 2026-11-19). El tarball no está firmado; no se pudo verificar una
  suma publicada por Lua.org.
- SHA-256 del tarball descargado:
  `2335b6c582a52654f94612bf10d2f4672805d05329aa6568b1d8cd9e5c6fb8e6`.
- No se usaron los paquetes Lua de Termux (`lua54`/`liblua5.4`): están
  compilados para Bionic y esta extensión se compila con el toolchain glibc de
  S1. Lua se compila desde el código fuente oficial con el mismo `gcc-glibc`, y
  se enlaza **estáticamente** (`liblua.a`); el `.so` final solo depende de
  `libm.so.6`, `libc.so.6` (verificado con `readelf -d`).

### Compilar Lua (una sola vez)

```bash
cd "$HOME/UNTITLED/spikes/s2_lua/vendor"
curl -fsSL -o lua-5.4.9.tar.gz https://www.lua.org/ftp/lua-5.4.9.tar.gz
sha256sum lua-5.4.9.tar.gz
tar xzf lua-5.4.9.tar.gz
cd lua-5.4.9/src
gcc -O2 -fPIC -DLUA_USE_POSIX -c lapi.c lcode.c lctype.c ldebug.c ldo.c \
  ldump.c lfunc.c lgc.c llex.c lmem.c lobject.c lopcodes.c lparser.c lstate.c \
  lstring.c ltable.c ltm.c lundump.c lvm.c lzio.c lauxlib.c lbaselib.c \
  lcorolib.c ldblib.c liolib.c lmathlib.c loadlib.c loslib.c lstrlib.c \
  ltablib.c lutf8lib.c linit.c
ar rcs liblua.a lapi.o lcode.o lctype.o ldebug.o ldo.o ldump.o lfunc.o lgc.o \
  llex.o lmem.o lobject.o lopcodes.o lparser.o lstate.o lstring.o ltable.o \
  ltm.o lundump.o lvm.o lzio.o lauxlib.o lbaselib.o lcorolib.o ldblib.o \
  liolib.o lmathlib.o loadlib.o loslib.o lstrlib.o ltablib.o lutf8lib.o linit.o
```

`vendor/lua-5.4.9/` está en `.gitignore` (fuente no versionado). La compilación
de la extensión requiere que `vendor/lua-5.4.9/src/liblua.a` exista; repetir los
pasos anteriores si falta.

## Compilación de la extensión

Mismo método que S1: `godot-cpp` ya compilado en `~/tools/godot-cpp` (tag
`godot-4.5-stable`), SCons de Termux y `g++` glibc. `scons` sin `platform=...`
falla en Termux.

```bash
cd "$HOME/UNTITLED/spikes/s2_lua"
scons platform=linux arch=arm64 target=template_debug -j4
```

Salida real (código 0):

```text
scons: Reading SConscript files ...
scons: done reading SConscript files.
scons: Building targets ...
g++ -o src/lua_sandbox.os -c -std=c++17 -fPIC -O2 -fno-exceptions -fPIC -DDEBUG_ENABLED -DNDEBUG -DTHREADS_ENABLED -DHOT_RELOAD_ENABLED -DLINUX_ENABLED -DUNIX_ENABLED -Isrc -Ivendor/lua-5.4.9/src -I/data/data/com.termux/files/home/tools/godot-cpp/include -I/data/data/com.termux/files/home/tools/godot-cpp/gen/include -I/data/data/com.termux/files/home/tools/godot-cpp/gdextension src/lua_sandbox.cpp
g++ -o src/register_types.os -c -std=c++17 -fPIC -O2 -fno-exceptions -fPIC -DDEBUG_ENABLED -DNDEBUG -DTHREADS_ENABLED -DHOT_RELOAD_ENABLED -DLINUX_ENABLED -DUNIX_ENABLED -Isrc -Ivendor/lua-5.4.9/src -I/data/data/com.termux/files/home/tools/godot-cpp/include -I/data/data/com.termux/files/home/tools/godot-cpp/gen/include -I/data/data/com.termux/files/home/tools/godot-cpp/gdextension src/register_types.cpp
g++ -o bin/libuntitled_sandbox.linux.template_debug.arm64.so -static-libgcc -static-libstdc++ -pthread -shared src/lua_sandbox.os src/register_types.os -Lvendor/lua-5.4.9/src -L/data/data/com.termux/files/home/tools/godot-cpp/bin -llua -lgodot-cpp.linux.template_debug.arm64 -ldl
scons: done building targets.
```

## Prueba

```bash
cd "$HOME/UNTITLED/spikes/s2_lua"
bash run_test.sh
```

Equivalente exacto (lo que ejecuta el script, tras asegurar
`.godot/extension_list.cfg`):

```bash
grun "$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64" \
  --headless --path "$HOME/UNTITLED/spikes/s2_lua" \
  --script res://test_lua_sandbox.gd
```

Salida real (ejecutada también desde otro directorio de trabajo; misma salida):

```text
libfontconfig.so.1: cannot open shared object file: No such file or directory
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

PASS load_infinite_loop_chunk
PASS instruction_limit_cuts_loop
PASS instruction_limit_last_error
  instruction error: instruction limit exceeded
PASS load_memory_chunk
PASS memory_limit_denies_growth
PASS memory_used_below_limit
  memory error: not enough memory
  memory used/peak/limit: 1042984/1048175/1048576
PASS load_host_chunk
PASS host_call_returns_expected
PASS host_call_after_load_returns_expected
PASS host_call_no_error
PASS syntax_error_controlled
  syntax error: mod:1: <name> or '...' expected near 'end'
PASS load_runtime_error_chunk
PASS runtime_error_controlled
  runtime error: mod:1: boom
PASS godot_survives_errors
PASS load_value_chunk
PASS int_arg_int_return
PASS string_arg_string_return
PASS array_return
PASS load_reuse_chunk
PASS instruction_budget_resets_per_call
CHECKS 20 FAILURES 0
ALL PASS
```

Código de salida real: **0**. El aviso de `libfontconfig.so.1` es no fatal y ya
aparecía en S1.

Correspondencia con los criterios de aceptación:

1. `instruction_limit_cuts_loop`: bucle `while true` → `kind ==
   "instruction_limit"`; `spin()` no vuelve.
2. `memory_limit_denies_growth`: `set_memory_limit(1 MiB)` + `string.rep('x',
   4096)` en bucle → `kind == "memory_limit"`, mensaje `not enough memory`;
   memoria usada 1 042 984 B ≤ tope 1 048 576 B.
3. `host_call_returns_expected`: `host_add(1, 41)` → `42`;
   `use_echo("abc")` → `"echo:abc"` (host registrado después de `load`).
4. `syntax_error_controlled` + `runtime_error_controlled`: ambos devuelven
   Dictionary de error y el proceso sigue hasta `ALL PASS` con código 0.

## Cómo funciona

- **Allocator propio**: `lua_newstate` usa un allocator que contabiliza bytes
  (con `osize` real cuando `ptr != NULL`; con `ptr == NULL`, `osize` es una
  etiqueta de tipo y no se usa). Si `usado - osize + nsize` supera el tope,
  devuelve `NULL`; Lua hace GC de emergencia, reintenta una vez y, si sigue sin
  caber, eleva `LUA_ERRMEM`, que `pcall` captura.
- **Hook de instrucciones**: `lua_sethook(..., LUA_MASKCOUNT, step)` con
  `step = min(limite, 10000)`. El hook acumula y llama `lua_error` al superar el
  tope. El hook se instala por `load`/`call` y se retira al terminar; el contador
  se reinicia en cada llamada.
- **Host**: `register_host` guarda el `Callable` y crea una closure C con el
  nombre como upvalue; al invocarse convierte argumentos Lua→Variant, llama
  `Callable.callv` y devuelve el resultado a Lua.
- El `lua_State` se crea en el primer `load` (permite fijar límites antes) y se
  cierra en el destructor/`reset()`.

## Fallos conocidos y límites

- Solo probado en **Linux arm64** (Godot 4.7 headless). Android no se compiló
  ni probó.
- El sandbox aísla ejecución (instrucciones y memoria), no capacidades: las
  librerías abiertas no incluyen `io`, `os`, `package` ni `debug`, pero `load`
  permite compilar más chunks Lua (siguen sujetos a los límites).
- Tablas Lua con claves enteras no consecutivas, o mezcladas, se entregan como
  `Dictionary`; claves que no son hashables en Godot (tablas) se omiten.
- Funciones Lua devueltas a GDScript se convierten a `null`; para exponerlas hay
  que envolverlas en una función de host.
- Los `Callable` pasados a Lua como argumento/retorno se guardan hasta
  `reset()`/destrucción del sandbox (no se liberan por GC de Lua). Es una fuga
  acotada, no un fallo funcional.
- `kind` se deduce del estado de `pcall` y del texto del error; un script puede
  falsificar el texto `"instruction limit exceeded"` para reportar ese `kind`.
- El límite de instrucciones no acota tiempo dentro de funciones de host (son
  código C/GDScript fuera de la VM Lua).
- `godot --headless --path ... --import` sigue abortando con 134 en este
  entorno (arrastrado de S1); no se usa. `run_test.sh` escribe
  `.godot/extension_list.cfg` directamente.

## Archivos

- `SConstruct`
- `src/lua_sandbox.h`, `src/lua_sandbox.cpp`, `src/register_types.cpp`
- `untitled_sandbox.gdextension`
- `project.godot`
- `test_lua_sandbox.gd`
- `run_test.sh`
- `.gitignore`
- `vendor/lua-5.4.9/` (generado, no versionado)
