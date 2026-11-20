class_name SurfaceMaterialDef
extends Resource

enum Type { FLESH, METAL, WOOD, CONCRETE, DIRT, GLASS, WATER }

const IDS := ["flesh", "metal", "wood", "concrete", "dirt", "glass", "water"]

const DEFS := {
	Type.FLESH: {
		"id": "flesh", "name": "Carne", "penetration": 0.70, "bounce": 0.02,
		"absorption": 0.25, "thickness": 0.40, "transfer": 0.35,
		"effect": "blood", "color": Color(0.55, 0.02, 0.02),
	},
	Type.METAL: {
		"id": "metal", "name": "Metal", "penetration": 0.15, "bounce": 0.90,
		"absorption": 0.50, "thickness": 0.02, "transfer": 0.08,
		"effect": "sparks", "color": Color(0.85, 0.55, 0.15),
	},
	Type.WOOD: {
		"id": "wood", "name": "Madera", "penetration": 0.55, "bounce": 0.15,
		"absorption": 0.35, "thickness": 0.10, "transfer": 0.55,
		"effect": "splinters", "color": Color(0.45, 0.28, 0.12),
	},
	Type.CONCRETE: {
		"id": "concrete", "name": "Hormigon", "penetration": 0.02, "bounce": 0.20,
		"absorption": 0.90, "thickness": 0.30, "transfer": 0.0,
		"effect": "dust", "color": Color(0.55, 0.54, 0.50),
	},
	Type.DIRT: {
		"id": "dirt", "name": "Tierra", "penetration": 0.25, "bounce": 0.05,
		"absorption": 0.65, "thickness": 0.50, "transfer": 0.12,
		"effect": "dust", "color": Color(0.38, 0.28, 0.16),
	},
	Type.GLASS: {
		"id": "glass", "name": "Vidrio", "penetration": 0.80, "bounce": 0.10,
		"absorption": 0.15, "thickness": 0.01, "transfer": 0.80,
		"effect": "shards", "color": Color(0.55, 0.80, 0.90),
	},
	Type.WATER: {
		"id": "water", "name": "Agua", "penetration": 0.35, "bounce": 0.05,
		"absorption": 0.90, "thickness": 4.00, "transfer": 0.0,
		"effect": "splash", "color": Color(0.35, 0.65, 0.85),
	},
}

const ALIASES := {
	"flesh": Type.FLESH, "carne": Type.FLESH, "body": Type.FLESH, "organic": Type.FLESH,
	"metal": Type.METAL, "steel": Type.METAL, "acero": Type.METAL, "hierro": Type.METAL,
	"wood": Type.WOOD, "madera": Type.WOOD, "lumber": Type.WOOD,
	"concrete": Type.CONCRETE, "hormigon": Type.CONCRETE, "cement": Type.CONCRETE,
	"stone": Type.CONCRETE, "piedra": Type.CONCRETE, "brick": Type.CONCRETE,
	"dirt": Type.DIRT, "tierra": Type.DIRT, "soil": Type.DIRT, "sand": Type.DIRT, "arena": Type.DIRT,
	"glass": Type.GLASS, "vidrio": Type.GLASS, "cristal": Type.GLASS,
	"water": Type.WATER, "agua": Type.WATER, "liquid": Type.WATER,
}

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
