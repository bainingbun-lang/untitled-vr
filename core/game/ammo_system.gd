class_name AmmoSystem
extends RefCounted

# Adapted from GodotFPS-Template (https://github.com/bukkbeek/GodotFPS-Template)
# Original: common/autoloads/bullets.gd
# License: MIT (c) 2026 bukkbeek - see third_party/GODOTFPS_TEMPLATE_LICENSE.txt

const AMMO_DATA_PATH = "res://data/base/ammo.json"
const WeaponDbScript = preload("res://core/game/weapon_db.gd")

# weapons.json (data/base) no lleva calibre por arma; mapa propio hasta que el
# registro de contenido anada "ammo_type" a las definiciones de arma.
const WEAPON_CALIBERS := {
	"pistol": "9mm",
	"submachine_gun": "9mm",
	"assault_rifle": "556",
	"shotgun": "12g",
	"sniper_rifle": "762x51",
	"bat": "",
}

var _ammo_data: Dictionary = {}
var _ammo_reserves: Dictionary = {}
var _max_reserve_per_type: int = 9999

static var _instance: AmmoSystem = null

func _init() -> void:
	_load_ammo_data()

func _load_ammo_data() -> void:
	var file = FileAccess.open(AMMO_DATA_PATH, FileAccess.READ)
	if file:
		var json_str := file.get_as_text()
		file.close()
		var parsed: Variant = JSON.parse_string(json_str)
		if parsed is Dictionary:
			_ammo_data = _parse_ammo_format(parsed)
			_init_reserves()
		else:
			push_error("ammo.json: JSON invalido")
	else:
		push_error("ammo.json: no se pudo abrir")

func _parse_ammo_format(data: Dictionary) -> Dictionary:
	var result: Dictionary = {"ammo_types": {}, "ammo_boxes": {}}
	
	# Old format with direct keys
	if data.has("ammo_types") and typeof(data.ammo_types) == TYPE_DICTIONARY:
		result.ammo_types = data.ammo_types
	if data.has("ammo_boxes") and typeof(data.ammo_boxes) == TYPE_DICTIONARY:
		result.ammo_boxes = data.ammo_boxes
	
	# New format with content array
	if data.has("content") and typeof(data.content) == TYPE_ARRAY:
		for entry in data.content:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var entry_type := str(entry.get("type", ""))
			var entry_id := str(entry.get("id", ""))
			if entry_type == "ammo" and not entry_id.is_empty():
				var local_id := entry_id.split(":")[1] if entry_id.contains(":") else entry_id
				result.ammo_types[local_id] = entry.duplicate(true)
			elif entry_type == "item" and entry_id.contains(":") and entry_id.split(":")[1].begins_with("ammo_box_"):
				var local_id := entry_id.split(":")[1]
				result.ammo_boxes[local_id] = entry.duplicate(true)
	
	return result

func _init_reserves() -> void:
	for ammo_id in _ammo_data.ammo_types:
		_ammo_reserves[ammo_id] = 0

func has_ammo_type(ammo_id: String) -> bool:
	return _ammo_data.ammo_types.has(ammo_id)

func get_ammo_data(ammo_id: String) -> Dictionary:
	return _ammo_data.ammo_types.get(ammo_id, {})

func get_reserve(ammo_id: String) -> int:
	return _ammo_reserves.get(ammo_id, 0)

func set_reserve(ammo_id: String, amount: int) -> void:
	if not _ammo_reserves.has(ammo_id):
		return
	_ammo_reserves[ammo_id] = clampi(amount, 0, _max_reserve_per_type)

func add_reserve(ammo_id: String, amount: int) -> int:
	if not _ammo_reserves.has(ammo_id):
		return 0
	var current = _ammo_reserves[ammo_id]
	var new_amount = clampi(current + amount, 0, _max_reserve_per_type)
	var added = new_amount - current
	_ammo_reserves[ammo_id] = new_amount
	return added

func remove_reserve(ammo_id: String, amount: int) -> int:
	if not _ammo_reserves.has(ammo_id):
		return 0
	var current = _ammo_reserves[ammo_id]
	var new_amount = max(current - amount, 0)
	var removed = current - new_amount
	_ammo_reserves[ammo_id] = new_amount
	return removed

func can_afford(ammo_id: String, amount: int) -> bool:
	return _ammo_reserves.get(ammo_id, 0) >= amount

func get_all_reserves() -> Dictionary:
	return _ammo_reserves.duplicate(true)

func get_max_reserve(ammo_id: String) -> int:
	return _max_reserve_per_type

func set_max_reserve(ammo_id: String, max_amount: int) -> void:
	_max_reserve_per_type = max(0, max_amount)

func get_box_definition(box_id: String) -> Dictionary:
	return _ammo_data.ammo_boxes.get(box_id, {})

func get_boxes_for_ammo_type(ammo_type: String) -> Array:
	var result = []
	for box_id in _ammo_data.ammo_boxes:
		var box_data = _ammo_data.ammo_boxes[box_id]
		if str(box_data.get("tags", [])).contains(ammo_type) or str(box_data.get("nombre", "")).to_lower().contains(ammo_type):
			var entry = {"id": box_id}
			for key in box_data:
				entry[key] = box_data[key]
			result.append(entry)
	return result

func create_ammo_box_pickup_data(box_id: String) -> Dictionary:
	var box_def = get_box_definition(box_id)
	if box_def.is_empty():
		return {}
	var ammo_type = box_def.ammo_type
	if not box_def.has("ammo_type"):
		for tag in box_def.get("tags", []):
			if _ammo_data.ammo_types.has(str(tag)):
				ammo_type = str(tag)
				break
	var ammo_data = get_ammo_data(ammo_type)
	return {
		"type": "ammo_box",
		"box_id": box_id,
		"ammo_type": ammo_type,
		"rounds": box_def.rounds,
		"model": box_def.model,
		"weight_kg": box_def.weight_kg,
		"price": box_def.price,
		"caliber": ammo_data.get("caliber", ammo_type),
		"damage": ammo_data.get("damage", 0),
		"penetration": ammo_data.get("penetration", 0.0)
	}

func get_caliber_for_weapon(weapon_id: String) -> String:
	var declared := ""
	if WeaponDbScript.has(weapon_id):
		declared = str(WeaponDbScript.get_def(weapon_id).get("ammo_type", ""))
	if not declared.is_empty():
		return declared
	return str(WEAPON_CALIBERS.get(weapon_id, ""))

func get_caliber_name(ammo_type: String) -> String:
	var data := get_ammo_data(ammo_type)
	var caliber := str(data.get("caliber", ""))
	return caliber if not caliber.is_empty() else ammo_type

static func get_singleton():
	if _instance == null:
		_instance = preload("res://core/game/ammo_system.gd").new()
	return _instance

func _ensure_initialized() -> void:
	pass