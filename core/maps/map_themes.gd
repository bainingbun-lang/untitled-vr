class_name MapThemes
extends RefCounted

const BuildingScript = preload("res://core/maps/building_generator.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")
const NavigationScript = preload("res://core/npc/npc_navigation.gd")
const WorldMaterialsScript = preload("res://core/maps/world_materials.gd")

const THEMES: Array = ["urbano", "industrial", "rural"]
const THEME_ALIASES: Dictionary = {
	"urban": "urbano", "city": "urbano", "ciudad": "urbano", "calle": "urbano",
	"factory": "industrial", "fabrica": "industrial", "nave": "industrial",
	"campo": "rural", "village": "rural", "campestre": "rural",
}
const THEME_PARAMS: Array = [
	"theme", "theme_density", "building_count", "theme_style", "time_of_day"
]
const TIME_OF_DAY: Array = ["dia", "atardecer", "noche"]
const THEME_SIZES: Dictionary = {
	"urbano": [[4, 4], [5, 4], [4, 5]],
	"industrial": [[6, 4], [5, 5], [7, 4]],
	"rural": [[3, 3], [4, 3], [3, 4]],
}
const MAX_BUILDINGS: int = 6
const MAX_THEME_NODES: int = 72
# Alto de muros de la oficina: con el vano del modelo de puerta (~0.76 del alto) da una puerta de ~2.05 m.
const OFFICE_WALL_HEIGHT: float = 2.7
const MODEL_ROAD_CROSS: String = "res://assets/models/maps/city-roads/road-crossroad.glb"
const MODEL_ROAD_CROSSING: String = "res://assets/models/maps/city-roads/road-crossing.glb"
const MODEL_ROAD_STRAIGHT: String = "res://assets/models/maps/city-roads/road-straight.glb"
const MODEL_ROAD_SIDE: String = "res://assets/models/maps/city-roads/road-side.glb"
const MODEL_SIDEWALK: String = "res://assets/models/maps/city-roads/tile-high.glb"
const MODEL_COMMERCIAL: String = "res://assets/models/maps/city-commercial/building-a.glb"
const MODEL_COMMERCIAL_ALT: String = "res://assets/models/maps/city-commercial/building-c.glb"
const MODEL_INDUSTRIAL: String = "res://assets/models/maps/city-industrial/building-a.glb"
const MODEL_INDUSTRIAL_ALT: String = "res://assets/models/maps/city-industrial/building-c.glb"
const MODEL_RURAL_HOUSE: String = "res://assets/models/maps/building/wall.glb"
const MODEL_CAR: String = "res://assets/models/maps/car/sedan.glb"
const MODEL_POLICE: String = "res://assets/models/maps/car/police.glb"
const MODEL_TAXI: String = "res://assets/models/maps/car/taxi.glb"
const MODEL_LAMP: String = "res://assets/models/maps/city-roads/light-square.glb"
const MODEL_FENCE: String = "res://assets/models/maps/nature/fence_simple.glb"
const MODEL_PIPE: String = "res://assets/models/maps/city-industrial/detail-tank.glb"
const MODEL_TREE: String = "res://assets/models/maps/nature/tree_default.glb"
const MODEL_ROCK: String = "res://assets/models/maps/nature/rock_largeA.glb"
const MODEL_OFFICE_FLOOR: String = "res://assets/models/maps/furniture/floorFull.glb"
const MODEL_OFFICE_WALL: String = "res://assets/models/maps/furniture/wall.glb"
const MODEL_OFFICE_DOOR: String = "res://assets/models/maps/furniture/wallDoorwayWide.glb"
const MODEL_OFFICE_WINDOW: String = "res://assets/models/maps/furniture/wallWindow.glb"
const MODEL_OFFICE_ROOF: String = "res://assets/models/maps/building/roof-flat-center.glb"
const MODEL_DESK: String = "res://assets/models/maps/furniture/desk.glb"
const MODEL_CHAIR: String = "res://assets/models/maps/furniture/chairDesk.glb"
const MODEL_COMPUTER: String = "res://assets/models/maps/furniture/computerScreen.glb"
const MODEL_SHELF: String = "res://assets/models/maps/furniture/bookcaseOpen.glb"
const MODEL_SOFA: String = "res://assets/models/maps/furniture/loungeSofa.glb"
const MODEL_PLANT: String = "res://assets/models/maps/furniture/pottedPlant.glb"
const MODEL_COUNTER: String = "res://assets/models/maps/furniture/kitchenBar.glb"
const MODEL_CEILING_LAMP: String = "res://assets/models/maps/furniture/lampSquareCeiling.glb"
const MODEL_KEYBOARD: String = "res://assets/models/maps/furniture/keyboard.glb"
const MODEL_MEETING_TABLE: String = "res://assets/models/maps/furniture/meetingTable.glb"
const MODEL_WATER_COOLER: String = "res://assets/models/maps/furniture/waterCooler.glb"
const MODEL_PRINTER: String = "res://assets/models/maps/furniture/printer.glb"
const MODEL_FILING_CABINET: String = "res://assets/models/maps/furniture/filingCabinet.glb"
const NAVIGATION_DECISION: String = (
	"Se reutiliza NPCNavigation en vez de NavigationRegion3D: el juego ya consume su A* "
	+ "desde NpcCombat/ArmedNpc, no requiere horneado en headless/Android y permite marcar "
	+ "puertas y habitaciones de la planta baja como celdas transitables. Las plantas "
	+ "superiores son interiores jugables con escaleras, fuera de la malla 2D de NPC."
)

static var _unit_cylinder: CylinderMesh = null
static var _unit_sphere: SphereMesh = null


static func normalize(value: Variant) -> String:
	var text: String = str(value).strip_edges().to_lower()
	if text.is_empty():
		return ""
	if THEMES.has(text):
		return text
	if THEME_ALIASES.has(text):
		return str(THEME_ALIASES[text])
	return ""


static func generate(seed: int, params: Dictionary) -> Dictionary:
	var generator_params: Dictionary = params.duplicate()
	for key in THEME_PARAMS:
		generator_params.erase(key)
	var meta: Dictionary = GeneratorScript.generate(seed, generator_params)
	if not bool(meta.get("ok", false)):
		return meta
	return apply_theme(meta, seed, params)


static func apply_theme(meta: Dictionary, seed: int = -1, params: Dictionary = {}) -> Dictionary:
	var result: Dictionary = meta.duplicate(true)
	var theme: String = normalize(params.get("theme", meta.get("theme", "")))
	if theme.is_empty():
		return result

	var width: int = int(meta.get("width", 0))
	var height: int = int(meta.get("height", 0))
	if width <= 0 or height <= 0:
		return result

	var seed_value: int = seed if seed >= 0 else int(meta.get("seed", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var density: float = clampf(
		float(params.get("theme_density", meta.get("theme_density", 0.55))), 0.0, 1.0
	)
	var spawn_cells: Array = meta.get("spawn_cells", [])
	var obstacle_cells: Array = meta.get("obstacle_cells", [])
	var streets: Dictionary = _streets(theme, width, height)
	var street_cells: Dictionary = streets["all"]
	var reserved: Dictionary = {}
	for cell in obstacle_cells:
		reserved[cell] = true
	for cell in streets["road_cells"]:
		reserved[cell] = true
	for cell in spawn_cells:
		_mark_radius(reserved, cell, 1)
	_mark_radius(reserved, Vector2i(0, height / 2), 1)
	_mark_radius(reserved, Vector2i(width - 1, height / 2), 1)

	var buildings: Array = []
	var sizes: Array = THEME_SIZES[theme]
	var target: int = clampi(int(round(density * float(MAX_BUILDINGS))), 1, MAX_BUILDINGS)
	var attempt_index: int = 0
	for index in range(target):
		var chosen: Array = sizes[rng.randi_range(0, sizes.size() - 1)]
		var size_options: Array = [chosen, [4, 4], [3, 3]]
		var placed := false
		for size in size_options:
			if placed:
				break
			var build_width: int = int(size[0])
			var build_depth: int = int(size[1])
			var candidates: Array = []
			for y in range(1, maxi(2, height - build_depth - 1)):
				for x in range(1, maxi(2, width - build_width - 1)):
					candidates.append(Vector2i(x, y))
			for shuffle_index in range(candidates.size() - 1, 0, -1):
				var other: int = rng.randi_range(0, shuffle_index)
				var swap: Variant = candidates[shuffle_index]
				candidates[shuffle_index] = candidates[other]
				candidates[other] = swap
			for cell in candidates:
				var footprint: Array = _footprint(cell, build_width, build_depth)
				if not _cells_free(footprint, reserved) or not _separated(buildings, footprint):
					continue
				var door_side: String = _street_side(cell, build_width, build_depth, street_cells)
				if door_side.is_empty():
					continue
				var floors: int = rng.randi_range(1, 2)
				if theme == "urbano" and rng.randf() < 0.35:
					floors = 3
				var style: String = _style_for(theme, rng)
				var spec: Dictionary = BuildingScript.generate(
					seed_value + index * 7919 + attempt_index,
					{
						"cell": cell,
						"width": build_width,
						"depth": build_depth,
						"floors": floors,
						"style": style,
						"door_side": door_side,
					}
				)
				attempt_index += 1
				if not bool(spec.get("ok", false)):
					continue
				buildings.append(spec)
				for occupied in footprint:
					reserved[occupied] = true
				placed = true
				break

	var office: Dictionary = {}
	if theme == "urbano":
		office = _office_spec(seed_value, width, height, reserved, buildings, street_cells)
		if not office.is_empty():
			buildings.append(office)
			for occupied in _footprint(
				office.get("cell", Vector2i.ZERO),
				int(office.get("width", 4)),
				int(office.get("depth", 4))
			):
				reserved[occupied] = true

	while buildings.size() > 1 and not _spawns_connected(
		width, height, spawn_cells, _navigation_obstacles(meta, buildings)
	):
		buildings.remove_at(buildings.size() - 1)

	var props: Array = _generate_props(
		theme, buildings, street_cells, spawn_cells, width, height, reserved, rng
	)
	var free_spawns: Array = _free_spawn_cells(reserved, street_cells, spawn_cells, width, height)
	var time_of_day: String = str(params.get("time_of_day", meta.get("time_of_day", "atardecer")))
	if not TIME_OF_DAY.has(time_of_day):
		time_of_day = "atardecer"
	var theme_data: Dictionary = {
		"theme": theme,
		"density": density,
		"time_of_day": time_of_day,
		"roads": streets["road_cells"],
		"sidewalks": streets["sidewalk_cells"],
		"buildings": buildings,
		"props": props,
		"free_spawn_cells": free_spawns,
		"navigation_obstacles": _navigation_obstacles(meta, buildings),
		"navigation_decision": NAVIGATION_DECISION,
		"node_estimate": buildings.size() * BuildingScript.MAX_BUILDING_NODES + MAX_THEME_NODES,
		"landmarks": _landmarks(theme, buildings, streets, width, height),
		"office": office,
	}
	result["time_of_day"] = time_of_day
	result["theme"] = theme
	result["theme_data"] = theme_data
	result["has_navigation"] = true
	result["tags"] = _with_tag(meta.get("tags", []), theme)
	result["id"] = "%s_%s" % [str(meta.get("id", "generated")), theme]
	return result


static func navigation_for(meta: Dictionary, theme_data: Dictionary = {}):
	var width: int = int(meta.get("width", 0))
	var height: int = int(meta.get("height", 0))
	var data: Dictionary = theme_data
	if data.is_empty():
		data = meta.get("theme_data", {})
	var obstacles: Array = data.get("navigation_obstacles", [])
	if obstacles.is_empty():
		obstacles = meta.get("obstacle_cells", [])
	return NavigationScript.new(width, height, obstacles, {})


static func build_world(parent: Node3D, meta: Dictionary) -> Dictionary:
	var theme_data: Dictionary = meta.get("theme_data", {})
	if parent == null or theme_data.is_empty():
		return {"ok": false, "built": false, "node_count": 0, "errors": ["tema: meta sin theme_data"]}

	var theme: String = normalize(theme_data.get("theme", meta.get("theme", "")))
	if theme.is_empty():
		return {"ok": false, "built": false, "node_count": 0, "errors": ["tema: desconocido"]}

	var root := Node3D.new()
	root.name = "Theme_%s" % theme
	root.set_meta("theme", theme)
	parent.add_child(root)

	var time_of_day: String = str(theme_data.get("time_of_day", meta.get("time_of_day", "atardecer")))
	root.set_meta("time_of_day", time_of_day)
	_build_streets(root, theme_data)
	var building_reports: Array = []
	var doors: Array = []
	var office_report: Dictionary = {}
	for spec in theme_data.get("buildings", []):
		var report: Dictionary = _build_building(root, spec, theme, time_of_day)
		building_reports.append(report)
		for door in report.get("doors", []):
			doors.append(door)
		if bool((spec as Dictionary).get("is_office", false)):
			office_report = report
	var prop_report: Dictionary = _build_props(root, theme_data)

	return {
		"ok": true,
		"built": true,
		"root": root,
		"theme": theme,
		"time_of_day": time_of_day,
		"buildings": building_reports,
		"doors": doors,
		"props": prop_report.get("props", []),
		"collision_count": int(prop_report.get("collision_count", 0)),
		"navigation": navigation_for(meta, theme_data),
		"node_count": BuildingScript.count_nodes(root),
		"landmarks": theme_data.get("landmarks", []),
		"office": office_report,
		"errors": [],
	}


static func decorate_builder_report(parent: Node3D, meta: Dictionary, report: Dictionary) -> Dictionary:
	var result: Dictionary = report.duplicate()
	var theme_data: Dictionary = meta.get("theme_data", {})
	if not theme_data.is_empty():
		var decoration: Dictionary = build_world(parent, meta)
		result["theme"] = str(theme_data.get("theme", ""))
		result["theme_report"] = decoration
		result["buildings"] = decoration.get("buildings", [])
		result["doors"] = decoration.get("doors", [])
		result["navigation"] = decoration.get("navigation", null)
		result["node_count"] = BuildingScript.count_nodes(parent)
		result["time_of_day"] = decoration.get("time_of_day", "atardecer")
		result["landmarks"] = decoration.get("landmarks", [])
		result["office"] = decoration.get("office", {})
	return result


static func _streets(theme: String, width: int, height: int) -> Dictionary:
	var road_set: Dictionary = {}
	var sidewalk_set: Dictionary = {}
	var row_a: int = clampi(height / 3, 2, height - 2)
	var row_b: int = clampi(height - height / 3, 2, height - 2)
	var column_a: int = clampi(width / 3, 2, width - 2)
	var column_b: int = clampi(width - width / 3, 2, width - 2)
	match theme:
		"urbano":
			for y in [row_a, row_b]:
				for x in range(width):
					road_set[Vector2i(x, y)] = true
			for y in range(height):
				road_set[Vector2i(column_a, y)] = true
		"industrial":
			for y in [row_a, mini(row_a + 1, height - 1)]:
				for x in range(width):
					road_set[Vector2i(x, y)] = true
			for y in range(height):
				road_set[Vector2i(column_b, y)] = true
		_:
			for y in range(height):
				road_set[Vector2i(column_a, y)] = true
			for x in range(width):
				road_set[Vector2i(row_b, x)] = true

	for cell in road_set.keys():
		var point: Vector2i = cell
		for direction in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var neighbor := point + Vector2i(direction[0], direction[1])
			if neighbor.x <= 0 or neighbor.y <= 0 or neighbor.x >= width - 1 or neighbor.y >= height - 1:
				continue
			if not road_set.has(neighbor):
				sidewalk_set[neighbor] = true

	var all: Dictionary = road_set.duplicate()
	for cell in sidewalk_set.keys():
		all[cell] = true
	var road_cells: Array = road_set.keys()
	road_cells.sort_custom(func(a, b):
		if a.x == b.x:
			return a.y < b.y
		return a.x < b.x
	)
	var sidewalk_cells: Array = sidewalk_set.keys()
	sidewalk_cells.sort_custom(func(a, b): return str(a) < str(b))
	return {
		"all": all,
		"road_cells": road_cells,
		"sidewalk_cells": sidewalk_cells,
	}


static func _build_streets(root: Node3D, theme_data: Dictionary) -> void:
	var theme: String = normalize(theme_data.get("theme", ""))
	var roads: Array = theme_data.get("roads", [])
	var sidewalks: Array = theme_data.get("sidewalks", [])
	var road_set: Dictionary = {}
	for value in roads:
		road_set[value] = true
	var placements: Array = []
	var light_placements: Array = []
	for value in roads:
		var cell: Vector2i = value
		var horizontal: bool = (
			road_set.has(cell + Vector2i(-1, 0)) or road_set.has(cell + Vector2i(1, 0))
		)
		var vertical: bool = (
			road_set.has(cell + Vector2i(0, -1)) or road_set.has(cell + Vector2i(0, 1))
		)
		var neighbors: int = int(horizontal) + int(vertical)
		var path: String = MODEL_ROAD_STRAIGHT
		if theme == "rural":
			path = "res://assets/models/maps/nature/ground_pathStraight.glb"
		if neighbors >= 3:
			path = MODEL_ROAD_CROSS if neighbors >= 4 else MODEL_ROAD_CROSSING
		elif neighbors == 1:
			path = MODEL_ROAD_SIDE
			if not vertical:
				horizontal = true
		var yaw: float = PI * 0.5 if vertical and not horizontal else 0.0
		placements.append([path, BuildingScript.cell_center(cell), yaw])
		
		if theme in ["urbano", "industrial"] and neighbors <= 2:
			var cell_center := BuildingScript.cell_center(cell)
			var offset_x: float = 0.0
			var offset_z: float = 0.0
			if horizontal and not vertical:
				offset_z = 3.5
			elif vertical and not horizontal:
				offset_x = 3.5
			else:
				offset_x = 3.5
				offset_z = 3.5
			light_placements.append([
				MODEL_LAMP,
				Vector3(cell_center.x + offset_x, 0.0, cell_center.z + offset_z),
				0.0
			])
	
	_add_model_group(
		root, "StreetModels", placements, Vector3(1.0, 0.04, 1.0), 90.0, true
	)
	
	if not light_placements.is_empty():
		_add_model_group(
			root, "StreetLights", light_placements, Vector3(0.35, 3.2, 0.35), 80.0, true
		)
	
	if theme == "urbano":
		var walk_placements: Array = []
		for value in sidewalks:
			walk_placements.append(
				[MODEL_SIDEWALK, BuildingScript.cell_center(value), 0.0]
			)
		_add_model_group(
			root, "SidewalkModels", walk_placements, Vector3(1.0, 0.08, 1.0), 80.0, true
		)
		var curb_placements: Array = []
		for value in sidewalks:
			curb_placements.append([
				"res://assets/models/maps/city-roads/tile-low.glb",
				BuildingScript.cell_center(value), 0.0
			])
		if not curb_placements.is_empty():
			_add_model_group(
				root, "CurbModels", curb_placements, Vector3(1.0, 0.15, 1.0), 70.0, true
			)


static func _generate_props(
	theme: String, buildings: Array, street_cells: Dictionary, spawn_cells: Array,
	width: int, height: int, reserved: Dictionary, rng: RandomNumberGenerator
) -> Array:
	var result: Array = []
	var count: int = 5
	for index in range(count):
		var kind: String = _prop_kind(theme, index, rng)
		for attempt in range(40):
			var cell := Vector2i(
				rng.randi_range(1, maxi(1, width - 2)),
				rng.randi_range(1, maxi(1, height - 2))
			)
			if reserved.has(cell) or not _adjacent(street_cells, cell):
				continue
			var point: Vector3 = BuildingScript.cell_center(cell)
			if _near_spawns(point, spawn_cells, 2.4):
				continue
			result.append({
				"kind": kind,
				"cell": cell,
				"position": point,
				"rotation": rng.randf_range(0.0, TAU),
			})
			reserved[cell] = true
			break
	return result


static func _build_props(root: Node3D, theme_data: Dictionary) -> Dictionary:
	var placements: Array = []
	var collision_boxes: Array = []
	var props: Array = []
	for value in theme_data.get("props", []):
		var prop: Dictionary = (value as Dictionary).duplicate()
		var kind: String = str(prop.get("kind", "crate"))
		var position: Vector3 = prop.get("position", Vector3.ZERO)
		var rotation: float = float(prop.get("rotation", 0.0))
		var path: String = MODEL_ROCK
		var fit := Vector3(1.2, 0.8, 1.2)
		var collision_center := position + Vector3(0.0, 0.3, 0.0)
		var collision_size := Vector3(0.9, 0.6, 0.8)
		match kind:
			"car":
				var cars: Array = [MODEL_CAR, MODEL_POLICE, MODEL_TAXI]
				path = str(cars[int(absf(rotation)) % cars.size()])
				fit = Vector3(2.0, 1.6, 3.2)
				collision_center = position + Vector3(0.0, 0.5, 0.0)
				collision_size = Vector3(1.8, 1.0, 3.0)
			"lamp":
				path = MODEL_LAMP
				fit = Vector3(0.35, 3.2, 0.35)
				collision_center = position + Vector3(0.0, 1.4, 0.0)
				collision_size = Vector3(0.22, 2.8, 0.22)
			"fence":
				path = MODEL_FENCE
				fit = Vector3(2.4, 1.2, 0.3)
				collision_center = position + Vector3(0.0, 0.6, 0.0)
				collision_size = Vector3(2.4, 1.2, 0.2)
			"pipe":
				path = MODEL_PIPE
				fit = Vector3(1.6, 1.2, 1.6)
				collision_center = position + Vector3(0.0, 0.6, 0.0)
				collision_size = Vector3(1.6, 1.2, 1.6)
			"tree":
				path = MODEL_TREE
				fit = Vector3(1.6, 3.0, 1.6)
				collision_center = position + Vector3(0.0, 1.0, 0.0)
				collision_size = Vector3(0.45, 2.0, 0.45)
		prop["model"] = path
		props.append(prop)
		placements.append([
			path, position + Vector3(0.0, fit.y * 0.5, 0.0), rotation, fit,
		])
		collision_boxes.append({"center": collision_center, "size": collision_size})

	_add_model_group(root, "DecorModels", placements, Vector3.ZERO, 90.0, true)
	if not collision_boxes.is_empty():
		var body := StaticBody3D.new()
		body.name = "DecorCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("surface", "concrete")
		var shape := CollisionShape3D.new()
		shape.name = "DecorShape"
		shape.shape = BuildingScript.collision_shape(collision_boxes)
		body.add_child(shape)
		root.add_child(body)

	return {"props": props, "collision_count": collision_boxes.size()}


static func _add_model_group(
	parent: Node3D, node_name: String, placements: Array,
	default_fit: Vector3, visibility_end: float, center: bool
) -> Node3D:
	var group := Node3D.new()
	group.name = node_name
	parent.add_child(group)
	var grouped: Dictionary = {}
	for value in placements:
		var placement: Array = value
		if placement.size() < 3:
			continue
		var path: String = str(placement[0])
		if not ResourceLoader.exists(path):
			continue
		var fit: Vector3 = default_fit
		if placement.size() >= 4:
			fit = placement[3]
		var transform := BuildingScript.model_transform(
			path, placement[1], float(placement[2]), fit, center
		)
		if not grouped.has(path):
			grouped[path] = []
		(grouped[path] as Array).append(transform)
	var index: int = 0
	for path in grouped.keys():
		BuildingScript.model_batch(
			group, "Batch_%d" % index, str(path), grouped[path], Vector3.ZERO, visibility_end
		)
		index += 1
	return group


static func _build_building(
	root: Node3D, spec: Dictionary, theme: String, time_of_day: String
) -> Dictionary:
	if bool(spec.get("is_office", false)):
		return _build_office(root, spec, theme, time_of_day)
	return _build_facade(root, spec, theme)


static func _build_facade(root: Node3D, spec: Dictionary, theme: String) -> Dictionary:
	var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
	var width: int = int(spec.get("width", 4))
	var depth: int = int(spec.get("depth", 4))
	var floors: int = maxi(1, int(spec.get("floors", 1)))
	var center: Vector3 = BuildingScript.cell_center(cell)
	var side: String = str(spec.get("door_side", "south"))
	var yaw: float = 0.0
	match side:
		"north":
			yaw = PI
		"east":
			yaw = PI * 0.5
		"west":
			yaw = -PI * 0.5
	var group := Node3D.new()
	group.name = "Building_%d_%d" % [cell.x, cell.y]
	group.set_meta("style", str(spec.get("style", "")))
	group.set_meta("model_kind", theme)
	root.add_child(group)

	var build_report: Dictionary = BuildingScript.build(group, spec)
	if not bool(build_report.get("ok", false)):
		_add_fallback_model(group, center, yaw, width, depth, floors, theme)

	var doors: Array = []
	var door_index: int = 0
	for value in spec.get("doors", []):
		var door: Dictionary = value
		var marker := Marker3D.new()
		marker.name = "Door_%d" % door_index
		marker.position = door.get("world_center", door.get("position", center))
		marker.add_to_group("building_door")
		marker.set_meta("building_cell", cell)
		group.add_child(marker)
		doors.append(marker)
		door_index += 1

	return {
		"ok": true,
		"root": group,
		"style": str(spec.get("style", "")),
		"doors": doors,
		"node_count": BuildingScript.count_nodes(group),
	}


static func _add_fallback_model(
	group: Node3D, center: Vector3, yaw: float,
	width: int, depth: int, floors: int, theme: String
) -> void:
	var path: String = MODEL_COMMERCIAL
	if theme == "industrial":
		path = MODEL_INDUSTRIAL
	elif theme == "rural":
		path = MODEL_RURAL_HOUSE
	var placements: Array = [[path, center, yaw, Vector3(float(width) * 0.98, float(floors) * 2.6, float(depth) * 0.98)]]
	_add_model_group(group, "BuildingModels", placements, Vector3.ZERO, 110.0, false)


static func _build_office(
	root: Node3D, spec: Dictionary, theme: String, time_of_day: String
) -> Dictionary:
	var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
	var width: int = maxi(4, int(spec.get("width", 5)))
	var depth: int = maxi(4, int(spec.get("depth", 5)))
	var x0: float = float(cell.x)
	var z0: float = float(cell.y)
	var group := Node3D.new()
	group.name = "Office_%d_%d" % [cell.x, cell.y]
	group.set_meta("surface", "wood")
	group.set_meta("is_office", true)
	group.set_meta("time_of_day", time_of_day)
	root.add_child(group)

	var side: String = str(spec.get("door_side", "south"))
	var entrance: Vector3 = Vector3(x0 + float(width) * 0.5, 1.0, z0)
	var spec_doors: Array = spec.get("doors", [])
	if not spec_doors.is_empty():
		var first_door: Dictionary = spec_doors[0]
		side = str(first_door.get("side", side))
		entrance = (first_door.get("world_center", entrance) as Vector3)
		entrance.y = 1.0
	var floors: Array = []
	var walls: Array = []
	var roofs: Array = []
	var furniture: Array = []
	var boxes: Array = []
	for z in range(depth):
		for x in range(width):
			var point := Vector3(x0 + float(x) + 0.5, 0.02, z0 + float(z) + 0.5)
			floors.append([MODEL_OFFICE_FLOOR, point, 0.0])
			roofs.append([MODEL_OFFICE_ROOF, Vector3(point.x, OFFICE_WALL_HEIGHT + 0.08, point.z), 0.0])

	for x in range(width):
		var south := Vector3(x0 + float(x) + 0.5, OFFICE_WALL_HEIGHT * 0.5, z0 + 0.06)
		var north := Vector3(x0 + float(x) + 0.5, OFFICE_WALL_HEIGHT * 0.5, z0 + float(depth) - 0.06)
		var south_door: bool = side == "south" and _near_xz(south, entrance, 0.6)
		var north_door: bool = side == "north" and _near_xz(north, entrance, 0.6)
		_office_wall_segment(walls, boxes,
			MODEL_OFFICE_DOOR if south_door else MODEL_OFFICE_WALL,
			south, 0.0, Vector3(1.0, OFFICE_WALL_HEIGHT, 0.12), south_door)
		_office_wall_segment(walls, boxes,
			MODEL_OFFICE_DOOR if north_door else MODEL_OFFICE_WINDOW,
			north, 0.0, Vector3(1.0, OFFICE_WALL_HEIGHT, 0.12), north_door)
	for z in range(depth):
		var west := Vector3(x0 + 0.06, OFFICE_WALL_HEIGHT * 0.5, z0 + float(z) + 0.5)
		var east := Vector3(x0 + float(width) - 0.06, OFFICE_WALL_HEIGHT * 0.5, z0 + float(z) + 0.5)
		var west_door: bool = side == "west" and _near_xz(west, entrance, 0.6)
		var east_door: bool = side == "east" and _near_xz(east, entrance, 0.6)
		_office_wall_segment(walls, boxes,
			MODEL_OFFICE_DOOR if west_door else MODEL_OFFICE_WINDOW,
			west, PI * 0.5, Vector3(1.0, OFFICE_WALL_HEIGHT, 0.12), west_door)
		_office_wall_segment(walls, boxes,
			MODEL_OFFICE_DOOR if east_door else MODEL_OFFICE_WALL,
			east, PI * 0.5, Vector3(1.0, OFFICE_WALL_HEIGHT, 0.12), east_door)

	for x in range(1, width - 1):
		var x_center: float = x0 + float(x) + 0.5
		var partition_door: bool = (
			absf(x_center - (x0 + 1.5)) < 0.55 or absf(x_center - (x0 + float(width) - 1.5)) < 0.55
		)
		_office_wall_segment(walls, boxes,
			MODEL_OFFICE_DOOR if partition_door else MODEL_OFFICE_WALL,
			Vector3(x_center, OFFICE_WALL_HEIGHT * 0.5, z0 + 2.0), 0.0,
			Vector3(1.0, OFFICE_WALL_HEIGHT, 0.12), partition_door)
	var split_x: float = x0 + float(width - 2)
	for z in range(2, depth - 1):
		var z_center: float = z0 + float(z) + 0.5
		var meeting_door: bool = absf(z_center - (z0 + 3.5)) < 0.55
		_office_wall_segment(walls, boxes,
			MODEL_OFFICE_DOOR if meeting_door else MODEL_OFFICE_WALL,
			Vector3(split_x, OFFICE_WALL_HEIGHT * 0.5, z_center), PI * 0.5,
			Vector3(1.0, OFFICE_WALL_HEIGHT, 0.12), meeting_door)

	_office_furniture(furniture, boxes, x0, z0, width, depth)
	_add_model_group(group, "OfficeFloor", floors, Vector3(1.0, 0.04, 1.0), 70.0, true)
	_add_model_group(group, "OfficeWalls", walls, Vector3.ZERO, 80.0, true)
	_add_model_group(group, "OfficeFurniture", furniture, Vector3.ZERO, 70.0, true)
	_add_model_group(group, "OfficeRoof", roofs, Vector3(1.0, 0.08, 1.0), 70.0, true)

	var body := StaticBody3D.new()
	body.name = "OfficeCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", "wood")
	var shape := CollisionShape3D.new()
	shape.name = "OfficeCollisionShape"
	shape.shape = BuildingScript.collision_shape(boxes)
	body.add_child(shape)
	group.add_child(body)

	var doors: Array = []
	var door_positions: Array = []
	_append_unique_point(door_positions, entrance)
	for value in spec_doors:
		var door_point: Vector3 = (value as Dictionary).get("world_center", entrance)
		door_point.y = 1.0
		_append_unique_point(door_positions, door_point)
	_append_unique_point(door_positions, Vector3(x0 + 1.5, 1.0, z0 + 2.0))
	_append_unique_point(door_positions, Vector3(x0 + float(width) - 1.5, 1.0, z0 + 2.0))
	_append_unique_point(door_positions, Vector3(split_x, 1.0, z0 + minf(3.5, float(depth) - 0.5)))
	for i in range(door_positions.size()):
		var marker := Marker3D.new()
		marker.name = "OfficeDoor_%d" % i
		marker.position = door_positions[i]
		marker.add_to_group("building_door")
		marker.set_meta("building_cell", cell)
		marker.set_meta("office", true)
		group.add_child(marker)
		doors.append(marker)

	var energy: float = 0.12
	if time_of_day == "atardecer":
		energy = 0.55
	elif time_of_day == "noche":
		energy = 1.2
	for light_point in [
		Vector3(x0 + 1.5, OFFICE_WALL_HEIGHT - 0.25, z0 + 1.3),
		Vector3(x0 + float(width) * 0.5, OFFICE_WALL_HEIGHT - 0.25, z0 + 3.0),
		Vector3(x0 + float(width) - 1.3, OFFICE_WALL_HEIGHT - 0.25, z0 + float(depth) - 1.3),
	]:
		var lamp := OmniLight3D.new()
		lamp.name = "OfficeLight"
		lamp.position = light_point
		lamp.light_color = Color(1.0, 0.86, 0.68)
		lamp.light_energy = energy
		lamp.omni_range = 8.0
		lamp.shadow_enabled = false
		group.add_child(lamp)

	return {
		"ok": true,
		"root": group,
		"style": "office",
		"doors": doors,
		"spawns": _office_spawns(spec),
		"node_count": BuildingScript.count_nodes(group),
	}


static func _near_xz(a: Vector3, b: Vector3, distance: float) -> bool:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) < distance


static func _append_unique_point(points: Array, point: Vector3) -> void:
	for value in points:
		if (value as Vector3).distance_to(point) < 0.6:
			return
	points.append(point)


static func _office_wall_segment(
	walls: Array, boxes: Array, path: String, center: Vector3,
	yaw: float, fit: Vector3, transparent: bool
) -> void:
	if not ResourceLoader.exists(path):
		return
	walls.append([path, center, yaw, fit])
	if not transparent:
		var size := fit
		if absf(sin(yaw)) > 0.5:
			size = Vector3(fit.z, fit.y, fit.x)
		boxes.append({"center": center, "size": size})


static func _office_furniture(
	placements: Array, boxes: Array, x0: float, z0: float, width: int, depth: int
) -> void:
	var counter_center := Vector3(x0 + 1.3, 0.55, z0 + 0.9)
	placements.append([MODEL_COUNTER, counter_center, 0.0, Vector3(1.8, 1.1, 0.65)])
	boxes.append({"center": counter_center, "size": Vector3(1.8, 1.1, 0.65)})
	var sofa_center := Vector3(x0 + float(width) - 1.2, 0.45, z0 + 0.9)
	placements.append([MODEL_SOFA, sofa_center, PI, Vector3(1.5, 0.9, 0.8)])
	boxes.append({"center": sofa_center, "size": Vector3(1.5, 0.9, 0.8)})
	
	var desk_points: Array = []
	for gx in range(1, width - 1):
		for gz in range(2, depth - 1):
			if (gx + gz) % 2 == 0:
				desk_points.append(Vector3(
					x0 + float(gx) + 0.5,
					0.4,
					z0 + float(gz) + 0.5
				))
	
	if desk_points.is_empty():
		desk_points = [
			Vector3(x0 + 1.4, 0.4, z0 + minf(3.1, float(depth) - 0.9)),
			Vector3(x0 + minf(2.5, float(width) - 0.6), 0.4, z0 + maxf(1.2, float(depth) - 1.0)),
			Vector3(x0 + float(width) - 1.2, 0.4, z0 + 1.3),
		]
	
	for point in desk_points:
		placements.append([MODEL_DESK, point, 0.0, Vector3(1.3, 0.8, 0.75)])
		boxes.append({"center": point, "size": Vector3(1.3, 0.8, 0.75)})
		
		var chair_pos: Vector3 = point + Vector3(0.0, 0.25, 0.85)
		placements.append([MODEL_CHAIR, chair_pos, PI, Vector3(0.55, 0.9, 0.55)])
		boxes.append({"center": chair_pos, "size": Vector3(0.55, 0.9, 0.55)})
		
		var monitor_pos: Vector3 = point + Vector3(0.0, 0.82, -0.2)
		placements.append([MODEL_COMPUTER, monitor_pos, 0.0, Vector3(0.55, 0.4, 0.12)])
		boxes.append({"center": monitor_pos, "size": Vector3(0.55, 0.4, 0.12)})
		
		var keyboard_pos: Vector3 = point + Vector3(0.0, 0.55, 0.3)
		placements.append([MODEL_KEYBOARD, keyboard_pos, 0.0, Vector3(0.5, 0.05, 0.2)])
	
	var shelf_positions: Array = []
	for z in range(1, depth - 1):
		if z % 2 == 0:
			shelf_positions.append(Vector3(x0 + 0.35, 0.95, z0 + float(z) + 0.5))
			shelf_positions.append(Vector3(x0 + float(width) - 0.35, 0.95, z0 + float(z) + 0.5))
	
	for shelf in shelf_positions:
		placements.append([MODEL_SHELF, shelf, PI * 0.5, Vector3(1.2, 1.9, 0.4)])
		boxes.append({"center": shelf, "size": Vector3(0.4, 1.9, 1.2)})
	
	placements.append([MODEL_PLANT, Vector3(x0 + 0.6, 0.5, z0 + 0.6), 0.0, Vector3(0.7, 1.0, 0.7)])
	placements.append([MODEL_PLANT, Vector3(x0 + float(width) - 0.7, 0.5, z0 + 0.6), 0.0, Vector3(0.7, 1.0, 0.7)])
	placements.append([MODEL_PLANT, Vector3(x0 + 1.0, 0.5, z0 + float(depth) - 0.7), 0.0, Vector3(0.7, 1.0, 0.7)])
	placements.append([MODEL_PLANT, Vector3(x0 + float(width) - 1.0, 0.5, z0 + float(depth) - 0.7), 0.0, Vector3(0.7, 1.0, 0.7)])
	
	var meeting_table_center := Vector3(x0 + float(width) * 0.5, 0.6, z0 + float(depth) * 0.5)
	placements.append([MODEL_MEETING_TABLE, meeting_table_center, 0.0, Vector3(2.5, 0.75, 1.5)])
	boxes.append({"center": meeting_table_center, "size": Vector3(2.5, 0.75, 1.5)})
	
	for i in range(4):
		var angle := PI * 0.5 * i
		var chair_pos := meeting_table_center + Vector3(
			sin(angle) * 1.8,
			0.25,
			cos(angle) * 1.2
		)
		placements.append([MODEL_CHAIR, chair_pos, angle + PI, Vector3(0.55, 0.9, 0.55)])
		boxes.append({"center": chair_pos, "size": Vector3(0.55, 0.9, 0.55)})
	
	var water_cooler_pos := Vector3(x0 + float(width) - 1.0, 1.0, z0 + 1.0)
	placements.append([MODEL_WATER_COOLER, water_cooler_pos, 0.0, Vector3(0.4, 1.0, 0.4)])
	boxes.append({"center": water_cooler_pos, "size": Vector3(0.4, 1.0, 0.4)})
	
	var printer_pos := Vector3(x0 + 1.0, 0.5, z0 + 1.5)
	placements.append([MODEL_PRINTER, printer_pos, PI * 0.5, Vector3(0.6, 0.4, 0.5)])
	boxes.append({"center": printer_pos, "size": Vector3(0.6, 0.4, 0.5)})
	
	var filing_pos := Vector3(x0 + 0.5, 1.0, z0 + float(depth) - 1.5)
	placements.append([MODEL_FILING_CABINET, filing_pos, PI, Vector3(0.5, 1.3, 0.6)])
	boxes.append({"center": filing_pos, "size": Vector3(0.5, 1.3, 0.6)})
	
	placements.append([MODEL_CEILING_LAMP, Vector3(x0 + 1.5, OFFICE_WALL_HEIGHT - 0.05, z0 + 1.3), 0.0, Vector3(0.5, 0.12, 0.5)])
	placements.append([MODEL_CEILING_LAMP, Vector3(x0 + float(width) * 0.5, OFFICE_WALL_HEIGHT - 0.05, z0 + minf(3.0, float(depth) - 0.7)), 0.0, Vector3(0.5, 0.12, 0.5)])
	placements.append([MODEL_CEILING_LAMP, Vector3(x0 + float(width) - 1.3, OFFICE_WALL_HEIGHT - 0.05, z0 + float(depth) - 1.3), 0.0, Vector3(0.5, 0.12, 0.5)])
	placements.append([MODEL_CEILING_LAMP, Vector3(x0 + float(width) * 0.5, OFFICE_WALL_HEIGHT - 0.05, z0 + float(depth) * 0.5), 0.0, Vector3(0.5, 0.12, 0.5)])
	placements.append([MODEL_CEILING_LAMP, Vector3(x0 + 1.5, OFFICE_WALL_HEIGHT - 0.05, z0 + float(depth) - 1.5), 0.0, Vector3(0.5, 0.12, 0.5)])
	placements.append([MODEL_CEILING_LAMP, Vector3(x0 + float(width) - 1.5, OFFICE_WALL_HEIGHT - 0.05, z0 + 1.5), 0.0, Vector3(0.5, 0.12, 0.5)])


static func _office_spec(
	seed_value: int, width: int, height: int, reserved: Dictionary,
	buildings: Array, street_cells: Dictionary
) -> Dictionary:
	var size: int = 5
	var candidates: Array = []
	for option in ([5, 4, 3] if width >= 16 and height >= 14 else [4, 3]):
		size = int(option)
		candidates.clear()
		for y in range(1, maxi(2, height - size - 1)):
			for x in range(1, maxi(2, width - size - 1)):
				var cell := Vector2i(x, y)
				var footprint: Array = _footprint(cell, size, size)
				if not _cells_free(footprint, reserved) or not _separated(buildings, footprint):
					continue
				if _street_side(cell, size, size, street_cells).is_empty():
					continue
				candidates.append(cell)
		if not candidates.is_empty():
			break
	if candidates.is_empty():
		return {}
	var center := Vector2(float(width) * 0.5, float(height) * 0.5)
	candidates.sort_custom(func(a, b):
		var da: float = Vector2(a).distance_to(center) + float((a.x * 17 + a.y * 31 + seed_value) % 13) * 0.01
		var db: float = Vector2(b).distance_to(center) + float((b.x * 17 + b.y * 31 + seed_value) % 13) * 0.01
		return da < db
	)
	var cell_choice: Vector2i = candidates[0]
	var spec: Dictionary = BuildingScript.generate(
		seed_value ^ 0x4f464643,
		{
			"cell": cell_choice,
			"width": size,
			"depth": size,
			"floors": 1,
			"style": "brick",
			"door_side": _street_side(cell_choice, size, size, street_cells),
		}
	)
	if not bool(spec.get("ok", false)):
		return {}
	spec["name"] = "Oficina Central"
	spec["is_office"] = true
	spec["office_role"] = "city_hall"
	var spec_doors: Array = spec.get("doors", [])
	if not spec_doors.is_empty():
		spec["door_side"] = str((spec_doors[0] as Dictionary).get("side", "south"))
	spec["spawns"] = _office_spawns(spec)
	return spec


static func _office_spawns(spec: Dictionary) -> Array:
	var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
	var width: int = int(spec.get("width", 5))
	var depth: int = int(spec.get("depth", 5))
	var x0: float = float(cell.x)
	var z0: float = float(cell.y)
	return [
		Vector3(x0 + 1.5, 0.1, z0 + 1.7),
		Vector3(x0 + minf(1.6, float(width) - 0.7), 0.1, z0 + float(depth) - 0.9),
		Vector3(x0 + minf(2.6, float(width) - 0.5), 0.1, z0 + float(depth) - 1.0),
		Vector3(x0 + float(width) - 1.2, 0.1, z0 + float(depth) - 0.8),
	]


static func _landmarks(
	theme: String, buildings: Array, streets: Dictionary, width: int, height: int
) -> Array:
	var result: Array = []
	var roads: Array = streets.get("road_cells", [])
	for value in buildings:
		var spec: Dictionary = value
		if bool(spec.get("is_office", false)):
			var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
			var size: float = float(spec.get("width", 4))
			result.append({
				"id": "oficina_central",
				"name": "Oficina Central",
				"type": "office",
				"position": BuildingScript.cell_center(cell) + Vector3(size * 0.5 - 0.5, 0.0, size * 0.5 - 0.5),
			})
			break
	if not roads.is_empty():
		var crossing: Vector2i = roads[mini(roads.size() / 2, roads.size() - 1)]
		result.append({
			"id": "plaza",
			"name": "Plaza central" if theme == "urbano" else "Cruce principal",
			"type": "plaza",
			"position": BuildingScript.cell_center(crossing),
		})
	var marker_cell := Vector2i(clampi(width - 3, 0, width - 1), clampi(height - 3, 0, height - 1))
	result.append({
		"id": "zona_verde" if theme == "rural" else "mirador",
		"name": "Arboleda" if theme == "rural" else ("Mirador industrial" if theme == "industrial" else "Mirador urbano"),
		"type": "landmark",
		"position": BuildingScript.cell_center(marker_cell),
	})
	return result


static func rng_boolean(seed_value: int) -> bool:
	return absi(seed_value) % 3 != 0


static func _queue(
	queues: Dictionary, surface: String, primitive: String,
	transform: Transform3D, scale: Vector3
) -> void:
	var key: String = "%s|%s" % [surface, primitive]
	if not queues.has(key):
		queues[key] = {
			"surface": surface,
			"primitive": primitive,
			"transforms": [],
		}
	var basis: Basis = transform.basis.scaled(scale)
	(queues[key]["transforms"] as Array).append(
		Transform3D(basis, transform.origin)
	)


static func _mesh_for(primitive: String) -> Mesh:
	match primitive:
		"cylinder":
			return unit_cylinder()
		"sphere":
			return unit_sphere()
		_:
			return BuildingScript.unit_box()


static func unit_cylinder() -> CylinderMesh:
	if _unit_cylinder == null:
		_unit_cylinder = CylinderMesh.new()
		_unit_cylinder.radial_segments = 8
		_unit_cylinder.rings = 1
	return _unit_cylinder


static func unit_sphere() -> SphereMesh:
	if _unit_sphere == null:
		_unit_sphere = SphereMesh.new()
		_unit_sphere.radial_segments = 8
		_unit_sphere.rings = 5
	return _unit_sphere


static func _spawns_connected(
	width: int, height: int, spawns: Array, blocked_cells: Array
) -> bool:
	if spawns.is_empty():
		return false
	var blocked: Dictionary = {}
	for cell in blocked_cells:
		blocked[cell] = true
	var start: Vector2i = spawns[0]
	if blocked.has(start):
		return false
	var queue: Array = [start]
	var seen: Dictionary = {start: true}
	var index: int = 0
	var directions: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		for direction in directions:
			var next: Vector2i = current + direction
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
				continue
			if blocked.has(next) or seen.has(next):
				continue
			seen[next] = true
			queue.append(next)
	for cell in spawns:
		if not seen.has(cell):
			return false
	return true


static func _navigation_obstacles(meta: Dictionary, buildings: Array) -> Array:
	var blocked: Dictionary = {}
	for cell in meta.get("obstacle_cells", []):
		blocked[cell] = true
	for value in buildings:
		var spec: Dictionary = value
		var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
		var build_width: int = int(spec.get("width", 4))
		var build_depth: int = int(spec.get("depth", 4))
		var passable: Dictionary = {}
		for door in spec.get("doors", []):
			var entry: Dictionary = door
			passable[entry.get("outside_cell", Vector2i.ZERO)] = true
			passable[entry.get("inside_cell", Vector2i.ZERO)] = true
		var interior_column: int = cell.x + build_width / 2
		passable[Vector2i(interior_column, cell.y + build_depth / 2)] = true
		for y in range(cell.y, cell.y + build_depth):
			for x in range(cell.x, cell.x + build_width):
				var point := Vector2i(x, y)
				if passable.has(point):
					continue
				var perimeter: bool = (
					x == cell.x or x == cell.x + build_width - 1
					or y == cell.y or y == cell.y + build_depth - 1
				)
				if perimeter or x == interior_column:
					blocked[point] = true
	for spawn in meta.get("spawn_cells", []):
		blocked.erase(spawn)
	return blocked.keys()


static func _free_spawn_cells(
	reserved: Dictionary, street_cells: Dictionary, spawn_cells: Array,
	width: int, height: int
) -> Array:
	var result: Array = []
	for cell in street_cells.keys():
		var point: Vector2i = cell
		if reserved.has(point) and not street_cells.has(point):
			continue
		if _near_spawns(BuildingScript.cell_center(point), spawn_cells, 1.2):
			continue
		result.append(point)
		if result.size() >= 8:
			break
	if result.is_empty():
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var point := Vector2i(x, y)
				if not reserved.has(point):
					result.append(point)
					if result.size() >= 4:
						return result
	return result


static func _with_tag(current: Variant, theme: String) -> Array:
	var result: Array = []
	if current is Array:
		for value in current:
			result.append(str(value))
	if not result.has(theme):
		result.append(theme)
	return result


static func _footprint(cell: Vector2i, width: int, depth: int) -> Array:
	var result: Array = []
	for y in range(cell.y, cell.y + depth):
		for x in range(cell.x, cell.x + width):
			result.append(Vector2i(x, y))
	return result


static func _cells_free(cells: Array, reserved: Dictionary) -> bool:
	for cell in cells:
		if reserved.has(cell):
			return false
	return true


static func _separated(buildings: Array, cells: Array) -> bool:
	for value in buildings:
		var spec: Dictionary = value
		var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
		var width: int = int(spec.get("width", 4)) + 1
		var depth: int = int(spec.get("depth", 4)) + 1
		for point in cells:
			var candidate: Vector2i = point
			if (
				candidate.x >= cell.x - 1 and candidate.x <= cell.x + width
				and candidate.y >= cell.y - 1 and candidate.y <= cell.y + depth
			):
				return false
	return true


static func _street_side(
	cell: Vector2i, width: int, depth: int, street_cells: Dictionary
) -> String:
	if _has_neighbor(cell, width, depth, street_cells, 0):
		return "south"
	if _has_neighbor(cell, width, depth, street_cells, 2):
		return "north"
	if _has_neighbor(cell, width, depth, street_cells, 3):
		return "west"
	if _has_neighbor(cell, width, depth, street_cells, 1):
		return "east"
	return ""


static func _has_neighbor(
	cell: Vector2i, width: int, depth: int, street_cells: Dictionary, side: int
) -> bool:
	for offset in range(width if side < 2 else depth):
		var neighbor: Vector2i
		match side:
			0:
				neighbor = Vector2i(cell.x + offset, cell.y - 1)
			1:
				neighbor = Vector2i(cell.x + width, cell.y + offset)
			2:
				neighbor = Vector2i(cell.x + offset, cell.y + depth)
			_:
				neighbor = Vector2i(cell.x - 1, cell.y + offset)
		if street_cells.has(neighbor):
			return true
	return false


static func _adjacent(street_cells: Dictionary, cell: Vector2i) -> bool:
	return (
		street_cells.has(cell + Vector2i(1, 0))
		or street_cells.has(cell + Vector2i(-1, 0))
		or street_cells.has(cell + Vector2i(0, 1))
		or street_cells.has(cell + Vector2i(0, -1))
	)


static func _mark_radius(target: Dictionary, center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			target[Vector2i(x, y)] = true


static func _near_spawns(point: Vector3, spawns: Array, distance: float) -> bool:
	for value in spawns:
		var spawn_xz: Vector2 = Vector2.ZERO
		if value is Vector2i:
			var cell: Vector2i = value
			spawn_xz = Vector2(cell)
		elif value is Vector2:
			spawn_xz = value
		elif value is Vector3:
			var position: Vector3 = value
			spawn_xz = Vector2(position.x, position.z)
		if Vector2(point.x, point.z).distance_to(spawn_xz) < distance:
			return true
	return false


static func _style_for(theme: String, rng: RandomNumberGenerator) -> String:
	var styles: Array
	match theme:
		"urbano":
			styles = ["brick", "concrete", "wood"]
		"industrial":
			styles = ["metal", "concrete"]
		_:
			styles = ["wood", "brick"]
	return str(styles[rng.randi_range(0, styles.size() - 1)])


static func _prop_kind(theme: String, index: int, rng: RandomNumberGenerator) -> String:
	match theme:
		"urbano":
			return "lamp" if index % 2 == 0 else "car"
		"industrial":
			return "pipe" if index % 2 == 0 else "fence"
		_:
			return "tree" if index % 2 == 0 else "rock"
