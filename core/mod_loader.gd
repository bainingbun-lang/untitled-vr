class_name ModLoader
extends RefCounted

const ModManifestScript = preload("res://core/mod_manifest.gd")
const ModRegistryScript = preload("res://core/mod_registry.gd")
const ModResolverScript = preload("res://core/mod_resolver.gd")
const EventBusScript = preload("res://core/event_bus.gd")

var _bus
var _registry


func _init(bus = null) -> void:
	if bus == null:
		bus = EventBusScript.new()
	_bus = bus
	_registry = ModRegistryScript.new(bus)


func validate(data: Dictionary) -> Dictionary:
	var normalized: Dictionary = data.duplicate(true)
	_normalize_json_ints(normalized)
	return ModManifestScript.parse(normalized)


func discover(dir: String) -> Dictionary:
	var root := DirAccess.open(dir)
	if root == null:
		return {
			"ok": false,
			"candidates": [],
			"rejected": {dir: "no se pudo abrir el directorio '%s'" % dir},
		}

	var candidates: Array = []
	var rejected: Dictionary = {}
	for subdir in root.get_directories():
		var mod_dir := dir.path_join(subdir)
		var manifest_path := mod_dir.path_join("mod.json")
		if not FileAccess.file_exists(manifest_path):
			continue

		var file := FileAccess.open(manifest_path, FileAccess.READ)
		if file == null:
			rejected[subdir] = "no se pudo leer mod.json"
			continue
		var text := file.get_as_text()
		file.close()

		var data: Variant = JSON.parse_string(text)
		if data == null:
			rejected[subdir] = "JSON invalido en mod.json"
			continue
		if typeof(data) != TYPE_DICTIONARY:
			rejected[subdir] = "mod.json debe ser un objeto JSON"
			continue

		var result := validate(data)
		if not result["ok"]:
			rejected[subdir] = "manifiesto invalido: %s" % " | ".join(result["errors"])
			continue

		candidates.append({"manifest": result["manifest"], "dir": mod_dir})

	return {
		"ok": rejected.is_empty(),
		"candidates": candidates,
		"rejected": rejected,
	}


func load_all(dir: String) -> Dictionary:
	var discovered := discover(dir)
	var candidates: Array = discovered["candidates"]
	var rejected: Dictionary = discovered["rejected"]

	var resolution: Dictionary = ModResolverScript.resolve(candidates)
	var errors: Array = resolution["errors"]
	var order: Array = resolution["order"]

	var result: Dictionary = _registry.load_all(candidates)
	var loaded: Array = result["loaded"]

	for id in result["failed"]:
		var module_id := str(id)
		if not rejected.has(module_id):
			rejected[module_id] = _reason_for(
				module_id, errors, str(result["failed"][module_id])
			)

	for candidate in candidates:
		var module_id := str(candidate["manifest"].get("id", ""))
		if loaded.has(module_id) or rejected.has(module_id):
			continue
		rejected[module_id] = _reason_for(module_id, errors, "no resuelto")

	return {
		"ok": rejected.is_empty(),
		"loaded": loaded,
		"rejected": rejected,
		"order": order,
	}


func get_registry():
	return _registry


func is_loaded(module_id: String) -> bool:
	return _registry.is_loaded(module_id)


func loaded_ids() -> Array:
	return _registry.loaded_ids()


func _reason_for(module_id: String, errors: Array, fallback: String) -> String:
	var reasons: Array = []
	for error in errors:
		var text := str(error)
		if text.contains(module_id):
			reasons.append(text)
	if reasons.is_empty():
		return fallback
	return " | ".join(reasons)


func _normalize_json_ints(data: Dictionary) -> void:
	for key in ["schema_version", "priority"]:
		if not data.has(key):
			continue
		var value: Variant = data[key]
		if typeof(value) != TYPE_FLOAT:
			continue
		var number: float = value
		if is_equal_approx(number, round(number)):
			data[key] = int(number)
