class_name BuildingGenerator
extends RefCounted

const WorldMaterialsScript = preload("res://core/maps/world_materials.gd")

const FLOOR_HEIGHT: float = 3.0
const WALL_HEIGHT: float = 2.8
const WALL_THICKNESS: float = 0.18
const FLOOR_THICKNESS: float = 0.3
const DOOR_WIDTH: float = 1.4
const DOOR_HEIGHT: float = 2.2
const WINDOW_WIDTH: float = 0.9
const WINDOW_SILL: float = 0.95
const WINDOW_HEIGHT: float = 1.1
const MAX_FLOORS: int = 3
const MAX_BUILDING_NODES: int = 16
const STYLE_SURFACES: Dictionary = {
	"brick": {"wall": "brick", "floor": "concrete", "roof": "concrete", "inner": "wood"},
	"wood": {"wall": "wood", "floor": "wood", "roof": "wood", "inner": "wood"},
	"metal": {"wall": "metal", "floor": "concrete", "roof": "metal", "inner": "metal"},
	"concrete": {"wall": "concrete", "floor": "concrete", "roof": "concrete", "inner": "concrete"},
}

static var _unit_box: BoxMesh = null


static func generate(seed: int, params: Dictionary) -> Dictionary:
	var errors: Array = []
	var cell := _as_cell(params.get("cell", Vector2i.ZERO), errors)
	var width: int = _clamped_int(params.get("width", 4), 3, 8)
	var depth: int = _clamped_int(params.get("depth", 4), 3, 8)
	var floors: int = _clamped_int(params.get("floors", 1), 1, MAX_FLOORS)
	var style := str(params.get("style", "brick")).strip_edges().to_lower()
	if not STYLE_SURFACES.has(style):
		style = "brick"
	var surfaces: Dictionary = STYLE_SURFACES[style]
	var door_side := str(params.get("door_side", "south")).strip_edges().to_lower()
	if door_side not in ["south", "north", "east", "west"]:
		door_side = "south"
	if not errors.is_empty():
		return _failure(errors)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var origin := Vector3(float(cell.x) + float(width) * 0.5, 0.0, float(cell.y) + float(depth) * 0.5)
	var boxes: Array = []
	var doors: Array = []
	var rooms: Array = []
	var stairs: Array = []
	var wall_surface: String = surfaces["wall"]

	for floor in range(floors):
		var base_y: float = float(floor) * FLOOR_HEIGHT
		var slab_center := Vector3(origin.x, base_y - FLOOR_THICKNESS * 0.5, origin.z)
		_add_box(
			boxes, slab_center, Vector3(width, FLOOR_THICKNESS, depth),
			wall_surface, true, "floor"
		)

		var openings_south: Array = [_window_opening(origin.x, rng)]
		var openings_north: Array = [_window_opening(origin.x + rng.randf_range(-0.35, 0.35), rng)]
		var openings_west: Array = [_window_opening(origin.z, rng)]
		var openings_east: Array = [_window_opening(origin.z + rng.randf_range(-0.35, 0.35), rng)]
		if floor == 0:
			var door_offset: float = rng.randf_range(-0.35, 0.35)
			var door_along: float = 0.0
			match door_side:
				"north", "south":
					door_along = origin.x + door_offset
				_:
					door_along = origin.z + door_offset
			var door_opening: Dictionary = {
				"from": door_along - DOOR_WIDTH * 0.5,
				"to": door_along + DOOR_WIDTH * 0.5,
				"bottom": 0.0,
				"top": DOOR_HEIGHT,
			}
			match door_side:
				"north":
					openings_north = [door_opening]
				"east":
					openings_east = [door_opening]
				"west":
					openings_west = [door_opening]
				_:
					openings_south = [door_opening]
			var outside_cell: Vector2i
			var inside_cell: Vector2i
			var world_center: Vector3
			match door_side:
				"north":
					outside_cell = Vector2i(int(floor(door_along)), cell.y + depth)
					inside_cell = Vector2i(int(floor(door_along)), cell.y + depth - 1)
					world_center = Vector3(door_along, 0.0, float(cell.y + depth))
				"east":
					outside_cell = Vector2i(cell.x + width, int(floor(door_along)))
					inside_cell = Vector2i(cell.x + width - 1, int(floor(door_along)))
					world_center = Vector3(float(cell.x + width), 0.0, door_along)
				"west":
					outside_cell = Vector2i(cell.x - 1, int(floor(door_along)))
					inside_cell = Vector2i(cell.x, int(floor(door_along)))
					world_center = Vector3(float(cell.x), 0.0, door_along)
				_:
					outside_cell = Vector2i(int(floor(door_along)), cell.y - 1)
					inside_cell = Vector2i(int(floor(door_along)), cell.y)
					world_center = Vector3(door_along, 0.0, float(cell.y))
			doors.append({
				"side": door_side,
				"floor": 0,
				"world_center": world_center,
				"outside_cell": outside_cell,
				"inside_cell": inside_cell,
				"width": DOOR_WIDTH,
				"height": DOOR_HEIGHT,
			})

		_add_wall_axis(
			boxes, "x", origin.z - float(depth) * 0.5,
			origin.x - float(width) * 0.5, origin.x + float(width) * 0.5,
			base_y, openings_south, wall_surface
		)
		_add_wall_axis(
			boxes, "x", origin.z + float(depth) * 0.5,
			origin.x - float(width) * 0.5, origin.x + float(width) * 0.5,
			base_y, openings_north, wall_surface
		)
		_add_wall_axis(
			boxes, "z", origin.x - float(width) * 0.5,
			origin.z - float(depth) * 0.5 + WALL_THICKNESS,
			origin.z + float(depth) * 0.5 - WALL_THICKNESS,
			base_y, openings_west, wall_surface
		)
		_add_wall_axis(
			boxes, "z", origin.x + float(width) * 0.5,
			origin.z - float(depth) * 0.5 + WALL_THICKNESS,
			origin.z + float(depth) * 0.5 - WALL_THICKNESS,
			base_y, openings_east, wall_surface
		)

		_add_wall_axis(
			boxes, "z", origin.x,
			origin.z - float(depth) * 0.5 + WALL_THICKNESS,
			origin.z + float(depth) * 0.5 - WALL_THICKNESS,
			base_y,
			[{
				"from": origin.z - DOOR_WIDTH * 0.5,
				"to": origin.z + DOOR_WIDTH * 0.5,
				"bottom": 0.0,
				"top": DOOR_HEIGHT,
			}],
			str(surfaces["inner"])
		)
		_add_box(
			boxes,
			Vector3(origin.x, base_y + 0.02, origin.z),
			Vector3(DOOR_WIDTH + 0.4, 0.04, float(depth) - 0.4),
			"concrete", false, "corridor"
		)

		rooms.append({
			"id": "F%d_R0" % floor,
			"bounds": AABB(
				Vector3(origin.x - float(width) * 0.5, base_y, origin.z - float(depth) * 0.5),
				Vector3(float(width) * 0.5, WALL_HEIGHT, float(depth))
			),
		})
		rooms.append({
			"id": "F%d_R1" % floor,
			"bounds": AABB(
				Vector3(origin.x, base_y, origin.z - float(depth) * 0.5),
				Vector3(float(width) * 0.5, WALL_HEIGHT, float(depth))
			),
		})

		if floor < floors - 1:
			var step_count: int = 10
			var rise: float = FLOOR_HEIGHT / float(step_count)
			var run: float = minf(0.32, (float(depth) - 1.2) / float(step_count))
			var start_z: float = origin.z + float(depth) * 0.5 - 1.0 - run * float(step_count)
			var start_x: float = origin.x - float(width) * 0.5 + 0.8
			for step in range(step_count):
				var step_center := Vector3(
					start_x,
					base_y + rise * (float(step) + 0.5),
					start_z + run * (float(step) + 0.5)
				)
				_add_box(
					boxes, step_center, Vector3(1.0, rise, run),
					str(surfaces["inner"]), true, "stair"
				)
			stairs.append({
				"floor": floor,
				"from": Vector3(start_x, base_y, start_z),
				"to": Vector3(start_x, base_y + FLOOR_HEIGHT, start_z + run * float(step_count)),
				"steps": step_count,
			})

	var roof_y: float = float(floors) * FLOOR_HEIGHT + 0.1
	_add_box(
		boxes, Vector3(origin.x, roof_y, origin.z),
		Vector3(width + 0.4, 0.25, depth + 0.4),
		str(surfaces["roof"]), true, "roof"
	)
	for side in [-1.0, 1.0]:
		_add_box(
			boxes,
			Vector3(origin.x, roof_y + 0.23, origin.z + side * (float(depth) * 0.5 + 0.1)),
			Vector3(width + 0.4, 0.24, 0.16),
			str(surfaces["roof"]), true, "parapet"
		)

	var collision_boxes: Array = []
	var footprint: Array = []
	for y in range(cell.y, cell.y + depth):
		for x in range(cell.x, cell.x + width):
			footprint.append(Vector2i(x, y))
	for box in boxes:
		if bool(box.get("solid", false)):
			collision_boxes.append(box)

	var bounds := AABB(
		Vector3(float(cell.x), 0.0, float(cell.y)),
		Vector3(float(width), float(floors) * FLOOR_HEIGHT + 0.4, float(depth))
	)
	return {
		"ok": true,
		"seed": seed,
		"name": "Building_%d" % seed,
		"style": style,
		"cell": cell,
		"width": width,
		"depth": depth,
		"floors": floors,
		"origin": origin,
		"bounds": bounds,
		"footprint": footprint,
		"boxes": boxes,
		"collision_boxes": collision_boxes,
		"doors": doors,
		"rooms": rooms,
		"stairs": stairs,
		"node_estimate": _estimate_nodes(boxes, doors),
		"errors": [],
	}


static func build(parent: Node3D, spec: Dictionary) -> Dictionary:
	if parent == null or not bool(spec.get("ok", false)):
		return {"ok": false, "errors": ["edificio: se requieren parent y spec valido"], "node_count": 0}

	var root := Node3D.new()
	root.name = str(spec.get("name", "Building"))
	root.set_meta("building_seed", int(spec.get("seed", 0)))
	parent.add_child(root)

	var grouped: Dictionary = {}
	for box in spec.get("boxes", []):
		var surface: String = str(box.get("surface", "concrete"))
		if not grouped.has(surface):
			grouped[surface] = []
		(grouped[surface] as Array).append(box)

	var visual_count: int = 0
	for surface in grouped.keys():
		var instances: Array = grouped[surface]
		if instances.is_empty():
			continue
		var visual := MultiMeshInstance3D.new()
		visual.name = "Visual_%s" % str(surface)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = unit_box()
		multimesh.instance_count = instances.size()
		for i in range(instances.size()):
			var box: Dictionary = instances[i]
			var transform := Transform3D(
				Basis().scaled(Vector3(box["size"])), Vector3(box["center"])
			)
			multimesh.set_instance_transform(i, transform)
		visual.multimesh = multimesh
		visual.material_override = WorldMaterialsScript.surface_material(str(surface))
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(visual)
		visual_count += 1

	var body := StaticBody3D.new()
	body.name = "Structure"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", str(spec.get("style", "brick")))
	var collision := CollisionShape3D.new()
	collision.name = "StructureShape"
	collision.shape = collision_shape(spec.get("collision_boxes", []))
	body.add_child(collision)
	root.add_child(body)

	var doors: Array = []
	for door in spec.get("doors", []):
		var value: Dictionary = door
		var marker := Marker3D.new()
		marker.name = "Door_%d" % doors.size()
		marker.position = value.get("world_center", Vector3.ZERO)
		marker.add_to_group("building_door")
		marker.set_meta("door", value)
		root.add_child(marker)
		doors.append(value)

	return {
		"ok": true,
		"root": root,
		"spec": spec,
		"doors": doors,
		"collision_count": (spec.get("collision_boxes", []) as Array).size(),
		"visual_count": visual_count,
		"node_count": count_nodes(root),
		"errors": [],
	}


static func collision_shape(boxes: Array) -> ConcavePolygonShape3D:
	var faces := PackedVector3Array()
	for value in boxes:
		var box: Dictionary = value
		var center: Vector3 = box.get("center", Vector3.ZERO)
		var size: Vector3 = box.get("size", Vector3.ONE)
		var hx: float = maxf(0.001, size.x * 0.5)
		var hy: float = maxf(0.001, size.y * 0.5)
		var hz: float = maxf(0.001, size.z * 0.5)
		var p0: Vector3 = center + Vector3(-hx, -hy, -hz)
		var p1: Vector3 = center + Vector3(hx, -hy, -hz)
		var p2: Vector3 = center + Vector3(hx, -hy, hz)
		var p3: Vector3 = center + Vector3(-hx, -hy, hz)
		var p4: Vector3 = center + Vector3(-hx, hy, -hz)
		var p5: Vector3 = center + Vector3(hx, hy, -hz)
		var p6: Vector3 = center + Vector3(hx, hy, hz)
		var p7: Vector3 = center + Vector3(-hx, hy, hz)
		for triangle in [
			[p0, p1, p2], [p0, p2, p3],
			[p4, p6, p5], [p4, p7, p6],
			[p0, p4, p5], [p0, p5, p1],
			[p3, p2, p6], [p3, p6, p7],
			[p0, p3, p7], [p0, p7, p4],
			[p1, p5, p6], [p1, p6, p2],
		]:
			for vertex in triangle:
				faces.append(vertex)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.set_backface_collision_enabled(true)
	return shape


static func unit_box() -> BoxMesh:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
	return _unit_box


static func count_nodes(node: Node) -> int:
	if node == null:
		return 0
	var total: int = 1
	for child in node.get_children():
		total += count_nodes(child)
	return total


static func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)


static func _window_opening(center: float, rng: RandomNumberGenerator) -> Dictionary:
	var width_variation: float = rng.randf_range(-0.12, 0.12)
	var half: float = WINDOW_WIDTH * 0.5 + width_variation
	return {
		"from": center - half,
		"to": center + half,
		"bottom": WINDOW_SILL,
		"top": WINDOW_SILL + WINDOW_HEIGHT,
	}


static func _add_wall_axis(
	boxes: Array, axis: String, fixed: float, start: float, end: float,
	base_y: float, openings: Array, surface: String
) -> void:
	for segment in _wall_segments(start, end, openings):
		var along_start: float = segment[0]
		var along_end: float = segment[1]
		var bottom: float = segment[2]
		var top: float = segment[3]
		if along_end - along_start <= 0.001 or top - bottom <= 0.001:
			continue
		var along_center: float = (along_start + along_end) * 0.5
		var center: Vector3
		var size: Vector3
		if axis == "x":
			center = Vector3(along_center, base_y + (bottom + top) * 0.5, fixed)
			size = Vector3(along_end - along_start, top - bottom, WALL_THICKNESS)
		else:
			center = Vector3(fixed, base_y + (bottom + top) * 0.5, along_center)
			size = Vector3(WALL_THICKNESS, top - bottom, along_end - along_start)
		_add_box(boxes, center, size, surface, true, "wall")


static func _wall_segments(start: float, end: float, openings: Array) -> Array:
	var sorted: Array = openings.duplicate()
	sorted.sort_custom(func(a, b): return float(a["from"]) < float(b["from"]))
	var segments: Array = []
	var cursor: float = start
	for value in sorted:
		var opening: Dictionary = value
		var from: float = clampf(float(opening["from"]), start, end)
		var to: float = clampf(float(opening["to"]), start, end)
		if to <= from:
			continue
		if from > cursor:
			segments.append([cursor, from, 0.0, WALL_HEIGHT])
		if float(opening["bottom"]) > 0.0:
			segments.append([from, to, 0.0, float(opening["bottom"])])
		if float(opening["top"]) < WALL_HEIGHT:
			segments.append([from, to, float(opening["top"]), WALL_HEIGHT])
		cursor = maxf(cursor, to)
	if cursor < end:
		segments.append([cursor, end, 0.0, WALL_HEIGHT])
	return segments


static func _add_box(
	boxes: Array, center: Vector3, size: Vector3, surface: String,
	solid: bool, kind: String
) -> void:
	boxes.append({
		"center": center,
		"size": size,
		"surface": surface,
		"solid": solid,
		"kind": kind,
	})


static func _estimate_nodes(boxes: Array, doors: Array) -> int:
	var surfaces: Dictionary = {}
	for value in boxes:
		surfaces[str(value.get("surface", "concrete"))] = true
	return 2 + surfaces.size() + doors.size()


static func _as_cell(value: Variant, errors: Array) -> Vector2i:
	match typeof(value):
		TYPE_VECTOR2I:
			return value
		TYPE_VECTOR2:
			var point: Vector2 = value
			return Vector2i(int(point.x), int(point.y))
		TYPE_ARRAY:
			var values: Array = value
			if values.size() >= 2:
				return Vector2i(int(values[0]), int(values[1]))
		TYPE_DICTIONARY:
			var values: Dictionary = value
			return Vector2i(int(values.get("x", 0)), int(values.get("y", 0)))
	errors.append("edificio: cell debe ser Vector2i o una pareja de enteros")
	return Vector2i.ZERO


static func _clamped_int(value: Variant, minimum: int, maximum: int) -> int:
	var number: float = 0.0
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			number = float(value)
		TYPE_STRING:
			number = float(str(value))
		_:
			number = float(minimum)
	return clampi(int(round(number)), minimum, maximum)


static func _failure(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"boxes": [],
		"collision_boxes": [],
		"doors": [],
		"footprint": [],
		"node_estimate": 0,
		"errors": errors.duplicate(),
	}
