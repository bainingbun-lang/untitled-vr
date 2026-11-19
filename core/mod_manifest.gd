class_name ModManifest
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULT_PRIORITY := 100
const ID_PATTERN := "^[a-z0-9-]+\\.[a-z0-9-]+$"
const SEMVER_PATTERN := "^[0-9]+\\.[0-9]+\\.[0-9]+$"
const SYSTEM_PATTERN := "^[a-z0-9_-]+$"
const VALID_PLATFORMS := ["android", "pc", "vr"]


static func parse(data: Dictionary) -> Dictionary:
	var errors: Array = []
	var manifest: Dictionary = data.duplicate(true)

	_validate_schema_version(manifest, errors)
	_validate_id(manifest, errors)
	_validate_version(manifest, errors)
	_validate_engine(manifest, errors)
	_validate_depends(manifest, errors)
	_validate_replaces(manifest, errors)
	_validate_priority(manifest, errors)
	_validate_platforms(manifest, errors)
	_validate_permissions(manifest, errors)
	_validate_pack(manifest, errors)
	_validate_entry(manifest, errors)

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"manifest": manifest,
	}


static func find_conflicts(manifests: Array, base_owner: String = "untitled.base") -> Array:
	var conflicts: Array = []
	var indexed := _index_replacements(manifests, base_owner)

	for key in indexed:
		var by_priority: Dictionary = indexed[key]
		var best := _highest_priority(by_priority)
		var module_ids: Array = by_priority[best]
		if module_ids.size() < 2:
			continue
		var split := _split_key(key)
		var owner: String = split[0]
		var system: String = split[1]
		var sorted_ids: Array = module_ids.duplicate()
		sorted_ids.sort()
		conflicts.append({
			"owner": owner,
			"system": system,
			"priority": best,
			"modules": sorted_ids,
			"message": (
				"Conflicto en el sistema '%s' de '%s': los módulos %s lo sustituyen con la misma prioridad %d"
				% [system, owner, ", ".join(sorted_ids), best]
			),
		})

	return conflicts


static func resolve_replacements(
	manifests: Array, base_owner: String = "untitled.base"
) -> Dictionary:
	var resolved: Dictionary = {}
	var indexed := _index_replacements(manifests, base_owner)

	for key in indexed:
		var by_priority: Dictionary = indexed[key]
		var best := _highest_priority(by_priority)
		var module_ids: Array = by_priority[best]
		if module_ids.size() == 1:
			resolved[key] = module_ids[0]

	return resolved


static func _index_replacements(manifests: Array, base_owner: String) -> Dictionary:
	var indexed: Dictionary = {}

	for entry in manifests:
		var manifest := _manifest_of(entry)
		if manifest.is_empty():
			continue
		var result := parse(manifest)
		if not result["ok"]:
			continue
		var normalized: Dictionary = result["manifest"]
		var module_id := str(normalized.get("id", ""))
		var priority := int(normalized.get("priority", DEFAULT_PRIORITY))
		for raw in normalized.get("replaces", []):
			var key := _replace_key(str(raw), base_owner)
			if key.is_empty():
				continue
			if not indexed.has(key):
				indexed[key] = {}
			var by_priority: Dictionary = indexed[key]
			if not by_priority.has(priority):
				by_priority[priority] = []
			var module_ids: Array = by_priority[priority]
			if not module_ids.has(module_id):
				module_ids.append(module_id)

	return indexed


static func _manifest_of(entry: Variant) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = entry
	if data.has("manifest") and typeof(data["manifest"]) == TYPE_DICTIONARY:
		return data["manifest"]
	return data


static func _replace_key(raw: String, base_owner: String) -> String:
	var parts := raw.split(":")
	if parts.size() == 1:
		if not _matches(parts[0], SYSTEM_PATTERN):
			return ""
		return "%s:%s" % [base_owner, parts[0]]
	if parts.size() == 2:
		if not _matches(parts[0], ID_PATTERN) or not _matches(parts[1], SYSTEM_PATTERN):
			return ""
		return "%s:%s" % [parts[0], parts[1]]
	return ""


static func _split_key(key: String) -> Array:
	var parts := key.split(":")
	if parts.size() != 2:
		return ["", ""]
	return [parts[0], parts[1]]


static func _highest_priority(by_priority: Dictionary) -> int:
	var best := 0
	var first := true
	for priority in by_priority:
		if first or int(priority) > best:
			best = int(priority)
			first = false
	return best


static func _matches(value: String, pattern: String) -> bool:
	var regex := RegEx.create_from_string(pattern)
	return regex.search(value) != null


static func _validate_schema_version(manifest: Dictionary, errors: Array) -> void:
	if not manifest.has("schema_version"):
		errors.append("schema_version: campo obligatorio ausente")
		return
	var value: Variant = manifest["schema_version"]
	if typeof(value) != TYPE_INT:
		errors.append("schema_version: se esperaba int, se recibio %s" % type_string(typeof(value)))
	elif value != SCHEMA_VERSION:
		errors.append("schema_version: debe ser 1, se recibio %d" % value)


static func _validate_id(manifest: Dictionary, errors: Array) -> void:
	if not manifest.has("id"):
		errors.append("id: campo obligatorio ausente")
		return
	var value: Variant = manifest["id"]
	if typeof(value) != TYPE_STRING:
		errors.append("id: se esperaba String, se recibio %s" % type_string(typeof(value)))
	elif not _matches(value, ID_PATTERN):
		errors.append("id: formato invalido '%s' (se esperaba autor.nombre)" % value)


static func _validate_version(manifest: Dictionary, errors: Array) -> void:
	if not manifest.has("version"):
		errors.append("version: campo obligatorio ausente")
		return
	var value: Variant = manifest["version"]
	if typeof(value) != TYPE_STRING:
		errors.append("version: se esperaba String, se recibio %s" % type_string(typeof(value)))
	elif not _matches(value, SEMVER_PATTERN):
		errors.append("version: formato invalido '%s' (se esperaba MAJOR.MINOR.PATCH)" % value)


static func _validate_engine(manifest: Dictionary, errors: Array) -> void:
	if not manifest.has("engine"):
		errors.append("engine: campo obligatorio ausente")
		return
	var value: Variant = manifest["engine"]
	if typeof(value) != TYPE_STRING:
		errors.append("engine: se esperaba String, se recibio %s" % type_string(typeof(value)))


static func _validate_depends(manifest: Dictionary, errors: Array) -> void:
	if not manifest.has("depends"):
		manifest["depends"] = {}
		return
	var value: Variant = manifest["depends"]
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("depends: se esperaba Dictionary, se recibio %s" % type_string(typeof(value)))
		return
	for key in value:
		if typeof(key) != TYPE_STRING:
			errors.append("depends: clave invalida '%s' (se esperaba un id String)" % str(key))
		elif typeof(value[key]) != TYPE_STRING:
			errors.append(
				"depends.%s: se esperaba String, se recibio %s"
				% [key, type_string(typeof(value[key]))]
			)


static func _validate_replaces(manifest: Dictionary, errors: Array) -> void:
	if not manifest.has("replaces"):
		manifest["replaces"] = []
		return
	var value: Variant = manifest["replaces"]
	if typeof(value) != TYPE_ARRAY:
		errors.append("replaces: se esperaba Array, se recibio %s" % type_string(typeof(value)))
		return
	for item in value:
		if typeof(item) != TYPE_STRING:
			errors.append("replaces: se esperaba String, se recibio %s" % type_string(typeof(item)))
		elif not _is_valid_replace(item):
			errors.append(
				"replaces: formato invalido '%s' (se esperaba 'sistema' o 'modulo:sistema')" % item
			)


static func _is_valid_replace(value: String) -> bool:
	var parts := value.split(":")
	if parts.size() == 1:
		return _matches(parts[0], SYSTEM_PATTERN)
	if parts.size() == 2:
		return _matches(parts[0], ID_PATTERN) and _matches(parts[1], SYSTEM_PATTERN)
	return false


static func _validate_priority(manifest: Dictionary, errors: Array) -> void:
	if not manifest.has("priority"):
		manifest["priority"] = DEFAULT_PRIORITY
		return
	var value: Variant = manifest["priority"]
	if typeof(value) != TYPE_INT:
		errors.append("priority: se esperaba int, se recibio %s" % type_string(typeof(value)))


static func _validate_platforms(manifest: Dictionary, errors: Array) -> void:
	if not manifest.has("platforms"):
		manifest["platforms"] = []
		return
	var value: Variant = manifest["platforms"]
	if typeof(value) != TYPE_ARRAY:
		errors.append("platforms: se esperaba Array, se recibio %s" % type_string(typeof(value)))
		return
	for item in value:
		if typeof(item) != TYPE_STRING:
			errors.append("platforms: se esperaba String, se recibio %s" % type_string(typeof(item)))
		elif not VALID_PLATFORMS.has(item):
			errors.append(
				"platforms: valor invalido '%s' (permitidos: android, pc, vr)" % item
			)


static func _validate_permissions(manifest: Dictionary, errors: Array) -> void:
	if not manifest.has("permissions"):
		manifest["permissions"] = []
		return
	var value: Variant = manifest["permissions"]
	if typeof(value) != TYPE_ARRAY:
		errors.append("permissions: se esperaba Array, se recibio %s" % type_string(typeof(value)))
		return
	for item in value:
		if typeof(item) != TYPE_STRING:
			errors.append(
				"permissions: se esperaba String, se recibio %s" % type_string(typeof(item))
			)


static func _validate_pack(manifest: Dictionary, errors: Array) -> void:
	if not manifest.has("pack"):
		return
	var value: Variant = manifest["pack"]
	if typeof(value) != TYPE_STRING:
		errors.append("pack: se esperaba String, se recibio %s" % type_string(typeof(value)))
		return
	var pack_name: String = value
	if pack_name.contains("/") or pack_name.contains("\\"):
		errors.append(
			"pack: formato invalido '%s' (se esperaba un nombre de archivo sin ruta)" % pack_name
		)
		return
	if not pack_name.ends_with(".pck"):
		errors.append("pack: formato invalido '%s' (se esperaba un archivo .pck)" % pack_name)


static func _validate_entry(manifest: Dictionary, errors: Array) -> void:
	if not manifest.has("entry"):
		return
	var value: Variant = manifest["entry"]
	if typeof(value) != TYPE_STRING:
		errors.append("entry: se esperaba String, se recibio %s" % type_string(typeof(value)))
		return
	var entry: String = value
	if not entry.begins_with("res://"):
		errors.append(
			"entry: formato invalido '%s' (se esperaba una ruta res://)" % entry
		)
		return
	if not entry.ends_with(".gd"):
		errors.append(
			"entry: formato invalido '%s' (se esperaba un script .gd)" % entry
		)
