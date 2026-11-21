class_name VrPickup
extends VrGrabbable

const VrGrabbable = preload("res://core/vr/vr_grabbable.gd")

signal pickup_used(item_data: Dictionary)

const INTERACTION_RADIUS: float = 0.25
const AUTO_GRAB_RADIUS: float = 0.15

@export var item_id: String = ""
@export var item_name: String = "Item"
@export var item_description: String = ""
@export var max_stack: int = 1
@export var current_stack: int = 1
@export var use_on_grip: bool = false
@export var use_on_trigger: bool = true
@export var consume_on_use: bool = false
@export var auto_grab: bool = false
@export var highlight_when_near: bool = true
@export var highlight_material: Material = null
@export var original_material: Material = null

var _near_hand: Variant = null
var _highlighted: bool = false
var _original_materials: Array[Material] = []

func _ready() -> void:
	super._ready()
	
	if item_id.is_empty():
		item_id = "pickup_" + str(get_instance_id())
	
	if highlight_when_near and highlight_material != null:
		_cache_original_materials()

func _cache_original_materials() -> void:
	_original_materials.clear()
	for mesh in find_children("*", "MeshInstance3D", true, false):
		if (mesh as MeshInstance3D).mesh != null:
			var surf_count := (mesh as MeshInstance3D).mesh.get_surface_count()
			for i in range(surf_count):
				var mat := (mesh as MeshInstance3D).get_surface_override_material(i)
				if mat == null:
					mat = (mesh as MeshInstance3D).mesh.surface_get_material(i)
				_original_materials.append(mat)

func _physics_process(delta: float) -> void:
	if auto_grab and not _is_grabbed:
		_check_auto_grab()

func _check_auto_grab() -> void:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return
	
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = AUTO_GRAB_RADIUS
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = 1
	
	var results := space.intersect_shape(query, 5)
	for result in results:
		var collider: Node3D = result["collider"] as Node3D
		if collider is Object and collider.has_method("can_grab") and collider.can_grab(self):
			collider.try_grab(self)
			break

func _get_trigger_value(hand: Variant) -> float:
	if hand == null:
		return 0.0
	if hand is Dictionary and hand.has("get_trigger_value"):
		return hand["get_trigger_value"].call()
	if hand is Object and hand.has_method("get_trigger_value"):
		return hand.get_trigger_value()
	return 0.0

func _get_hand_name(hand: Variant) -> String:
	if hand == null:
		return ""
	if hand is Dictionary and hand.has("get_hand_name"):
		return hand["get_hand_name"].call()
	if hand is Object and hand.has_method("get_hand_name"):
		return hand.get_hand_name()
	return ""

func on_grabbed(hand: Variant, hand_name: String, grab_transform: Transform3D) -> void:
	super.on_grabbed(hand, hand_name, grab_transform)
	_set_highlight(false)

func on_released(hand: Variant, hand_name: String, velocity: Vector3) -> void:
	super.on_released(hand, hand_name, velocity)
	
	if use_on_trigger and _get_trigger_value(hand) > 0.5:
		_use_item(hand)

func _use_item(hand: Variant) -> void:
	var data := {
		"item_id": item_id,
		"item_name": item_name,
		"stack": current_stack,
		"hand": _get_hand_name(hand),
		"position": global_position,
		"velocity": linear_velocity,
	}
	print("[DEBUG VrPickup] _use_item called, emitting pickup_used with data:", data)
	var connections = pickup_used.get_connections()
	print("[DEBUG VrPickup] signal connections:", connections)
	for conn in connections:
		print("[DEBUG VrPickup] calling callable manually:", conn.callable)
		conn.callable.call(data)
	print("[DEBUG VrPickup] after manual calls")
	pickup_used.emit(data)
	print("[DEBUG VrPickup] after emit")
	
	if consume_on_use:
		current_stack -= 1
		if current_stack <= 0:
			queue_free()

func on_hand_collision(hand: Object, position: Vector3, normal: Vector3) -> void:
	super.on_hand_collision(hand, position, normal)
	
	if not _highlighted and highlight_when_near:
		_near_hand = hand
		_set_highlight(true)

func _set_highlight(enabled: bool) -> void:
	if not highlight_when_near or highlight_material == null:
		return
	
	_highlighted = enabled
	
	var meshes := find_children("*", "MeshInstance3D", true, false)
	var idx := 0
	for mesh in meshes:
		if (mesh as MeshInstance3D).mesh == null:
			continue
		var surf_count := (mesh as MeshInstance3D).mesh.get_surface_count()
		for i in range(surf_count):
			if enabled:
				(mesh as MeshInstance3D).set_surface_override_material(i, highlight_material)
			else:
				if idx < _original_materials.size():
					(mesh as MeshInstance3D).set_surface_override_material(i, _original_materials[idx])
				idx += 1

func get_item_data() -> Dictionary:
	return {
		"id": item_id,
		"name": item_name,
		"description": item_description,
		"max_stack": max_stack,
		"current_stack": current_stack,
	}

func set_stack(count: int) -> void:
	current_stack = clampi(count, 0, max_stack)
	if current_stack <= 0:
		queue_free()

func add_to_stack(amount: int) -> int:
	var available_space: int = max_stack - current_stack
	var added: int = min(amount, available_space)
	current_stack += added
	return added

func can_stack_with(other: VrPickup) -> bool:
	return other != null and other.item_id == item_id and current_stack < max_stack

func merge_stack(other: VrPickup) -> bool:
	if not can_stack_with(other):
		return false
	var added := add_to_stack(other.current_stack)
	other.current_stack -= added
	if other.current_stack <= 0:
		other.queue_free()
	return true