class_name WeaponDb
extends RefCounted

const WEAPONS: Dictionary = {
	"pistol": {
		"id": "pistol",
		"name": "Pistola",
		"damage": 24.0,
		"fire_rate": 6.0,
		"range": 60.0,
		"mag": 12,
		"auto": false,
		"spread": 1.2,
		"pellets": 1,
		"tags": ["weapon", "sidearm"],
		"reload_time": 1.1,
		"weight": 1.2,
		"impulse": 0.06,
		"uses_ammo": true,
	},
	"submachine_gun": {
		"id": "submachine_gun",
		"name": "Subfusil",
		"damage": 16.0,
		"fire_rate": 12.0,
		"range": 45.0,
		"mag": 30,
		"auto": true,
		"spread": 3.0,
		"pellets": 1,
		"tags": ["weapon", "smg"],
		"reload_time": 1.6,
		"weight": 2.8,
		"impulse": 0.045,
		"uses_ammo": true,
	},
	"assault_rifle": {
		"id": "assault_rifle",
		"name": "Rifle de asalto",
		"damage": 28.0,
		"fire_rate": 9.0,
		"range": 120.0,
		"mag": 30,
		"auto": true,
		"spread": 2.0,
		"pellets": 1,
		"tags": ["weapon", "rifle"],
		"reload_time": 2.0,
		"weight": 3.5,
		"impulse": 0.09,
		"uses_ammo": true,
	},
	"shotgun": {
		"id": "shotgun",
		"name": "Escopeta",
		"damage": 12.0,
		"fire_rate": 1.2,
		"range": 30.0,
		"mag": 6,
		"auto": false,
		"spread": 7.0,
		"pellets": 8,
		"tags": ["weapon", "shotgun"],
		"reload_time": 2.4,
		"weight": 3.2,
		"impulse": 0.05,
		"uses_ammo": true,
	},
	"sniper_rifle": {
		"id": "sniper_rifle",
		"name": "Rifle de francotirador",
		"damage": 95.0,
		"fire_rate": 0.8,
		"range": 300.0,
		"mag": 5,
		"auto": false,
		"spread": 0.15,
		"pellets": 1,
		"tags": ["weapon", "sniper"],
		"reload_time": 2.6,
		"weight": 4.0,
		"impulse": 0.25,
		"uses_ammo": true,
	},
	"bat": {
		"id": "bat",
		"name": "Bate",
		"damage": 35.0,
		"fire_rate": 2.5,
		"range": 2.4,
		"mag": 0,
		"auto": false,
		"spread": 0.0,
		"pellets": 1,
		"tags": ["weapon", "melee"],
		"reload_time": 0.0,
		"weight": 1.5,
		"impulse": 0.18,
		"uses_ammo": false,
	},
}


const BALLISTICS: Dictionary = {
	"pistol": {
		"penetration": 0.35, "falloff_start": 12.0, "falloff_end": 60.0, "falloff_min": 0.35,
		"projectile_speed": 0.0, "projectile_gravity": 0.0, "projectile_min_distance": 30.0,
		"impact_speed": 120.0, "effect_scale": 0.7, "max_penetrations": 1, "max_ricochets": 1,
	},
	"submachine_gun": {
		"penetration": 0.30, "falloff_start": 10.0, "falloff_end": 45.0, "falloff_min": 0.28,
		"projectile_speed": 0.0, "projectile_gravity": 0.0, "projectile_min_distance": 30.0,
		"impact_speed": 110.0, "effect_scale": 0.6, "max_penetrations": 1, "max_ricochets": 1,
	},
	"assault_rifle": {
		"penetration": 0.70, "falloff_start": 25.0, "falloff_end": 120.0, "falloff_min": 0.45,
		"projectile_speed": 0.0, "projectile_gravity": 0.0, "projectile_min_distance": 40.0,
		"impact_speed": 240.0, "effect_scale": 0.9, "max_penetrations": 2, "max_ricochets": 1,
	},
	"shotgun": {
		"penetration": 0.25, "falloff_start": 8.0, "falloff_end": 30.0, "falloff_min": 0.18,
		"projectile_speed": 380.0, "projectile_gravity": 0.6, "projectile_min_distance": 25.0,
		"impact_speed": 90.0, "effect_scale": 1.3, "max_penetrations": 1, "max_ricochets": 0,
	},
	"sniper_rifle": {
		"penetration": 0.95, "falloff_start": 60.0, "falloff_end": 300.0, "falloff_min": 0.60,
		"projectile_speed": 850.0, "projectile_gravity": 0.25, "projectile_min_distance": 40.0,
		"impact_speed": 340.0, "effect_scale": 1.5, "max_penetrations": 2, "max_ricochets": 2,
	},
	"bat": {
		"penetration": 0.0, "falloff_start": 1.0, "falloff_end": 3.0, "falloff_min": 1.0,
		"projectile_speed": 0.0, "projectile_gravity": 0.0, "projectile_min_distance": 999.0,
		"impact_speed": 20.0, "effect_scale": 1.0, "max_penetrations": 0, "max_ricochets": 0,
	},
}


static func all() -> Dictionary:
	var result: Dictionary = {}
	for id in WEAPONS.keys():
		result[id] = _with_ballistics(str(id), WEAPONS[id] as Dictionary)
	return result


static func get_def(id: String) -> Dictionary:
	if not WEAPONS.has(id):
		return {}
	return _with_ballistics(id, WEAPONS[id] as Dictionary)


static func _with_ballistics(id: String, base: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	var extras: Dictionary = BALLISTICS.get(id, {})
	for key in extras.keys():
		if not result.has(key):
			result[key] = extras[key]
	return result


static func list_ids() -> Array:
	var ids: Array = WEAPONS.keys()
	ids.sort()
	return ids


static func has(id: String) -> bool:
	return WEAPONS.has(id)


static func register_items(item_db: ItemDb) -> void:
	if item_db == null or not item_db.has_method("register"):
		return
	for id in list_ids():
		var def: Dictionary = get_def(id)
		var tags: Array = []
		for tag in def.get("tags", []):
			var text := str(tag).strip_edges().to_lower()
			if not text.is_empty() and text != "weapon" and not tags.has(text):
				tags.append(text)
		tags.append("weapon")
		item_db.register({
			"id": id,
			"nombre": str(def.get("name", id)),
			"apilable": false,
			"max_stack": 1,
			"peso": float(def.get("weight", 0.0)),
			"tags": tags,
		})
