class_name VrComfort extends RefCounted

const PROFILE_KEYS := ["version", "turn_mode", "smooth_turn_speed", "snap_turn_degrees", "snap_cooldown", "stick_deadzone", "snap_threshold", "move_speed", "comfort_vignette_enabled", "vignette_intensity", "vignette_speed_ref", "vignette_angular_ref", "teleport_enabled", "teleport_max_distance", "seated_mode", "height_offset"]

const VERSION := 1

static func default_profile() -> Dictionary:
	return {
		"version": VERSION,
		"turn_mode": "smooth",
		"smooth_turn_speed": 1.6,
		"snap_turn_degrees": 30.0,
		"snap_cooldown": 0.25,
		"stick_deadzone": 0.2,
		"snap_threshold": 0.7,
		"move_speed": 2.2,
		"comfort_vignette_enabled": true,
		"vignette_intensity": 0.85,
		"vignette_speed_ref": 3.0,
		"vignette_angular_ref": 2.0,
		"teleport_enabled": false,
		"teleport_max_distance": 5.0,
		"seated_mode": false,
		"height_offset": 0.0,
	}

static func validate_profile(data: Dictionary) -> Dictionary:
	var result := {"ok": false, "errors": [], "profile": {}}
	var errors: Array[String] = []

	if not (data is Dictionary):
		errors.append("perfil no es Dictionary")
		result["errors"] = errors
		return result

	for key in PROFILE_KEYS:
		if not data.has(key):
			errors.append("falta clave: " + key)
			result["errors"] = errors
			return result

	var version = data["version"]
	if typeof(version) != TYPE_INT or int(version) != VERSION:
		errors.append("version de perfil no soportada")

	var turn_mode = data["turn_mode"]
	if typeof(turn_mode) != TYPE_STRING or not ["smooth", "snap", "off"].has(turn_mode):
		errors.append("turn_mode invalido")

	for key in ["smooth_turn_speed", "snap_turn_degrees", "snap_cooldown", "stick_deadzone", "snap_threshold", "move_speed", "vignette_intensity", "vignette_speed_ref", "vignette_angular_ref", "teleport_max_distance"]:
		var val = data[key]
		if not _is_number(val):
			errors.append(key + " no es numero")
		elif float(val) < 0.0:
			errors.append(key + " fuera de rango (negativo)")
	
	var height_offset = data["height_offset"]
	if not _is_number(height_offset):
		errors.append("height_offset no es numero")
	elif absf(float(height_offset)) > 1.0:
		errors.append("height_offset fuera de rango")

	if float(data["stick_deadzone"]) > 1.0:
		errors.append("stick_deadzone > 1.0")

	if float(data["vignette_intensity"]) > 1.0:
		errors.append("vignette_intensity > 1.0")

	for key in ["comfort_vignette_enabled", "teleport_enabled", "seated_mode"]:
		if typeof(data[key]) != TYPE_BOOL:
			errors.append(key + " no es bool")

	if not errors.is_empty():
		result["errors"] = errors
		return result

	result["ok"] = true
	result["profile"] = _canonical(data)
	result["errors"] = errors
	return result

static func _canonical(data: Dictionary) -> Dictionary:
	var canonical := {}
	for key in PROFILE_KEYS:
		canonical[key] = _copy(data[key])
	return canonical

static func _is_number(value) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

static func _copy(value) -> Variant:
	if value is Dictionary:
		return value.duplicate(true)
	if value is Array:
		return value.duplicate(true)
	return value


static func compute_vignette(
	linear_speed: float, angular_speed: float,
	speed_ref: float = 3.0, angular_ref: float = 2.0,
	intensity: float = 0.85
) -> float:
	var linear_part: float = clampf(linear_speed / maxf(speed_ref, 0.0001), 0.0, 1.0)
	var angular_part: float = clampf(angular_speed / maxf(angular_ref, 0.0001), 0.0, 1.0)
	return clampf(maxf(linear_part, angular_part), 0.0, 1.0) * clampf(intensity, 0.0, 1.0)


static func turn_delta(
	stick_x: float, mode: String, smooth_speed: float, snap_degrees: float,
	delta: float, deadzone: float = 0.0, can_step: bool = true,
	snap_threshold: float = 0.7
) -> float:
	if mode == "off" or delta <= 0.0 or absf(stick_x) <= deadzone:
		return 0.0
	if mode == "snap":
		if not can_step or absf(stick_x) < maxf(deadzone, snap_threshold):
			return 0.0
		return -signf(stick_x) * deg_to_rad(snap_degrees)
	if mode == "smooth":
		var span: float = maxf(1.0 - deadzone, 0.0001)
		var amount: float = clampf((absf(stick_x) - deadzone) / span, 0.0, 1.0)
		return -signf(stick_x) * amount * maxf(smooth_speed, 0.0) * delta
	return 0.0


static func locomotion_velocity(
	stick: Vector2, forward: Vector3, speed: float, deadzone: float = 0.0
) -> Vector3:
	if stick.length_squared() <= deadzone * deadzone or forward.length_squared() <= 0.000001:
		return Vector3.ZERO
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length_squared() <= 0.000001:
		return Vector3.ZERO
	flat = flat.normalized()
	var right := flat.cross(Vector3.UP).normalized()
	var axis := right * stick.x + flat * stick.y
	return axis * maxf(speed, 0.0)


static func rotate_around_y(xform: Transform3D, pivot: Vector3, yaw: float) -> Transform3D:
	var rotation := Basis().rotated(Vector3.UP, yaw)
	var result := xform
	result.basis = rotation * xform.basis
	result.origin = pivot + rotation * (xform.origin - pivot)
	return result


static func translation_for_teleport(xform: Transform3D, head: Vector3, target: Vector3) -> Transform3D:
	var shift := target - head
	shift.y = 0.0
	var result := xform
	result.origin += shift
	return result


static func apply_seated_height(head_position: Vector3, height_offset: float, default_eye_height: float = 1.65) -> Vector3:
	if height_offset != 0.0:
		return Vector3(head_position.x, default_eye_height + height_offset, head_position.z)
	return head_position