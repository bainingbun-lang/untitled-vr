class_name VRActionMap extends RefCounted

const VERSION := 1
const PLATFORMS := ["quest", "pc_vr", "pc_teclado", "android_tactil"]
const ACTIONS := ["grab", "trigger", "teleport", "menu", "move", "run"]
const KINDS := ["button", "axis", "key", "touch", "gesture"]
const HANDS := ["left", "right", "any"]
const BINDING_KEYS := ["kind", "device", "id", "hand", "source_action", "threshold"]
const PROFILE_KEYS := ["version", "platform", "bindings"]
const EVENT_KEYS := ["platform", "kind", "device", "id", "hand", "pressed", "value"]

const DEFAULT_BINDINGS := {
	"quest": {
"grab": {"kind": "button", "device": "quest_controller", "id": "grip", "hand": "left", "source_action": "squeeze", "threshold": 0.5},
	"trigger": {"kind": "button", "device": "quest_controller", "id": "trigger", "hand": "any", "source_action": "trigger", "threshold": 0.5},
	"teleport": {"kind": "button", "device": "quest_controller", "id": "thumbstick_press", "hand": "right", "source_action": "teleport", "threshold": 0.5},
	"menu": {"kind": "button", "device": "quest_controller", "id": "menu", "hand": "left", "source_action": "menu", "threshold": 0.5},
	"move": {"kind": "axis", "device": "quest_controller", "id": "thumbstick", "hand": "left", "source_action": "move", "threshold": 0.25},
	"run": {"kind": "button", "device": "quest_controller", "id": "thumbstick_press", "hand": "left", "source_action": "run", "threshold": 0.5},
},
	"pc_vr": {
		"grab": {"kind": "button", "device": "pc_vr_controller", "id": "grip", "hand": "left", "source_action": "squeeze", "threshold": 0.5},
		"trigger": {"kind": "button", "device": "pc_vr_controller", "id": "trigger", "hand": "any", "source_action": "trigger", "threshold": 0.5},
		"teleport": {"kind": "button", "device": "pc_vr_controller", "id": "thumbstick_press", "hand": "right", "source_action": "teleport", "threshold": 0.5},
		"menu": {"kind": "button", "device": "pc_vr_controller", "id": "menu", "hand": "left", "source_action": "menu", "threshold": 0.5},
		"move": {"kind": "axis", "device": "pc_vr_controller", "id": "thumbstick", "hand": "left", "source_action": "move", "threshold": 0.25},
		"run": {"kind": "button", "device": "pc_vr_controller", "id": "thumbstick_press", "hand": "left", "source_action": "run", "threshold": 0.5},
	},
	"pc_teclado": {
		"grab": {"kind": "key", "device": "keyboard", "id": "E", "hand": "any", "source_action": "", "threshold": 0.5},
		"trigger": {"kind": "key", "device": "keyboard", "id": "F", "hand": "any", "source_action": "", "threshold": 0.5},
		"teleport": {"kind": "key", "device": "keyboard", "id": "T", "hand": "any", "source_action": "", "threshold": 0.5},
		"menu": {"kind": "key", "device": "keyboard", "id": "Escape", "hand": "any", "source_action": "", "threshold": 0.5},
		"move": {"kind": "axis", "device": "keyboard", "id": "WASD", "hand": "any", "source_action": "", "threshold": 0.25},
		"run": {"kind": "key", "device": "keyboard", "id": "Shift", "hand": "any", "source_action": "", "threshold": 0.5},
	},
	"android_tactil": {
		"grab": {"kind": "touch", "device": "touchscreen", "id": "grab_pad", "hand": "left", "source_action": "", "threshold": 0.5},
		"trigger": {"kind": "touch", "device": "touchscreen", "id": "trigger_pad", "hand": "right", "source_action": "", "threshold": 0.5},
		"teleport": {"kind": "touch", "device": "touchscreen", "id": "teleport_pad", "hand": "right", "source_action": "", "threshold": 0.5},
		"menu": {"kind": "touch", "device": "touchscreen", "id": "menu_button", "hand": "any", "source_action": "", "threshold": 0.5},
		"move": {"kind": "axis", "device": "touchscreen", "id": "move_stick", "hand": "left", "source_action": "", "threshold": 0.25},
		"run": {"kind": "touch", "device": "touchscreen", "id": "run_pad", "hand": "left", "source_action": "", "threshold": 0.5},
	},
}

var _profile: Dictionary = {}


func _init(platform: String = "quest") -> void:
	var chosen := platform
	if not PLATFORMS.has(chosen):
		chosen = "quest"
	_profile = default_profile(chosen)


func default_bindings(platform: String) -> Dictionary:
	var source = DEFAULT_BINDINGS.get(platform, null)
	if source is Dictionary:
		return _copy(source)
	return {}


func default_profile(platform: String) -> Dictionary:
	if not PLATFORMS.has(platform):
		return {}
	var checked := validate_profile({
		"version": VERSION,
		"platform": platform,
		"bindings": default_bindings(platform),
	})
	if bool(checked["ok"]):
		return checked["profile"]
	return {}


func platform() -> String:
	return str(_profile.get("platform", ""))


func profile() -> Dictionary:
	return _copy(_profile)


func configure(candidate) -> bool:
	var checked := validate_profile(candidate)
	if not bool(checked["ok"]):
		return false
	_profile = checked["profile"]
	return true


func to_dictionary(candidate = null) -> Dictionary:
	var checked := validate_profile(_profile if candidate == null else candidate)
	if bool(checked["ok"]):
		return _copy(checked["profile"])
	return {}


func from_dictionary(data) -> Dictionary:
	return to_dictionary(data)


func validate_profile(data) -> Dictionary:
	var result := {"ok": false, "errors": [], "profile": {}}
	var errors: Array[String] = []
	if not (data is Dictionary):
		errors.append("perfil no es Dictionary")
		result["errors"] = errors
		return result
	if not _exact_keys(data, PROFILE_KEYS):
		errors.append("perfil: claves exactas version, platform, bindings")
		return _finish_profile_validation(result, errors, {})
	var version = data["version"]
	if typeof(version) != TYPE_INT or int(version) != VERSION:
		errors.append("version de perfil no soportada")
	var name = data["platform"]
	if typeof(name) != TYPE_STRING or not PLATFORMS.has(name):
		errors.append("plataforma desconocida")
	var bindings = data["bindings"]
	if not (bindings is Dictionary):
		errors.append("bindings no es Dictionary")
		result["errors"] = errors
		return result
	if not _exact_keys(bindings, ACTIONS):
		errors.append("bindings: claves exactas " + ", ".join(ACTIONS))
		result["errors"] = errors
		return result

	var canonical_bindings := {}
	var signatures := {}
	for action in ACTIONS:
		var binding_check := validate_binding(bindings[action])
		if not bool(binding_check["ok"]):
			for error in binding_check["errors"]:
				errors.append("%s: %s" % [action, error])
			continue
		var canonical: Dictionary = binding_check["binding"]
		var key := signature(canonical)
		if signatures.has(key):
			errors.append("conflicto: %s y %s comparten entrada" % [str(signatures[key]), action])
		else:
			signatures[key] = action
		canonical_bindings[action] = canonical

	var canonical_profile := {}
	for key in PROFILE_KEYS:
		match key:
			"version":
				canonical_profile[key] = VERSION
			"platform":
				canonical_profile[key] = name if (typeof(name) == TYPE_STRING and PLATFORMS.has(name)) else ""
			"bindings":
				canonical_profile[key] = canonical_bindings
	if not errors.is_empty():
		return _finish_profile_validation(result, errors, {})
	return _finish_profile_validation(result, errors, canonical_profile)


func validate_binding(data) -> Dictionary:
	var result := {"ok": false, "errors": [], "binding": {}}
	var errors: Array[String] = []
	if not (data is Dictionary):
		errors.append("binding no es Dictionary")
		result["errors"] = errors
		return result
	if not _exact_keys(data, BINDING_KEYS):
		errors.append("binding: claves exactas " + ", ".join(BINDING_KEYS))
		result["errors"] = errors
		return result
	var kind = data["kind"]
	if typeof(kind) != TYPE_STRING or not KINDS.has(kind):
		errors.append("kind invalido")
	var device = data["device"]
	if typeof(device) != TYPE_STRING or str(device).is_empty() or str(device).contains("|"):
		errors.append("device invalido")
	var identifier = data["id"]
	if typeof(identifier) != TYPE_STRING or str(identifier).is_empty() or str(identifier).contains("|"):
		errors.append("id invalido")
	var hand = data["hand"]
	if typeof(hand) != TYPE_STRING or not HANDS.has(hand):
		errors.append("hand invalida")
	if typeof(data["source_action"]) != TYPE_STRING:
		errors.append("source_action no es String")
	var threshold = data["threshold"]
	if not _is_number(threshold) or float(threshold) < 0.0 or float(threshold) > 1.0:
		errors.append("threshold fuera de rango")
	if not errors.is_empty():
		result["errors"] = errors
		return result
	var canonical := {}
	for key in BINDING_KEYS:
		canonical[key] = _copy(data[key])
	result["ok"] = true
	result["binding"] = canonical
	result["errors"] = errors
	return result


func signature(binding: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["kind", "device", "id", "hand"]:
		parts.append(str(binding.get(key, "")))
	return "|".join(parts)


func get_binding(action: String, candidate = null) -> Dictionary:
	var checked := validate_profile(_profile if candidate == null else candidate)
	if not bool(checked["ok"]) or not ACTIONS.has(action):
		return {}
	return _copy(checked["profile"]["bindings"][action])


func get_source_action(action: String, candidate = null) -> String:
	var binding := get_binding(action, candidate)
	return str(binding.get("source_action", ""))


func rebind(action: String, changes, allow_swap: bool = false) -> Dictionary:
	var result := rebind_profile(_profile, action, changes, allow_swap)
	if bool(result["ok"]):
		_profile = result["profile"]
	return result


func rebind_profile(candidate, action: String, changes, allow_swap: bool = false) -> Dictionary:
	var result := {"ok": false, "errors": [], "profile": {}}
	var errors: Array[String] = []
	var checked := validate_profile(candidate)
	if not bool(checked["ok"]):
		for error in checked["errors"]:
			errors.append(error)
		result["errors"] = errors
		return result
	if not ACTIONS.has(action):
		errors.append("accion desconocida: " + action)
		result["errors"] = errors
		return result
	if not (changes is Dictionary):
		errors.append("cambios no es Dictionary")
		result["errors"] = errors
		return result
	for key in changes.keys():
		if typeof(key) != TYPE_STRING or not BINDING_KEYS.has(key):
			errors.append("clave de binding desconocida: " + str(key))
	if not errors.is_empty():
		result["errors"] = errors
		return result

	var current: Dictionary = checked["profile"]
	var merged: Dictionary = _copy(current["bindings"][action])
	for key in changes.keys():
		merged[key] = _copy(changes[key])
	var binding_check := validate_binding(merged)
	if not bool(binding_check["ok"]):
		for error in binding_check["errors"]:
			errors.append(error)
		result["errors"] = errors
		return result

	var bindings: Dictionary = _copy(current["bindings"])
	var new_signature := signature(binding_check["binding"])
	var conflicting := ""
	for other in ACTIONS:
		if other == action:
			continue
		if signature(bindings[other]) == new_signature:
			conflicting = other
			break
	if not conflicting.is_empty():
		if not allow_swap:
			errors.append("conflicto: %s ya usa esa entrada" % conflicting)
			result["errors"] = errors
			return result
		bindings[action] = binding_check["binding"]
		bindings[conflicting] = _copy(current["bindings"][action])
	else:
		bindings[action] = binding_check["binding"]

	var final_check := validate_profile({
		"version": VERSION,
		"platform": current["platform"],
		"bindings": bindings,
	})
	if not bool(final_check["ok"]):
		for error in final_check["errors"]:
			errors.append(error)
		result["errors"] = errors
		return result
	result["ok"] = true
	result["profile"] = final_check["profile"]
	result["errors"] = errors
	return result


func validate_event(event) -> Dictionary:
	var result := {"ok": false, "errors": [], "event": {}}
	var errors: Array[String] = []
	if not (event is Dictionary):
		errors.append("evento no es Dictionary")
		result["errors"] = errors
		return result
	for key in ["kind", "device", "id"]:
		if not event.has(key) or typeof(event[key]) != TYPE_STRING or str(event[key]).is_empty():
			errors.append("evento: %s invalido" % key)
	if event.has("platform") and typeof(event["platform"]) != TYPE_STRING:
		errors.append("evento: platform no es String")
	if event.has("hand") and (typeof(event["hand"]) != TYPE_STRING or not HANDS.has(event["hand"])):
		errors.append("evento: hand invalida")
	if event.has("pressed") and typeof(event["pressed"]) != TYPE_BOOL:
		errors.append("evento: pressed no es bool")
	if event.has("value") and not (_is_number(event["value"]) or event["value"] is Vector2):
		errors.append("evento: value no es numerico ni Vector2")
	if not errors.is_empty():
		result["errors"] = errors
		return result
	var canonical := {}
	for key in EVENT_KEYS:
		if event.has(key):
			canonical[key] = _copy(event[key])
	result["ok"] = true
	result["event"] = canonical
	result["errors"] = errors
	return result


func resolve(action: String, event, candidate = null) -> Dictionary:
	var result := {"ok": false, "matched": false, "value": 0.0, "binding": {}, "errors": []}
	var errors: Array[String] = []
	var checked := validate_profile(_profile if candidate == null else candidate)
	if not bool(checked["ok"]):
		for error in checked["errors"]:
			errors.append(error)
		result["errors"] = errors
		return result
	if not ACTIONS.has(action):
		errors.append("accion desconocida: " + action)
		result["errors"] = errors
		return result
	var event_check := validate_event(event)
	if not bool(event_check["ok"]):
		for error in event_check["errors"]:
			errors.append(error)
		result["errors"] = errors
		return result

	result["ok"] = true
	result["errors"] = errors
	var binding: Dictionary = checked["profile"]["bindings"][action]
	result["binding"] = _copy(binding)
	var source: Dictionary = event_check["event"]
	if source.has("platform") and str(source["platform"]) != str(checked["profile"]["platform"]):
		return result
	if str(source["kind"]) != str(binding["kind"]):
		return result
	if str(source["device"]) != str(binding["device"]):
		return result
	if str(source["id"]) != str(binding["id"]):
		return result
	var binding_hand := str(binding["hand"])
	var source_hand := str(source.get("hand", "any"))
	if binding_hand != "any" and source_hand != "any" and binding_hand != source_hand:
		return result

	var threshold := float(binding["threshold"])
	var magnitude := -1.0
	if str(binding["kind"]) == "axis":
		if source.has("value"):
			magnitude = _magnitude(source["value"])
		elif source.has("pressed") and bool(source["pressed"]):
			magnitude = 1.0
	else:
		if source.has("pressed"):
			if not bool(source["pressed"]):
				return result
			magnitude = 1.0
		elif source.has("value"):
			magnitude = _magnitude(source["value"])
		else:
			magnitude = 1.0
	if magnitude + 0.000001 < threshold:
		return result
	result["matched"] = true
	result["value"] = _copy(source["value"]) if source.has("value") else 1.0
	return result


func action_from_event(event, candidate = null) -> String:
	for action in ACTIONS:
		var result := resolve(action, event, candidate)
		if bool(result["ok"]) and bool(result["matched"]):
			return action
	return ""


func _finish_profile_validation(result: Dictionary, errors: Array, canonical_profile: Dictionary) -> Dictionary:
	result["errors"] = errors
	if errors.is_empty():
		result["ok"] = true
		result["profile"] = canonical_profile
	return result


func _exact_keys(data: Dictionary, expected: Array) -> bool:
	if data.size() != expected.size():
		return false
	for key in expected:
		if not data.has(key):
			return false
	return true


func _is_number(value) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _magnitude(value) -> float:
	if value is Vector2:
		return (value as Vector2).length()
	if _is_number(value):
		return absf(float(value))
	return -1.0


func _copy(value) -> Variant:
	if value is Dictionary:
		return value.duplicate(true)
	if value is Array:
		return value.duplicate(true)
	return value


class InputSourceAdapter extends RefCounted:
	var source = null
	var _map = null

	func _init(input_source = null, action_map = null) -> void:
		source = input_source
		_map = action_map

	func configure(action_map) -> void:
		_map = action_map

	func get_pose(hand: String) -> Transform3D:
		if source != null and source.has_method("get_pose"):
			return source.get_pose(hand)
		return Transform3D.IDENTITY

	func is_pressed(action: String) -> bool:
		if _map == null:
			return false
		var source_action: String = str(_map.get_source_action(action))
		if source_action.is_empty():
			return false
		if source == null or not source.has_method("is_pressed"):
			return false
		return bool(source.is_pressed(source_action))

	func is_tracking(hand: String) -> bool:
		if source != null and source.has_method("is_tracking"):
			return bool(source.is_tracking(hand))
		return false

	func get_joint(hand: String, joint: String) -> Transform3D:
		if source != null and source.has_method("get_joint"):
			return source.get_joint(hand, joint)
		return Transform3D.IDENTITY
