class_name WorldSpawner
extends RefCounted

const NPCStateMachineScript = preload("res://core/npc/npc_state_machine.gd")
const NPCPersonalityScript = preload("res://core/npc/npc_personality.gd")
const NPCNeedsScript = preload("res://core/npc/npc_needs.gd")
const NPCMemoryScript = preload("res://core/npc/npc_memory.gd")
const NPCRoutineScript = preload("res://core/npc/npc_routine.gd")
const NPCControllerScript = preload("res://core/npc/npc_controller.gd")

const PLATFORM_LIMITS := {"android": 8, "pc": 32, "vr": 16}
const DEFAULT_LIMIT: int = 8
const DEFAULT_PLATFORM: String = "pc"
const PLATFORM_ALIASES := {
	"android": "android",
	"mobile": "android",
	"movil": "android",
	"celular": "android",
	"pc": "pc",
	"windows": "pc",
	"desktop": "pc",
	"linux": "pc",
	"escritorio": "pc",
	"vr": "vr",
	"quest": "vr",
	"oculus": "vr",
}
const PERSONALITY_FIELDS: Array = [
	"temperament", "confidence", "bravery", "fear", "curiosity", "sociability", "aggressiveness",
]
const NEEDS_FIELDS: Array = ["fatigue", "stress", "fear", "confusion", "stun", "health"]
const LIMIT_FIELDS: Array = ["max_npcs", "max_npcs_per_platform", "npc_limit", "npcs_max"]


class SpawnedNPC extends RefCounted:
	var id: String = ""
	var spawn_index: int = 0
	var spawn_point: Vector3 = Vector3.ZERO
	var platform: String = ""
	var state_machine = null
	var personality = null
	var needs = null
	var memory = null
	var routine = null
	var controller = null

	func to_dict() -> Dictionary:
		var state := ""
		if state_machine != null and state_machine.has_method("get_state"):
			state = str(state_machine.get_state())
		var needs_data := {}
		for key in ["fatigue", "stress", "fear", "confusion", "stun", "health"]:
			needs_data[key] = float(needs.get(key)) if needs != null else 0.0
		var personality_data := {}
		for key in [
			"temperament", "confidence", "bravery", "fear", "curiosity", "sociability", "aggressiveness",
		]:
			personality_data[key] = float(personality.get(key)) if personality != null else 0.5
		var stops: Array = []
		if routine != null:
			stops = routine.patrol_waypoints.duplicate(true)
		return {
			"id": id,
			"spawn_index": spawn_index,
			"spawn_point": spawn_point,
			"platform": platform,
			"state": state,
			"needs": needs_data,
			"personality": personality_data,
			"routine": stops,
		}

	func _to_string() -> String:
		return "SpawnedNPC(%s)" % str(to_dict())


func spawn(map_meta: Dictionary, npc_defs: Array, seed: int) -> Dictionary:
	var report := {"spawned": [], "rejected": []}
	var points := _spawn_points(map_meta)
	if points.is_empty():
		for i in range(npc_defs.size()):
			report["rejected"].append(_reject(i, _peek_id(npc_defs[i]), "mapa sin spawn points"))
		return report

	var declarations := _map_platforms(map_meta)
	var primary := _primary_platform(map_meta, declarations)
	var seen_ids := {}
	var remaining := {}
	var accepted: Array = []

	for i in range(npc_defs.size()):
		var parsed := _parse_def(npc_defs[i], i, primary, declarations, seen_ids)
		if not bool(parsed["ok"]):
			report["rejected"].append(_reject(i, str(parsed["id"]), str(parsed["reason"])))
			continue
		var record: Dictionary = parsed["record"]
		var platform: String = str(record["platform"])
		if not remaining.has(platform):
			remaining[platform] = get_platform_limit(map_meta, platform)
		if int(remaining[platform]) <= 0:
			var reason := "limite de NPCs por plataforma '%s' alcanzado (%d)" % [
				platform, get_platform_limit(map_meta, platform),
			]
			report["rejected"].append(_reject(i, str(record["id"]), reason))
			continue
		remaining[platform] = int(remaining[platform]) - 1
		seen_ids[str(record["id"])] = true
		accepted.append(record)

	var order: Array = []
	for i in range(accepted.size()):
		order.append(i)
	var shuffled_points := points.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if order.size() > 1:
		_shuffle(order, rng)
	if shuffled_points.size() > 1:
		_shuffle(shuffled_points, rng)

	for position in range(order.size()):
		var entry: Dictionary = accepted[int(order[position])]
		var spawn_index: int = position % shuffled_points.size()
		var point: Vector3 = shuffled_points[spawn_index]
		var npc := _build_npc(entry, point, spawn_index)
		var snapshot: Dictionary = npc.to_dict()
		report["spawned"].append({
			"id": str(entry["id"]),
			"index": int(entry["index"]),
			"spawn_index": spawn_index,
			"spawn_point": point,
			"position": point,
			"platform": str(entry["platform"]),
			"state": str(snapshot["state"]),
			"needs": snapshot["needs"],
			"personality": snapshot["personality"],
			"routine": snapshot["routine"],
			"npc": npc,
		})

	return report


func get_platform_limit(map_meta: Dictionary, platform: String) -> int:
	var key := _normalize_platform(platform)
	if key.is_empty():
		key = DEFAULT_PLATFORM
	var limit := int(PLATFORM_LIMITS.get(key, DEFAULT_LIMIT))
	var profiles = map_meta.get("performance_profiles", null)
	if profiles is Dictionary:
		for alias in _aliases_for(key):
			if not profiles.has(alias):
				continue
			var profile = profiles[alias]
			if profile is Dictionary:
				for field in LIMIT_FIELDS:
					if profile.has(field):
						limit = mini(limit, _non_negative_int(profile[field], limit))
		for field in LIMIT_FIELDS:
			if profiles.has(field):
				limit = mini(limit, _non_negative_int(profiles[field], limit))
	for field in LIMIT_FIELDS:
		if map_meta.has(field):
			limit = mini(limit, _non_negative_int(map_meta[field], limit))
	return maxi(0, limit)


func _build_npc(entry: Dictionary, point: Vector3, spawn_index: int) -> SpawnedNPC:
	var needs = NPCNeedsScript.new()
	var needs_data: Dictionary = entry["needs"]
	if needs_data.has("fatigue"):
		needs.change_fatigue(float(needs_data["fatigue"]))
	if needs_data.has("stress"):
		needs.change_stress(float(needs_data["stress"]))
	if needs_data.has("fear"):
		needs.change_fear(float(needs_data["fear"]))
	if needs_data.has("confusion"):
		needs.change_confusion(float(needs_data["confusion"]))
	if needs_data.has("stun"):
		needs.change_stun(float(needs_data["stun"]))
	if needs_data.has("health"):
		needs.change_health(float(needs_data["health"]))

	var personality = NPCPersonalityScript.new(entry["personality"])
	var routine = NPCRoutineScript.new((entry["routine"] as Array).duplicate(true))
	var memory = NPCMemoryScript.new()
	var state_machine = NPCStateMachineScript.new()
	var state := str(entry["state"])
	if state != "idle":
		state_machine.transition_to(state)
	if needs.stun > 0.5:
		state_machine.transition_to("stunned")
	var controller = NPCControllerScript.new(state_machine, personality, needs, memory, routine)

	var npc := SpawnedNPC.new()
	npc.id = str(entry["id"])
	npc.spawn_index = spawn_index
	npc.spawn_point = point
	npc.platform = str(entry["platform"])
	npc.state_machine = state_machine
	npc.personality = personality
	npc.needs = needs
	npc.memory = memory
	npc.routine = routine
	npc.controller = controller
	return npc


func _parse_def(
	value: Variant,
	index: int,
	primary: String,
	declarations: Array,
	seen_ids: Dictionary
) -> Dictionary:
	var result := {"ok": false, "record": {}, "reason": "", "id": ""}
	if not (value is Dictionary):
		result["reason"] = "definicion invalida: se esperaba un Dictionary"
		return result

	var raw: Dictionary = value
	var id := _as_id(_first(raw, ["id", "npc_id", "name"]))
	result["id"] = id
	if id.is_empty():
		result["reason"] = "id obligatorio ausente o invalido"
		return result
	if seen_ids.has(id):
		result["reason"] = "id duplicado: " + id
		return result

	var errors: Array = []
	var platform := primary
	var platform_value = _first(raw, ["platform", "plataforma"])
	if platform_value != null:
		platform = _normalize_platform(platform_value)
		if platform.is_empty():
			errors.append("plataforma desconocida: " + str(platform_value))
		elif not declarations.is_empty() and not declarations.has(platform):
			errors.append("plataforma '%s' no declarada por el mapa" % platform)

	var personality := _parse_personality(_first(raw, ["personality", "personalidad"]), errors)
	var needs := _parse_needs(_first(raw, ["needs", "necesidades"]), errors)
	var routine := _parse_routine(_first(raw, ["routine", "rutina", "stops"]), errors)
	var state := "idle"
	var state_value = _first(raw, ["state", "estado"])
	if state_value != null:
		state = str(state_value)
		if not NPCStateMachineScript.VALID_STATES.has(state):
			errors.append("state desconocido: " + state)

	if not errors.is_empty():
		result["reason"] = str(errors[0])
		return result

	result["ok"] = true
	result["record"] = {
		"id": id,
		"index": index,
		"platform": platform,
		"personality": personality,
		"needs": needs,
		"routine": routine,
		"state": state,
	}
	return result


static func _parse_personality(value: Variant, errors: Array) -> Dictionary:
	var result := {}
	if value == null:
		return result
	if not (value is Dictionary):
		errors.append("personality: se esperaba un Dictionary")
		return result
	var raw: Dictionary = value
	for key in PERSONALITY_FIELDS:
		if not raw.has(key):
			continue
		var parsed: Variant = _as_number(raw[key])
		if parsed == null:
			errors.append("personality.%s: numero invalido" % key)
			continue
		result[key] = parsed
	return result


static func _parse_needs(value: Variant, errors: Array) -> Dictionary:
	var result := {}
	if value == null:
		return result
	if not (value is Dictionary):
		errors.append("needs: se esperaba un Dictionary")
		return result
	var raw: Dictionary = value
	for key in NEEDS_FIELDS:
		if not raw.has(key):
			continue
		var parsed: Variant = _as_number(raw[key])
		if parsed == null:
			errors.append("needs.%s: numero invalido" % key)
			continue
		result[key] = parsed
	return result


static func _parse_routine(value: Variant, errors: Array) -> Array:
	var result: Array = []
	if value == null:
		return result
	var raw: Array = []
	if value is Array:
		raw = value
	elif value is Dictionary:
		var source: Dictionary = value
		if source.has("stops") and source["stops"] is Array:
			raw = source["stops"]
		elif source.has("waypoint_id") or source.has("id"):
			raw = [value]
		else:
			errors.append("routine: se esperaban stops o waypoint_id")
			return result
	else:
		errors.append("routine: se esperaba un Array")
		return result

	for item in raw:
		if not (item is Dictionary):
			errors.append("routine: cada parada debe ser un Dictionary")
			continue
		var stop: Dictionary = item
		var waypoint := _as_id(_first(stop, ["waypoint_id", "id", "name"]))
		if waypoint.is_empty():
			errors.append("routine: waypoint_id obligatorio")
			continue
		var duration := 1.0
		if stop.has("duration"):
			var parsed: Variant = _as_number(stop["duration"])
			if parsed == null or float(parsed) < 0.0:
				errors.append("routine.duration: numero invalido")
				continue
			duration = float(parsed)
		result.append({"waypoint_id": waypoint, "duration": duration})
	return result


static func _shuffle(values: Array, rng: RandomNumberGenerator) -> Array:
	for i in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temporary: Variant = values[i]
		values[i] = values[j]
		values[j] = temporary
	return values


static func _spawn_points(map_meta: Dictionary) -> Array:
	var raw = map_meta.get("spawn_points", [])
	if not (raw is Array):
		return []
	var result: Array = []
	for item in raw:
		var point: Variant = _as_point(item)
		if point != null:
			result.append(point)
	return result


static func _as_point(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR3:
			return value
		TYPE_VECTOR3I:
			var point: Vector3i = value
			return Vector3(point)
		TYPE_VECTOR2:
			var point: Vector2 = value
			return Vector3(point.x, 0.0, point.y)
		TYPE_VECTOR2I:
			var point: Vector2i = value
			return Vector3(float(point.x), 0.0, float(point.y))
		TYPE_ARRAY:
			var values: Array = value
			if values.size() < 3:
				return null
			var x: Variant = _as_number(values[0])
			var y: Variant = _as_number(values[1])
			var z: Variant = _as_number(values[2])
			if x == null or y == null or z == null:
				return null
			return Vector3(x, y, z)
		TYPE_DICTIONARY:
			var values: Dictionary = value
			if values.has("position"):
				return _as_point(values["position"])
			if values.has("point"):
				return _as_point(values["point"])
			var x: Variant = _as_number(values.get("x", 0.0))
			var y: Variant = _as_number(values.get("y", 0.0))
			var z: Variant = _as_number(values.get("z", values.get("depth", 0.0)))
			if x == null or y == null or z == null:
				return null
			return Vector3(x, y, z)
		_:
			return null


static func _map_platforms(map_meta: Dictionary) -> Array:
	var result: Array = []
	var raw = map_meta.get("platforms", null)
	if raw is String:
		raw = [raw]
	if raw is Array:
		for item in raw:
			var platform := _normalize_platform(item)
			if platform != "" and not result.has(platform):
				result.append(platform)
	var single = _first(map_meta, ["platform", "plataforma"])
	if single != null:
		var platform := _normalize_platform(single)
		if platform != "" and not result.has(platform):
			result.append(platform)
	return result


static func _primary_platform(map_meta: Dictionary, declarations: Array) -> String:
	if not declarations.is_empty():
		return str(declarations[0])
	var single = _first(map_meta, ["platform", "plataforma"])
	var platform := _normalize_platform(single)
	if platform != "":
		return platform
	return DEFAULT_PLATFORM


static func _normalize_platform(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	var text := (value as String).strip_edges().to_lower()
	if text.is_empty():
		return ""
	if PLATFORM_ALIASES.has(text):
		return str(PLATFORM_ALIASES[text])
	return ""


static func _aliases_for(platform: String) -> Array:
	var result: Array = []
	for key in PLATFORM_ALIASES.keys():
		if str(PLATFORM_ALIASES[key]) == platform:
			result.append(str(key))
	if not result.has(platform):
		result.append(platform)
	return result


static func _first(source: Dictionary, keys: Array) -> Variant:
	for key in keys:
		if source.has(key):
			return source[key]
	return null


static func _peek_id(value: Variant) -> String:
	if value is Dictionary:
		var source: Dictionary = value
		return _as_id(_first(source, ["id", "npc_id", "name"]))
	if typeof(value) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		return str(value)
	return ""


static func _as_id(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING:
			var text := (value as String).strip_edges()
			return text
		TYPE_INT, TYPE_FLOAT:
			var parsed: Variant = _as_number(value)
			if parsed != null and floorf(float(parsed)) == float(parsed):
				return str(int(parsed))
		_:
			pass
	return ""


static func _as_number(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			var number := float(value)
			if is_nan(number) or is_inf(number):
				return null
			return number
		TYPE_STRING:
			var text := (value as String).strip_edges()
			if not text.is_valid_float():
				return null
			var number := text.to_float()
			if is_nan(number) or is_inf(number):
				return null
			return number
		_:
			return null


static func _non_negative_int(value: Variant, fallback: int) -> int:
	var parsed: Variant = _as_number(value)
	if parsed == null:
		return fallback
	var number := float(parsed)
	if floorf(number) != number:
		return fallback
	return maxi(0, int(number))


static func _reject(index: int, id: String, reason: String) -> Dictionary:
	return {
		"index": index,
		"id": id,
		"reason": reason,
		"motivo": reason,
	}
