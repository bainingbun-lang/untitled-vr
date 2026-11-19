class_name MapCatalog
extends RefCounted

const MapValidatorScript = preload("res://core/maps/map_validator.gd")

const STATUS_CRITERIA: Array = [
	"status",
	"compatibility",
	"compatibility_status",
	"compat_status",
	"compat",
]

const FILTER_CRITERIA := {
	"platforms": "platforms",
	"platform": "platforms",
	"supported_platforms": "platforms",
	"tags": "tags",
	"tag": "tags",
	"players_min": "players_min",
	"min_players": "players_min",
	"min_player_count": "players_min",
	"players_max": "players_max",
	"max_players": "players_max",
	"max_player_count": "players_max",
	"players": "players",
	"player_count": "players",
}

const STATUS_NAMES := {
	MapValidatorScript.Status.COMPATIBLE: "compatible",
	MapValidatorScript.Status.COMPATIBLE_WITH_WARNINGS: "compatible_with_warnings",
	MapValidatorScript.Status.REQUIRES_ADAPTATION: "requires_adaptation",
	MapValidatorScript.Status.INCOMPATIBLE: "incompatible",
}

const STATUS_VALUE_ALIASES := {
	"ok": MapValidatorScript.Status.COMPATIBLE,
	"warning": MapValidatorScript.Status.COMPATIBLE_WITH_WARNINGS,
	"warnings": MapValidatorScript.Status.COMPATIBLE_WITH_WARNINGS,
}

var _registry
var _log: Array = []

func _init(registry = null) -> void:
	_registry = registry

func get_log() -> Array:
	return _log.duplicate()

func clear_log() -> void:
	_log.clear()

func filter(criteria: Dictionary) -> Array:
	if _registry == null or not _registry.has_method("list"):
		_record_error("MapCatalog: MapRegistry no disponible")
		return []

	var names: Array = []
	for key in criteria.keys():
		names.append(str(key))
	for name in names:
		if not STATUS_CRITERIA.has(name) and not FILTER_CRITERIA.has(name):
			_record_error("MapCatalog: criterio desconocido '%s'" % name)
			return []

	var statuses: Array = []
	for key in STATUS_CRITERIA:
		if not criteria.has(key) or criteria[key] == null:
			continue
		var parsed = _parse_statuses(criteria[key])
		if parsed == null:
			_record_error("MapCatalog: valor de compatibilidad invalido en '%s'" % str(key))
			return []
		for status in parsed:
			if not statuses.has(status):
				statuses.append(status)

	var filters: Dictionary = {}
	for name in names:
		if not FILTER_CRITERIA.has(name):
			continue
		var canonical: String = str(FILTER_CRITERIA[name])
		var value = criteria[name]
		if value == null:
			continue
		var parsed = _parse_filter_value(canonical, value)
		if parsed == null:
			_record_error("MapCatalog: valor invalido en criterio '%s'" % name)
			return []
		if not filters.has(canonical):
			filters[canonical] = []
		var constraints: Array = filters[canonical]
		constraints.append(parsed)

	var validator = MapValidatorScript.new()
	var ids: Array = []
	for meta in _registry.list():
		if not (meta is Dictionary):
			continue
		var raw_id = meta.get("id")
		if raw_id == null or str(raw_id) == "":
			continue
		if not statuses.is_empty():
			var validation: Dictionary = validator.validate(meta)
			var status: int = validation.get("status", MapValidatorScript.Status.INCOMPATIBLE)
			if not statuses.has(status):
				continue
		if not _matches_filters(meta, filters):
			continue
		ids.append(str(raw_id))

	ids.sort()
	return ids

func _parse_statuses(value) -> Variant:
	if value is Array:
		var result: Array = []
		for item in value:
			var parsed = _parse_statuses(item)
			if parsed == null:
				return null
			for status in parsed:
				if not result.has(status):
					result.append(status)
		return result
	if value is int:
		return _status_from_int(value)
	if value is float:
		return _status_from_int(int(value))
	if value is String:
		var result: Array = []
		for token in str(value).split(","):
			var text := str(token).strip_edges().to_lower()
			if text == "":
				continue
			if STATUS_VALUE_ALIASES.has(text):
				result.append(int(STATUS_VALUE_ALIASES[text]))
				continue
			if text.is_valid_int():
				var parsed = _status_from_int(int(text))
				if parsed == null:
					return null
				for status in parsed:
					if not result.has(status):
						result.append(status)
				continue
			var found := false
			for status in STATUS_NAMES:
				if str(STATUS_NAMES[status]) == text:
					result.append(int(status))
					found = true
					break
			if not found:
				return null
		return result
	return null

func _status_from_int(value: int) -> Variant:
	if STATUS_NAMES.has(value):
		return [value]
	return null

func _parse_filter_value(canonical: String, value) -> Variant:
	if canonical == "platforms" or canonical == "tags":
		return _filter_string_list(value)
	return _filter_int(value)

func _filter_string_list(value) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			var result: Array = []
			for item in value:
				var text := str(item).strip_edges().to_lower()
				if text != "" and not result.has(text):
					result.append(text)
			return result
		TYPE_STRING:
			var text := str(value).strip_edges()
			if text == "":
				return []
			if text.begins_with("["):
				var parsed = JSON.parse_string(text)
				if parsed is Array:
					return _filter_string_list(parsed)
				return null
			var result: Array = []
			for token in text.split(","):
				var token_text := str(token).strip_edges().to_lower()
				if token_text != "" and not result.has(token_text):
					result.append(token_text)
			return result
		_:
			return null

func _filter_int(value) -> Variant:
	var number: Variant = null
	match typeof(value):
		TYPE_INT:
			number = int(value)
		TYPE_FLOAT:
			var candidate: float = value
			if floor(candidate) != candidate:
				return null
			number = int(candidate)
		TYPE_STRING:
			var text := str(value).strip_edges()
			if text.is_valid_int():
				number = int(text)
			elif text.is_valid_float():
				var candidate := text.to_float()
				if floor(candidate) != candidate:
					return null
				number = int(candidate)
			else:
				return null
		_:
			return null
	var result: int = number
	if result < 1:
		return null
	return result

func _matches_filters(meta: Dictionary, filters: Dictionary) -> bool:
	for canonical in filters.keys():
		var constraints: Array = filters[canonical]
		for constraint in constraints:
			if not _matches_constraint(meta, str(canonical), constraint):
				return false
	return true

func _matches_constraint(meta: Dictionary, canonical: String, constraint) -> bool:
	match canonical:
		"platforms", "tags":
			var declared = meta.get(canonical)
			if not (declared is Array):
				return false
			var available: Array = []
			for item in declared:
				available.append(str(item).strip_edges().to_lower())
			for requested in constraint:
				if not available.has(str(requested)):
					return false
			return true
		"players_min":
			var available_max = _meta_int(meta.get("players_max"))
			return available_max != null and int(available_max) >= int(constraint)
		"players_max":
			var available_min = _meta_int(meta.get("players_min"))
			return available_min != null and int(available_min) <= int(constraint)
		"players":
			var available_min = _meta_int(meta.get("players_min"))
			var available_max = _meta_int(meta.get("players_max"))
			if available_min == null or available_max == null:
				return false
			var requested: int = int(constraint)
			return int(available_min) <= requested and requested <= int(available_max)
	return false

func _meta_int(value) -> Variant:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			var number: float = value
			if floor(number) == number:
				return int(number)
		_:
			pass
	return null

func _record_error(message: String) -> void:
	if not _log.has(message):
		_log.append(message)
	push_error(message)
