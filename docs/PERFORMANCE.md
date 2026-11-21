# UNTITLED Performance Guide

## Target Platforms & Budgets

| Platform | FPS Target | Frame Budget | Max Tris | Max Draw Calls | Max Shadow Lights |
|----------|------------|--------------|----------|----------------|-------------------|
| Quest 3 (72Hz) | 72 | 13.888ms | 150,000 | 120 | 2 |
| Quest 3 (90Hz) | 90 | 11.111ms | 120,000 | 100 | 2 |
| Android (mobile) | 60 | 16.667ms | 100,000 | 80 | 1 |
| PC (desktop) | 90 | 11.111ms | 500,000 | 300 | 4 |

## Recommended Project Settings

### Rendering - Texture Compression (VRAM)
```ini
rendering/textures/vram_compression/import_etc2_astc = true
rendering/textures/vram_compression/import_bptc = true
rendering/textures/default_texture_import_format = 0  # Detect
rendering/textures/import_anisotropic_filter_level = 2
```

**Why**: ASTC/ETC2 compression reduces VRAM usage 4-8x vs uncompressed. Critical for Quest's 8-12GB shared memory. Anisotropic 2x is a good balance.

### Renderer
```ini
rendering/renderer/rendering_method = "mobile"
rendering/renderer/rendering_quality = "low"
rendering/environment/defaults/default_environment = ""
```

**Why**: Mobile renderer disables expensive features (SSAO, volumetric fog, screen-space reflections) automatically. Quality "low" forces mobile shader paths.

### MSAA & Foveation (VR)
```ini
xr/openxr/foveation_level = 1  # 0=off, 1=low, 2=medium, 3=high
rendering/anti_aliasing/msaa_2d = 2  # 2x or 4x for VR
rendering/anti_aliasing/msaa_3d = 2
```

**Why**: Foveation renders periphery at lower resolution (saves 15-30% GPU). MSAA 2x is minimum for VR comfort; 4x if budget allows.

### Render Scale
```ini
xr/openxr/render_target_size_mode = 1  # Manual
xr/openxr/render_target_scale = 1.0  # Adjust at runtime (0.7-1.0)
```

**Why**: Dynamic render scale is primary degradation lever. 0.7 = ~50% pixels, huge GPU savings.

### Physics
```ini
physics/3d/physics_ticks_per_second = 72  # Match 72Hz, or 90 for 90Hz
physics/3d/solver_iterations = 4
physics/3d/solver_max_substeps = 4
```

**Why**: 72Hz physics matches display refresh, reduces interpolation artifacts. Lower iterations save CPU.

### Shadows
```ini
rendering/shadows/shadow_atlas_size = 2048  # Small atlas for mobile
rendering/shadows/directional_shadow_count = 1
rendering/shadows/directional_shadow_size = 0  # 2048
rendering/shadows/spot_shadow_count = 1
rendering/shadows/spot_shadow_size = 1  # 1024
rendering/shadows/omni_shadow_count = 0
rendering/shadows/omni_shadow_size = 0
rendering/shadows/max_distance = 30.0
rendering/shadows/fade_distance = 5.0
```

**Why**: Small atlas (2048) fits in tile memory. 1 directional + 1 spot max. Distance 30m matches Quest culling.

### Disable on Mobile
```ini
rendering/environment/defaults/enable_ssao = false
rendering/environment/defaults/enable_volumetric_fog = false
rendering/environment/defaults/enable_screen_space_reflections = false
rendering/environment/defaults/enable_sdfgi = false
rendering/environment/defaults/enable_glow = false
rendering/environment/defaults/enable_dof = false
rendering/environment/defaults/enable_motion_blur = false
rendering/environment/defaults/enable_lens_distortion = false
rendering/environment/defaults/enable_chromatic_aberration = false
rendering/environment/defaults/enable_vignette = false
```

**Why**: All these are expensive post-process effects with no mobile fallback. Disable entirely.

### Mipmaps & LOD
```ini
rendering/textures/default_mipmaps = true
rendering/mesh_import/import_lod = true
rendering/mesh_import/lod_simplification_factor = 0.5
```

**Why**: Mipmaps prevent aliasing and improve cache efficiency. Mesh LOD at 50% reduction per level.

### Asset Import Defaults
```ini
rendering/textures/import_srgb_to_linear = true
rendering/textures/import_detect_3d = true
rendering/textures/import_generate_mipmaps = true
rendering/textures/import_compress_mode = 2  # VRAM Compressed
rendering/textures/import_compress_lossy_quality = 0.7
rendering/mesh_import/import_materials = 0  # Don't import materials (use shared)
```

**Why**: sRGB->linear for PBR correctness. VRAM compression mandatory. Shared materials from WorldMaterials.

## Platform-Specific Budget Tables

### Quest 3 (72Hz) - Primary Target
| Budget | Value | Measurement |
|--------|-------|-------------|
| Frame time | ≤13.888ms | VrPerformance.observe_frame() |
| Visible triangles | ≤150,000 | PerfBudget.tri_estimate |
| Draw calls | ≤120 | PerfBudget.draw_calls |
| Shadow lights | ≤2 | PerfBudget.shadow_lights |
| Texture size | ≤1024px | PerfBudget.texture_sizes |
| Ragdolls | ≤8 | Runtime count |
| Shell casings | ≤24 | Pool size |
| Decals | ≤128 | Pool size |
| NPCs (active) | ≤12 | VrPerformance profile |
| Particles | ≤120 | VrPerformance profile |
| Physics bodies | ≤200 | PerfBudget.physics_bodies |

### Quest 3 (90Hz)
| Budget | Value |
|--------|-------|
| Frame time | ≤11.111ms |
| Visible triangles | ≤120,000 |
| Draw calls | ≤100 |
| Shadow lights | ≤2 |
| NPCs (active) | ≤10 |
| Particles | ≤96 |

### Android (60Hz)
| Budget | Value |
|--------|-------|
| Frame time | ≤16.667ms |
| Visible triangles | ≤100,000 |
| Draw calls | ≤80 |
| Shadow lights | ≤1 |
| Texture size | ≤512px (recommended) |
| NPCs (active) | ≤8 |
| Particles | ≤80 |

### PC (Desktop)
| Budget | Value |
|--------|-------|
| Frame time | ≤11.111ms (90Hz) / 16.667ms (60Hz) |
| Visible triangles | ≤500,000 |
| Draw calls | ≤300 |
| Shadow lights | ≤4 |
| Texture size | ≤2048px |
| NPCs (active) | ≤50 |
| Particles | ≤500 |

## Runtime Optimization Systems

### MultiMesh Instancing (map_world_builder.gd)
- All repeated props (barrels, crates, vegetation) use MultiMeshInstance3D
- Single draw call per prop type regardless of instance count
- `visibility_range_end` + `visibility_range_fade_mode` for GPU culling

### Shared Materials (world_materials.gd)
- Desktop/Mobile material separation with ref-counting
- Mobile materials disable: triplanar mapping, point_size, ambient_light, fog
- `release_material()` for cleanup, `clear_unused_materials()` for bulk

### NPC LOD (npc_lod.gd)
| Distance | Visual LOD | Anim Update | AI Update |
|----------|------------|-------------|-----------|
| 0-15m | Near (0) | Every frame | Every frame |
| 15-35m | Mid (1) | Every 2 frames | Every 3 frames |
| 35-70m | Far (2) | Every 4 frames | Every 5 frames |
| >70m | Culled (3) | Stopped | Stopped |

- Occlusion culling at 1Hz interval
- Automatic degrade level based on frame budget

### Frustum Culling (vr_performance.gd)
- Camera frustum planes extracted at 10Hz
- AABB and sphere visibility tests
- `apply_profile_to_scene()` sets `visibility_range_end` on all MeshInstance3D/MultiMeshInstance3D

### Pooling Systems
- Shell casings: 24 max, recycled on fire
- Decals: 128 max, LRU replacement
- AudioStreamPlayer3D: 16 voices, priority-based

### Adaptive Degradation (vr_performance.gd)
| Level | Trigger | Render Scale | Shadow Dist | Particles | NPCs |
|-------|---------|--------------|-------------|-----------|------|
| 0 | - | 1.0 | 18m | 120 | 12 |
| 1 | 10 slow frames | 0.92 | 15m | 86 | 10 |
| 2 | 20 slow frames | 0.84 | 12m | 62 | 8 |
| 3 | 30 slow frames | 0.77 | 9m | 44 | 6 |
| 4 | 40 slow frames | 0.70 | 6m | 32 | 4 |

Recovery: 24 stable frames per level to step back up.

## What Cannot Be Measured Without Device

| Metric | Why | Workaround |
|--------|-----|------------|
| Actual GPU frame time | Headless has no GPU | Use VrPerformance budget as proxy |
| VRAM usage | No VRAM in headless | Track texture count/size, mesh memory |
| Thermal throttling | No thermal sensors | Assume sustained load degrades |
| Display latency | No display | Profile on device with adb logcat |
| Battery impact | No battery | Estimate from CPU/GPU usage |
| Asynchronous reprojection | VR compositor only | Test on device with `adb shell dumpsys gfxinfo` |

## Performance Analysis Tools

### PerfBudget (tools/perf_budget.gd)
```bash
# Run budget analysis
grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path ~/UNTITLED --script res://tools/perf_budget.gd
```

Output: Per-theme budget report with PASS/FAIL per metric.

### Test Suite (tests/test_perf_budget.gd)
```bash
grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path ~/UNTITLED --script res://tests/test_perf_budget.gd
```

Validates: budget constants, theme analysis, building analysis, triangle/draw-call estimation, material/texture counting, shadow/physics/particle counting.

### Apply VR Settings Script (tools/apply_vr_project_settings.sh)
```bash
./tools/apply_vr_project_settings.sh build/vr_project
```

Creates a copy of the project with all VR-optimized settings applied. Does NOT modify main project.

## Asset Budget Guidelines

| Asset Type | Quest Max | Android Max | PC Max | Format |
|------------|-----------|-------------|--------|--------|
| Character | 15,000 tris | 10,000 tris | 50,000 tris | glTF |
| Weapon | 8,000 tris | 5,000 tris | 20,000 tris | glTF |
| Prop | 5,000 tris | 3,000 tris | 15,000 tris | glTF |
| Building tile | 10,000 tris | 5,000 tris | 30,000 tris | glTF |
| Texture | 1024px | 512px | 2048px | ASTC 4x4 / BC7 |
| Material | Shared | Shared | Per-asset | StandardMaterial3D |

All textures MUST be ASTC compressed (VRAM). Use `rendering/textures/vram_compression/import_etc2_astc=true`.

## Profiling Checklist (On Device)

- [ ] `adb logcat -s Godot` - check for errors
- [ ] `adb shell dumpsys gfxinfo <package>` - frame timing
- [ ] `adb shell dumpsys meminfo <package>` - memory usage
- [ ] `adb shell cat /sys/class/thermal/thermal_zone*/temp` - thermal
- [ ] Meta Quest Developer Hub - GPU/CPU counters
- [ ] RenderDoc for Android - draw call analysis

## Performance Regression Testing

Run `test_perf_budget.gd` on every PR. Budget failures = build failure.

Run `test_r4_performance_regression.gd` for runtime degradation/recovery validation.

Run `test_r4_perf_measurements.gd` for baseline measurements.

## References

- [Godot Mobile Rendering](https://docs.godotengine.org/en/stable/tutorials/rendering/optimizing_for_mobile.html)
- [Meta Quest Performance Guidelines](https://developer.oculus.com/documentation/unity/unity-perf/)
- [ASTC Texture Compression](https://developer.arm.com/tools-and-software/graphics-and-gaming/astc-texture-compression)