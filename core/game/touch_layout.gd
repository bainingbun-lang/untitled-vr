class_name TouchLayout
extends RefCounted

const VERSION := 1
const SAVE_PATH := "user://touch_layout.json"
const PROFILE_DIESTRO := "diestro"
const PROFILE_ZURDO := "zurdo"
const PROFILE_COMPACTO := "compacto"
const PROFILES := [PROFILE_DIESTRO, PROFILE_ZURDO, PROFILE_COMPACTO]
const CONTROL_IDS := ["joystick", "look", "fire", "jump", "reload", "interact", "menu", "hotbar"]
const SIDES := ["left", "right"]
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const SAFE_INSET := 0.03
const SCALE_MIN := 0.5
const SCALE_MAX := 2.0
const OPACITY_MIN := 0.1
const OPACITY_MAX := 1.0
const SENSITIVITY_MIN := 0.0005
const SENSITIVITY_MAX := 0.02
const DEADZONE_MIN := 0.0
const DEADZONE_MAX := 0.4
const DEFAULT_SENSITIVITY := 0.003
const DEFAULT_DEADZONE := 0.14
const MAX_FILE_BYTES := 65536
const SEPARATION := 2.0

var save_path: String = SAVE_PATH
var profile: String = PROFILE_DIESTRO
var controls: Dictionary = {}
var look_sensitivity: float = DEFAULT_SENSITIVITY
var move_deadzone: float = DEFAULT_DEADZONE


func _init(path: String = SAVE_PATH) -> void:
	save_path = path
	reset(PROFILE_DIESTRO)
	load_from_disk()


static func base_size(id: String) -> Vector2:
	match id:
		"joystick":
			return Vector2(260.0, 260.0)
		"look":
			return Vector2(520.0, 300.0)
		"fire":
			return Vector2(150.0, 120.0)
		"jump":
			return Vector2(150.0, 100.0)
		"reload":
			return Vector2(140.0, 90.0)
		"interact":
			return Vector2(180.0, 90.0)
		"menu":
			return Vector2(110.0, 80.0)
		"hotbar":
			return Vector2(90.0, 90.0)
	return Vector2(100.0, 100.0)


static func default_profile_data(profile_id: String) -> Dictionary:
	var positions := {
		"joystick": Vector2(0.17, 0.62),
		"look": Vector2(0.75, 0.40),
		"fire": Vector2(0.90, 0.86),
		"jump": Vector2(0.73, 0.86),
		"reload": Vector2(0.90, 0.70),
		"interact": Vector2(0.73, 0.70),
		"menu": Vector2(0.92, 0.09),
		"hotbar": Vector2(0.16, 0.90),
	}
	var compact_positions := {
		"joystick": Vector2(0.14, 0.60),
		"look": Vector2(0.78, 0.38),
		"fire": Vector2(0.92, 0.80),
		"jump": Vector2(0.76, 0.80),
		"reload": Vector2(0.92, 0.64),
		"interact": Vector2(0.76, 0.64),
		"menu": Vector2(0.92, 0.08),
		"hotbar": Vector2(0.14, 0.88),
	}
	var chosen_profile: String = profile_id if PROFILES.has(profile_id) else PROFILE_DIESTRO
	var compact: bool = chosen_profile == PROFILE_COMPACTO
	var mirror: bool = chosen_profile == PROFILE_ZURDO
	var data := {}
	for id in CONTROL_IDS:
		var pos: Vector2 = positions[id]
		var scale := 1.0
		if compact:
			pos = compact_positions[id]
			scale = 0.8
		var side := "left" if pos.x < 0.5 else "right"
		if mirror:
			pos = Vector2(1.0 - pos.x, pos.y)
			side = "right" if side == "left" else "left"
		data[id] = {
			"position": clamp_position(id, pos, scale),
			"scale": scale,
			"opacity": 1.0,
			"visible": true,
			"side": side,
		}
	return data


static func clamp_position(id: String, position: Vector2, scale: float) -> Vector2:
	var half := base_size(id) * clampf(scale, SCALE_MIN, SCALE_MAX) * 0.5 / DESIGN_SIZE
	var min_point := Vector2(SAFE_INSET, SAFE_INSET) + half
	var max_point := Vector2(1.0 - SAFE_INSET, 1.0 - SAFE_INSET) - half
	var result := position
	if max_point.x <= min_point.x:
		result.x = 0.5
	else:
		result.x = clampf(result.x, min_point.x, max_point.x)
	if max_point.y <= min_point.y:
		result.y = 0.5
	else:
		result.y = clampf(result.y, min_point.y, max_point.y)
	return result


static func rect_for(id: String, entry: Dictionary, viewport: Vector2 = DESIGN_SIZE) -> Rect2:
	var scale := clampf(float(entry.get("scale", 1.0)), SCALE_MIN, SCALE_MAX)
	var ratio := Vector2(maxf(viewport.x, 1.0), maxf(viewport.y, 1.0)) / DESIGN_SIZE
	var half := base_size(id) * scale * 0.5 * ratio
	var raw_position = entry.get("position", Vector2.ZERO)
	var normalized := Vector2.ZERO
	if raw_position is Vector2:
		normalized = raw_position
	elif raw_position is Array and (raw_position as Array).size() == 2:
		normalized = Vector2(float(raw_position[0]), float(raw_position[1]))
	var center := normalized * viewport
	var inset := Vector2(SAFE_INSET * viewport.x, SAFE_INSET * viewport.y)
	var min_center := inset + half
	var max_center := viewport - inset - half
	if max_center.x > min_center.x:
		center.x = clampf(center.x, min_center.x, max_center.x)
	else:
		center.x = viewport.x * 0.5
	if max_center.y > min_center.y:
		center.y = clampf(center.y, min_center.y, max_center.y)
	else:
		center.y = viewport.y * 0.5
	return Rect2(center - half, half * 2.0)


static func _is_number(value) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func reset(profile_id: String = PROFILE_DIESTRO) -> void:
	profile = profile_id if PROFILES.has(profile_id) else PROFILE_DIESTRO
	controls = default_profile_data(profile)
	look_sensitivity = DEFAULT_SENSITIVITY
	move_deadzone = DEFAULT_DEADZONE


func to_dict() -> Dictionary:
	var serialized := {}
	for id in CONTROL_IDS:
		var entry: Dictionary = controls[id]
		var pos: Vector2 = entry["position"]
		serialized[id] = {
			"position": [pos.x, pos.y],
			"scale": float(entry["scale"]),
			"opacity": float(entry["opacity"]),
			"visible": bool(entry["visible"]),
			"side": str(entry["side"]),
		}
	return {
		"version": VERSION,
		"profile": profile,
		"controls": serialized,
		"look_sensitivity": look_sensitivity,
		"move_deadzone": move_deadzone,
	}


func parse(data) -> Dictionary:
	var errors: Array = []
	var result := {"ok": false, "errors": errors, "config": {}}
	if not (data is Dictionary):
		errors.append("config no es Dictionary")
		return result
	var source: Dictionary = data
	if int(source.get("version", -1)) != VERSION:
		errors.append("version incompatible")
		return result
	var profile_id := str(source.get("profile", ""))
	if not PROFILES.has(profile_id):
		errors.append("perfil desconocido")
		return result
	var source_controls = source.get("controls")
	if not (source_controls is Dictionary):
		errors.append("controles ausentes")
		return result
	for key in (source_controls as Dictionary).keys():
		if not CONTROL_IDS.has(str(key)):
			errors.append("control desconocido: %s" % str(key))
	for id in CONTROL_IDS:
		if not (source_controls as Dictionary).has(id):
			errors.append("control ausente: %s" % id)
			continue
		var entry = (source_controls as Dictionary)[id]
		if not (entry is Dictionary):
			errors.append("entrada invalida: %s" % id)
			continue
		var raw_pos = (entry as Dictionary).get("position")
		if not (raw_pos is Array) or (raw_pos as Array).size() != 2:
			errors.append("posicion invalida: %s" % id)
			continue
		if not _is_number((raw_pos as Array)[0]) or not _is_number((raw_pos as Array)[1]):
			errors.append("posicion no numerica: %s" % id)
			continue
		var pos := Vector2(float((raw_pos as Array)[0]), float((raw_pos as Array)[1]))
		var scale = (entry as Dictionary).get("scale")
		var opacity = (entry as Dictionary).get("opacity")
		var visible = (entry as Dictionary).get("visible")
		var side = (entry as Dictionary).get("side")
		if not _is_number(scale) or float(scale) < SCALE_MIN or float(scale) > SCALE_MAX:
			errors.append("escala fuera de rango: %s" % id)
			continue
		if not _is_number(opacity) or float(opacity) < OPACITY_MIN or float(opacity) > OPACITY_MAX:
			errors.append("opacidad fuera de rango: %s" % id)
			continue
		if typeof(visible) != TYPE_BOOL:
			errors.append("visibilidad invalida: %s" % id)
			continue
		if not (side is String) or not SIDES.has(str(side)):
			errors.append("lado invalido: %s" % id)
			continue
		if clamp_position(id, pos, float(scale)).distance_to(pos) > 0.0001:
			errors.append("control fuera de la zona segura: %s" % id)
			continue
		result.config[id] = {
			"position": pos,
			"scale": float(scale),
			"opacity": float(opacity),
			"visible": bool(visible),
			"side": str(side),
		}
	var sensitivity = source.get("look_sensitivity")
	var deadzone = source.get("move_deadzone")
	if not _is_number(sensitivity) or float(sensitivity) < SENSITIVITY_MIN or float(sensitivity) > SENSITIVITY_MAX:
		errors.append("sensibilidad fuera de rango")
	if not _is_number(deadzone) or float(deadzone) < DEADZONE_MIN or float(deadzone) > DEADZONE_MAX:
		errors.append("zona muerta fuera de rango")
	if result.config.size() != CONTROL_IDS.size():
		errors.append("controles incompletos")
	if errors.is_empty() and _has_overlap(result.config):
		errors.append("controles solapados")
	if not errors.is_empty():
		return result
	result.config = {
		"profile": profile_id,
		"controls": result.config,
		"look_sensitivity": float(sensitivity),
		"move_deadzone": float(deadzone),
	}
	result.ok = true
	return result


func from_dict(data) -> bool:
	var checked := parse(data)
	if not bool(checked["ok"]):
		reset()
		return false
	profile = str(checked["config"]["profile"])
	controls = checked["config"]["controls"]
	look_sensitivity = float(checked["config"]["look_sensitivity"])
	move_deadzone = float(checked["config"]["move_deadzone"])
	return true


func save_to_disk(path: String = "") -> bool:
	var target := path if not path.is_empty() else save_path
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "", false))
	file.flush()
	file.close()
	return true


func load_from_disk(path: String = "") -> bool:
	var target := path if not path.is_empty() else save_path
	if not FileAccess.file_exists(target):
		reset()
		return false
	var file := FileAccess.open(target, FileAccess.READ)
	if file == null:
		reset()
		return false
	var length := file.get_length()
	if length > MAX_FILE_BYTES:
		file.close()
		reset()
		return false
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		reset()
		return false
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		reset()
		return false
	return from_dict(parsed)


func set_profile(profile_id: String) -> void:
	if not PROFILES.has(profile_id):
		return
	profile = profile_id
	controls = default_profile_data(profile_id)


func position(id: String) -> Vector2:
	if not controls.has(id):
		return Vector2.ZERO
	return (controls[id] as Dictionary)["position"]


func rect(id: String, viewport: Vector2 = DESIGN_SIZE) -> Rect2:
	if not controls.has(id):
		return Rect2()
	return rect_for(id, controls[id], viewport)


func entry(id: String) -> Dictionary:
	if not controls.has(id):
		return {}
	return (controls[id] as Dictionary).duplicate(true)


func set_position(id: String, pos: Vector2) -> void:
	if not controls.has(id):
		return
	var item: Dictionary = controls[id]
	item["position"] = clamp_position(id, pos, float(item["scale"]))
	controls[id] = item
	_resolve_overlaps()


func set_control_scale(id: String, value: float) -> void:
	if not controls.has(id):
		return
	var item: Dictionary = controls[id]
	var scale := clampf(value, SCALE_MIN, SCALE_MAX)
	item["scale"] = scale
	item["position"] = clamp_position(id, item["position"], scale)
	controls[id] = item
	_resolve_overlaps()


func set_control_opacity(id: String, value: float) -> void:
	if not controls.has(id):
		return
	var item: Dictionary = controls[id]
	item["opacity"] = clampf(value, OPACITY_MIN, OPACITY_MAX)
	controls[id] = item


func set_control_visible(id: String, value: bool) -> void:
	if not controls.has(id):
		return
	var item: Dictionary = controls[id]
	item["visible"] = value
	controls[id] = item


func set_control_side(id: String, side: String) -> void:
	if not controls.has(id) or not SIDES.has(side):
		return
	var item: Dictionary = controls[id]
	item["side"] = side
	controls[id] = item


func set_look_sensitivity(value: float) -> void:
	look_sensitivity = clampf(value, SENSITIVITY_MIN, SENSITIVITY_MAX)


func set_move_deadzone(value: float) -> void:
	move_deadzone = clampf(value, DEADZONE_MIN, DEADZONE_MAX)


static func _has_overlap(config: Dictionary) -> bool:
	for i in range(CONTROL_IDS.size()):
		for j in range(i + 1, CONTROL_IDS.size()):
			var a := rect_for(CONTROL_IDS[i], config[CONTROL_IDS[i]])
			var b := rect_for(CONTROL_IDS[j], config[CONTROL_IDS[j]])
			if a.grow(-1.0).intersects(b.grow(-1.0)):
				return true
	return false


func _overlap_count(id: String, pos: Vector2, scale: float) -> int:
	var trial := rect_for(id, {"position": pos, "scale": scale}).grow(-1.0)
	var count := 0
	for other in CONTROL_IDS:
		var other_id: String = other
		if other_id == id:
			continue
		if rect(other_id).grow(-1.0).intersects(trial):
			count += 1
	return count


func _resolve_overlaps() -> void:
	for _pass in range(16):
		var moved := false
		for i in range(CONTROL_IDS.size()):
			for j in range(i + 1, CONTROL_IDS.size()):
				var a_id: String = CONTROL_IDS[i]
				var b_id: String = CONTROL_IDS[j]
				var a := rect(a_id)
				var b := rect(b_id)
				if not a.grow(-1.0).intersects(b.grow(-1.0)):
					continue
				var shift_x := a.end.x - b.position.x
				var alt_x := a.position.x - b.end.x
				if absf(alt_x) < absf(shift_x):
					shift_x = alt_x
				var shift_y := a.end.y - b.position.y
				var alt_y := a.position.y - b.end.y
				if absf(alt_y) < absf(shift_y):
					shift_y = alt_y
				var x_delta := Vector2(shift_x + (SEPARATION if shift_x > 0.0 else -SEPARATION), 0.0)
				var y_delta := Vector2(0.0, shift_y + (SEPARATION if shift_y > 0.0 else -SEPARATION))
				var best_score := 1.0e12
				var best_id := ""
				var best_pos := Vector2.ZERO
				for item_id in [b_id, a_id]:
					var target_id: String = item_id
					var other_id: String = a_id if target_id == b_id else b_id
					var other_rect := rect(other_id)
					var item: Dictionary = controls[target_id]
					var base_pos: Vector2 = item["position"]
					var scale := float(item["scale"])
					var deltas: Array = [x_delta, y_delta] if target_id == b_id else [-x_delta, -y_delta]
					for candidate_delta in deltas:
						var delta: Vector2 = candidate_delta
						if absf(delta.x) + absf(delta.y) < 0.001:
							continue
						var candidate := clamp_position(target_id, base_pos + delta / DESIGN_SIZE, scale)
						var candidate_rect := rect_for(target_id, {"position": candidate, "scale": scale})
						if candidate_rect.grow(-1.0).intersects(other_rect.grow(-1.0)):
							continue
						var score := float(_overlap_count(target_id, candidate, scale) * 1000) + absf(delta.x) + absf(delta.y)
						if score < best_score:
							best_score = score
							best_id = target_id
							best_pos = candidate
				if best_id.is_empty():
					continue
				var best_item: Dictionary = controls[best_id]
				best_item["position"] = best_pos
				controls[best_id] = best_item
				moved = true
		if not moved:
			break
