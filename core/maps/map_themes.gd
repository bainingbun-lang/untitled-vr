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
const THEME_PARAMS: Array = ["theme", "theme_density", "building_count", "theme_style"]
const THEME_SIZES: Dictionary = {
	"urbano": [[4, 4], [5, 4], [4, 5]],
	"industrial": [[6, 4], [5, 5], [7, 4]],
	"rural": [[3, 3], [4, 3], [3, 4]],
}
const MAX_BUILDINGS: int = 6
const MAX_THEME_NODES: int = 64
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

	while buildings.size() > 0 and not _spawns_connected(
		width, height, spawn_cells, _navigation_obstacles(meta, buildings)
	):
		buildings.remove_at(buildings.size() - 1)

	var props: Array = _generate_props(
		theme, buildings, street_cells, spawn_cells, width, height, reserved, rng
	)
	var free_spawns: Array = _free_spawn_cells(reserved, street_cells, spawn_cells, width, height)
	var theme_data: Dictionary = {
		"theme": theme,
		"density": density,
		"roads": streets["road_cells"],
		"sidewalks": streets["sidewalk_cells"],
		"buildings": buildings,
		"props": props,
		"free_spawn_cells": free_spawns,
		"navigation_obstacles": _navigation_obstacles(meta, buildings),
		"navigation_decision": NAVIGATION_DECISION,
		"node_estimate": buildings.size() * BuildingScript.MAX_BUILDING_NODES + MAX_THEME_NODES,
	}
	result["theme"] = theme
	result["theme_data"] = theme_data
	result["has_navigation"] = true
	result["tags"] = _with_tag(meta.get("tags", []), theme)
	result["id"] = "%s_%s" % [str(meta.get("id", "generated")), theme]
	return result


static func navigation_for(meta: Dictionary, theme_data: Dictionary = {}) -> NPCNavigation:
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

	_build_streets(root, theme_data)
	var building_reports: Array = []
	var doors: Array = []
	for spec in theme_data.get("buildings", []):
		var report: Dictionary = BuildingScript.build(root, spec)
		building_reports.append(report)
		for door in report.get("doors", []):
			doors.append(door)
	var prop_report: Dictionary = _build_props(root, theme_data)

	return {
		"ok": true,
		"built": true,
		"root": root,
		"theme": theme,
		"buildings": building_reports,
		"doors": doors,
		"props": prop_report.get("props", []),
		"collision_count": int(prop_report.get("collision_count", 0)),
		"navigation": navigation_for(meta, theme_data),
		"node_count": BuildingScript.count_nodes(root),
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
	var road_surface: String = "asphalt" if theme == "urbano" else ("concrete" if theme == "industrial" else "ground")
	var groups: Dictionary = {
		road_surface: (theme_data.get("roads", []) as Array).duplicate(),
		"concrete": [],
	}
	if theme == "urbano":
		groups["concrete"] = (theme_data.get("sidewalks", []) as Array).duplicate()
	for surface in groups.keys():
		var cells: Array = groups[surface]
		if cells.is_empty():
			continue
		var visual := MultiMeshInstance3D.new()
		visual.name = "Street_%s" % surface
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = BuildingScript.unit_box()
		multimesh.instance_count = cells.size()
		for i in range(cells.size()):
			var center: Vector3 = BuildingScript.cell_center(cells[i])
			center.y = 0.015 if str(surface) == road_surface else 0.03
			multimesh.set_instance_transform(
				i, Transform3D(Basis().scaled(Vector3(1.0, 0.03, 1.0)), center)
			)
		visual.multimesh = multimesh
		visual.material_override = WorldMaterialsScript.surface_material(str(surface))
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(visual)


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
	var queues: Dictionary = {}
	var collision_boxes: Array = []
	var props: Array = []
	for value in theme_data.get("props", []):
		var prop: Dictionary = value
		var kind: String = str(prop.get("kind", "crate"))
		var position: Vector3 = prop.get("position", Vector3.ZERO)
		var rotation: float = float(prop.get("rotation", 0.0))
		var basis := Basis().rotated(Vector3.UP, rotation)
		props.append(prop)
		match kind:
			"car":
				_queue(queues, "metal", "box", Transform3D(basis, position + Vector3(0.0, 0.52, 0.0)), Vector3(1.5, 0.62, 2.8))
				_queue(queues, "metal", "box", Transform3D(basis, position + Vector3(0.0, 1.05, -0.2)), Vector3(1.2, 0.45, 1.4))
				for offset_x in [-0.72, 0.72]:
					for offset_z in [-0.9, 0.9]:
						_queue(
							queues, "concrete", "cylinder",
							Transform3D(basis * Basis().rotated(Vector3.FORWARD, PI * 0.5), position + Vector3(offset_x, 0.28, offset_z)),
							Vector3(0.27, 0.16, 0.27)
						)
				collision_boxes.append({"center": position + Vector3(0.0, 0.5, 0.0), "size": Vector3(1.5, 1.0, 2.8)})
			"lamp":
				_queue(queues, "metal", "cylinder", Transform3D(Basis(), position + Vector3(0.0, 1.6, 0.0)), Vector3(0.07, 1.6, 0.07))
				_queue(queues, "metal", "box", Transform3D(basis, position + Vector3(0.0, 3.25, 0.0)), Vector3(0.5, 0.22, 0.5))
				collision_boxes.append({"center": position + Vector3(0.0, 1.4, 0.0), "size": Vector3(0.22, 2.8, 0.22)})
			"fence":
				_queue(queues, "metal", "box", Transform3D(basis, position + Vector3(0.0, 0.6, 0.0)), Vector3(2.4, 1.0, 0.12))
				collision_boxes.append({"center": position + Vector3(0.0, 0.6, 0.0), "size": Vector3(2.4, 1.2, 0.2)})
			"pipe":
				_queue(
					queues, "metal", "cylinder",
					Transform3D(basis * Basis().rotated(Vector3.FORWARD, PI * 0.5), position + Vector3(0.0, 0.45, 0.0)),
					Vector3(0.16, 1.2, 0.16)
				)
				collision_boxes.append({"center": position + Vector3(0.0, 0.45, 0.0), "size": Vector3(2.4, 0.4, 0.4)})
			"tree":
				_queue(queues, "wood", "cylinder", Transform3D(Basis(), position + Vector3(0.0, 1.2, 0.0)), Vector3(0.17, 1.2, 0.17))
				_queue(queues, "ground", "sphere", Transform3D(Basis(), position + Vector3(0.0, 2.65, 0.0)), Vector3(0.95, 0.75, 0.95))
				collision_boxes.append({"center": position + Vector3(0.0, 1.0, 0.0), "size": Vector3(0.45, 2.0, 0.45)})
			_:
				_queue(queues, "concrete", "sphere", Transform3D(Basis(), position + Vector3(0.0, 0.28, 0.0)), Vector3(0.55, 0.36, 0.48))
				collision_boxes.append({"center": position + Vector3(0.0, 0.3, 0.0), "size": Vector3(0.9, 0.6, 0.8)})

	for key in queues.keys():
		var entry: Dictionary = queues[key]
		var primitive: String = str(entry["primitive"])
		var transforms: Array = entry["transforms"]
		var visual := MultiMeshInstance3D.new()
		visual.name = "Decor_%s" % str(key).replace("|", "_")
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _mesh_for(primitive)
		multimesh.instance_count = transforms.size()
		for i in range(transforms.size()):
			multimesh.set_instance_transform(i, transforms[i])
		visual.multimesh = multimesh
		visual.material_override = WorldMaterialsScript.surface_material(str(entry["surface"]))
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(visual)

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
			return "pipe" if rng.randf() < 0.5 else "fence"
		_:
			return "tree" if rng.randf() < 0.65 else "rock"
