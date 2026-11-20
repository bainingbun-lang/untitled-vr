import sys

path = sys.argv[1]
updates = {
    "application": {
        "run/main_scene": '"res://scenes/vr/vr_boot.tscn"',
    },
    "rendering": {
        "renderer/rendering_method": '"mobile"',
        "renderer/rendering_method.mobile": '"mobile"',
        "textures/vram_compression/import_etc2_astc": "true",
    },
    "xr": {
        "openxr/enabled": "true",
        "shaders/enabled": "true",
        "openxr/form_factor": "0",
        "openxr/view_configuration": "1",
        "openxr/reference_space": "2",
        "openxr/environment_blend_mode": "0",
        "openxr/startup_alert": "false",
        "openxr/foveation_level": "1",
        "openxr/foveation_dynamic": "true",
        "openxr/foveation_eye_tracked": "false",
        "openxr/foveation_with_subsampled_images": "false",
        "openxr/extensions/hand_tracking": "false",
        "openxr/extensions/eye_gaze_interaction": "false",
        "openxr/extensions/user_presence": "true",
    },
}

with open(path, "r", encoding="utf-8") as handle:
    lines = handle.read().splitlines()

sections = {}
order = []
current = None
for line in lines:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        current = stripped[1:-1]
        if current not in sections:
            sections[current] = []
            order.append(current)
    elif current is not None:
        sections[current].append(line)

for section, values in updates.items():
    if section not in sections:
        sections[section] = []
        order.append(section)
    body = sections[section]
    for key, value in values.items():
        for index, line in enumerate(body):
            if line.split("=", 1)[0].strip() == key:
                body[index] = f"{key}={value}"
                break
        else:
            body.append(f"{key}={value}")

with open(path, "w", encoding="utf-8") as handle:
    for section in order:
        handle.write(f"[{section}]\n")
        for line in sections[section]:
            handle.write(line + "\n")
        handle.write("\n")
