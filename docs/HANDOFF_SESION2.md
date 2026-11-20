# HANDOFF SESION 2 (2026-11-20) — LEER PRIMERO si la sesion se cierra o el entorno se elimina

Complementa a HANDOFF.md, CHARTER.md y ROADMAP.md. Este archivo es lo mas reciente. Sin claves: nunca las escribas en el repo (se sube a GitHub).

## 0. Estado actual (el usuario pidio PARAR)
- El usuario pidio cerrar todos los procesos y NO HACER NADA hasta su aviso ("reiniciare"). Procesos cerrados: sched.sh, memguard.sh, autopilot.sh y agentes OpenCode.
- Al volver: preguntar o esperar su aviso; despues empezar por la seccion 3 (bugs graves).
- Mencion: "activare la rama plus" y "mi celular para la rama plus" — no esta claro si es una rama git, un plan de pago o modo de ejecucion. PREGUNTAR en una linea antes de asumir.

## 1. Lo que quiere el usuario (prioridades)
1. ARREGLAR YA (P0): en la ultima version que jugo, varios modelos 3D de AK-47 estaban tirados/parados por el mapa, NO podia agarrar armas y los NPC NO se movian. Ademas, al iniciar el juego y cerrarlo, NO podia volver a abrirlo (crasheaba). Es el "segundo arranque VR no reproducido" de HANDOFF.md: reproducirlo y corregirlo (revisar estado persistente/user://, recursos duplicados al spawnear, escenas que se instancian dos veces, cierre limpio del XR).
2. ACTUALIZADOR DENTRO DEL JUEGO (U1): al abrir debe consultar la ultima version (GitHub Releases, tag vr-latest o releases de la rama), mostrar "Actualizacion disponible" y poder descargar e instalar el APK (en Android el instalador requiere permiso de "instalar apps desconocidas"; en Quest abrir el APK descargado/sideload). Compara version del juego con la del release; sin red debe fallar en silencio.
3. Resto de la vision: sandbox VR ultra realista y moddable, gore por capas, voces NPC, vehiculos, armas ultra realistas, Fase 1 moddable (D1-D3), M2 modos, V3 confort VR, R3 gore v2, R4 rendimiento. Ver CHARTER/ROADMAP/IDEAS_APROBADAS.
4. VR (Quest) = plataforma principal; Android = pruebas; PC despues. No afirmar que VR funciona sin probarlo en casco.

## 2. Como quiere que trabaje el agente
- Respuestas CORTAS, sin relleno. Trabajar en silencio; no reportar avances hasta que lo pida (salvo bloqueos).
- Permiso total para ejecutar comandos, monitorear, instalar, borrar memoria/procesos propios. Excepcion: NO cerrar Termux, Claude ni TikTok. No borrar claves ni configuraciones del usuario sin respaldo (ver errores).
- Ahorro de tokens de CLAUDE: Claude solo orquesta y verifica; los agentes de OpenCode son los "esclavos" y pueden gastar sin limite (no hay limite de uso para ellos). Prefijar comandos con `rtk`.
- Nunca crashear el celular: 7.3 GB RAM. Cada agente OpenCode ~430 MB. Maximo 2 agentes simultaneos (3 si hay >1800 MB libres y swap <2800 MB). sched.sh ya respeta esto; memguard.sh libera procesos propios y pausa agentes si MemAvailable <700 MB.
- IDEA NUEVA del usuario (enjambre): en vez de repartir carpetas distintas, que VARIOS modelos trabajen sobre UNA misma tarea, se revisen entre si, busquen errores, comparen y mejoren, y asi sucesivamente, para terminar las etapas mas rapido y mejor. Diseño acordado: 1 agente OpenCode implementa la tarea; luego TODOS los modelos disponibles la revisan en paralelo por llamadas curl a la API (casi sin RAM) con `~/untitled-control/swarm_review.sh <tarea> [ronda]` (escribe reviews/<tarea>/rN/_todos.md; sin probar aun); luego un agente consolida y corrige; repetir hasta sin hallazgos graves. Los revisores NO deben ser procesos OpenCode (RAM).

## 3. Plan inmediato sugerido
1. Reproducir headless el bug P0 (armas tiradas/duplicadas, no agarrables, NPC inmoviles, crash en 2.o arranque): `grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path ~/UNTITLED --script res://tests/NOMBRE.gd`. Escribir un brief B1 (UNTITLED/briefs/C8_B1_*.md) y lanzarlo con OpenCode; luego pasar swarm_review.sh.
2. Brief U1 (actualizador).
3. Terminar cola pendiente: M2_gamemodes, V3_vrcomfort, D3a_modtools, D3b_debugdocs (briefs C7_D3a_modtools.md y C7_D3b_debugdocs.md ya creados; D3 original C7_D3_modtools.md), R3_goreV2, R4_perf. Estado de lo que alcanzaron a escribir: SIN VERIFICAR. Verificar con tests antes de aceptar. Hay muchos archivos modificados sin commit en ~/UNTITLED (rama feature/mod-system; el remoto usa main).
4. Despues de cada entrega: verificar, commit, push, esperar CI (APK en GitHub Releases vr-latest y /sdcard/Download/untitled_vr_debug.apk).

## 4. Proveedores de modelos (OpenCode)
- El modelo gratis de OpenCode (big-pickle y otros opencode/*-free) llego a "Free usage limit reached": NO usarlos. Ya no sirven.
- NVIDIA (API tipo OpenAI, https://integrate.api.nvidia.com/v1): hay DOS claves, guardadas en:
  - Clave 1 -> proveedor `nvidia`: ~/.local/share/opencode/auth.json. Acepta moonshotai/kimi-k3.1-pro por curl, pero DENTRO de OpenCode kimi da "UnknownError": no usarlo con OpenCode (si se usa, por curl directo).
  - Clave 2 -> proveedor `nvidia2`: ~/.config/opencode/opencode.json (copia en opencode.json.bak). Acepta 13 modelos (200): mistralai/mistral-large-4-1t-a52b (DEFECTO), nvidia/nemotron-3-ultra-550b-a55b, minimaxai/minimax-m3.1-flash (small_model), stepfun-ai/step-5-preview, google/gemma-4-31b-it, meta/muse-glimmer-30b, poolside/laguna-xs-2.1, nvidia/nemotron-3.5-super-vl-120b-a12b y otros.
- Las claves se pasaron por el chat; recomendar rotarlas. El listado /v1/models es publico y NO prueba que la clave sirva: probar con /chat/completions. Muchos modelos viejos dan 410 (retirados) y otros 403 (sin acceso).
- Usa `opencode run -m nvidia2/<modelo> "..."`; launch7.sh usa el modelo por defecto del config.

## 5. Errores/trampas encontrados en esta sesion (no repetir)
1. OpenCode se colgaba SIN salida: el directorio ~/.local/share/opencode/snapshot estaba corrupto ("not a git repository"). Solucion: moverlo (no borrar) a snapshot.bak-*; opencode volvio a funcionar.
2. `pkill -f <patron>` mata tu propia shell de Bash si el patron aparece en la linea de comandos (exit 143/144). Usar `ps -eo pid,args | grep ... | grep -v grep` y kill por PID, o patrones que no se auto-coincidan.
3. SOBREESCRIBI la entrada `nvidia` de auth.json sin respaldo (habia una clave previa del usuario, se perdio). Regla: SIEMPRE copiar el archivo antes de modificar credenciales/config del usuario. El usuario dijo "ojo no la elimines": no borrar claves.
4. Una clave pegada con un caracter mal (0 vs O al final) dio 403 en todo; comparar caracteres y probar la clave tal como la pega el usuario antes de concluir que esta revocada.
5. Un subagente Sonnet lanzado para D3 quedo cancelado al interrumpir; no asumir que sigue vivo, comprobar con ls de los archivos creados.
6. Tras reinicio del contenedor mueren los procesos: relanzar con `cd ~/untitled-control && : > sched.log && setsid nohup bash sched.sh </dev/null >/dev/null 2>&1 &` y memguard.sh igual. Los exit codes de las tareas estan en ~/untitled-control/cycle2/<tarea>.exit.
7. Desde Termux solo se ven y cierran procesos del propio usuario (sin root): no se puede liberar RAM de otras apps; pedir al usuario que cierre apps a mano.
8. Mensajes del usuario como "nira tengo una idea... esperame... no hagas nada" significan PARAR y esperar; no seguir lanzando trabajo.

## 6. Archivos clave
- ~/UNTITLED/docs: CHARTER, ROADMAP, HANDOFF (anterior), este archivo, MASTER, MOD_SYSTEM, VR_BUILD, IDEAS_APROBADAS, CONTEXTO_SESION.
- ~/untitled-control: sched.sh (cola, QUEUE=), launch7.sh (lanza un brief por tarea), memguard.sh, swarm_review.sh, autopilot.sh (espera cola vacia, finish_vr.sh, commit, push, CI), cycle2/ (logs y .exit), sched.log, memguard.log.
- Briefs: ~/UNTITLED/briefs/C6_*.md, C7_*.md. Copias de docs en /sdcard/Documents/UNTITLED_*.md.
