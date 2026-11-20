class_name ModHooks
extends RefCounted

const EventBusScript = preload("res://core/event_bus.gd")

const EVENTS := {
	"weapon_fired": {
		"payload": {
			"weapon_id": "", "origin": Vector3.ZERO, "direction": Vector3.FORWARD,
			"pellets": 1, "damage": 0.0, "ammo": -1, "projectile": false,
		},
		"permission": "read_events",
		"modifiable": ["damage"],
	},
	"weapon_reloaded": {
		"payload": {
			"weapon_id": "", "mag": 0, "reserve": 0, "duration": 0.0,
		},
		"permission": "read_events",
		"modifiable": [],
	},
	"weapon_jammed": {
		"payload": {"weapon_id": "", "reason": ""},
		"permission": "read_events",
		"modifiable": [],
	},
	"projectile_hit": {
		"payload": {
			"weapon_id": "", "hit": false, "position": Vector3.ZERO,
			"damage": 0.0, "distance": 0.0, "surface": "concrete",
		},
		"permission": "read_events",
		"modifiable": ["damage"],
	},
	"damage_dealt": {
		"payload": {
			"target": "", "zone": "", "amount": 0.0, "point": Vector3.ZERO,
			"source": "", "weapon_id": "", "lethal": false,
		},
		"permission": "read_events",
		"modifiable": ["amount"],
	},
	"wound_created": {
		"payload": {
			"target": "", "zone": "", "severity": 0.0, "point": Vector3.ZERO,
			"amount": 0.0,
		},
		"permission": "read_events",
		"modifiable": [],
	},
	"limb_severed": {
		"payload": {
			"target": "", "limb": "", "point": Vector3.ZERO, "severity": 0.0,
		},
		"permission": "read_events",
		"modifiable": [],
	},
	"npc_spawned": {
		"payload": {
			"npc_id": "", "npc_type": "", "position": Vector3.ZERO, "faction": "",
		},
		"permission": "read_events",
		"modifiable": [],
	},
	"npc_died": {
		"payload": {
			"npc_id": "", "npc_type": "", "killer": "", "position": Vector3.ZERO,
		},
		"permission": "read_events",
		"modifiable": [],
	},
	"player_died": {
		"payload": {"player_id": "", "killer": "", "position": Vector3.ZERO},
		"permission": "read_events",
		"modifiable": [],
	},
	"item_picked": {
		"payload": {
			"item_id": "", "amount": 1, "inventory_owner": "", "position": Vector3.ZERO,
		},
		"permission": "read_events",
		"modifiable": [],
	},
	"vehicle_entered": {
		"payload": {"vehicle_id": "", "player_id": "", "seats": 0},
		"permission": "read_events",
		"modifiable": [],
	},
	"map_loaded": {
		"payload": {
			"map_id": "", "map_name": "", "path": "", "seed": 0,
		},
		"permission": "read_events",
		"modifiable": [],
	},
	"wave_started": {
		"payload": {
			"wave": 0, "total_waves": 0, "mode": "", "enemy_count": 0,
		},
		"permission": "read_events",
		"modifiable": [],
	},
}

const CAPABILITIES := {
	"read_events": "Suscribirse a eventos publicos y recibir su payload",
	"modify_damage": "Modificar damage/amount en los eventos marcados como modificables",
	"spawn_entities": "Pedir al nucleo la aparicion de entidades",
	"inventory": "Leer o modificar el inventario del jugador",
	"network": "Acceso a red; siempre denegado desde el manifiesto",
}

const MODIFIABLE_EVENTS := ["weapon_fired", "projectile_hit", "damage_dealt"]
const DEFAULT_MAX_MICROS := 5000
const DEFAULT_MAX_INSTRUCTIONS := 10000
const MAX_EMIT_DEPTH := 8

static var _instance = null

var bus = null
var _permissions: Dictionary = {}
var _disabled: Dictionary = {}
var _disabled_reasons: Dictionary = {}
var _instructions: Dictionary = {}
var _max_micros: int = DEFAULT_MAX_MICROS
var _max_instructions: int = DEFAULT_MAX_INSTRUCTIONS
var _depth: int = 0


static func instance() -> ModHooks:
	if _instance == null:
		_instance = load("res://core/game/mod_hooks.gd").new()
	return _instance


static func event_spec(event: String) -> Dictionary:
	var spec: Variant = EVENTS.get(event, null)
	return spec if spec is Dictionary else {}


static func is_event(event: String) -> bool:
	return EVENTS.has(event) and EventBusScript.is_valid_event(event)


static func emit(event: String, payload: Dictionary = {}) -> Dictionary:
	return instance().emit_event(event, payload)


static func payload_for(event: String, values: Dictionary = {}) -> Dictionary:
	var spec := event_spec(event)
	var defaults: Dictionary = spec.get("payload", {})
	var result := defaults.duplicate(true)
	for key in values:
		if result.has(key):
			result[key] = _coerce(result[key], values[key])
		else:
			result[key] = values[key]
	return result


static func _coerce(default_value: Variant, value: Variant) -> Variant:
	if typeof(default_value) == typeof(value):
		return value
	match typeof(default_value):
		TYPE_STRING:
			return str(value)
		TYPE_INT:
			return int(value) if value is float or value is int or value is String else 0
		TYPE_FLOAT:
			return float(value) if value is float or value is int or value is String else 0.0
		TYPE_BOOL:
			return bool(value)
		TYPE_VECTOR3:
			return value if value is Vector3 else Vector3.ZERO
		TYPE_ARRAY:
			return value if value is Array else []
		TYPE_DICTIONARY:
			return value if value is Dictionary else {}
		_:
			return value


func configure(max_micros: int = DEFAULT_MAX_MICROS, max_instructions: int = DEFAULT_MAX_INSTRUCTIONS) -> void:
	_max_micros = maxi(max_micros, 0)
	_max_instructions = maxi(max_instructions, 1)
	if bus != null and bus.has_method("set_guard"):
		bus.set_guard(Callable(self, "_on_bus_violation"), _max_micros)


func bind(new_bus) -> void:
	bus = new_bus
	configure(_max_micros, _max_instructions)


func get_bus():
	return bus


func reset() -> void:
	bus = null
	_permissions.clear()
	_disabled.clear()
	_disabled_reasons.clear()
	_instructions.clear()
	_depth = 0


func emit_event(event: String, payload: Dictionary = {}) -> Dictionary:
	var invalid := {
		"ok": false, "handled": 0, "stopped": false,
		"errors": ["evento desconocido: '%s'" % event],
		"event": event, "payload": payload.duplicate(true),
		"modified_by": [], "violations": [],
	}
	if not is_event(event):
		return invalid
	if bus == null:
		invalid["errors"] = ["bus de mods no enlazado"]
		return invalid
	if _depth >= MAX_EMIT_DEPTH:
		invalid["errors"] = ["profundidad maxima de eventos alcanzada"]
		return invalid

	var first := _depth == 0
	if first:
		_instructions.clear()
	_depth += 1
	var normalized := payload_for(event, payload)
	var result: Dictionary = bus.emit(event, normalized)
	_depth -= 1
	result["event"] = event
	result["payload"] = normalized
	if not result.has("modified_by"):
		result["modified_by"] = []
	if not result.has("violations"):
		result["violations"] = []
	return result


func set_permissions(module_id: String, permissions: Array) -> void:
	_permissions[module_id] = permissions.duplicate()


func permissions_of(module_id: String) -> Array:
	var value: Variant = _permissions.get(module_id, [])
	return value.duplicate() if value is Array else []


func can(module_id: String, action: String) -> bool:
	if action == "network":
		return false
	if is_disabled(module_id):
		return false
	var granted: Array = permissions_of(module_id)
	if granted.is_empty():
		return true
	if action == "subscribe" or action == "emit":
		return granted.has(action) or granted.has("read_events")
	if action == "read_events":
		return granted.has("read_events") or granted.has("subscribe") or granted.has("emit")
	return granted.has(action)


func has_permission(module_id: String, action: String) -> bool:
	return can(module_id, action)


func checkpoint(module_id: String) -> bool:
	if is_disabled(module_id):
		return false
	var used: int = int(_instructions.get(module_id, 0)) + 1
	_instructions[module_id] = used
	if used > _max_instructions:
		deactivate(module_id, "exceso de instrucciones por llamada")
		return false
	return true


func instruction_count(module_id: String) -> int:
	return int(_instructions.get(module_id, 0))


func is_disabled(module_id: String) -> bool:
	return _disabled.has(module_id)


func disabled_reasons() -> Dictionary:
	return _disabled_reasons.duplicate()


func deactivate(module_id: String, reason: String) -> bool:
	if _disabled.has(module_id):
		return false
	_disabled[module_id] = true
	_disabled_reasons[module_id] = reason
	if bus != null:
		bus.unsubscribe_owner(module_id)
	push_error("ModHooks: modulo '%s' desactivado: %s" % [module_id, reason])
	return true


func forget(module_id: String) -> void:
	_permissions.erase(module_id)
	_disabled.erase(module_id)
	_disabled_reasons.erase(module_id)
	_instructions.erase(module_id)


func register_manifest(module_id: String, manifest: Dictionary, api, target = null) -> int:
	if is_disabled(module_id) or api == null:
		return 0
	var hooks: Variant = manifest.get("hooks", null)
	if not hooks is Dictionary:
		return 0
	var registered := 0
	for raw_event in hooks:
		var event := str(raw_event)
		if not is_event(event):
			push_error("ModHooks: evento desconocido '%s' en el manifiesto de '%s'" % [event, module_id])
			continue
		var entries: Array = hooks[raw_event] if hooks[raw_event] is Array else [hooks[raw_event]]
		for raw_entry in entries:
			var method := ""
			var priority := 100
			if raw_entry is String:
				method = raw_entry
			elif raw_entry is Dictionary:
				method = str(raw_entry.get("method", ""))
				priority = int(raw_entry.get("priority", 100))
			if method.is_empty():
				continue
			if api.subscribe_declared(event, method, priority, target) > 0:
				registered += 1
	return registered


func dependency_order(candidates: Array) -> Array:
	var resolver = load("res://core/mod_resolver.gd")
	if resolver != null and resolver.has_method("resolve"):
		var result: Variant = resolver.resolve(candidates)
		if result is Dictionary:
			var order: Variant = result.get("order", [])
			return order.duplicate() if order is Array else []
	return []


func _on_bus_violation(owner: String, reason: String, _event: String) -> void:
	deactivate(owner, reason)
