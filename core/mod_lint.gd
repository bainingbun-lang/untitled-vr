class_name ModLint
extends RefCounted

const ModManifestScript = preload("res://core/mod_manifest.gd")
const ContentRegistryScript = preload("res://core/game/content_registry.gd")
const ModHooksScript = preload("res://core/game/mod_hooks.gd")

const MANIFEST_FILE := "mod.json"
const CONTENT_DIR := "content"
const MAX_FILE_BYTES := 5 * 1024 * 1024
const FORBIDDEN_CHARS := [":", "*", "?", "\"", "<", ">", "|"]


static func check(dir: String, max_file_bytes: int = MAX_FILE_BYTES) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []

	if not (dir.begins_with("res://") or dir.begins_with("user://")):
		errors.append("ruta no portable '%s' (se esperaba res:// o user://)" % dir)
		return _result(errors, warnings)

	var root := DirAccess.open(dir)
	if root == null:
		errors.append("no se pudo abrir el directorio '%s'" % dir)
		return _result(errors, warnings)

	var files: Array = []
	var folders: Array = []
	_collect(dir, "", files, folders, errors, warnings)
	_check_case_collisions(files, folders, errors)

	var manifest: Dictionary = {}
	if not files.has(MANIFEST_FILE):
		errors.append("falta mod.json en '%s'" % dir)
	else:
		manifest = _read_manifest(dir, errors)

	if not manifest.is_empty():
		_check_entry(manifest, dir, errors)
		_walk_traversal(manifest, "mod.json", errors)
		_check_content(dir, manifest, errors, warnings)
		_check_hooks(manifest, errors, warnings)
	_check_sizes(dir, files, max_file_bytes, errors)

	return _result(errors, warnings)


static func _result(errors: Array, warnings: Array) -> Dictionary:
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
	}


static func _collect(
	base: String,
	relative: String,
	files: Array,
	folders: Array,
	errors: Array,
	warnings: Array
) -> void:
	var current := base if relative.is_empty() else base.path_join(relative)
	var dir := DirAccess.open(current)
	if dir == null:
		errors.append("no se pudo abrir el directorio '%s'" % current)
		return

	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var child := name if relative.is_empty() else relative.path_join(name)
			_check_name(child, errors, warnings)
			if _has_traversal(child):
				errors.append("ruta con traversal '%s'" % child)
			if dir.current_is_dir():
				folders.append(child)
				_collect(base, child, files, folders, errors, warnings)
			else:
				files.append(child)
		name = dir.get_next()
	dir.list_dir_end()


static func _check_name(name: String, errors: Array, warnings: Array) -> void:
	if name.contains("\\"):
		errors.append("nombre no portable '%s': contiene backslash" % name)
	for character in FORBIDDEN_CHARS:
		if name.contains(character):
			errors.append(
				"nombre no portable '%s': contiene el caracter prohibido '%s'"
				% [name, character]
			)
	if _has_uppercase(name):
		warnings.append("nombre con mayusculas '%s': puede no ser portable" % name)


static func _check_case_collisions(files: Array, folders: Array, errors: Array) -> void:
	var seen: Dictionary = {}
	var names: Array = []
	names.append_array(files)
	names.append_array(folders)
	for name in names:
		var key := str(name).to_lower()
		var text := str(name)
		if seen.has(key) and seen[key] != text:
			errors.append(
				"nombres que colisionan sin distincion de mayusculas: '%s' y '%s'"
				% [seen[key], text]
			)
		else:
			seen[key] = text


static func _has_uppercase(text: String) -> bool:
	for i in text.length():
		var character: String = text[i]
		if character >= "A" and character <= "Z":
			return true
	return false


static func _has_traversal(path: String) -> bool:
	for segment in path.replace("\\", "/").split("/"):
		if segment == "..":
			return true
	return false


static func _read_manifest(dir: String, errors: Array) -> Dictionary:
	var path := dir.path_join(MANIFEST_FILE)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("no se pudo leer mod.json")
		return {}
	var text := file.get_as_text()
	file.close()

	var parser := JSON.new()
	if parser.parse(text) != OK:
		errors.append("JSON invalido en mod.json")
		return {}
	var data: Variant = parser.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("mod.json debe ser un objeto JSON")
		return {}

	var normalized: Dictionary = data
	_normalize_json_ints(normalized)
	var parsed: Dictionary = ModManifestScript.parse(normalized)
	for error in parsed["errors"]:
		errors.append("manifiesto: %s" % error)
	return normalized


static func _normalize_json_ints(data: Dictionary) -> void:
	for key in ["schema_version", "priority"]:
		if not data.has(key):
			continue
		var value: Variant = data[key]
		if typeof(value) != TYPE_FLOAT:
			continue
		var number: float = value
		if is_equal_approx(number, round(number)):
			data[key] = int(number)


static func _check_entry(manifest: Dictionary, dir: String, errors: Array) -> void:
	if not manifest.has("entry"):
		return
	var value: Variant = manifest["entry"]
	if typeof(value) != TYPE_STRING:
		return
	var entry: String = value
	if entry.is_empty() or not entry.begins_with("res://"):
		return
	# el entry res:// vive dentro del PCK: en la carpeta fuente esta bajo dir/
	if not FileAccess.file_exists(entry) and not FileAccess.file_exists(dir.path_join(entry.trim_prefix("res://"))):
		errors.append("entry: el archivo '%s' no existe" % entry)


static func _walk_traversal(value: Variant, path: String, errors: Array) -> void:
	match typeof(value):
		TYPE_STRING:
			var text: String = value
			if _has_traversal(text):
				errors.append("ruta con traversal en '%s': '%s'" % [path, text])
		TYPE_DICTIONARY:
			for key in value:
				_walk_traversal(value[key], "%s.%s" % [path, str(key)], errors)
		TYPE_ARRAY:
			for i in value.size():
				_walk_traversal(value[i], "%s[%d]" % [path, i], errors)


static func _check_sizes(dir: String, files: Array, max_file_bytes: int, errors: Array) -> void:
	for relative in files:
		var file := FileAccess.open(dir.path_join(relative), FileAccess.READ)
		if file == null:
			continue
		var size: int = file.get_length()
		file.close()
		if size > max_file_bytes:
			errors.append(
				"archivo demasiado grande '%s': %d bytes (maximo %d)"
				% [relative, size, max_file_bytes]
			)


static func _check_content(dir: String, manifest: Dictionary, errors: Array, warnings: Array) -> void:
	var mod_id: String = str(manifest.get("id", ""))
	if mod_id.is_empty():
		return

	var content_dir_path := dir.path_join(CONTENT_DIR)
	var content_dir := DirAccess.open(content_dir_path)
	if content_dir == null:
		return

	var registry := ContentRegistryScript.new()

	content_dir.list_dir_begin()
	var file_name := content_dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != ".." and not content_dir.current_is_dir():
			var name := str(file_name)
			if name.ends_with(".json") and name != "mod.json":
				var path := content_dir_path.path_join(name)
				var text := FileAccess.get_file_as_string(path)
				var parsed: Variant = JSON.parse_string(text)
				if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
					errors.append("%s: JSON invalido" % path)
				else:
					var root: Dictionary = parsed
					var raw_defs: Variant = root.get("content", root.get("defs", null))
					if raw_defs == null and root.has("type"):
						raw_defs = [root]
					if raw_defs != null:
						if typeof(raw_defs) != TYPE_ARRAY:
							errors.append("%s: se esperaba un array 'content'" % path)
						else:
							for raw_def in raw_defs:
								if typeof(raw_def) != TYPE_DICTIONARY:
									errors.append("%s: cada entrada debe ser un objeto" % path)
									continue
								var entry: Dictionary = raw_def
								var type_name := str(entry.get("type", ""))
								if type_name.is_empty():
									errors.append("%s: falta campo 'type'" % path)
									continue
								if not ContentRegistryScript.TYPES.has(type_name):
									errors.append("%s: tipo desconocido '%s'" % [path, type_name])
									continue
								var result := registry.validate(type_name, entry, mod_id)
								if not bool(result.get("ok", false)):
									for error in result.get("errors", []):
										errors.append("contenido %s: %s" % [type_name, str(error)])
		file_name = content_dir.get_next()
	content_dir.list_dir_end()


static func _check_hooks(manifest: Dictionary, errors: Array, warnings: Array) -> void:
	if not manifest.has("hooks"):
		return
	var hooks: Variant = manifest["hooks"]
	if typeof(hooks) != TYPE_DICTIONARY:
		errors.append("hooks: se esperaba un Dictionary")
		return
	for raw_event in hooks:
		var event := str(raw_event)
		if not ModHooksScript.is_event(event):
			errors.append("hooks: evento desconocido '%s'" % event)
			continue
		var entries: Array = hooks[raw_event] if hooks[raw_event] is Array else [hooks[raw_event]]
		for raw_entry in entries:
			var method := ""
			var priority := 100
			if raw_entry is String:
				method = raw_entry
			elif raw_entry is Dictionary:
				method = str(raw_entry.get("method", ""))
				priority = int(raw_entry.get("priority", 100))
			else:
				errors.append("hooks.%s: entrada invalida, se esperaba String o Dictionary" % event)
				continue
			if method.is_empty():
				errors.append("hooks.%s: falta campo 'method'" % event)
			if priority < 0 or priority > 1000:
				warnings.append("hooks.%s: prioridad %d fuera de rango recomendado (0-1000)" % [event, priority])
