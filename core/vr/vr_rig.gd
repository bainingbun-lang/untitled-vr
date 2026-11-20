class_name VrRig
extends Node3D

signal activated()
signal vignette_changed(strength: float)

const VrBagScript = preload("res://core/vr/vr_bag.gd")
const VrWeaponHandScript = preload("res://core/vr/vr_weapon_hand.gd")
const DbScript = preload("res://core/game/weapon_db.gd")

@export var move_speed: float = 2.2
@export var turn_mode: String = "smooth"
@export var smooth_turn_speed: float = 1.6
@export var snap_turn_degrees: float = 30.0
@export var stick_deadzone: float = 0.2
@export var snap_threshold: float = 0.7
@export var snap_cooldown: float = 0.25
@export var comfort_vignette_enabled: bool = true
@export var teleport_enabled: bool = false
@export var teleport_max_distance: float = 5.0
@export var auto_process: bool = true

var xr_availability_override: Callable = Callable()
var xr_interface = null
var xr_origin: XROrigin3D = null
var xr_camera: XRCamera3D = null
var left_controller: XRController3D = null
var right_controller: XRController3D = null
var left_hand = null
var right_hand = null
var bag = null
var weapon_system: Node = null
var input_provider = null

var _active: bool = false
var _built: bool = false
var _xr_origin: XROrigin3D = null
var _snap_timer: float = 0.0
var _vignette: float = 0.0
var _vignette_ring: MeshInstance3D = null


func _ready() -> void:
	build()


func build() -> bool:
	if _built:
		return _active
	_built = true
	if not _probe_xr_available():
		return false
	_xr_origin = XROrigin3D.new()
	_xr_origin.name = "XROrigin3D"
	add_child(_xr_origin)
	xr_origin = _xr_origin

	xr_camera = XRCamera3D.new()
	xr_camera.name = "XRCamera3D"
	xr_origin.add_child(xr_camera)

	left_controller = XRController3D.new()
	left_controller.name = "LeftController"
	left_controller.set("tracker", &"left_hand")
	left_controller.set("pose", &"aim")
	xr_origin.add_child(left_controller)

	right_controller = XRController3D.new()
	right_controller.name = "RightController"
	right_controller.set("tracker", &"right_hand")
	right_controller.set("pose", &"aim")
	xr_origin.add_child(right_controller)

	bag = VrBagScript.new(DbScript.list_ids())
	left_hand = _make_hand("left")
	right_hand = _make_hand("right")
	add_child(left_hand)
	add_child(right_hand)

	if comfort_vignette_enabled:
		_build_vignette_ring()

	_active = true
	activated.emit()
	return true


func _probe_xr_available() -> bool:
	if xr_availability_override.is_valid():
		return bool(xr_availability_override.call())
	if not ClassDB.class_exists("XRServer"):
		return false
	if not ClassDB.class_exists("OpenXRInterface"):
		return false
	var candidate = XRServer.find_interface("OpenXR")
	if candidate == null:
		return false
	if candidate.has_method("is_initialized") and not bool(candidate.call("is_initialized")):
		return false
	xr_interface = candidate
	return true


func _make_hand(hand_name: String):
	var node = VrWeaponHandScript.new()
	node.name = hand_name.capitalize() + "WeaponHand"
	node.hand = hand_name
	node.bag = bag
	node.weapon_system = weapon_system
	node.input_provider = _provider()
	node.auto_process = false
	return node


func _build_vignette_ring() -> void:
	if xr_camera == null:
		return
	var mesh := TorusMesh.new()
	mesh.set("inner_radius", 0.09)
	mesh.set("outer_radius", 0.17)
	mesh.set("rings", 6)
	mesh.set("segments", 24)
	_vignette_ring = MeshInstance3D.new()
	_vignette_ring.name = "ComfortVignette"
	_vignette_ring.mesh = mesh
	_vignette_ring.rotation.x = PI * 0.5
	_vignette_ring.position.z = -0.3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	_vignette_ring.material_override = material
	xr_camera.add_child(_vignette_ring)


func is_active() -> bool:
	return _active


func is_built() -> bool:
	return _built


func set_input_provider(provider) -> void:
	input_provider = provider
	var chosen = provider if provider != null else self
	if left_hand != null:
		left_hand.input_provider = chosen
	if right_hand != null:
		right_hand.input_provider = chosen


func set_weapon_system(node: Node) -> void:
	weapon_system = node
	if left_hand != null:
		left_hand.bind_weapon_system(node)
	if right_hand != null:
		right_hand.bind_weapon_system(node)


func controller_for(hand_name: String):
	if hand_name == "left":
		return left_controller
	if hand_name == "right":
		return right_controller
	return null


func _provider():
	return input_provider if input_provider != null else self


func _call_provider(method: String, args: Array, fallback):
	var provider = _provider()
	if provider != null and provider.has_method(method):
		return provider.callv(method, args)
	return fallback


func get_pose(hand_name: String) -> Transform3D:
	var controller = controller_for(hand_name)
	if controller == null:
		return Transform3D.IDENTITY
	return controller.global_transform


func is_grip_pressed(hand_name: String) -> bool:
	var controller = controller_for(hand_name)
	if controller == null or not controller.has_method("is_button_pressed"):
		return false
	return bool(controller.call("is_button_pressed", &"grip"))


func is_trigger_pressed(hand_name: String) -> bool:
	var controller = controller_for(hand_name)
	if controller == null or not controller.has_method("is_button_pressed"):
		return false
	return bool(controller.call("is_button_pressed", &"trigger"))


func get_stick(hand_name: String) -> Vector2:
	var controller = controller_for(hand_name)
	if controller == null:
		return Vector2.ZERO
	if controller.has_method("get_vector2"):
		var value = controller.call("get_vector2", &"thumbstick")
		if value is Vector2:
			return value
	if controller.has_method("get_axis"):
		var axis_x = controller.call("get_axis", &"thumbstick_x")
		var axis_y = controller.call("get_axis", &"thumbstick_y")
		return Vector2(float(axis_x), float(axis_y))
	return Vector2.ZERO


func _process(delta: float) -> void:
	if auto_process and _active:
		step(delta)


func step(delta: float) -> void:
	step_locomotion(delta)
	if left_hand != null:
		left_hand.step(delta)
	if right_hand != null:
		right_hand.step(delta)
	_update_vignette(delta)


func step_locomotion(delta: float) -> void:
	if xr_origin == null or delta <= 0.0:
		return
	var move_stick: Vector2 = _call_provider("get_stick", ["left"], Vector2.ZERO)
	var turn_stick: Vector2 = _call_provider("get_stick", ["right"], Vector2.ZERO)
	var velocity := locomotion_velocity(move_stick, _head_forward(), move_speed, stick_deadzone)
	if velocity.length_squared() > 0.000001:
		xr_origin.global_position += velocity * delta
	var can_step: bool = _snap_timer <= 0.0
	var yaw := turn_delta(
		turn_stick.x, turn_mode, smooth_turn_speed, snap_turn_degrees,
		delta, stick_deadzone, can_step
	)
	if absf(yaw) > 0.000001:
		xr_origin.global_transform = rotate_around_y(xr_origin.global_transform, _head_position(), yaw)
		if turn_mode == "snap":
			_snap_timer = snap_cooldown
	_snap_timer = maxf(_snap_timer - delta, 0.0)
	if absf(turn_stick.x) < snap_threshold:
		_snap_timer = 0.0


func _head_forward() -> Vector3:
	if xr_camera == null:
		return Vector3.FORWARD
	var forward := -xr_camera.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.000001 else Vector3.FORWARD


func _head_position() -> Vector3:
	return xr_camera.global_position if xr_camera != null else global_position


func _update_vignette(delta: float) -> void:
	if not comfort_vignette_enabled:
		_vignette = 0.0
		return
	var move_stick: Vector2 = _call_provider("get_stick", ["left"], Vector2.ZERO)
	var turn_stick: Vector2 = _call_provider("get_stick", ["right"], Vector2.ZERO)
	var linear: float = locomotion_velocity(move_stick, _head_forward(), move_speed, stick_deadzone).length()
	var angular: float = absf(turn_delta(
		turn_stick.x, turn_mode, smooth_turn_speed, snap_turn_degrees,
		delta, stick_deadzone, false
	)) / maxf(delta, 0.0001)
	_vignette = compute_vignette(linear, angular)
	if _vignette_ring != null and _vignette_ring.material_override is StandardMaterial3D:
		var material := _vignette_ring.material_override as StandardMaterial3D
		var color := material.albedo_color
		color.a = clampf(_vignette, 0.0, 1.0) * 0.85
		material.albedo_color = color
	vignette_changed.emit(_vignette)


func vignette_strength() -> float:
	return _vignette if comfort_vignette_enabled else 0.0


func try_teleport(target: Vector3) -> bool:
	if not _active or not teleport_enabled or xr_origin == null:
		return false
	var head := _head_position()
	var horizontal_target := Vector3(target.x, head.y, target.z)
	if horizontal_target.distance_to(head) > teleport_max_distance:
		return false
	xr_origin.global_transform = translation_for_teleport(xr_origin.global_transform, head, horizontal_target)
	return true


static func locomotion_velocity(stick: Vector2, forward: Vector3, speed: float, deadzone: float = 0.0) -> Vector3:
	if stick.length_squared() <= deadzone * deadzone or forward.length_squared() <= 0.000001:
		return Vector3.ZERO
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length_squared() <= 0.000001:
		return Vector3.ZERO
	flat = flat.normalized()
	var right := flat.cross(Vector3.UP).normalized()
	var axis := right * stick.x - flat * stick.y
	return axis * maxf(speed, 0.0)


static func turn_delta(
	stick_x: float, mode: String, smooth_speed: float, snap_degrees: float,
	delta: float, deadzone: float = 0.0, can_step: bool = true
) -> float:
	if mode == "off" or delta <= 0.0 or absf(stick_x) <= deadzone:
		return 0.0
	if mode == "snap":
		if not can_step or absf(stick_x) < maxf(deadzone, 0.7):
			return 0.0
		return -signf(stick_x) * deg_to_rad(snap_degrees)
	if mode == "smooth":
		var span: float = maxf(1.0 - deadzone, 0.0001)
		var amount: float = clampf((absf(stick_x) - deadzone) / span, 0.0, 1.0)
		return -signf(stick_x) * amount * maxf(smooth_speed, 0.0) * delta
	return 0.0


static func rotate_around_y(xform: Transform3D, pivot: Vector3, yaw: float) -> Transform3D:
	var rotation := Basis().rotated(Vector3.UP, yaw)
	var result := xform
	result.basis = rotation * xform.basis
	result.origin = pivot + rotation * (xform.origin - pivot)
	return result


static func translation_for_teleport(xform: Transform3D, head: Vector3, target: Vector3) -> Transform3D:
	var shift := target - head
	shift.y = 0.0
	var result := xform
	result.origin += shift
	return result


static func compute_vignette(
	linear_speed: float, angular_speed: float,
	speed_ref: float = 3.0, angular_ref: float = 2.0
) -> float:
	var linear_part: float = clampf(linear_speed / maxf(speed_ref, 0.0001), 0.0, 1.0)
	var angular_part: float = clampf(angular_speed / maxf(angular_ref, 0.0001), 0.0, 1.0)
	return clampf(maxf(linear_part, angular_part), 0.0, 1.0)
