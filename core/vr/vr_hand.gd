class_name VrHand
extends Node3D

signal grabbed(node: Node3D, hand_name: String)
signal released(node: Node3D, hand_name: String, velocity: Vector3)
signal haptic(hand: String, duration: float, amplitude: float)
signal collision_entered(collider: Node3D, position: Vector3, normal: Vector3)
signal collision_exited(collider: Node3D)

const HandAnchorScript = preload("res://core/vr/hand_anchor.gd")
const VrGloveScript = preload("res://core/vr/vr_glove.gd")

const GRAB_RADIUS: float = 0.12
const MAX_GRAB_DISTANCE: float = 0.3
const RELEASE_VELOCITY_SCALE: float = 1.5
const HAPTIC_GRAB_DURATION: float = 0.05
const HAPTIC_GRAB_AMPLITUDE: float = 0.4
const HAPTIC_RELEASE_DURATION: float = 0.03
const HAPTIC_RELEASE_AMPLITUDE: float = 0.3

@export var hand_name: String = "right"
@export var anchor_mass: float = 0.1
@export var follow_stiffness: float = 1200.0
@export var follow_damping: float = 80.0
@export var grab_radius: float = GRAB_RADIUS
@export var max_grab_distance: float = MAX_GRAB_DISTANCE
@export var collision_layer: int = 1
@export var collision_mask: int = 1
@export var use_continuous_cd: bool = true
@export var show_visual: bool = true
@export var haptic_enabled: bool = true

var anchor: Object = null
var glove: Object = null
var _grabbed_object: Node3D = null
var _grab_joint: Generic6DOFJoint3D = null
var _grab_offset: Transform3D = Transform3D.IDENTITY
var _was_gripping: bool = false
var _current_grip_value: float = 0.0
var _current_trigger_value: float = 0.0
var _current_zone: String = "grip"
var _initialized: bool = false
var _last_anchor_transform: Transform3D = Transform3D.IDENTITY
var _velocity_history: Array[Vector3] = []
var _max_velocity_history: int = 5
var _contact_monitor: bool = true
var _max_contacts: int = 10

func _ready() -> void:
	build()
	set_physics_process(true)

func build() -> bool:
	if _initialized:
		return true
	
	anchor = HandAnchorScript.new()
	anchor.name = "Anchor_" + hand_name
	anchor.hand_name = hand_name
	anchor.anchor_mass = anchor_mass
	anchor.follow_stiffness = follow_stiffness
	anchor.follow_damping = follow_damping
	anchor.collision_layer = collision_layer
	anchor.collision_mask = collision_mask
	anchor.use_continuous_cd = use_continuous_cd
	add_child(anchor)
	
	if show_visual:
		glove = VrGloveScript.new()
		if not glove.build(hand_name):
			glove.free()
			glove = null
		else:
			anchor.add_child(glove)
	
	anchor.anchor_updated.connect(_on_anchor_updated)
	
	_initialized = true
	return true

func _on_anchor_updated(global_transform: Transform3D) -> void:
	_last_anchor_transform = global_transform
	_update_velocity_history(global_transform.origin)
	
	if _grabbed_object != null and is_instance_valid(_grabbed_object):
		_update_grabbed_object(global_transform)

func _update_velocity_history(position: Vector3) -> void:
	if _last_anchor_transform.origin != Vector3.ZERO:
		var vel := (position - _last_anchor_transform.origin) / Engine.physics_ticks_per_second
		_velocity_history.append(vel)
		if _velocity_history.size() > _max_velocity_history:
			_velocity_history.remove_at(0)

func get_average_velocity() -> Vector3:
	if _velocity_history.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for v in _velocity_history:
		sum += v
	return sum / _velocity_history.size()

func set_target_transform(target: Transform3D) -> void:
	if anchor != null:
		anchor.set_target_transform(target)

func try_grab(target: Node3D, grip_value: float = 1.0, zone: String = "grip") -> bool:
	if _grabbed_object != null:
		return false
	if not is_instance_valid(target):
		return false
	if not target.is_in_group("vr_grabbable") and not target.is_in_group("physics_props") and not target.is_in_group("grabbable"):
		return false
	
	var distance := _last_anchor_transform.origin.distance_to(target.global_position)
	if distance > max_grab_distance:
		return false
	
	if target.has_method("can_grab") and not target.can_grab(self):
		return false
	
	var grab_transform := _last_anchor_transform
	if target.has_method("get_grab_transform"):
		grab_transform = target.get_grab_transform(hand_name, _last_anchor_transform)
	
	_grabbed_object = target
	_current_grip_value = grip_value
	_current_zone = zone
	_grab_offset = grab_transform.affine_inverse() * target.global_transform
	
	if target is RigidBody3D:
		_create_physics_joint(target, grab_transform)
	elif target.has_method("on_grabbed"):
		target.on_grabbed(self, hand_name, grab_transform)
	
	_was_gripping = true
	grabbed.emit(target, hand_name)
	
	if haptic_enabled:
		haptic.emit(hand_name, HAPTIC_GRAB_DURATION, HAPTIC_GRAB_AMPLITUDE)
	
	return true

func try_grab_any(grip_value: float = 1.0, zone: String = "grip", max_dist: float = -1.0) -> bool:
	if _grabbed_object != null:
		return false
	
	var search_radius := max_dist if max_dist > 0 else max_grab_distance
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return false
	
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = search_radius
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, _last_anchor_transform.origin)
	query.collision_mask = collision_mask
	query.exclude = [anchor.get_rid()] if anchor != null and anchor.has_method("get_rid") else []
	
	var results := space.intersect_shape(query, 10)
	for result in results:
		var collider: Node3D = result["collider"] as Node3D
		if collider == null or not is_instance_valid(collider):
			continue
		if collider == anchor:
			continue
		if collider.is_in_group("vr_grabbable") or collider.is_in_group("physics_props") or collider.is_in_group("grabbable"):
			if try_grab(collider, grip_value, zone):
				return true
	
	return false

func _create_physics_joint(body: RigidBody3D, grab_transform: Transform3D) -> void:
	_grab_joint = Generic6DOFJoint3D.new()
	_grab_joint.linear_limit_x = 0.0
	_grab_joint.linear_limit_y = 0.0
	_grab_joint.linear_limit_z = 0.0
	_grab_joint.angular_limit_x = 0.0
	_grab_joint.angular_limit_y = 0.0
	_grab_joint.angular_limit_z = 0.0
	
	var joint_global := grab_transform
	_grab_joint.global_transform = joint_global
	
	add_child(_grab_joint)
	body.add_child(_grab_joint)
	
	body.freeze = false
	body.sleeping = false

func _update_grabbed_object(anchor_transform: Transform3D) -> void:
	if _grabbed_object == null or not is_instance_valid(_grabbed_object):
		release()
		return
	
	if _grabbed_object is RigidBody3D and _grab_joint != null and is_instance_valid(_grab_joint):
		var target_transform := anchor_transform * _grab_offset
		_grab_joint.global_transform = target_transform
	elif _grabbed_object.has_method("on_grab_update"):
		var target_transform := anchor_transform * _grab_offset
		_grabbed_object.on_grab_update(target_transform, _current_grip_value)

func release(throw_velocity: Vector3 = Vector3.ZERO) -> void:
	if _grabbed_object == null or not is_instance_valid(_grabbed_object):
		return
	
	var obj := _grabbed_object
	var final_velocity := throw_velocity
	
	if final_velocity == Vector3.ZERO:
		final_velocity = get_average_velocity() * RELEASE_VELOCITY_SCALE
	
	if obj is RigidBody3D:
		if _grab_joint != null and is_instance_valid(_grab_joint):
			_grab_joint.queue_free()
			_grab_joint = null
		obj.linear_velocity = final_velocity
		obj.angular_velocity = Vector3.ZERO
		obj.freeze = false
		obj.sleeping = false
	elif obj.has_method("on_released"):
		obj.on_released(self, hand_name, final_velocity)
	
	_grabbed_object = null
	_grab_offset = Transform3D.IDENTITY
	_current_grip_value = 0.0
	_current_trigger_value = 0.0
	_was_gripping = false
	
	released.emit(obj, hand_name, final_velocity)
	
	if haptic_enabled:
		haptic.emit(hand_name, HAPTIC_RELEASE_DURATION, HAPTIC_RELEASE_AMPLITUDE)

func force_release() -> void:
	release(Vector3.ZERO)

func is_grabbing() -> bool:
	return _grabbed_object != null and is_instance_valid(_grabbed_object)

func get_grabbed_object() -> Node3D:
	return _grabbed_object

func get_grip_value() -> float:
	return _current_grip_value

func get_trigger_value() -> float:
	return _current_trigger_value

func get_zone() -> String:
	return _current_zone

func get_anchor_transform() -> Transform3D:
	return _last_anchor_transform

func get_anchor() -> Object:
	return anchor

func get_glove() -> Object:
	return glove

func update_hand_pose(grip_value: float, trigger_value: float, zone: String = "grip") -> void:
	_current_grip_value = grip_value
	_current_trigger_value = trigger_value
	_current_zone = zone
	
	if glove != null:
		glove.set_pose(grip_value, trigger_value, zone)

func _physics_process(delta: float) -> void:
	if not _initialized:
		return
	
	var grip_pressed := _current_grip_value > 0.5
	var was_gripping := _was_gripping
	
	if not grip_pressed and was_gripping and is_grabbing():
		release()

func teleport_to(transform: Transform3D) -> void:
	if anchor != null:
		anchor.teleport_to(transform)
	_last_anchor_transform = transform
	_velocity_history.clear()

func get_hand_name() -> String:
	return hand_name

func set_hand_name(name: String) -> void:
	hand_name = "left" if name == "left" else "right"
	if anchor != null:
		anchor.hand_name = hand_name
	if glove != null:
		glove.hand = hand_name