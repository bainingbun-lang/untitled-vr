class_name VrInteractableHandle
extends VrInteractable

signal grabbed(hand: String)
signal released(hand: String, velocity: Vector3)
signal rotated(delta_angle: float)
signal moved(delta_position: Vector3)

const DEFAULT_GRAB_RADIUS: float = 0.15
const DEFAULT_MAX_ANGULAR_VELOCITY: float = 10.0
const DEFAULT_MAX_LINEAR_VELOCITY: float = 5.0
const DEFAULT_DAMPING: float = 0.1
const DEFAULT_STIFFNESS: float = 50.0

@export var handle_grab_radius: float = DEFAULT_GRAB_RADIUS
@export var max_angular_velocity: float = DEFAULT_MAX_ANGULAR_VELOCITY
@export var max_linear_velocity: float = DEFAULT_MAX_LINEAR_VELOCITY
@export var damping: float = DEFAULT_DAMPING
@export var stiffness: float = DEFAULT_STIFFNESS
@export var constrain_rotation: bool = true
@export var constrain_position: bool = false
@export var rotation_axis: Vector3 = Vector3.UP
@export var allow_two_handed: bool = true
@export var haptic_on_grab: bool = true
@export var haptic_duration: float = 0.04
@export var haptic_amplitude: float = 0.3

var primary_hand: String = ""
var secondary_hand: String = ""
var primary_grip: float = 0.0
var secondary_grip: float = 0.0
var _primary_pose: Transform3D = Transform3D.IDENTITY
var _secondary_pose: Transform3D = Transform3D.IDENTITY
var _initial_primary_pose: Transform3D = Transform3D.IDENTITY
var _initial_secondary_pose: Transform3D = Transform3D.IDENTITY
var _initial_rotation: Basis = Basis.IDENTITY
var _initial_position: Vector3 = Vector3.ZERO
var _angular_velocity: float = 0.0
var _linear_velocity: Vector3 = Vector3.ZERO
var _handle_node: Node3D = null
var _grab_points: Dictionary = {}

func _ready() -> void:
	super._ready()
	_setup_handle()
	_initial_rotation = global_transform.basis
	_initial_position = global_position

func _setup_handle() -> void:
	_handle_node = find_child("*Handle*") as Node3D
	if _handle_node == null:
		_handle_node = find_child("*Grip*") as Node3D
	if _handle_node == null:
		for child in get_children():
			if child is Node3D and (child.name.to_lower().contains("handle") or child.name.to_lower().contains("grip")):
				_handle_node = child
				break
	if _handle_node == null:
		_handle_node = self
	
	_grab_points = {
		"left": find_child("*Grab*Left*") as Node3D,
		"right": find_child("*Grab*Right*") as Node3D,
	}
	for hand in _grab_points.keys():
		if _grab_points[hand] == null:
			_grab_points[hand] = find_child("*Grip*%s*" % hand.capitalize()) as Node3D
		if _grab_points[hand] == null:
			_grab_points[hand] = _handle_node

func can_interact(actor: Node3D, hand: String = "right") -> bool:
	if not is_instance_valid(actor):
		return false
	if primary_hand != "" and primary_hand != hand and not allow_two_handed:
		return false
	if secondary_hand != "" and secondary_hand != hand:
		return false
	var grab_point: Node3D = _grab_points.get(hand, _handle_node)
	if grab_point == null:
		grab_point = _handle_node
	if grab_point == null:
		return false
	var actor_pos: Vector3 = actor.global_position
	if actor.has_method("get_hand_pose"):
		actor_pos = actor.get_hand_pose(hand).origin
	var distance: float = actor_pos.distance_to(grab_point.global_position)
	return distance <= handle_grab_radius + 0.001

func start_interaction(actor: Node3D, hand: String = "right", interaction_type: String = "grab") -> bool:
	if not can_interact(actor, hand):
		return false
	
	is_interacting = true
	interactor = actor
	
	if primary_hand == "":
		primary_hand = hand
		_primary_pose = _get_hand_pose_for(hand)
		_initial_primary_pose = _primary_pose
		_initial_position = global_position
		_initial_rotation = global_transform.basis
		if haptic_on_grab:
			_emit_haptic(hand)
		grabbed.emit(hand)
	elif secondary_hand == "" and allow_two_handed and hand != primary_hand:
		secondary_hand = hand
		_secondary_pose = _get_hand_pose_for(hand)
		_initial_secondary_pose = _secondary_pose
		if haptic_on_grab:
			_emit_haptic(hand)
		grabbed.emit(hand)
	else:
		return false
	
	interaction_started.emit(actor)
	return true

func _update_interaction(delta: float) -> void:
	if not is_instance_valid(interactor):
		force_release()
		return
	
	var primary_pose: Transform3D = _get_hand_pose_for(primary_hand) if primary_hand != "" else Transform3D.IDENTITY
	var secondary_pose: Transform3D = _get_hand_pose_for(secondary_hand) if secondary_hand != "" else Transform3D.IDENTITY
	
	if primary_hand != "":
		_primary_pose = primary_pose
		primary_grip = _get_grip_value_for(primary_hand)
	
	if secondary_hand != "":
		_secondary_pose = secondary_pose
		secondary_grip = _get_grip_value_for(secondary_hand)
	
	if primary_hand != "" and secondary_hand != "":
		_update_two_handed(delta)
	elif primary_hand != "":
		_update_single_handed(delta)
	
	_check_grip_release(delta)

func _update_single_handed(delta: float) -> void:
	var hand_pose: Transform3D = _primary_pose
	var initial_pose: Transform3D = _initial_primary_pose
	
	var delta_pos: Vector3 = hand_pose.origin - initial_pose.origin
	var delta_rot: Basis = hand_pose.basis * initial_pose.basis.inverse()
	
	var axis: Vector3 = rotation_axis.normalized()
	var angle: float = 0.0
	# Get angle around the specific rotation axis
	var euler: Vector3 = delta_rot.get_euler()
	if axis == Vector3.UP:
		angle = euler.y
	elif axis == Vector3.RIGHT:
		angle = euler.x
	elif axis == Vector3.FORWARD:
		angle = euler.z
	else:
		# For arbitrary axis, project the rotation onto that axis
		var q: Quaternion = Quaternion(delta_rot)
		# Use slerp to get the angle around the axis
		angle = atan2(q.x * axis.x + q.y * axis.y + q.z * axis.z, q.w) * 2.0
	
	if constrain_rotation:
		angle = clampf(angle, -max_angular_velocity * delta, max_angular_velocity * delta)
		_angular_velocity = move_toward(_angular_velocity, angle / maxf(delta, 0.001), stiffness * delta)
		angle = _angular_velocity * delta
	else:
		angle = clampf(angle, -max_angular_velocity * delta, max_angular_velocity * delta)
		_angular_velocity = angle / maxf(delta, 0.001)
	
	if angle != 0.0:
		var rot: Basis = Basis(axis, angle)
		global_transform.basis = rot * _initial_rotation
		rotated.emit(angle)
	
	if constrain_position:
		delta_pos = delta_pos.clamp(Vector3(-max_linear_velocity * delta, -max_linear_velocity * delta, -max_linear_velocity * delta),
			Vector3(max_linear_velocity * delta, max_linear_velocity * delta, max_linear_velocity * delta))
		_linear_velocity = _linear_velocity.move_toward(delta_pos / maxf(delta, 0.001), stiffness * delta)
		global_position = _initial_position + _linear_velocity * delta
		moved.emit(_linear_velocity * delta)
	else:
		global_position = _initial_position + delta_pos
		moved.emit(delta_pos)

func _update_two_handed(delta: float) -> void:
	var primary_dir: Vector3 = (_primary_pose.origin - _secondary_pose.origin).normalized()
	var initial_dir: Vector3 = (_initial_primary_pose.origin - _initial_secondary_pose.origin).normalized()
	
	var angle: float = acos(clampf(primary_dir.dot(initial_dir), -1.0, 1.0))
	var axis: Vector3 = initial_dir.cross(primary_dir).normalized()
	if axis.length_squared() < 0.0001:
		axis = rotation_axis.normalized()
	
	if constrain_rotation:
		angle = clampf(angle, -max_angular_velocity * delta, max_angular_velocity * delta)
		_angular_velocity = move_toward(_angular_velocity, angle / maxf(delta, 0.001), stiffness * delta)
		angle = _angular_velocity * delta
	else:
		angle = clampf(angle, -max_angular_velocity * delta, max_angular_velocity * delta)
		_angular_velocity = angle / maxf(delta, 0.001)
	
	if angle != 0.0:
		var rot: Basis = Basis(axis, angle)
		global_transform.basis = rot * _initial_rotation
		rotated.emit(angle)
	
	var center: Vector3 = (_primary_pose.origin + _secondary_pose.origin) * 0.5
	var initial_center: Vector3 = (_initial_primary_pose.origin + _initial_secondary_pose.origin) * 0.5
	var delta_center: Vector3 = center - initial_center
	
	if constrain_position:
		delta_center = delta_center.clamp(Vector3(-max_linear_velocity * delta, -max_linear_velocity * delta, -max_linear_velocity * delta),
			Vector3(max_linear_velocity * delta, max_linear_velocity * delta, max_linear_velocity * delta))
		_linear_velocity = _linear_velocity.move_toward(delta_center / maxf(delta, 0.001), stiffness * delta)
		global_position = _initial_position + _linear_velocity * delta
		moved.emit(_linear_velocity * delta)
	else:
		global_position = _initial_position + delta_center
		moved.emit(delta_center)

func _check_grip_release(delta: float) -> void:
	if primary_hand != "" and _get_grip_value_for(primary_hand) < 0.3:
		_release_hand(primary_hand)
	if secondary_hand != "" and _get_grip_value_for(secondary_hand) < 0.3:
		_release_hand(secondary_hand)

func _release_hand(hand: String) -> void:
	var velocity: Vector3 = Vector3.ZERO
	if hand == primary_hand:
		var dt: float = 1.0 / 60.0
		velocity = (_primary_pose.origin - _initial_primary_pose.origin) / maxf(dt, 0.001)
		velocity = velocity.clamp(Vector3(-max_linear_velocity, -max_linear_velocity, -max_linear_velocity),
			Vector3(max_linear_velocity, max_linear_velocity, max_linear_velocity))
		primary_hand = ""
		_primary_pose = Transform3D.IDENTITY
		_initial_primary_pose = Transform3D.IDENTITY
		primary_grip = 0.0
	elif hand == secondary_hand:
		secondary_hand = ""
		_secondary_pose = Transform3D.IDENTITY
		_initial_secondary_pose = Transform3D.IDENTITY
		secondary_grip = 0.0
	
	released.emit(hand, velocity)
	
	if primary_hand == "" and secondary_hand == "":
		end_interaction()

func _get_hand_pose_for(hand: String) -> Transform3D:
	if not is_instance_valid(interactor):
		return Transform3D.IDENTITY
	if interactor.has_method("get_hand_pose"):
		return interactor.get_hand_pose(hand)
	return interactor.global_transform

func _get_grip_value_for(hand: String) -> float:
	if not is_instance_valid(interactor):
		return 0.0
	if interactor.has_method("get_grip_value"):
		return interactor.get_grip_value(hand)
	return 1.0

func _emit_haptic(hand: String) -> void:
	if not is_instance_valid(interactor):
		return
	if interactor.has_method("emit_haptic"):
		interactor.emit_haptic(hand, haptic_duration, haptic_amplitude)

func end_interaction() -> void:
	if is_interacting:
		var old_primary := primary_hand
		var old_secondary := secondary_hand
		primary_hand = ""
		secondary_hand = ""
		_primary_pose = Transform3D.IDENTITY
		_secondary_pose = Transform3D.IDENTITY
		_initial_primary_pose = Transform3D.IDENTITY
		_initial_secondary_pose = Transform3D.IDENTITY
		_angular_velocity = 0.0
		_linear_velocity = Vector3.ZERO
		super.end_interaction()

func force_release() -> void:
	end_interaction()

func is_grabbed() -> bool:
	return primary_hand != "" or secondary_hand != ""

func is_two_handed() -> bool:
	return primary_hand != "" and secondary_hand != ""

func get_angular_velocity() -> float:
	return _angular_velocity

func get_linear_velocity() -> Vector3:
	return _linear_velocity