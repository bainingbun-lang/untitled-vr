class_name SaveSystem
extends RefCounted

const SAVE_VERSION := 2
const MIN_VERSION := 1
const DEFAULT_ROOT := "user://saves"
const DEFAULT_SLOT := "auto"
const SLOT_SUFFIX := ".sav"
const BACKUP_SUFFIX := ".bak"
const TEMP_SUFFIX := ".tmp"

var root_dir: String

var _migrations: Dictionary = {}
var _log: Array = []
var _config_error: String = ""


func _init(p_root_dir: String = DEFAULT_ROOT) -> void:
	var candidate := p_root_dir.strip_edges()
	if candidate.length() < 8 or not candidate.begins_with("user://"):
		_config_error = "raiz de guardado invalida: solo se permite user://"
		root_dir = DEFAULT_ROOT
		return
	root_dir = candidate


static func validate_slot(slot: String) -> bool:
	if slot.is_empty() or slot.length() > 48:
		return false
	for i in slot.length():
		var character := slot[i]
		if not (
			(character >= "a" and character <= "z")
			or (character >= "A" and character <= "Z")
			or (character >= "0" and character <= "9")
			or character == "_"
			or character == "-"
		):
			return false
	return true


func slot_path(slot: String) -> String:
	return root_dir.path_join(slot + SLOT_SUFFIX)


func backup_path(slot: String) -> String:
	return slot_path(slot) + BACKUP_SUFFIX


func temp_path(slot: String) -> String:
	return slot_path(slot) + TEMP_SUFFIX


func exists(slot: String) -> bool:
	if not _config_error.is_empty() or not validate_slot(slot):
		return false
	return FileAccess.file_exists(slot_path(slot))


func list() -> Array:
	var slots: Array = []
	if not _config_error.is_empty():
		return slots
	var dir := DirAccess.open(root_dir)
	if dir == null:
		return slots
	for file_name in dir.get_files():
		var name := str(file_name)
		if not name.ends_with(SLOT_SUFFIX):
			continue
		var slot := name.substr(0, name.length() - SLOT_SUFFIX.length())
		if validate_slot(slot):
			slots.append(slot)
	slots.sort()
	return slots


func save(slot: String, data: Dictionary, version: int = SAVE_VERSION) -> Dictionary:
	var errors: Array = []
	if not _config_error.is_empty():
		errors.append(_config_error)
	if not validate_slot(slot):
		errors.append("ranura invalida: '%s'" % slot)
	if version < MIN_VERSION or version > SAVE_VERSION:
		errors.append("version no soportada: %d" % version)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "slot": slot}

	var envelope := make_envelope(data, version)
	var committed := _commit(slot_path(slot), envelope, true)
	if not bool(committed["ok"]):
		return {
			"ok": false,
			"errors": committed["errors"],
			"slot": slot,
		}
	_record("guardado %s v%d" % [slot, version])
	return {
		"ok": true,
		"errors": [],
		"slot": slot,
		"version": version,
		"timestamp": int(envelope["timestamp"]),
		"checksum": str(envelope["checksum"]),
	}


func load_slot(slot: String = DEFAULT_SLOT) -> Dictionary:
	var result := _load_result(slot)
	var errors: Array = result["errors"]
	if not _config_error.is_empty():
		errors.append(_config_error)
	if not validate_slot(slot):
		errors.append("ranura invalida: '%s'" % slot)
	if not errors.is_empty():
		return result

	var candidates: Array = []
	var main_check := _read_validated(slot_path(slot))
	if bool(main_check["ok"]):
		candidates.append({"source": "main", "check": main_check})
	else:
		result["main_errors"] = main_check["errors"]
	var backup_check := _read_validated(backup_path(slot))
	if bool(backup_check["ok"]):
		candidates.append({"source": "backup", "check": backup_check})
	else:
		result["backup_errors"] = backup_check["errors"]

	if candidates.is_empty():
		errors.append("partida principal corrupta o ausente: %s" % "; ".join(_messages(main_check["errors"])))
		errors.append("copia de seguridad corrupta o ausente: %s" % "; ".join(_messages(backup_check["errors"])))
		return result

	for candidate in candidates:
		var check: Dictionary = candidate["check"]
		var migrated := _migrate(check["data"], int(check["version"]))
		if not bool(migrated["ok"]):
			errors.append("%s: %s" % [candidate["source"], "; ".join(_messages(migrated["errors"]))])
			continue

		var source := str(candidate["source"])
		var data: Dictionary = migrated["data"]
		result["ok"] = true
		result["data"] = data
		result["version"] = SAVE_VERSION
		result["source"] = source
		result["recovered"] = source == "backup"
		result["migrated"] = not (migrated["applied"] as Array).is_empty()
		result["applied_migrations"] = migrated["applied"]
		result["original_version"] = check["version"]
		result["timestamp"] = check["timestamp"]
		result["checksum"] = check["checksum"]
		errors.clear()

		if result["recovered"] or result["migrated"]:
			var repaired := _commit(slot_path(slot), make_envelope(data), false)
			if bool(repaired["ok"]):
				result["repaired"] = true
			else:
				_record("no se pudo reparar la ranura %s: %s" % [slot, "; ".join(_messages(repaired["errors"]))])
		_record("cargado %s desde %s" % [slot, source])
		return result

	return result


func info(slot: String) -> Dictionary:
	var result := {
		"ok": false,
		"errors": [],
		"slot": slot,
		"version": 0,
		"timestamp": 0,
		"checksum": "",
	}
	if not _config_error.is_empty():
		result["errors"].append(_config_error)
	if not validate_slot(slot):
		result["errors"].append("ranura invalida: '%s'" % slot)
	if not (result["errors"] as Array).is_empty():
		return result
	var check := _read_validated(slot_path(slot))
	result["ok"] = check["ok"]
	result["errors"] = check["errors"]
	result["version"] = check["version"]
	result["timestamp"] = check["timestamp"]
	result["checksum"] = check["checksum"]
	return result


func delete(slot: String, confirm: bool = false) -> Dictionary:
	var errors: Array = []
	if confirm != true:
		errors.append("borrado requiere confirm=true")
	if not _config_error.is_empty():
		errors.append(_config_error)
	if not validate_slot(slot):
		errors.append("ranura invalida: '%s'" % slot)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "slot": slot}
	var removed := false
	for path in [slot_path(slot), backup_path(slot), temp_path(slot)]:
		if not FileAccess.file_exists(path):
			continue
		if not _remove(path):
			errors.append("no se pudo borrar: %s" % path)
		else:
			removed = true
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "slot": slot}
	if not removed:
		return {"ok": false, "errors": ["ranura no existe: %s" % slot], "slot": slot}
	_record("borrada ranura %s" % slot)
	return {"ok": true, "errors": [], "slot": slot}


func register_migration(from_version: int, hook: Callable) -> Dictionary:
	if from_version < MIN_VERSION or from_version >= SAVE_VERSION:
		return {"ok": false, "errors": ["version de origen no migrable: %d" % from_version]}
	if not hook.is_valid():
		return {"ok": false, "errors": ["gancho de migracion invalido para v%d" % from_version]}
	_migrations[from_version] = hook
	_record("migracion registrada v%d -> v%d" % [from_version, from_version + 1])
	return {"ok": true, "errors": []}


func has_migration(from_version: int) -> bool:
	return _migrations.has(from_version)


func clear_migrations() -> void:
	_migrations.clear()


func get_log() -> Array:
	return _log.duplicate()


func clear_log() -> void:
	_log.clear()


static func make_envelope(data: Dictionary, version: int = SAVE_VERSION, timestamp: int = -1) -> Dictionary:
	var stamp := timestamp if timestamp >= 0 else int(Time.get_unix_time_from_system())
	return {
		"version": version,
		"timestamp": stamp,
		"checksum": compute_checksum(data),
		"data": data.duplicate(true),
	}


static func compute_checksum(data: Dictionary) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(normalize(data), "", true).to_utf8_buffer())
	return context.finish().hex_encode()


static func normalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var normalized: Dictionary = {}
			var source_dict: Dictionary = value
			for key in source_dict.keys():
				normalized[str(key)] = normalize(source_dict[key])
			return normalized
		TYPE_ARRAY:
			var normalized_array: Array = []
			var source_array: Array = value
			for item in source_array:
				normalized_array.append(normalize(item))
			return normalized_array
		TYPE_FLOAT:
			var number: float = value
			if not is_nan(number) and not is_inf(number) and floor(number) == number:
				return int(number)
			return number
		_:
			return value


static func validate_envelope(value: Variant) -> Dictionary:
	var result := {
		"ok": false,
		"errors": [],
		"version": 0,
		"timestamp": 0,
		"checksum": "",
		"data": {},
	}
	var errors: Array = result["errors"]
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("partida: se esperaba un Dictionary")
		return result
	var raw: Dictionary = value
	var version_value = _as_int(raw.get("version", null))
	if version_value == null:
		errors.append("version: se esperaba un entero")
	else:
		var version := int(version_value)
		if version < MIN_VERSION:
			errors.append("version no soportada: %d" % version)
		elif version > SAVE_VERSION:
			errors.append("version futura no soportada: %d" % version)
		else:
			result["version"] = version
	var timestamp_value = _as_int(raw.get("timestamp", null))
	if timestamp_value == null or int(timestamp_value) < 0:
		errors.append("timestamp: se esperaba un entero >= 0")
	else:
		result["timestamp"] = int(timestamp_value)
	var checksum_value: Variant = raw.get("checksum", "")
	if typeof(checksum_value) != TYPE_STRING or str(checksum_value).length() != 64:
		errors.append("checksum: se esperaba un SHA-256 hexadecimal")
	else:
		result["checksum"] = str(checksum_value).to_lower()
	var data_value: Variant = raw.get("data", null)
	if typeof(data_value) != TYPE_DICTIONARY:
		errors.append("data: se esperaba un Dictionary")
	else:
		result["data"] = (data_value as Dictionary).duplicate(true)
	if not (result["checksum"] as String).is_empty() and typeof(data_value) == TYPE_DICTIONARY:
		if str(result["checksum"]) != compute_checksum(result["data"]):
			errors.append("checksum no coincide con los datos")
	result["ok"] = errors.is_empty()
	return result


func _read_validated(path: String) -> Dictionary:
	var result := {
		"ok": false,
		"errors": [],
		"version": 0,
		"timestamp": 0,
		"checksum": "",
		"data": {},
	}
	var errors: Array = result["errors"]
	if not FileAccess.file_exists(path):
		errors.append("archivo no existe: %s" % path)
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("no se pudo abrir: %s (error %d)" % [path, FileAccess.get_open_error()])
		return result
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		errors.append("error al leer: %s" % path)
		return result
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("JSON invalido: %s" % path)
		return result
	var validated := validate_envelope(normalize(json.data))
	if not bool(validated["ok"]):
		for error in validated["errors"]:
			errors.append(str(error))
		return result
	result["ok"] = true
	result["version"] = validated["version"]
	result["timestamp"] = validated["timestamp"]
	result["checksum"] = validated["checksum"]
	result["data"] = validated["data"]
	return result


func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	var result := {
		"ok": true,
		"errors": [],
		"data": data.duplicate(true),
		"applied": [],
	}
	var current: Dictionary = result["data"]
	var version := from_version
	while version < SAVE_VERSION:
		if not _migrations.has(version):
			result["ok"] = false
			result["errors"].append("sin gancho de migracion para v%d" % version)
			return result
		var hook: Callable = _migrations[version]
		var migrated: Variant = hook.call(current)
		if typeof(migrated) != TYPE_DICTIONARY:
			result["ok"] = false
			result["errors"].append("migracion v%d -> v%d devolvio un valor invalido" % [version, version + 1])
			return result
		current = migrated
		result["applied"].append(version)
		version += 1
	result["data"] = current
	return result


func _commit(path: String, envelope: Dictionary, rotate: bool) -> Dictionary:
	var errors: Array = []
	var dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if dir_error != OK:
		return {"ok": false, "errors": ["no se pudo crear el directorio de guardado (error %d)" % dir_error]}
	var temp := path + TEMP_SUFFIX
	var backup := path + BACKUP_SUFFIX
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["no se pudo crear el archivo temporal: %s" % temp]}
	file.store_string(JSON.stringify(envelope, "\t"))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_remove(temp)
		return {"ok": false, "errors": ["error al escribir el archivo temporal: %s" % temp]}

	var main_valid := bool(_read_validated(path)["ok"])
	var rotated := false
	if rotate and FileAccess.file_exists(path) and main_valid:
		if FileAccess.file_exists(backup) and not _remove(backup):
			_remove(temp)
			return {"ok": false, "errors": ["no se pudo rotar la copia de seguridad: %s" % backup]}
		if not _rename(path, backup):
			_remove(temp)
			return {"ok": false, "errors": ["no se pudo rotar la partida anterior: %s" % path]}
		rotated = true
	elif FileAccess.file_exists(path):
		if not _remove(path):
			_remove(temp)
			return {"ok": false, "errors": ["no se pudo reemplazar la partida: %s" % path]}

	if not _rename(temp, path):
		errors.append("no se pudo finalizar la escritura atomica: %s" % path)
		if rotated and FileAccess.file_exists(backup):
			_rename(backup, path)
		_remove(temp)
		return {"ok": false, "errors": errors}
	return {"ok": true, "errors": []}


func _load_result(slot: String) -> Dictionary:
	return {
		"ok": false,
		"errors": [],
		"slot": slot,
		"data": {},
		"version": 0,
		"original_version": 0,
		"timestamp": 0,
		"checksum": "",
		"source": "",
		"recovered": false,
		"migrated": false,
		"repaired": false,
		"applied_migrations": [],
		"main_errors": [],
		"backup_errors": [],
	}


func _record(message: String) -> void:
	if not _log.has(message):
		_log.append(message)


func _messages(values: Variant) -> Array:
	var messages: Array = []
	if typeof(values) != TYPE_ARRAY:
		return messages
	for value in values:
		messages.append(str(value))
	return messages


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


static func _remove(path: String) -> bool:
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


static func _rename(from: String, to: String) -> bool:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from),
		ProjectSettings.globalize_path(to)
	) == OK
