class_name VrBag
extends RefCounted

const LoadoutScript = preload("res://core/game/loadout.gd")

var head_position: Vector3 = Vector3.ZERO
var head_forward: Vector3 = Vector3.FORWARD
var head_right: Vector3 = Vector3.RIGHT
var bag_back: float = 0.45
var bag_side: float = 0.28
var bag_down: float = 0.40
var bag_radius: float = 0.35

var _stored: Array = []
var _held: Dictionary = {"left": "", "right": ""}
var _open: bool = false


func _init(weapon_ids: Array = []) -> void:
	set_items(weapon_ids)


func set_head_pose(pos: Vector3, forward: Vector3) -> void:
	head_position = pos
	if forward.length_squared() > 0.000001:
		head_forward = forward.normalized()
	else:
		head_forward = Vector3.FORWARD
	var right := head_forward.cross(Vector3.UP)
	head_right = right.normalized() if right.length_squared() > 0.000001 else Vector3.RIGHT


func set_head_transform(xform: Transform3D) -> void:
	head_position = xform.origin
	var forward := -xform.basis.z
	head_forward = forward.normalized() if forward.length_squared() > 0.000001 else Vector3.FORWARD
	var right := xform.basis.x
	head_right = right.normalized() if right.length_squared() > 0.000001 else Vector3.RIGHT


func configure_zone(back: float, side: float, down: float, radius: float) -> void:
	bag_back = maxf(back, 0.0)
	bag_side = maxf(side, 0.0)
	bag_down = maxf(down, 0.0)
	bag_radius = maxf(radius, 0.05)


func bag_center() -> Vector3:
	return head_position - head_forward * bag_back + head_right * bag_side - Vector3.UP * bag_down


func is_in_bag_zone(hand_position: Vector3) -> bool:
	return hand_position.distance_to(bag_center()) <= bag_radius


func open(hand_position: Vector3) -> bool:
	if not is_in_bag_zone(hand_position):
		close()
		return false
	_open = true
	return true


func close() -> void:
	_open = false


func is_open() -> bool:
	return _open


func set_items(weapon_ids: Array) -> void:
	_stored = []
	for raw_id in weapon_ids:
		var id := str(raw_id)
		if not id.is_empty() and not _stored.has(id):
			_stored.append(id)


func load_from_inventory(inventory, item_db) -> void:
	var ids: Array = []
	if inventory != null and inventory.has_method("count"):
		for raw_id in LoadoutScript.weapon_ids(item_db):
			var id := str(raw_id)
			if int(inventory.count(id)) > 0:
				ids.append(id)
	set_items(ids)


func items() -> Array:
	return _stored.duplicate()


func has_item(item_id: String) -> bool:
	return _stored.has(item_id) or held_in("left") == item_id or held_in("right") == item_id


func held_in(hand: String) -> String:
	return str(_held.get(hand, ""))


func held_item() -> String:
	var right := held_in("right")
	return right if not right.is_empty() else held_in("left")


func take(item_id: String, hand: String = "right") -> bool:
	if not _open or not _held.has(hand):
		return false
	if not held_in(hand).is_empty():
		return false
	if held_in("left") == item_id or held_in("right") == item_id:
		return false
	var index := _stored.find(item_id)
	if index < 0:
		return false
	_stored.remove_at(index)
	_held[hand] = item_id
	return true


func stow(hand: String = "right") -> void:
	if not _held.has(hand):
		return
	var id := held_in(hand)
	if id.is_empty():
		return
	_held[hand] = ""
	if not _stored.has(id):
		_stored.append(id)
