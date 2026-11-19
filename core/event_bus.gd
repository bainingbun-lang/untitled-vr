class_name ModEventBus
extends RefCounted

# Limitación: GDScript no captura excepciones lanzadas dentro de un handler.
# Un error de script dentro de un handler lo detiene el motor.

const ALLOWED_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"

var _next_id := 1
var _next_seq := 0
var _subscriptions: Dictionary = {}
var _by_event: Dictionary = {}


static func is_valid_event(event: String) -> bool:
	if event.is_empty():
		return false
	var parts := event.split(".")
	if parts.size() < 2:
		return false
	for part in parts:
		if part.is_empty():
			return false
		for i in part.length():
			if not ALLOWED_CHARS.contains(part[i]):
				return false
	return true


func subscribe(event: String, handler: Callable, owner: String, priority: int = 100) -> int:
	if not is_valid_event(event):
		return -1
	if not handler.is_valid():
		return -1
	if owner.is_empty():
		return -1

	var subscription_id := _next_id
	_next_id += 1
	_next_seq += 1
	_subscriptions[subscription_id] = {
		"event": event,
		"handler": handler,
		"owner": owner,
		"priority": priority,
		"seq": _next_seq,
	}
	if not _by_event.has(event):
		_by_event[event] = []
	_by_event[event].append(subscription_id)
	return subscription_id


func unsubscribe(subscription_id: int) -> bool:
	if not _subscriptions.has(subscription_id):
		return false
	var event: String = _subscriptions[subscription_id]["event"]
	_subscriptions.erase(subscription_id)
	var ids: Array = _by_event.get(event, [])
	ids.erase(subscription_id)
	if ids.is_empty():
		_by_event.erase(event)
	return true


func unsubscribe_owner(owner: String) -> int:
	var removed := 0
	var ids := _subscriptions.keys()
	for subscription_id in ids:
		if _subscriptions[subscription_id]["owner"] == owner:
			if unsubscribe(subscription_id):
				removed += 1
	return removed


func has_subscribers(event: String) -> bool:
	if not is_valid_event(event):
		return false
	return _by_event.has(event) and not _by_event[event].is_empty()


func emit(event: String, payload: Dictionary = {}) -> Dictionary:
	var errors: Array = []
	if not is_valid_event(event):
		errors.append("evento invalido: '%s'" % event)
		return {"ok": false, "handled": 0, "stopped": false, "errors": errors}

	var snapshot := _snapshot(event)
	var handled := 0
	var stopped := false
	for entry in snapshot:
		var handler: Callable = entry["handler"]
		if not handler.is_valid():
			errors.append(
				"handler invalido para el evento '%s' (owner '%s')" % [event, entry["owner"]]
			)
			continue
		handled += 1
		var result = handler.call(payload)
		if result is bool and result:
			stopped = true
			break

	return {"ok": true, "handled": handled, "stopped": stopped, "errors": errors}


func clear() -> void:
	_subscriptions.clear()
	_by_event.clear()


func _snapshot(event: String) -> Array:
	var entries: Array = []
	for subscription_id in _by_event.get(event, []):
		if not _subscriptions.has(subscription_id):
			continue
		var subscription: Dictionary = _subscriptions[subscription_id]
		entries.append(subscription.duplicate())
	entries.sort_custom(
		func(a, b):
			if a["priority"] != b["priority"]:
				return a["priority"] > b["priority"]
			return a["seq"] < b["seq"]
	)
	return entries
