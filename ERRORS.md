# ERRORS

| Problema | Causa | Solución | Estado |
|---|---|---|---|
| Godot no puede escribir en `/tmp` desde Termux | `/tmp` no escribible en Termux | Ejecutar con glibc-runner (`grun`) y proot con bind de `$HOME/tmp` a `/tmp` | RESUELTO (verificado con M1 y export) |
| PCK del mod con `project.godot` del proyecto base | Error de copia al preparar el mod | Corregido y reexportado; sin errores de fontconfig después | RESUELTO |
| `replace_files=false` no impide sobrescribir archivos de `res://` del proyecto | Comportamiento real de `load_resource_pack`: solo conserva archivos ya cargados desde otro PCK | No es un fallo: el núcleo es modificable. Usar `replace_files=true` cuando se quiera sustituir y asumir que un script ya cargado requiere reinicio o `CACHE_MODE_IGNORE` (M1, M3) | RESUELTA POR DISEÑO |
| `pm install` denegado | Falta de permiso en el teléfono | Ninguna aplicada | ABIERTO |
| Aviso de fontconfig | Entorno Termux/proot sin configuración de fuentes | Sin acción registrada | NO VERIFICADO |
| Autoload `res://mod_manager.gd` en errores de export | `project.godot` mal copiado | Corregido (ver T-EXPORT-TRIAGE); era el único error real del export | RESUELTO |
| APK editor Android instalado no coincide con el 4.7 oficial | Instalación previa de `org.godotengine.editor.v4`, versión no verificada | Pendiente: instalar el APK 4.7 oficial (bloqueado por permisos) | ABIERTO |
| `opencode run` muestra la ayuda o `t.includes is not a function` | Un mensaje largo con `--flags` se parsea como opciones; `--title` con mensaje largo también falla | Mensaje corto como posicional primero, detalle en archivo con `-f` colocado después del mensaje (`opencode run "msg" -m modelo --dir ... -f spec.txt`) | RESUELTO (verificado) |
| `grun godot` falla con `libfontconfig.so.1` | Falta la biblioteca en el entorno proot/Termux | Ignorable: Godot funciona y termina con código 0 | RESUELTO (aviso, sin efecto) |
| `PROJECT_STATUS.md` indicaba rama `main`, HEAD `628563e` y 25 archivos | Documento escrito antes de la Fase B | Corregido: rama `feature/mod-system`, HEAD `de457b2`, 51 archivos; `main` sigue en `628563e` | RESUELTO |
| `PROJECT_STATUS.md` afirmaba que no existían mods en el proyecto | Estado anterior a la Fase B | Corregido: `core/` y `mods/example.hello/` documentados; el juego sigue sin escenas | RESUELTO |
| `CHANGELOG.md` atribuía al validador una limitación ya superada | La entrada de `c85d736` es previa a `08e8abd`; el código actual distingue `owner:sistema` | Nota corregida en `CHANGELOG.md` y discrepancia registrada aquí | RESUELTO |
| `TASKS.md` mantenía pendiente el esquema del cargador | `core/mod_registry.gd` ya implementa `scan`, `load_all` y `unload` | Marcada HECHA la tarea 9 (`d808b94`) | RESUELTO |
| `T-STATE-DOCS` decía que había 10 modelos `-free` | Recuento anterior de `opencode models` | `TOKEN_BUDGET.md` usa el recuento verificado: 11 `-free` + `big-pickle` (12) | RESUELTO |
| `build_example_mod.sh` emite `Couldn't save project.binary at '/tmp/...'` | `grun` sin bind de `/tmp` escribible; el PCK se genera igual | Ignorable para el PCK; si se necesita `project.binary`, ejecutar con `proot -b $HOME/tmp:/tmp` | ABIERTO (sin efecto en las pruebas) |
| Sustitución de script del núcleo sin efecto en instancias ya creadas | Caché de `ResourceLoader` e instancias existentes: el script ya resuelto, la instancia y el autoload conservan la versión anterior (M3) | Reiniciar el proceso o usar `ResourceLoader.load(..., CACHE_MODE_IGNORE)` para cargas nuevas; `load()` con caché por defecto sigue devolviendo la versión antigua | RESUELTA POR DISEÑO (limitación documentada, M3) |
| Las pruebas de spike generaban `.pck` versionables | `spikes/*/out/` no estaba en `.gitignore` | Añadido `spikes/*/out/` a `.gitignore`; los packs se regeneran con `run.sh` | RESUELTA |
