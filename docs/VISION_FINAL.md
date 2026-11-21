# VISION FINAL — UNTITLED VR (dictada por el usuario; leer antes de decidir cualquier cosa)

Repositorio: https://github.com/bainingbun-lang/untitled-vr — se distribuye por GitHub (no Meta Store): APKs verificables (sha256), versiones identificadas, changelog y posibilidad de recuperar versiones anteriores.

Esto NO es una lista de lo que se implementa ya. Es el destino. Nada se da por terminado mientras falten partes importantes, y no se reduce la vision a un prototipo.

## Vision
- Sandbox VR profundo para Meta Quest: experimentar con armas, objetos, NPC, fisicas, mapas y mods. Mundo vivo: nada estatico ni decorativo; interacciones, comportamientos y respuestas fisicas coherentes.
- Calidad visual alta y realista: modelos buenos, materiales convincentes, iluminacion cuidada, animaciones naturales, escenarios con intencion artistica. NO una coleccion desordenada de recursos gratuitos ni un mapa de pruebas convertido en el juego.
- VR que aproveche Quest: controles naturales, inmersion, comodidad, rendimiento estable (optimizar sin excusarse para dejarlo pobre).

## Sistemas
- Armas fisicas e interactivas: agarre adecuado, recarga manual completa (cargadores, mecanismos), respuestas fisicas coherentes.
- NPC realistas: reaccionan al entorno, interactuan, actuan de forma convincente (no solo "se mueven"); no valen solo en pruebas simuladas.
- Mapas variados, detallados y de calidad; poder descargarlos, instalarlos y seleccionarlos. La oficina es un ejemplo, no el limite.
- Sandbox con herramientas de creacion y construccion cuando corresponda.
- Arquitectura ampliable: nuevos sistemas, mapas, armas, comportamientos y mods sin reconstruir desde cero.

## Mods
- Sistema profundo y flexible que pueda ampliar o modificar casi cualquier sistema.
- Administrador de mods en el propio Quest: instalar, actualizar, activar, desactivar, eliminar; dependencias e incompatibilidades.
- Contenido local sin internet; la conexion solo para descargar, compartir, actualizar.
- Guardados persistentes y automaticos con espacios independientes (mundos, cambios, experimentos).
- Futuro (sin desviar la prioridad): multijugador y modos con objetivos.

## Calidad final
- Graficos de alta calidad, fisicas convincentes, interacciones profundas, audio inmersivo, efectos bien integrados. Efectos de impacto, reaccion de materiales y deformaciones pueden llegar en el pulido final.
- Comodidad VR: giro, reduccion de mareo, altura y posicion, modos sentado y de pie.

## Prioridad actual y fases
- FASE A (ahora): una APK funcional, estable y suficientemente completa para que el usuario pruebe en el visor real controles, agarre de armas, movimiento, menus, NPC y sistemas principales. Luego el usuario entrega su informe.
- FASE B (despues del informe, no antes): calidad visual, mapas, fisicas e interacciones profundas, mods, y llevar el juego a la vision completa.
- No avanzar prematuramente a la Fase B sin las pruebas del usuario.

## Metodo de trabajo acordado (no cambiar)
- Claude coordina; OpenCode ejecuta. Todos los agentes disponibles en una unica tarea prioritaria; quien termina se incorpora a la siguiente tarea pendiente del mismo ciclo.
- Al completar una tarea, un agente hace la revision final (codigo, integracion, errores) y queda registrada; solo entonces se da por terminada.
- No repartir en tareas independientes, no dejar agentes inactivos con tareas pendientes, no interrumpir con informes innecesarios.
- El coordinador mantiene la secuencia activa, recupera agentes detenidos y sigue hasta terminar o hasta un bloqueo real.
- Nunca dar por probado en Quest lo que solo se compilo o simulo. No aceptar un simple "LISTO": exigir evidencia (compilacion limpia, salida de tests, quien llama a lo nuevo).
