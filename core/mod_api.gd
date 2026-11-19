class_name ModApi
extends RefCounted

var module_id: String

var _bus
var _subscriptions: Array = []


func _init(module_id: String, bus) -> void:
	self.module_id = module_id
	_bus = bus


func subscribe(event: String, handler: Callable, priority: int = 100) -> int:
	var subscription_id: int = _bus.subscribe(event, handler, module_id, priority)
	if subscription_id > 0:
		_subscriptions.append(subscription_id)
	return subscription_id


func emit(event: String, payload: Dictionary = {}) -> Dictionary:
	return _bus.emit(event, payload)


func _release() -> int:
	_subscriptions.clear()
	return _bus.unsubscribe_owner(module_id)
