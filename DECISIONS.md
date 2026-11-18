# DECISIONS

Formato: decisión — motivo — alternativa descartada. Fecha `NO VERIFICADO` cuando la fuente no la registra.

| Decisión | Fecha | Motivo | Alternativa descartada |
|---|---|---|---|
| Trabajar en `$HOME/UNTITLED` | 2026-11-18 (decisión del usuario) | Repo git en `main` (7 archivos versionados), copia de seguridad y manifiestos verificados | Editar sobre `/sdcard/Documents/UNTITLED` |
| Usar inicialmente el editor Godot Android | 2026-11-18 (decisión del usuario) | Decisión del usuario | Editor Godot Linux arm64 en Termux (queda como herramienta verificada) |
| Permitir mods T2 en GDScript | 2026-11-18 (decisión del usuario) | Decisión del usuario, con advertencia y elección explícita | Prohibir GDScript en mods |
| Objetivo de 60 FPS en S25 FE | 2026-11-18 (decisión del usuario) | Decisión del usuario; sujeto a medición | Objetivos menores fijados de antemano |
| Día sin Claude: domingo | 2026-11-18 (decisión del usuario) | Decisión del usuario | Sin día de descanso |
| Compatibilidad Quest desde el diseño | 2026-11-18 (decisión del usuario) | Decisión del usuario | Añadir VR más tarde |
| Sin límite de lenguaje para mods | 2026-11-18 (decisión del usuario) | Decisión del usuario (sin restricciones arbitrarias) | Lista cerrada de lenguajes permitidos |
| Ejecutar Godot con glibc-runner (grun) + proot y bind de `$HOME/tmp` a `/tmp` | 2026-11-18 | Godot escribe en `/tmp`, no escribible desde Termux | Ejecución directa en Termux (falla por `/tmp`) |
| Conservar `/sdcard/Documents/UNTITLED` intacto | 2026-11-18 | Copia de seguridad con hashes idénticos; origen aún no retirado | Borrar el origen tras copiar |
| Migrar solo los 7 archivos versionados (`.godot/` ignorado) | 2026-11-18 | Commit `95d7cda`; `.godot/` es caché | Versionar `.godot/` |
| Exportar mods como PCK (propuesta, pendiente de F2) | 2026-11-18 | M1: `load_resource_pack` funciona en Linux arm64 headless | Otros formatos de empaquetado (no evaluados) |
| Mantener el renderizador XR sin decidir hasta R1 | 2026-11-18 | Conflicto documental: `deploying_to_android` (stable) recomienda Compatibility para Quest; el anuncio 4.7 recomienda Mobile para XR nuevos | Fijar Mobile o Compatibility sin medir |
| Usar OpenCode free para rutina y Claude para decisiones | 2026-11-18 (decisión del usuario) | Coste de los modelos `-free` no verificado; no hay datos de cuota | Usar un solo proveedor |
