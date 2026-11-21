class_name VrInteractableSlider
extends VrInteractable

signal value_changed(value: float)
signal limit_reached(limit: String)

const DEFAULT_MIN_VALUE: float = 0.0
const DEFAULT_MAX_VALUE: float = 1.0
const DEFAULT_SPRING: float = 0.0
const DEFAULT_DAMPING: float = 0.1
const DEFAULT_MAX_FORCE: float = 100.0

@export var min_value: float = DEFAULT_MIN_VALUE
@export var max_value: float = DEFAULT_MAX_VALUE
@export var spring: float = DEFAULT_SPRING
@export var damping: float = DEFAULT_DAMPING
@export var max_force: float = DEFAULT_MAX_FORCE
@export var axis: Vector3 = Vector3.BACK
@export var invert: bool = false
@export var use_limits: bool = true
@export var snap_to_limits: bool = false
@export var snap_threshold: float = 0.05
@export var steps: int = 0

var current_value: float = 0.0
var target_value: float = 0.0
var _velocity: float = 0.0
var _initial_value: float = 0.0
var _initial_hand_position: float = 0.0
var _slider_axis: Vector3 = Vector3.FORWARD
var _slider_length: float = 1.0

func _ready() -> void:
	super._ready()
	_setup_slider()
	_initial_value = current_value
	_slider_axis = axis.normalized()
	_slider_length = maxf(max_value - min_value, 0.001)

func _setup_slider() -> void:
	var slider_node: Node3D = find_child("*Slider*") as Node3D
	if slider_node == null:
		for child in get_children():
			if child is Node3D and child.name.to_lower().contains("slider"):
				slider_node = child
				break
	if slider_node != null:
		var aabb: AABB = _get_node_aabb(slider_node)
		_slider_length = maxf(aabb.size.dot(_slider_axis), 0.001)

func start_interaction(actor: Node3D, hand: String = "right", interaction_type: String = "grab") -> bool:
	if not super.start_interaction(actor, hand, interaction_type):
		return false
	_initial_hand_position = _get_hand_position_along_axis()
	_initial_value = current_value
	return true

func _update_interaction(delta: float) -> void:
	var hand_pos: float = _get_hand_position_along_axis()
	var delta_pos: float = hand_pos - _initial_hand_position
	if invert:
		delta_pos = -delta_pos
	
	var new_target: float = _initial_value + delta_pos / maxf(_slider_length, 0.001) * (max_value - min_value)
	
	if use_limits:
		new_target = clampf(new_target, min_value, max_value)
		if snap_to_limits:
			if absf(new_target - min_value) < snap_threshold:
				new_target = min_value
				limit_reached.emit("min")
			elif absf(new_target - max_value) < snap_threshold:
				new_target = max_value
				limit_reached.emit("max")
	
	target_value = new_target
	
	if spring > 0.0:
		var spring_force: float = (target_value - current_value) * spring
		var damping_force: float = -_velocity * damping
		var total_force: float = clampf(spring_force + damping_force, -max_force, max_force)
		_velocity += total_force * delta
		_velocity *= 1.0 - damping * delta
		current_value += _velocity * delta
	else:
		current_value = target_value
	
	if use_limits:
		current_value = clampf(current_value, min_value, max_value)
	
	if steps > 1:
		var step_size: float = (max_value - min_value) / (steps - 1)
		current_value = round((current_value - min_value) / step_size) * step_size + min_value
		current_value = clampf(current_value, min_value, max_value)
	
	_apply_position()
	value_changed.emit(current_value)

func _get_hand_position_along_axis() -> float:
	var hand_pose: Transform3D = _get_hand_pose()
	return hand_pose.origin.dot(_slider_axis)

func _apply_position() -> void:
	var slider_node: Node3D = find_child("*Slider*") as Node3D
	if slider_node == null:
		for child in get_children():
			if child is Node3D and child.name.to_lower().contains("slider"):
				slider_node = child
				break
	if slider_node != null:
		var t: float = (current_value - min_value) / maxf(max_value - min_value, 0.001)
		var local_pos: Vector3 = _slider_axis * (t * _slider_length)
		slider_node.position = local_pos

func end_interaction() -> void:
	if is_interacting:
		super.end_interaction()
		if spring > 0.0:
			_velocity = 0.0

func force_release() -> void:
	end_interaction()

func set_value(value: float) -> void:
	current_value = clampf(value, min_value, max_value) if use_limits else value
	target_value = current_value
	_apply_position()
	value_changed.emit(current_value)

func get_value() -> float:
	return current_value

func get_normalized_value() -> float:
	if max_value == min_value:
		return 0.0
	return (current_value - min_value) / (max_value - min_value)

func is_at_min_limit() -> bool:
	return use_limits and absf(current_value - min_value) < 0.001

func is_at_max_limit() -> bool:
	return use_limits and absf(current_value - max_value) < 0.001

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