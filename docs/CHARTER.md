# CHARTER — vision y reglas estrictas de UNTITLED (LEER PRIMERO; sustituye a leer la conversacion)
## Vision (palabras del usuario)
Sandbox FPS en VR **extremadamente realista y moldeable**. **Todo es modificable por mods de la comunidad** (armas, items, NPC, mapas, sonidos, gore, reglas). El sistema de mods es PARTE DEL NUCLEO y se construye desde ya, no al final. Plataforma principal: Meta Quest (OpenXR); Android/PC secundarios. Primero una base solida; despues decoraciones y contenido.
## Pilares
1. Armas ultra realistas (balistica real, mecanica, recarga manual, retroceso fisico, accesorios, sonido por capas).
2. Gore y heridas a otro nivel: tejido en capas (piel, grasa, musculo, hueso), heridas progresivas, cuchillo (apuñalar, clavar, serrar con friccion, cortar extremidades), desmembramiento. Se disenara cuando la base este solida (ver ROADMAP fase 3).
3. Graficos realistas dentro del presupuesto de Quest (72/90 Hz).
4. Moldeable: todo dato-dirigido + API de mods + herramientas (SDK, validador, panel de depuracion).
## REGLAS ESTRICTAS (no negociables)
- Modelos 3D, texturas y sonidos se DESCARGAN con licencia CC0/MIT/CC-BY (registro en assets/CREDITS.md). NUNCA crear modelos con primitivas ("no cuadros ni circulos"). Excepcion: efectos procedurales (sangre, particulas, decals).
- Honestidad: separar Implementado / Compilado / Probado / Verificado / Integrado. Nada se dice funcionando en casco sin que el usuario lo pruebe. Verificar cada entrega con tests propios: grun, sin 'SCRIPT ERROR', con 'PASS (N assertions)' (Godot devuelve exit 0 aunque no compile). Un APK se compila solo con el arbol estable (tools/check_compile.gd => bad=0).
- Ahorro de tokens: el usuario esta al limite de cuota. Claude = orquestador/verificador, respuestas cortas, SIN informes largos ni avisos innecesarios; trabajar en silencio y automatizar (sched.sh, autopilot.sh, CI). La programacion la hacen agentes OpenCode; Claude solo arregla cosas pequeñas o criticas. Maximo UN subagente Sonnet y UN Opus (solo si de verdad hace falta). NO pedir permiso (permiso total concedido).
- Seguridad del telefono: 7 GB RAM + 4 GB swap; sobrecargar => el contenedor se reinicia y mata los procesos. Planificador: MAX 2-3 agentes, no lanzar con swap>3400 MB ni con Gradle activo. Godot limitado a 2 procesos por ~/.local/bin/grun.
- Modificacion segura: no editar sched.sh/launch7.sh con ellos corriendo; no pkill -f con texto presente en el propio comando; agentes con archivos disjuntos; nunca compilar un APK mientras un agente edita archivos.
- Mods: todo contenido nuevo debe poder expresarse como dato/mod (manifest, registry, eventos). No codificar contenido a fuego en el nucleo si puede ser un recurso.
- VR: sin HUD plano (informacion en el arma y la muñeca); una mano agarra y dispara, la otra solo ayuda a apuntar; recarga manual completa; sin sacudida de camara.
- Gore: respetar GameSession.gore_enabled y niveles (apagado/normal/extremo) y las politicas de plataforma (sideload ok; tiendas pueden restringir).
## Entrega y descarga
Repo privado https://github.com/bainingbun-lang/untitled-vr ; push a main => GitHub Actions compila el APK VR y lo publica en Releases (tag vr-latest). APK local: /sdcard/Download/untitled_vr_debug.apk.
