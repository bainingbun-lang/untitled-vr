class_name VrGlove
extends Node3D

const VrHandModelScript = preload("res://core/vr/vr_hand_model.gd")
const HandPoseScript = preload("res://core/vr/vr_hand_pose.gd")

const PATHS: Dictionary = {
	"left": "res://assets/models/hands/Hand_low_L.gltf",
	"right": "res://assets/models/hands/Hand_low_R.gltf",
}
const CHAINS: Dictionary = {
	"thumb": ["Thumb_Metacarpal", "Thumb_Proximal", "Thumb_Distal"],
	"index": ["Index_Proximal", "Index_Intermediate", "Index_Distal"],
	"middle": ["Middle_Proximal", "Middle_Intermediate", "Middle_Distal"],
	"ring": ["Ring_Proximal", "Ring_Intermediate", "Ring_Distal"],
	"pinky": ["Little_Proximal", "Little_Intermediate", "Little_Distal"],
}

var hand: String = "right"
var skeleton: Skeleton3D = null
var model_instance: Node3D = null
var curl_sign: float = -1.0
var last_values: Dictionary = {}
var _bones: Dictionary = {}
var _rest: Dictionary = {}
var _visible: bool = true
var _physics_bones: Dictionary = {}

func set_glove_visible(visible: bool) -> void:
	_visible = visible
	if model_instance != null:
		model_instance.visible = visible

func is_glove_visible() -> bool:
	return _visible

func build(hand_name: String) -> bool:
	hand = "left" if hand_name == "left" else "right"
	var path: String = PATHS[hand]
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	model_instance = packed.instantiate()
	name = "Glove_" + hand
	add_child(model_instance)
	skeleton = model_instance.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return false
	var suffix := "_L" if hand == "left" else "_R"
	for finger in CHAINS.keys():
		var ids: Array = []
		for bone_name in CHAINS[finger]:
			var id: int = skeleton.find_bone(str(bone_name) + suffix)
			ids.append(id)
			if id >= 0:
				_rest[id] = skeleton.get_bone_rest(id).basis.get_rotation_quaternion()
		_bones[finger] = ids
	_pick_curl_sign()
	set_pose(0.0, 0.0, "open")
	return true



func finger_tip(finger: String) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var tip_name := finger.capitalize().replace("Pinky", "Little") + "_Tip" + ("_L" if hand == "left" else "_R")
	var id: int = skeleton.find_bone(tip_name)
	if id < 0:
		return Vector3.ZERO
	return skeleton.get_bone_global_pose(id).origin

func palm_center() -> Vector3:
	if skeleton == null:
		return global_position
	var id: int = skeleton.find_bone("Palm" + ("_L" if hand == "left" else "_R"))
	if id < 0:
		return global_position
	return skeleton.get_bone_global_pose(id).origin

func _pick_curl_sign() -> void:
	curl_sign = -1.0
	set_pose(0.0, 0.0, "open")
	var open_distance: float = finger_tip("index").distance_to(palm_center())
	set_pose(1.0, 0.0, "grip")
	var closed_distance: float = finger_tip("index").distance_to(palm_center())
	if closed_distance > open_distance:
		curl_sign = 1.0

func set_pose(grip_value: float, trigger_value: float, zone: String = "grip") -> void:
	if skeleton == null:
		return
	last_values = HandPoseScript.pose(grip_value, trigger_value, zone, hand)
	var fingers: Dictionary = last_values["fingers"]
	for finger in _bones.keys():
		var ids: Array = _bones[finger]
		var angles: Array = fingers[finger]
		for i in ids.size():
			var id: int = ids[i]
			if id < 0:
				continue
			var rest: Quaternion = _rest[id]
			var bend := Quaternion(Vector3.RIGHT, curl_sign * float(angles[i]))
			skeleton.set_bone_pose_rotation(id, rest * bend)

func set_physics_pose(grip_value: float, trigger_value: float, zone: String = "grip") -> void:
	set_pose(grip_value, trigger_value, zone)

func get_hand_name() -> String:
	return hand

func get_skeleton() -> Skeleton3D:
	return skeleton

func get_model_instance() -> Node3D:
	return model_instance

func visible_mesh_count() -> int:
	var count := 0
	if model_instance == null:
		return 0
	for mesh in model_instance.find_children("*", "MeshInstance3D", true, false):
		if (mesh as MeshInstance3D).visible and (mesh as MeshInstance3D).mesh != null:
			count += 1
	return count

func curl_of(finger: String) -> float:
	if not last_values.has("fingers"):
		return 0.0
	return float((last_values["fingers"][finger] as Array)[0])