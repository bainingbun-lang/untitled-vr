class_name VrDistanceGrab
extends RefCounted

signal target_highlighted(target: Node3D, hand: String)
signal target_cleared(hand: String)
signal grabbed(target: Node3D, hand: String)

const MAX_DISTANCE: float = 6.0
const CONE_ANGLE_DEG: float = 8.0
const FLY_DURATION_MIN: float = 0.25
const FLY_DURATION_MAX: float = 0.35
const CLOSE_GRAB_RADIUS: float = 0.25
const HIGHLIGHT_EMISSION: Color = Color(1.0, 0.8, 0.2, 0.3)

var enabled: bool = true
var _hand: String = "right"
var _target: Node3D = null
var _target_material: StandardMaterial3D = null
var _original_emission: Color = Color(0, 0, 0, 0)
var _flying: bool = false
var _fly_start: Vector3 = Vector3.ZERO
var _fly_end: Vector3 = Vector3.ZERO
var _fly_start_time: float = 0.0
var _fly_duration: float = 0.3
var _space_state: PhysicsDirectSpaceState3D = null
var _cone_cos: float = 0.0
var _query: PhysicsRayQueryParameters3D = null

func _init(hand_name: String = "right") -> void:
	_hand = hand_name
	_cone_cos = cos(deg_to_rad(CONE_ANGLE_DEG))
	_query = PhysicsRayQueryParameters3D.new()
	_query.collision_mask = 1
	_query.exclude = []
	_query.hit_from_inside = false

func set_hand(hand_name: String) -> void:
	_hand = hand_name

func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		_clear_highlight()

func is_enabled() -> bool:
	return enabled

func _get_space_state(weapon_hand: Node) -> PhysicsDirectSpaceState3D:
	if _space_state == null or not is_instance_valid(_space_state):
		var world: World3D = weapon_hand.get_world_3d()
		_space_state = world.direct_space_state if world != null else null
	return _space_state

func step(delta: float, hand_pose: Transform3D, grip_pressed: bool, holsters, bag, weapon_hand: Node) -> void:
	if not enabled:
		return
	
	var space = _get_space_state(weapon_hand)
	if space == null:
		return
	
	if _flying:
		_update_fly(delta, hand_pose, weapon_hand)
		return
	
	var target: Node3D = _find_target(space, hand_pose, holsters, bag, weapon_hand)
	
	if target != _target:
		_clear_highlight()
		_target = target
		if target != null:
			_apply_highlight(target)
			target_highlighted.emit(target, _hand)
		else:
			target_cleared.emit(_hand)
	
	if _target != null and grip_pressed:
		_start_fly(hand_pose, weapon_hand)

func _find_target(space: PhysicsDirectSpaceState3D, hand_pose: Transform3D, holsters, bag, weapon_hand: Node) -> Node3D:
	var hand_pos: Vector3 = hand_pose.origin
	var hand_forward: Vector3 = -hand_pose.basis.z
	
	if holsters != null and bag != null and weapon_hand.weapon_id.is_empty():
		var nearest: Dictionary = holsters.nearest_slot(hand_pose)
		if bool(nearest["ok"]) and nearest["distance"] <= CLOSE_GRAB_RADIUS:
			return null
	
	var best_target: Node3D = null
	var best_score: float = 1.0e9
	
	for group in ["weapon_pickup", "grabbable", "physics_props"]:
		for node in weapon_hand.get_tree().get_nodes_in_group(group):
			if not (node is Node3D) or not is_instance_valid(node):
				continue
			if node == weapon_hand or (weapon_hand.holder != null and node == weapon_hand.holder):
				continue
			var target_pos: Vector3 = (node as Node3D).global_position
			var to_target: Vector3 = target_pos - hand_pos
			var distance: float = to_target.length()
			
			if distance > MAX_DISTANCE or distance <= 0.0001:
				continue
			
			var dir: Vector3 = to_target.normalized()
			var dot: float = hand_forward.dot(dir)
			
			if dot < _cone_cos:
				print("DEBUG: skipping target ", node.name, " dot=", dot, " cone_cos=", _cone_cos, " angle_deg=", rad_to_deg(acos(clampf(dot, -1.0, 1.0))))
				continue
			else:
				print("DEBUG: target in cone ", node.name, " dot=", dot, " cone_cos=", _cone_cos, " angle_deg=", rad_to_deg(acos(clampf(dot, -1.0, 1.0))))
			
			var angle_score: float = acos(clampf(dot, -1.0, 1.0))
			var score: float = angle_score * 100.0 + distance
			
			if score < best_score:
				best_score = score
				best_target = node as Node3D
	
	return best_target

func _apply_highlight(target: Node3D) -> void:
	var mesh: MeshInstance3D = _find_mesh(target)
	if mesh == null:
		return
	
	if mesh.material_override is StandardMaterial3D:
		_target_material = mesh.material_override as StandardMaterial3D
	else:
		_target_material = StandardMaterial3D.new()
		mesh.material_override = _target_material
	
	_original_emission = _target_material.emission
	_target_material.emission = HIGHLIGHT_EMISSION
	_target_material.emission_energy_multiplier = 1.0

func _clear_highlight() -> void:
	if _target_material != null and is_instance_valid(_target_material):
		_target_material.emission = _original_emission
	_target_material = null
	_original_emission = Color(0, 0, 0, 0)

func _find_mesh(node: Node3D) -> MeshInstance3D:
	if node is MeshInstance3D and node.mesh != null:
		return node
	for child in node.get_children():
		if child is Node3D:
			var found: MeshInstance3D = _find_mesh(child as Node3D)
			if found != null:
				return found
	return null

func _start_fly(hand_pose: Transform3D, weapon_hand) -> void:
	if _target == null or _flying:
		return
	
	_flying = true
	_fly_start = _target.global_position
	_fly_end = hand_pose.origin
	_fly_start_time = Time.get_ticks_msec() / 1000.0
	_fly_duration = randf_range(FLY_DURATION_MIN, FLY_DURATION_MAX)
	
	var controller = weapon_hand.input_provider
	if controller != null and controller.has_method("controller_for"):
		var ctrl = controller.call("controller_for", _hand)
		if ctrl != null and ctrl.has_method("trigger_haptic"):
			ctrl.call("trigger_haptic", 0.08, 0.5, 0.7)

func _update_fly(delta: float, hand_pose: Transform3D, weapon_hand) -> void:
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _fly_start_time
	var t: float = clampf(elapsed / _fly_duration, 0.0, 1.0)
	
	var ease_t: float = t * t * (3.0 - 2.0 * t)
	
	var current_pos: Vector3 = _fly_start.lerp(_fly_end, ease_t)
	
	if is_instance_valid(_target):
		_target.global_position = current_pos
	
	if t >= 1.0:
		_flying = false
		_finish_grab(weapon_hand)

func _finish_grab(weapon_hand) -> void:
	if _target == null or not is_instance_valid(_target):
		_clear_highlight()
		_target = null
		return
	
	var target = _target
	_clear_highlight()
	_target = null
	
	if target.has_meta("weapon_id") and weapon_hand.weapon_id.is_empty():
		var weapon_id: String = str(target.get_meta("weapon_id"))
		if not weapon_id.is_empty():
			weapon_hand.weapon_id = weapon_id
			weapon_hand._build_visual(weapon_id)
			if weapon_hand.use_physical_grab:
				weapon_hand.configure_handling()
				var pose: Transform3D = Transform3D(weapon_hand._aim_basis(weapon_hand._pose(_hand)), weapon_hand._pose(_hand).origin)
				weapon_hand.grab_weapon_from_pose(pose, 1.0, "grip")
			target.free()
			weapon_hand.weapon_taken.emit(weapon_id, _hand)
			weapon_hand.pulse(_hand, 0.06, 0.5, 0.6)
			grabbed.emit(target, _hand)
			return
	
	if target.is_in_group("physics_props") or target.is_in_group("grabbable"):
		var pose: Transform3D = weapon_hand._pose(_hand)
		if weapon_hand.grab_world_prop(target, weapon_hand.PROP_GRAB_RADIUS):
			weapon_hand.pulse(_hand, 0.05, 0.4, 0.5)
			grabbed.emit(target, _hand)

func cancel() -> void:
	_flying = false
	_clear_highlight()
	_target = null

func get_target() -> Node3D:
	return _target

func is_flying() -> bool:
	return _flying