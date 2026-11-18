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
| Arquitectura en tres capas: núcleo mínimo, módulos y experiencia | 2026-11-18 (aprobado por el usuario) | El núcleo no depende de sistemas de juego; los módulos usan la misma API que los mods | Núcleo con sistemas de juego integrados |
| Manifiesto `mod.json` como formato inicial, versionado y extensible | 2026-11-18 (aprobado por el usuario) | No limitar futuras capacidades del sistema de mods | Formato cerrado sin versión |
| Error de carga si dos módulos sustituyen el mismo sistema sin prioridad o resolución explícita; dependencias y conflictos documentados para el usuario | 2026-11-18 (aprobado por el usuario) | Evitar comportamiento indefinido entre mods | Resolver conflictos por orden de carga implícito |
| GDScript como lenguaje base de mods; Lua y WASM como alternativas por investigar, sin integrar hasta verificar Android, PC y VR | 2026-11-18 (aprobado por el usuario) | Compatibilidad y seguridad sin sacrificar innecesariamente la libertad | Integrar Lua o WASM antes de verificarlos |
| Enfoque progresivo en etapas E0–E7; orden reorganizable con razón técnica documentada | 2026-11-18 (aprobado por el usuario) | Avance verificable por etapas | Desarrollo simultáneo de todos los sistemas |
| Firma de paquetes: investigar integridad, procedencia y confianza; permitir instalación manual de mods no verificados con advertencia | 2026-11-18 (aprobado por el usuario) | No descartar la firma ni impedir mods externos | Descartar la firma; exigir verificación para instalar |
| Todas las plataformas (Android, PC, VR) deben ser modificables; el sistema de mods no se limita a mapas, texturas o contenido | 2026-11-18 (condición aprobada por el usuario) | Plataforma de creación y no solo mods de contenido | Mods limitados a contenido visual |
