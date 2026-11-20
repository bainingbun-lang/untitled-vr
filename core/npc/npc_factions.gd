class_name NPCFactions
extends RefCounted

# Relaciones entre facciones. Solo datos en memoria + snapshot Dictionary.
# Sin OS.execute, sin rutas absolutas y sin clases de extension: compatible con
# Android/Windows/VR.

const SNAPSHOT_VERSION: int = 1
const KEY_SEPARATOR: String = "|"

const DEFAULT_RELATION: float = 0.0
const DEFAULT_SAME_FACTION_RELATION: float = 100.0

var _factions: Dictionary = {}
var _members: Dictionary = {}
var _relations: Dictionary = {}
var _default_relation: float = DEFAULT_RELATION
var _same_faction_relation: float = DEFAULT_SAME_FACTION_RELATION


func _init(p_options: Dictionary = {}) -> void:
	var default_value: Variant = _strict_float(p_options.get("default_relation", DEFAULT_RELATION))
	if default_value != null:
		_default_relation = _clamp_relation(float(default_value))
	var same_value: Variant = _strict_float(p_options.get("same_faction_relation", DEFAULT_SAME_FACTION_RELATION))
	if same_value != null:
		_same_faction_relation = clampf(float(same_value), 0.0, 100.0)
	var faction_list: Variant = p_options.get("factions", [])
	if faction_list is Array:
		for item in faction_list:
			if item is Dictionary:
				register_faction(str(item.get("id", "")), str(item.get("name", "")))
	var member_map: Variant = p_options.get("members", {})
	if member_map is Dictionary:
		for entity in member_map.keys():
			set_member(str(entity), str(member_map[entity]))
	var relation_list: Variant = p_options.get("relations", [])
	if relation_list is Array:
		for item in relation_list:
			if item is Dictionary:
				set_relation(str(item.get("a", "")), str(item.get("b", "")), float(item.get("value", 0.0)))


func has_faction(faction_id: String) -> bool:
	return _factions.has(str(faction_id))


func register_faction(faction_id: String, faction_name: String = "") -> bool:
	var key: String = str(faction_id)
	if not _valid_id(key) or _factions.has(key):
		return false
	_factions[key] = str(faction_name)
	return true


func set_faction_name(faction_id: String, faction_name: String) -> bool:
	var key: String = str(faction_id)
	if not _factions.has(key):
		return false
	_factions[key] = str(faction_name)
	return true


func get_faction_name(faction_id: String) -> String:
	var key: String = str(faction_id)
	if not _factions.has(key):
		return ""
	return str(_factions[key])


func faction_ids() -> Array:
	var ids: Array = _factions.keys()
	ids.sort()
	return ids


func clear_factions() -> void:
	_factions.clear()
	_members.clear()
	_relations.clear()


func set_member(entity_id: String, faction_id: String) -> bool:
	var entity: String = str(entity_id)
	var faction: String = str(faction_id)
	if not _valid_id(entity) or not _factions.has(faction):
		return false
	_members[entity] = faction
	return true


func remove_member(entity_id: String) -> bool:
	return _members.erase(str(entity_id))


func get_faction(entity_id: String) -> String:
	var entity: String = str(entity_id)
	if not _members.has(entity):
		return ""
	return str(_members[entity])


func member_ids() -> Array:
	var ids: Array = _members.keys()
	ids.sort()
	return ids


func members() -> Dictionary:
	return _members.duplicate(true)


func set_default_relation(value: float) -> void:
	var parsed: Variant = _strict_float(value)
	if parsed != null:
		_default_relation = _clamp_relation(float(parsed))


func get_default_relation() -> float:
	return _default_relation


func set_same_faction_relation(value: float) -> void:
	var parsed: Variant = _strict_float(value)
	if parsed != null:
		_same_faction_relation = clampf(float(parsed), 0.0, 100.0)


func get_same_faction_relation() -> float:
	return _same_faction_relation


func set_relation(faction_a: String, faction_b: String, value: float) -> bool:
	var a: String = str(faction_a)
	var b: String = str(faction_b)
	if a == b or not _factions.has(a) or not _factions.has(b):
		return false
	var parsed: Variant = _strict_float(value)
	if parsed == null:
		return false
	var pair: Array = _pair(a, b)
	var key: String = str(pair[0]) + KEY_SEPARATOR + str(pair[1])
	_relations[key] = {
		"a": pair[0],
		"b": pair[1],
		"value": _clamp_relation(float(parsed)),
	}
	return true


func get_relation(faction_a: String, faction_b: String) -> float:
	var a: String = str(faction_a)
	var b: String = str(faction_b)
	if a == b:
		return _same_faction_relation
	if not _factions.has(a) or not _factions.has(b):
		return _default_relation
	var pair: Array = _pair(a, b)
	var key: String = str(pair[0]) + KEY_SEPARATOR + str(pair[1])
	if not _relations.has(key):
		return _default_relation
	return float((_relations[key] as Dictionary)["value"])


func relation_pairs() -> Array:
	var records: Array = []
	for key in _relations.keys():
		var source: Dictionary = _relations[key]
		records.append({
			"a": str(source["a"]),
			"b": str(source["b"]),
			"value": float(source["value"]),
		})
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if str(left["a"]) != str(right["a"]):
			return str(left["a"]) < str(right["a"])
		return str(left["b"]) < str(right["b"])
	)
	return records


# Aportacion de faccion para la herencia de afinidad. 0.0 si falta algun bando.
func relation_between_entities(entity_a: String, entity_b: String) -> float:
	var faction_a: String = get_faction(entity_a)
	var faction_b: String = get_faction(entity_b)
	if faction_a.is_empty() or faction_b.is_empty():
		return 0.0
	if faction_a == faction_b:
		return _same_faction_relation
	return get_relation(faction_a, faction_b)


func to_dict() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"default_relation": _default_relation,
		"same_faction_relation": _same_faction_relation,
		"factions": _faction_records(),
		"members": _member_records(),
		"relations": relation_pairs(),
	}


func restore(data: Variant) -> bool:
	var checked: Dictionary = validate_snapshot(data)
	if not bool(checked["ok"]):
		return false
	var clean: Dictionary = checked["snapshot"]
	var next_factions: Dictionary = {}
	var next_members: Dictionary = {}
	var next_relations: Dictionary = {}
	for item in clean["factions"]:
		var entry: Dictionary = item
		next_factions[str(entry["id"])] = str(entry["name"])
	for item in clean["members"]:
		var entry: Dictionary = item
		next_members[str(entry["entity"])] = str(entry["faction"])
	for item in clean["relations"]:
		var entry: Dictionary = item
		var key: String = str(entry["a"]) + KEY_SEPARATOR + str(entry["b"])
		next_relations[key] = {
			"a": str(entry["a"]),
			"b": str(entry["b"]),
			"value": float(entry["value"]),
		}
	_factions = next_factions
	_members = next_members
	_relations = next_relations
	_default_relation = float(clean["default_relation"])
	_same_faction_relation = float(clean["same_faction_relation"])
	return true


static func validate_snapshot(data: Variant) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"errors": [],
		"snapshot": {},
	}
	var errors: Array = result["errors"]
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("factions: se esperaba un Dictionary")
		return result
	var raw: Dictionary = data
	var version: Variant = _strict_int(raw.get("version", null))
	if version == null or int(version) != SNAPSHOT_VERSION:
		errors.append("factions: version de snapshot no soportada")

	var default_value: Variant = _strict_float(raw.get("default_relation", null))
	if default_value == null or float(default_value) < -100.0 or float(default_value) > 100.0:
		errors.append("factions: default_relation debe ser numerico en [-100, 100]")
		default_value = DEFAULT_RELATION
	var same_value: Variant = _strict_float(raw.get("same_faction_relation", null))
	if same_value == null or float(same_value) < 0.0 or float(same_value) > 100.0:
		errors.append("factions: same_faction_relation debe ser numerico en [0, 100]")
		same_value = DEFAULT_SAME_FACTION_RELATION

	var clean_factions: Array = []
	var faction_ids_seen: Dictionary = {}
	if not _valid_array(raw.get("factions", null)):
		errors.append("factions: 'factions' debe ser un Array")
	else:
		var items: Array = raw["factions"]
		for i in range(items.size()):
			var entry: Variant = items[i]
			if typeof(entry) != TYPE_DICTIONARY:
				errors.append("factions.factions[%d]: debe ser un Dictionary" % i)
				continue
			var source: Dictionary = entry
			var id_value: Variant = _strict_id(source.get("id", null))
			if id_value == null:
				errors.append("factions.factions[%d]: id invalido" % i)
				continue
			var id: String = str(id_value)
			if faction_ids_seen.has(id):
				errors.append("factions.factions[%d]: id duplicado '%s'" % [i, id])
				continue
			var name_value: Variant = source.get("name", "")
			if typeof(name_value) != TYPE_STRING:
				errors.append("factions.factions[%d]: name debe ser String" % i)
				continue
			faction_ids_seen[id] = true
			clean_factions.append({"id": id, "name": str(name_value)})
	clean_factions.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left["id"]) < str(right["id"])
	)

	var clean_members: Array = []
	var entities_seen: Dictionary = {}
	if not _valid_array(raw.get("members", null)):
		errors.append("factions: 'members' debe ser un Array")
	else:
		var items: Array = raw["members"]
		for i in range(items.size()):
			var entry: Variant = items[i]
			if typeof(entry) != TYPE_DICTIONARY:
				errors.append("factions.members[%d]: debe ser un Dictionary" % i)
				continue
			var source: Dictionary = entry
			var entity_value: Variant = _strict_id(source.get("entity", null))
			var faction_value: Variant = _strict_id(source.get("faction", null))
			if entity_value == null or faction_value == null:
				errors.append("factions.members[%d]: entity/faction invalidos" % i)
				continue
			var entity: String = str(entity_value)
			if entities_seen.has(entity):
				errors.append("factions.members[%d]: entity duplicada '%s'" % [i, entity])
				continue
			if not faction_ids_seen.has(str(faction_value)):
				errors.append("factions.members[%d]: faccion desconocida '%s'" % [i, str(faction_value)])
				continue
			entities_seen[entity] = true
			clean_members.append({"entity": entity, "faction": str(faction_value)})
	clean_members.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left["entity"]) < str(right["entity"])
	)

	var clean_relations: Array = []
	var pairs_seen: Dictionary = {}
	if not _valid_array(raw.get("relations", null)):
		errors.append("factions: 'relations' debe ser un Array")
	else:
		var items: Array = raw["relations"]
		for i in range(items.size()):
			var entry: Variant = items[i]
			if typeof(entry) != TYPE_DICTIONARY:
				errors.append("factions.relations[%d]: debe ser un Dictionary" % i)
				continue
			var source: Dictionary = entry
			var a_value: Variant = _strict_id(source.get("a", null))
			var b_value: Variant = _strict_id(source.get("b", null))
			var value_value: Variant = _strict_float(source.get("value", null))
			if a_value == null or b_value == null:
				errors.append("factions.relations[%d]: extremos invalidos" % i)
				continue
			var a: String = str(a_value)
			var b: String = str(b_value)
			if a == b or not faction_ids_seen.has(a) or not faction_ids_seen.has(b):
				errors.append("factions.relations[%d]: extremos desconocidos o iguales" % i)
				continue
			if value_value == null or float(value_value) < -100.0 or float(value_value) > 100.0:
				errors.append("factions.relations[%d]: value fuera de rango" % i)
				continue
			var pair: Array = _pair(a, b)
			var key: String = str(pair[0]) + KEY_SEPARATOR + str(pair[1])
			if pairs_seen.has(key):
				errors.append("factions.relations[%d]: relacion duplicada" % i)
				continue
			pairs_seen[key] = true
			clean_relations.append({"a": pair[0], "b": pair[1], "value": float(value_value)})
	clean_relations.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if str(left["a"]) != str(right["a"]):
			return str(left["a"]) < str(right["a"])
		return str(left["b"]) < str(right["b"])
	)

	result["ok"] = errors.is_empty()
	if errors.is_empty():
		result["snapshot"] = {
			"version": SNAPSHOT_VERSION,
			"default_relation": float(default_value),
			"same_faction_relation": float(same_value),
			"factions": clean_factions,
			"members": clean_members,
			"relations": clean_relations,
		}
	return result


func _faction_records() -> Array:
	var records: Array = []
	for id in _factions.keys():
		records.append({"id": str(id), "name": str(_factions[id])})
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left["id"]) < str(right["id"])
	)
	return records


func _member_records() -> Array:
	var records: Array = []
	for entity in _members.keys():
		records.append({"entity": str(entity), "faction": str(_members[entity])})
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left["entity"]) < str(right["entity"])
	)
	return records


static func _pair(a: String, b: String) -> Array:
	if a < b:
		return [a, b]
	return [b, a]


static func _clamp_relation(value: float) -> float:
	return clampf(value, -100.0, 100.0)


static func _valid_array(value: Variant) -> bool:
	return typeof(value) == TYPE_ARRAY


static func _valid_id(value: Variant) -> bool:
	var id: Variant = _strict_id(value)
	return id != null


static func _strict_id(value: Variant) -> Variant:
	if typeof(value) != TYPE_STRING:
		return null
	var text: String = value
	if text.is_empty() or text != text.strip_edges() or text.contains(KEY_SEPARATOR):
		return null
	return text


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
