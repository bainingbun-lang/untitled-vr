class_name MapLoader
extends RefCounted

const MapValidatorScript = preload("res://core/maps/map_validator.gd")
const MapMetadataScript = preload("res://core/maps/map_metadata.gd")


func load_dir(dir: String, registry) -> Dictionary:
	var report := {"registered": [], "rejected": []}

	if registry == null:
		_reject(report, dir, "", "Registro de mapas no disponible")
		return report

	var dir_access := DirAccess.open(dir)
	if dir_access == null:
		_reject(report, dir, "", "No se puede abrir el directorio: " + dir)
		return report

	var files: Array = []
	dir_access.list_dir_begin()
	var file_name := dir_access.get_next()
	while not file_name.is_empty():
		if not dir_access.current_is_dir() and file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir_access.get_next()
	dir_access.list_dir_end()
	files.sort()

	var validator = MapValidatorScript.new()
	var defaults: Dictionary = MapMetadataScript.new().metadata

	for json_file in files:
		var path := dir.path_join(json_file)
		var parsed = _read_json(path)
		if not (parsed is Dictionary):
			_reject(report, json_file, "", "JSON invalido o no es un objeto")
			continue

		var meta := _adapt(parsed, defaults)
		var id := str(meta.get("id", ""))
		if id == "":
			_reject(report, json_file, id, "Falta identificador unico (id)")
			continue
		if report["registered"].has(id) or not registry.get_map(id).is_empty():
			_reject(report, json_file, id, "Identificador duplicado: " + id)
			continue

		var validation: Dictionary = validator.validate(meta)
		if validation.status > MapValidatorScript.Status.COMPATIBLE_WITH_WARNINGS:
			var reason := "Mapa no valido"
			for error_message in validation.get("errors", []):
				reason += ": " + str(error_message)
			_reject(report, json_file, id, reason)
			continue

		if not registry.register(meta):
			_reject(report, json_file, id, "No se pudo registrar el mapa")
			continue

		report["registered"].append(id)

	return report


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		return null
	return json.get_data()


func _adapt(parsed: Dictionary, defaults: Dictionary) -> Dictionary:
	var meta := parsed.duplicate(true)
	for key in defaults.keys():
		if not meta.has(key):
			var value = defaults[key]
			if value is Array or value is Dictionary:
				value = value.duplicate(true)
			meta[key] = value
	if meta.has("license") and not (meta["license"] is String):
		meta["license"] = str(meta["license"])
	meta["spawn_points"] = _adapt_points(meta.get("spawn_points", []))
	return meta


func _adapt_points(raw) -> Array:
	var points: Array = []
	if not (raw is Array):
		return points
	for item in raw:
		if item is Vector3:
			points.append(item)
		elif item is Array and item.size() >= 3:
			points.append(Vector3(_as_float(item[0]), _as_float(item[1]), _as_float(item[2])))
		elif item is Dictionary and item.has("x") and item.has("y") and item.has("z"):
			points.append(Vector3(_as_float(item["x"]), _as_float(item["y"]), _as_float(item["z"])))
		else:
			points.append(item)
	return points


func _as_float(value) -> float:
	if value is int or value is float:
		return float(value)
	return float(str(value))


func _reject(report: Dictionary, file: String, id: String, reason: String) -> void:
	report["rejected"].append({
		"file": file,
		"id": id,
		"reason": reason,
		"motivo": reason,
	})
