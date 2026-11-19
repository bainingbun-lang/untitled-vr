| Punto | Estado | Referencia | Tarea Mínima |
|---|---|---|---|
| 1. Escena VR | FALTA | - | Crear escena con XROrigin3D y configurar OpenXR |
| 2. Movimiento/Interacción | FALTA | - | Implementar locomoción y controladores VR |
| 3. Primera Arma | FALTA | - | Crear modelo, sistema de disparo raycast y cargador |
| 4. Escenario Jugable | FALTA | - | Diseñar entorno básico navegable en VR |
| 5. Carga de Mod | EXISTE | core/mod_registry.gd:106 | Crear mod VR que use ModApi para modificar VR |

**Dependencias:** 1 $\rightarrow$ 2 $\rightarrow$ 4 $\rightarrow$ 3 $\rightarrow$ 5

**Orden recomendado:**
1. Configurar XROrigin3D y cámara VR.
2. Implementar locomoción y agarre.
3. Montar escenario básico.
4. Implementar arma y disparo.
5. Integrar funcionalidad de arma mediante el sistema de mods.
