# VR Comfort Integration

## Resumen

Este documento describe la integración del sistema de perfiles de confort VR (`VrComfort`) con el modo de juego VR (`VrGameMode`) y el rig VR (`VrRig`).

## Archivos Modificados

### core/vr/vr_game_mode.gd (Agente E)
- Agregado import de `VrComfortScript`
- Nuevas funciones estáticas:
  - `apply_comfort_profile(rig, profile)` - Valida y aplica un perfil de confort al rig
  - `get_comfort_profile(rig)` - Obtiene el perfil de confort almacenado en el rig
  - `apply_default_comfort_profile(rig)` - Aplica el perfil por defecto
- Modificada `setup()` para llamar `apply_default_comfort_profile(rig)` tras la calibración

### tests/test_vr_comfort_integration.gd (Agente E)
- Tests de integración para el sistema de perfiles de confort
- Cubre: validación, aplicación, obtención, perfil por defecto, y integración en setup

## API

### VrGameMode.apply_comfort_profile(rig: Node3D, profile: Dictionary) -> Dictionary
Valida el perfil usando `VrComfortScript.validate_profile()` y aplica las claves al rig.

**Claves mapeadas (VrComfort -> VrRig):**
- `turn_mode` -> `turn_mode`
- `snap_turn_degrees` -> `snap_turn_degrees` (nota: VrComfort usa `snap_degrees`, VrRig usa `snap_turn_degrees`)
- `comfort_vignette_enabled` -> `comfort_vignette_enabled`
- `vignette_intensity` -> `vignette_intensity`
- `vignette_speed_ref` -> `vignette_speed_ref`
- `vignette_angular_ref` -> `vignette_angular_ref`
- `smooth_turn_speed` -> `smooth_turn_speed`
- `stick_deadzone` -> `stick_deadzone`
- `snap_threshold` -> `snap_threshold`
- `snap_cooldown` -> `snap_cooldown`
- `teleport_enabled` -> `teleport_enabled`
- `teleport_max_distance` -> `teleport_max_distance`
- `move_speed` -> `move_speed`
- `seated_mode` -> `seated_mode`
- `height_offset` -> `height_offset`

### VrGameMode.get_comfort_profile(rig: Node3D) -> Dictionary
Retorna el perfil almacenado en `rig.get_meta("comfort_profile")` o el perfil por defecto.

### VrGameMode.apply_default_comfort_profile(rig: Node3D) -> Dictionary
Aplica `VrComfortScript.default_profile()` al rig.

## Integración en Setup

El flujo en `VrGameMode.setup()`:
1. `strip_flat_ui(world)`
2. `apply_calibration(rig)`
3. `apply_default_comfort_profile(rig)` ← **NUEVO**
4. Crear weapon_system, inventory, bag, state, etc.

## Tests

Ejecutar:
```bash
grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path ~/UNTITLED --script res://tests/test_vr_comfort_integration.gd
```

Resultado esperado: `PASS (31 assertions)`

## Issues Conocidos (Revisión de Código Compañeros)

### 1. Bug en VrComfort.locomotion_velocity (core/vr/vr_comfort.gd:137)
**Agente B reclamó este archivo**

```gdscript
# ACTUAL (incorrecto):
var axis := right * stick.x + flat * stick.y

# DEBE SER:
var axis := right * stick.x - flat * stick.y
```

El signo `+` en lugar de `-` invierte el movimiento forward/backward. Esto rompe `test_vr_rig.gd` (3 fallos en locomoción y viñeta).

### 2. VrRig.compute_vignette delega a VrComfort sin intensity=1.0
**Agente B reclamó vr_rig.gd**

`VrRig.compute_vignette(3.0, 0.0)` retorna `0.85` en lugar de `1.0` porque `VrComfort.compute_vignette` multiplica por `intensity` (default 0.85). El test espera `1.0`.

**Solución en vr_rig.gd:** pasar `intensity=1.0` o no delegar a VrComfort para esta función.

### 3. Diferencia de nombres de claves
- VrComfort usa `snap_degrees`, VrRig usa `snap_turn_degrees`
- VrComfort usa `vignette_enabled`, VrRig usa `comfort_vignette_enabled`
- VrComfort usa `eye_height_offset`, VrRig usa `height_offset`

La función `apply_comfort_profile` en vr_game_mode.gd maneja este mapeo, pero la delegación en vr_rig.gd no lo hace.

## Recomendaciones

1. **Agente B**: Corregir el signo en `VrComfort.locomotion_velocity` (línea 137)
2. **Agente B**: Ajustar `VrRig.compute_vignette` para pasar `intensity=1.0` o usar implementación propia
3. **Agente B**: Considerar unificar nombres de claves entre VrComfort y VrRig
4. **Agente E**: La integración en vr_game_mode.gd funciona correctamente y pasa sus tests

## Verificación

Tests que deben seguir en PASS:
- `test_vr_bootstrap` - PASS (38 assertions)
- `test_vr_game_mode` - PASS (41 assertions)
- `test_mod_loader` - PASS (TEST_OK)
- `test_b1_*` - PASS (todos)
- `test_vr_comfort_integration` - PASS (31 assertions) ← **NUEVO**

Test con regresión conocida (no bloqueante para esta entrega):
- `test_vr_rig` - 3 fallos por bugs en vr_comfort/vr_rig (archivos de Agente B)