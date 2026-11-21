#!/bin/bash
# apply_vr_project_settings.sh
# Applies VR-optimized project settings to a COPY of the project.
# Does NOT modify the main project.
#
# Usage: ./tools/apply_vr_project_settings.sh <target_directory>
# Example: ./tools/apply_vr_project_settings.sh build/vr_project

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_DIR="${1:-}"
if [[ -z "$TARGET_DIR" ]]; then
    echo "Usage: $0 <target_directory>"
    echo "Example: $0 build/vr_project"
    exit 1
fi

TARGET_DIR="$(cd "$PROJECT_ROOT" && realpath "$TARGET_DIR")"

echo "=== Apply VR Project Settings ==="
echo "Source: $PROJECT_ROOT"
echo "Target: $TARGET_DIR"
echo ""

# Create target directory as copy of project
if [[ -d "$TARGET_DIR" ]]; then
    echo "Target exists, removing..."
    rm -rf "$TARGET_DIR"
fi

echo "Copying project..."
cp -r "$PROJECT_ROOT" "$TARGET_DIR"

# Remove build artifacts and temp dirs from copy
rm -rf "$TARGET_DIR/build"
rm -rf "$TARGET_DIR/.godot"
rm -rf "$TARGET_DIR/tmp_props"
rm -rf "$TARGET_DIR/.git"

cd "$TARGET_DIR"

# Apply VR-optimized settings to project.godot
PROJECT_GODOT="project.godot"

echo "Applying VR settings to $PROJECT_GODOT..."

# Backup original
cp "$PROJECT_GODOT" "$PROJECT_GODOT.bak"

# Python script to modify project.godot
python3 << 'PYEOF'
import configparser
import sys

config = configparser.ConfigParser()
config.optionxform = str  # Preserve case
config.read('project.godot')

# Ensure sections exist
sections = [
    'rendering/textures/vram_compression',
    'rendering/textures',
    'rendering/renderer',
    'rendering/anti_aliasing',
    'xr/openxr',
    'physics/3d',
    'rendering/shadows',
    'rendering/environment/defaults',
    'rendering/mesh_import',
]
for s in sections:
    if s not in config:
        config[s] = {}

# VRAM Texture Compression
config['rendering/textures/vram_compression']['import_etc2_astc'] = 'true'
config['rendering/textures/vram_compression']['import_bptc'] = 'true'

# Texture defaults
config['rendering/textures']['default_texture_import_format'] = '0'  # Detect
config['rendering/textures']['import_anisotropic_filter_level'] = '2'
config['rendering/textures']['import_srgb_to_linear'] = 'true'
config['rendering/textures']['import_detect_3d'] = 'true'
config['rendering/textures']['import_generate_mipmaps'] = 'true'
config['rendering/textures']['import_compress_mode'] = '2'  # VRAM Compressed
config['rendering/textures']['import_compress_lossy_quality'] = '0.7'

# Renderer
config['rendering/renderer']['rendering_method'] = '"mobile"'
config['rendering/renderer']['rendering_quality'] = '"low"'
config['rendering/renderer']['rendering_quality'] = '"low"'

# MSAA
config['rendering/anti_aliasing']['msaa_2d'] = '2'
config['rendering/anti_aliasing']['msaa_3d'] = '2'

# OpenXR / VR
config['xr/openxr']['foveation_level'] = '1'
config['xr/openxr']['render_target_size_mode'] = '1'  # Manual
config['xr/openxr']['render_target_scale'] = '1.0'

# Physics
config['physics/3d']['physics_ticks_per_second'] = '72'
config['physics/3d']['solver_iterations'] = '4'
config['physics/3d']['solver_max_substeps'] = '4'

# Shadows
config['rendering/shadows']['shadow_atlas_size'] = '2048'
config['rendering/shadows']['directional_shadow_count'] = '1'
config['rendering/shadows']['directional_shadow_size'] = '0'  # 2048
config['rendering/shadows']['spot_shadow_count'] = '1'
config['rendering/shadows']['spot_shadow_size'] = '1'  # 1024
config['rendering/shadows']['omni_shadow_count'] = '0'
config['rendering/shadows']['omni_shadow_size'] = '0'
config['rendering/shadows']['max_distance'] = '30.0'
config['rendering/shadows']['fade_distance'] = '5.0'

# Disable expensive post-process on mobile
config['rendering/environment/defaults']['enable_ssao'] = 'false'
config['rendering/environment/defaults']['enable_volumetric_fog'] = 'false'
config['rendering/environment/defaults']['enable_screen_space_reflections'] = 'false'
config['rendering/environment/defaults']['enable_sdfgi'] = 'false'
config['rendering/environment/defaults']['enable_glow'] = 'false'
config['rendering/environment/defaults']['enable_dof'] = 'false'
config['rendering/environment/defaults']['enable_motion_blur'] = 'false'
config['rendering/environment/defaults']['enable_lens_distortion'] = 'false'
config['rendering/environment/defaults']['enable_chromatic_aberration'] = 'false'
config['rendering/environment/defaults']['enable_vignette'] = 'false'

# Mipmaps & LOD
config['rendering/mesh_import']['import_materials'] = '0'  # Don't import materials (use shared)

# Write back
with open('project.godot', 'w') as f:
    config.write(f)

print("project.godot updated successfully")
PYEOF

echo ""
echo "Verifying applied settings..."

# Verify key settings
python3 << 'PYEOF'
import configparser
config = configparser.ConfigParser()
config.optionxform = str
config.read('project.godot')

checks = [
    ('rendering/textures/vram_compression', 'import_etc2_astc', 'true'),
    ('rendering/textures/vram_compression', 'import_bptc', 'true'),
    ('rendering/renderer', 'rendering_method', '"mobile"'),
    ('rendering/renderer', 'rendering_quality', '"low"'),
    ('rendering/anti_aliasing', 'msaa_2d', '2'),
    ('rendering/anti_aliasing', 'msaa_3d', '2'),
    ('xr/openxr', 'foveation_level', '1'),
    ('physics/3d', 'physics_ticks_per_second', '72'),
    ('rendering/shadows', 'shadow_atlas_size', '2048'),
    ('rendering/shadows', 'directional_shadow_count', '1'),
    ('rendering/shadows', 'max_distance', '30.0'),
    ('rendering/environment/defaults', 'enable_ssao', 'false'),
    ('rendering/environment/defaults', 'enable_volumetric_fog', 'false'),
    ('rendering/environment/defaults', 'enable_screen_space_reflections', 'false'),
    ('rendering/environment/defaults', 'enable_sdfgi', 'false'),
    ('rendering/environment/defaults', 'enable_glow', 'false'),
    ('rendering/environment/defaults', 'enable_dof', 'false'),
    ('rendering/environment/defaults', 'enable_motion_blur', 'false'),
    ('rendering/mesh_import', 'import_materials', '0'),
]

all_pass = True
for section, key, expected in checks:
    actual = config.get(section, key, fallback='MISSING')
    if actual == expected:
        print(f"  ✓ {section}.{key} = {actual}")
    else:
        print(f"  ✗ {section}.{key} = {actual} (expected {expected})")
        all_pass = False

if all_pass:
    print("\n✓ All VR settings verified!")
    sys.exit(0)
else:
    print("\n✗ Some settings failed verification")
    sys.exit(1)
PYEOF

echo ""
echo "=== Done ==="
echo "VR-optimized project ready at: $TARGET_DIR"
echo ""
echo "To build VR APK:"
echo "  cd $TARGET_DIR"
echo "  ./tools/build_vr.sh"