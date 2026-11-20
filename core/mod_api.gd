class_name ModApi
extends RefCounted

const ModHooksScript = preload("res://core/game/mod_hooks.gd")

var module_id: String
var _bus
var _subscriptions: Array = []
var _permissions: Array = []
var _manifest: Dictionary = {}
var _target = null
var _declared := false
var _hooks_active := false


func _init(module_id: String, bus, permissions: Array = [], manifest: Dictionary = {}) -> void:
	self.module_id = module_id
	_bus = bus
	_manifest = manifest if not manifest.is_empty() else _discover_manifest(module_id)
	var declared: Variant = _manifest.get("permissions", [])
	if permissions.is_empty() and declared is Array and not (declared as Array).is_empty():
		_permissions = (declared as Array).duplicate()
	else:
		_permissions = permissions.duplicate()


func _ensure_hooks():
	var hooks := ModHooksScript.instance()
	if not _hooks_active or hooks.get_bus() != _bus:
		hooks.bind(_bus)
		hooks.set_permissions(module_id, _permissions)
		_hooks_active = true
	return hooks


func subscribe(event: String, handler: Callable, priority: int = 100) -> int:
	if not has_permission("read_events"):
		push_error("ModApi: permiso 'read_events' ausente para %s" % module_id)
		return -1
	if not ModHooksScript.is_event(event):
		return _bus.subscribe(event, handler, module_id, priority, true) if _bus != null else -1
	var hooks = _ensure_hooks()
	if hooks.is_disabled(module_id):
		return -1
	if not hooks.checkpoint(module_id):
		return -1
	var can_modify := (
		ModHooksScript.MODIFIABLE_EVENTS.has(event)
		and hooks.can(module_id, "modify_damage")
	)
	var subscription_id: int = _bus.subscribe(event, handler, module_id, priority, can_modify)
	if subscription_id > 0:
		_subscriptions.append(subscription_id)
	return subscription_id


func subscribe_declared(event: String, method: String, priority: int = 100, target = null) -> int:
	if target == null:
		target = _target
	if target == null or not target.has_method(method):
		push_error("ModApi: '%s' no implementa '%s'" % [module_id, method])
		return -1
	return subscribe(event, Callable(target, method), priority)


func bind_target(target) -> int:
	_target = target
	if _declared or target == null:
		return 0
	_declared = true
	return _ensure_hooks().register_manifest(module_id, _manifest, self, target)


func emit(event: String, payload: Dictionary = {}) -> Dictionary:
	if not has_permission("emit"):
		push_error("ModApi: permiso 'emit' ausente para %s" % module_id)
		return {}
	if not ModHooksScript.is_event(event):
		return _bus.emit(event, payload) if _bus != null else {}
	var hooks = _ensure_hooks()
	if hooks.is_disabled(module_id):
		return {"ok": false, "handled": 0, "stopped": false, "errors": ["modulo desactivado"]}
	if not hooks.checkpoint(module_id):
		return {"ok": false, "handled": 0, "stopped": false, "errors": ["limite de instrucciones"]}
	return hooks.emit_event(event, payload)


func set_value(payload: Dictionary, key: String, value: Variant, permission: String = "modify_damage") -> bool:
	if not has_permission(permission):
		push_error("ModApi: permiso '%s' ausente para %s" % [permission, module_id])
		return false
	if not _ensure_hooks().checkpoint(module_id):
		return false
	payload[key] = value
	return true


func request(action: String, _data: Dictionary = {}) -> bool:
	var hooks = _ensure_hooks()
	if not hooks.can(module_id, action):
		return false
	return hooks.checkpoint(module_id)


func network_request(_url: String = "") -> bool:
	return false


func fail(reason: String) -> bool:
	return _ensure_hooks().deactivate(module_id, reason)


func has_permission(perm: String) -> bool:
	if perm == "network":
		return false
	if _hooks_active and ModHooksScript.instance().is_disabled(module_id):
		return false
	if _permissions.is_empty():
		return true
	if perm == "subscribe" or perm == "emit":
		return _permissions.has(perm) or _permissions.has("read_events")
	if perm == "read_events":
		return _permissions.has("read_events") or _permissions.has("subscribe") or _permissions.has("emit")
	return _permissions.has(perm)


func _has_permission(perm: String) -> bool:
	return has_permission(perm)


func permissions() -> Array:
	return _permissions.duplicate()


func manifest() -> Dictionary:
	return _manifest.duplicate(true)


func checkpoint() -> bool:
	return _ensure_hooks().checkpoint(module_id)


func _release() -> int:
	_subscriptions.clear()
	_declared = false
	_target = null
	if _hooks_active:
		ModHooksScript.instance().forget(module_id)
		_hooks_active = false
	return _bus.unsubscribe_owner(module_id) if _bus != null else 0


func _discover_manifest(id: String) -> Dictionary:
	for base in ["res://mods", "res://build/mods", "user://mods"]:
		var path := String(base).path_join(id).path_join("mod.json")
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return parsed
	return {}
