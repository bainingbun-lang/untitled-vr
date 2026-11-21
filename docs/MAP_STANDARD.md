# Estándar de Mapas (MAP_STANDARD)

## Resumen
Este documento define los estándares técnicos y de calidad para la generación de mapas en el proyecto. Todos los mapas deben cumplir estos requisitos para garantizar rendimiento en Quest (72 FPS), compatibilidad móvil y calidad de juego.

---

## 1. Presupuesto de Rendimiento (Mobile/Quest)

| Métrica | Límite | Notas |
|---------|--------|-------|
| Build time | ≤ 2500 ms | Tiempo total de generación del mapa |
| Node count | ≤ 800 | Nodos totales en WorldGeometry |
| Draw calls | ≤ 150 | Estimado por MeshInstance3D visibles |
| Triángulos/scena | ≤ 50,000 | Total triangles renderizados |
| Texturas | ≤ 1024 px | ASTC comprimido, max dimension |
| Props por mapa | ≤ 6 | physics_props (RigidBody3D) |
| Obstáculos | ≤ 8 | StaticBody3D con colliders simples |

### Per-Frame
- **0 allocations** por frame en gameplay
- **No dynamic lights** por disparo/arma
- **Culling distance** configurable por VrPerformance

---

## 2. Convención Geométrica

```
1 celda = 1 unidad * scale
grid[y][x] -> world (x+0.5, 0, y+0.5)
Suelo caminable: y=0 (BoxShape3D 0.5 grosor, centrado en y=-0.25)
boundaries.min/max definen rectángulo jugable + 1.0 margen para spawns
```

### Coordenadas
- **Origen**: esquina inferior-izquierda del bounds
- **Y-up**: altura positiva hacia arriba
- **Escala**: 1.0 = 1 metro por celda (configurable via `meta.scale`)

---

## 3. Temas Soportados

| Tema | Paleta | Vegetación | Cercas | Coches | Props típicos |
|------|--------|------------|--------|--------|---------------|
| **urbano** | Concreto, ladrillo, metal | Árboles genéricos (pocos) | No | Sí (taxi) | Barriles, contenedores |
| **industrial** | Metal, concreto oxidado | Pinos | Sí (perímetro) | Sí (taxi) | Tanques, cajas metálicas |
| **rural** | Tierra, hierba, madera | Robles, arbustos | Sí (perímetro) | No | Rocas, cajas madera |

### Parámetros por tema (theme_density 0.55 default)
- `width` / `height`: 24x18 celdas (estándar)
- `obstacle_density`: 0.12
- `spawn_count`: 4 mínimo
- `time_of_day`: "dia", "atardecer", "noche"

---

## 4. Estructura de Salida (meta dict)

```gdscript
{
  "ok": true,
  "theme": "urbano|industrial|rural",
  "seed": int,
  "time_of_day": "dia|atardecer|noche",
  "scale": 1.0,
  "width": 24,
  "height": 18,
  "boundaries": {"min": Vector3, "max": Vector3},
  "spawn_points": [Vector3, ...],  # ≥4, en navmesh, clearance 1.5m
  "obstacle_cells": [Vector2i, ...],
  "grid": ["...#...", "..S....", ...],  # opcional
  "theme_data": {
    "buildings": [...],
    "props": [...],
    "streets": {...}
  },
  "has_navigation": true,
  "has_collisions": true
}
```

### Spawn Points (Requisitos)
- Mínimo 4 por mapa
- Todos en NavigationMesh (distancia < 0.5m)
- Clearance 1.5m radio sin colisiones
- Raycast suelo: hit en "Ground" o "Building*"
- Cero spawns en colisión o caída libre

---

## 5. Navegación

- **NavigationRegion3D** obligatorio (nombre "NavigationRegion")
- **NavigationMesh** baked con polígonos > 10
- **NavigationAgent3D** pathfinding funcional entre spawns
- Doorways y habitaciones planta baja marcadas como transitables
- Plantas superiores: interiores jugables con escaleras (fuera malla 2D NPC)

---

## 6. Colisiones y Física

| Tipo | Límite | Uso |
|------|--------|-----|
| TrimeshCollisionShape3D | 0 | Prohibido (costoso) |
| ConcavePolygonShape3D | ≤ 10 | Solo edificios complejos |
| Convex (Box/Sphere/Capsule/Cylinder) | Libre | Props, obstáculos, paredes |
| PrimitiveMesh visibles | 0 | Solo debug, nunca en build final |

### Physics Props (RigidBody3D)
- Grupo: `physics_props`
- Layer: 2, Mask: 1
- `can_sleep = true`, `sleeping = true` al spawn
- Meta: `surface` (metal/wood/concrete), `prop_kind`
- Visual: MultiMeshInstance3D (instancing, 1 draw call/tipo)
- Collider: Box/Cylinder simple, altura = collider height * 0.5 + 0.01

---

## 7. Vegetación

- **Árboles**: max 12, spacing 3.0m, margen 1.0m de bounds
- **Arbustos**: max 12, spacing 2.0m, escala 0.7
- **Sin interpenetración**: AABB global no intersectan entre sí
- **Tema rural**: roble (tree_oak), **industrial**: pino (tree_pineDefaultA), **urbano**: default
- Grupo: `vegetation` (para tests y culling)
- Culling distance: 80m (ajustable por VrPerformance)

---

## 8. Cercas

- **Temas**: rural, industrial (no urbano)
- **Modelo**: fence_simple.glb (nature kit)
- **Máx**: 20 secciones, spacing 1.0m, margen 0.5m
- **Ubicación**: perímetro bounds (4 lados)
- **Sin interpenetración**: AABB global no intersectan
- Grupo: `fence`
- Culling: 70m

---

## 9. Coches Aparcados

- **Temas**: urbano, industrial (no rural)
- **Modelo**: taxi.glb (car kit)
- **Máx**: 8 coches, spacing 3.5m
- **Distancia spawns**: ≥ 4.0m
- **Sin interpenetración**: AABB global no intersectan
- Grupo: `parked_car`
- Culling: 80m
- Rotación aleatoria 0-TAU

---

## 10. Props de Física (physics_props)

| Kind | Modelo | Superficie | Masa | Shape | Dims |
|------|--------|------------|------|-------|------|
| barrel_metal | security_light.glb | metal | 0 (static) | box | 0.3, 6.0, 0.3 |
| crate_wood | painted_wooden_bench.glb | wood | 0 | box | 1.5, 0.9, 0.5 |
| trash_metal | trashbag.glb | metal | 12 | cylinder | 0.4, 1.0, 0.4 |
| fence_section | fence_simple.glb | metal | 0 | box | 2.0, 1.2, 0.1 |

*Rutas actualizadas a assets existentes en Kenney kits*

---

## 11. Materiales y Texturas

- **Triplanar PBR** para suelo/paredes (world_materials.gd)
- **Props GLB reales** con StandardMaterial3D
- **Meta `surface`** en colliders para footsteps/impact audio
- **Texturas**: max 1024px, ASTC, sin mipmaps rotos
- **Sky**: PanoramaSkyMaterial con fallback ProceduralSkyMaterial
- **Fog**: densidad 0.0012-0.008 según time_of_day/mobile

---

## 12. Validación (map_validator.gd)

Status codes:
- `OK` (0): Lista para jugar
- `COMPATIBLE_WITH_WARNINGS` (1): Jugable con avisos
- `INCOMPATIBLE` (2): Requiere fixes

### Checks obligatorios
- [ ] Meta.ok == true
- [ ] Spawn points ≥ 4 y válidos
- [ ] NavigationRegion + Mesh presentes
- [ ] Build time ≤ 2500ms
- [ ] Node count ≤ 800
- [ ] Draw calls ≤ 150
- [ ] Texturas ≤ 1024px
- [ ] Sin TrimeshCollisionShape3D
- [ ] Sin primitive visibles
- [ ] Vegetación/cercas/coches sin interpenetración

---

## 13. Testing

Tests automatizados (headless):
```
test_maps_beta.gd      # Beta QA completo (este estándar)
test_maps_qa.gd        # Regresión + catálogo
test_map_load_performance.gd  # Build time + node count
test_map_vegetation.gd       # Vegetación placement
test_map_fences.gd           # Cercas placement
test_themed_maps.gd          # Assets por tema
test_map_catalog.gd          # MapCatalog.get_available_maps
```

Ejecutar: `grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path ~/UNTITLED --script res://tests/test_maps_beta.gd`

---

## 14. Catálogo de Mapas (MapCatalog)

- `get_available_maps()` retorna Array[Dictionary] con: id, theme, license, has_collisions, has_navigation, spawn_points
- MapRegistry registra metas por tema para tests
- Filtrado por tema, licencia, features

---

## 15. Checklist de Entrega (Definition of Done)

- [ ] Build time < 2500ms en los 3 temas
- [ ] Node count < 800 en los 3 temas
- [ ] Draw calls < 150 estimado
- [ ] 4+ spawn points válidos por mapa
- [ ] NavigationMesh funcional (pathfinding entre spawns)
- [ ] Vegetación sin interpenetración (rural/industrial/urbano)
- [ ] Cercas sin interpenetración (rural/industrial)
- [ ] Coches aparcados sin interpenetración (urbano/industrial)
- [ ] 0 TrimeshCollisionShape3D
- [ ] Texturas ≤ 1024px ASTC
- [ ] Props GLB reales (Kenney kits)
- [ ] Tests `test_maps_beta.gd` PASS (todas las assertions)
- [ ] `docs/MAP_STANDARD.md` actualizado

---

## 16. Referencias de Código

| Archivo | Responsabilidad |
|---------|-----------------|
| `core/maps/map_world_builder.gd` | Construcción mundo (suelo, paredes, obstáculos, vegetación, cercas, coches, props) |
| `core/maps/map_themes.gd` | Generación meta por tema, decoración |
| `core/maps/map_generator.gd` | Parámetros generación procedural |
| `core/maps/world_materials.gd` | Materiales, props config, sky, mobile detect |
| `core/maps/map_validator.gd` | Validación meta + build report |
| `core/maps/map_catalog.gd` | Catálogo runtime + get_available_maps |
| `core/maps/map_registry.gd` | Registro metas para tests |
| `core/maps/building_generator.gd` | Model batching, transforms, bounds |
| `tests/test_maps_beta.gd` | QA beta completo (este estándar) |

---

*Última actualización: 2026-11-21*
*Versión: 1.0 (M3 Maps & Models)*