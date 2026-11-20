class_name WeaponDb
extends RefCounted

const ContentRegistryScript = preload("res://core/game/content_registry.gd")


static func all() -> Dictionary:
	var registry := ContentRegistryScript.instance()
	var result: Dictionary = {}
	for id in registry.ordered_ids("weapon"):
		result[id] = registry.definition("weapon", id)
	return result


static func get_def(id: String) -> Dictionary:
	return ContentRegistryScript.instance().definition("weapon", id)


static func list_ids() -> Array:
	return ContentRegistryScript.instance().ids("weapon")


static func has(id: String) -> bool:
	return ContentRegistryScript.instance().has("weapon", id)


static func register_items(item_db: ItemDb) -> void:
	if item_db == null or not item_db.has_method("register"):
		return
	for id in list_ids():
		var def: Dictionary = get_def(id)
		var tags: Array = []
		for tag in def.get("tags", []):
			var text := str(tag).strip_edges().to_lower()
			if not text.is_empty() and text != "weapon" and not tags.has(text):
				tags.append(text)
		tags.append("weapon")
		item_db.register({
			"id": id,
			"nombre": str(def.get("name", id)),
			"apilable": false,
			"max_stack": 1,
			"peso": float(def.get("weight", 0.0)),
			"tags": tags,
		})
