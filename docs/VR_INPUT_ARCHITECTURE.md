# Interacción VR: mandos y Hand Tracking (beta jugable)

Estado: diseño verificado en documentación. No verificado en hardware. Ninguna función de este documento está "terminada" hasta ejecutarse en un Meta Quest 3S.

## 1. Hechos verificados (fuentes oficiales)
- Godot: el hand tracking usa XRHandModifier3D (bajo Skeleton3D) y XRHandTracker, sobre la extensión OpenXR de hand tracking. No hace falta plugin de proveedor para el caso básico. Fuente: https://docs.godotengine.org/en/stable/tutorials/xr/openxr_hand_tracking.html
- Godot 4.7: la extensión de hand tracking viene activada por defecto por compatibilidad. Si la beta es solo mandos, desactivarla. Fuente: https://docs.godotengine.org/en/4.7/tutorials/xr/openxr_settings.html
- OpenXRHand está deprecado; usar XRHandModifier3D. Fuente: https://docs.godotengine.org/en/stable/classes/class_openxrhand.html
- Quest 3S: las muestras de Meta listan Quest 3 y 3S para hand tracking con XR_EXT_hand_tracking. El usuario debe activarlo en Ajustes > Seguimiento de movimiento. Fuente: https://developers.meta.com/vr/documentation/native/android/move-body-tracking/ (referencia de requisitos)
- Quest 3 (no 3S): compatible por la misma familia, pero no verificado en este proyecto.
- Body tracking (Movement SDK) es OTRA tecnología. No se usa en la beta. Requiere permiso BODY_TRACKING y plugins que el Movement SDK documenta como incompatibles con el plugin OpenXR estándar. Fuera de alcance.

## 2. Arquitectura: una sola interfaz de interacción
Capa de entrada (`core/vr/input_source.gd`, nueva):
- `InputSource` (interfaz): `get_pose(hand)`, `is_pressed(action)`, `is_tracking(hand)`, `get_joint(hand, joint)`.
- `ControllerSource`: implementa la interfaz con XRController3D (botones Touch: grip, trigger, A/B).
- `HandSource`: implementa la interfaz con XRHandTracker. Gestos (pellizco, puño) se calculan por distancia entre articulaciones con umbrales configurables.
- Acciones del juego: `grab`, `release`, `trigger`, `switch_tool`, `interact`. Ambas fuentes producen las mismas acciones.

Mods: pueden registrar gestos y mapeos con la API del núcleo (`register_gesture`, `bind_action`), y sustituir una `InputSource` completa. El permiso `input.read` gobierna si un mod puede leer entradas.

## 3. Cambio entre modos
- Detección: si `has_tracking_data` es falso durante N segundos y hay mandos activos, cambiar a ControllerSource; si las manos reaparecen, volver a HandSource.
- Un cambio nunca suelta un objeto agarrado sin aviso: se mantiene el agarre hasta que la fuente pierda la pose de forma sostenida.

## 4. Pérdida y recuperación de tracking
- Mientras no hay datos: congelar la última pose conocida y no procesar gestos.
- Tras un umbral (p. ej. 0,5 s), soltar objetos agarrados por mano.
- Al recuperar datos: reanudar sin saltos (interpolación corta).

## 5. Rendimiento
- Actualizar al ritmo del tracker; no asignar arrays de articulaciones por fotograma (reutilizar buffers).
- Usar `bone_update` solo rotación para la malla de manos, salvo que se necesite tamaño real.

## 6. Plan de fases (cada una debe ejecutarse)
| Fase | Entregable ejecutable | Prueba |
|---|---|---|
| V1 | Escena XR con XROrigin3D, cámara y mandos visibles | Headless sin XR: la escena carga. En Quest: se ve el origen. |
| V2 | Agarrar y soltar con mando (grip) | Prueba con fuente simulada; en Quest: objeto sigue la mano. |
| V3 | Agarre con dos manos | Prueba de distancia; en Quest: objeto orientado entre ambas manos. |
| V4 | Primera arma: disparo con trigger y pellizco | Prueba de raycast; en Quest: disparo y eco visual. |
| V5 | HandSource con pellizco como grip | Prueba con articulaciones simuladas; en Quest: pellizco agarra. |
| V6 | Cambio entre mandos y manos y pérdida de tracking | Prueba del temporizador; en Quest: quitar mandos y ver el cambio. |

## 7. Bloqueos actuales
- **Sin Quest conectado:** no hay `adb` ni emparejamiento. Hasta tenerlo, V1–V6 solo se prueban con fuentes simuladas.
- **Sin exportación XR:** la extensión OpenXR no está activa en el proyecto principal (decisión de Fase B).
- Por eso ninguna fase de hardware puede darse por terminada todavía.

## 8. Siguiente paso recomendado
Con el resultado de la auditoría de VR (`docs/VR_SLICE_AUDIT.md`), lanzar V1 y V2 a OpenCode, con fuentes simuladas, y dejar V3–V6 como fases de hardware con criterio de aceptación explícito.
