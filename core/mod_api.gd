class_name ModApi
extends RefCounted

var module_id: String
var _bus
var _subscriptions: Array = []
var _permissions: Array = []

func _init(module_id: String, bus, permissions: Array = []) -> void:
	self.module_id = module_id
	_bus = bus
	_permissions = permissions


func subscribe(event: String, handler: Callable, priority: int = 100) -> int:
	if not _has_permission("subscribe") and not _permissions.is_empty():
		push_error("ModApi: permiso 'subscribe' ausente para %s" % module_id)
		return -1
	var subscription_id: int = _bus.subscribe(event, handler, module_id, priority)
	if subscription_id > 0:
		_subscriptions.append(subscription_id)
	return subscription_id


func emit(event: String, payload: Dictionary = {}) -> Dictionary:
	if not _has_permission("emit") and not _permissions.is_empty():
		push_error("ModApi: permiso 'emit' ausente para %s" % module_id)
		return {}
	return _bus.emit(event, payload)

func _has_permission(perm: String) -> bool:
	return _permissions.has(perm)


func _release() -> int:
	_subscriptions.clear()
	return _bus.unsubscribe_owner(module_id)
