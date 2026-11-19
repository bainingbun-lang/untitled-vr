class_name ModBackup
extends RefCounted

var root_dir: String


func _init(p_root_dir: String = "user://backups") -> void:
	root_dir = p_root_dir


func snapshot(source_dir: String, label: String) -> Dictionary:
	var errors: Array = []
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(source_dir)):
		return {
			"ok": false,
			"errors": ["source_dir no existe: %s" % source_dir],
			"id": "",
			"files": 0,
		}

	var id := _make_id(label)
	var dest := root_dir.path_join(id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest))
	_copy_tree(source_dir, dest, errors)

	var manifest := make_manifest(source_dir)
	var manifest_file := FileAccess.open(dest.path_join("manifest.json"), FileAccess.WRITE)
	if manifest_file == null:
		errors.append("no se pudo escribir manifest.json")
	else:
		manifest_file.store_string(JSON.stringify({"version": 1, "files": manifest}, "\t"))
		if manifest_file.get_error() != OK:
			errors.append("error al escribir manifest.json")
		manifest_file.close()

	if not errors.is_empty():
		_remove_dir(dest)
		return {"ok": false, "errors": errors, "id": "", "files": 0}

	return {"ok": true, "errors": [], "id": id, "files": manifest.size() + 1}


func verify(id: String) -> Dictionary:
	var result := {
		"ok": false,
		"mismatched": [],
		"missing": [],
		"extra": [],
		"errors": [],
	}
	if not _valid_id(id):
		result["errors"] = ["id invalido: %s" % id]
		return result

	var snapshot_dir := root_dir.path_join(id)
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(snapshot_dir)):
		result["errors"] = ["snapshot no existe: %s" % id]
		return result

	var data: Variant = _read_json(snapshot_dir.path_join("manifest.json"))
	if typeof(data) != TYPE_DICTIONARY:
		result["errors"] = ["manifest.json invalido o ausente en: %s" % id]
		return result

	var files: Variant = data.get("files", null)
	if typeof(files) != TYPE_DICTIONARY:
		result["errors"] = ["manifest.json sin 'files' valido en: %s" % id]
		return result

	var checked := check_manifest(snapshot_dir, files)
	result["ok"] = checked["ok"]
	result["mismatched"] = checked["mismatched"]
	result["missing"] = checked["missing"]
	result["extra"] = checked["extra"]
	return result


func restore(id: String, target_dir: String) -> Dictionary:
	var errors: Array = []
	var pre_restore_id := ""

	var verification := verify(id)
	if not verification["ok"]:
		errors.append("snapshot no verificado, no se restaura: %s" % id)
		for item in verification["errors"]:
			errors.append(str(item))
		return {"ok": false, "errors": errors, "pre_restore_id": pre_restore_id}

	var snapshot_dir := root_dir.path_join(id)
	var files := _read_manifest(id)
	if files.is_empty():
		errors.append("manifest.json invalido o ausente en: %s" % id)
		return {"ok": false, "errors": errors, "pre_restore_id": pre_restore_id}

	var target_exists := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target_dir))
	if target_exists:
		var pre := snapshot(target_dir, "pre-restore")
		if not pre["ok"]:
			errors.append("no se pudo crear el snapshot pre-restore")
			for item in pre["errors"]:
				errors.append(str(item))
			return {"ok": false, "errors": errors, "pre_restore_id": ""}
		pre_restore_id = str(pre["id"])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))

	var relative_paths: Array = files.keys()
	relative_paths.sort()
	for relative in relative_paths:
		var source_path := snapshot_dir.path_join(str(relative))
		var destination_path := target_dir.path_join(str(relative))
		_copy_file(source_path, destination_path, errors)

	if not errors.is_empty():
		return {"ok": false, "errors": errors, "pre_restore_id": pre_restore_id}

	return {"ok": true, "errors": [], "pre_restore_id": pre_restore_id}


func list() -> Array:
	var ids: Array = []
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_dir)):
		return ids

	var dir := DirAccess.open(root_dir)
	if dir == null:
		return ids

	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		if dir.current_is_dir():
			var manifest_path := root_dir.path_join(name).path_join("manifest.json")
			if FileAccess.file_exists(manifest_path):
				ids.append(name)
		name = dir.get_next()
	dir.list_dir_end()

	ids.sort()
	return ids


func delete(id: String, confirm: bool) -> Dictionary:
	if confirm != true:
		return {"ok": false, "errors": ["borrado requiere confirm=true"]}
	if not _valid_id(id):
		return {"ok": false, "errors": ["id invalido: %s" % id]}

	var snapshot_dir := root_dir.path_join(id)
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(snapshot_dir)):
		return {"ok": false, "errors": ["snapshot no existe: %s" % id]}

	_remove_dir(snapshot_dir)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(snapshot_dir)):
		return {"ok": false, "errors": ["no se pudo borrar el snapshot: %s" % id]}
	return {"ok": true, "errors": []}


static func make_manifest(dir: String) -> Dictionary:
	var manifest: Dictionary = {}
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		return manifest

	var files: Array = []
	_collect_files(dir, "", files)
	files.sort()
	for relative in files:
		if str(relative).get_file() == "manifest.json":
			continue
		manifest[str(relative)] = FileAccess.get_sha256(dir.path_join(str(relative)))
	return manifest


static func check_manifest(dir: String, manifest: Dictionary) -> Dictionary:
	var current := make_manifest(dir)
	var mismatched: Array = []
	var missing: Array = []
	var extra: Array = []

	for relative in manifest:
		if not current.has(relative):
			missing.append(relative)
		elif str(current[relative]) != str(manifest[relative]):
			mismatched.append(relative)

	for relative in current:
		if not manifest.has(relative):
			extra.append(relative)

	mismatched.sort()
	missing.sort()
	extra.sort()

	return {
		"ok": mismatched.is_empty() and missing.is_empty() and extra.is_empty(),
		"mismatched": mismatched,
		"missing": missing,
		"extra": extra,
	}


func _make_id(label: String) -> String:
	var base := _sanitize_label(label) + "-" + str(int(Time.get_unix_time_from_system()))
	var candidate := base
	var suffix := 2
	while DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_dir.path_join(candidate))):
		candidate = base + "-" + str(suffix)
		suffix += 1
	return candidate


static func _sanitize_label(label: String) -> String:
	var out := ""
	var lower := label.to_lower()
	for i in lower.length():
		var character := lower[i]
		if (
			(character >= "a" and character <= "z")
			or (character >= "0" and character <= "9")
			or character == "-"
		):
			out += character
		else:
			out += "-"
	if out.is_empty():
		out = "snapshot"
	return out


static func _valid_id(id: String) -> bool:
	return (
		not id.is_empty()
		and id != "."
		and id != ".."
		and not id.contains("/")
		and not id.contains("\\")
	)


func _read_manifest(id: String) -> Dictionary:
	var data: Variant = _read_json(root_dir.path_join(id).path_join("manifest.json"))
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var files: Variant = data.get("files", null)
	if typeof(files) != TYPE_DICTIONARY:
		return {}
	return files


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


static func _collect_files(dir: String, prefix: String, out: Array) -> void:
	var access := DirAccess.open(dir)
	if access == null:
		return

	access.list_dir_begin()
	var name := access.get_next()
	while not name.is_empty():
		if name == "." or name == "..":
			name = access.get_next()
			continue
		var full := dir.path_join(name)
		var relative := name if prefix.is_empty() else prefix.path_join(name)
		if access.current_is_dir():
			_collect_files(full, relative, out)
		else:
			out.append(relative)
		name = access.get_next()
	access.list_dir_end()


func _copy_tree(source: String, destination: String, errors: Array) -> void:
	var access := DirAccess.open(source)
	if access == null:
		errors.append("no se pudo abrir: %s" % source)
		return

	access.list_dir_begin()
	var name := access.get_next()
	while not name.is_empty():
		if name == "." or name == "..":
			name = access.get_next()
			continue
		var source_path := source.path_join(name)
		var destination_path := destination.path_join(name)
		if access.current_is_dir():
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination_path))
			_copy_tree(source_path, destination_path, errors)
		else:
			_copy_file(source_path, destination_path, errors)
		name = access.get_next()
	access.list_dir_end()


func _copy_file(source: String, destination: String, errors: Array) -> void:
	var source_file := FileAccess.open(source, FileAccess.READ)
	if source_file == null:
		errors.append("no se pudo leer: %s" % source)
		return
	var data := source_file.get_buffer(source_file.get_length())
	source_file.close()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination.get_base_dir()))
	var destination_file := FileAccess.open(destination, FileAccess.WRITE)
	if destination_file == null:
		errors.append("no se pudo escribir: %s" % destination)
		return
	destination_file.store_buffer(data)
	if destination_file.get_error() != OK:
		errors.append("error al escribir: %s" % destination)
	destination_file.close()


func _remove_dir(path: String) -> void:
	var access := DirAccess.open(path)
	if access == null:
		return

	access.list_dir_begin()
	var name := access.get_next()
	while not name.is_empty():
		if name == "." or name == "..":
			name = access.get_next()
			continue
		var full := path.path_join(name)
		if access.current_is_dir():
			_remove_dir(full)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(full))
		name = access.get_next()
	access.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
