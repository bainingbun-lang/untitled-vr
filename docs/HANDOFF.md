# HANDOFF — para el siguiente Claude (tras /clear). Lee: CHARTER.md, ROADMAP.md, este archivo; luego solo lo que necesites.
## Prompt de arranque (pegar)
"Continuas UNTITLED (Godot 4.7, VR Quest). Lee ~/UNTITLED/docs/CHARTER.md, ROADMAP.md y HANDOFF.md (copias en /sdcard/Documents/UNTITLED_*.md). Respuestas cortas, ahorra tokens, permiso total. Eres orquestador/verificador; programan agentes OpenCode (cola ~/untitled-control/sched.sh; reanudar tras reinicio con: cd ~/untitled-control && : > sched.log && setsid nohup bash sched.sh </dev/null >/dev/null 2>&1 &). Pregunta al usuario solo lo imprescindible."
## Estado (2026-11-20 ~22:00)
- Verificado headless: mods, mapas (Kenney, oficina), NPC IA (ArmedNpc existe), inventario, armas/balistica/gore v1, VR (rig, bootstrap OpenXR, manos, calibracion, onboarding, recarga manual, retroceso+haptica, vehiculos, action map, escala/entorno corregidos), coches Kenney, armas v2 + manos descargadas.
- APK VR corregido publicado en GitHub Releases vr-latest y en /sdcard/Download/untitled_vr_debug.apk (sha 1819f293...). El usuario lo probara cuando cargue su Quest y reportara por foto/video (analizar con ffmpeg: contact sheet de fotogramas y leer la imagen).
- Pendiente en cola: I1 (NPC vivos: hoy son maniquies), K1 (coches en el mundo), A1 (audio real), N1 (animaciones). Briefs sin lanzar listos: M2 (modos/supervivencia), V3 (confort), R3 (gore v2), R4 (rendimiento) en UNTITLED/briefs. autopilot.sh (en ejecucion o relanzar): espera COLA VACIA, corre finish_vr.sh, hace commit/push y espera el CI.
- Riesgos conocidos: nada probado en casco; segundo arranque VR no reproducido; el APK local y el de CI deben salir de un arbol estable.
## ACTUALIZACION 22:10 (leer esto primero)
- Usuario APROBO las 40 ideas (docs/IDEAS_APROBADAS.md); facciones = modo RP aparte. Va a hacer /clear: todo debe estar en docs. Su cuota semanal va al ~23% y la ventana de contexto se llena rapido: SER BREVE.
- Cola automatica (sched.sh): I1_aiworld, K1_carsworld, A1_realaudio, N1_animation y luego D1_datadriven -> D2_modevents -> D3_modtools (Fase 1 moddable). autopilot.sh (relanzar si no corre: bash ~/untitled-control/autopilot.sh en segundo plano) espera COLA VACIA, ejecuta finish_vr.sh, commit, push y espera el CI.
- Briefs sin encolar listos: M2_gamemodes, V3_vrcomfort, R3_goreV2, R4_perf (encolar segun el roadmap).
- Si el contenedor se reinicia: relanzar sched.sh y autopilot.sh (ver prompt de arranque). Verificar cada entrega con sus tests antes de aceptarla.
## Siguiente paso recomendado
1) Esperar reporte del usuario del APK (graficos/controles). 2) FASE 1 del ROADMAP: nucleo moddable dato-dirigido (crear brief C7_*). 3) Continuar con fases 2-3 en orden.
## Documentos
CONTEXTO_SESION.md (trampas del entorno, detalle largo), RECUPERACION_TOTAL.md y PROMPTS_Y_SCRIPTS.md (todos los briefs y scripts), GAME_CONTRACT.md (interfaces), VR_BUILD.md, MOD_SYSTEM.md, assets/CREDITS.md.
