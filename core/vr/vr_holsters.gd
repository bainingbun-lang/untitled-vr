class_name VrHolsters
extends RefCounted

signal stowed(item_id: String, slot: String, hand: String)
signal drawn(item_id: String, slot: String, hand: String)
signal haptic(hand: String, duration: float, amplitude: float)

const SLOTS: Dictionary = {
	"hip": {"offset": Vector3(0.18, -0.36, 0.02), "radius": 0.16},
	"back": {"offset": Vector3(0.0, 0.02, 0.24), "radius": 0.18},
	"chest": {"offset": Vector3(0.0, -0.20, -0.16), "radius": 0.13},
	"bag": {"offset": Vector3(0.26, -0.34, 0.32), "radius": 0.20},
}
const LONG_GUN_TAGS: Array = ["rifle", "sniper", "shotgun", "smg"]

var head_transform: Transform3D = Transform3D.IDENTITY
var _slots: Dictionary = {}
var _location: Dictionary = {}
var _events: Array = []


func _init() -> void:
	reset()


func reset() -> void:
	for slot in SLOTS.keys():
		_slots[slot] = ""
	_location.clear()
	_events.clear()


func set_head_pose(xform: Transform3D) -> void:
	head_transform = xform


static func normalized_safe(value: Vector3, fallback: Vector3) -> Vector3:
	var result := value
	if is_nan(result.x) or is_nan(result.y) or is_nan(result.z) or result.length_squared() <= 0.000001:
		return fallback
	return result.normalized()


func slot_position(slot: String) -> Vector3:
	if not SLOTS.has(slot):
		return head_transform.origin
	var local: Vector3 = (SLOTS[slot] as Dictionary)["offset"]
	var basis: Basis = head_transform.basis
	return head_transform.origin + basis.x * local.x + basis.y * local.y + basis.z * local.z


func slot_radius(slot: String) -> float:
	if not SLOTS.has(slot):
		return 0.01
	return maxf(float((SLOTS[slot] as Dictionary)["radius"]), 0.01)


func nearest_slot(hand_pose: Transform3D, radius_scale: float = 1.0) -> Dictionary:
	var best := ""
	var best_distance: float = 1.0e9
	for slot in SLOTS.keys():
		var distance: float = hand_pose.origin.distance_to(slot_position(str(slot)))
		if distance < best_distance:
			best_distance = distance
			best = str(slot)
	var limit: float = slot_radius(best) * maxf(radius_scale, 0.0)
	return {
		"slot": best if best_distance <= limit else "",
		"distance": best_distance,
		"ok": best_distance <= limit,
	}


static func item_kind(item_id: String, tags: Array = []) -> String:
	if tags.has("magazine"):
		return "magazine"
	if tags.has("rifle") or tags.has("sniper") or tags.has("shotgun") or tags.has("smg"):
		return "long_gun"
	if item_id.contains("rifle") or item_id.contains("smg") or item_id == "shotgun" or item_id == "bat":
		return "long_gun"
	if tags.has("melee"):
		return "long_gun"
	if tags.has("sidearm") or item_id == "pistol":
		return "pistol"
	return "prop"


func preferred_slot(item_id: String, tags: Array = []) -> String:
	var kind := item_kind(item_id, tags)
	if kind == "pistol":
		return "hip"
	if kind == "long_gun":
		return "back"
	if kind == "magazine":
		return "chest"
	return "bag"


func can_stow(item_id: String, slot: String, tags: Array = []) -> bool:
	if item_id.is_empty() or not SLOTS.has(slot):
		return false
	if bool(_location.has(item_id)):
		return false
	return preferred_slot(item_id, tags) == slot


func stow(item_id: String, hand: String = "right", slot: String = "") -> bool:
	if item_id.is_empty():
		return false
	if slot.is_empty():
		slot = preferred_slot(item_id)
	if not can_stow(item_id, slot):
		return false
	var previous: String = str(_slots.get(slot, ""))
	if not previous.is_empty():
		_location.erase(previous)
	_slots[slot] = item_id
	_location[item_id] = slot
	_events.append({"type": "stow", "slot": slot, "item": item_id, "hand": hand, "sound": "holster_clip"})
	stowed.emit(item_id, slot, hand)
	_pulse(hand)
	return true


func draw(slot: String, hand: String = "right") -> String:
	if not SLOTS.has(slot):
		return ""
	var item_id: String = str(_slots.get(slot, ""))
	if item_id.is_empty():
		return ""
	_slots[slot] = ""
	_location.erase(item_id)
	_events.append({"type": "draw", "slot": slot, "item": item_id, "hand": hand, "sound": "holster_draw"})
	drawn.emit(item_id, slot, hand)
	_pulse(hand)
	return item_id


func draw_item(item_id: String, hand: String = "right") -> bool:
	if not _location.has(item_id):
		return false
	return not draw(str(_location[item_id]), hand).is_empty()


func slot_of(item_id: String) -> String:
	return str(_location.get(item_id, ""))


func item_in(slot: String) -> String:
	return str(_slots.get(slot, ""))


func is_stowed(item_id: String) -> bool:
	return _location.has(item_id)


func events() -> Array:
	var result: Array = _events.duplicate(true)
	_events.clear()
	return result


func _pulse(hand: String) -> void:
	haptic.emit(hand, 0.05, 0.38)
