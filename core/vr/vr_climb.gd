class_name VrClimb
extends Node

## VrClimb - Adapted from godot-xr-tools XRToolsMovementClimb
##
## Provides climbing movement for the player in VR.
## Requires VrRig with left/right controllers and hands.
## Climbable objects should have VrClimbable attached.


signal player_climb_start
signal player_climb_end


## Distance at which grabs snap
const SNAP_DISTANCE: float = 1.0

## Order in which movement is processed (lower = earlier)
@export var order: int = 15

## Force to push player away upon letting go
@export var forward_push: float = 1.0

## Momentum multiplier when flinging off walls
@export var fling_multiplier: float = 1.0

## How many velocities to average out upon letting go
@export var velocity_averages: int = 5


# Left climbing handle
var _left_handle: Node3D = null

# Right climbing handle
var _right_handle: Node3D = null

# Dominant handle (moving the player)
var _dominant: Node3D = null

# Velocity averager
var _averager: VrVelocityAverager = null

# References to rig components (set during setup)
var _rig: Node = null
var _left_controller: Variant = null
var _right_controller: Variant = null
var _left_hand: Node = null
var _right_hand: Node = null
var _xr_origin: XROrigin3D = null
var _player_body: Node3D = null


func _ready() -> void:
	_averager = VrVelocityAverager.new(velocity_averages)


func _get_global_position(obj: Variant) -> Vector3:
	if obj == null:
		return Vector3.ZERO
	if obj is Node3D and obj.is_inside_tree():
		return obj.global_position
	if obj is Dictionary and obj.has("global_position"):
		return obj["global_position"]
	return Vector3.ZERO


func _get_global_transform(obj: Variant) -> Transform3D:
	if obj == null:
		return Transform3D.IDENTITY
	if obj is Node3D and obj.is_inside_tree():
		return obj.global_transform
	if obj is Dictionary and obj.has("global_transform"):
		return obj["global_transform"]
	return Transform3D.IDENTITY


func setup(rig: Node) -> void:
	_rig = rig
	if rig.has_method("controller_for"):
		_left_controller = rig.controller_for("left")
		_right_controller = rig.controller_for("right")
	if rig.has_method("get_node"):
		_xr_origin = rig.get_node_or_null("XROrigin3D") as XROrigin3D
		_player_body = _xr_origin if _xr_origin else rig
		_left_hand = rig.get_node_or_null("LeftWeaponHand")
		_right_hand = rig.get_node_or_null("RightWeaponHand")


## Performs player physics movement
## Returns true if climbing movement was performed (to bypass gravity)
func physics_movement(delta: float, player_body: Node3D, disabled: bool = false) -> bool:
	if disabled or _rig == null:
		_set_climbing(false, player_body)
		return false

	# Check for climbing handles being deleted while held
	if not is_instance_valid(_left_handle):
		_left_handle = null
	if not is_instance_valid(_right_handle):
		_right_handle = null
	if not is_instance_valid(_dominant):
		_dominant = null

	# Snap grabs if too far
	if _left_handle and _left_controller:
		var left_pickup_pos := _get_global_position(_left_controller)
		var left_grab_pos := _get_global_position(_left_handle)
		if left_pickup_pos.distance_to(left_grab_pos) > SNAP_DISTANCE:
			_release_left()

	if _right_handle and _right_controller:
		var right_pickup_pos := _get_global_position(_right_controller)
		var right_grab_pos := _get_global_position(_right_handle)
		if right_pickup_pos.distance_to(right_grab_pos) > SNAP_DISTANCE:
			_release_right()

	# Update climbing state
	_set_climbing(_dominant != null, player_body)

	# Skip if not actively climbing
	if _dominant == null:
		return false

	# Calculate how much the player has moved
	var offset := Vector3.ZERO
	if _dominant == _left_handle and _left_controller:
		var left_pickup_pos := _get_global_position(_left_controller)
		var left_grab_pos := _get_global_position(_left_handle)
		offset = left_pickup_pos - left_grab_pos
	elif _dominant == _right_handle and _right_controller:
		var right_pickup_pos := _get_global_position(_right_controller)
		var right_grab_pos := _get_global_position(_right_handle)
		offset = right_pickup_pos - right_grab_pos

	# Move the player by the offset (inverse because we move the world relative to hand)
	var old_position := player_body.global_position
	if player_body.has_method("move_and_collide"):
		player_body.move_and_collide(-offset)
	elif player_body.has_method("move_and_slide"):
		player_body.velocity = Vector3.ZERO
		player_body.global_position -= offset
	else:
		player_body.global_position -= offset
	
	# Reset velocity since we're manually positioning
	if player_body.has_method("set_velocity"):
		player_body.set_velocity(Vector3.ZERO)
	elif player_body.has_method("set_linear_velocity"):
		player_body.set_linear_velocity(Vector3.ZERO)

	# Update the players average-velocity data
	var distance := player_body.global_position - old_position
	_averager.add_distance(delta, distance)

	# Report exclusive motion performed (to bypass gravity)
	return true


## Called when left hand grabs a climbable
func on_left_picked_up(what: Node3D) -> void:
	var climbable := what as VrClimbable
	if not climbable:
		return
	
	_left_handle = climbable.get_grab_handle(_left_controller)
	if not _left_handle:
		return
	
	_dominant = _left_handle
	
	# If hands have collision targeting, target the handle
	if _left_hand and _left_hand.has_method("add_target_override"):
		_left_hand.call("add_target_override", _left_handle, 0)

	# Update the handle's position to match the controller
	if _left_controller and _left_handle:
		_left_handle.global_transform = _get_global_transform(_left_controller)


## Called when left hand releases
func on_left_dropped() -> void:
	if _left_hand and _left_hand.has_method("remove_target_override"):
		_left_hand.call("remove_target_override", _left_handle)
	_left_handle = null
	_dominant = _right_handle


## Called when right hand grabs a climbable
func on_right_picked_up(what: Node3D) -> void:
	var climbable := what as VrClimbable
	if not climbable:
		return
	
	_right_handle = climbable.get_grab_handle(_right_controller)
	if not _right_handle:
		return
	
	_dominant = _right_handle
	
	if _right_hand and _right_hand.has_method("add_target_override"):
		_right_hand.call("add_target_override", _right_handle, 0)

	# Update the handle's position to match the controller
	if _right_controller and _right_handle:
		_right_handle.global_transform = _get_global_transform(_right_controller)


## Called when right hand releases
func on_right_dropped() -> void:
	if _right_hand and _right_hand.has_method("remove_target_override"):
		_right_hand.call("remove_target_override", _right_handle)
	_right_handle = null
	_dominant = _left_handle


func _release_left() -> void:
	on_left_dropped()


func _release_right() -> void:
	on_right_dropped()


# Toggles climbing state
func _set_climbing(active: bool, player_body: Node3D) -> void:
	if active == (_dominant != null):
		return

	if active:
		_averager.clear()
		player_climb_start.emit()
	else:
		# Calculate the forward direction (based on camera-forward)
		var dir_forward: Vector3 = Vector3.FORWARD
		if _rig and _rig.has_method("get_pose"):
			var head_pose: Transform3D = _rig.get_pose("left")  # Use left as reference for head
			dir_forward = -head_pose.basis.z
			dir_forward.y = 0.0
			if dir_forward.length_squared() > 0.000001:
				dir_forward = dir_forward.normalized()
		elif _rig and _rig.has_method("get_global_transform"):
			# Fallback for mock rigs without get_pose
			dir_forward = -_rig.global_transform.basis.z
			dir_forward.y = 0.0
			if dir_forward.length_squared() > 0.000001:
				dir_forward = dir_forward.normalized()
		
		# Set player velocity based on averaged velocity, fling multiplier, and forward push
		var velocity := _averager.get_velocity()
		
		if player_body.has_method("apply_impulse"):
			player_body.apply_impulse((velocity * fling_multiplier) + (dir_forward * forward_push))
		elif player_body.has_method("set_linear_velocity"):
			player_body.set_linear_velocity((velocity * fling_multiplier) + (dir_forward * forward_push))
		elif player_body is RigidBody3D:
			player_body.linear_velocity = (velocity * fling_multiplier) + (dir_forward * forward_push)
		
		player_climb_end.emit()


func is_climbing() -> bool:
	return _dominant != null


func get_dominant_hand() -> String:
	if _dominant == _left_handle:
		return "left"
	elif _dominant == _right_handle:
		return "right"
	return ""


class VrVelocityAverager extends RefCounted:
	var _samples: Array[Vector3] = []
	var _max_samples: int
	var _times: Array[float] = []
	
	func _init(max_samples: int) -> void:
		_max_samples = max(max_samples, 2)
	
	func add_distance(delta: float, distance: Vector3) -> void:
		if delta <= 0.0:
			return
		var velocity := distance / delta
		_samples.append(velocity)
		_times.append(Time.get_ticks_msec() / 1000.0)
		_trim()
	
	func get_velocity() -> Vector3:
		if _samples.is_empty():
			return Vector3.ZERO
		var sum := Vector3.ZERO
		for v in _samples:
			sum += v
		return sum / _samples.size()
	
	func clear() -> void:
		_samples.clear()
		_times.clear()
	
	func _trim() -> void:
		while _samples.size() > _max_samples:
			_samples.pop_front()
			_times.pop_front()