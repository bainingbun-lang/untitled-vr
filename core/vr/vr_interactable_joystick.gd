class_name VrInteractableJoystick
extends VrInteractable

signal value_changed(value: Vector2)
signal limit_reached(axis: String, limit: String)

const DEFAULT_MAX_ANGLE: float = 0.5
const DEFAULT_SPRING: float = 10.0
const DEFAULT_DAMPING: float = 0.5
const DEFAULT_MAX_FORCE: float = 50.0
const DEFAULT_DEADZONE: float = 0.05
const DEFAULT_INVERT_X: bool = false
const DEFAULT_INVERT_Y: bool = false

@export var max_angle: float = DEFAULT_MAX_ANGLE
@export var spring: float = DEFAULT_SPRING
@export var damping: float = DEFAULT_DAMPING
@export var max_force: float = DEFAULT_MAX_FORCE
@export var deadzone: float = DEFAULT_DEADZONE
@export var invert_x: bool = DEFAULT_INVERT_X
@export var invert_y: bool = DEFAULT_INVERT_Y
@export var return_to_center: bool = true
@export var clamp_to_circle: bool = true

var current_value: Vector2 = Vector2.ZERO
var target_value: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _initial_value: Vector2 = Vector2.ZERO
var _initial_hand_pos: Vector2 = Vector2.ZERO
var _center_pos: Vector3 = Vector3.ZERO
var _stick_node: Node3D = null
var _stick_length: float = 0.3
var _base_rotation: Basis = Basis.IDENTITY

func _ready() -> void:
	super._ready()
	_setup_joystick()
	_center_pos = global_position
	_base_rotation = global_transform.basis

func _setup_joystick() -> void:
	_stick_node = find_child("*Stick*") as Node3D
	if _stick_node == null:
		_stick_node = find_child("*Joystick*") as Node3D
	if _stick_node == null:
		for child in get_children():
			if child is Node3D and (child.name.to_lower().contains("stick") or child.name.to_lower().contains("joystick")):
				_stick_node = child
				break
	if _stick_node != null:
		var aabb: AABB = _get_node_aabb(_stick_node)
		_stick_length = maxf(maxf(maxf(aabb.size.y, aabb.size.x), aabb.size.z), 0.3)

func start_interaction(actor: Node3D, hand: String = "right", interaction_type: String = "grab") -> bool:
	if not super.start_interaction(actor, hand, interaction_type):
		return false
	_initial_hand_pos = _get_hand_relative_position()
	_initial_value = current_value
	return true

func _update_interaction(delta: float) -> void:
	var hand_pos: Vector2 = _get_hand_relative_position()
	var delta_pos: Vector2 = hand_pos - _initial_hand_pos
	
	var new_target: Vector2 = _initial_value + delta_pos / _stick_length
	
	if clamp_to_circle:
		if new_target.length() > 1.0:
			new_target = new_target.normalized()
	
	if invert_x:
		new_target.x = -new_target.x
	if invert_y:
		new_target.y = -new_target.y
	
	target_value = new_target
	
	var spring_force: Vector2 = (target_value - current_value) * spring
	var damping_force: Vector2 = -_velocity * damping
	var total_force: Vector2 = Vector2(
		clampf(spring_force.x + damping_force.x, -max_force, max_force),
		clampf(spring_force.y + damping_force.y, -max_force, max_force)
	)
	_velocity += total_force * delta
	_velocity *= Vector2(1.0, 1.0) - Vector2(damping, damping) * delta
	current_value += _velocity * delta
	
	if clamp_to_circle and current_value.length() > 1.0:
		current_value = current_value.normalized()
	
	if deadzone > 0.0:
		if current_value.length() < deadzone:
			current_value = Vector2.ZERO
	
	_check_limits()
	_apply_rotation()
	value_changed.emit(current_value)

func _get_hand_relative_position() -> Vector2:
	var hand_pose: Transform3D = _get_hand_pose()
	var relative: Vector3 = global_transform.basis.inverse() * (hand_pose.origin - global_position)
	return Vector2(relative.x, -relative.z)

func _check_limits() -> void:
	if current_value.x > 0.95:
		limit_reached.emit("x", "max")
	elif current_value.x < -0.95:
		limit_reached.emit("x", "min")
	if current_value.y > 0.95:
		limit_reached.emit("y", "max")
	elif current_value.y < -0.95:
		limit_reached.emit("y", "min")

func _apply_rotation() -> void:
	if _stick_node == null:
		return
	var angle_x: float = clampf(current_value.y * max_angle, -max_angle, max_angle)
	var angle_z: float = clampf(-current_value.x * max_angle, -max_angle, max_angle)
	_stick_node.rotation = Vector3(angle_x, 0.0, angle_z)

func end_interaction() -> void:
	if is_interacting:
		super.end_interaction()
		if return_to_center and spring > 0.0:
			target_value = Vector2.ZERO

func force_release() -> void:
	end_interaction()

func set_value(value: Vector2) -> void:
	current_value = value
	if clamp_to_circle and current_value.length() > 1.0:
		current_value = current_value.normalized()
	target_value = current_value
	_apply_rotation()
	value_changed.emit(current_value)

func get_value() -> Vector2:
	return current_value

func is_centered() -> bool:
	return current_value.length() < deadzone

func _get_node_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var stack: Array = [{"node": root, "xform": Transform3D.IDENTITY}]
	while not stack.is_empty():
		var entry: Dictionary = stack.pop_back()
		var node: Node = entry["node"]
		var xform: Transform3D = entry["xform"]
		if node is Node3D:
			xform = xform * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var child_box: AABB = xform * (node as MeshInstance3D).mesh.get_aabb()
			result = child_box if not found else result.merge(child_box)
			found = true
		for child in node.get_children():
			stack.append({"node": child, "xform": xform})
	return result