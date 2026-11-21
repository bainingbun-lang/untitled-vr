class_name VrRig
extends Node3D

signal activated()
signal vignette_changed(strength: float)
signal menu_pressed()
signal reload_requested(hand: String)
signal health_changed(current: float, maximum: float)
signal died()
signal recentered()

const VrHandModelScript = preload("res://core/vr/vr_hand_model.gd")
const VrBagScript = preload("res://core/vr/vr_bag.gd")
const VrWeaponHandScript = preload("res://core/vr/vr_weapon_hand.gd")
const VrClimbScript = preload("res://core/vr/vr_climb.gd")
const DbScript = preload("res://core/game/weapon_db.gd")
const VrComfortScript = preload("res://core/vr/vr_comfort.gd")
const VrInputScript = load("res://core/vr/vr_input.gd")

@export var move_speed: float = 2.2
@export var turn_mode: String = "smooth"
@export var smooth_turn_speed: float = 1.6
@export var snap_turn_degrees: float = 30.0
@export var stick_deadzone: float = 0.2
@export var snap_threshold: float = 0.7
@export var snap_cooldown: float = 0.25
@export var comfort_vignette_enabled: bool = true
@export var vignette_intensity: float = 0.85
@export var vignette_speed_ref: float = 3.0
@export var vignette_angular_ref: float = 2.0
@export var teleport_enabled: bool = false
@export var teleport_max_distance: float = 5.0
@export var seated_mode: bool = false
@export var height_offset: float = 0.0
@export var auto_process: bool = true
@export var climb_enabled: bool = true
@export var climb_forward_push: float = 1.0
@export var climb_fling_multiplier: float = 1.0
@export var climb_velocity_averages: int = 5
const BODY_RADIUS: float = 0.25

var xr_availability_override: Callable = Callable()
var xr_interface = null
var xr_origin: XROrigin3D = null
var floor_fix_delay: float = 1.5
var default_eye_height: float = 1.65
var floor_offset: float = 0.0
var _floor_timer: float = 0.0
var _floor_checked: bool = false
var xr_camera: XRCamera3D = null
var left_controller = null
var right_controller = null
var left_hand = null
var hand_models: Dictionary = {}
var right_hand = null
var bag = null
var weapon_system: Node = null
var input_provider = null
var vr_input = null

var health: float = 100.0
var max_health: float = 100.0
var inputs_suspended: bool = false

var _was_menu: bool = false
var _reload_was: Dictionary = {}
var _climb_grip_was: Dictionary = {}
var _active: bool = false
var _built: bool = false
var _xr_origin: XROrigin3D = null
var _snap_timer: float = 0.0
var _body_shape: CapsuleShape3D = null
var _vignette: float = 0.0
var _vignette_ring: MeshInstance3D = null
var _climb: VrClimb = null


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
	xr_origin.world_scale = 1.0
	xr_origin.current = true

	xr_camera = XRCamera3D.new()
	xr_camera.name = "XRCamera3D"
	xr_origin.add_child(xr_camera)
	xr_camera.current = true

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

	for pair in [["left", left_controller], ["right", right_controller]]:
		var model = VrHandModelScript.new()
		if model.build(pair[0]):
			pair[1].add_child(model)
			hand_models[pair[0]] = model
		else:
			model.free()

	bag = VrBagScript.new(DbScript.list_ids())
	left_hand = _make_hand("left")
	right_hand = _make_hand("right")
	add_child(left_hand)
	add_child(right_hand)

	vr_input = VrInputScript.new(self)
	var initialized = vr_input.initialize(xr_interface)
	set_input_provider(vr_input)
	if not initialized:
		vr_input.set_simulated(true)

	if climb_enabled:
		_climb = VrClimbScript.new()
		_climb.forward_push = climb_forward_push
		_climb.fling_multiplier = climb_fling_multiplier
		_climb.velocity_averages = climb_velocity_averages
		_climb.setup(self)

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
	var provider = _provider()
	if provider != null and provider.has_method("get_pose"):
		return provider.get_pose(hand_name)
	var controller = controller_for(hand_name)
	if controller == null:
		return Transform3D.IDENTITY
	return controller.global_transform


func is_grip_pressed(hand_name: String) -> bool:
	var provider = _provider()
	if provider != null and provider.has_method("is_grip_pressed"):
		return provider.is_grip_pressed(hand_name)
	var controller = controller_for(hand_name)
	if controller == null:
		return false
	if controller.has_method("is_button_pressed") and bool(controller.call("is_button_pressed", &"grip")):
		return true
	return controller.has_method("get_float") and float(controller.call("get_float", &"grip")) > 0.5


func is_trigger_pressed(hand_name: String) -> bool:
	var provider = _provider()
	if provider != null and provider.has_method("is_trigger_pressed"):
		return provider.is_trigger_pressed(hand_name)
	var controller = controller_for(hand_name)
	if controller == null:
		return false
	if controller.has_method("is_button_pressed") and bool(controller.call("is_button_pressed", &"trigger")):
		return true
	return controller.has_method("get_float") and float(controller.call("get_float", &"trigger")) > 0.5


func get_stick(hand_name: String) -> Vector2:
	var provider = _provider()
	if provider != null and provider.has_method("get_stick"):
		return provider.get_stick(hand_name)
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


func _ensure_floor_height(delta: float) -> void:
	if _floor_checked or xr_camera == null or xr_origin == null:
		return
	_floor_timer += maxf(delta, 0.0)
	if _floor_timer < floor_fix_delay:
		return
	_floor_checked = true
	if xr_interface != null and xr_interface.has_method("get_play_area_mode") \
			and int(xr_interface.call("get_play_area_mode")) >= 3:
		return
	var eye: float = xr_camera.position.y
	if eye < 0.5 and eye > -0.5:
		floor_offset = default_eye_height - eye
		xr_origin.position.y += floor_offset


func _update_hand_models() -> void:
	for hand_name in hand_models.keys():
		var model = hand_models[hand_name]
		var controller = controller_for(hand_name)
		var grip: float = 0.0
		var trigger: float = 0.0
		if controller != null and controller.has_method("get_float"):
			grip = float(controller.call("get_float", &"grip"))
			trigger = float(controller.call("get_float", &"trigger"))
		else:
			grip = 1.0 if is_grip_pressed(hand_name) else 0.0
			trigger = 1.0 if is_trigger_pressed(hand_name) else 0.0
		var node = left_hand if hand_name == "left" else right_hand
		var zone := "grip"
		if node != null and str(node.weapon_id).is_empty():
			zone = "magazine"
		model.set_pose(grip, trigger, zone)


func step(delta: float) -> void:
	_ensure_floor_height(delta)
	_update_hand_models()
	_poll_buttons()
	if inputs_suspended:
		return
	if bag != null and xr_camera != null:
		bag.set_head_transform(xr_camera.global_transform)
	
	# Climbing physics (runs before locomotion to override gravity)
	if _climb != null and climb_enabled and xr_origin != null:
		var did_climb: bool = _climb.physics_movement(delta, xr_origin, not climb_enabled)
		if did_climb:
			# Climbing handled movement, skip gravity for this frame
			pass
	
	step_locomotion(delta)
	if left_hand != null:
		left_hand.step(delta)
	if right_hand != null:
		right_hand.step(delta)
	_update_vignette(delta)


func _poll_buttons() -> void:
	var menu_down: bool = bool(_call_provider("is_menu_pressed", ["left"], false))
	if menu_down and not _was_menu:
		menu_pressed.emit()
	_was_menu = menu_down
	for hand_name in ["left", "right"]:
		var down: bool = bool(_call_provider("is_reload_pressed", [hand_name], false))
		if down and not bool(_reload_was.get(hand_name, false)):
			reload_requested.emit(hand_name)
			var hand_node = left_hand if hand_name == "left" else right_hand
			if hand_node != null and hand_node.has_method("try_reload"):
				hand_node.call("try_reload")
		_reload_was[hand_name] = down
	
	# Climbing grip detection
	if _climb != null and climb_enabled:
		for hand_name in ["left", "right"]:
			var grip_pressed: bool = is_grip_pressed(hand_name)
			var hand_node = left_hand if hand_name == "left" else right_hand
			var hand_empty: bool = hand_node != null and str(hand_node.weapon_id).is_empty()
			
			# Track grip state for climb
			var was_grip: bool = bool(_climb_grip_was.get(hand_name, false))
			_climb_grip_was[hand_name] = grip_pressed
			
			if grip_pressed and not was_grip and hand_empty:
				_try_climb_grab(hand_name)
			elif not grip_pressed and was_grip:
				# Grip released
				if hand_name == "left":
					_climb.on_left_dropped()
				else:
					_climb.on_right_dropped()


func set_inputs_suspended(value: bool) -> void:
	inputs_suspended = value
	if value:
		if left_hand != null and left_hand.has_method("reset_buttons"):
			left_hand.call("reset_buttons")
		if right_hand != null and right_hand.has_method("reset_buttons"):
			right_hand.call("reset_buttons")


func is_menu_pressed(hand_name: String = "left") -> bool:
	return _controller_button(hand_name, &"menu")


func is_reload_pressed(hand_name: String = "right") -> bool:
	return _controller_button(hand_name, &"a") or _controller_button(hand_name, &"x")


func _controller_button(hand_name: String, action: StringName) -> bool:
	if not _active:
		return false
	var provider = _provider()
	if provider != null and provider.has_method("is_button_pressed"):
		return provider.is_button_pressed(hand_name, str(action))
	var controller = controller_for(hand_name)
	if controller == null or not controller.has_method("is_button_pressed"):
		return false
	return bool(controller.call("is_button_pressed", action))


func _try_climb_grab(hand_name: String) -> void:
	if _climb == null or xr_origin == null:
		return
	var controller = controller_for(hand_name)
	if controller == null:
		return
	
	var space = get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return
	
	# Raycast from controller to find climbable objects
	var query = PhysicsRayQueryParameters3D.new()
	query.from = controller.global_position
	query.to = controller.global_position + (-controller.global_transform.basis.z) * 1.5
	query.collision_mask = 1  # Default physics layer for static bodies
	query.exclude = [xr_origin.get_rid()] if xr_origin else []
	
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return
	
	var collider: Node3D = result.collider as Node3D
	if collider == null:
		return
	
	# Check if collider has VrClimbable
	var climbable = _find_climbable(collider)
	if climbable == null:
		return
	
	# Notify climb system
	if hand_name == "left":
		_climb.on_left_picked_up(climbable)
	else:
		_climb.on_right_picked_up(climbable)


func _find_climbable(node: Node) -> Node:
	var current := node
	while current != null:
		if current is VrClimbable:
			return current
		if current.has_method("get_parent"):
			current = current.get_parent()
		else:
			break
	return null


func take_damage(amount: float, _point: Vector3 = Vector3.ZERO, _normal: Vector3 = Vector3.UP, _attacker = null) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit()


func heal_to_full() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func step_locomotion(delta: float) -> void:
	if xr_origin == null or delta <= 0.0:
		return
	var move_stick: Vector2 = _call_provider("get_stick", ["left"], Vector2.ZERO)
	var turn_stick: Vector2 = _call_provider("get_stick", ["right"], Vector2.ZERO)
	var forward_ref = _hand_forward() if seated_mode else _head_forward()
	var velocity := locomotion_velocity(move_stick, forward_ref, move_speed, stick_deadzone)
	if velocity.length_squared() > 0.000001:
		xr_origin.global_position += _slide_motion(velocity * delta)
	var can_step: bool = _snap_timer <= 0.0
	var yaw := turn_delta(
		turn_stick.x, turn_mode, smooth_turn_speed, snap_turn_degrees,
		delta, stick_deadzone, can_step, snap_threshold
	)
	if absf(yaw) > 0.000001:
		var pivot := _hand_position() if seated_mode else _head_position()
		xr_origin.global_transform = rotate_around_y(xr_origin.global_transform, pivot, yaw)
		if turn_mode == "snap":
			_snap_timer = snap_cooldown
	_snap_timer = maxf(_snap_timer - delta, 0.0)
	if absf(turn_stick.x) < snap_threshold:
		_snap_timer = 0.0


func _body_blocked(motion: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null or motion.length_squared() <= 0.0000001:
		return motion
	if _body_shape == null:
		_body_shape = CapsuleShape3D.new()
		_body_shape.radius = BODY_RADIUS
		_body_shape.height = 1.2
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _body_shape
	query.collision_mask = 1
	query.transform = Transform3D(Basis.IDENTITY, xr_origin.global_position + Vector3(0.0, 0.9, 0.0))
	var core := CapsuleShape3D.new()
	core.radius = BODY_RADIUS * 0.4
	core.height = 1.0
	query.shape = core
	if _hits_static(space.intersect_shape(query, 4)):
		return motion
	query.shape = _body_shape
	var passable: Array[RID] = []
	for entry in space.intersect_shape(query, 8):
		if not (entry["collider"] is StaticBody3D):
			passable.append(entry["rid"])
	query.exclude = passable
	var rest: Dictionary = space.get_rest_info(query)
	if not rest.is_empty():
		var away: Vector3 = query.transform.origin - (rest["point"] as Vector3)
		away.y = 0.0
		if away.length_squared() > 0.00000001:
			away = away.normalized()
			motion -= away * minf(motion.dot(away), 0.0)
			if motion.length_squared() <= 0.0000001:
				return Vector3.ZERO
	query.motion = motion
	var fractions: PackedFloat32Array = space.cast_motion(query)
	return motion * fractions[0] if not fractions.is_empty() else motion


static func _hits_static(results: Array) -> bool:
	for entry in results:
		if entry["collider"] is StaticBody3D:
			return true
	return false


func _slide_motion(motion: Vector3) -> Vector3:
	var full := _body_blocked(motion)
	if full.is_equal_approx(motion):
		return motion
	var along_x := _body_blocked(Vector3(motion.x, 0.0, 0.0))
	var along_z := _body_blocked(Vector3(0.0, 0.0, motion.z))
	var best := full
	for candidate in [along_x, along_z]:
		if candidate.length_squared() > best.length_squared():
			best = candidate
	return best


func _head_forward() -> Vector3:
	if xr_camera == null:
		return Vector3.FORWARD
	var forward := -xr_camera.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.000001 else Vector3.FORWARD


func _head_position() -> Vector3:
	return xr_camera.global_position if xr_camera != null else global_position


func _hand_forward() -> Vector3:
	var controller: XRController3D = controller_for("right") as XRController3D
	if controller == null:
		return _head_forward()
	var forward: Vector3 = -controller.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.000001 else Vector3.FORWARD


func _hand_position() -> Vector3:
	var controller = controller_for("right")
	if controller == null:
		return _head_position()
	return controller.global_position


func _update_vignette(delta: float) -> void:
	if not comfort_vignette_enabled:
		_vignette = 0.0
		if _vignette_ring != null and _vignette_ring.material_override is StandardMaterial3D:
			var material := _vignette_ring.material_override as StandardMaterial3D
			var color := material.albedo_color
			color.a = 0.0
			material.albedo_color = color
		vignette_changed.emit(0.0)
		return
	var move_stick: Vector2 = _call_provider("get_stick", ["left"], Vector2.ZERO)
	var turn_stick: Vector2 = _call_provider("get_stick", ["right"], Vector2.ZERO)
	var linear: float = locomotion_velocity(move_stick, _head_forward(), move_speed, stick_deadzone).length()
	var angular: float = absf(turn_delta(
		turn_stick.x, turn_mode, smooth_turn_speed, snap_turn_degrees,
		delta, stick_deadzone, false, snap_threshold
	)) / maxf(delta, 0.0001)
	_vignette = VrComfortScript.compute_vignette(linear, angular, vignette_speed_ref, vignette_angular_ref, vignette_intensity)
	if _vignette_ring != null and _vignette_ring.material_override is StandardMaterial3D:
		var material := _vignette_ring.material_override as StandardMaterial3D
		var color := material.albedo_color
		color.a = clampf(_vignette, 0.0, 1.0)
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


func recenter() -> void:
	if xr_interface != null and xr_interface.has_method("recenter_pose"):
		xr_interface.call("recenter_pose")
	recentered.emit()


func set_seated_mode(enabled: bool) -> void:
	seated_mode = enabled
	if enabled and height_offset == 0.0:
		height_offset = -0.3
	elif not enabled:
		height_offset = 0.0
	if xr_origin != null and xr_camera != null:
		var head_pos := _head_position()
		var adjusted := VrComfortScript.apply_seated_height(head_pos, height_offset, default_eye_height)
		xr_origin.global_position.y += (adjusted.y - head_pos.y)


func apply_comfort_profile(profile: Dictionary) -> void:
	var validated := VrComfortScript.validate_profile(profile)
	if not bool(validated["ok"]):
		return
	profile = validated["profile"]
	move_speed = profile["move_speed"]
	turn_mode = profile["turn_mode"]
	smooth_turn_speed = profile["smooth_turn_speed"]
	snap_turn_degrees = profile["snap_turn_degrees"]
	snap_cooldown = profile["snap_cooldown"]
	stick_deadzone = profile["stick_deadzone"]
	snap_threshold = profile["snap_threshold"]
	comfort_vignette_enabled = profile["comfort_vignette_enabled"]
	vignette_intensity = profile["vignette_intensity"]
	vignette_speed_ref = profile["vignette_speed_ref"]
	vignette_angular_ref = profile["vignette_angular_ref"]
	teleport_enabled = profile["teleport_enabled"]
	teleport_max_distance = profile["teleport_max_distance"]
	seated_mode = profile["seated_mode"]
	height_offset = profile["height_offset"]
	set_seated_mode(seated_mode)


static func locomotion_velocity(stick: Vector2, forward: Vector3, speed: float, deadzone: float = 0.0) -> Vector3:
	return VrComfortScript.locomotion_velocity(stick, forward, speed, deadzone)


static func locomotion_velocity_hand(stick: Vector2, hand_forward: Vector3, speed: float, deadzone: float = 0.0) -> Vector3:
	if stick.length_squared() <= deadzone * deadzone or hand_forward.length_squared() <= 0.000001:
		return Vector3.ZERO
	var flat := Vector3(hand_forward.x, 0.0, hand_forward.z)
	if flat.length_squared() <= 0.000001:
		return Vector3.ZERO
	flat = flat.normalized()
	var right := flat.cross(Vector3.UP).normalized()
	var axis := right * stick.x - flat * stick.y
	return axis * maxf(speed, 0.0)


static func turn_delta(
	stick_x: float, mode: String, smooth_speed: float, snap_degrees: float,
	delta: float, deadzone: float = 0.0, can_step: bool = true,
	snap_threshold: float = 0.7
) -> float:
	return VrComfortScript.turn_delta(stick_x, mode, smooth_speed, snap_degrees, delta, deadzone, can_step, snap_threshold)


static func rotate_around_y(xform: Transform3D, pivot: Vector3, yaw: float) -> Transform3D:
	return VrComfortScript.rotate_around_y(xform, pivot, yaw)


static func translation_for_teleport(xform: Transform3D, head: Vector3, target: Vector3) -> Transform3D:
	return VrComfortScript.translation_for_teleport(xform, head, target)


static func compute_vignette(
	linear_speed: float, angular_speed: float,
	speed_ref: float = 3.0, angular_ref: float = 2.0
) -> float:
	return VrComfortScript.compute_vignette(linear_speed, angular_speed, speed_ref, angular_ref)