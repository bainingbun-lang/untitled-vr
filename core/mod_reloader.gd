class_name ModReloader
extends RefCounted

const ModManifestScript = preload("res://core/mod_manifest.gd")
const CACHE_ROOT := "user://mod_reloader_cache"

static var _copy_counter := 0

func reload(registry, loader, mod_id: String, dir: String) -> Dictionary:
	var failure := {"ok": false, "error": ""}
	if registry == null or loader == null:
		failure["error"] = "registry o loader no validos"
		return failure
	if mod_id.is_empty():
		failure["error"] = "id de modulo vacio"
		return failure
	if not registry.is_loaded(mod_id):
		failure["error"] = "el modulo '%s' no esta cargado" % mod_id
		return failure

	var manifest_path := dir.path_join("mod.json")
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		failure["error"] = "no se pudo leer '%s'" % manifest_path
		return failure
	var text := file.get_as_text()
	file.close()
	var stripped := text.strip_edges()
	if stripped.is_empty() or not stripped.ends_with("}") or not stripped.contains(":"):
		failure["error"] = "JSON invalido en '%s'" % manifest_path
		return failure
	var data: Variant = JSON.parse_string(text)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		failure["error"] = "JSON invalido en '%s'" % manifest_path
		return failure
	var validation: Dictionary = loader.validate(data)
	if not bool(validation.get("ok", false)):
		failure["error"] = "manifiesto invalido: %s" % _join(validation.get("errors", []))
		return failure
	var new_manifest: Dictionary = validation.get("manifest", {})
	if str(new_manifest.get("id", "")) != mod_id:
		failure["error"] = "el manifiesto declara '%s', se esperaba '%s'" % [
			str(new_manifest.get("id", "")), mod_id
		]
		return failure
	var runtime := str(new_manifest.get("runtime", "gdscript"))
	if runtime != "gdscript":
		failure["error"] = "recarga no soportada para runtime '%s'" % runtime
		return failure

	var entry := str(new_manifest.get("entry", ""))
	var fresh_entry := ""
	if entry != "":
		var source_file := FileAccess.open(entry, FileAccess.READ)
		if source_file == null:
			failure["error"] = "no se pudo releer la entrada '%s'" % entry
			return failure
		var source := source_file.get_as_text()
		source_file.close()
		fresh_entry = _fresh_copy(mod_id, source)
		if fresh_entry.is_empty():
			failure["error"] = "no se pudo preparar una copia fresca de '%s'" % entry
			return failure
		var fresh: Variant = ResourceLoader.load(
			fresh_entry, "", ResourceLoader.CACHE_MODE_IGNORE
		)
		if fresh == null or not (fresh is GDScript):
			failure["error"] = "no se pudo compilar la entrada '%s'" % entry
			return failure
		var probe: Variant = fresh.new()
		if probe == null or not probe.has_method("_mod_init"):
			failure["error"] = "la entrada '%s' no implementa _mod_init" % entry
			return failure

	var previous: Array = _snapshot(registry, mod_id)
	var to_unload: Array = []
	for item in previous:
		to_unload.append(str(item["id"]))
	to_unload.reverse()
	for oid in to_unload:
		var unloaded: Dictionary = registry.unload(oid)
		if not bool(unloaded.get("ok", false)):
			_restore(registry, previous)
			failure["error"] = "no se pudo descargar '%s': %s" % [
				oid, _join(unloaded.get("errors", []))
			]
			return failure

	if fresh_entry != "":
		new_manifest["entry"] = fresh_entry

	var candidates: Array = []
	for item in previous:
		var candidate_manifest: Dictionary = item["manifest"]
		var candidate_dir := str(item["dir"])
		if str(item["id"]) == mod_id:
			candidate_manifest = new_manifest
			candidate_dir = dir
		candidates.append({"manifest": candidate_manifest, "dir": candidate_dir})

	var loaded: Dictionary = registry.load_all(candidates)
	if not bool(loaded.get("ok", false)) or not registry.is_loaded(mod_id):
		_restore(registry, previous)
		var detail := _join(loaded.get("errors", []))
		if detail.is_empty():
			detail = str(loaded.get("failed", {}))
		failure["error"] = "fallo al recargar '%s': %s" % [mod_id, detail]
		return failure

	var expected: Array = []
	for item in previous:
		expected.append(str(item["id"]))
	var actual: Array = []
	for oid in registry.loaded_ids():
		if expected.has(str(oid)):
			actual.append(str(oid))
	if actual != expected:
		_restore(registry, previous)
		failure["error"] = "el orden de carga cambio tras la recarga de '%s'" % mod_id
		return failure

	return {"ok": true, "error": ""}

func _fresh_copy(mod_id: String, source: String) -> String:
	var root := DirAccess.open("user://")
	if root == null:
		return ""
	if not root.dir_exists("mod_reloader_cache"):
		root.make_dir("mod_reloader_cache")
	var safe_id := mod_id.replace(".", "_").replace("/", "_")
	_copy_counter += 1
	var name := "%s_%d_%d.gd" % [safe_id, Time.get_ticks_usec(), _copy_counter]
	var path := CACHE_ROOT.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(source)
	file.close()
	return path

func _snapshot(registry, mod_id: String) -> Array:
	var dependents: Array = []
	for other_id in registry.loaded_ids():
		var oid := str(other_id)
		if oid == mod_id:
			continue
		var record: Dictionary = registry._loaded.get(oid, {})
		var depends: Variant = record.get("manifest", {}).get("depends", {})
		if typeof(depends) == TYPE_DICTIONARY and depends.has(mod_id):
			dependents.append(oid)

	var previous: Array = []
	for other_id in registry.loaded_ids():
		var oid := str(other_id)
		if oid != mod_id and not dependents.has(oid):
			continue
		var record: Dictionary = registry._loaded.get(oid, {})
		var manifest: Dictionary = record.get("manifest", {})
		previous.append({
			"id": oid,
			"manifest": manifest.duplicate(true),
			"dir": str(record.get("dir", "")),
		})
	return previous

func _restore(registry, previous: Array) -> void:
	var ids: Array = []
	for item in previous:
		ids.append(str(item["id"]))
	ids.reverse()
	for oid in ids:
		if registry.is_loaded(oid):
			registry.unload(oid)
	var candidates: Array = []
	for item in previous:
		candidates.append({"manifest": item["manifest"], "dir": item["dir"]})
	registry.load_all(candidates)

func _join(errors: Array) -> String:
	var parts: Array = []
	for error in errors:
		parts.append(str(error))
	return " | ".join(parts)
