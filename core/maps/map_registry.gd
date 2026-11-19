class_name MapRegistry
extends RefCounted

var _maps: Dictionary = {}
var _validator: MapValidator

func _init():
	_validator = MapValidator.new()

func register(meta: Dictionary) -> bool:
	var id = meta.get("id")
	if id == null or id == "":
		return false
	
	if _maps.has(id):
		return false
		
	var result = _validator.validate(meta)
	if result.status > MapValidator.Status.COMPATIBLE_WITH_WARNINGS:
		return false
		
	_maps[id] = meta
	return true

func get_map(id: String) -> Dictionary:
	return _maps.get(id, {})

func list() -> Array:
	return _maps.values()

func unregister(id: String) -> bool:
	if _maps.has(id):
		_maps.erase(id)
		return true
	return false
