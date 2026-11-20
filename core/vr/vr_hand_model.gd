class_name VrHandModel
extends Node3D

# Mano visible (godot-xr-tools Hand_low, CC0) con huesos de dedos; la pose sale de VrHandPose.

const PoseScript = preload("res://core/vr/vr_hand_pose.gd")
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
var curl_sign: float = -1.0
var last_values: Dictionary = {}
var _bones: Dictionary = {}
var _rest: Dictionary = {}


func build(hand_name: String) -> bool:
	hand = "left" if hand_name == "left" else "right"
	var path: String = PATHS[hand]
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var instance := packed.instantiate()
	name = "HandModel_" + hand
	add_child(instance)
	skeleton = instance.find_child("Skeleton3D", true, false) as Skeleton3D
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


func visible_mesh_count() -> int:
	var count := 0
	for mesh in find_children("*", "MeshInstance3D", true, false):
		if (mesh as MeshInstance3D).visible and (mesh as MeshInstance3D).mesh != null:
			count += 1
	return count


func finger_tip(finger: String) -> Vector3:
	var id: int = skeleton.find_bone(finger.capitalize().replace("Pinky", "Little") + "_Tip" + ("_L" if hand == "left" else "_R"))
	if id < 0 or skeleton == null:
		return Vector3.ZERO
	return skeleton.get_bone_global_pose(id).origin


func palm_center() -> Vector3:
	var id: int = skeleton.find_bone("Palm" + ("_L" if hand == "left" else "_R"))
	if id < 0:
		return global_position
	return skeleton.get_bone_global_pose(id).origin


# El eje de curvado depende del hueso: se prueba el signo que acerca la punta del indice a la palma.
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
	last_values = PoseScript.pose(grip_value, trigger_value, zone, hand)
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


func curl_of(finger: String) -> float:
	if not last_values.has("fingers"):
		return 0.0
	return float((last_values["fingers"][finger] as Array)[0])
