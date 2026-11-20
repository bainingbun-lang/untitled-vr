# Gore Modding API

This document describes how to create mods that interact with the gore system via ModHooks and ContentRegistry.

## Overview

The gore system emits events through ModHooks when blood, decals, puddles, parts, or dismemberments occur. Mods can subscribe to these events to add custom behavior (sound, particles, gameplay effects, etc.).

Gore profiles can be defined in mod manifests and loaded via ContentRegistry to customize gore limits and behavior.

## ModHooks Events

All gore events are registered in `ModHooks.EVENTS` and `EventBus.HOOK_EVENTS`.

### gore_blood_spawned
Emitted when blood particles are created (via `GoreFx.blood_hit` or `GoreFx.on_death`).

**Payload:**
```json
{
  "target": "instance_id_string",
  "position": Vector3,
  "normal": Vector3,
  "amount": float,
  "jet": bool
}
```

### gore_puddle_created
Emitted when a blood puddle is created (via `GoreFx.puddle` or `GoreFx.on_death`).

**Payload:**
```json
{
  "target": "instance_id_string",
  "position": Vector3,
  "normal": Vector3,
  "size": float
}
```

### gore_decal_created
Emitted when a blood decal is created (via `GoreFx._add_decal`, called from `blood_hit`, `on_death`, `dismember`).

**Payload:**
```json
{
  "target": "instance_id_string",
  "position": Vector3,
  "normal": Vector3,
  "size": float
}
```

### gore_part_created
Emitted for each gib piece created during dismemberment (via `GoreFx.dismember`).

**Payload:**
```json
{
  "target": "instance_id_string",
  "position": Vector3,
  "zone": "string",
  "size": float,
  "count": int
}
```

### gore_dismemberment
Emitted once per dismemberment event (via `GoreFx.dismember`).

**Payload:**
```json
{
  "target": "instance_id_string",
  "position": Vector3,
  "limb": "string",
  "severity": float,  // 0.0 - 1.0
  "piece_count": int
}
```

## Mod Manifest Example

```json
{
  "id": "my_gore_mod",
  "version": "1.0.0",
  "hooks": {
    "gore_blood_spawned": ["on_blood_spawned"],
    "gore_puddle_created": ["on_puddle_created"],
    "gore_decal_created": ["on_decal_created"],
    "gore_part_created": ["on_part_created"],
    "gore_dismemberment": ["on_dismemberment"]
  },
  "permissions": ["read_events"]
}
```

## Mod Script Example

```gdscript
extends RefCounted

var api

func on_blood_spawned(payload: Dictionary) -> void:
    print("Blood spawned at ", payload.position, " amount: ", payload.amount)
    # Add custom sound, particles, etc.

func on_puddle_created(payload: Dictionary) -> void:
    print("Puddle created size: ", payload.size)

func on_decal_created(payload: Dictionary) -> void:
    print("Decal created at ", payload.position)

func on_part_created(payload: Dictionary) -> void:
    print("Gib piece from zone: ", payload.zone)

func on_dismemberment(payload: Dictionary) -> void:
    print("Dismemberment: ", payload.limb, " severity: ", payload.severity)
```

## Gore Profiles

Mods can define gore profiles in their manifest under `content.gore_profile`:

```json
{
  "id": "my_gore_mod",
  "version": "1.0.0",
  "content": {
    "gore_profile": {
      "my_gore_mod:extreme": {
        "type": "gore_profile",
        "id": "my_gore_mod:extreme",
        "name": "Extreme Gore",
        "level": "extreme",
        "decal_limit": 100,
        "particle_limit": 200,
        "parts_limit": 20,
        "puddle_limit": 30
      }
    }
  }
}
```

Or load programmatically via `ContentRegistry.set_mod()`.

### Profile Schema

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| type | string | required | Must be "gore_profile" |
| id | string | required | Unique identifier |
| name | string | required | Display name |
| level | string | "medium" | "low", "medium", "high", "extreme" |
| decal_limit | int | 64 | Max decals (clamped to 64) |
| particle_limit | int | 32 | Max particles (clamped to 32) |
| parts_limit | int | 12 | Max gib parts (clamped to 12) |
| puddle_limit | int | 16 | Max puddles (clamped to 16) |
| audio_enabled | bool | true | Enable gore sounds |

### Applying a Profile

```gdscript
var registry = ContentRegistry.instance()
var profile = registry.definition("gore_profile", "my_gore_mod:extreme")
if not profile.is_empty():
    GoreFx.apply_profile(profile)
```

## Limits

All limits are clamped to engine maximums for mobile performance:
- Decals: 64 max
- Active particles: 32 max
- Puddles: 16 max
- Gib parts: 12 max

## Best Practices

1. **Use `read_events` permission** - Required to subscribe to gore events.
2. **Keep handlers fast** - Gore events fire frequently; avoid heavy computation.
3. **Pool resources** - Reuse particles/sounds instead of creating new ones.
4. **Respect limits** - Profile limits are clamped; don't assume your values will be used verbatim.
5. **Clean up** - Use `api._release()` when mod unloads to avoid leaks.

## Testing

Run the gore moddability test:
```bash
godot --headless --script res://tests/test_gore_moddable.gd
```

Expected: PASS (42 assertions)