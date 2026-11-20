class_name ItemDb
extends RefCounted

const DEFAULT_MAX_STACK := 1
const DEFAULT_STACKABLE_MAX_STACK := 64

var _items: Dictionary = {}
var _log: Array = []


func _init(defs: Array = []) -> void:
	for def in defs:
		register(def)


func register(def: Variant) -> bool:
	var parsed := parse(def)
	var label := ""
	if typeof(def) == TYPE_DICTIONARY:
		label = str((def as Dictionary).get("id", ""))
	if not parsed["ok"]:
		_record("item '%s' rechazado: %s" % [label, "; ".join(parsed["errors"])])
		return false

	var normalized: Dictionary = parsed["definition"]
	var id := str(normalized["id"])
	if _items.has(id):
		_record("id duplicado '%s'" % id)
		return false

	_items[id] = normalized
	return true


func load_json(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if parsed == null:
		var failure := {"ok": false, "registered": 0, "errors": ["JSON invalido"]}
		_record(failure["errors"][0])
		return failure

	var defs: Array = []
	if typeof(parsed) == TYPE_DICTIONARY:
		var root: Dictionary = parsed
		if root.has("items") and typeof(root["items"]) == TYPE_ARRAY:
			defs = root["items"]
		else:
			defs = [root]
	elif typeof(parsed) == TYPE_ARRAY:
		defs = parsed
	else:
		var failure := {"ok": false, "registered": 0, "errors": ["JSON: se esperaba objeto o array"]}
		_record(failure["errors"][0])
		return failure

	var registered := 0
	var errors: Array = []
	for def in defs:
		if register(def):
			registered += 1
		else:
			var last := "error desconocido"
			if not _log.is_empty():
				last = str(_log[_log.size() - 1])
			errors.append(last)
	return {
		"ok": errors.is_empty(),
		"registered": registered,
		"errors": errors,
	}


func has(id: String) -> bool:
	return _items.has(id)


func get_def(id: String) -> Dictionary:
	if not _items.has(id):
		return {}
	return (_items[id] as Dictionary).duplicate(true)


func list() -> Array:
	var ids: Array = _items.keys()
	ids.sort()
	return ids


func all() -> Dictionary:
	return _items.duplicate(true)


func unregister(id: String) -> bool:
	if not _items.has(id):
		return false
	_items.erase(id)
	return true


func get_log() -> Array:
	return _log.duplicate()


func clear_log() -> void:
	_log.clear()


static func parse(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"ok": false,
			"errors": ["item: se esperaba un Dictionary"],
			"definition": {},
		}

	var raw: Dictionary = data
	var def: Dictionary = raw.duplicate(true)
	var errors: Array = []

	var id := _string(raw.get("id", ""))
	def["id"] = id
	if id.is_empty():
		errors.append("id: campo obligatorio ausente")
	elif not _valid_id(id):
		errors.append("id: formato invalido '%s'" % id)

	var nombre := _string(raw.get("nombre", raw.get("name", ""))).strip_edges()
	def["nombre"] = nombre
	if nombre.is_empty():
		errors.append("nombre: campo obligatorio ausente")

	var apilable := false
	var raw_apilable = raw.get("apilable", raw.get("stackable", false))
	if typeof(raw_apilable) != TYPE_BOOL:
		errors.append("apilable: debe ser bool")
	else:
		apilable = raw_apilable
	def["apilable"] = apilable

	var max_stack := DEFAULT_MAX_STACK
	var raw_max_stack = raw.get("max_stack", null)
	if raw_max_stack == null:
		max_stack = DEFAULT_STACKABLE_MAX_STACK if apilable else DEFAULT_MAX_STACK
	else:
		var parsed_stack = _int(raw_max_stack)
		if parsed_stack == null or parsed_stack < 1:
			errors.append("max_stack: debe ser un entero >= 1")
		else:
			max_stack = parsed_stack
	if not apilable:
		max_stack = DEFAULT_MAX_STACK
	def["max_stack"] = max_stack

	var peso := 0.0
	var raw_peso = raw.get("peso", raw.get("weight", 0.0))
	match typeof(raw_peso):
		TYPE_INT, TYPE_FLOAT:
			peso = float(raw_peso)
		TYPE_STRING:
			var text := str(raw_peso).strip_edges()
			if text.is_valid_float():
				peso = text.to_float()
			else:
				errors.append("peso: debe ser numerico")
		_:
			errors.append("peso: debe ser numerico")
	if peso < 0.0:
		errors.append("peso: no puede ser negativo")
	def["peso"] = peso

	var raw_tags = raw.get("tags", [])
	if typeof(raw_tags) != TYPE_ARRAY:
		errors.append("tags: debe ser un Array")
		def["tags"] = []
	else:
		var tags: Array = []
		for tag in raw_tags:
			if typeof(tag) != TYPE_STRING:
				errors.append("tags: cada etiqueta debe ser String")
				break
			var text := str(tag).strip_edges().to_lower()
			if text.is_empty() or tags.has(text):
				continue
			tags.append(text)
		def["tags"] = tags

	if not errors.is_empty():
		return {"ok": false, "errors": errors, "definition": {}}
	return {"ok": true, "errors": [], "definition": def}


static func _valid_id(id: String) -> bool:
	if id.is_empty() or id != id.to_lower():
		return false
	for c in id:
		var digit := c >= "0" and c <= "9"
		var letter := c >= "a" and c <= "z"
		if not digit and not letter and c != "_" and c != "-":
			return false
	return true


static func _string(value: Variant) -> String:
	if typeof(value) == TYPE_STRING:
		return value
	if typeof(value) == TYPE_STRING_NAME:
		return String(value)
	return ""


static func _int(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			var number: float = value
			if floor(number) == number:
				return int(number)
		TYPE_STRING:
			var text := str(value).strip_edges()
			if text.is_valid_int():
				return int(text)
	return null


func _record(message: String) -> void:
	if not _log.has(message):
		_log.append(message)
