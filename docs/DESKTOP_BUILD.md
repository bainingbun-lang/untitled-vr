# A20 — Exportación de escritorio (Windows / Linux x86_64)

## Estado

Artefactos generados y verificados solo por formato, tamaño y SHA-256. No se han ejecutado: en este entorno (Termux/Android ARM64) no es posible arrancar binarios PE32+ ni ELF x86-64. No se afirma que funcionen en destino.

## Plantillas disponibles

`~/.local/share/godot/export_templates/4.7.stable/` contiene, entre otras:

- Windows: `windows_release_x86_64.exe`, `windows_debug_x86_64.exe`, `windows_release_x86_64_console.exe`, `windows_debug_x86_64_console.exe`, variantes `x86_32` y `arm64`.
- Linux: `linux_release.x86_64`, `linux_debug.x86_64`, variantes `x86_32`, `arm32` y `arm64`.

`version.txt` = `4.7.stable`. No fue necesario descargar ni instalar plantillas `.tpz`.

## Presets

`export_presets.cfg` conserva `[preset.0]` (Android) sin cambios y añade:

- `[preset.1]` `Windows Desktop` / `Windows Desktop`, con `application/modify_resources=false` (sin rcedit; no se modifica el icono de recursos)
- `[preset.2]` `Linux x86_64` / `Linux`

Copia de seguridad previa: `~/untitled-control/export_presets.cfg.bak-A20-20261120-001302`.

## Flujo

`tools/build_desktop.sh` reconstruye siempre `build/desktop_project` desde cero con `core`, `scenes`, `assets`, `mods`, `project.godot`, `export_presets.cfg`, `icon.svg` e `icon.svg.import`. Después importa en headless y exporta dentro de `termux-chroot` (Godot necesita `/tmp`).

Uso:

```sh
bash tools/build_desktop.sh
```

Comandos efectivos (dentro de `termux-chroot`):

```sh
grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path build/desktop_project --editor --quit
grun -s "ld.so ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path build/desktop_project --export-release 'Windows Desktop' ~/untitled-control/builds/untitled_win.exe"
grun -s "ld.so ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path build/desktop_project --export-release 'Linux x86_64' ~/untitled-control/builds/untitled_linux_x86_64"
```

Dos particularidades del entorno obligan a esa forma:

1. `termux-chroot` ejecuta `sh -c "$*"`: hay que pasarle la orden `bash -c "..."` como un único argumento, si no se pierde el primer comando.
2. `grun` usa `$@` sin comillas al lanzar el binario, por lo que `grun <godot> ... --export-release 'Windows Desktop' ...` parte el nombre en `Windows` + `Desktop` y Godot responde `Invalid export preset name: Windows.` (fallo reproducido dos veces). `grun -s "<orden>"` conserva la cadena citada; `ld.so` dentro de ese shell mantiene el lanzamiento glibc sin partir argumentos.

Logs: `~/untitled-control/cycle2/A20_import.log`, `A20_win_export.log`, `A20_linux_export.log`, `A20_build_script.log`. Ninguno contiene `SCRIPT ERROR`.

## Artefactos

| Artefacto | `file` | Tamaño | SHA-256 |
| --- | --- | --- | --- |
| `~/untitled-control/builds/untitled_win.exe` | PE32+ executable for MS Windows 5.02 (GUI), x86-64 | 109160448 bytes | `c42eb5d17f683eb8bcd52c19a9f36ebf811b1788623878d5276a7d9ffc09f95c` |
| `~/untitled-control/builds/untitled_linux_x86_64` | ELF 64-bit LSB executable, x86-64, dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2 | 73433400 bytes | `3154bb4465f616e24b811dd576e9230022872cd80f8d5ab854efed2716b926d4` |

Sumas también en `~/untitled-control/builds/desktop_sha256.txt`.

## Verificación

- Importación: salida 0, sin `SCRIPT ERROR`.
- Exportaciones: salida 0, sin `SCRIPT ERROR` ni errores de plantilla/preset.
- Script completo: salida 0, `BUILD_OK`, hashes reproducibles en dos ejecuciones.
- `file`, `stat` y `sha256sum` ejecutados sobre ambos artefactos.
- Pendiente: prueba de ejecución en Windows x86_64 y Linux x86_64 reales.
