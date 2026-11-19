class_name MapAdapter
extends RefCounted

const MapValidatorScript = preload("res://core/maps/map_validator.gd")
const MapMetadataScript = preload("res://core/maps/map_metadata.gd")

const SCHEMA := [
	"id",
	"version",
	"author",
	"license",
	"scale",
	"has_collisions",
	"has_navigation",
	"spawn_points",
	"forbidden_zones",
	"performance_profiles",
	"zones",
	"main_scene",
	"boundaries",
	"exits",
	"platforms",
	"tags",
	"players_min",
	"players_max",
]

const ALIASES := {
	"id": [
		"map_id", "mapid", "uid", "uuid", "guid", "identifier",
		"map_identifier", "unique_id", "uniqueid", "unique_identifier", "key",
	],
	"license": [
		"licence", "map_license", "license_name", "license_type", "lic",
	],
	"version": [
		"map_version", "schema_version", "revision", "map_revision",
	],
	"author": [
		"creator", "map_author", "author_name", "created_by", "createdby",
	],
	"scale": [
		"map_scale", "global_scale", "unit_scale", "world_scale",
	],
	"has_collisions": [
		"collision", "collisions", "collision_shapes", "has_collision",
		"colliders", "baked_collisions",
	],
	"has_navigation": [
		"navigation", "navmesh", "navigation_mesh", "has_navmesh",
		"baked_navigation", "baked_navmesh", "nav",
	],
	"spawn_points": [
		"spawn", "spawns", "spawn_positions", "player_spawns",
		"player_spawn_points", "start_positions", "start_points", "starts",
	],
	"forbidden_zones": [
		"forbidden_areas", "no_go_zones", "blocked_zones", "blocked_areas",
		"restricted_zones", "restricted_areas",
	],
	"zones": [
		"areas", "trigger_zones", "event_zones", "named_areas",
	],
	"performance_profiles": [
		"perf_profiles", "performance", "profiles", "resource_limits",
	],
	"main_scene": [
		"entry_scene", "root_scene", "scene", "scene_path",
	],
	"boundaries": [
		"bounds", "map_boundaries", "borders", "limits",
	],
	"exits": [
		"exit_zones", "exit_portals", "portals", "exit_points",
	],
	"platforms": [
		"platform", "supported_platforms", "target_platforms", "device", "devices",
	],
	"tags": [
		"tag", "labels", "label", "keywords", "keyword", "categories",
	],
	"players_min": [
		"min_players", "min_player_count", "minimum_players", "playersmin",
	],
	"players_max": [
		"max_players", "max_player_count", "maximum_players", "playersmax",
	],
}

const PLATFORM_ALIASES := {
	"mobile": "android",
	"android": "android",
	"pc": "pc",
	"desktop": "pc",
	"windows": "pc",
	"linux": "pc",
	"vr": "vr",
	"quest": "vr",
	"oculus": "vr",
}

const TRUE_VALUES := ["true", "yes", "si", "sí", "1", "on", "y", "t"]
const FALSE_VALUES := ["false", "no", "0", "off", "n", "f", ""]


static func adapt(raw: Dictionary) -> Dictionary:
	var meta: Dictionary = MapMetadataScript.new().metadata.duplicate(true)
	var warnings: Array = []
	var errors: Array = []
	var normals := _canonical_normals()
	var lookup := _alias_lookup(normals)
	var candidates: Dictionary = {}

	for key in raw.keys():
		var source: String = str(key)
		var normalized := _normalize_key(source)
		var canonical: String = ""
		var alias: bool = false
		if normals.has(normalized):
			canonical = normals[normalized]
		elif lookup.has(normalized):
			canonical = lookup[normalized]
			alias = true
		else:
			meta[key] = raw[key]
			warnings.append("Campo desconocido preservado: '%s'" % source)
			continue

		var candidate := {
			"value": raw[key],
			"source": source,
			"alias": alias,
		}
		if candidates.has(canonical):
			var previous: Dictionary = candidates[canonical]
			if bool(previous["alias"]) and not alias:
				warnings.append(
					"Campo '%s' ignorado: prevalece '%s'"
					% [str(previous["source"]), source]
				)
				candidates[canonical] = candidate
			else:
				warnings.append(
					"Campo duplicado ignorado: '%s' (se usa '%s')"
					% [source, str(previous["source"])]
				)
		else:
			candidates[canonical] = candidate

	for field in SCHEMA:
		if not candidates.has(field):
			continue
		var candidate: Dictionary = candidates[field]
		_apply_field(
			field,
			candidate["value"],
			meta,
			errors,
			warnings,
			str(candidate["source"]),
			bool(candidate["alias"])
		)

	var validator = MapValidatorScript.new()
	var validation: Dictionary = validator.validate(meta)
	for error in validation.get("errors", []):
		var message := str(error)
		if not errors.has(message):
			errors.append(message)
	for warning in validation.get("warnings", []):
		var message := str(warning)
		if not warnings.has(message):
			warnings.append(message)

	var status: int = validation.get("status", MapValidatorScript.Status.INCOMPATIBLE)
	var ok: bool = errors.is_empty() and status <= MapValidatorScript.Status.COMPATIBLE_WITH_WARNINGS
	return {
		"ok": ok,
		"meta": meta,
		"warnings": warnings,
		"errors": errors,
	}


static func _canonical_normals() -> Dictionary:
	var normals := {}
	for field in SCHEMA:
		normals[_normalize_key(field)] = field
	return normals


static func _alias_lookup(normals: Dictionary) -> Dictionary:
	var lookup := normals.duplicate()
	for canonical in ALIASES:
		for alias in ALIASES[canonical]:
			lookup[_normalize_key(alias)] = canonical
	return lookup


static func _normalize_key(key: Variant) -> String:
	var value := str(key).to_lower()
	var out := ""
	for character in value:
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			out += character
	return out


static func _apply_field(
	field: String,
	value: Variant,
	meta: Dictionary,
	errors: Array,
	warnings: Array,
	source: String,
	renamed: bool
) -> void:
	if renamed:
		warnings.append("Campo renombrado '%s' -> '%s'" % [source, field])

	if field in ["id", "license", "version", "author", "main_scene"]:
		var converted: Variant = _as_string(value)
		if converted == null:
			errors.append(
				"%s: se esperaba String, se recibio %s" % [field, type_string(typeof(value))]
			)
		else:
			meta[field] = converted
	elif field == "scale":
		var converted: Variant = _as_float(value)
		if converted == null:
			errors.append(
				"scale: se esperaba numero, se recibio %s" % type_string(typeof(value))
			)
		else:
			meta[field] = converted
	elif field in ["has_collisions", "has_navigation"]:
		var converted: Variant = _as_bool(value)
		if converted == null:
			errors.append(
				"%s: se esperaba bool, se recibio %s" % [field, type_string(typeof(value))]
			)
		else:
			meta[field] = converted
	elif field in ["spawn_points", "forbidden_zones", "zones", "boundaries", "exits"]:
		var converted: Variant = _as_array(value)
		if converted == null:
			errors.append(
				"%s: se esperaba Array, se recibio %s" % [field, type_string(typeof(value))]
			)
		else:
			meta[field] = converted
	elif field == "performance_profiles":
		var converted: Variant = _as_dictionary(value)
		if converted == null:
			errors.append(
				"performance_profiles: se esperaba Dictionary, se recibio %s"
				% type_string(typeof(value))
			)
		else:
			meta[field] = converted
	elif field == "platforms":
		var converted: Variant = _as_platform_list(value)
		if converted == null:
			errors.append(
				"platforms: se esperaba una lista de android/pc/vr, se recibio %s"
				% type_string(typeof(value))
			)
		else:
			meta[field] = converted
	elif field == "tags":
		var converted: Variant = _as_string_list(value)
		if converted == null:
			errors.append(
				"tags: se esperaba una lista de strings, se recibio %s"
				% type_string(typeof(value))
			)
		else:
			meta[field] = converted
	elif field in ["players_min", "players_max"]:
		var converted: Variant = _as_int(value)
		if converted == null:
			errors.append(
				"%s: se esperaba un entero, se recibio %s"
				% [field, type_string(typeof(value))]
			)
		else:
			meta[field] = converted


static func _as_platform_list(value: Variant) -> Variant:
	var items: Variant = _as_string_list(value)
	if items == null:
		return null
	var result: Array = []
	for item in items:
		var text := str(item).strip_edges().to_lower()
		if text == "":
			continue
		if PLATFORM_ALIASES.has(text):
			text = str(PLATFORM_ALIASES[text])
		if not result.has(text):
			result.append(text)
	return result


static func _as_string_list(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			var result: Array = []
			for item in value:
				var converted: Variant = _as_string(item)
				if converted == null:
					return null
				var text := str(converted).strip_edges()
				if text != "" and not result.has(text):
					result.append(text)
			return result
		TYPE_STRING:
			var text := str(value).strip_edges()
			if text == "":
				return []
			if text.begins_with("[") or text.begins_with("{"):
				var parsed: Variant = JSON.parse_string(text)
				if parsed is Array:
					return _as_string_list(parsed)
				return null
			var result: Array = []
			for token in text.split(","):
				var token_text := str(token).strip_edges()
				if token_text != "" and not result.has(token_text):
					result.append(token_text)
			return result
		TYPE_DICTIONARY:
			return _as_string_list([value])
		_:
			return null


static func _as_int(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			var number: float = value
			if floor(number) == number:
				return int(number)
			return null
		TYPE_STRING:
			var text := str(value).strip_edges()
			if text.is_valid_int():
				return int(text)
			if text.is_valid_float():
				var number := text.to_float()
				if floor(number) == number:
					return int(number)
			return null
		_:
			return null


static func _as_string(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
			return str(value)
		_:
			return null


static func _as_float(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return value
		TYPE_INT:
			return float(value)
		TYPE_STRING:
			var text: String = value
			text = text.strip_edges()
			if text.is_valid_float() or text.is_valid_int():
				return text.to_float()
			return null
		_:
			return null


static func _as_bool(value: Variant) -> Variant:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT:
			return value != 0
		TYPE_FLOAT:
			return value != 0.0
		TYPE_STRING:
			var text: String = value
			text = text.strip_edges().to_lower()
			if text in TRUE_VALUES:
				return true
			if text in FALSE_VALUES:
				return false
			return null
		_:
			return null


static func _as_array(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			return (value as Array).duplicate(true)
		TYPE_DICTIONARY:
			return [value]
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4:
			return [value]
		TYPE_STRING:
			var text: String = value
			text = text.strip_edges()
			if text.begins_with("[") or text.begins_with("{"):
				var parsed: Variant = JSON.parse_string(text)
				if parsed is Array:
					return parsed
				if parsed is Dictionary:
					return [parsed]
			var parts := text.split(",")
			if _all_numbers(parts):
				if parts.size() == 3:
					return [Vector3(_number(parts[0]), _number(parts[1]), _number(parts[2]))]
				if parts.size() == 2:
					return [Vector2(_number(parts[0]), _number(parts[1]))]
			return null
		_:
			return null


static func _as_dictionary(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
		TYPE_STRING:
			var text: String = value
			text = text.strip_edges()
			if text.begins_with("{"):
				var parsed: Variant = JSON.parse_string(text)
				if parsed is Dictionary:
					return parsed
			return null
		_:
			return null


static func _all_numbers(parts: Array) -> bool:
	for part in parts:
		var text: String = str(part).strip_edges()
		if not text.is_valid_float() and not text.is_valid_int():
			return false
	return true


static func _number(part: Variant) -> float:
	return str(part).strip_edges().to_float()
