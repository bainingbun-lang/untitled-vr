class_name PickupManager
extends Node

const ItemDbScript = preload("res://core/game/item_db.gd")
const InventoryScript = preload("res://core/game/inventory.gd")
const GameWorldScript = preload("res://core/game/game_world.gd")
const AmmoSystemScript = preload("res://core/game/ammo_system.gd")
const WeaponPickupScript = preload("res://core/game/weapon_pickup.gd")
const WeaponDbScript = preload("res://core/game/weapon_db.gd")

signal crate_collected(position: Vector3)
signal ammo_picked(ammo_type: String, amount: int)
signal health_picked(amount: float)
signal armor_picked(amount: float)
signal weapon_picked(weapon_id: String)
signal ammo_box_picked(box_id: String, ammo_type: String, rounds: int)
signal weapon_dropped(weapon_data: Dictionary)

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
	
	var ammo_system = AmmoSystemScript.get_singleton()
	var ammo_types = ammo_system.get_all_reserves().keys()
	if ammo_types.is_empty():
		ammo_types = ["9mm", "556", "762x39", "12g"]
	var ammo_type = ammo_types[rng.randi_range(0, ammo_types.size() - 1)]
	var box_id = "ammo_box_" + ammo_type + "_medium"
	var box_def = ammo_system.get_box_definition(box_id)
	var box_rounds = int(box_def.get("rounds", 30))
	contents["ammo_box"] = {
		"type": ammo_type,
		"box_id": box_id,
		"rounds": box_rounds,
	}
	
	if rng.randf() < 0.4:
		contents["health"] = rng.randi_range(25, 50)
	
	if rng.randf() < 0.2:
		contents["armor"] = rng.randi_range(15, 35)
	
	if rng.randf() < 0.15:
		var weapons = ["pistol", "submachine_gun", "shotgun", "assault_rifle"]
		contents["weapon"] = weapons[rng.randi_range(0, weapons.size() - 1)]
	
	return contents

func spawn_ammo_pickup(position: Vector3, ammo_type: String, amount: int) -> void:
	var ammo_system = AmmoSystemScript.get_singleton()
	var added = ammo_system.add_reserve(ammo_type, amount)
	if added > 0:
		ammo_picked.emit(ammo_type, added)
		_give_ammo_to_player(ammo_type, added)

func spawn_health_pickup(position: Vector3, amount: float) -> void:
	_spawn_generic_pickup(position, "health", {"amount": amount})

func spawn_armor_pickup(position: Vector3, amount: float) -> void:
	_spawn_generic_pickup(position, "armor", {"amount": amount})

func spawn_weapon_pickup(position: Vector3, weapon_id: String, ammo_type: String = "", current_ammo: int = 0, reserve_ammo: int = 0) -> void:
	var resolved_ammo_type = ammo_type
	if resolved_ammo_type.is_empty():
		resolved_ammo_type = AmmoSystemScript.get_singleton().get_caliber_for_weapon(weapon_id)
	
	var pickup = WeaponPickupScript.spawn_weapon_pickup(position, weapon_id, resolved_ammo_type, current_ammo, reserve_ammo)
	if world:
		world.add_child(pickup)
	pickup.picked_up.connect(_on_weapon_picked_up.bind())
	
	var pickup_data = {
		"node": pickup,
		"type": "weapon_pickup",
		"data": {"weapon_id": weapon_id, "ammo_type": resolved_ammo_type},
		"spawn_time": Time.get_ticks_msec() / 1000.0,
	}
	_pickups.append(pickup_data)

func spawn_ammo_box_pickup(position: Vector3, box_id: String) -> void:
	var ammo_system = AmmoSystemScript.get_singleton()
	var box_def = ammo_system.get_box_definition(box_id)
	if box_def.is_empty():
		return
	
	var pickup = WeaponPickupScript.spawn_ammo_box_pickup(position, box_id)
	if world:
		world.add_child(pickup)
	pickup.picked_up.connect(_on_ammo_box_picked_up.bind())
	
	var pickup_data = {
		"node": pickup,
		"type": "ammo_box_pickup",
		"data": {"box_id": box_id},
		"spawn_time": Time.get_ticks_msec() / 1000.0,
	}
	_pickups.append(pickup_data)

func spawn_weapon_loot(position: Vector3, weapon_id: String, current_ammo: int = 0, reserve_ammo: int = 0, condition: float = 1.0) -> void:
	if not WeaponDbScript.has(weapon_id):
		return

	var ammo_system = AmmoSystemScript.get_singleton()
	var ammo_type = ammo_system.get_caliber_for_weapon(weapon_id)

	var pickup = WeaponPickupScript.spawn_weapon_pickup(position, weapon_id, ammo_type, current_ammo, reserve_ammo)
	pickup.rotation_speed = 20.0
	pickup.bob_height = 0.03
	if world:
		world.add_child(pickup)
	pickup.picked_up.connect(_on_weapon_loot_picked_up.bind())
	
	var pickup_data = {
		"node": pickup,
		"type": "weapon_loot",
		"data": {
			"weapon_id": weapon_id,
			"ammo_type": ammo_type,
			"current_ammo": current_ammo,
			"reserve_ammo": reserve_ammo,
			"condition": condition
		},
		"spawn_time": Time.get_ticks_msec() / 1000.0,
	}
	_pickups.append(pickup_data)
	weapon_dropped.emit(pickup_data["data"])

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
	
	if contents.has("ammo_box"):
		var ammo_box = contents["ammo_box"]
		var ammo_system = AmmoSystemScript.get_singleton()
		var added = ammo_system.add_reserve(ammo_box["type"], ammo_box["rounds"])
		if added > 0:
			ammo_picked.emit(ammo_box["type"], added)
			_give_ammo_to_player(ammo_box["type"], added)
			ammo_box_picked.emit(ammo_box["box_id"], ammo_box["type"], added)
	
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

func _on_weapon_picked_up(pickup_data: Dictionary) -> void:
	var weapon_id = pickup_data.get("weapon_id", "")
	if weapon_id != "":
		weapon_picked.emit(weapon_id)
		_give_weapon_to_player(weapon_id)

func _on_ammo_box_picked_up(pickup_data: Dictionary) -> void:
	var box_id = pickup_data.get("box_id", "")
	var ammo_type = pickup_data.get("ammo_type", "")
	var rounds = pickup_data.get("rounds", 0)
	if box_id != "" and ammo_type != "":
		ammo_box_picked.emit(box_id, ammo_type, rounds)

func _on_weapon_loot_picked_up(pickup_data: Dictionary) -> void:
	var weapon_id = pickup_data.get("weapon_id", "")
	if weapon_id != "":
		weapon_picked.emit(weapon_id)
		_give_weapon_to_player(weapon_id)

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
		var max_hp = 100.0
		if player.has("max_health"):
			max_hp = float(player.get("max_health"))
		player.set("health", min(current + amount, max_hp))

func _give_armor_to_player(amount: float) -> void:
	if not player:
		return
	if player.has_method("add_armor"):
		player.call("add_armor", amount)
	elif player.has_method("armor"):
		var current = float(player.get("armor"))
		var max_armor = 100.0
		if player.has("max_armor"):
			max_armor = float(player.get("max_armor"))
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
				"data": pickup.get("data", {}),
			})
	return result

func clear_all() -> void:
	for pickup in _pickups:
		if pickup["node"] and is_instance_valid(pickup["node"]):
			pickup["node"].queue_free()
	_pickups.clear()

func drop_weapon_on_death(killer_position: Vector3, weapon_id: String, current_ammo: int, reserve_ammo: int) -> void:
	var drop_pos = killer_position + Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5))
	spawn_weapon_loot(drop_pos, weapon_id, current_ammo, reserve_ammo, 0.8)

func spawn_caliber_loot(position: Vector3, caliber: String) -> void:
	var ammo_system = AmmoSystemScript.get_singleton()
	var box_id = "ammo_box_" + caliber + "_medium"
	var box_def = ammo_system.get_box_definition(box_id)
	if box_def.is_empty():
		var ammo_types = ammo_system.get_all_reserves().keys()
		for at in ammo_types:
			var alt_box = "ammo_box_" + at + "_small"
			if ammo_system.get_box_definition(alt_box):
				box_id = alt_box
				break
	spawn_ammo_box_pickup(position, box_id)