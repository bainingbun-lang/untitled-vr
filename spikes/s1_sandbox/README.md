# S1 — Extensión mínima `untitled_sandbox`

Spike aislado para comprobar que una GDExtension con godot-cpp carga en Godot 4.7
headless (Linux arm64).

## Resultado

- Carga: **sí**.
- `Probe.get_version()` devuelve `s1`.
- Script de prueba termina con código **0**.

## godot-cpp

- Tag: `godot-4.5-stable` (el más cercano disponible; no existe `godot-4.7-stable`).
- Commit: `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77`.
- Ruta: `$HOME/tools/godot-cpp`.

## Toolchain

Termux no trae compilador para glibc; `clang` de Termux enlaza contra Bionic y no
sirve para una GDExtension de Godot (proceso glibc). Se instaló el toolchain glibc
del repositorio de Termux:

```bash
yes | apt install gcc-glibc
```

`g++` resuelve a `/data/data/com.termux/files/usr/glibc/bin/g++` (GCC 14.2.1,
target `aarch64-linux-gnu`). SCons ya estaba instalado (`~/.local/bin/scons`,
v4.11.1).

## Compilación

### 1. godot-cpp (una sola vez)

```bash
cd "$HOME/tools/godot-cpp"
scons platform=linux arch=arm64 target=template_debug -j4
```

Salida: `scons: done building targets.` (código 0). Genera
`bin/libgodot-cpp.linux.template_debug.arm64.a`.

### 2. Extensión

```bash
cd "$HOME/UNTITLED/spikes/s1_sandbox"
scons -j4
```

Salida real (código 0):

```text
scons: Reading SConscript files ...
scons: done reading SConscript files.
scons: Building targets ...
g++ -o src/probe.os -c -std=c++17 -fPIC -O2 -fno-exceptions -fPIC -DDEBUG_ENABLED -DNDEBUG -DTHREADS_ENABLED -DHOT_RELOAD_ENABLED -DLINUX_ENABLED -DUNIX_ENABLED -Isrc -I/data/data/com.termux/files/home/tools/godot-cpp/include -I/data/data/com.termux/files/home/tools/godot-cpp/gen/include -I/data/data/com.termux/files/home/tools/godot-cpp/gdextension src/probe.cpp
g++ -o src/register_types.os -c -std=c++17 -fPIC -O2 -fno-exceptions -fPIC -DDEBUG_ENABLED -DNDEBUG -DTHREADS_ENABLED -DHOT_RELOAD_ENABLED -DLINUX_ENABLED -DUNIX_ENABLED -Isrc -I/data/data/com.termux/files/home/tools/godot-cpp/include -I/data/data/com.termux/files/home/tools/godot-cpp/gen/include -I/data/data/com.termux/files/home/tools/godot-cpp/gdextension src/register_types.cpp
g++ -o bin/libuntitled_sandbox.linux.template_debug.arm64.so -static-libgcc -static-libstdc++ -pthread -shared src/probe.os src/register_types.os -L/data/data/com.termux/files/home/tools/godot-cpp/bin -lgodot-cpp.linux.template_debug.arm64
scons: done building targets.
```

`SConstruct` enlaza contra el archivo estático ya compilado de godot-cpp (no
recompila las ~900 fuentes de godot-cpp). El `.so` resultante es
`bin/libuntitled_sandbox.linux.template_debug.arm64.so`.

## Prueba

```bash
cd "$HOME/UNTITLED/spikes/s1_sandbox"
bash run_test.sh
```

Equivalente exacto (lo que ejecuta el script, tras asegurar
`.godot/extension_list.cfg`):

```bash
grun "$HOME/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64" \
  --headless --path "$HOME/UNTITLED/spikes/s1_sandbox" \
  --script res://test_probe.gd
```

Salida real:

```text
libfontconfig.so.1: cannot open shared object file: No such file or directory
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

Probe.get_version() = s1
PASS test_probe
```

Código de salida real: **0**.

El aviso de `libfontconfig.so.1` es no fatal (Godot continúa y el proceso termina
con 0); ya se ignoraba en el resto del proyecto.

## Notas y fallos conocidos

- Godot no descubre `.gdextension` solo por estar en el proyecto: necesita
  `.godot/extension_list.cfg`. `run_test.sh` lo escribe si no existe. Sin ese
  archivo el test falló con `Identifier "Probe" not declared in the current scope`
  (código 1).
- `godot --headless --path ... --import` (editor headless) generó
  `extension_list.cfg`, pero el proceso abortó después con código 134. No se
  investigó más porque el camino de prueba directo funciona. Fallo sin resolver.
- `scons` sin `platform=...` falla en Termux porque el Python de Termux reporta
  `sys.platform == "android"` y godot-cpp no lo detecta. Por eso `SConstruct` no
  auto-detecta: fija flags y rutas directamente.
- Probado solo Linux arm64. Android no se compiló ni probó.

## Archivos

- `SConstruct`
- `src/probe.h`, `src/probe.cpp`, `src/register_types.cpp`
- `untitled_sandbox.gdextension`
- `project.godot`
- `test_probe.gd`
- `run_test.sh`
- `.gitignore`
