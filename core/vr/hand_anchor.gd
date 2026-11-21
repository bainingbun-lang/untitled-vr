class_name HandAnchor
extends RigidBody3D

signal anchor_updated(global_transform: Transform3D)

const MAX_SPEED: float = 120.0
const MAX_ANGULAR_SPEED: float = 120.0
const COLLISION_SHAPE_RADIUS: float = 0.05
const SNAP_DISTANCE: float = 0.02

@export var hand_name: String = "right"
@export var anchor_mass: float = 0.1
@export var follow_stiffness: float = 5000.0
@export var follow_damping: float = 150.0
@export var collision_layer_phys: int = 1
@export var collision_mask_phys: int = 1
@export var use_continuous_cd: bool = true

var _target_transform: Transform3D = Transform3D.IDENTITY
var _initialized: bool = false
var _collision_shape: CollisionShape3D = null

func _init() -> void:
	mass = 0.1

func _ready() -> void:
	collision_layer = collision_layer_phys
	collision_mask = collision_mask_phys
	mass = float(anchor_mass)
	sleeping = false
	continuous_cd = use_continuous_cd
	contact_monitor = true
	max_contacts_reported = 10
	
	# Add collision shape for physics interactions
	if not _collision_shape:
		var shape = SphereShape3D.new()
		shape.radius = COLLISION_SHAPE_RADIUS
		_collision_shape = CollisionShape3D.new()
		_collision_shape.shape = shape
		add_child(_collision_shape)
	
	set_physics_process(true)
	_initialized = true

func set_target_transform(target: Transform3D) -> void:
	_target_transform = target

func _physics_process(delta: float) -> void:
	if not _initialized:
		return
	
	var current_transform := global_transform
	var position_error := _target_transform.origin - current_transform.origin
	var rotation_error := _get_rotation_error(current_transform.basis, _target_transform.basis)
	
	var distance := position_error.length()
	
	# Snap to target if very close
	if distance < SNAP_DISTANCE and rotation_error.length() < 0.01:
		global_transform = _target_transform
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		anchor_updated.emit(global_transform)
		return
	
	# Calculate target linear velocity
	var target_linear_vel := position_error * follow_stiffness
	target_linear_vel = target_linear_vel.limit_length(MAX_SPEED)
	
	# Calculate target angular velocity (approximate)
	var target_angular_vel := rotation_error * follow_stiffness
	target_angular_vel = target_angular_vel.limit_length(MAX_ANGULAR_SPEED)
	
	# Smooth interpolation
	var interp_factor: float = 1.0 - exp(-follow_damping * delta)
	linear_velocity = linear_velocity.lerp(target_linear_vel, interp_factor)
	angular_velocity = angular_velocity.lerp(target_angular_vel, interp_factor)
	
	anchor_updated.emit(global_transform)

func _get_rotation_error(current: Basis, target: Basis) -> Vector3:
	var error_quat := current.get_rotation_quaternion().inverse() * target.get_rotation_quaternion()
	return error_quat.get_axis() * error_quat.get_angle()

func get_hand_name() -> String:
	return hand_name

func teleport_to(transform: Transform3D) -> void:
	global_transform = transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_target_transform = transform