class_name NPCRelations
extends RefCounted

# Afinidad dirigida (subject -> target) en [-100, 100], con decaimiento hacia 0,
# eventos con presupuesto por tick, herencia de faccion y actitud con histeresis.
# El adaptador behavior_context/merge_behavior_context solo LEE este estado y
# devuelve claves de contexto que NPCBehavior ya entiende: no se modifica dicho
# script. Solo datos en memoria + Dictionary -> sin rutas ni llamadas externas.

const SNAPSHOT_VERSION: int = 1
const KEY_SEPARATOR: String = "|"
const ENTITY_PLAYER: String = "player"

const EVENT_HELP: String = "help"
const EVENT_AGGRESSION: String = "aggression"
const EVENT_GIFT: String = "gift"
const EVENT_DELTAS: Dictionary = {
	EVENT_HELP: 12.0,
	EVENT_AGGRESSION: -25.0,
	EVENT_GIFT: 8.0,
}

const ATTITUDE_HOSTILE: String = "hostil"
const ATTITUDE_NEUTRAL: String = "neutral"
const ATTITUDE_FRIENDLY: String = "amistoso"
const ATTITUDES: Array = [ATTITUDE_HOSTILE, ATTITUDE_NEUTRAL, ATTITUDE_FRIENDLY]

const DEFAULT_DECAY_RATE: float = 2.0
const DEFAULT_TICK_CAP: float = 40.0
const DEFAULT_FACTION_WEIGHT: float = 0.35
const DEFAULT_ATTITUDE_BORDER: float = 25.0
const DEFAULT_HYSTERESIS: float = 12.0
const EPSILON: float = 0.000001

const NPCFactionsScript = preload("res://core/npc/npc_factions.gd")

var factions = null
var _affinities: Dictionary = {}
var _attitudes: Dictionary = {}
var _tick_usage: Dictionary = {}
var _decay_rate: float = DEFAULT_DECAY_RATE
var _tick_cap: float = DEFAULT_TICK_CAP
var _faction_weight: float = DEFAULT_FACTION_WEIGHT
var _attitude_border: float = DEFAULT_ATTITUDE_BORDER
var _hysteresis: float = DEFAULT_HYSTERESIS


func _init(p_options: Dictionary = {}, p_factions = null) -> void:
	factions = p_factions if p_factions != null else NPCFactionsScript.new()
	var value: Variant = _strict_float(p_options.get("decay_rate", DEFAULT_DECAY_RATE))
	if value != null:
		_decay_rate = clampf(float(value), 0.0, 1000.0)
	value = _strict_float(p_options.get("tick_cap", DEFAULT_TICK_CAP))
	if value != null:
		_tick_cap = clampf(float(value), 0.0, 10000.0)
	value = _strict_float(p_options.get("faction_weight", DEFAULT_FACTION_WEIGHT))
	if value != null:
		_faction_weight = clampf(float(value), 0.0, 1.0)
	value = _strict_float(p_options.get("attitude_border", DEFAULT_ATTITUDE_BORDER))
	if value != null:
		_attitude_border = clampf(float(value), 0.001, 100.0)
	value = _strict_float(p_options.get("hysteresis", DEFAULT_HYSTERESIS))
	if value != null:
		_hysteresis = clampf(float(value), 0.0, maxf(_attitude_border - EPSILON, 0.0))


func set_decay_rate(value: float) -> void:
	var parsed: Variant = _strict_float(value)
	if parsed != null:
		_decay_rate = clampf(float(parsed), 0.0, 1000.0)


func get_decay_rate() -> float:
	return _decay_rate


func set_tick_cap(value: float) -> void:
	var parsed: Variant = _strict_float(value)
	if parsed != null:
		_tick_cap = clampf(float(parsed), 0.0, 10000.0)


func get_tick_cap() -> float:
	return _tick_cap


func set_faction_weight(value: float) -> void:
	var parsed: Variant = _strict_float(value)
	if parsed != null:
		_faction_weight = clampf(float(parsed), 0.0, 1.0)


func get_faction_weight() -> float:
	return _faction_weight


func set_attitude_border(value: float) -> void:
	var parsed: Variant = _strict_float(value)
	if parsed != null:
		_attitude_border = clampf(float(parsed), 0.001, 100.0)
		_hysteresis = minf(_hysteresis, maxf(_attitude_border - EPSILON, 0.0))


func get_attitude_border() -> float:
	return _attitude_border


func set_hysteresis(value: float) -> void:
	var parsed: Variant = _strict_float(value)
	if parsed != null:
		_hysteresis = clampf(float(parsed), 0.0, maxf(_attitude_border - EPSILON, 0.0))


func get_hysteresis() -> float:
	return _hysteresis


func set_affinity(subject: String, target: String, value: float) -> bool:
	var parsed: Variant = _strict_float(value)
	if not _valid_pair(subject, target) or parsed == null:
		return false
	var key: String = _pair_key(subject, target)
	_affinities[key] = {
		"from": subject,
		"to": target,
		"value": clampf(float(parsed), -100.0, 100.0),
	}
	return true


func get_base_affinity(subject: String, target: String) -> float:
	if not _valid_pair(subject, target):
		return 0.0
	var key: String = _pair_key(subject, target)
	if not _affinities.has(key):
		return 0.0
	return float((_affinities[key] as Dictionary)["value"])


# Afinidad efectiva: individual + aportacion de faccion (ponderada y limitada).
func get_affinity(subject: String, target: String) -> float:
	if not _valid_pair(subject, target):
		return 0.0
	var base: float = get_base_affinity(subject, target)
	var faction_value: float = factions.relation_between_entities(subject, target) if factions != null else 0.0
	return clampf(base + faction_value * _faction_weight, -100.0, 100.0)


func apply_event(subject: String, target: String, event_type: String, p_options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {
		"ok": false,
		"event": str(event_type),
		"requested": 0.0,
		"applied": 0.0,
		"capped": false,
		"reason": "invalid",
		"value": get_base_affinity(subject, target),
		"attitude": ATTITUDE_NEUTRAL,
	}
	if not _valid_pair(subject, target):
		report["reason"] = "invalid_id"
		return report
	var kind: String = str(event_type).to_lower()
	if not EVENT_DELTAS.has(kind):
		report["reason"] = "unknown_event"
		return report
	var intensity: float = 1.0
	if p_options.has("intensity"):
		var parsed: Variant = _strict_float(p_options["intensity"])
		if parsed == null:
			report["reason"] = "invalid_intensity"
			return report
		intensity = clampf(float(parsed), 0.0, 1.0)
	var desired: float = float(EVENT_DELTAS[kind]) * intensity
	report["requested"] = desired
	if absf(desired) < EPSILON:
		report["ok"] = true
		report["reason"] = "zero_delta"
		report["attitude"] = get_attitude(subject, target)
		return report
	var used: float = float(_tick_usage.get(subject, 0.0))
	var remaining: float = maxf(_tick_cap - used, 0.0)
	var applied: float = signf(desired) * minf(absf(desired), remaining)
	if absf(applied) < EPSILON:
		report["reason"] = "tick_cap_reached"
		report["capped"] = true
		report["attitude"] = get_attitude(subject, target)
		return report
	var key: String = _pair_key(subject, target)
	var record: Dictionary = _affinities.get(key, {"from": subject, "to": target, "value": 0.0})
	record["value"] = clampf(float(record["value"]) + applied, -100.0, 100.0)
	_affinities[key] = record
	_tick_usage[subject] = used + absf(applied)
	report["ok"] = true
	report["applied"] = applied
	report["capped"] = absf(applied) < absf(desired) - EPSILON
	report["reason"] = "capped" if report["capped"] else "applied"
	report["value"] = float(record["value"])
	report["attitude"] = get_attitude(subject, target)
	return report


# Paso de simulacion: decaimiento hacia neutro + renovacion del presupuesto.
func tick(delta: float) -> void:
	var parsed: Variant = _strict_float(delta)
	var seconds: float = maxf(float(parsed) if parsed != null else 0.0, 0.0)
	if seconds > 0.0 and _decay_rate > 0.0:
		var step: float = _decay_rate * seconds
		for key in _affinities.keys():
			var record: Dictionary = _affinities[key]
			var value: float = float(record["value"])
			if value > 0.0:
				record["value"] = maxf(value - step, 0.0)
			elif value < 0.0:
				record["value"] = minf(value + step, 0.0)
			_affinities[key] = record
	reset_tick()


func reset_tick() -> void:
	_tick_usage.clear()


func get_tick_usage(entity_id: String) -> float:
	return float(_tick_usage.get(str(entity_id), 0.0))


# Consulta con histeresis: la actitud anterior ensancha/estrecha la banda.
func get_attitude(subject: String, target: String) -> String:
	if not _valid_pair(subject, target):
		return ATTITUDE_NEUTRAL
	var key: String = _pair_key(subject, target)
	var previous: String = ATTITUDE_NEUTRAL
	if _attitudes.has(key):
		previous = str((_attitudes[key] as Dictionary)["attitude"])
	var next: String = _classify(get_affinity(subject, target), previous)
	_attitudes[key] = {"from": subject, "to": target, "attitude": next}
	return next


func get_last_attitude(subject: String, target: String) -> String:
	var key: String = _pair_key(subject, target)
	if not _attitudes.has(key):
		return ATTITUDE_NEUTRAL
	return str((_attitudes[key] as Dictionary)["attitude"])


func clear_attitude(subject: String, target: String) -> bool:
	return _attitudes.erase(_pair_key(subject, target))


# Adaptador de lectura para NPCBehavior: claves que _build_context conserva y
# las funciones de puntuacion ya interpretan. No altera el script de comportamiento.
func behavior_context(subject: String, target: String, p_options: Dictionary = {}) -> Dictionary:
	if not _valid_pair(subject, target):
		return {"relation_target": target, "relation_affinity": 0.0, "relation_attitude": ATTITUDE_NEUTRAL}
	var value: float = get_affinity(subject, target)
	var attitude: String = get_attitude(subject, target)
	var context: Dictionary = {
		"relation_target": target,
		"relation_affinity": value,
		"relation_attitude": attitude,
	}
	var influence: float = clampf(float(p_options.get("influence", 1.0)), 0.0, 1.0)
	if attitude == ATTITUDE_HOSTILE:
		context["danger"] = clampf(0.5 + 0.5 * (-value / 100.0) * influence, 0.0, 1.0)
	elif attitude == ATTITUDE_FRIENDLY:
		context["sociability"] = clampf(0.5 + 0.5 * (value / 100.0) * influence, 0.0, 1.0)
	return context


func merge_behavior_context(base: Dictionary, subject: String, target: String, p_options: Dictionary = {}) -> Dictionary:
	var context: Dictionary = base.duplicate(true)
	var injected: Dictionary = behavior_context(subject, target, p_options)
	for key in injected.keys():
		context[key] = injected[key]
	return context


func to_dict() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"decay_rate": _decay_rate,
		"tick_cap": _tick_cap,
		"faction_weight": _faction_weight,
		"attitude_border": _attitude_border,
		"hysteresis": _hysteresis,
		"affinities": _affinity_records(),
		"attitudes": _attitude_records(),
		"tick_usage": _tick_records(),
		"factions": factions.to_dict() if factions != null and factions.has_method("to_dict") else {},
	}


func restore(data: Variant) -> bool:
	var checked: Dictionary = validate_snapshot(data)
	if not bool(checked["ok"]):
		return false
	var clean: Dictionary = checked["snapshot"]
	if factions != null and factions.has_method("restore"):
		if not bool(factions.restore(clean["factions"])):
			return false
	var next_affinities: Dictionary = {}
	var next_attitudes: Dictionary = {}
	var next_tick: Dictionary = {}
	for item in clean["affinities"]:
		var entry: Dictionary = item
		var key: String = str(entry["from"]) + KEY_SEPARATOR + str(entry["to"])
		next_affinities[key] = {
			"from": str(entry["from"]),
			"to": str(entry["to"]),
			"value": float(entry["value"]),
		}
	for item in clean["attitudes"]:
		var entry: Dictionary = item
		var key: String = str(entry["from"]) + KEY_SEPARATOR + str(entry["to"])
		next_attitudes[key] = {
			"from": str(entry["from"]),
			"to": str(entry["to"]),
			"attitude": str(entry["attitude"]),
		}
	for item in clean["tick_usage"]:
		var entry: Dictionary = item
		next_tick[str(entry["entity"])] = float(entry["value"])
	_affinities = next_affinities
	_attitudes = next_attitudes
	_tick_usage = next_tick
	_decay_rate = float(clean["decay_rate"])
	_tick_cap = float(clean["tick_cap"])
	_faction_weight = float(clean["faction_weight"])
	_attitude_border = float(clean["attitude_border"])
	_hysteresis = float(clean["hysteresis"])
	return true


static func validate_snapshot(data: Variant) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"errors": [],
		"snapshot": {},
	}
	var errors: Array = result["errors"]
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("relations: se esperaba un Dictionary")
		return result
	var raw: Dictionary = data
	var version: Variant = _strict_int(raw.get("version", null))
	if version == null or int(version) != SNAPSHOT_VERSION:
		errors.append("relations: version de snapshot no soportada")

	var decay_rate: Variant = _strict_float(raw.get("decay_rate", null))
	if decay_rate == null or float(decay_rate) < 0.0 or float(decay_rate) > 1000.0:
		errors.append("relations: decay_rate debe ser numerico en [0, 1000]")
		decay_rate = DEFAULT_DECAY_RATE
	var tick_cap: Variant = _strict_float(raw.get("tick_cap", null))
	if tick_cap == null or float(tick_cap) < 0.0 or float(tick_cap) > 10000.0:
		errors.append("relations: tick_cap debe ser numerico en [0, 10000]")
		tick_cap = DEFAULT_TICK_CAP
	var faction_weight: Variant = _strict_float(raw.get("faction_weight", null))
	if faction_weight == null or float(faction_weight) < 0.0 or float(faction_weight) > 1.0:
		errors.append("relations: faction_weight debe ser numerico en [0, 1]")
		faction_weight = DEFAULT_FACTION_WEIGHT
	var attitude_border: Variant = _strict_float(raw.get("attitude_border", null))
	if attitude_border == null or float(attitude_border) < 0.001 or float(attitude_border) > 100.0:
		errors.append("relations: attitude_border debe ser numerico en (0, 100]")
		attitude_border = DEFAULT_ATTITUDE_BORDER
	var hysteresis: Variant = _strict_float(raw.get("hysteresis", null))
	if hysteresis == null or float(hysteresis) < 0.0 or float(hysteresis) > float(attitude_border):
		errors.append("relations: hysteresis debe ser numerico en [0, attitude_border]")
		hysteresis = DEFAULT_HYSTERESIS

	var clean_affinities: Array = []
	var affinity_keys: Dictionary = {}
	if not _valid_array(raw.get("affinities", null)):
		errors.append("relations: 'affinities' debe ser un Array")
	else:
		var items: Array = raw["affinities"]
		for i in range(items.size()):
			var entry: Variant = items[i]
			if typeof(entry) != TYPE_DICTIONARY:
				errors.append("relations.affinities[%d]: debe ser un Dictionary" % i)
				continue
			var source: Dictionary = entry
			var from_value: Variant = _strict_id(source.get("from", null))
			var to_value: Variant = _strict_id(source.get("to", null))
			var value_value: Variant = _strict_float(source.get("value", null))
			if from_value == null or to_value == null or value_value == null:
				errors.append("relations.affinities[%d]: campos invalidos" % i)
				continue
			var from_id: String = str(from_value)
			var to_id: String = str(to_value)
			if from_id == to_id:
				errors.append("relations.affinities[%d]: from y to no pueden coincidir" % i)
				continue
			var key: String = from_id + KEY_SEPARATOR + to_id
			if affinity_keys.has(key):
				errors.append("relations.affinities[%d]: par duplicado" % i)
				continue
			if float(value_value) < -100.0 or float(value_value) > 100.0:
				errors.append("relations.affinities[%d]: value fuera de [-100, 100]" % i)
				continue
			affinity_keys[key] = true
			clean_affinities.append({"from": from_id, "to": to_id, "value": float(value_value)})
	clean_affinities.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if str(left["from"]) != str(right["from"]):
			return str(left["from"]) < str(right["from"])
		return str(left["to"]) < str(right["to"])
	)

	var clean_attitudes: Array = []
	var attitude_keys: Dictionary = {}
	if not _valid_array(raw.get("attitudes", null)):
		errors.append("relations: 'attitudes' debe ser un Array")
	else:
		var items: Array = raw["attitudes"]
		for i in range(items.size()):
			var entry: Variant = items[i]
			if typeof(entry) != TYPE_DICTIONARY:
				errors.append("relations.attitudes[%d]: debe ser un Dictionary" % i)
				continue
			var source: Dictionary = entry
			var from_value: Variant = _strict_id(source.get("from", null))
			var to_value: Variant = _strict_id(source.get("to", null))
			var attitude_value: Variant = source.get("attitude", null)
			if from_value == null or to_value == null or typeof(attitude_value) != TYPE_STRING:
				errors.append("relations.attitudes[%d]: campos invalidos" % i)
				continue
			var from_id: String = str(from_value)
			var to_id: String = str(to_value)
			if from_id == to_id or not ATTITUDES.has(str(attitude_value)):
				errors.append("relations.attitudes[%d]: attitude desconocida o par invalido" % i)
				continue
			var key: String = from_id + KEY_SEPARATOR + to_id
			if attitude_keys.has(key):
				errors.append("relations.attitudes[%d]: par duplicado" % i)
				continue
			attitude_keys[key] = true
			clean_attitudes.append({"from": from_id, "to": to_id, "attitude": str(attitude_value)})
	clean_attitudes.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if str(left["from"]) != str(right["from"]):
			return str(left["from"]) < str(right["from"])
		return str(left["to"]) < str(right["to"])
	)

	var clean_tick: Array = []
	var tick_keys: Dictionary = {}
	if not _valid_array(raw.get("tick_usage", null)):
		errors.append("relations: 'tick_usage' debe ser un Array")
	else:
		var items: Array = raw["tick_usage"]
		for i in range(items.size()):
			var entry: Variant = items[i]
			if typeof(entry) != TYPE_DICTIONARY:
				errors.append("relations.tick_usage[%d]: debe ser un Dictionary" % i)
				continue
			var source: Dictionary = entry
			var entity_value: Variant = _strict_id(source.get("entity", null))
			var value_value: Variant = _strict_float(source.get("value", null))
			if entity_value == null or value_value == null or float(value_value) < 0.0:
				errors.append("relations.tick_usage[%d]: campos invalidos" % i)
				continue
			var entity: String = str(entity_value)
			if tick_keys.has(entity):
				errors.append("relations.tick_usage[%d]: entidad duplicada" % i)
				continue
			tick_keys[entity] = true
			clean_tick.append({"entity": entity, "value": float(value_value)})
	clean_tick.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left["entity"]) < str(right["entity"])
	)

	var factions_check: Dictionary = NPCFactionsScript.validate_snapshot(raw.get("factions", null))
	if not bool(factions_check["ok"]):
		for error in factions_check["errors"]:
			errors.append(str(error))

	result["ok"] = errors.is_empty()
	if errors.is_empty():
		result["snapshot"] = {
			"version": SNAPSHOT_VERSION,
			"decay_rate": float(decay_rate),
			"tick_cap": float(tick_cap),
			"faction_weight": float(faction_weight),
			"attitude_border": float(attitude_border),
			"hysteresis": float(hysteresis),
			"affinities": clean_affinities,
			"attitudes": clean_attitudes,
			"tick_usage": clean_tick,
			"factions": factions_check["snapshot"],
		}
	return result


func _classify(value: float, previous: String) -> String:
	var border: float = _attitude_border
	var margin: float = _hysteresis
	if previous == ATTITUDE_FRIENDLY:
		if value >= border - margin:
			return ATTITUDE_FRIENDLY
		if value <= -border - margin:
			return ATTITUDE_HOSTILE
		return ATTITUDE_NEUTRAL
	if previous == ATTITUDE_HOSTILE:
		if value <= -border + margin:
			return ATTITUDE_HOSTILE
		if value >= border + margin:
			return ATTITUDE_FRIENDLY
		return ATTITUDE_NEUTRAL
	if value >= border + margin:
		return ATTITUDE_FRIENDLY
	if value <= -border - margin:
		return ATTITUDE_HOSTILE
	return ATTITUDE_NEUTRAL


func _affinity_records() -> Array:
	var records: Array = []
	for key in _affinities.keys():
		var source: Dictionary = _affinities[key]
		records.append({
			"from": str(source["from"]),
			"to": str(source["to"]),
			"value": float(source["value"]),
		})
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if str(left["from"]) != str(right["from"]):
			return str(left["from"]) < str(right["from"])
		return str(left["to"]) < str(right["to"])
	)
	return records


func _attitude_records() -> Array:
	var records: Array = []
	for key in _attitudes.keys():
		var source: Dictionary = _attitudes[key]
		records.append({
			"from": str(source["from"]),
			"to": str(source["to"]),
			"attitude": str(source["attitude"]),
		})
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if str(left["from"]) != str(right["from"]):
			return str(left["from"]) < str(right["from"])
		return str(left["to"]) < str(right["to"])
	)
	return records


func _tick_records() -> Array:
	var records: Array = []
	for entity in _tick_usage.keys():
		records.append({"entity": str(entity), "value": float(_tick_usage[entity])})
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left["entity"]) < str(right["entity"])
	)
	return records


static func _pair_key(subject: String, target: String) -> String:
	return str(subject) + KEY_SEPARATOR + str(target)


static func _valid_pair(subject: Variant, target: Variant) -> bool:
	if not _valid_id(subject) or not _valid_id(target):
		return false
	return str(subject) != str(target)


static func _valid_id(value: Variant) -> bool:
	return _strict_id(value) != null


static func _strict_id(value: Variant) -> Variant:
	if typeof(value) != TYPE_STRING:
		return null
	var text: String = value
	if text.is_empty() or text != text.strip_edges() or text.contains(KEY_SEPARATOR):
		return null
	return text


static func _valid_array(value: Variant) -> bool:
	return typeof(value) == TYPE_ARRAY


static func _strict_int(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			var number: float = float(value)
			if not is_nan(number) and not is_inf(number) and floorf(number) == number:
				return int(number)
	return null


static func _strict_float(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			var number: float = float(value)
			if is_nan(number) or is_inf(number):
				return null
			return number
	return null
