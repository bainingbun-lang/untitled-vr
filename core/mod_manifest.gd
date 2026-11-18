class_name ModManifest
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULT_PRIORITY := 100
const ID_PATTERN := "^[a-z0-9-]+\\.[a-z0-9-]+$"
const SEMVER_PATTERN := "^[0-9]+\\.[0-9]+\\.[0-9]+$"
const REPLACE_PART_PATTERN := "^[a-z0-9_.-]+$"
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

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"manifest": manifest,
	}


static func find_conflicts(manifests: Array) -> Array:
	var conflicts: Array = []
	var systems: Dictionary = {}

	for entry in manifests:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var manifest: Dictionary = entry
		if entry.has("manifest") and typeof(entry["manifest"]) == TYPE_DICTIONARY:
			manifest = entry["manifest"]

		var module_id := str(manifest.get("id", ""))
		var priority := DEFAULT_PRIORITY
		if typeof(manifest.get("priority", DEFAULT_PRIORITY)) == TYPE_INT:
			priority = manifest.get("priority", DEFAULT_PRIORITY)

		var replaces: Variant = manifest.get("replaces", [])
		if typeof(replaces) != TYPE_ARRAY:
			continue

		for raw in replaces:
			if typeof(raw) != TYPE_STRING:
				continue
			var system := _system_of(raw)
			if system.is_empty():
				continue
			if not systems.has(system):
				systems[system] = {}
			var by_priority: Dictionary = systems[system]
			if not by_priority.has(priority):
				by_priority[priority] = []
			var module_ids: Array = by_priority[priority]
			if not module_ids.has(module_id):
				module_ids.append(module_id)

	for system in systems:
		var by_priority: Dictionary = systems[system]
		for priority in by_priority:
			var module_ids: Array = by_priority[priority]
			if module_ids.size() < 2:
				continue
			for i in range(module_ids.size()):
				for j in range(i + 1, module_ids.size()):
					conflicts.append(
						"conflicto: %s sustituido por %s y %s con la misma prioridad %d"
						% [system, module_ids[i], module_ids[j], priority]
					)

	return conflicts


static func _system_of(replace: String) -> String:
	var parts := replace.split(":")
	var candidate := parts[parts.size() - 1] if parts.size() > 0 else ""
	return candidate if _matches(candidate, REPLACE_PART_PATTERN) else ""


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
	if parts.size() < 1 or parts.size() > 2:
		return false
	for part in parts:
		if part.is_empty() or not _matches(part, REPLACE_PART_PATTERN):
			return false
	return true


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
