class_name Inventory
extends RefCounted

const SNAPSHOT_VERSION := 1
const ItemDbScript = preload("res://core/game/item_db.gd")

var _db
var _slots: Array = []
var _max_weight: float = -1.0
var _log: Array = []


func _init(db = null, slot_capacity: int = 20, max_weight: float = -1.0) -> void:
	_db = db if db != null else ItemDbScript.new()
	var capacity: int = maxi(slot_capacity, 0)
	_slots = []
	_slots.resize(capacity)
	for i in range(capacity):
		_slots[i] = {}
	_max_weight = max_weight


func slot_capacity() -> int:
	return _slots.size()


func max_weight() -> float:
	return _max_weight


func slots() -> Array:
	return _slots.duplicate(true)


func used_slots() -> int:
	var used := 0
	for slot in _slots:
		if not (slot as Dictionary).is_empty():
			used += 1
	return used


func count(id: String) -> int:
	var total := 0
	for slot in _slots:
		var entry: Dictionary = slot
		if not entry.is_empty() and str(entry.get("id", "")) == id:
			total += int(entry.get("count", 0))
	return total


func total_weight() -> float:
	var total := 0.0
	for slot in _slots:
		var entry: Dictionary = slot
		if entry.is_empty():
			continue
		var def: Dictionary = _db.get_def(str(entry.get("id", "")))
		total += float(def.get("peso", 0.0)) * float(int(entry.get("count", 0)))
	return total


func can_add(id: String, amount: int = 1) -> Dictionary:
	return _public(_plan_add(id, amount))


func can_remove(id: String, amount: int = 1) -> Dictionary:
	return _public(_plan_remove(id, amount))


func add(id: String, amount: int = 1) -> Dictionary:
	var plan := _plan_add(id, amount)
	for placement in plan["placements"]:
		var index := int(placement["slot"])
		var units := int(placement["amount"])
		var entry: Dictionary = _slots[index]
		if entry.is_empty():
			entry = {"id": id, "count": 0}
		entry["count"] = int(entry.get("count", 0)) + units
		_slots[index] = entry
	return _public(plan)


func remove(id: String, amount: int = 1) -> Dictionary:
	var plan := _plan_remove(id, amount)
	for removal in plan["removals"]:
		var index := int(removal["slot"])
		var units := int(removal["amount"])
		var entry: Dictionary = _slots[index]
		var left := int(entry.get("count", 0)) - units
		if left <= 0:
			_slots[index] = {}
		else:
			entry["count"] = left
			_slots[index] = entry
	return _public(plan)


func transfer(target, id: String, amount: int = 1) -> Dictionary:
	if target == null or not target.has_method("can_add"):
		return {"ok": false, "transferred": 0, "reason": "destino invalido"}
	if target == self:
		return {"ok": false, "transferred": 0, "reason": "destino es el mismo inventario"}
	if amount < 1:
		return {"ok": false, "transferred": 0, "reason": "cantidad invalida"}

	var source_check := can_remove(id, amount)
	if not bool(source_check["ok"]):
		return {
			"ok": false,
			"transferred": 0,
			"reason": "origen: %s" % str(source_check["reason"]),
		}

	var target_check = target.can_add(id, amount)
	var target_ok := typeof(target_check) == TYPE_DICTIONARY and bool(target_check.get("ok", false))
	if not target_ok:
		var why := "sin capacidad"
		if typeof(target_check) == TYPE_DICTIONARY:
			why = str(target_check.get("reason", why))
		return {
			"ok": false,
			"transferred": 0,
			"reason": "destino: %s" % why,
		}

	var removed := remove(id, amount)
	var added = target.add(id, amount)
	if not bool(removed["ok"]) or not bool(added.get("ok", false)):
		var rollback = target.remove(id, int(added.get("added", 0)))
		add(id, int(removed.get("removed", 0)))
		_record("transferencia inconsistente: %s" % str(rollback.get("reason", "")))
		return {"ok": false, "transferred": 0, "reason": "transferencia inconsistente"}
	return {"ok": true, "transferred": amount}


func clear() -> void:
	for i in range(_slots.size()):
		_slots[i] = {}


func to_dict() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"slot_capacity": _slots.size(),
		"max_weight": _max_weight,
		"slots": _slots.duplicate(true),
	}


func restore(data: Dictionary) -> bool:
	var checked := validate_snapshot(data, _db)
	if not bool(checked["ok"]):
		for error in checked["errors"]:
			_record(str(error))
		return false
	_slots = (checked["slots"] as Array).duplicate(true)
	_max_weight = float(checked["max_weight"])
	return true


static func validate_snapshot(data: Variant, db) -> Dictionary:
	var result := {
		"ok": false,
		"errors": [],
		"slot_capacity": 0,
		"max_weight": -1.0,
		"slots": [],
	}
	var errors: Array = result["errors"]

	if typeof(data) != TYPE_DICTIONARY:
		errors.append("snapshot: se esperaba un Dictionary")
		return result

	var raw: Dictionary = data
	var version = _as_int(raw.get("version", SNAPSHOT_VERSION))
	if version == null or version != SNAPSHOT_VERSION:
		errors.append("version de snapshot no soportada")

	var capacity = _as_int(raw.get("slot_capacity", null))
	if capacity == null or capacity < 0:
		errors.append("slot_capacity: debe ser un entero >= 0")
		capacity = 0

	var weight = _as_float(raw.get("max_weight", -1.0))
	if weight == null:
		errors.append("max_weight: debe ser numerico")
		weight = -1.0

	var raw_slots = raw.get("slots", null)
	if typeof(raw_slots) != TYPE_ARRAY:
		errors.append("slots: debe ser un Array")
		return result
	var source_slots: Array = raw_slots
	if source_slots.size() != capacity:
		errors.append("slots: tamano distinto de slot_capacity")

	var slots: Array = []
	var total := 0.0
	for i in range(source_slots.size()):
		var entry = source_slots[i]
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("slots[%d]: debe ser un Dictionary" % i)
			slots.append({})
			continue
		var source: Dictionary = entry
		if source.is_empty():
			slots.append({})
			continue

		var id := _as_string(source.get("id", ""))
		var units = _as_int(source.get("count", null))
		if id.is_empty() or db == null or not db.has(id):
			errors.append("slots[%d]: item desconocido '%s'" % [i, id])
			slots.append({})
			continue
		if units == null or units < 1:
			errors.append("slots[%d]: count debe ser un entero >= 1" % i)
			slots.append({})
			continue

		var def: Dictionary = db.get_def(id)
		var limit: int = int(def.get("max_stack", 1))
		if not bool(def.get("apilable", false)):
			limit = 1
		if units > maxi(limit, 1):
			errors.append("slots[%d]: count excede max_stack" % i)
			slots.append({})
			continue

		slots.append({"id": id, "count": units})
		total += float(def.get("peso", 0.0)) * float(units)

	if weight >= 0.0 and total > weight + 0.000001:
		errors.append("peso total excede max_weight")

	result["ok"] = errors.is_empty()
	result["slot_capacity"] = capacity
	result["max_weight"] = weight
	result["slots"] = slots
	return result


func get_log() -> Array:
	return _log.duplicate()


func clear_log() -> void:
	_log.clear()


func _plan_add(id: String, amount: int) -> Dictionary:
	var plan := {
		"placements": [],
		"added": 0,
		"rejected": 0,
		"reason": "",
		"ok": false,
	}
	if amount < 1:
		plan["rejected"] = maxi(amount, 0)
		plan["reason"] = "cantidad invalida"
		return plan
	if _db == null or not _db.has(id):
		plan["rejected"] = amount
		plan["reason"] = "item desconocido '%s'" % id
		return plan

	var def: Dictionary = _db.get_def(id)
	var stackable := bool(def.get("apilable", false))
	var limit: int = maxi(int(def.get("max_stack", 1)), 1)
	if not stackable:
		limit = 1

	var peso := float(def.get("peso", 0.0))
	var affordable := amount
	if _max_weight >= 0.0 and peso > 0.0:
		var left: float = maxf(_max_weight - total_weight(), 0.0)
		affordable = mini(int(floor(left / peso)), amount)

	var remaining := amount
	if stackable:
		for i in range(_slots.size()):
			if remaining <= 0 or affordable <= 0:
				break
			var entry: Dictionary = _slots[i]
			if str(entry.get("id", "")) != id:
				continue
			var space: int = limit - int(entry.get("count", 0))
			if space <= 0:
				continue
			var take: int = mini(space, mini(remaining, affordable))
			if take <= 0:
				break
			plan["placements"].append({"slot": i, "amount": take})
			remaining -= take
			affordable -= take
			plan["added"] += take

	for i in range(_slots.size()):
		if remaining <= 0 or affordable <= 0:
			break
		var entry: Dictionary = _slots[i]
		if not entry.is_empty():
			continue
		var take: int = mini(limit, mini(remaining, affordable))
		if take <= 0:
			break
		plan["placements"].append({"slot": i, "amount": take})
		remaining -= take
		affordable -= take
		plan["added"] += take

	plan["rejected"] = remaining
	plan["ok"] = remaining == 0
	if remaining > 0:
		plan["reason"] = "peso excedido" if affordable <= 0 else "sin slots libres"
	return plan


func _plan_remove(id: String, amount: int) -> Dictionary:
	var plan := {
		"removals": [],
		"removed": 0,
		"rejected": 0,
		"reason": "",
		"ok": false,
	}
	if amount < 1:
		plan["rejected"] = maxi(amount, 0)
		plan["reason"] = "cantidad invalida"
		return plan

	var remaining := amount
	for i in range(_slots.size()):
		if remaining <= 0:
			break
		var entry: Dictionary = _slots[i]
		if str(entry.get("id", "")) != id:
			continue
		var available := int(entry.get("count", 0))
		var take: int = mini(available, remaining)
		if take <= 0:
			continue
		plan["removals"].append({"slot": i, "amount": take})
		remaining -= take
		plan["removed"] += take

	plan["rejected"] = remaining
	plan["ok"] = remaining == 0
	if remaining > 0:
		plan["reason"] = "cantidad insuficiente"
	return plan


func _public(plan: Dictionary) -> Dictionary:
	var result := plan.duplicate()
	result.erase("placements")
	result.erase("removals")
	return result


func _record(message: String) -> void:
	if not _log.has(message):
		_log.append(message)


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


static func _as_float(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return float(value)
		TYPE_STRING:
			var text := str(value).strip_edges()
			if text.is_valid_float():
				return text.to_float()
	return null


static func _as_string(value: Variant) -> String:
	if typeof(value) == TYPE_STRING:
		return value
	if typeof(value) == TYPE_STRING_NAME:
		return String(value)
	return ""
