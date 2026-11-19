class_name ModResolver
extends RefCounted

const DEFAULT_PRIORITY := 100


static func is_valid_version(v: String) -> bool:
	var parts: Variant = v.split(".")
	if parts.size() != 3:
		return false
	for part in parts:
		if part.is_empty():
			return false
		for i in part.length():
			if not "0123456789".contains(part[i]):
				return false
	return true


static func compare(a: String, b: String) -> int:
	var pa: Variant = _parse_version(a)
	var pb: Variant = _parse_version(b)
	if pa.is_empty() or pb.is_empty():
		return 0
	for i in 3:
		if pa[i] < pb[i]:
			return -1
		if pa[i] > pb[i]:
			return 1
	return 0


static func is_valid_range(range: String) -> bool:
	var tokens: Variant = _range_tokens(range)
	if tokens.is_empty():
		return false
	for token in tokens:
		if token == "*":
			continue
		if token.begins_with("^"):
			if not is_valid_version(token.substr(1)):
				return false
			continue
		var rest: Variant = token
		for candidate in [">=", "<=", ">", "<", "="]:
			if token.begins_with(candidate):
				rest = token.substr(candidate.length())
				break
		if not is_valid_version(rest):
			return false
	return true


static func satisfies(version: String, range: String) -> bool:
	if not is_valid_version(version) or not is_valid_range(range):
		return false
	for token in _range_tokens(range):
		if token == "*":
			continue
		if token.begins_with("^"):
			var base_text: Variant = token.substr(1)
			var base: Variant = _parse_version(base_text)
			if compare(version, base_text) < 0:
				return false
			var upper: Variant = ""
			if base[0] > 0:
				upper = "%d.0.0" % (base[0] + 1)
			else:
				upper = "0.%d.0" % (base[1] + 1)
			if compare(version, upper) >= 0:
				return false
			continue
		var op: Variant = ""
		var rest: Variant = token
		for candidate in [">=", "<=", ">", "<", "="]:
			if token.begins_with(candidate):
				op = candidate
				rest = token.substr(candidate.length())
				break
		var result: Variant = compare(version, rest)
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


static func resolve(manifests: Array) -> Dictionary:
	var errors: Array[String] = []
	var raw: Array = []

	for entry in manifests:
		var manifest: Variant = _manifest_of(entry)
		if manifest.is_empty():
			errors.append("manifiesto inválido: se esperaba un Dictionary con id")
			continue
		var id: Variant = str(manifest.get("id", ""))
		if not _is_valid_id(id):
			errors.append("manifiesto ignorado: id inválido '%s'" % id)
			continue
		raw.append(manifest)

	var counts: Variant = {}
	for manifest in raw:
		var id: Variant = str(manifest.get("id", ""))
		counts[id] = int(counts.get(id, 0)) + 1

	var duplicate_ids: Variant = {}
	var count_keys: Array = counts.keys()
	count_keys.sort()
	for id in count_keys:
		if int(counts[id]) > 1:
			duplicate_ids[id] = true
			errors.append("id duplicado '%s' (%d manifiestos)" % [id, int(counts[id])])

	var records: Variant = {}
	for manifest in raw:
		var id: Variant = str(manifest.get("id", ""))
		if duplicate_ids.has(id):
			continue
		var depends: Dictionary = {}
		if typeof(manifest.get("depends", {})) == TYPE_DICTIONARY:
			depends = manifest.get("depends", {})
		records[id] = {
			"id": id,
			"version": str(manifest.get("version", "")),
			"priority": int(manifest.get("priority", DEFAULT_PRIORITY)),
			"depends": depends,
		}

	var failed: Variant = {}
	var fail_reason: Variant = {}
	for id in duplicate_ids:
		failed[id] = true
		fail_reason[id] = "id duplicado"

	var ids_sorted: Array = records.keys()
	ids_sorted.sort()

	for id in ids_sorted:
		var record: Dictionary = records[id]
		if not is_valid_version(str(record["version"])):
			errors.append("%s: versión inválida '%s'" % [id, record["version"]])
			_mark_failed(failed, fail_reason, str(id), "versión inválida")

	for id in ids_sorted:
		var record: Dictionary = records[id]
		var depends: Dictionary = record["depends"]
		var dep_keys: Array = depends.keys()
		dep_keys.sort()
		for dep_key in dep_keys:
			var dep_id: Variant = str(dep_key)
			var raw_range: Variant = str(depends[dep_key])
			if not is_valid_range(raw_range):
				errors.append(
					"%s: rango de dependencia inválido '%s' para %s" % [id, raw_range, dep_id]
				)
				_mark_failed(failed, fail_reason, str(id), "rango inválido")
				continue
			if not records.has(dep_id):
				if duplicate_ids.has(dep_id):
					continue
				errors.append("%s requiere %s %s, no está instalado" % [id, dep_id, raw_range])
				_mark_failed(failed, fail_reason, str(id), "dependencia inexistente")
				continue
			var installed: Variant = str(records[dep_id]["version"])
			if not is_valid_version(installed):
				continue
			if not satisfies(installed, raw_range):
				errors.append(
					"%s requiere %s %s, instalada %s" % [id, dep_id, raw_range, installed]
				)
				_mark_failed(failed, fail_reason, str(id), "versión incompatible")

	var graph: Variant = {}
	for id in ids_sorted:
		var deps: Array = []
		for dep_key in records[id]["depends"].keys():
			var dep_id: Variant = str(dep_key)
			if records.has(dep_id):
				deps.append(dep_id)
		graph[id] = deps

	for component in _find_cycles(ids_sorted, graph):
		var component_ids: Array = component.duplicate()
		component_ids.sort()
		errors.append("dependencia circular: %s" % ", ".join(component_ids))
		for id in component_ids:
			_mark_failed(failed, fail_reason, str(id), "dependencia circular")

	var dependents: Variant = {}
	for id in ids_sorted:
		for dep_key in records[id]["depends"].keys():
			var dep_id: Variant = str(dep_key)
			if not dependents.has(dep_id):
				dependents[dep_id] = []
			dependents[dep_id].append(str(id))

	var pending: Array = failed.keys()
	pending.sort()
	var head: Variant = 0
	while head < pending.size():
		var bad: Variant = str(pending[head])
		head += 1
		if not dependents.has(bad):
			continue
		for dependent in dependents[bad]:
			var dependent_id: Variant = str(dependent)
			if failed.has(dependent_id):
				continue
			failed[dependent_id] = true
			fail_reason[dependent_id] = bad
			errors.append(
				"%s no se carga porque %s no se carga" % [dependent_id, bad]
			)
			pending.append(dependent_id)

	var priorities: Variant = {}
	var indegree: Variant = {}
	for id in ids_sorted:
		if failed.has(id):
			continue
		priorities[id] = int(records[id]["priority"])
		var count: Variant = 0
		for dep_key in records[id]["depends"].keys():
			if not failed.has(str(dep_key)):
				count += 1
		indegree[id] = count

	var reverse: Variant = {}
	for id in ids_sorted:
		if failed.has(id):
			continue
		for dep_key in records[id]["depends"].keys():
			var dep_id: Variant = str(dep_key)
			if failed.has(dep_id):
				continue
			if not reverse.has(dep_id):
				reverse[dep_id] = []
			reverse[dep_id].append(str(id))

	var ready: Array = []
	for id in ids_sorted:
		if not failed.has(id) and int(indegree[id]) == 0:
			_insert_ready(ready, str(id), priorities)

	var order: Array[String] = []
	while not ready.is_empty():
		var id: Variant = str(ready.pop_front())
		order.append(id)
		if not reverse.has(id):
			continue
		for dependent in reverse[id]:
			var dependent_id: Variant = str(dependent)
			indegree[dependent_id] = int(indegree[dependent_id]) - 1
			if int(indegree[dependent_id]) == 0:
				_insert_ready(ready, dependent_id, priorities)

	if order.size() != indegree.size():
		for id in ids_sorted:
			if not failed.has(id) and not order.has(id):
				order.append(str(id))

	var versions: Variant = {}
	for id in order:
		versions[id] = str(records[id]["version"])

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"order": order,
		"versions": versions,
	}


static func _parse_version(v: String) -> Array:
	if not is_valid_version(v):
		return []
	var parts: Variant = v.split(".")
	return [int(parts[0]), int(parts[1]), int(parts[2])]


static func _range_tokens(range: String) -> Array:
	var text: Variant = range.strip_edges()
	text = text.replace("\t", " ").replace("\n", " ").replace("\r", " ")
	return text.split(" ", false)


static func _is_valid_id(id: String) -> bool:
	var parts: Variant = id.split(".")
	if parts.size() != 2:
		return false
	for part in parts:
		if part.is_empty():
			return false
		for i in part.length():
			if not "abcdefghijklmnopqrstuvwxyz0123456789-".contains(part[i]):
				return false
	return true


static func _manifest_of(entry: Variant) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = entry
	if data.has("manifest") and typeof(data["manifest"]) == TYPE_DICTIONARY:
		return data["manifest"]
	return data


static func _mark_failed(
	failed: Dictionary, fail_reason: Dictionary, id: String, reason: String
) -> void:
	if not failed.has(id):
		failed[id] = true
		fail_reason[id] = reason


static func _insert_ready(queue: Array, id: String, priorities: Dictionary) -> void:
	var index: Variant = 0
	var my_priority: Variant = int(priorities[id])
	while index < queue.size():
		var other: Variant = str(queue[index])
		var other_priority: Variant = int(priorities[other])
		if my_priority < other_priority:
			break
		if my_priority == other_priority and id < other:
			break
		index += 1
	queue.insert(index, id)


static func _find_cycles(ids: Array, graph: Dictionary) -> Array:
	var state: Variant = {
		"index": 0,
		"indices": {},
		"low": {},
		"stack": [],
		"on_stack": {},
		"cycles": [],
	}
	for id in ids:
		if not state["indices"].has(id):
			_strongconnect(str(id), graph, state)
	return state["cycles"]


static func _strongconnect(v: String, graph: Dictionary, state: Dictionary) -> void:
	var indices: Dictionary = state["indices"]
	var low: Dictionary = state["low"]
	var stack: Array = state["stack"]
	var on_stack: Dictionary = state["on_stack"]

	indices[v] = state["index"]
	low[v] = state["index"]
	state["index"] = int(state["index"]) + 1
	stack.append(v)
	on_stack[v] = true

	for neighbor in graph.get(v, []):
		var w: Variant = str(neighbor)
		if not indices.has(w):
			_strongconnect(w, graph, state)
			if int(low[w]) < int(low[v]):
				low[v] = low[w]
		elif on_stack.get(w, false):
			if int(indices[w]) < int(low[v]):
				low[v] = indices[w]

	if int(low[v]) == int(indices[v]):
		var component: Array = []
		while true:
			var w: Variant = str(stack.pop_back())
			on_stack[w] = false
			component.append(w)
			if w == v:
				break
		var self_loop: Variant = component.size() == 1 and graph.get(v, []).has(v)
		if component.size() > 1 or self_loop:
			state["cycles"].append(component)
