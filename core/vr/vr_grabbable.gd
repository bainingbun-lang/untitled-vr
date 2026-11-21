class_name VrGrabbable
extends RigidBody3D

signal grabbed(hand: Variant, hand_name: String, grab_transform: Transform3D)
signal released(hand: Variant, hand_name: String, velocity: Vector3)
signal grab_update(transform: Transform3D, grip_value: float)

const DEFAULT_MASS: float = 1.0
const DEFAULT_LINEAR_DAMP: float = 0.1
const DEFAULT_ANGULAR_DAMP: float = 0.1
const GRAB_LINEAR_DAMP: float = 3.0
const GRAB_ANGULAR_DAMP: float = 3.0

@export var grabbable: bool = true
@export var body_mass: float = DEFAULT_MASS
@export var body_linear_damp: float = DEFAULT_LINEAR_DAMP
@export var body_angular_damp: float = DEFAULT_ANGULAR_DAMP
@export var grab_linear_damp: float = GRAB_LINEAR_DAMP
@export var grab_angular_damp: float = GRAB_ANGULAR_DAMP
@export var can_grab_when_held: bool = true
@export var grab_priority: int = 0
@export var two_handed: bool = false
@export var secondary_grab_points: Array[Transform3D] = []
@export var throw_velocity_multiplier: float = 1.5

var _original_mass: float = 0.0
var _original_linear_damp: float = 0.0
var _original_angular_damp: float = 0.0
var _is_grabbed: bool = false
var _grabbing_hand: Variant = null
var _grab_transform: Transform3D = Transform3D.IDENTITY
var _initialized: bool = false

func _ready() -> void:
	# Use current mass if user set it before _ready, otherwise use body_mass
	if mass == 1.0:
		mass = body_mass
	_original_mass = mass
	_original_linear_damp = body_linear_damp if linear_damp == 0.1 else linear_damp
	_original_angular_damp = body_angular_damp if angular_damp == 0.1 else angular_damp
	
	if grabbable:
		add_to_group("vr_grabbable")
	
	linear_damp = _original_linear_damp
	angular_damp = _original_angular_damp
	sleeping = false
	_initialized = true

func _get_hand_name(hand: Variant) -> String:
	if hand == null:
		return ""
	if hand is Dictionary and hand.has("get_hand_name"):
		return hand["get_hand_name"].call()
	if hand is Object and hand.has_method("get_hand_name"):
		return hand.get_hand_name()
	return ""

func _is_valid_hand(hand: Variant) -> bool:
	if hand == null:
		return false
	if hand is Dictionary:
		return true
	if hand is Object:
		return is_instance_valid(hand)
	return false

func can_grab(hand: Variant) -> bool:
	if not grabbable:
		return false
	if _is_grabbed and not can_grab_when_held:
		return false
	if not _is_valid_hand(hand):
		return false
	return true

func on_grabbed(hand: Variant, hand_name: String, grab_transform: Transform3D) -> void:
	if _is_grabbed:
		return
	
	_is_grabbed = true
	_grabbing_hand = hand
	_grab_transform = grab_transform
	
	mass = _original_mass
	linear_damp = grab_linear_damp
	angular_damp = grab_angular_damp
	freeze = false
	sleeping = false
	
	grabbed.emit(hand, hand_name, grab_transform)

func on_grab_update(transform: Transform3D, grip_value: float) -> void:
	if not _is_grabbed:
		return
	_grab_transform = transform
	grab_update.emit(transform, grip_value)

func on_released(hand: Variant, hand_name: String, velocity: Vector3) -> void:
	if not _is_grabbed:
		return
	
	var throw_vel := velocity * throw_velocity_multiplier
	linear_velocity = throw_vel
	angular_velocity = Vector3.ZERO
	
	mass = _original_mass
	linear_damp = _original_linear_damp
	angular_damp = _original_angular_damp
	freeze = false
	sleeping = false
	
	_is_grabbed = false
	_grabbing_hand = null
	
	released.emit(hand, hand_name, throw_vel)

func on_hand_collision(hand: Object, position: Vector3, normal: Vector3) -> void:
	if _is_grabbed:
		return
	
	if has_method("_on_hand_brush"):
		_on_hand_brush(hand, position, normal)

func get_grab_transform() -> Transform3D:
	return _grab_transform

func is_grabbed() -> bool:
	return _is_grabbed

func get_grabbing_hand() -> Object:
	return _grabbing_hand

func set_grabbable(value: bool) -> void:
	grabbable = value
	if value:
		add_to_group("vr_grabbable")
	else:
		remove_from_group("vr_grabbable")

func _on_hand_brush(hand: Object, position: Vector3, normal: Vector3) -> void:
	pass