# Auditoría de Infraestructura de IA/NPCs

| Punto | Estado | Referencia | Tarea Mínima Faltante |
| :--- | :--- | :--- | :--- |
| 1. Sistemas IA/NPC | FALTA | `PROJECT_STATUS.md:7` | Implementar NavigationAgent3D y State Machine base. |
| 2. Escenas Interiores | FALTA | `PROJECT_STATUS.md:7` | Crear escena de edificio/hotel con geometría básica. |
| 3. Sistema de Mods | EXISTE | `core/mod_registry.gd:118` | Integrar carga de escenas (.tscn) vía PCK en ModRegistry. |
| 4. Dependencias IA | PARCIAL | `core/event_bus.gd:1` | Definir eventos de señalización IA en ModEventBus. |
| 5. Restricciones Beta | PARCIAL | `BETA_JUGABLE_PLAN.md:10` | Definir budget de CPU/Memoria para NPCs en Quest 3S. |

## Orden Recomendado de Tareas (IA Jugable)
1. **Geometría**: Crear escena de interior simple (Hotel/Edificio).
2. **Navegación**: Configurar `NavigationRegion3D` y `NavigationAgent3D` en la escena.
3. **NPC Base**: Crear escena de NPC con `CharacterBody3D` y State Machine básica.
4. **Rutinas Civiles**: Implementar lógica de puntos de interés (Waypoints) y tiempos de espera.
5. **Lógica Hostil**: Implementar percepción (RayCast/Area3D) y persecución simple.
6. **Integración Mods**: Permitir que un mod defina el comportamiento del NPC vía `ModApi`.
7. **Optimización**: Ajustar límites de updates de IA para mantener 60 FPS en S25 FE / Quest 3S.
