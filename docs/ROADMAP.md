# ROADMAP (aprobado en principio por el usuario; ajustar con sus reportes)
## Fase 0 — Cerrar la base (en curso)
I1 IA viva en el mundo, K1 coches en el mundo, A1 audio real y disparos por capas, N1 animaciones/manos/combate NPC. Mas: corregir errores graficos que reporte el usuario (el decide si hay o no) y arreglar lo que falle en casco. Menu mejorado con mas opciones (ajustes, modo, mods, recalibrar).
## Fase 1 — NUCLEO MODDABLE (se hace YA, antes que contenido nuevo)
- Todo dato-dirigido: armas, municion, items, NPC, mapas, materiales de superficie, sonidos, parametros de gore, reglas de modo => definiciones JSON/Resource cargadas por ModRegistry (ya existen ModManifest, ModResolver, ModRegistry, ModLoader, ModReloader, ModLint, ModProfile, eventos, sandbox Lua/WASM).
- API de mods por capacidades/permisos, eventos (disparo, daño, muerte, recarga, spawn), reemplazo de assets, mods de script (Lua sandbox), orden de carga y dependencias.
- Mods de ejemplo: arma nueva (JSON + modelo), NPC nuevo, mapa nuevo, pack de sonidos.
- Herramientas: SDK/plantilla de mod, tools/validate_mod.gd, documentacion docs/MOD_SYSTEM.md, navegador de mods en el menu VR, panel de depuracion (consola, spawn de items/NPC, tiempo, toggle de gore/IA) = prioridad baja pero prevista.
## Fase 2 — Armas ultra realistas (como mods internos: validan la API)
Balistica real (calibre, masa, velocidad, arrastre, penetracion/rebote por material), mecanica (encasquillado, expulsion, inspeccion, desmontaje), accesorios (silenciador, mira, cargador), tipos de municion, retroceso fisico y haptica ya existentes, sonido por capas y distancia (A1), mas armas (revolver, cuchillos, granadas) con modelos DESCARGADOS.
## Fase 3 — Heridas y gore de otro nivel (cuando fase 1 y 2 sean solidas)
3a Modelo de tejido en capas por region (piel/grasa/musculo/hueso) con salud propia + shader de capas reveladas por mascara + decals de herida; sangrado y rastro.
3b Cortes de malla: miembros pre-cortados con tapas de carne/hueso; desmembramiento progresivo (no instantaneo).
3c CUCHILLO: la hoja se sigue con la mano; apuñalar = penetracion segun profundidad de colision, hoja clavada (joint) con friccion; serrar = progreso de corte por movimiento a lo largo del filo que agranda la herida y cambia las capas visibles (piel -> carne -> hueso); poder arrancar/mochar una extremidad; animaciones de NPC reactivas.
Limites: presupuesto Quest (niveles de gore y topes), no inventar sin base solida; se prototipa en desktop-quality con perfiles.
## Fase 4 — Graficos y mundo
PBR, iluminacion dia/noche, linterna, clima, mapas reales descargados (Kenney ya), edificios con interiores, oclusion, LOD, MultiMesh; revisar errores graficos que reporte el usuario.
## Fase 5 — Juego y comunidad
Supervivencia por oleadas, objetivos, recogidas, puntuacion en la muñeca, confort VR (giro por pasos, viñeta, sentado), ajustes 3D; distribucion de mods (carpeta user://mods, descarga por URL/GitHub), versiones y compatibilidad.
## Fase 6 — Despues
Decoracion y pulido, cooperativo en linea, logros, modo creativo.
