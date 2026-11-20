class_name VehicleSpawner
extends RefCounted

const VehicleScript = preload("res://core/game/vehicle.gd")
const DbScript = preload("res://core/game/vehicle_db.gd")
const MAX_ALIVE := 6

static var max_alive: int = MAX_ALIVE
static var last_error: String = ""
static var _alive: Array = []


# El orquestador la llama al colocar un coche en el mundo (menu de aparicion, mapas).
static func spawn(vehicle_id: String, xform: Transform3D, parent: Node) -> Node3D:
	last_error = ""
	if parent == null or not is_instance_valid(parent):
		last_error = "sin padre"
		return null
	if DbScript.get_def(vehicle_id).is_empty():
		last_error = "vehiculo desconocido: " + vehicle_id
		return null
	var vehicle = VehicleScript.new()
	if not vehicle.setup(vehicle_id):
		vehicle.free()
		last_error = "modelo no disponible: " + vehicle_id
		return null
	parent.add_child(vehicle)
	vehicle.global_transform = xform
	_prune()
	_alive.append(vehicle)
	_enforce_limit()
	return vehicle


static func alive_count() -> int:
	_prune()
	return _alive.size()


static func alive() -> Array:
	_prune()
	return _alive.duplicate()


static func clear() -> void:
	for vehicle in _alive:
		if is_instance_valid(vehicle):
			vehicle.get_parent().remove_child(vehicle)
			vehicle.queue_free()
	_alive.clear()


static func _prune() -> void:
	_alive = _alive.filter(func(v) -> bool: return is_instance_valid(v) and v.is_inside_tree())


static func _enforce_limit() -> void:
	var guard := 0
	while _alive.size() > maxi(max_alive, 1) and guard < 32:
		guard += 1
		var victim = null
		for vehicle in _alive:
			if vehicle.driver == null:
				victim = vehicle
				break
		if victim == null:
			return
		_alive.erase(victim)
		victim.get_parent().remove_child(victim)
		victim.queue_free()
