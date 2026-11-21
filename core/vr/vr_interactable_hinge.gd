class_name VrInteractableHinge
extends VrInteractable

signal angle_changed(angle: float)
signal limit_reached(limit: String)

const DEFAULT_MIN_ANGLE: float = -1.57
const DEFAULT_MAX_ANGLE: float = 1.57
const DEFAULT_SPRING: float = 0.0
const DEFAULT_DAMPING: float = 0.1
const DEFAULT_MAX_FORCE: float = 100.0

@export var min_angle: float = DEFAULT_MIN_ANGLE
@export var max_angle: float = DEFAULT_MAX_ANGLE
@export var spring: float = DEFAULT_SPRING
@export var damping: float = DEFAULT_DAMPING
@export var max_force: float = DEFAULT_MAX_FORCE
@export var axis: Vector3 = Vector3.UP
@export var invert: bool = false
@export var use_limits: bool = true
@export var snap_to_limits: bool = false
@export var snap_threshold: float = 0.1

var current_angle: float = 0.0
var target_angle: float = 0.0
var _angular_velocity: float = 0.0
var _initial_angle: float = 0.0
var _initial_hand_rotation: float = 0.0
var _pivot: Node3D = null
var _hinge_axis: Vector3 = Vector3.UP

func _ready() -> void:
	super._ready()
	_setup_pivot()
	_initial_angle = current_angle
	_hinge_axis = axis.normalized()

func _setup_pivot() -> void:
	_pivot = find_child("*Pivot*") as Node3D
	if _pivot == null:
		_pivot = find_child("*Hinge*") as Node3D
	if _pivot == null:
		for child in get_children():
			if child is Node3D and (child.name.to_lower().contains("pivot") or child.name.to_lower().contains("hinge")):
				_pivot = child
				break
	if _pivot == null:
		_pivot = Node3D.new()
		_pivot.name = "HingePivot"
		_pivot.position = global_position
		add_child(_pivot)
		for child in get_children():
			if child != _pivot and child is Node3D:
				child.reparent(_pivot)

func start_interaction(actor: Node3D, hand: String = "right", interaction_type: String = "grab") -> bool:
	if not super.start_interaction(actor, hand, interaction_type):
		return false
	_initial_hand_rotation = _get_hand_rotation_around_axis()
	_initial_angle = current_angle
	return true

func _update_interaction(delta: float) -> void:
	var hand_rotation: float = _get_hand_rotation_around_axis()
	var delta_rotation: float = hand_rotation - _initial_hand_rotation
	if invert:
		delta_rotation = -delta_rotation
	
	var new_target: float = _initial_angle + delta_rotation
	
	if use_limits:
		new_target = clampf(new_target, min_angle, max_angle)
		if snap_to_limits:
			if absf(new_target - min_angle) < snap_threshold:
				new_target = min_angle
				limit_reached.emit("min")
			elif absf(new_target - max_angle) < snap_threshold:
				new_target = max_angle
				limit_reached.emit("max")
	
	target_angle = new_target
	
	if spring > 0.0:
		var spring_force: float = (target_angle - current_angle) * spring
		var damping_force: float = -_angular_velocity * damping
		var total_force: float = clampf(spring_force + damping_force, -max_force, max_force)
		_angular_velocity += total_force * delta
		_angular_velocity *= 1.0 - damping * delta
		current_angle += _angular_velocity * delta
	else:
		current_angle = target_angle
	
	if use_limits:
		current_angle = clampf(current_angle, min_angle, max_angle)
	
	_apply_rotation()
	angle_changed.emit(current_angle)

func _get_hand_rotation_around_axis() -> float:
	var hand_pose: Transform3D = _get_hand_pose()
	var hand_forward: Vector3 = -hand_pose.basis.z
	var hand_up: Vector3 = hand_pose.basis.y
	
	var axis_proj: Vector3 = _hinge_axis
	var forward_proj: Vector3 = hand_forward - _hinge_axis * hand_forward.dot(_hinge_axis)
	var up_proj: Vector3 = hand_up - _hinge_axis * hand_up.dot(_hinge_axis)
	
	if forward_proj.length_squared() < 0.0001:
		forward_proj = up_proj
	if forward_proj.length_squared() < 0.0001:
		return 0.0
	
	forward_proj = forward_proj.normalized()
	var reference: Vector3 = _hinge_axis.cross(forward_proj).normalized()
	
	return atan2(hand_forward.dot(reference), hand_forward.dot(forward_proj))

func _apply_rotation() -> void:
	if _pivot == null:
		return
	var rotation: Basis = Basis(_hinge_axis, current_angle)
	_pivot.rotation = rotation.get_euler()

func end_interaction() -> void:
	if is_interacting:
		super.end_interaction()
		if spring > 0.0:
			_angular_velocity = 0.0

func force_release() -> void:
	end_interaction()

func set_angle(angle: float) -> void:
	current_angle = clampf(angle, min_angle, max_angle) if use_limits else angle
	target_angle = current_angle
	_apply_rotation()
	angle_changed.emit(current_angle)

func get_angle() -> float:
	return current_angle

func is_at_min_limit() -> bool:
	return use_limits and absf(current_angle - min_angle) < 0.01

func is_at_max_limit() -> bool:
	return use_limits and absf(current_angle - max_angle) < 0.01