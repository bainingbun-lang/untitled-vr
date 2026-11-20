class_name ModRegistry
extends RefCounted

# Limitacion de plataforma: Godot no puede descargar un PCK ya cargado.
# "Descargar" un modulo aqui significa desactivarlo: ejecutar su _mod_shutdown()
# si existe y retirar sus suscripciones al bus. Los recursos que aporto el PCK
# siguen en memoria hasta reiniciar el proceso; no hay API para liberarlos.
#
# La descarga no hace cascada automatica: si otro modulo cargado declara una
# dependencia sobre el modulo solicitado, unload() falla sin descargar nada y
# deja la decision (y el orden) en manos del llamador.

const ModManifestScript = preload("res://core/mod_manifest.gd")
const ModApiScript = preload("res://core/mod_api.gd")
const RuntimeGDScript = preload("res://core/runtime_gdscript.gd")
const RuntimeLua = preload("res://core/runtime_lua.gd")
const RuntimeWasm = preload("res://core/runtime_wasm.gd")
const ContentRegistryScript = preload("res://core/game/content_registry.gd")

const RESOLVER_PATH := "res://core/mod_resolver.gd"
const DEFAULT_PRIORITY := 100

var _bus
var _loaded: Dictionary = {}
var _order: Array = []


func _init(bus) -> void:
	_bus = bus


func scan(root_dir: String) -> Dictionary:
	var errors: Array = []
	var candidates: Array = []
	var root := DirAccess.open(root_dir)
	if root == null:
		errors.append("no se pudo abrir el directorio '%s'" % root_dir)
		return {"ok": false, "errors": errors, "candidates": candidates}

	for sub_dir in root.get_directories():
		var dir := root_dir.path_join(sub_dir)
		var manifest_path := dir.path_join("mod.json")
		if not FileAccess.file_exists(manifest_path):
			continue

		var file := FileAccess.open(manifest_path, FileAccess.READ)
		if file == null:
			errors.append("%s: no se pudo leer mod.json" % dir)
			continue
		var text := file.get_as_text()
		file.close()

		var data: Variant = JSON.parse_string(text)
		if data == null:
			errors.append("%s: JSON invalido en mod.json" % dir)
			continue
		if typeof(data) != TYPE_DICTIONARY:
			errors.append("%s: mod.json debe ser un objeto JSON" % dir)
			continue

		_normalize_json_ints(data)
		var result := ModManifestScript.parse(data)
		if not result["ok"]:
			errors.append("%s: manifiesto invalido: %s" % [dir, " | ".join(result["errors"])])
			continue

		candidates.append({"manifest": result["manifest"], "dir": dir})

	return {"ok": errors.is_empty(), "errors": errors, "candidates": candidates}


func load_all(candidates: Array) -> Dictionary:
	var errors: Array = []
	var failed: Dictionary = {}
	var loaded_now: Array = []

	var by_id: Dictionary = {}
	for candidate in candidates:
		var manifest := _manifest_of(candidate)
		var module_id := str(manifest.get("id", ""))
		if module_id.is_empty() or by_id.has(module_id):
			continue
		by_id[module_id] = candidate

	var conflicts := ModManifestScript.find_conflicts(candidates)
	var conflicting: Dictionary = {}
	for conflict in conflicts:
		var message := str(conflict.get("message", "conflicto de reemplazo"))
		errors.append(message)
		for module_id in conflict.get("modules", []):
			conflicting[str(module_id)] = true

	var filtered: Array = []
	for candidate in candidates:
		var manifest := _manifest_of(candidate)
		var module_id := str(manifest.get("id", ""))
		if conflicting.has(module_id):
			failed[module_id] = "conflicto de reemplazo"
			continue
		filtered.append(candidate)

	var resolution := _resolve(filtered)
	for error in resolution["errors"]:
		errors.append(str(error))

	var order: Array = resolution["order"]
	for module_id in order:
		var id := str(module_id)
		if _loaded.has(id):
			continue
		if failed.has(id):
			continue
		if not by_id.has(id):
			continue

		var candidate: Dictionary = by_id[id]
		var manifest: Dictionary = candidate["manifest"]
		var dir := str(candidate.get("dir", ""))
		var runtime_type := str(manifest.get("runtime", "gdscript"))

		var blocked := _failed_dependency(manifest, failed)
		if not blocked.is_empty():
			failed[id] = "dependencia no disponible: %s" % blocked
			errors.append("%s no se carga porque su dependencia %s fallo" % [id, blocked])
			continue

		var adapter: RuntimeAdapter = null
		match runtime_type:
			"gdscript":
				adapter = RuntimeGDScript.new()
			"lua":
				adapter = RuntimeLua.new()
			"wasm":
				adapter = RuntimeWasm.new()
			_:
				failed[id] = "runtime desconocido: %s" % runtime_type
				errors.append("%s: runtime desconocido %s" % [id, runtime_type])
				continue

		var load_err: String = adapter.load(manifest, dir)
		if load_err != "":
			failed[id] = load_err
			errors.append("%s: %s" % [id, load_err])
			continue

		var permissions: Array = manifest.get("permissions", [])
		var api = ModApiScript.new(id, _bus, permissions)
		var init_err: String = adapter.init(api)
		if init_err != "":
			failed[id] = init_err
			errors.append("%s: %s" % [id, init_err])
			continue

		_loaded[id] = {
			"manifest": manifest,
			"dir": dir,
			"adapter": adapter,
			"api": api,
		}
		_order.append(id)
		loaded_now.append(id)
		ContentRegistryScript.instance().load_mod(id, dir, int(manifest.get("priority", DEFAULT_PRIORITY)))

	for candidate in candidates:
		var manifest := _manifest_of(candidate)
		var module_id := str(manifest.get("id", ""))
		if module_id.is_empty() or _loaded.has(module_id) or failed.has(module_id):
			continue
		failed[module_id] = "no resuelto (dependencias incompletas)"
		errors.append("%s no se cargo: dependencias incompletas" % module_id)

	ContentRegistryScript.instance().sync_loaded(loaded_ids())
	return {
		"ok": failed.is_empty() and errors.is_empty(),
		"loaded": loaded_now,
		"failed": failed,
		"errors": errors,
	}


func unload(module_id: String) -> Dictionary:
	var errors: Array = []
	if not _loaded.has(module_id):
		errors.append("el modulo '%s' no esta cargado" % module_id)
		return {"ok": false, "errors": errors}

	var dependents := _dependents_of(module_id)
	if not dependents.is_empty():
		errors.append(
			"no se puede descargar '%s': los modulos %s dependen de el"
			% [module_id, ", ".join(dependents)]
		)
		return {"ok": false, "errors": errors}

	var record: Dictionary = _loaded[module_id]
	var adapter: RuntimeAdapter = record.get("adapter", null)
	if adapter != null:
		adapter.unload()
	var api: Variant = record.get("api", null)
	if api != null:
		api._release()

	_loaded.erase(module_id)
	_order.erase(module_id)
	ContentRegistryScript.instance().unload_mod(module_id)
	ContentRegistryScript.instance().sync_loaded(loaded_ids())
	return {"ok": true, "errors": errors}


func is_loaded(module_id: String) -> bool:
	return _loaded.has(module_id)


func loaded_ids() -> Array:
	return _order.duplicate()


func get_instance(module_id: String) -> Object:
	if not _loaded.has(module_id):
		return null
	var adapter = _loaded[module_id].get("adapter", null)
	return adapter.get_instance() if adapter != null else null


# JSON.parse_string devuelve todos los numeros como float. ModManifest exige
# int en schema_version y priority, asi que se normalizan justo en el limite
# del JSON antes de validar.
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


func _manifest_of(entry: Variant) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = entry
	if data.has("manifest") and typeof(data["manifest"]) == TYPE_DICTIONARY:
		return data["manifest"]
	return data


func _failed_dependency(manifest: Dictionary, failed: Dictionary) -> String:
	var depends: Variant = manifest.get("depends", {})
	if typeof(depends) != TYPE_DICTIONARY:
		return ""
	var keys: Array = depends.keys()
	keys.sort()
	for key in keys:
		var dep_id := str(key)
		if failed.has(dep_id):
			return dep_id
	return ""


func _dependents_of(module_id: String) -> Array:
	var dependents: Array = []
	for other_id in _order:
		if other_id == module_id:
			continue
		var manifest: Dictionary = _loaded[other_id]["manifest"]
		var depends: Variant = manifest.get("depends", {})
		if typeof(depends) == TYPE_DICTIONARY and depends.has(module_id):
			dependents.append(str(other_id))
	dependents.sort()
	return dependents


func _absolute_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path


func _resolve(candidates: Array) -> Dictionary:
	var resolver: Variant = load(RESOLVER_PATH)
	if resolver != null and resolver is GDScript and resolver.can_instantiate():
		return resolver.resolve(candidates)
	return _fallback_resolve(candidates)


# Respaldo de resolucion usado solo si ModResolver no esta disponible en el
# runtime (p. ej. un script que no compila en esta version del motor). Mantiene
# el mismo contrato: order con dependencias antes que dependientes y errores
# que describen por que un modulo se queda fuera.
func _fallback_resolve(candidates: Array) -> Dictionary:
	var errors: Array = []
	var records: Dictionary = {}
	var counts: Dictionary = {}

	for candidate in candidates:
		var manifest := _manifest_of(candidate)
		var module_id := str(manifest.get("id", ""))
		if module_id.is_empty():
			errors.append("manifiesto invalido: id ausente")
			continue
		counts[module_id] = int(counts.get(module_id, 0)) + 1
		if not records.has(module_id):
			records[module_id] = manifest

	var ids_sorted: Array = records.keys()
	ids_sorted.sort()

	var failed: Dictionary = {}
	var depends: Dictionary = {}

	for module_id in ids_sorted:
		var id := str(module_id)
		if int(counts[id]) > 1:
			failed[id] = true
			errors.append("id duplicado '%s' (%d manifiestos)" % [id, int(counts[id])])
			continue
		var manifest: Dictionary = records[id]
		var raw_depends: Variant = manifest.get("depends", {})
		if typeof(raw_depends) != TYPE_DICTIONARY:
			failed[id] = true
			errors.append("%s: depends invalido" % id)
			continue
		depends[id] = raw_depends
		var version := str(manifest.get("version", ""))
		if not _is_version(version):
			failed[id] = true
			errors.append("%s: version invalida '%s'" % [id, version])

	var changed := true
	while changed:
		changed = false
		for module_id in ids_sorted:
			var id := str(module_id)
			if failed.has(id) or not depends.has(id):
				continue
			var dep_keys: Array = depends[id].keys()
			dep_keys.sort()
			for dep_key in dep_keys:
				var dep_id := str(dep_key)
				var raw_range := str(depends[id][dep_key])
				if not _is_range(raw_range):
					failed[id] = true
					errors.append("%s: rango de dependencia invalido '%s'" % [id, raw_range])
					changed = true
					break
				if not records.has(dep_id) or failed.has(dep_id):
					failed[id] = true
					errors.append("%s requiere %s, no disponible" % [id, dep_id])
					changed = true
					break
				var installed := str(records[dep_id].get("version", ""))
				if not _satisfies(installed, raw_range):
					failed[id] = true
					errors.append("%s requiere %s %s, instalada %s" % [id, dep_id, raw_range, installed])
					changed = true
					break

	var indegree: Dictionary = {}
	var remaining: Dictionary = {}
	for module_id in ids_sorted:
		var id := str(module_id)
		if failed.has(id):
			continue
		remaining[id] = true
		var count := 0
		for dep_key in depends[id].keys():
			if not failed.has(str(dep_key)):
				count += 1
		indegree[id] = count

	var ready: Array = []
	for module_id in ids_sorted:
		var id := str(module_id)
		if remaining.has(id) and int(indegree[id]) == 0:
			ready.append(id)

	var order: Array = []
	while not ready.is_empty():
		ready.sort_custom(
			func(a, b):
				var pa := int(records[a].get("priority", DEFAULT_PRIORITY))
				var pb := int(records[b].get("priority", DEFAULT_PRIORITY))
				if pa != pb:
					return pa < pb
				return a < b
		)
		var id := str(ready.pop_front())
		order.append(id)
		for module_id in ids_sorted:
			var other := str(module_id)
			if other == id or not remaining.has(other):
				continue
			if depends[other].has(id):
				indegree[other] = int(indegree[other]) - 1
				if int(indegree[other]) == 0 and not ready.has(other):
					ready.append(other)

	for module_id in ids_sorted:
		var id := str(module_id)
		if remaining.has(id) and not order.has(id):
			failed[id] = true
			errors.append("dependencia circular: %s" % id)

	return {"ok": errors.is_empty(), "errors": errors, "order": order}


func _is_version(value: String) -> bool:
	var parts := value.split(".")
	if parts.size() != 3:
		return false
	for part in parts:
		if part.is_empty():
			return false
		for i in part.length():
			if not "0123456789".contains(part[i]):
				return false
	return true


func _parse_version(value: String) -> Array:
	if not _is_version(value):
		return []
	var parts := value.split(".")
	return [int(parts[0]), int(parts[1]), int(parts[2])]


func _compare_versions(a: String, b: String) -> int:
	var pa := _parse_version(a)
	var pb := _parse_version(b)
	if pa.is_empty() or pb.is_empty():
		return 0
	for i in 3:
		if pa[i] < pb[i]:
			return -1
		if pa[i] > pb[i]:
			return 1
	return 0


func _range_tokens(range: String) -> Array:
	var text := range.strip_edges()
	text = text.replace("\t", " ").replace("\n", " ").replace("\r", " ")
	return text.split(" ", false)


func _is_range(range: String) -> bool:
	var tokens := _range_tokens(range)
	if tokens.is_empty():
		return false
	for token in tokens:
		if token == "*":
			continue
		if token.begins_with("^"):
			if not _is_version(token.substr(1)):
				return false
			continue
		var rest: String = token
		for candidate in [">=", "<=", ">", "<", "="]:
			if token.begins_with(candidate):
				rest = token.substr(candidate.length())
				break
		if not _is_version(rest):
			return false
	return true


func _satisfies(version: String, range: String) -> bool:
	if not _is_version(version) or not _is_range(range):
		return false
	for token in _range_tokens(range):
		if token == "*":
			continue
		if token.begins_with("^"):
			var base_text: String = token.substr(1)
			var base := _parse_version(base_text)
			if _compare_versions(version, base_text) < 0:
				return false
			var upper := ""
			if base[0] > 0:
				upper = "%d.0.0" % (base[0] + 1)
			else:
				upper = "0.%d.0" % (base[1] + 1)
			if _compare_versions(version, upper) >= 0:
				return false
			continue
		var op := ""
		var rest: String = token
		for candidate in [">=", "<=", ">", "<", "="]:
			if token.begins_with(candidate):
				op = candidate
				rest = token.substr(candidate.length())
				break
		var result := _compare_versions(version, rest)
		if op == ">=" and result < 0:
			return false
		elif op == ">" and result <= 0:
			return false
		elif op == "<=" and result > 0:
			return false
		elif op == "<" and result >= 0:
			return false
		elif (op == "=" or op.is_empty()) and result != 0:
			return false
	return true
