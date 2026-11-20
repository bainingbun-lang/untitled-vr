class_name Loadout
extends RefCounted

const WEAPON_DB_PATH := "res://core/game/weapon_db.gd"


static func give_starting_kit(inventory, item_db) -> Dictionary:
	var result := {
		"ok": false,
		"given": [],
		"missing": [],
		"reasons": {},
		"already_owned": [],
	}
	if inventory == null or item_db == null:
		result["reasons"]["invalid"] = "inventario o base de items invalida"
		return result
	if not inventory.has_method("count") or not inventory.has_method("can_add") or not inventory.has_method("add"):
		result["reasons"]["invalid"] = "inventario sin interface compatible"
		return result

	_register_weapons(item_db)
	for id in weapon_ids(item_db):
		if int(inventory.count(id)) > 0:
			result["given"].append(id)
			result["already_owned"].append(id)
			continue
		var check = inventory.can_add(id, 1)
		if not _is_ok(check):
			result["missing"].append(id)
			result["reasons"][id] = _reason(check, "sin capacidad")
			continue
		var added = inventory.add(id, 1)
		if _is_ok(added) and int(added.get("added", 0)) > 0:
			result["given"].append(id)
		else:
			result["missing"].append(id)
			result["reasons"][id] = _reason(added, "sin capacidad")

	result["ok"] = (result["missing"] as Array).is_empty()
	return result


static func weapon_ids(item_db) -> Array:
	var ids: Array = []
	if item_db == null or not item_db.has_method("list") or not item_db.has_method("get_def"):
		return ids
	for raw_id in item_db.list():
		var id := str(raw_id)
		var def: Dictionary = item_db.get_def(id)
		var tags = def.get("tags", [])
		if tags is Array and (tags as Array).has("weapon"):
			ids.append(id)
	if item_db.has_method("has") and ResourceLoader.exists(WEAPON_DB_PATH):
		var script = load(WEAPON_DB_PATH)
		if script != null and script.has_method("list_ids"):
			for raw_id in script.list_ids():
				var id := str(raw_id)
				if item_db.has(id) and not ids.has(id):
					ids.append(id)
	ids.sort()
	return ids


static func _register_weapons(item_db) -> void:
	if not ResourceLoader.exists(WEAPON_DB_PATH):
		return
	var script = load(WEAPON_DB_PATH)
	if script != null and script.has_method("register_items"):
		script.register_items(item_db)


static func _is_ok(value) -> bool:
	return typeof(value) == TYPE_DICTIONARY and bool((value as Dictionary).get("ok", false))


static func _reason(value, fallback: String) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var text := str((value as Dictionary).get("reason", ""))
		if not text.is_empty():
			return text
	return fallback
