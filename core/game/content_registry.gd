class_name ContentRegistry
extends RefCounted

# Original content registry system with mod loading, validation, and priority-based overrides
# No direct reference repo equivalent - inspired by Godot resource system patterns
# License: MIT (c) 2026 UNTITLED project - see third_party/ for dependency licenses

const TYPES: Array[String] = [
	"weapon", "ammo", "item", "npc_type", "surface", "vehicle", "sound_bank", "gore_profile",
]
const BASE_MOD_ID := "untitled.base"
const BASE_DIR := "res://data/base"
const CONTENT_DIR_NAME := "content"
const DEFAULT_PRIORITY := 100

static var _instance = null

var _mods: Dictionary = {}
var _entries: Dictionary = {}
var _public: Dictionary = {}
var _errors: Array = []


static func instance() -> ContentRegistry:
	if _instance == null:
		_instance = _create()
		_instance.load_base()
	return _instance


static func reset() -> ContentRegistry:
	_instance = _create()
	_instance.load_base()
	return _instance


static func _create() -> ContentRegistry:
	return load("res://core/game/content_registry.gd").new()


func load_base() -> Dictionary:
	return load_mod(BASE_MOD_ID, BASE_DIR, 0)


func load_mod(mod_id: String, dir: String, priority: int = DEFAULT_PRIORITY) -> Dictionary:
	var errors: Array = []
	if not _valid_mod_id(mod_id):
		errors.append("mod: id invalido '%s'" % mod_id)
		return {"ok": false, "registered": 0, "errors": errors}

	var collected: Dictionary = {}
	for type_name in TYPES:
		collected[type_name] = []

	var content_dir := dir.path_join(CONTENT_DIR_NAME)
	var dirs: Array[String] = [content_dir, dir]
	for scan_dir in dirs:
		var handle := DirAccess.open(scan_dir)
		if handle == null:
			continue
		for file_name in handle.get_files():
			var name := str(file_name)
			if not name.ends_with(".json") or name == "mod.json":
				continue
			var path: String = scan_dir.path_join(name)
			var text := FileAccess.get_file_as_string(path)
			var parsed: Variant = JSON.parse_string(text)
			if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
				errors.append("%s: JSON invalido" % path)
				continue
			var root: Dictionary = parsed
			var raw_defs: Variant = root.get("content", root.get("defs", null))
			if raw_defs == null and root.has("type"):
				raw_defs = [root]
			if raw_defs == null:
				continue
			if typeof(raw_defs) != TYPE_ARRAY:
				errors.append("%s: se esperaba un array 'content'" % path)
				continue
			for raw_def in raw_defs:
				if typeof(raw_def) != TYPE_DICTIONARY:
					errors.append("%s: cada entrada debe ser un objeto" % path)
					continue
				var entry: Dictionary = raw_def
				var type_name := str(entry.get("type", ""))
				if not TYPES.has(type_name):
					errors.append("%s: tipo desconocido '%s'" % [path, type_name])
					continue
				collected[type_name].append(entry)

	var normalized: Dictionary = {}
	var registered := 0
	for type_name in TYPES:
		normalized[type_name] = {}
		for raw_def in collected[type_name]:
			var result := validate(str(type_name), raw_def, mod_id)
			if not bool(result.get("ok", false)):
				for error in result.get("errors", []):
					errors.append("%s: %s" % [type_name, str(error)])
				continue
			var def: Dictionary = result.get("definition", {})
			var canonical := str(def.get("id", ""))
			if normalized[type_name].has(canonical):
				errors.append("%s: id duplicado '%s' dentro del mod" % [type_name, canonical])
				continue
			normalized[type_name][canonical] = {
				"def": def,
				"meta": result.get("meta", {}),
			}
			registered += 1

	set_mod(mod_id, normalized, priority)
	for error in errors:
		_append_error(error)
	return {
		"ok": errors.is_empty(),
		"registered": registered,
		"errors": errors,
	}


func set_mod(mod_id: String, definitions: Dictionary, priority: int = DEFAULT_PRIORITY) -> void:
	var normalized: Dictionary = {}
	for type_name in TYPES:
		normalized[type_name] = {}
		var raw_entries: Dictionary = definitions.get(type_name, {})
		for key in raw_entries:
			if typeof(raw_entries[key]) != TYPE_DICTIONARY:
				_append_error("%s: entrada '%s' no es un objeto" % [type_name, str(key)])
				continue
			var raw: Dictionary = raw_entries[key]
			if raw.has("def") and raw.has("meta"):
				normalized[type_name][str(key)] = raw.duplicate(true)
				continue
			var result := validate(str(type_name), raw, mod_id)
			if not bool(result.get("ok", false)):
				for error in result.get("errors", []):
					_append_error("%s: %s" % [type_name, str(error)])
				continue
			var def: Dictionary = result.get("definition", {})
			normalized[type_name][str(def.get("id", key))] = {
				"def": def,
				"meta": result.get("meta", {}),
			}
	_mods[mod_id] = {
		"priority": priority,
		"entries": normalized,
	}
	_rebuild()


func unload_mod(mod_id: String) -> bool:
	if not _mods.has(mod_id):
		return false
	_mods.erase(mod_id)
	_rebuild()
	return true


func sync_loaded(loaded_ids: Array) -> void:
	var keep: Dictionary = {}
	for raw_id in loaded_ids:
		keep[str(raw_id)] = true
	var stale: Array = []
	for mod_id in _mods.keys():
		if str(mod_id) != BASE_MOD_ID and not keep.has(str(mod_id)):
			stale.append(str(mod_id))
	for mod_id in stale:
		_mods.erase(mod_id)
	_rebuild()


func validate(type_name: String, raw: Variant, mod_id: String = "") -> Dictionary:
	var errors: Array = []
	if not TYPES.has(type_name):
		errors.append("tipo desconocido '%s'" % type_name)
		return _invalid(errors)
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("%s: se esperaba un Dictionary" % type_name)
		return _invalid(errors)

	var entry: Dictionary = raw
	var def: Dictionary = entry.duplicate(true)
	def.erase("type")
	var replaces := _parse_replaces(entry.get("replaces", []), errors)
	def.erase("replaces")

	var id := str(def.get("id", ""))
	if not _valid_canonical_id(id):
		errors.append("id: se esperaba 'modid:nombre' en minusculas, se recibio '%s'" % id)
	elif not mod_id.is_empty() and not id.begins_with(mod_id + ":"):
		errors.append("id: '%s' no pertenece al mod '%s'" % [id, mod_id])

	var allowed: Array = _allowed_keys(type_name)
	for key in def.keys():
		if not allowed.has(str(key)):
			errors.append("%s: campo desconocido '%s'" % [type_name, str(key)])

	match type_name:
		"weapon":
			_validate_weapon(def, errors)
		"ammo":
			_validate_ammo(def, errors)
		"item":
			_validate_item(def, errors)
		"npc_type":
			_validate_npc_type(def, errors)
		"surface":
			_validate_surface(def, errors)
		"vehicle":
			_validate_vehicle(def, errors)
		"sound_bank":
			_validate_sound_bank(def, errors)
		"gore_profile":
			_validate_gore_profile(def, errors)

	if not errors.is_empty():
		return _invalid(errors)
	return {
		"ok": true,
		"errors": [],
		"definition": def,
		"meta": {"replaces": replaces},
	}


func entries(type_name: String) -> Dictionary:
	var result: Dictionary = {}
	for canonical in _bucket(type_name):
		var record: Dictionary = _bucket(type_name)[canonical]
		var def: Dictionary = record["def"]
		result[canonical] = def.duplicate(true)
	return result


func all(type_name: String) -> Dictionary:
	var result: Dictionary = {}
	for canonical in _bucket(type_name):
		var record: Dictionary = _bucket(type_name)[canonical]
		var def: Dictionary = record["def"]
		var public_id := str(record["public"])
		var public_def: Dictionary = def.duplicate(true)
		public_def["id"] = public_id
		result[public_id] = public_def
	return result


func definition(type_name: String, id: String) -> Dictionary:
	var canonical := canonical_id(type_name, id)
	if canonical.is_empty() or not _bucket(type_name).has(canonical):
		return {}
	var record: Dictionary = _bucket(type_name)[canonical]
	var def: Dictionary = record["def"]
	var public_id := str(record["public"])
	var public_def: Dictionary = def.duplicate(true)
	public_def["id"] = public_id
	return public_def


func has(type_name: String, id: String) -> bool:
	return not canonical_id(type_name, id).is_empty()


func ids(type_name: String) -> Array:
	var result: Array = all(type_name).keys()
	result.sort()
	return result


func ordered_ids(type_name: String) -> Array:
	var result: Array = []
	for canonical in _bucket(type_name):
		result.append(str(_bucket(type_name)[canonical]["public"]))
	return result


func canonical_id(type_name: String, id: String) -> String:
	if id.contains(":"):
		return id if _bucket(type_name).has(id) else ""
	_bucket(type_name)
	if _public[type_name].has(id):
		return str(_public[type_name][id])
	return ""


func owner_of(type_name: String, id: String) -> String:
	var canonical := canonical_id(type_name, id)
	if canonical.is_empty():
		return ""
	return str(canonical.split(":")[0])


func errors() -> Array:
	return _errors.duplicate()


func clear_errors() -> void:
	_errors.clear()


func _bucket(type_name: String) -> Dictionary:
	if not _entries.has(type_name):
		_entries[type_name] = {}
	if not _public.has(type_name):
		_public[type_name] = {}
	return _entries[type_name]


func _rebuild() -> void:
	_entries.clear()
	_public.clear()
	_errors.clear()
	for type_name in TYPES:
		_entries[type_name] = {}
		_public[type_name] = {}

	var mod_ids: Array = _mods.keys()
	mod_ids.sort_custom(
		func(a, b):
			var pa := int(_mods[a]["priority"])
			var pb := int(_mods[b]["priority"])
			return pa < pb if pa != pb else str(a) < str(b)
	)

	for mod_id in mod_ids:
		var record: Dictionary = _mods[mod_id]
		var priority := int(record["priority"])
		for type_name in TYPES:
			var type_entries: Dictionary = record["entries"].get(type_name, {})
			for canonical in type_entries:
				var item: Dictionary = type_entries[canonical]
				var def: Dictionary = item["def"]
				var meta: Dictionary = item["meta"]
				var public_id := str(canonical).split(":")[1]
				var bucket: Dictionary = _entries[type_name]
				if bucket.has(canonical):
					var previous: Dictionary = bucket[canonical]
					if _can_replace(meta, str(canonical), public_id, priority, previous):
						_install(type_name, str(canonical), public_id, def, mod_id, priority)
					else:
						_append_error(
							"%s: '%s' no sustituye a '%s' (se requiere replaces explicito y mayor prioridad)"
							% [type_name, str(mod_id), str(canonical)]
						)
					continue
				if _public[type_name].has(public_id):
					var other_canonical := str(_public[type_name][public_id])
					var other: Dictionary = bucket[other_canonical]
					if _can_replace(meta, other_canonical, public_id, priority, other):
						_install(type_name, str(canonical), public_id, def, mod_id, priority)
					else:
						_append_error(
							"%s: id publico '%s' ya lo usa '%s'"
							% [type_name, public_id, other_canonical]
						)
					continue
				_install(type_name, str(canonical), public_id, def, mod_id, priority)


func _install(
	type_name: String, canonical: String, public_id: String,
	def: Dictionary, mod_id: String, priority: int
) -> void:
	_entries[type_name][canonical] = {
		"def": def.duplicate(true),
		"public": public_id,
		"owner": mod_id,
		"priority": priority,
	}
	_public[type_name][public_id] = canonical


func _can_replace(
	meta: Dictionary, canonical: String, public_id: String,
	priority: int, previous: Dictionary
) -> bool:
	if priority <= int(previous["priority"]):
		return false
	var replaces: Array = meta.get("replaces", [])
	return replaces.has(canonical) or replaces.has(public_id)


func _append_error(message: String) -> void:
	if not _errors.has(message):
		_errors.append(message)


func _invalid(errors: Array) -> Dictionary:
	return {"ok": false, "errors": errors, "definition": {}, "meta": {}}


func _parse_replaces(raw: Variant, errors: Array) -> Array:
	var result: Array = []
	if raw == null:
		return result
	var values: Array = []
	if typeof(raw) == TYPE_STRING:
		values = [raw]
	elif typeof(raw) == TYPE_ARRAY:
		values = raw
	else:
		errors.append("replaces: se esperaba String o Array de String")
		return result
	for value in values:
		if typeof(value) != TYPE_STRING:
			errors.append("replaces: cada entrada debe ser String")
			continue
		var text := str(value).strip_edges()
		if not _valid_canonical_id(text):
			errors.append("replaces: id invalido '%s'" % text)
			continue
		if not result.has(text):
			result.append(text)
	return result


func _allowed_keys(type_name: String) -> Array:
	var common: Array = ["id", "name", "description"]
	match type_name:
		"weapon":
			return common + [
				"damage", "fire_rate", "range", "mag", "auto", "spread", "pellets", "tags",
				"reload_time", "weight", "impulse", "uses_ammo", "penetration", "falloff_start",
				"falloff_end", "falloff_min", "projectile_speed", "projectile_gravity",
				"projectile_min_distance", "impact_speed", "effect_scale", "max_penetrations",
				"max_ricochets", "model", "ammo_id", "caliber",
				"fire_mode", "burst_count", "burst_delay", "vr_knife",
			]
		"ammo":
			return common + ["weapon", "caliber", "magazine", "damage", "uses_ammo", "tags", "magazine_sizes", "box_sizes", "price_per_round", "pellets"]
		"item":
			return ["id", "nombre", "name", "apilable", "max_stack", "peso", "tags", "description", "ammo_type", "rounds", "model", "weight_kg", "price"]
		"npc_type":
			return common + ["role", "models", "aliases", "health", "speed", "weapon_id", "zombie", "behavior_tree"]
		"surface":
			return common + [
				"penetration", "bounce", "absorption", "thickness", "transfer", "effect",
				"color", "aliases",
			]
		"vehicle":
			return common + ["kind", "model", "mass", "max_speed", "engine_force", "brake", "health"]
		"sound_bank":
			return common + ["category", "files", "layers", "loop"]
		"gore_profile":
			return common + ["level", "decal_limit", "particle_limit", "parts_limit", "puddle_limit"]
	return common


func _validate_weapon(def: Dictionary, errors: Array) -> void:
	_check_string(def, "name", errors)
	_check_num(def, "damage", 0.0, errors)
	_check_num(def, "fire_rate", 0.0001, errors)
	_check_num(def, "range", 0.0001, errors)
	_check_int(def, "mag", 0, errors)
	_check_enum(def, "fire_mode", ["semi", "auto", "burst"], errors)
	# burst_count and burst_delay are only required for burst fire mode
	var fire_mode := str(def.get("fire_mode", "semi"))
	if fire_mode == "burst":
		_check_int(def, "burst_count", 1, errors)
		_check_num(def, "burst_delay", 0.0, errors)
	else:
		_check_optional_int(def, "burst_count", 1, errors)
		_check_optional_num(def, "burst_delay", 0.0, errors)
	_check_bool(def, "auto", errors)
	_check_num(def, "spread", 0.0, errors)
	_check_int(def, "pellets", 1, errors)
	_check_strings(def, "tags", errors, true)
	_check_num(def, "reload_time", 0.0, errors)
	_check_num(def, "weight", 0.0, errors)
	_check_num(def, "impulse", 0.0, errors)
	_check_bool(def, "uses_ammo", errors)
	_check_num(def, "penetration", 0.0, errors)
	_check_num(def, "falloff_start", 0.0, errors)
	_check_num(def, "falloff_end", 0.0, errors)
	_check_num(def, "falloff_min", 0.0, errors)
	_check_num(def, "projectile_speed", 0.0, errors)
	_check_num(def, "projectile_gravity", 0.0, errors)
	_check_num(def, "projectile_min_distance", 0.0001, errors)
	_check_num(def, "impact_speed", 0.0, errors)
	_check_num(def, "effect_scale", 0.0001, errors)
	_check_int(def, "max_penetrations", 0, errors)
	_check_int(def, "max_ricochets", 0, errors)
	_check_num_range(def, "penetration", 0.0, 1.0, errors)
	_check_optional_string(def, "model", errors)
	_check_optional_string(def, "ammo_id", errors)
	_check_optional_string(def, "caliber", errors)
	_check_optional_string(def, "description", errors)


func _validate_ammo(def: Dictionary, errors: Array) -> void:
	_check_string(def, "name", errors)
	_check_string(def, "weapon", errors)
	_check_string(def, "caliber", errors)
	_check_int(def, "magazine", 0, errors)
	_check_num(def, "damage", 0.0, errors)
	_check_bool(def, "uses_ammo", errors)
	_check_strings(def, "tags", errors, false)
	_check_optional_string(def, "description", errors)


func _validate_item(def: Dictionary, errors: Array) -> void:
	if not def.has("nombre") and def.has("name"):
		def["nombre"] = def["name"]
	_check_string(def, "nombre", errors)
	_check_bool(def, "apilable", errors)
	_check_int(def, "max_stack", 1, errors)
	_check_num(def, "peso", 0.0, errors)
	_check_strings(def, "tags", errors, false)
	_check_optional_string(def, "description", errors)


func _validate_npc_type(def: Dictionary, errors: Array) -> void:
	_check_string(def, "name", errors)
	_check_string(def, "role", errors)
	_check_strings(def, "models", errors, true)
	_check_strings(def, "aliases", errors, false)
	_check_num(def, "health", 0.0001, errors)
	_check_num(def, "speed", 0.0, errors)
	_check_bool(def, "zombie", errors)
	_check_optional_string(def, "weapon_id", errors)
	_check_optional_string(def, "description", errors)


func _validate_surface(def: Dictionary, errors: Array) -> void:
	_check_string(def, "name", errors)
	for key in ["penetration", "bounce", "absorption", "thickness", "transfer"]:
		_check_num_range(def, key, 0.0, 4.0, errors)
	var effect := str(def.get("effect", ""))
	if not ["blood", "sparks", "splinters", "dust", "shards", "splash"].has(effect):
		errors.append("effect: valor invalido '%s'" % effect)
	var color: Variant = def.get("color", null)
	if typeof(color) != TYPE_ARRAY or (color as Array).size() < 3:
		errors.append("color: se esperaba un array de 3 o 4 componentes")
	else:
		var converted: Array = []
		for component in color:
			if typeof(component) != TYPE_FLOAT and typeof(component) != TYPE_INT:
				errors.append("color: componentes numericos requeridos")
				break
			converted.append(clampf(float(component), 0.0, 1.0))
		if converted.size() >= 3:
			def["color"] = converted
	_check_strings(def, "aliases", errors, true)
	_check_optional_string(def, "description", errors)


func _validate_vehicle(def: Dictionary, errors: Array) -> void:
	_check_string(def, "name", errors)
	_check_string(def, "kind", errors)
	_check_string(def, "model", errors)
	_check_num(def, "mass", 0.0001, errors)
	_check_num(def, "max_speed", 0.0001, errors)
	_check_num(def, "engine_force", 0.0001, errors)
	_check_num(def, "brake", 0.0001, errors)
	_check_num(def, "health", 0.0001, errors)
	_check_optional_string(def, "description", errors)


func _validate_sound_bank(def: Dictionary, errors: Array) -> void:
	_check_string(def, "name", errors)
	_check_string(def, "category", errors)
	_check_strings(def, "files", errors, false)
	_check_strings(def, "layers", errors, false)
	_check_bool(def, "loop", errors)
	_check_optional_string(def, "description", errors)


func _validate_gore_profile(def: Dictionary, errors: Array) -> void:
	_check_string(def, "name", errors)
	var level := str(def.get("level", ""))
	if not ["off", "normal", "extreme"].has(level):
		errors.append("level: valor invalido '%s'" % level)
	_check_int(def, "decal_limit", 0, errors)
	_check_int(def, "particle_limit", 0, errors)
	_check_int(def, "parts_limit", 0, errors)
	_check_int(def, "puddle_limit", 0, errors)
	_check_optional_string(def, "description", errors)


func _check_string(def: Dictionary, key: String, errors: Array) -> void:
	var value: Variant = def.get(key, null)
	if typeof(value) != TYPE_STRING or str(value).strip_edges().is_empty():
		errors.append("%s: String no vacio obligatorio" % key)
	else:
		def[key] = str(value)


func _check_optional_string(def: Dictionary, key: String, errors: Array) -> void:
	if not def.has(key):
		return
	if typeof(def[key]) != TYPE_STRING:
		errors.append("%s: debe ser String" % key)
		return
	def[key] = str(def[key])


func _check_optional_int(def: Dictionary, key: String, minimum: int, errors: Array) -> void:
	if not def.has(key):
		return
	var value: Variant = def.get(key, null)
	var number: int = 0
	match typeof(value):
		TYPE_INT:
			number = int(value)
		TYPE_FLOAT:
			var real: float = value
			if floor(real) != real:
				errors.append("%s: debe ser un entero" % key)
				return
			number = int(real)
		_:
			errors.append("%s: entero obligatorio" % key)
			return
	if number < minimum:
		errors.append("%s: debe ser >= %s" % [key, str(minimum)])


func _check_optional_num(def: Dictionary, key: String, minimum: float, errors: Array) -> void:
	if not def.has(key):
		return
	var value: Variant = def.get(key, null)
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		errors.append("%s: numero obligatorio" % key)
		return
	var number := float(value)
	if number < minimum:
		errors.append("%s: debe ser >= %s" % [key, str(minimum)])


func _check_num(def: Dictionary, key: String, minimum: float, errors: Array) -> void:
	var value: Variant = def.get(key, null)
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		errors.append("%s: numero obligatorio" % key)
		return
	var number := float(value)
	if number < minimum:
		errors.append("%s: debe ser >= %s" % [key, str(minimum)])
		return
	def[key] = number


func _check_num_range(def: Dictionary, key: String, minimum: float, maximum: float, errors: Array) -> void:
	_check_num(def, key, minimum, errors)
	if def.has(key) and typeof(def[key]) == TYPE_FLOAT and float(def[key]) > maximum:
		errors.append("%s: debe ser <= %s" % [key, str(maximum)])


func _check_int(def: Dictionary, key: String, minimum: int, errors: Array) -> void:
	var value: Variant = def.get(key, null)
	var number: int = 0
	match typeof(value):
		TYPE_INT:
			number = int(value)
		TYPE_FLOAT:
			var real: float = value
			if floor(real) != real:
				errors.append("%s: debe ser un entero" % key)
				return
			number = int(real)
		_:
			errors.append("%s: entero obligatorio" % key)
			return
	if number < minimum:
		errors.append("%s: debe ser >= %d" % [key, minimum])
		return
	def[key] = number


func _check_bool(def: Dictionary, key: String, errors: Array) -> void:
	if typeof(def.get(key, null)) != TYPE_BOOL:
		errors.append("%s: bool obligatorio" % key)


func _check_enum(def: Dictionary, key: String, allowed: Array, errors: Array) -> void:
	var value: Variant = def.get(key, null)
	if typeof(value) != TYPE_STRING:
		errors.append("%s: String obligatorio" % key)
		return
	if not allowed.has(value):
		errors.append("%s: valor no valido '%s', permitidos: %s" % [key, value, allowed])


func _check_strings(def: Dictionary, key: String, errors: Array, required: bool) -> void:
	var value: Variant = def.get(key, null)
	if value == null and not required:
		def[key] = []
		return
	if typeof(value) != TYPE_ARRAY:
		errors.append("%s: Array de String obligatorio" % key)
		return
	var result: Array = []
	for item in value:
		if typeof(item) != TYPE_STRING:
			errors.append("%s: cada elemento debe ser String" % key)
			return
		var text := str(item).strip_edges().to_lower()
		if not text.is_empty() and not result.has(text):
			result.append(text)
	if required and result.is_empty():
		errors.append("%s: al menos un valor" % key)
	def[key] = result


func _valid_mod_id(value: String) -> bool:
	var parts := value.split(".")
	if parts.size() != 2:
		return false
	return _valid_word(parts[0]) and _valid_word(parts[1])


func _valid_canonical_id(value: String) -> bool:
	var parts := value.split(":")
	if parts.size() != 2:
		return false
	if not _valid_mod_id(parts[0]):
		return false
	var local := parts[1]
	if local.is_empty() or local != local.to_lower():
		return false
	for c in local:
		var digit := "0123456789".contains(c)
		var letter := "abcdefghijklmnopqrstuvwxyz".contains(c)
		if not digit and not letter and c != "_" and c != "-":
			return false
	return true


func _valid_word(value: String) -> bool:
	if value.is_empty() or value != value.to_lower():
		return false
	for c in value:
		var digit := "0123456789".contains(c)
		var letter := "abcdefghijklmnopqrstuvwxyz".contains(c)
		if not digit and not letter and c != "-" and c != "_":
			return false
	return true
