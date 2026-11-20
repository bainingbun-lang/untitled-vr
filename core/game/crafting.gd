class_name Crafting
extends RefCounted

const RECIPE_VERSION := 1
const ItemDbScript = preload("res://core/game/item_db.gd")
const InventoryScript = preload("res://core/game/inventory.gd")

var _db
var _recipes: Dictionary = {}
var _log: Array = []


func _init(db = null) -> void:
	_db = db if db != null else ItemDbScript.new()


func register(data: Variant) -> bool:
	var parsed := parse(data)
	var label := ""
	if typeof(data) == TYPE_DICTIONARY:
		label = str((data as Dictionary).get("id", ""))
	if not bool(parsed["ok"]):
		_record("receta '%s' rechazada: %s" % [label, _join(parsed["errors"])])
		return false

	var recipe: Dictionary = parsed["recipe"]
	var id := str(recipe["id"])
	if _recipes.has(id):
		_record("id duplicado '%s'" % id)
		return false

	var unknown: Array = []
	for field in ["inputs", "outputs"]:
		for item_id in (recipe[field] as Dictionary).keys():
			if _db == null or not _db.has(str(item_id)):
				unknown.append(str(item_id))
	if not unknown.is_empty():
		_record("receta '%s' rechazada: item desconocido '%s'" % [id, unknown[0]])
		return false

	_recipes[id] = recipe
	return true


func load_json(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if parsed == null:
		var failure := {"ok": false, "registered": 0, "errors": ["JSON invalido"]}
		_record(failure["errors"][0])
		return failure
	return load_data(parsed)


func load_data(data: Variant) -> Dictionary:
	var recipes: Array = []
	if typeof(data) == TYPE_ARRAY:
		recipes = data
	elif typeof(data) == TYPE_DICTIONARY:
		var root: Dictionary = data
		if root.has("recipes") and typeof(root["recipes"]) == TYPE_ARRAY:
			recipes = root["recipes"]
		elif root.has("recetas") and typeof(root["recetas"]) == TYPE_ARRAY:
			recipes = root["recetas"]
		else:
			for key in root.keys():
				var entry = root[key]
				if typeof(entry) != TYPE_DICTIONARY:
					recipes = []
					break
				var with_id: Dictionary = entry
				if not with_id.has("id"):
					with_id["id"] = _as_string(key)
				recipes.append(with_id)
	else:
		var failure := {"ok": false, "registered": 0, "errors": ["JSON: se esperaba objeto o array"]}
		_record(failure["errors"][0])
		return failure

	var registered := 0
	var errors: Array = []
	for data_recipe in recipes:
		if register(data_recipe):
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
	return _recipes.has(id)


func get_recipe(id: String) -> Dictionary:
	if not _recipes.has(id):
		return {}
	return (_recipes[id] as Dictionary).duplicate(true)


func list() -> Array:
	var ids: Array = _recipes.keys()
	ids.sort()
	return ids


func all() -> Dictionary:
	return _recipes.duplicate(true)


func unregister(id: String) -> bool:
	if not _recipes.has(id):
		return false
	_recipes.erase(id)
	return true


func get_log() -> Array:
	return _log.duplicate()


func clear_log() -> void:
	_log.clear()


func to_dict() -> Dictionary:
	var recipes: Array = []
	for id in list():
		recipes.append((_recipes[id] as Dictionary).duplicate(true))
	return {
		"version": RECIPE_VERSION,
		"recipes": recipes,
	}


func load_snapshot(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return load_data(data)
	var root: Dictionary = data
	if root.has("version"):
		var version = _as_int(root.get("version", RECIPE_VERSION))
		if version == null or int(version) != RECIPE_VERSION:
			var failure := {"ok": false, "registered": 0, "errors": ["version de recetas no soportada"]}
			_record(failure["errors"][0])
			return failure
	return load_data(root)


func can_craft(inventory, recipe_id: String, station_tags: Variant = []) -> Dictionary:
	var recipe := get_recipe(recipe_id)
	if recipe.is_empty():
		return _failure("receta desconocida '%s'" % recipe_id, recipe_id)
	return _plan(inventory, recipe, station_tags)


func craft(inventory, recipe_id: String, station_tags: Variant = []) -> Dictionary:
	var recipe := get_recipe(recipe_id)
	if recipe.is_empty():
		return _failure("receta desconocida '%s'" % recipe_id, recipe_id)

	var plan := _plan(inventory, recipe, station_tags)
	if not bool(plan["ok"]):
		return plan

	var inputs: Dictionary = recipe["inputs"]
	var outputs: Dictionary = recipe["outputs"]
	var snapshot = null
	if inventory.has_method("to_dict"):
		snapshot = inventory.to_dict()

	for item_id in inputs.keys():
		inventory.remove(str(item_id), int(inputs[item_id]))

	var produced: Dictionary = {}
	for item_id in outputs.keys():
		var id := str(item_id)
		var amount := int(outputs[item_id])
		var added = inventory.add(id, amount)
		if typeof(added) != TYPE_DICTIONARY or not bool((added as Dictionary).get("ok", false)):
			var why := "no cabe la salida '%s'" % id
			if typeof(added) == TYPE_DICTIONARY:
				why = str((added as Dictionary).get("reason", why))
			_rollback(inventory, snapshot, produced, inputs)
			return _failure("salida rechazada: %s" % why, recipe_id)
		produced[id] = amount

	return {
		"ok": true,
		"recipe_id": recipe_id,
		"time": float(recipe["time"]),
		"station_tags": (recipe["station_tags"] as Array).duplicate(),
		"consumed": inputs.duplicate(true),
		"produced": produced.duplicate(true),
		"outputs": outputs.duplicate(true),
		"reason": "",
	}


func craftable(inventory, station_tags: Variant = []) -> Array:
	var result: Array = []
	for id in list():
		if bool(_plan(inventory, _recipes[id], station_tags)["ok"]):
			result.append(id)
	return result


func get_craftable(inventory, station_tags: Variant = []) -> Array:
	return craftable(inventory, station_tags)


func get_craftable_recipes(inventory, station_tags: Variant = []) -> Array:
	return craftable(inventory, station_tags)


func list_craftable(inventory, station_tags: Variant = []) -> Array:
	return craftable(inventory, station_tags)


static func parse(data: Variant) -> Dictionary:
	var errors: Array = []
	var recipe: Dictionary = {}
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("receta: se esperaba un Dictionary")
		return {"ok": false, "errors": errors, "recipe": recipe}

	var raw: Dictionary = data
	var id := _as_string(raw.get("id", ""))
	recipe["id"] = id
	if id.is_empty():
		errors.append("id: campo obligatorio ausente")
	elif not _valid_id(id):
		errors.append("id: formato invalido '%s'" % id)

	recipe["inputs"] = _parse_amounts(
		_first(raw, ["inputs", "entradas", "ingredientes"]), "entradas", errors)
	recipe["outputs"] = _parse_amounts(
		_first(raw, ["outputs", "salidas", "resultados"]), "salidas", errors)

	var time_value = _first(raw, ["time", "tiempo"])
	if time_value == null:
		time_value = 0.0
	var time_number = _as_float(time_value)
	if time_number == null or time_number < 0.0:
		errors.append("time: debe ser un numero >= 0")
		time_number = 0.0
	recipe["time"] = float(time_number)

	var station_value: Variant = _first(raw, ["station_tags", "tags_estacion", "estacion_tags", "required_tags", "tags"])
	if station_value != null and typeof(station_value) != TYPE_ARRAY \
		and typeof(station_value) != TYPE_STRING and typeof(station_value) != TYPE_DICTIONARY:
		errors.append("station_tags: debe ser un Array")
	recipe["station_tags"] = _parse_tags(station_value)

	for key in ["inputs", "outputs"]:
		var amounts: Dictionary = recipe[key]
		if amounts.is_empty():
			errors.append("%s: se requiere al menos un item" % key)
		for item_id in amounts.keys():
			if not _valid_id(str(item_id)):
				errors.append("%s: id de item invalido '%s'" % [key, str(item_id)])

	if not errors.is_empty():
		return {"ok": false, "errors": errors, "recipe": {}}
	return {"ok": true, "errors": [], "recipe": recipe}


func _plan(inventory, recipe: Dictionary, station_tags: Variant) -> Dictionary:
	var recipe_id := str(recipe.get("id", ""))
	if inventory == null or not inventory.has_method("can_remove") \
		or not inventory.has_method("can_add") or not inventory.has_method("remove") \
		or not inventory.has_method("add"):
		return _failure("inventario invalido", recipe_id)

	var required: Array = recipe.get("station_tags", [])
	var provided := _parse_tags(station_tags)
	var missing_tags: Array = []
	for tag in required:
		if not provided.has(str(tag)):
			missing_tags.append(str(tag))
	if not missing_tags.is_empty():
		var result := _failure("faltan tags de estacion: %s" % _join(missing_tags), recipe_id)
		result["missing_tags"] = missing_tags
		return result

	var inputs: Dictionary = recipe["inputs"]
	var missing: Array = []
	for item_id in inputs.keys():
		var id := str(item_id)
		var amount := int(inputs[item_id])
		var check = inventory.can_remove(id, amount)
		var removed := 0
		if typeof(check) == TYPE_DICTIONARY:
			removed = int((check as Dictionary).get("removed", 0))
		if typeof(check) != TYPE_DICTIONARY or not bool((check as Dictionary).get("ok", false)):
			missing.append({"id": id, "amount": amount - removed})
	if not missing.is_empty():
		var result := _failure("faltan entradas", recipe_id)
		result["missing"] = missing
		return result

	var simulated = _clone(inventory)
	if simulated == null:
		return _failure("no se puede simular el inventario", recipe_id)
	for item_id in inputs.keys():
		simulated.remove(str(item_id), int(inputs[item_id]))

	var outputs: Dictionary = recipe["outputs"]
	var blocked: Array = []
	for item_id in outputs.keys():
		var id := str(item_id)
		var amount := int(outputs[item_id])
		var check = simulated.can_add(id, amount)
		if typeof(check) != TYPE_DICTIONARY or not bool((check as Dictionary).get("ok", false)):
			var why := "sin capacidad"
			if typeof(check) == TYPE_DICTIONARY:
				why = str((check as Dictionary).get("reason", why))
			blocked.append({"id": id, "amount": amount, "reason": why})
	if not blocked.is_empty():
		var result := _failure("no cabe la salida", recipe_id)
		result["blocked"] = blocked
		return result

	return {
		"ok": true,
		"recipe_id": recipe_id,
		"time": float(recipe["time"]),
		"reason": "",
	}


func _clone(inventory):
	if not inventory.has_method("to_dict") or not inventory.has_method("restore"):
		return null
	var snapshot = inventory.to_dict()
	if typeof(snapshot) != TYPE_DICTIONARY:
		return null
	var capacity := 0
	var weight := -1.0
	if snapshot.has("slot_capacity"):
		capacity = int(_as_int((snapshot as Dictionary)["slot_capacity"]))
	if snapshot.has("max_weight"):
		weight = float(_as_float((snapshot as Dictionary)["max_weight"]))
	var clone = InventoryScript.new(_db, capacity, weight)
	if not clone.restore(snapshot):
		return null
	return clone


func _rollback(inventory, snapshot, produced: Dictionary, inputs: Dictionary) -> void:
	if snapshot != null and inventory.has_method("restore"):
		inventory.restore(snapshot)
		return
	for item_id in produced.keys():
		inventory.remove(str(item_id), int(produced[item_id]))
	for item_id in inputs.keys():
		inventory.add(str(item_id), int(inputs[item_id]))
	_record("crafteo inconsistente: rollback manual aplicado")


func _failure(reason: String, recipe_id: String) -> Dictionary:
	return {
		"ok": false,
		"recipe_id": recipe_id,
		"time": 0.0,
		"reason": reason,
		"missing": [],
		"blocked": [],
	}


static func _parse_amounts(value: Variant, field: String, errors: Array) -> Dictionary:
	var amounts: Dictionary = {}
	if value == null:
		return amounts
	if typeof(value) == TYPE_DICTIONARY:
		for key in (value as Dictionary).keys():
			var id := _as_string(key)
			var parsed = _as_int((value as Dictionary)[key])
			if id.is_empty() or parsed == null or int(parsed) < 1:
				errors.append("%s: '%s' debe tener cantidad entera >= 1" % [field, id])
				continue
			amounts[id] = int(parsed)
		return amounts
	if typeof(value) == TYPE_ARRAY:
		for entry in value:
			if typeof(entry) != TYPE_DICTIONARY:
				errors.append("%s: cada entrada debe ser un Dictionary" % field)
				continue
			var item: Dictionary = entry
			var id := _as_string(_first(item, ["id", "item", "item_id"]))
			var parsed = _as_int(_first(item, ["amount", "cantidad", "count"]))
			if id.is_empty() or parsed == null or int(parsed) < 1:
				errors.append("%s: '%s' debe tener cantidad entera >= 1" % [field, id])
				continue
			amounts[id] = int(parsed)
		return amounts
	errors.append("%s: debe ser un Dictionary" % field)
	return amounts


static func _parse_tags(value: Variant) -> Array:
	var tags: Array = []
	if value == null:
		return tags
	if typeof(value) == TYPE_STRING:
		value = [value]
	if typeof(value) == TYPE_DICTIONARY:
		value = (value as Dictionary).get("tags", (value as Dictionary).get("estacion_tags", []))
	if typeof(value) != TYPE_ARRAY:
		return tags
	for tag in value:
		var text := _as_string(tag).strip_edges().to_lower()
		if text.is_empty() or tags.has(text):
			continue
		tags.append(text)
	return tags


static func _first(source: Dictionary, keys: Array) -> Variant:
	for key in keys:
		if source.has(str(key)):
			return source[str(key)]
	return null


static func _join(parts: Array) -> String:
	var text := ""
	for i in range(parts.size()):
		if i > 0:
			text += "; "
		text += str(parts[i])
	return text


static func _valid_id(id: String) -> bool:
	if id.is_empty() or id != id.to_lower():
		return false
	for c in id:
		var digit := c >= "0" and c <= "9"
		var letter := c >= "a" and c <= "z"
		if not digit and not letter and c != "_" and c != "-":
			return false
	return true


static func _as_string(value: Variant) -> String:
	if typeof(value) == TYPE_STRING:
		return value
	if typeof(value) == TYPE_STRING_NAME:
		return String(value)
	return ""


static func _as_int(value: Variant) -> Variant:
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


static func _as_float(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return float(value)
		TYPE_STRING:
			var text := str(value).strip_edges()
			if text.is_valid_float():
				return text.to_float()
	return null


func _record(message: String) -> void:
	if not _log.has(message):
		_log.append(message)
