class_name HandsViewmodel
extends Node3D

const ARMS_MODEL_PATH: String = "res://assets/models/weapons/v2/fps_arms.glb"
const HAND_LEFT_PATH: String = "res://assets/models/hands/Hand_low_L.gltf"
const HAND_RIGHT_PATH: String = "res://assets/models/hands/Hand_low_R.gltf"

const GRIPS: Dictionary = {
	"pistol": {"right": Vector3(0.01, -0.07, 0.02), "left": Vector3(-0.02, -0.035, -0.06)},
	"submachine_gun": {"right": Vector3(0.01, -0.08, 0.06), "left": Vector3(-0.025, -0.055, -0.20)},
	"assault_rifle": {"right": Vector3(0.01, -0.075, 0.10), "left": Vector3(-0.03, -0.055, -0.40)},
	"shotgun": {"right": Vector3(0.01, -0.08, 0.12), "left": Vector3(-0.03, -0.05, -0.46)},
	"sniper_rifle": {"right": Vector3(0.01, -0.08, 0.12), "left": Vector3(-0.03, -0.05, -0.55)},
	"bat": {"right": Vector3(0.01, -0.09, 0.08), "left": Vector3(-0.025, -0.07, -0.22)},
}

const DEFAULT_GRIP: Dictionary = {
	"right": Vector3(0.01, -0.07, 0.04),
	"left": Vector3(-0.025, -0.05, -0.28),
}

const ARMS_SCALE: float = 0.05

var _weapon_id: String = ""
var _arms: Node3D = null
var _skeleton: Skeleton3D = null
var _wrist_r: int = -1
var _wrist_l: int = -1
var _forearm_r: int = -1
var _forearm_l: int = -1
var _vr_left: Node3D = null
var _vr_right: Node3D = null
var _vr_attached: Dictionary = {}
var _reload_phase: String = ""
var _recoil_blend: float = 0.0
var _last_right: Vector3 = Vector3.ZERO
var _last_left: Vector3 = Vector3.ZERO


func _ready() -> void:
	_ensure_hands()


func _viewmodel() -> Node:
	var node := get_parent()
	var guard := 0
	while node != null and guard < 6:
		if node.has_method("current_weapon"):
			return node
		node = node.get_parent()
		guard += 1
	return null


func _process(delta: float) -> void:
	_ensure_hands()
	var vm := _viewmodel()
	if vm == null or not vm.has_method("current_weapon"):
		return
	var id := str(vm.call("current_weapon"))
	if id != _weapon_id:
		set_weapon(id)
	if vm.has_method("reload_phase"):
		_reload_phase = str(vm.call("reload_phase"))
	else:
		_reload_phase = ""
	var recoil := Vector3.ZERO
	if vm.has_method("recoil_offset"):
		recoil = vm.call("recoil_offset")
	var rig_pos := Vector3.ZERO
	if vm.has_method("rig_position"):
		rig_pos = vm.call("rig_position")
	position = rig_pos + recoil
	if vm.has_method("rig_rotation"):
		rotation_degrees = vm.call("rig_rotation")
	_recoil_blend = lerpf(_recoil_blend, clampf(recoil.length() * 1.6, 0.0, 1.0), clampf(delta * 12.0, 0.0, 1.0))
	_apply_arms(delta)


func _ensure_hands() -> void:
	if is_instance_valid(_arms):
		return
	if ResourceLoader.exists(ARMS_MODEL_PATH):
		var packed := load(ARMS_MODEL_PATH) as PackedScene
		if packed != null:
			var instance := packed.instantiate()
			if instance is Node3D:
				_arms = instance as Node3D
				_arms.name = "RealArms"
				_arms.scale = Vector3(ARMS_SCALE, ARMS_SCALE, ARMS_SCALE)
				_arms.position = Vector3(-0.18, 0.10, 0.16)
				add_child(_arms)
				_skeleton = _find_skeleton(_arms)
				if _skeleton != null:
					_wrist_r = _find_bone_like("wrist.r")
					_wrist_l = _find_bone_like("wrist.l")
					_forearm_r = _find_bone_like("forearm.r")
					_forearm_l = _find_bone_like("forearm.l")
	_vr_left = _make_vr_hand("left", HAND_LEFT_PATH)
	_vr_right = _make_vr_hand("right", HAND_RIGHT_PATH)


func _make_vr_hand(side: String, path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate()
	if not instance is Node3D:
		return null
	var hand := instance as Node3D
	hand.name = "VRHand_%s" % side
	hand.scale = Vector3(0.95, 0.95, 0.95)
	hand.visible = false
	add_child(hand)
	return hand


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D and (node as Skeleton3D).get_bone_count() > 0:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_bone_like(token: String) -> int:
	if _skeleton == null:
		return -1
	for i in range(_skeleton.get_bone_count()):
		var name := String(_skeleton.get_bone_name(i)).to_lower().replace("_", ".").replace("-", ".")
		if name == token or name.ends_with(token) or name.contains(token):
			return i
	return -1


func set_weapon(id: String) -> void:
	_weapon_id = id
	_reload_phase = ""
	_apply_arms(0.016)


func has_hands() -> bool:
	return is_instance_valid(_arms) and _skeleton != null


func model_instance() -> Node:
	return _arms


func grip_for(side: String) -> Vector3:
	var grip: Dictionary = GRIPS.get(_weapon_id, DEFAULT_GRIP)
	return grip.get(side, Vector3.ZERO)


func grip_position(side: String) -> Vector3:
	if not is_inside_tree():
		return grip_for(side)
	var vm := _viewmodel()
	if vm != null and vm.has_method("to_global"):
		return (vm as Node3D).to_global(grip_for(side))
	return to_global(grip_for(side))


func vr_hand(side: String) -> Node3D:
	if side == "left":
		return _vr_left
	return _vr_right


func attach_hand_to_controller(side: String, controller: Node) -> bool:
	if controller == null or not controller is Node3D:
		return false
	var hand := vr_hand(side)
	if hand == null or not is_instance_valid(hand):
		return false
	hand.reparent(controller, false)
	hand.transform = Transform3D.IDENTITY
	hand.visible = true
	hand.name = "VRHand_%s" % side
	_vr_attached[side] = true
	return true


func is_vr_attached(side: String) -> bool:
	return _vr_attached.get(side) == true


func reload_blend() -> float:
	return clampf(_recoil_blend, 0.0, 1.0)


func wrist_position(side: String) -> Vector3:
	if side == "right":
		return _last_right
	return _last_left


func _apply_arms(delta: float) -> void:
	if _skeleton == null or not is_instance_valid(_arms):
		return
	var right := grip_for("right")
	var left := grip_for("left")
	var vm := _viewmodel()
	if vm != null and _reload_phase == "insert_mag" and vm.has_method("parts"):
		var parts = vm.call("parts")
		if parts != null and parts.has_method("node"):
			var magazine: Node3D = parts.call("node", "magazine")
			if magazine != null and is_instance_valid(magazine) and vm.has_method("to_local"):
				var local := (vm as Node3D).to_local(magazine.global_position)
				left = lerp(left, local + Vector3(-0.05, 0.02, 0.0), 0.75)
	if vm != null and _reload_phase == "charge" and vm.has_method("part_offset"):
		var offset: Vector3 = vm.call("part_offset", "bolt")
		if offset.length_squared() > 0.0001:
			left += Vector3(0.0, 0.015, 0.0) + offset * 0.15
	var sway := Vector3(0.0, 0.0, _recoil_blend * -0.012)
	right += sway
	left += sway * 0.7
	_last_right = right
	_last_left = left
	_set_wrist(_wrist_r, _forearm_r, right)
	_set_wrist(_wrist_l, _forearm_l, left)
	if delta > 0.0 and _recoil_blend > 0.0:
		_arms.rotation_degrees.x = lerpf(_arms.rotation_degrees.x, -_recoil_blend * 2.5, clampf(delta * 10.0, 0.0, 1.0))
	else:
		_arms.rotation_degrees.x = lerpf(_arms.rotation_degrees.x, 0.0, clampf(delta * 6.0, 0.0, 1.0))


func _set_wrist(wrist_idx: int, forearm_idx: int, target_in_rig: Vector3) -> void:
	if wrist_idx < 0 or not is_inside_tree():
		return
	var vm := _viewmodel()
	var world_target := Vector3.ZERO
	if vm is Node3D:
		world_target = (vm as Node3D).to_global(target_in_rig)
	else:
		world_target = to_global(target_in_rig)
	var local_target := _skeleton.to_local(world_target)
	var pose := _skeleton.get_bone_global_pose(wrist_idx)
	pose.origin = local_target
	_skeleton.set_bone_global_pose(wrist_idx, pose)
	if forearm_idx >= 0:
		var forearm_pose := _skeleton.get_bone_global_pose(forearm_idx)
		forearm_pose.origin = forearm_pose.origin.lerp(local_target, 0.62)
		_skeleton.set_bone_global_pose(forearm_idx, forearm_pose)
