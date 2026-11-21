class_name VrMoveable
extends VrGrabbable

const VrGrabbable = preload("res://core/vr/vr_grabbable.gd")

signal moveable_pushed(pusher: Node3D, impulse: Vector3, position: Vector3)
signal moveable_pulled(puller: Node3D, force: Vector3)
signal moveable_state_changed(state: String)
signal _moveable_state_changed(state: String)

const STATE_IDLE: String = "idle"
const STATE_GRABBED: String = "grabbed"
const STATE_PUSHED: String = "pushed"
const STATE_PULLED: String = "pulled"
const STATE_THROWN: String = "thrown"

const MODE_RIGID: int = 0
const MODE_STATIC: int = 1
const MODE_KINEMATIC: int = 2
const MODE_CHARACTER: int = 3

var _stored_mode: int = MODE_RIGID

@export var moveable_type: String = "generic"
@export var push_resistance: float = 50.0
@export var pull_resistance: float = 30.0
@export var max_push_speed: float = 5.0
@export var max_pull_speed: float = 3.0
@export var angular_resistance: float = 10.0
@export var snap_to_hand: bool = true
@export var snap_speed: float = 15.0
@export var require_two_hands: bool = false
@export var secondary_hand_position: Transform3D = Transform3D.IDENTITY
@export var kinematic_when_held: bool = false

var _state: String = STATE_IDLE
var _push_accumulator: Vector3 = Vector3.ZERO
var _pull_accumulator: Vector3 = Vector3.ZERO
var _secondary_hand: Variant = null
var _primary_hand: Variant = null
var _grabbed_with_two_hands: bool = false

func _ready() -> void:
	super._ready()
	
	if kinematic_when_held:
		set_physics_process(true)

func _get_anchor_transform(hand: Variant) -> Transform3D:
	if hand == null:
		return Transform3D.IDENTITY
	if hand is Dictionary and hand.has("get_anchor_transform"):
		return hand["get_anchor_transform"].call()
	if hand is Object and hand.has_method("get_anchor_transform"):
		return hand.get_anchor_transform()
	return Transform3D.IDENTITY

func _is_same_hand(a: Variant, b: Variant) -> bool:
	if a == null or b == null:
		return false
	if a is Dictionary and b is Dictionary:
		return a == b
	if a is Object and b is Object:
		return a == b
	return false

func _is_valid_hand(hand: Variant) -> bool:
	if hand == null:
		return false
	if hand is Dictionary:
		return true
	if hand is Object:
		return is_instance_valid(hand)
	return false

func can_grab(hand: Variant) -> bool:
	if not super.can_grab(hand):
		return false
	if require_two_hands and _secondary_hand != null and not _is_same_hand(_secondary_hand, hand):
		return false
	return true

func on_grabbed(hand: Variant, hand_name: String, grab_transform: Transform3D) -> void:
	super.on_grabbed(hand, hand_name, grab_transform)
	
	_primary_hand = hand
	_state = STATE_GRABBED
	_moveable_state_changed.emit(_state)
	
	if require_two_hands and _secondary_hand != null:
		_grabbed_with_two_hands = true
	
	if kinematic_when_held:
		_stored_mode = MODE_KINEMATIC
		freeze = true

func on_grab_update(transform: Transform3D, grip_value: float) -> void:
	super.on_grab_update(transform, grip_value)
	
	if snap_to_hand and _state == STATE_GRABBED:
		_snap_to_transform(transform)
	
	if _secondary_hand != null and _is_valid_hand(_secondary_hand):
		_update_two_hand_orientation()

func _snap_to_transform(target: Transform3D) -> void:
	if _stored_mode == MODE_KINEMATIC:
		global_transform = global_transform.interpolate_with(target, snap_speed * (1.0 / Engine.physics_ticks_per_second))
	else:
		var pos_error := target.origin - global_position
		var rot_error := _get_rotation_error(global_transform.basis, target.basis)
		
		var target_vel := pos_error * snap_speed
		target_vel = target_vel.limit_length(max_push_speed)
		linear_velocity = linear_velocity.lerp(target_vel, 0.5)
		
		var target_ang_vel := rot_error * snap_speed
		target_ang_vel = target_ang_vel.limit_length(max_push_speed * 2.0)
		angular_velocity = angular_velocity.lerp(target_ang_vel, 0.5)

func _get_rotation_error(current: Basis, target: Basis) -> Vector3:
	var error_quat := current.get_rotation_quaternion().inverse() * target.get_rotation_quaternion()
	return error_quat.get_axis() * error_quat.get_angle()

func _update_two_hand_orientation() -> void:
	if _primary_hand == null or _secondary_hand == null:
		return
	
	var primary_transform: Transform3D = _get_anchor_transform(_primary_hand)
	var secondary_transform: Transform3D = _get_anchor_transform(_secondary_hand)
	
	var direction: Vector3 = (secondary_transform.origin - primary_transform.origin).normalized()
	var target_basis := Basis()
	target_basis.z = -direction
	target_basis.x = Vector3.UP.cross(direction).normalized()
	if target_basis.x.length_squared() < 0.01:
		target_basis.x = Vector3.RIGHT
	target_basis.y = direction.cross(target_basis.x).normalized()
	
	var target_transform := Transform3D(target_basis, primary_transform.origin)
	
	if _stored_mode == MODE_KINEMATIC:
		global_transform = global_transform.interpolate_with(target_transform, snap_speed * (1.0 / Engine.physics_ticks_per_second))
	else:
		var rot_error := _get_rotation_error(global_transform.basis, target_basis)
		var target_ang_vel := rot_error * snap_speed
		target_ang_vel = target_ang_vel.limit_length(max_push_speed * 2.0)
		angular_velocity = angular_velocity.lerp(target_ang_vel, 0.5)

func on_released(hand: Variant, hand_name: String, velocity: Vector3) -> void:
	var was_primary := _is_same_hand(hand, _primary_hand)
	var was_secondary := _is_same_hand(hand, _secondary_hand)
	
	if was_primary:
		_primary_hand = null
	if was_secondary:
		_secondary_hand = null
	
	if was_primary and _secondary_hand != null:
		_primary_hand = _secondary_hand
		_secondary_hand = null
	
	if _primary_hand == null and _secondary_hand == null:
		_grabbed_with_two_hands = false
		super.on_released(hand, hand_name, velocity)
		
		_state = STATE_THROWN
		_moveable_state_changed.emit(_state)
		
		if kinematic_when_held:
			_stored_mode = MODE_RIGID
			freeze = false
			call_deferred("_set_state_idle")
	else:
		super.on_released(hand, hand_name, velocity)

func _set_state_idle() -> void:
	_state = STATE_IDLE
	_moveable_state_changed.emit(_state)

func try_add_secondary_hand(hand: Variant) -> bool:
	if _secondary_hand != null or _is_same_hand(hand, _primary_hand):
		return false
	if not _is_valid_hand(hand):
		return false
	
	_secondary_hand = hand
	_grabbed_with_two_hands = true
	return true

func remove_secondary_hand(hand: Variant) -> void:
	if _is_same_hand(_secondary_hand, hand):
		_secondary_hand = null
		_grabbed_with_two_hands = false
	if _is_same_hand(_primary_hand, hand):
		_primary_hand = _secondary_hand
		_secondary_hand = null

func apply_push(impulse: Vector3, position: Vector3, pusher: Node3D = null) -> void:
	if _state == STATE_GRABBED:
		return
	
	_state = STATE_PUSHED
	_moveable_state_changed.emit(_state)
	
	var clamped_impulse := impulse.limit_length(push_resistance)
	apply_impulse(clamped_impulse, position - global_position)
	
	_push_accumulator += clamped_impulse
	moveable_pushed.emit(pusher, clamped_impulse, position)
	
	call_deferred("_reset_push_state")

func _reset_push_state() -> void:
	if _state == STATE_PUSHED and _primary_hand == null:
		_state = STATE_IDLE
		_moveable_state_changed.emit(_state)

func apply_pull(force: Vector3, puller: Node3D = null) -> void:
	if _state == STATE_GRABBED:
		return
	
	_state = STATE_PULLED
	_moveable_state_changed.emit(_state)
	
	var clamped_force := force.limit_length(pull_resistance)
	apply_force(clamped_force)
	
	_pull_accumulator += clamped_force
	moveable_pulled.emit(puller, clamped_force)
	
	call_deferred("_reset_pull_state")

func _reset_pull_state() -> void:
	if _state == STATE_PULLED and _primary_hand == null:
		_state = STATE_IDLE
		_moveable_state_changed.emit(_state)

func on_hand_collision(hand: Variant, position: Vector3, normal: Vector3) -> void:
	super.on_hand_collision(hand, position, normal)
	
	if _state != STATE_GRABBED and not _is_same_hand(hand, _primary_hand) and not _is_same_hand(hand, _secondary_hand):
		var push_dir := -normal
		var push_impulse := push_dir * push_resistance * 0.5
		apply_push(push_impulse, position, hand)

func get_state() -> String:
	return _state

func is_grabbed_with_two_hands() -> bool:
	return _grabbed_with_two_hands

func get_primary_hand() -> Variant:
	return _primary_hand

func get_secondary_hand() -> Variant:
	return _secondary_hand