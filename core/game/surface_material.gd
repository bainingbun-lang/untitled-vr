class_name SurfaceMaterialDef
extends Resource

const ContentRegistryScript = preload("res://core/game/content_registry.gd")

enum Type { FLESH, METAL, WOOD, CONCRETE, DIRT, GLASS, WATER }

const _TYPE_IDS: Array[String] = ["flesh", "metal", "wood", "concrete", "dirt", "glass", "water"]

static var IDS: Array = _build_ids()
static var DEFS: Dictionary = _build_defs()
static var ALIASES: Dictionary = _build_aliases()

@export var type: int = Type.CONCRETE
@export var penetration: float = 0.0
@export var bounce: float = 0.0
@export var absorption: float = 0.0
@export var thickness: float = 0.0
@export var transfer: float = 0.0


func _init(p_type: int = Type.CONCRETE) -> void:
	configure(p_type)


func configure(p_type: int) -> void:
	type = p_type if DEFS.has(p_type) else Type.CONCRETE
	var def: Dictionary = DEFS[type]
	penetration = float(def.get("penetration", 0.0))
	bounce = float(def.get("bounce", 0.0))
	absorption = float(def.get("absorption", 0.0))
	thickness = float(def.get("thickness", 0.0))
	transfer = float(def.get("transfer", 0.0))


static func refresh() -> void:
	DEFS = _build_defs()
	IDS = _build_ids()
	ALIASES = _build_aliases()


static func all_types() -> Array:
	return IDS.duplicate()


static func type_name(p_type: int) -> String:
	if not DEFS.has(p_type):
		return "concrete"
	return str((DEFS[p_type] as Dictionary).get("id", "concrete"))


static func props(p_type: int) -> Dictionary:
	if not DEFS.has(p_type):
		p_type = Type.CONCRETE
	return (DEFS[p_type] as Dictionary).duplicate()


static func type_from(value) -> int:
	if typeof(value) == TYPE_INT:
		return int(value) if DEFS.has(int(value)) else -1
	var text := str(value).strip_edges().to_lower()
	if text.is_empty():
		return -1
	if ALIASES.has(text):
		return int(ALIASES[text])
	if text.is_valid_int():
		var number := int(text)
		return number if DEFS.has(number) else -1
	for id in IDS:
		if text.contains(str(id)):
			return int(ALIASES[str(id)])
	return -1


static func from_collider(collider) -> int:
	var node := collider as Node
	if node == null:
		return Type.CONCRETE
	var cursor: Node = node
	var depth := 0
	while cursor != null and depth < 6:
		for key in ["surface", "surface_type", "surface_material", "material"]:
			if cursor.has_meta(key):
				var found := type_from(cursor.get_meta(key))
				if found >= 0:
					return found
		for id in IDS:
			var key := str(id)
			if cursor.is_in_group("surface_" + key) or cursor.is_in_group("surface_" + key + "s") or cursor.is_in_group(key):
				return int(ALIASES[key])
		cursor = cursor.get_parent()
		depth += 1
	return Type.CONCRETE


static func penetration_of(p_type: int) -> float:
	return float(props(p_type).get("penetration", 0.0))


static func bounce_of(p_type: int) -> float:
	return float(props(p_type).get("bounce", 0.0))


static func absorption_of(p_type: int) -> float:
	return float(props(p_type).get("absorption", 0.0))


static func thickness_of(p_type: int) -> float:
	return float(props(p_type).get("thickness", 0.0))


static func transfer_of(p_type: int) -> float:
	return float(props(p_type).get("transfer", 0.0))


static func effect(p_type: int) -> String:
	return str(props(p_type).get("effect", "dust"))


static func color(p_type: int) -> Color:
	var def: Dictionary = props(p_type)
	var value = def.get("color", Color(0.5, 0.5, 0.5))
	return value if value is Color else Color(0.5, 0.5, 0.5)


static func penetration_cost(p_type: int) -> float:
	var def: Dictionary = props(p_type)
	var cost: float = (1.0 - float(def.get("penetration", 0.0))) * 0.8
	cost += float(def.get("absorption", 0.0)) * 0.2
	cost += clampf(float(def.get("thickness", 0.0)), 0.0, 4.0) * 0.1
	return clampf(cost, 0.0, 1.2)


static func can_penetrate(p_type: int, power: float) -> bool:
	return clampf(power, 0.0, 1.0) > penetration_cost(p_type)


static func _build_defs() -> Dictionary:
	var registry := ContentRegistryScript.instance()
	var result: Dictionary = {}
	for type_id in range(_TYPE_IDS.size()):
		var id := str(_TYPE_IDS[type_id])
		var entry: Dictionary = registry.definition("surface", id)
		var def: Dictionary = entry.duplicate(true)
		def.erase("aliases")
		def["id"] = id
		var raw_color: Array = def.get("color", [0.5, 0.5, 0.5])
		while raw_color.size() < 3:
			raw_color.append(0.5)
		def["color"] = Color(float(raw_color[0]), float(raw_color[1]), float(raw_color[2]))
		result[type_id] = def
	return result


static func _build_ids() -> Array:
	var result: Array = []
	for id in _TYPE_IDS:
		result.append(str(id))
	return result


static func _build_aliases() -> Dictionary:
	var result: Dictionary = {}
	var registry := ContentRegistryScript.instance()
	for type_id in range(_TYPE_IDS.size()):
		var id := str(_TYPE_IDS[type_id])
		var def: Dictionary = registry.definition("surface", id)
		result[id] = type_id
		for alias in def.get("aliases", []):
			result[str(alias)] = type_id
	return result
