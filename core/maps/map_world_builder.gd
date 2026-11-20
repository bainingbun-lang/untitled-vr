class_name MapWorldBuilder
extends RefCounted

const MAX_NODES: int = 180
const MAX_OBSTACLES: int = 32
const MAX_PROPS: int = 6
const MAX_SPAWN_MARKERS: int = 16
const GAMEPLAY_NODES: int = 60
const FLOOR_THICKNESS: float = 0.5
const WALL_HEIGHT: float = 2.0
const WALL_THICKNESS: float = 0.5
const OBSTACLE_SIZE: float = 0.8
const OBSTACLE_HEIGHT: float = 1.2
const PROP_INSET: float = 1.5
const GEOMETRY_CONVENTION: String = (
	"1 celda = 1 unidad * scale; grid[y][x] -> (x+0.5, 0, y+0.5); "
	+ "suelo caminable en y=0 (caja de 0.5 de grosor centrada en y=-0.25); "
	+ "boundaries.min/max definen el rectangulo jugable y se amplian 1.0 para incluir spawns; "
	+ "obstacles > obstacle_cells > grid ('#' es obstaculo, 'S' es spawn); "
	+ "obstaculos muestreados por paso deterministico para no exceder MAX_NODES; "
	+ "GAMEPLAY_NODES reserva hueco para HUD, hotbar y maniquies; "
	+ "props RigidBody3D del grupo physics_props distribuidos por meta.seed evitando spawns"
)


static func build(meta: Dictionary, parent: Node3D) -> Dictionary:
	var errors: Array = []
	if parent == null:
		errors.append("parent: se requiere un Node3D")
		return _failure(errors)

	var spawn_points: Array = _parse_spawns(meta, errors)
	if spawn_points.is_empty():
		if errors.is_empty():
			errors.append("spawn_points: el mapa no tiene puntos de aparicion validos")
		return _failure(errors)

	var bounds: AABB = _parse_bounds(meta, spawn_points)
	if bounds.size.x <= 0.0 or bounds.size.z <= 0.0:
		errors.append("boundaries: limites del mapa invalidos")
		return _failure(errors)

	var scale: float = _positive_float(meta.get("scale", 1.0), 1.0)
	var obstacle_points: Array = _limit_points(_obstacle_points(meta, scale), MAX_OBSTACLES)
	var marker_count: int = mini(spawn_points.size(), MAX_SPAWN_MARKERS)
	var reserved: int = 1 + 3 + 12 + 2 + marker_count + GAMEPLAY_NODES
	var available: int = MAX_NODES - reserved
	var obstacle_limit: int = mini(MAX_OBSTACLES, maxi(0, (available - MAX_PROPS * 3) / 3))
	obstacle_points = _limit_points(obstacle_points, obstacle_limit)
	var prop_limit: int = mini(MAX_PROPS, maxi(0, (available - obstacle_points.size() * 3) / 3))

	var root := Node3D.new()
	root.name = "WorldGeometry"
	parent.add_child(root)

	var ground_material := _material(Color(0.24, 0.34, 0.22))
	var wall_material := _material(Color(0.38, 0.36, 0.32))
	var obstacle_material := _material(Color(0.44, 0.43, 0.40))
	var prop_material := _material(Color(0.55, 0.32, 0.18))

	_build_floor(root, bounds, ground_material)
	_build_walls(root, bounds, wall_material)
	_build_obstacles(root, obstacle_points, obstacle_material)
	_build_environment(root)
	_build_spawn_markers(root, spawn_points, marker_count)
	var props: Array = populate_physics_props(
		root, meta, bounds, spawn_points, prop_limit, prop_material
	)

	return {
		"ok": true,
		"spawn_points": spawn_points,
		"bounds": bounds,
		"errors": [],
		"props": props,
		"obstacle_count": obstacle_points.size(),
		"node_count": count_nodes(root),
	}


static func create_physics_prop(
	parent: Node3D, position: Vector3, kind: String = "box", size: float = 0.6,
	material: StandardMaterial3D = null
) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Prop_%s" % kind
	body.collision_layer = 2
	body.collision_mask = 1
	body.position = position

	var shape: Shape3D
	var mesh: Mesh
	if kind == "barrel":
		var radius: float = size * 0.5
		var height: float = size * 1.4
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = radius
		cylinder_shape.height = height
		shape = cylinder_shape
		var cylinder_mesh := CylinderMesh.new()
		cylinder_mesh.top_radius = radius
		cylinder_mesh.bottom_radius = radius
		cylinder_mesh.height = height
		mesh = cylinder_mesh
	else:
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(size, size, size)
		shape = box_shape
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(size, size, size)
		mesh = box_mesh

	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	if material != null:
		visual.material_override = material
	body.add_child(visual)
	body.add_to_group("physics_props")
	parent.add_child(body)
	return body


static func populate_physics_props(
	parent: Node3D, meta: Dictionary, bounds: AABB, spawn_points: Array, limit: int,
	material: StandardMaterial3D = null
) -> Array:
	var result: Array = []
	if parent == null or limit <= 0:
		return result

	var rng := RandomNumberGenerator.new()
	rng.seed = _as_int(meta.get("seed", 0), 0)
	var inset_x: float = mini(PROP_INSET, bounds.size.x * 0.25)
	var inset_z: float = mini(PROP_INSET, bounds.size.z * 0.25)
	var min_x: float = bounds.position.x + inset_x
	var max_x: float = bounds.end.x - inset_x
	var min_z: float = bounds.position.z + inset_z
	var max_z: float = bounds.end.z - inset_z
	if max_x <= min_x or max_z <= min_z:
		return result

	var placed: Array = []
	var attempts: int = 0
	while result.size() < limit and attempts < limit * 40:
		attempts += 1
		var point := Vector3(
			rng.randf_range(min_x, max_x),
			0.7,
			rng.randf_range(min_z, max_z)
		)
		if _too_close(point, spawn_points, 2.0) or _too_close(point, placed, 1.4):
			continue
		var kind: String = "barrel" if rng.randi_range(0, 1) == 0 else "box"
		placed.append(point)
		result.append(create_physics_prop(parent, point, kind, 0.6, material))
	return result


static func count_nodes(node: Node) -> int:
	if node == null:
		return 0
	var total: int = 1
	for child in node.get_children():
		total += count_nodes(child)
	return total


static func _failure(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"spawn_points": [],
		"bounds": AABB(),
		"errors": errors.duplicate(),
		"props": [],
		"obstacle_count": 0,
		"node_count": 0,
	}


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.metallic = 0.0
	return material


static func _build_floor(root: Node3D, bounds: AABB, material: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(bounds.size.x, FLOOR_THICKNESS, bounds.size.z)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	body.position = Vector3(
		bounds.position.x + bounds.size.x * 0.5,
		-FLOOR_THICKNESS * 0.5,
		bounds.position.z + bounds.size.z * 0.5
	)
	root.add_child(body)


static func _build_walls(root: Node3D, bounds: AABB, material: StandardMaterial3D) -> void:
	var center_x: float = bounds.position.x + bounds.size.x * 0.5
	var center_z: float = bounds.position.z + bounds.size.z * 0.5
	var span_x: float = bounds.size.x + WALL_THICKNESS * 2.0
	var span_z: float = bounds.size.z + WALL_THICKNESS * 2.0
	var center_y: float = WALL_HEIGHT * 0.5
	_static_box(
		root, "WallNorth",
		Vector3(center_x, center_y, bounds.position.z - WALL_THICKNESS * 0.5),
		Vector3(span_x, WALL_HEIGHT, WALL_THICKNESS), material
	)
	_static_box(
		root, "WallSouth",
		Vector3(center_x, center_y, bounds.end.z + WALL_THICKNESS * 0.5),
		Vector3(span_x, WALL_HEIGHT, WALL_THICKNESS), material
	)
	_static_box(
		root, "WallWest",
		Vector3(bounds.position.x - WALL_THICKNESS * 0.5, center_y, center_z),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, span_z), material
	)
	_static_box(
		root, "WallEast",
		Vector3(bounds.end.x + WALL_THICKNESS * 0.5, center_y, center_z),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, span_z), material
	)


static func _static_box(
	root: Node3D, node_name: String, center: Vector3, size: Vector3,
	material: StandardMaterial3D
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	body.position = center
	root.add_child(body)
	return body


static func _build_obstacles(
	root: Node3D, points: Array, material: StandardMaterial3D
) -> void:
	for i in range(points.size()):
		var point: Vector3 = points[i]
		_static_box(
			root, "Obstacle_%d" % i,
			Vector3(point.x, point.y + OBSTACLE_HEIGHT * 0.5, point.z),
			Vector3(OBSTACLE_SIZE, OBSTACLE_HEIGHT, OBSTACLE_SIZE), material
		)


static func _build_environment(root: Node3D) -> void:
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.24, 0.42, 0.72)
	sky_material.sky_horizon_color = Color(0.64, 0.78, 0.88)
	sky_material.ground_bottom_color = Color(0.16, 0.18, 0.20)
	sky_material.ground_horizon_color = Color(0.40, 0.42, 0.44)
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.5
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	root.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.04
	root.add_child(sun)


static func _build_spawn_markers(root: Node3D, spawns: Array, count: int) -> void:
	for i in range(count):
		var marker := Marker3D.new()
		marker.name = "Spawn_%d" % i
		marker.position = spawns[i]
		marker.add_to_group("spawn_points")
		root.add_child(marker)


static func _parse_spawns(meta: Dictionary, errors: Array) -> Array:
	var raw: Variant = meta.get("spawn_points", null)
	if not (raw is Array):
		errors.append("spawn_points: se esperaba una lista de posiciones")
		return []
	var result: Array = []
	for item in raw:
		var point: Variant = _as_point(item)
		if point == null:
			continue
		if not result.has(point):
			result.append(point)
		if result.size() >= MAX_SPAWN_MARKERS:
			break
	return result


static func _parse_bounds(meta: Dictionary, spawns: Array) -> AABB:
	var min_point: Vector3 = Vector3(INF, INF, INF)
	var max_point: Vector3 = Vector3(-INF, -INF, -INF)
	var raw: Variant = meta.get("boundaries", null)
	if raw is Dictionary:
		var source: Dictionary = raw
		var low: Variant = _as_point(source.get("min", null))
		var high: Variant = _as_point(source.get("max", null))
		if low != null:
			min_point = low
		if high != null:
			max_point = high

	if is_inf(min_point.x) or is_inf(max_point.x):
		min_point = Vector3.ZERO
		max_point = Vector3.ZERO
		for item in _obstacle_points(meta, _positive_float(meta.get("scale", 1.0), 1.0)):
			var obstacle: Vector3 = item
			min_point.x = mini(min_point.x, obstacle.x)
			min_point.z = mini(min_point.z, obstacle.z)
			max_point.x = maxi(max_point.x, obstacle.x)
			max_point.z = maxi(max_point.z, obstacle.z)
		for item in spawns:
			var spawn: Vector3 = item
			min_point.x = mini(min_point.x, spawn.x)
			min_point.z = mini(min_point.z, spawn.z)
			max_point.x = maxi(max_point.x, spawn.x)
			max_point.z = maxi(max_point.z, spawn.z)
		min_point.x -= 2.0
		min_point.z -= 2.0
		max_point.x += 2.0
		max_point.z += 2.0

	for item in spawns:
		var spawn: Vector3 = item
		min_point.x = mini(min_point.x, spawn.x - 1.0)
		min_point.z = mini(min_point.z, spawn.z - 1.0)
		max_point.x = maxi(max_point.x, spawn.x + 1.0)
		max_point.z = maxi(max_point.z, spawn.z + 1.0)
	min_point.y = mini(min_point.y, 0.0)
	max_point.y = maxi(max_point.y, 1.0)
	return AABB(min_point, max_point - min_point)


static func _obstacle_points(meta: Dictionary, scale: float) -> Array:
	var result: Array = []
	var raw: Variant = meta.get("obstacles", null)
	if raw is Array:
		for item in raw:
			var point: Variant = _as_point(item)
			if point != null and not result.has(point):
				result.append(point)
		return result

	var cells: Variant = meta.get("obstacle_cells", null)
	if cells is Array:
		for item in cells:
			var cell_value: Variant = _as_cell(item)
			if cell_value == null:
				continue
			var cell: Vector2i = cell_value
			var point: Vector3 = Vector3(
				(float(cell.x) + 0.5) * scale, 0.0, (float(cell.y) + 0.5) * scale
			)
			if not result.has(point):
				result.append(point)
		return result

	var grid: Variant = meta.get("grid", null)
	if grid is Array:
		for y in range(grid.size()):
			var row: String = str(grid[y])
			for x in range(row.length()):
				if row.substr(x, 1) == "#":
					result.append(Vector3(
						(float(x) + 0.5) * scale, 0.0, (float(y) + 0.5) * scale
					))
	return result


static func _limit_points(points: Array, limit: int) -> Array:
	if limit <= 0 or points.is_empty():
		return []
	if points.size() <= limit:
		return points.duplicate()
	var result: Array = []
	for i in range(limit):
		var index: int = int(float(i) * float(points.size()) / float(limit))
		result.append(points[mini(index, points.size() - 1)])
	return result


static func _too_close(point: Vector3, others: Array, distance: float) -> bool:
	for other in others:
		var other_point: Vector3 = other
		if point.distance_to(other_point) < distance:
			return true
	return false


static func _as_point(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR3:
			var point: Vector3 = value
			if _finite(point.x) and _finite(point.y) and _finite(point.z):
				return point
		TYPE_VECTOR3I:
			var point: Vector3i = value
			return Vector3(point)
		TYPE_VECTOR2:
			var point: Vector2 = value
			if _finite(point.x) and _finite(point.y):
				return Vector3(point.x, 0.0, point.y)
		TYPE_VECTOR2I:
			var point: Vector2i = value
			return Vector3(float(point.x), 0.0, float(point.y))
		TYPE_ARRAY:
			var values: Array = value
			if values.size() < 3:
				return null
			var x: Variant = _number(values[0])
			var y: Variant = _number(values[1])
			var z: Variant = _number(values[2])
			if x != null and y != null and z != null:
				return Vector3(x, y, z)
		TYPE_DICTIONARY:
			var values: Dictionary = value
			if values.has("position"):
				return _as_point(values["position"])
			var x: Variant = _number(values.get("x", 0.0))
			var y: Variant = _number(values.get("y", 0.0))
			var z: Variant = _number(values.get("z", 0.0))
			if x != null and y != null and z != null:
				return Vector3(x, y, z)
	return null


static func _as_cell(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2I:
			return value
		TYPE_VECTOR2:
			var point: Vector2 = value
			return Vector2i(int(point.x), int(point.y))
		TYPE_VECTOR3:
			var point: Vector3 = value
			return Vector2i(int(point.x), int(point.z))
		TYPE_ARRAY:
			var values: Array = value
			if values.size() < 2:
				return null
			var x: Variant = _as_int(values[0], -1)
			var y: Variant = _as_int(values[1], -1)
			if int(x) < 0 or int(y) < 0:
				return null
			return Vector2i(int(x), int(y))
	return null


static func _number(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			var number: float = float(value)
			return number if _finite(number) else null
		TYPE_STRING:
			var text: String = str(value).strip_edges()
			if not text.is_valid_float():
				return null
			var number: float = text.to_float()
			return number if _finite(number) else null
		_:
			return null


static func _as_int(value: Variant, fallback: int) -> int:
	var parsed: Variant = _number(value)
	if parsed == null:
		return fallback
	var number: float = float(parsed)
	if floor(number) != number:
		return fallback
	return int(clampi(int(number), -2147483648, 2147483647))


static func _positive_float(value: Variant, fallback: float) -> float:
	var parsed: Variant = _number(value)
	if parsed == null or float(parsed) <= 0.0:
		return fallback
	return float(parsed)


static func _finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
