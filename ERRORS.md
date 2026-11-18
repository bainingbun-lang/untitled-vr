# ERRORS

| Problema | Causa | Solución | Estado |
|---|---|---|---|
| Godot no puede escribir en `/tmp` desde Termux | `/tmp` no escribible en Termux | Ejecutar con glibc-runner (`grun`) y proot con bind de `$HOME/tmp` a `/tmp` | RESUELTO (verificado con M1 y export) |
| PCK del mod con `project.godot` del proyecto base | Error de copia al preparar el mod | Corregido y reexportado; sin errores de fontconfig después | RESUELTO |
| `replace_files=false` no protege archivos de `res://` del proyecto | Comportamiento real de `load_resource_pack`: solo protege archivos ya cargados desde otro PCK | Cargar primero el PCK base (conserva BASE v1); usar `replace_files=true` solo cuando se quiera sobrescribir | ABIERTO (mitigación conocida, falta diseño del PCK base) |
| `pm install` denegado | Falta de permiso en el teléfono | Ninguna aplicada | ABIERTO |
| Aviso de fontconfig | Entorno Termux/proot sin configuración de fuentes | Sin acción registrada | NO VERIFICADO |
| Autoload `res://mod_manager.gd` en errores de export | `project.godot` mal copiado | Corregido (ver T-EXPORT-TRIAGE); era el único error real del export | RESUELTO |
| APK editor Android instalado no coincide con el 4.7 oficial | Instalación previa de `org.godotengine.editor.v4`, versión no verificada | Pendiente: instalar el APK 4.7 oficial (bloqueado por permisos) | ABIERTO |
| `opencode run` muestra la ayuda o `t.includes is not a function` | Un mensaje largo con `--flags` se parsea como opciones; `--title` con mensaje largo también falla | Mensaje corto como posicional primero, detalle en archivo con `-f` colocado después del mensaje (`opencode run "msg" -m modelo --dir ... -f spec.txt`) | RESUELTO (verificado) |
| `grun godot` falla con `libfontconfig.so.1` | Falta la biblioteca en el entorno proot/Termux | Ignorable: Godot funciona y termina con código 0 | RESUELTO (aviso, sin efecto) |
