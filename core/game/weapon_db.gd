class_name WeaponDb
extends RefCounted

# Adapted from Godot-FPS-Template (https://github.com/AxelReviron/Godot-FPS-Template)
# Original: Weapons.gd (weapon definitions resource)
# Adapted from GodotWeapons (https://github.com/JarLowrey/GodotWeapons)
# Original: Weapons.gd (weapon resource definitions)
# Adapted from GodotFPS-Template (https://github.com/bukkbeek/GodotFPS-Template)
# Original: common/weapon/weapons.gd (weapon data resource)
# License: MIT (c) 2026 Axel Reviron, 2017 James Lowrey, 2026 bukkbeek - see third_party/GODOT_FPS_TEMPLATE_LICENSE.txt, third_party/GODOTWEAPONS_LICENSE.txt, third_party/GODOTFPS_TEMPLATE_LICENSE.txt

const ContentRegistryScript = preload("res://core/game/content_registry.gd")
const ItemDbScript = preload("res://core/game/item_db.gd")


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
