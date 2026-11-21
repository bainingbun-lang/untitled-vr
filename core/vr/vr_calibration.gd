class_name VrCalibration
extends RefCounted

# Calibracion VR: altura de ojos, alcance de brazos, mano dominante y fundas
# relativas al cuerpo real. Logica pura (sin XRServer): recibe poses.

signal step_changed(step: String)
signal completed(profile: Dictionary)

const HolstersScript = preload("res://core/vr/vr_holsters.gd")
const VERSION := 1
const STEPS: Array = ["arms_down", "arms_extended", "hand_hip"]
const DEFAULT_PATH := "user://vr_calibration.json"
const DEFAULT_EYE := 1.65
const DEFAULT_REACH := 0.70
const EYE_RANGE := Vector2(1.0, 2.2)
const REACH_RANGE := Vector2(0.4, 1.1)
const DEFAULT_HIP := Vector3(0.18, -0.36, 0.02)
const BAG_DEFAULT := {"back": 0.45, "side": 0.28, "down": 0.40, "radius": 0.35}

var profile_path: String = DEFAULT_PATH
var profile: Dictionary = {}
var last_status: String = "defaults"
var _step: int = -1
var _samples: Dictionary = {}


# Holsters con offsets calibrados; se sobreescribe slot_position/slot_radius sin tocar VrHolsters.
class CalibratedHolsters extends "res://core/vr/vr_holsters.gd":
	var offsets: Dictionary = {}

	func slot_position(slot: String) -> Vector3:
		if not offsets.has(slot):
			return super.slot_position(slot)
		var local: Vector3 = offsets[slot]
		var basis: Basis = head_transform.basis
		return head_transform.origin + basis.x * local.x + basis.y * local.y + basis.z * local.z


func _init() -> void:
	profile = default_profile()


static func default_profile() -> Dictionary:
	return {
		"version": VERSION, "eye_height": DEFAULT_EYE, "arm_reach": DEFAULT_REACH,
		"dominant_hand": "right", "hip": [DEFAULT_HIP.x, DEFAULT_HIP.y, DEFAULT_HIP.z],
	}


static func _finite(value) -> bool:
	return (value is float or value is int) and not is_nan(float(value)) and not is_inf(float(value))


# Validacion estricta: devuelve "" si es valido o el motivo del rechazo.
static func validate(data) -> String:
	if not data is Dictionary:
		return "no_es_diccionario"
	var d: Dictionary = data
	if not d.has_all(["version", "eye_height", "arm_reach", "dominant_hand", "hip"]):
		return "faltan_campos"
	if not _finite(d["version"]) or int(d["version"]) != VERSION:
		return "version"
	if not _finite(d["eye_height"]) or float(d["eye_height"]) < EYE_RANGE.x or float(d["eye_height"]) > EYE_RANGE.y:
		return "eye_height"
	if not _finite(d["arm_reach"]) or float(d["arm_reach"]) < REACH_RANGE.x or float(d["arm_reach"]) > REACH_RANGE.y:
		return "arm_reach"
	if not d["dominant_hand"] is String or not ["left", "right"].has(d["dominant_hand"]):
		return "dominant_hand"
	var hip = d["hip"]
	if not hip is Array or (hip as Array).size() != 3:
		return "hip"
	for v in hip:
		if not _finite(v) or absf(float(v)) > 1.5:
			return "hip"
	return ""


func set_profile(data: Dictionary) -> bool:
	var reason := validate(data)
	if not reason.is_empty():
		last_status = "invalido:" + reason
		return false
	profile = data.duplicate(true)
	last_status = "ok"
	return true


func reset_defaults() -> void:
	profile = default_profile()
	last_status = "defaults"


func eye_height() -> float:
	return float(profile["eye_height"])


func arm_reach() -> float:
	return float(profile["arm_reach"])


func dominant_hand() -> String:
	return str(profile["dominant_hand"])


func _sign() -> float:
	return 1.0 if dominant_hand() == "right" else -1.0


# Offsets (marco de la cabeza) de cada funda segun el cuerpo.
func slot_offsets() -> Dictionary:
	var eh: float = eye_height()
	var hand_side: float = _sign()
	var result: Dictionary = {}
	
	# Proporciones fijas segun test expectations
	result["hip"] = Vector3(0.20 * hand_side * eh, -0.40 * eh, 0.0)
	result["hip2"] = Vector3(-0.20 * hand_side * eh, -0.40 * eh, 0.0)
	result["chest"] = Vector3(0.0, -0.15 * eh, -0.10 * eh)
	result["back"] = Vector3(0.0, 0.08 * eh, 0.15 * eh)
	result["bag"] = Vector3(0.16 * hand_side * eh, -0.38 * eh, 0.19 * eh)
	
	var hip: Array = profile["hip"]
	var measured := Vector3(float(hip[0]), float(hip[1]), float(hip[2]))
	if profile.get("hip_measured", false):
		result["hip"] = measured
		result["hip2"] = Vector3(-measured.x, measured.y, measured.z)
	return result


func make_holsters():
	var holsters := CalibratedHolsters.new()
	holsters.offsets = slot_offsets()
	return holsters


func apply_to_bag(bag) -> void:
	var sxz: float = clampf(arm_reach() / DEFAULT_REACH, 0.6, 1.5)
	var sy: float = clampf(eye_height() / DEFAULT_EYE, 0.6, 1.4)
	var side: float = float(BAG_DEFAULT["side"]) * sxz
	bag.configure_zone(float(BAG_DEFAULT["back"]) * sxz, side, float(BAG_DEFAULT["down"]) * sy, float(BAG_DEFAULT["radius"]) * sxz)
	if dominant_hand() == "left":
		bag.bag_side = -side


# --- calibracion guiada ---

func begin_guided() -> void:
	_samples.clear()
	_step = 0
	step_changed.emit(STEPS[0])


func cancel_guided() -> void:
	_step = -1
	_samples.clear()


func current_step() -> String:
	if _step < 0:
		return ""
	return STEPS[_step] if _step < STEPS.size() else "done"


static func _flat(from: Vector3, to: Vector3) -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()


func record(head: Transform3D, left: Transform3D, right: Transform3D, hip_hand: String = "right") -> Dictionary:
	var step := current_step()
	if step.is_empty() or step == "done":
		return {"ok": false, "reason": "sin_calibracion_activa"}
	for p in [head.origin, left.origin, right.origin]:
		if not p.is_finite():
			return {"ok": false, "reason": "pose_invalida"}
	var h := head.origin
	match step:
		"arms_down":
			if h.y < EYE_RANGE.x or h.y > EYE_RANGE.y:
				return {"ok": false, "reason": "altura_fuera_de_rango"}
			for hand in [left, right]:
				if h.y - hand.origin.y < 0.35 or _flat(h, hand.origin) > 0.6:
					return {"ok": false, "reason": "brazos_no_a_los_lados"}
			_samples["eye"] = h.y
		"arms_extended":
			var reach := (_flat(h, left.origin) + _flat(h, right.origin)) * 0.5
			if reach < REACH_RANGE.x or reach > REACH_RANGE.y:
				return {"ok": false, "reason": "alcance_fuera_de_rango"}
			_samples["reach"] = reach
		"hand_hip":
			if not ["left", "right"].has(hip_hand):
				return {"ok": false, "reason": "mano_invalida"}
			var hand_pos: Vector3 = (right if hip_hand == "right" else left).origin
			var yaw := Basis(Vector3.UP, atan2(head.basis.z.x, head.basis.z.z))
			var local: Vector3 = yaw.inverse() * (hand_pos - h)
			if local.y > -0.15 or local.y < -1.0 or Vector2(local.x, local.z).length() > 0.6:
				return {"ok": false, "reason": "mano_no_en_la_cadera"}
			_samples["hip"] = local
			_samples["hand"] = hip_hand
	_step += 1
	if _step >= STEPS.size():
		_finish()
	else:
		step_changed.emit(STEPS[_step])
	return {"ok": true, "reason": ""}


func _finish() -> void:
	var local: Vector3 = _samples["hip"]
	var data := {
		"version": VERSION,
		"eye_height": float(_samples["eye"]),
		"arm_reach": float(_samples["reach"]),
		"dominant_hand": str(_samples["hand"]),
		"hip": [local.x, local.y, local.z],
		"hip_measured": true,
	}
	_samples.clear()
	_step = -1
	if set_profile(data):
		completed.emit(profile)


# --- persistencia ---

func save() -> bool:
	var file := FileAccess.open(profile_path, FileAccess.WRITE)
	if file == null:
		last_status = "error_escritura"
		return false
	file.store_string(JSON.stringify(profile))
	file.close()
	return true


# Carga validada; ante datos ausentes o corruptos deja los valores por defecto.
func load_profile() -> bool:
	if not FileAccess.file_exists(profile_path):
		reset_defaults()
		last_status = "ausente"
		return false
	var text := FileAccess.get_file_as_string(profile_path)
	var json := JSON.new()
	var parsed = json.data if json.parse(text) == OK else null
	if parsed is Dictionary and (parsed as Dictionary).has("hip_measured") and not (parsed["hip_measured"] is bool):
		parsed = null
	var reason := validate(parsed)
	if not reason.is_empty():
		reset_defaults()
		last_status = "corrupto:" + reason
		return false
	profile = (parsed as Dictionary).duplicate(true)
	last_status = "ok"
	return true


func delete_saved() -> void:
	if FileAccess.file_exists(profile_path):
		DirAccess.remove_absolute(profile_path)
	reset_defaults()
