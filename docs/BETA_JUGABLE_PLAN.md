# Beta jugable VR + Android: plan por fases

Regla: ninguna fase está terminada sin ejecución real. "Simulado" = probado con entradas simuladas en headless. "Hardware" = probado en Meta Quest 3S o S25 FE.

## Decisiones aprobadas (vigentes)
- **D-P1 Permisos por defecto denegados.** ModApi deniega toda llamada que no esté en los permisos declarados. Ningún permiso se concede globalmente. Cada mod declara sus permisos en mod.json.
- **D-P2 Validación previa.** Los permisos se validan antes de cargar y ejecutar el mod. Un permiso faltante produce un error claro con el nombre del permiso y el mod afectado; el mod no se carga.
- **D-P3 Migración.** Los mods existentes sin campo `permissions` quedan desactivados hasta declararlos. Se documenta la migración en docs/MOD_MIGRATION.md.
- **D-P4 Ampliación autorizada.** Los mods amplían sistemas mediante APIs y capacidades declaradas explícitamente.
- **D-P5 Quest 3S.** Sin conexión ADB por ahora. Desarrollo con simulación, pruebas automatizadas y validación de escritorio. Las pruebas físicas se harán al conectar el Quest.
- **D-P6 Alcance de la beta.** Prioridad: calibración, locomoción VR, inventario genérico, interacción física, NPCs y compatibilidad con mods. Combate fuera de alcance en esta iteración.
- **D-P7 Orden de trabajo.** No se lanzan implementadores que toquen archivos de V1/V2 o B.1 mientras estén activos. Fase 1 empieza cuando terminen esos trabajos. Claude supervisa y revisa decisiones; OpenCode implementa.

## Dependencias
- Fase 0 (ya en curso): B.1 (runtimes Lua/WASM) y V1/V2 (escena XR y agarre con mando).
- Fase 1 depende de V1/V2. Fase 2 depende de 1. Fases 3–5 dependen de 2.

## Fases
| Fase | Contenido | Verificación en simulado | Verificación en hardware |
|---|---|---|---|
| 1. Calibración y perfil | Postura, altura, alcance, altura de bolsillos, comprobación de manos, recalibración, persistencia en user:// | Persistencia tras reinicio del proceso (test) | Quest 3S: calibración completa y reinicio |
| 2. Inventario y bolsillos | Slots (bolsillo izq/der, espalda, arma larga, pequeños), guardar/extraer por zona, lista persistente | Test de guardar/extraer/persistir con zonas simuladas | Acercar mano a zona y extraer |
| 3. Locomoción una mano | Gesto, velocidades lenta/normal/correr, rampa de aceleración, anti falsos positivos, cambio de mano, cabeza define dirección | Test de gesto simulado y curva de velocidad | Caminar con una mano sosteniendo arma con la otra |
| 4. Armas y munición | Extraer/guardar armas, 1 o 2 manos, recoger del escenario, cambio sin menú; munición ilimitada y limitada con cargadores | Test de estado de munición y recarga | Disparar, recargar, cambiar arma |
| 5. Mods de los sistemas | Mods que añaden objetos, armas, categorías, zonas, reglas, modo de munición, gestos y perfiles de calibración | Mod de ejemplo que añade un arma y una zona | Solo si la fase 4 está en hardware |
| 6. Android táctil | Mismos sistemas con controles de pantalla | Test de entrada táctil simulada | S25 FE: toque real |

## Decisiones previas que bloquean fases
1. **Permisos por defecto de ModApi** (concede todo si no hay permisos declarados). Afecta a mods de todas las fases 5. Pendiente de decisión.
2. **Hardware:** el Quest 3S no está conectado (sin adb). Las fases "Hardware" quedan bloqueadas hasta conectarlo. Las demás pueden avanzar en simulado.
3. **Hand tracking como locomoción:** el gesto debe calibrarse en el casco. Sin Quest, solo se puede validar la lógica.

## Riesgos
- Falsos positivos de gesto: se mitigan con umbral de duración y de amplitud, configurables por mod.
- Coste de tracking: solo consultar articulaciones del tracker activo (ver docs/VR_INPUT_ARCHITECTURE.md).
- Compartir inventario entre VR y Android: la lógica va en core/, la presentación por plataforma.
