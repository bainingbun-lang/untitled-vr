class_name VehicleDb
extends RefCounted

const MODEL_DIR := "res://assets/models/vehicles/"
const ContentRegistryScript = preload("res://core/game/content_registry.gd")


static func all() -> Dictionary:
	var result: Dictionary = {}
	for id in ContentRegistryScript.instance().ordered_ids("vehicle"):
		var entry: Dictionary = ContentRegistryScript.instance().definition("vehicle", id)
		entry["scene_builder"] = "glb"
		entry["model_path"] = MODEL_DIR + str(entry.get("model", ""))
		result[id] = entry
	return result


static func list_ids() -> Array:
	return ContentRegistryScript.instance().ids("vehicle")


static func get_def(id: String) -> Dictionary:
	var entries := all()
	return (entries[id] as Dictionary) if entries.has(id) else {}
