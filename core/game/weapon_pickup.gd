class_name WeaponPickup
extends Node3D

# Adapted from GodotFPS-Template (https://github.com/bukkbeek/GodotFPS-Template)
# Original: common/utils/ammo_refil.gd, common/weapon/weapon.gd
# Adapted from Godot-FPS-Template (https://github.com/AxelReviron/Godot-FPS-Template)
# Original: objects/weapon_interaction_component.gd
# License: MIT (c) 2026 bukkbeek, 2026 Axel Reviron - see third_party/GODOTFPS_TEMPLATE_LICENSE.txt, third_party/GODOT_FPS_TEMPLATE_LICENSE.txt

const AmmoSystemScript = preload("res://core/game/ammo_system.gd")
const WeaponDbScript = preload("res://core/game/weapon_db.gd")
const InventoryScript = preload("res://core/game/inventory.gd")

signal picked_up(pickup_data: Dictionary)
signal player_entered(body: Node3D)
signal player_exited(body: Node3D)

@export var pickup_type: String = "weapon"
@export var weapon_id: String = ""
@export var ammo_type: String = ""
@export var current_ammo: int = 0
@export var max_ammo: int = 0
@export var reserve_ammo: int = 0
@export var is_loaded: bool = true
@export var pickup_model: PackedScene = null
@export var rotation_speed: float = 45.0
@export var bob_height: float = 0.05
@export var bob_speed: float = 2.0
@export var pickup_sound: AudioStream = null
@export var pickup_particles: PackedScene = null
@export var despawn_time: float = 300.0
@export var auto_pickup: bool = true
@export var require_interact: bool = false

var _body: Node3D = null
var _collision: Area3D = null
var _model_instance: Node3D = null
var _start_y: float = 0.0
var _time: float = 0.0
var _despawn_timer: float = 0.0
var _player_in_range: bool = false
var _player_body: Node3D = null
var _pickup_data: Dictionary = {}
var _initialized: bool = false

func _ready() -> void:
	_setup_pickup()

func _process(delta: float) -> void:
	if not _initialized:
		return
	_time += delta
	_animate_model(delta)
	_update_despawn_timer(delta)

func _setup_pickup() -> void:
	_body = Node3D.new()
	_body.name = "PickupBody"
	add_child(_body)

	_collision = Area3D.new()
	_collision.name = "PickupArea"
	_collision.monitoring = true
	_collision.monitorable = true
	_collision.collision_layer = 0
	_collision.collision_mask = 2
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.5
	collision_shape.shape = sphere_shape
	_collision.add_child(collision_shape)
	_collision.body_entered.connect(_on_body_entered.bind())
	_collision.body_exited.connect(_on_body_exited.bind())
	_collision.area_entered.connect(_on_area_entered.bind())
	_body.add_child(_collision)

	if pickup_model:
		_model_instance = pickup_model.instantiate()
		_model_instance.name = "PickupModel"
		_body.add_child(_model_instance)
	else:
		_create_default_model()

	_start_y = _body.position.y
	_build_pickup_data()
	_initialized = true

func _create_default_model() -> void:
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.3, 0.1, 0.5)
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.6, 0.2) if pickup_type == "ammo_box" else Color(0.3, 0.5, 0.8)
	mesh_instance.material_override = material
	
	mesh_instance.name = "DefaultModel"
	_body.add_child(mesh_instance)
	_model_instance = mesh_instance

func _build_pickup_data() -> void:
	var ammo_system = AmmoSystemScript.get_singleton()

	if pickup_type == "weapon":
		var info := weapon_info(weapon_id)

		var resolved_ammo_type = ammo_type
		if resolved_ammo_type.is_empty():
			resolved_ammo_type = str(info.ammo_type)

		var ammo_data = ammo_system.get_ammo_data(resolved_ammo_type)

		_pickup_data = {
			"type": "weapon",
			"weapon_id": weapon_id,
			"weapon_name": info.display_name,
			"ammo_type": resolved_ammo_type,
			"caliber": ammo_data.get("caliber", resolved_ammo_type),
			"caliber_name": ammo_system.get_caliber_name(resolved_ammo_type),
			"current_ammo": current_ammo if current_ammo > 0 else int(info.magazine_size),
			"max_ammo": max_ammo if max_ammo > 0 else int(info.magazine_size),
			"reserve_ammo": reserve_ammo,
			"is_loaded": is_loaded,
			"damage": info.damage,
			"fire_rate": info.fire_rate,
			"weight": info.weight_kg,
			"value": info.price
		}
	elif pickup_type == "ammo_box":
		var box_data = ammo_system.create_ammo_box_pickup_data(weapon_id)
		_pickup_data = box_data
		_pickup_data["type"] = "ammo_box"
	else:
		_pickup_data = {
			"type": pickup_type,
			"item_id": weapon_id
		}

func _animate_model(delta: float) -> void:
	if not _model_instance:
		return
	
	var rot_y = deg_to_rad(rotation_speed * _time)
	_model_instance.rotation = Vector3(0, rot_y, 0)
	
	var bob = sin(_time * bob_speed) * bob_height
	_model_instance.position = Vector3(0, _start_y + bob, 0)

func _update_despawn_timer(delta: float) -> void:
	if despawn_time <= 0:
		return
	_despawn_timer += delta
	if _despawn_timer >= despawn_time:
		_despawn()

func _despawn() -> void:
	if pickup_particles:
		var particles = pickup_particles.instantiate()
		particles.global_position = global_position
		get_tree().root.add_child(particles)
	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_in_range = true
	_player_body = body
	player_entered.emit(body)
	if auto_pickup and not require_interact:
		_try_pickup(body)

func _on_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_in_range = false
	if _player_body == body:
		_player_body = null
	player_exited.emit(body)

func _on_area_entered(area: Area3D) -> void:
	if area.get_class() == "RayCast3D" or area.has_method("is_player_interactor"):
		_try_pickup(area.get_parent())

func _try_pickup(player: Node) -> void:
	var player_node := player as Node3D
	if player_node == null or not _is_player(player_node):
		return

	var inventory = _get_player_inventory(player_node)
	if not inventory:
		return

	var can_pickup = false
	var reason = ""

	if _pickup_data.type == "weapon":
		can_pickup = true
	elif _pickup_data.type == "ammo_box":
		var ammo_type = _pickup_data.ammo_type
		var ammo_system = AmmoSystemScript.get_singleton()
		var current_reserve = ammo_system.get_reserve(ammo_type)
		var max_reserve = ammo_system.get_max_reserve(ammo_type)
		if current_reserve >= max_reserve:
			can_pickup = false
			reason = "Ammo reserve full"
		else:
			can_pickup = true

	if can_pickup:
		_perform_pickup(player_node, inventory)
	else:
		_show_pickup_failed(reason)

func _perform_pickup(player: Node3D, inventory) -> void:
	picked_up.emit(_pickup_data)
	
	if pickup_sound:
		var audio = AudioStreamPlayer3D.new()
		audio.stream = pickup_sound
		audio.global_position = global_position
		get_tree().root.add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free.bind())
	
	if pickup_particles:
		var particles = pickup_particles.instantiate()
		particles.global_position = global_position
		get_tree().root.add_child(particles)
	
	queue_free()

func _show_pickup_failed(reason: String) -> void:
	print("Pickup failed: ", reason)

func _is_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.has_method("is_player") or body.name == "Player"

func _get_player_inventory(player: Node3D):
	if player.has_method("get_inventory"):
		return player.get_inventory()
	var inventory_node = player.get_node_or_null("Inventory")
	if inventory_node and inventory_node.has_method("get_inventory"):
		return inventory_node.get_inventory()
	return null

func get_pickup_data() -> Dictionary:
	return _pickup_data.duplicate(true)

func set_weapon_data(weapon_id: String, p_ammo_type: String = "", p_current_ammo: int = 0, p_reserve_ammo: int = 0) -> void:
	self.weapon_id = weapon_id
	self.ammo_type = p_ammo_type
	self.current_ammo = p_current_ammo
	self.reserve_ammo = p_reserve_ammo
	if _initialized:
		_build_pickup_data()

func set_ammo_box(box_id: String) -> void:
	self.pickup_type = "ammo_box"
	self.weapon_id = box_id
	if _initialized:
		_build_pickup_data()

const WEAPON_DEFAULT_PRICES := {
	"pistol": 350,
	"submachine_gun": 750,
	"assault_rifle": 1800,
	"shotgun": 900,
	"sniper_rifle": 2600,
	"bat": 50,
}

static func weapon_info(weapon_id: String) -> Dictionary:
	var AmmoSystemScript = preload("res://core/game/ammo_system.gd")
	var WeaponDbScript = preload("res://core/game/weapon_db.gd")
	var ammo_system = AmmoSystemScript.get_singleton()
	var weapon_def: Dictionary = {}
	if WeaponDbScript.has(weapon_id):
		weapon_def = WeaponDbScript.get_def(weapon_id)

	var ammo_type = ammo_system.get_caliber_for_weapon(weapon_id)
	if weapon_def.has("ammo_type"):
		ammo_type = str(weapon_def.get("ammo_type", ""))

	var magazine_size = weapon_def.get("magazine_size", weapon_def.get("mag", 30))
	var price = weapon_def.get("price", WEAPON_DEFAULT_PRICES.get(weapon_id, 500))

	return {
		"id": weapon_id,
		"display_name": str(weapon_def.get("display_name", weapon_def.get("name", weapon_id))),
		"ammo_type": ammo_type,
		"caliber_name": ammo_system.get_caliber_name(ammo_type),
		"magazine_size": int(magazine_size),
		"damage": float(weapon_def.get("damage", 25.0)),
		"fire_rate": float(weapon_def.get("fire_rate", 600.0)),
		"weight_kg": float(weapon_def.get("weight_kg", weapon_def.get("weight", 3.0))),
		"price": int(price),
		"is_melee": ammo_type.is_empty(),
		"model_path": weapon_model_path(weapon_id),
	}

static func weapon_model_path(weapon_id: String) -> String:
	var WeaponDbScript = preload("res://core/game/weapon_db.gd")
	var weapon_def: Dictionary = {}
	if WeaponDbScript.has(weapon_id):
		weapon_def = WeaponDbScript.get_def(weapon_id)
	var declared := str(weapon_def.get("model_path", ""))
	if not declared.is_empty() and ResourceLoader.exists(declared):
		return declared
	for path in ["res://assets/models/weapons/%s.glb" % weapon_id, "res://assets/models/weapons/%s/model.gltf" % weapon_id]:
		if ResourceLoader.exists(path):
			return path
	return ""

static func spawn_weapon_pickup(position: Vector3, weapon_id: String, ammo_type: String = "", current_ammo: int = 0, reserve_ammo: int = 0, model: PackedScene = null):
	var WeaponPickupScript = preload("res://core/game/weapon_pickup.gd")
	var pickup_node = WeaponPickupScript.new()
	pickup_node.pickup_type = "weapon"
	pickup_node.weapon_id = weapon_id
	pickup_node.ammo_type = ammo_type
	pickup_node.current_ammo = current_ammo
	pickup_node.reserve_ammo = reserve_ammo
	if model:
		pickup_node.pickup_model = model
	pickup_node.position = position
	return pickup_node

static func spawn_ammo_box_pickup(position: Vector3, box_id: String, model: PackedScene = null):
	var WeaponPickupScript = preload("res://core/game/weapon_pickup.gd")
	var pickup_node = WeaponPickupScript.new()
	pickup_node.pickup_type = "ammo_box"
	pickup_node.weapon_id = box_id
	if model:
		pickup_node.pickup_model = model
	pickup_node.position = position
	return pickup_node