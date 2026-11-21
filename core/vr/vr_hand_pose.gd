class_name VrHandPose
extends RefCounted

const FINGERS: Array[String] = ["thumb", "index", "middle", "ring", "pinky"]
const JOINTS: int = 3
const ZONE_BASE_CURL: Dictionary = {
	"grip": 0.78,
	"handguard": 0.48,
	"stock": 0.36,
	"magazine": 0.60,
	"slide": 0.62,
	"bolt": 0.62,
	"pump": 0.55,
	"trigger": 0.82,
	"open": 0.10,
}


static func clamp01(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return clampf(value, 0.0, 1.0)


static func joint_angles(curl_value: float, joint: int = 0) -> float:
	var amount: float = clamp01(curl_value)
	var proximal: float = 1.15
	var middle: float = 1.35
	var distal: float = 0.95
	var weights: Array = [proximal, middle, distal]
	var weight: float = float(weights[clampi(joint, 0, JOINTS - 1)])
	return deg_to_rad(90.0 * amount * weight)


static func finger_curl(finger: String, grip_value: float, trigger_value: float, zone: String) -> float:
	var grip: float = clamp01(grip_value)
	var trigger: float = clamp01(trigger_value)
	var base: float = clamp01(ZONE_BASE_CURL.get(zone, 0.60))
	var curl: float = base * (0.35 + 0.65 * grip)
	if finger == "index":
		curl = maxf(curl, trigger * 0.85)
	elif finger == "thumb":
		curl = clampf(curl * 0.72 + 0.12, 0.0, 1.0)
	elif finger == "middle":
		curl = clampf(curl * 0.96, 0.0, 1.0)
	elif finger == "ring":
		curl = clampf(curl * 0.90, 0.0, 1.0)
	elif finger == "pinky":
		curl = clampf(curl * 0.84, 0.0, 1.0)
	return clamp01(curl)


static func pose(grip_value: float = 1.0, trigger_value: float = 0.0, zone: String = "grip", hand: String = "right") -> Dictionary:
	var fingers: Dictionary = {}
	for finger in FINGERS:
		var curl: float = finger_curl(finger, grip_value, trigger_value, zone)
		var angles: Array = []
		for joint in JOINTS:
			angles.append(joint_angles(curl, joint))
		fingers[finger] = angles
	var wrist: float = deg_to_rad(-8.0 * clamp01(grip_value))
	return {
		"hand": "left" if hand == "left" else "right",
		"zone": zone,
		"grip": clamp01(grip_value),
		"trigger": clamp01(trigger_value),
		"fingers": fingers,
		"wrist": wrist,
	}


static func two_hand_pose(
	primary_zone: String, secondary_zone: String,
	primary_grip: float = 1.0, secondary_grip: float = 1.0,
	primary_trigger: float = 0.0, secondary_trigger: float = 0.0,
	primary_hand: String = "right", secondary_hand: String = "left"
) -> Dictionary:
	var primary: Dictionary = pose(primary_grip, primary_trigger, primary_zone, primary_hand)
	var secondary: Dictionary = pose(secondary_grip, secondary_trigger, secondary_zone, secondary_hand)
	return {
		"primary": primary,
		"secondary": secondary,
		"primary_zone": primary_zone,
		"secondary_zone": secondary_zone,
		"mixed": primary_zone != secondary_zone,
	}


static func angle_for(node_name: String, values: Dictionary) -> float:
	var parts: PackedStringArray = node_name.split("_")
	if parts.size() < 3 or not values.has("fingers"):
		return 0.0
	var fingers: Dictionary = values["fingers"]
	var finger: String = parts[1]
	if not fingers.has(finger):
		return 0.0
	var chain: Array = fingers[finger]
	var joint: int = int(parts[2]) - 1
	if joint < 0 or joint >= chain.size():
		return 0.0
	return float(chain[joint])


static func apply_to(node: Node, values: Dictionary) -> int:
	if node == null or not is_instance_valid(node):
		return 0
	var changed: int = 0
	for child in node.find_children("*", "Node3D", true, false):
		var part: Node3D = child as Node3D
		if part == null:
			continue
		var name: String = part.name
		if not name.begins_with("Finger_"):
			continue
		var angle: float = angle_for(name, values)
		part.rotation.x = angle
		changed += 1
	return changed
