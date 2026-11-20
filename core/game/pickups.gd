class_name PickupManager
extends Node

const ItemDbScript = preload("res://core/game/item_db.gd")
const InventoryScript = preload("res://core/game/inventory.gd")
const GameWorldScript = preload("res://core/game/game_world.gd")

signal crate_collected(position: Vector3)
signal ammo_picked(ammo_type: String, amount: int)
signal health_picked(amount: float)
signal armor_picked(amount: float)
signal weapon_picked(weapon_id: String)

var world: Node3D = null
var player: Node3D = null
var _seed: int = 0
var _pickups: Array = []
var _crate_scenes: Array = []
var _max_pickups: int = 50
var _pickup_lifetime: float = 120.0
var _cleanup_timer: float = 0.0

func setup(p_world: Node3D, p_player: Node3D, p_seed: int) -> void:
	world = p_world
	player = p_player
	_seed = p_seed
	_load_crate_scenes()

func _load_crate_scenes() -> void:
	_crate_scenes = []
	var crate_paths = [
		"res://assets/models/props/ammo_box/model.gltf",
		"res://assets/models/props/wooden_crate_02/model.gltf",
		"res://assets/models/props/plastic_crate_02/model.gltf",
	]
	for path in crate_paths:
		if ResourceLoader.exists(path):
			var scene = load(path)
			if scene:
				_crate_scenes.append(scene)

func tick(delta: float) -> void:
	_cleanup_timer += delta
	if _cleanup_timer >= 5.0:
		_cleanup_timer = 0.0
		_cleanup_expired_pickups()
	
	for pickup in _pickups:
		if pickup and is_instance_valid(pickup) and pickup.has_method("tick"):
			pickup.call("tick", delta)

func spawn_supply_crates(wave: int, spawn_points: Array) -> void:
	if _crate_scenes.is_empty() or spawn_points.is_empty():
		return
	
	var crate_count = clampi(1 + wave / 3, 1, 5)
	var rng = RandomNumberGenerator.new()
	rng.seed = _seed + wave * 1337
	
	var points = spawn_points.duplicate()
	points.shuffle()
	
	for i in range(min(crate_count, points.size())):
		var pos = points[i]
		var crate_type = rng.randi_range(0, _crate_scenes.size() - 1)
		_spawn_crate(pos, crate_type, wave)

func _spawn_crate(position: Vector3, crate_type: int, wave: int) -> void:
	var scene = _crate_scenes[crate_type]
	var instance = scene.instantiate()
	if not instance:
		return
	
	instance.name = "SupplyCrate_%d_%d" % [wave, _pickups.size()]
	instance.global_position = position + Vector3.UP * 0.5
	
	if world:
		world.add_child(instance)
	
	var pickup_data = {
		"node": instance,
		"type": "crate",
		"wave": wave,
		"spawn_time": Time.get_ticks_msec() / 1000.0,
		"contents": _generate_crate_contents(wave),
	}
	
	_pickups.append(pickup_data)
	
	if instance.has_method("body_entered"):
		instance.connect("body_entered", Callable(self, "_on_body_entered").bind(instance))

func _generate_crate_contents(wave: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = _seed + wave * 999 + _pickups.size() * 7
	
	var contents = {}
	
	var ammo_types = ["pistol_ammo", "smg_ammo", "rifle_ammo", "shotgun_ammo", "sniper_ammo"]
	var ammo_type = ammo_types[rng.randi_range(0, ammo_types.size() - 1)]
	contents["ammo"] = {
		"type": ammo_type,
		"amount": rng.randi_range(12, 30) + wave * 2,
	}
	
	if rng.randf() < 0.4:
		contents["health"] = rng.randi_range(25, 50)
	
	if rng.randf() < 0.2:
		contents["armor"] = rng.randi_range(15, 35)
	
	if rng.randf() < 0.15:
		var weapons = ["pistol", "submachine_gun", "shotgun"]
		contents["weapon"] = weapons[rng.randi_range(0, weapons.size() - 1)]
	
	return contents

func spawn_ammo_pickup(position: Vector3, ammo_type: String, amount: int) -> void:
	_spawn_generic_pickup(position, "ammo", {"type": ammo_type, "amount": amount})

func spawn_health_pickup(position: Vector3, amount: float) -> void:
	_spawn_generic_pickup(position, "health", {"amount": amount})

func spawn_armor_pickup(position: Vector3, amount: float) -> void:
	_spawn_generic_pickup(position, "armor", {"amount": amount})

func spawn_weapon_pickup(position: Vector3, weapon_id: String) -> void:
	_spawn_generic_pickup(position, "weapon", {"weapon_id": weapon_id})

func _spawn_generic_pickup(position: Vector3, pickup_type: String, data: Dictionary) -> void:
	if _pickups.size() >= _max_pickups:
		_cleanup_oldest_pickup()
	
	var pickup_data = {
		"node": null,
		"type": pickup_type,
		"data": data,
		"spawn_time": Time.get_ticks_msec() / 1000.0,
	}
	
	_pickups.append(pickup_data)

func _on_body_entered(body: Node3D, crate: Node3D) -> void:
	if body != player:
		return
	
	var pickup_data = _find_pickup_by_node(crate)
	if not pickup_data:
		return
	
	if pickup_data["type"] == "crate":
		_collect_crate(pickup_data)

func _collect_crate(pickup_data: Dictionary) -> void:
	var contents = pickup_data.get("contents", {})
	
	if contents.has("ammo"):
		var ammo = contents["ammo"]
		ammo_picked.emit(ammo["type"], ammo["amount"])
		_give_ammo_to_player(ammo["type"], ammo["amount"])
	
	if contents.has("health"):
		health_picked.emit(contents["health"])
		_give_health_to_player(contents["health"])
	
	if contents.has("armor"):
		armor_picked.emit(contents["armor"])
		_give_armor_to_player(contents["armor"])
	
	if contents.has("weapon"):
		weapon_picked.emit(contents["weapon"])
		_give_weapon_to_player(contents["weapon"])
	
	crate_collected.emit(pickup_data["node"].global_position)
	
	if pickup_data["node"] and is_instance_valid(pickup_data["node"]):
		pickup_data["node"].queue_free()
	
	_pickups.erase(pickup_data)

func _find_pickup_by_node(node: Node3D) -> Dictionary:
	for pickup in _pickups:
		if pickup["node"] == node:
			return pickup
	return {}

func _cleanup_expired_pickups() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var to_remove = []
	
	for pickup in _pickups:
		if pickup["node"] and not is_instance_valid(pickup["node"]):
			to_remove.append(pickup)
		elif current_time - pickup["spawn_time"] > _pickup_lifetime:
			if pickup["node"] and is_instance_valid(pickup["node"]):
				pickup["node"].queue_free()
			to_remove.append(pickup)
	
	for pickup in to_remove:
		_pickups.erase(pickup)

func _cleanup_oldest_pickup() -> void:
	if _pickups.is_empty():
		return
	var oldest = _pickups[0]
	if oldest["node"] and is_instance_valid(oldest["node"]):
		oldest["node"].queue_free()
	_pickups.remove_at(0)

func _give_ammo_to_player(ammo_type: String, amount: int) -> void:
	if not player:
		return
	var inventory = player.get("inventory")
	if inventory and inventory.has_method("add"):
		inventory.call("add", ammo_type, amount)

func _give_health_to_player(amount: float) -> void:
	if not player:
		return
	if player.has_method("heal"):
		player.call("heal", amount)
	elif player.has_method("health"):
		var current = float(player.get("health"))
		var max_hp = float(player.get("max_health", 100.0))
		player.set("health", min(current + amount, max_hp))

func _give_armor_to_player(amount: float) -> void:
	if not player:
		return
	if player.has_method("add_armor"):
		player.call("add_armor", amount)
	elif player.has_method("armor"):
		var current = float(player.get("armor"))
		var max_armor = float(player.get("max_armor", 100.0))
		player.set("armor", min(current + amount, max_armor))

func _give_weapon_to_player(weapon_id: String) -> void:
	if not player:
		return
	var inventory = player.get("inventory")
	if inventory and inventory.has_method("add"):
		inventory.call("add", weapon_id, 1)
	if player.has_method("equip"):
		player.call("equip", weapon_id)

func get_active_pickups() -> Array:
	var result = []
	for pickup in _pickups:
		if pickup["node"] and is_instance_valid(pickup["node"]):
			result.append({
				"type": pickup["type"],
				"position": pickup["node"].global_position,
				"age": Time.get_ticks_msec() / 1000.0 - pickup["spawn_time"],
			})
	return result

func clear_all() -> void:
	for pickup in _pickups:
		if pickup["node"] and is_instance_valid(pickup["node"]):
			pickup["node"].queue_free()
	_pickups.clear()