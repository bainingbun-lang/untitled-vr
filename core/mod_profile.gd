class_name ModProfile
extends RefCounted

var root_dir: String


func _init(p_root_dir: String = "user://profiles") -> void:
	root_dir = p_root_dir


static func validate_name(name: String) -> bool:
	if name.is_empty() or name.length() > 40:
		return false
	for i in name.length():
		var character := name[i]
		if not (
			(character >= "a" and character <= "z")
			or (character >= "0" and character <= "9")
			or character == "-"
		):
			return false
	return true


static func make(name: String, mods: Array, experimental: bool = false) -> Dictionary:
	var errors: Array = []

	if not validate_name(name):
		errors.append("nombre de perfil invalido: '%s' (se esperaba [a-z0-9-]{1,40})" % name)

	var unique: Dictionary = {}
	for item in mods:
		if typeof(item) != TYPE_STRING:
			errors.append("mods: se esperaba String, se recibio %s" % type_string(typeof(item)))
			continue
		var id: String = item
		if id.is_empty():
			errors.append("mods: id vacio")
			continue
		unique[id] = true

	var ids: Array = unique.keys()
	ids.sort()

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"profile": {
			"name": name,
			"mods": ids,
			"experimental": experimental,
		},
	}


static func diff(loaded: Array, profile: Dictionary) -> Dictionary:
	var loaded_set: Dictionary = {}
	for item in loaded:
		if typeof(item) == TYPE_STRING and not str(item).is_empty():
			loaded_set[str(item)] = true

	var profile_set: Dictionary = {}
	var raw_mods: Variant = profile.get("mods", [])
	if typeof(raw_mods) == TYPE_ARRAY:
		for item in raw_mods:
			if typeof(item) == TYPE_STRING and not str(item).is_empty():
				profile_set[str(item)] = true

	var to_load: Array = []
	for id in profile_set:
		if not loaded_set.has(id):
			to_load.append(id)

	var to_unload: Array = []
	for id in loaded_set:
		if not profile_set.has(id):
			to_unload.append(id)

	to_load.sort()
	to_unload.sort()
	return {"to_load": to_load, "to_unload": to_unload}


func save(profile: Dictionary) -> Dictionary:
	var errors: Array = []
	var raw_name: Variant = profile.get("name", null)
	var raw_mods: Variant = profile.get("mods", null)
	var raw_experimental: Variant = profile.get("experimental", false)

	if typeof(raw_name) != TYPE_STRING:
		errors.append("profile.name: se esperaba String")
	if typeof(raw_mods) != TYPE_ARRAY:
		errors.append("profile.mods: se esperaba Array")
	if typeof(raw_experimental) != TYPE_BOOL:
		errors.append("profile.experimental: se esperaba bool")
	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	var normalized := make(str(raw_name), raw_mods, raw_experimental)
	if not normalized["ok"]:
		return {"ok": false, "errors": normalized["errors"]}

	var profile_data: Dictionary = normalized["profile"]
	var path := _profile_path(str(profile_data["name"]))
	if not _write_json(path, profile_data):
		return {"ok": false, "errors": ["no se pudo escribir el perfil: %s" % path]}

	return {"ok": true, "errors": [], "profile": profile_data}


func load_profile(name: String) -> Dictionary:
	if not validate_name(name):
		return {
			"ok": false,
			"errors": ["nombre de perfil invalido: '%s'" % name],
			"profile": {},
		}

	var data: Variant = _read_json(_profile_path(name))
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"ok": false,
			"errors": ["perfil no existe o JSON invalido: %s" % name],
			"profile": {},
		}

	var stored: Dictionary = data
	var raw_name: Variant = stored.get("name", name)
	var raw_mods: Variant = stored.get("mods", null)
	var raw_experimental: Variant = stored.get("experimental", false)

	var errors: Array = []
	if typeof(raw_name) != TYPE_STRING:
		errors.append("perfil invalido: 'name' debe ser String")
	if typeof(raw_mods) != TYPE_ARRAY:
		errors.append("perfil invalido: 'mods' debe ser Array")
	if typeof(raw_experimental) != TYPE_BOOL:
		errors.append("perfil invalido: 'experimental' debe ser bool")
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "profile": {}}

	var normalized := make(str(raw_name), raw_mods, raw_experimental)
	if not normalized["ok"]:
		return {"ok": false, "errors": normalized["errors"], "profile": {}}

	return {"ok": true, "errors": [], "profile": normalized["profile"]}


func list() -> Array:
	var names: Array = []
	var global_root := ProjectSettings.globalize_path(root_dir)
	if not DirAccess.dir_exists_absolute(global_root):
		return names

	var access := DirAccess.open(root_dir)
	if access == null:
		return names

	access.list_dir_begin()
	var file_name := access.get_next()
	while not file_name.is_empty():
		if file_name == "." or file_name == "..":
			file_name = access.get_next()
			continue
		if not access.current_is_dir() and file_name.ends_with(".json"):
			var base := file_name.substr(0, file_name.length() - 5)
			if base != "last_good" and validate_name(base):
				names.append(base)
		file_name = access.get_next()
	access.list_dir_end()

	names.sort()
	return names


func delete(name: String, confirm: bool) -> Dictionary:
	if confirm != true:
		return {"ok": false, "errors": ["borrado requiere confirm=true"]}
	if not validate_name(name):
		return {"ok": false, "errors": ["nombre de perfil invalido: '%s'" % name]}

	var path := _profile_path(name)
	if not FileAccess.file_exists(path):
		return {"ok": false, "errors": ["perfil no existe: %s" % name]}

	if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
		return {"ok": false, "errors": ["no se pudo borrar el perfil: %s" % name]}

	return {"ok": true, "errors": []}


func mark_last_good(name: String) -> Dictionary:
	if not validate_name(name):
		return {"ok": false, "errors": ["nombre de perfil invalido: '%s'" % name]}

	var path := root_dir.path_join("last_good.json")
	if not _write_json(path, {"name": name}):
		return {"ok": false, "errors": ["no se pudo guardar last_good.json"]}

	return {"ok": true, "errors": []}


func last_good() -> String:
	var data: Variant = _read_json(root_dir.path_join("last_good.json"))
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	var name: Variant = data.get("name", "")
	if typeof(name) != TYPE_STRING or not validate_name(name):
		return ""
	return str(name)


func _profile_path(name: String) -> String:
	return root_dir.path_join(name + ".json")


func _write_json(path: String, data: Variant) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	var ok := file.get_error() == OK
	file.close()
	return ok


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data
