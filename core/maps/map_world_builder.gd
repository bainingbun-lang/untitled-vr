class_name MapWorldBuilder
extends RefCounted

const WorldMaterialsScript = preload("res://core/maps/world_materials.gd")
const BuildingScript = preload("res://core/maps/building_generator.gd")
const VrPerformance = preload("res://core/vr/vr_performance.gd")
const RemoteLog = preload("res://core/debug/remote_log.gd")

const MAX_NODES: int = 200
const MAX_OBSTACLES: int = 8
const MAX_PROPS: int = 6
const MAX_SPAWN_MARKERS: int = 16
const GAMEPLAY_NODES: int = 60
const FLOOR_THICKNESS: float = 0.5
const WALL_HEIGHT: float = 2.0
const WALL_THICKNESS: float = 0.5
const OBSTACLE_SIZE: float = 0.8
const OBSTACLE_HEIGHT: float = 1.2
const PROP_INSET: float = 1.5
const MODEL_ROAD_TILE: String = "res://assets/models/maps/city-roads/tile-low.glb"
const MODEL_GROUND_GRASS: String = "res://assets/models/maps/nature/ground_grass.glb"
const MODEL_BARREL: String = "res://assets/models/props/barrel_01/model.gltf"
const MODEL_CRATE: String = "res://assets/models/props/wooden_crate_02/model.gltf"
const MODEL_ROCK: String = "res://assets/models/maps/nature/rock_largeA.glb"
const MODEL_TANK: String = "res://assets/models/maps/city-industrial/detail-tank.glb"
const MODEL_TREE_DEFAULT: String = "res://assets/models/maps/nature/tree_default.glb"
const MODEL_TREE_OAK: String = "res://assets/models/maps/nature/tree_oak.glb"
const MODEL_TREE_PINE: String = "res://assets/models/maps/nature/tree_pineDefaultA.glb"
const MODEL_BUSH: String = "res://assets/models/maps/nature/plant_bush.glb"
const MODEL_FENCE: String = "res://assets/models/maps/nature/fence_simple.glb"
const MODEL_CAR: String = "res://assets/models/maps/car/taxi.glb"
const VEGETATION_MARGIN: float = 1.0
const FENCE_MARGIN: float = 0.5
const TREE_SPACING: float = 3.0
const BUSH_SPACING: float = 2.0
const FENCE_SPACING: float = 1.0
const MAX_TREES: int = 12
const MAX_BUSHES: int = 12
const MAX_PARKED_CARS: int = 8
const CAR_SPACING: float = 3.5
const GEOMETRY_CONVENTION: String = (
	"1 celda = 1 unidad * scale; grid[y][x] -> (x+0.5, 0, y+0.5); "
	+ "suelo caminable en y=0 (caja de 0.5 de grosor centrada en y=-0.25); "
	+ "boundaries.min/max definen el rectangulo jugable y se amplian 1.0 para incluir spawns; "
	+ "obstacles > obstacle_cells > grid ('#' es obstaculo, 'S' es spawn); "
	+ "obstaculos muestreados por paso deterministico para no exceder MAX_NODES; "
	+ "GAMEPLAY_NODES reserva hueco para HUD, hotbar y maniquies; "
	+ "props RigidBody3D del grupo physics_props distribuidos por meta.seed evitando spawns; "
	+ "props asentados por raycast a la capa 1 (suelo yace en y=0), visual alineado al fondo del collider, sin rotacion inicial y dormidos; "
	+ "superficies PBR triplanar y props glTF reales con colision convexa simple y set_meta('surface')"
)

static var _prop_multimesh_cache: Dictionary = {}
static var _prop_visual_mesh_cache: Dictionary = {}
static var _prop_visual_material_cache: Dictionary = {}


static func _build_vegetation(root: Node3D, bounds: AABB, spawn_points: Array, theme: String, perf: VrPerformance = null) -> void:
	var tree_path := MODEL_TREE_DEFAULT
	var bush_path := MODEL_BUSH
	if theme == "rural":
		tree_path = MODEL_TREE_OAK
	elif theme == "industrial":
		tree_path = MODEL_TREE_PINE
	
	var transforms_trees: Array = []
	var transforms_bushes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(bounds.position.x * 1000 + bounds.position.z)
	
	var min_x: float = bounds.position.x + VEGETATION_MARGIN
	var max_x: float = bounds.end.x - VEGETATION_MARGIN
	var min_z: float = bounds.position.z + VEGETATION_MARGIN
	var max_z: float = bounds.end.z - VEGETATION_MARGIN
	
	var tree_count: int = 0
	var bush_count: int = 0
	
	var cull_dist: float = 80.0
	if perf != null:
		cull_dist = perf.get_culling_distance()
	
	for x_pos in range(int(min_x), int(max_x), int(TREE_SPACING)):
		if tree_count >= MAX_TREES:
			break
		for z_pos in range(int(min_z), int(max_z), int(TREE_SPACING)):
			if tree_count >= MAX_TREES:
				break
			var point := Vector3(
				float(x_pos) + rng.randf_range(-0.3, 0.3),
				0.0,
				float(z_pos) + rng.randf_range(-0.3, 0.3)
			)
			if _too_close_planar(point, spawn_points, 3.5):
				continue
			transforms_trees.append(BuildingScript.model_transform(
				tree_path, point, rng.randf_range(0.0, TAU), Vector3(1.0, 1.0, 1.0)
			))
			tree_count += 1
	
	for x_pos in range(int(min_x), int(max_x), int(BUSH_SPACING)):
		if bush_count >= MAX_BUSHES:
			break
		for z_pos in range(int(min_z), int(max_z), int(BUSH_SPACING)):
			if bush_count >= MAX_BUSHES:
				break
			var point := Vector3(
				float(x_pos) + rng.randf_range(-0.4, 0.4),
				0.0,
				float(z_pos) + rng.randf_range(-0.4, 0.4)
			)
			if _too_close_planar(point, spawn_points, 2.5):
				continue
			transforms_bushes.append(BuildingScript.model_transform(
				bush_path, point, rng.randf_range(0.0, TAU), Vector3(0.7, 0.7, 0.7)
			))
			bush_count += 1
	
	if not transforms_trees.is_empty():
		var trees_node := BuildingScript.model_batch(root, "Trees", tree_path, transforms_trees, Vector3(1.0, 1.0, 1.0), cull_dist)
		if trees_node != null:
			trees_node.add_to_group("vegetation")
	if not transforms_bushes.is_empty():
		var bushes_node := BuildingScript.model_batch(root, "Bushes", bush_path, transforms_bushes, Vector3(0.7, 0.7, 0.7), cull_dist * 0.75)
		if bushes_node != null:
			bushes_node.add_to_group("vegetation")


static func _build_parked_cars(root: Node3D, bounds: AABB, spawn_points: Array, theme: String, perf: VrPerformance = null) -> void:
	if theme != "urbano" and theme != "industrial":
		return
	var path := MODEL_CAR
	if not ResourceLoader.exists(path):
		return
	var transforms: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(bounds.position.x) + "," + str(bounds.position.z) + ",1993")
	
	var min_x: float = bounds.position.x + VEGETATION_MARGIN
	var max_x: float = bounds.end.x - VEGETATION_MARGIN
	var min_z: float = bounds.position.z + VEGETATION_MARGIN
	var max_z: float = bounds.end.z - VEGETATION_MARGIN
	
	var count: int = 0
	for x_pos in range(int(min_x), int(max_x), int(CAR_SPACING)):
		if count >= MAX_PARKED_CARS:
			break
		for z_pos in range(int(min_z), int(max_z), int(CAR_SPACING)):
			if count >= MAX_PARKED_CARS:
				break
			var point := Vector3(
				float(x_pos) + rng.randf_range(-0.5, 0.5),
				0.0,
				float(z_pos) + rng.randf_range(-0.5, 0.5)
			)
			if _too_close_planar(point, spawn_points, 4.0):
				continue
			if _too_close_planar(point, [], 3.5):
				continue
			transforms.append(BuildingScript.model_transform(
				path, point, rng.randf_range(0.0, TAU), Vector3(1.0, 1.0, 1.0)
			))
			count += 1
	
	var cull_dist: float = 80.0
	if perf != null:
		cull_dist = perf.get_culling_distance()
	
	if not transforms.is_empty():
		var cars_node := BuildingScript.model_batch(root, "ParkedCars", path, transforms, Vector3(1.0, 1.0, 1.0), cull_dist)
		if cars_node != null:
			cars_node.add_to_group("parked_car")


static func _build_fences(root: Node3D, bounds: AABB, theme: String, perf: VrPerformance = null) -> void:
	if theme != "rural" and theme != "industrial":
		return
	var path := MODEL_FENCE
	if not ResourceLoader.exists(path):
		return
	var transforms: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(bounds.position.x) + "," + str(bounds.position.z) + ",997")
	
	var min_x: float = bounds.position.x + FENCE_MARGIN
	var max_x: float = bounds.end.x - FENCE_MARGIN
	var min_z: float = bounds.position.z + FENCE_MARGIN
	var max_z: float = bounds.end.z - FENCE_MARGIN
	
	var count: int = 0
	for x_pos in range(int(min_x), int(max_x), int(FENCE_SPACING)):
		if count >= 20:
			break
		for z_pos in [int(min_z), int(max_z)]:
			if count >= 20:
				break
			var point := Vector3(
				float(x_pos) + rng.randf_range(-0.2, 0.2),
				0.0,
				float(z_pos) + rng.randf_range(-0.2, 0.2)
			)
			if _too_close_planar(point, [], 1.5):
				continue
			transforms.append(BuildingScript.model_transform(
				path, point, PI * 0.5, Vector3(2.0, 1.0, 0.2)
			))
			count += 1
	
	for z_pos in range(int(min_z), int(max_z), int(FENCE_SPACING)):
		if count >= 20:
			break
		for x_pos in [int(min_x), int(max_x)]:
			if count >= 20:
				break
			var point := Vector3(
				float(x_pos) + rng.randf_range(-0.2, 0.2),
				0.0,
				float(z_pos) + rng.randf_range(-0.2, 0.2)
			)
			if _too_close_planar(point, [], 1.5):
				continue
			transforms.append(BuildingScript.model_transform(
				path, point, 0.0, Vector3(2.0, 1.0, 0.2)
			))
			count += 1
	
	var cull_dist: float = 70.0
	if perf != null:
		cull_dist = perf.get_culling_distance()
	
	if not transforms.is_empty():
		var fences_node := BuildingScript.model_batch(root, "Fences", path, transforms, Vector3(2.0, 1.0, 0.2), cull_dist)
		if fences_node != null:
			fences_node.add_to_group("fence")


static func build(meta: Dictionary, parent: Node3D, perf: VrPerformance = null) -> Dictionary:
	var map_label := str(meta.get("name", meta.get("id", "?")))
	RemoteLog.crumb("construyendo mapa " + map_label)
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

	var mobile := WorldMaterialsScript.is_mobile()
	var ground_material := WorldMaterialsScript.surface_material("ground", mobile)
	var wall_material := WorldMaterialsScript.surface_material("brick", mobile)
	var obstacle_materials := [
		WorldMaterialsScript.surface_material("concrete", mobile),
		WorldMaterialsScript.surface_material("wood", mobile),
		WorldMaterialsScript.surface_material("metal", mobile),
	]
	var obstacle_surfaces := ["concrete", "wood", "metal"]

	var theme_name := str(meta.get("theme", ""))
	var time_of_day := str(meta.get("time_of_day", "atardecer"))
	_build_floor(root, bounds, ground_material, perf)
	_build_real_ground(root, bounds, theme_name, perf)
	var diag_empty := bool(meta.get("diag_empty", false))
	var props: Array = []
	if not diag_empty:
		_build_walls(root, bounds, wall_material, "brick", perf)
		_build_obstacles(root, obstacle_points, obstacle_materials, obstacle_surfaces, theme_name, perf)
		_build_vegetation(root, bounds, spawn_points, theme_name, perf)
		_build_fences(root, bounds, theme_name, perf)
		_build_parked_cars(root, bounds, spawn_points, theme_name, perf)
	_build_environment(root, time_of_day, theme_name)
	_build_spawn_markers(root, spawn_points, marker_count)
	if not diag_empty:
		props = populate_physics_props(root, meta, bounds, spawn_points, prop_limit, null, perf)

	var report: Dictionary = {
		"ok": true,
		"spawn_points": spawn_points,
		"bounds": bounds,
		"errors": [],
		"props": props,
		"obstacle_count": obstacle_points.size(),
		"node_count": count_nodes(root),
		"time_of_day": time_of_day,
		"theme": theme_name,
	}
	if meta.has("theme") and ResourceLoader.exists("res://core/maps/map_themes.gd"):
		var theme_script: Script = load("res://core/maps/map_themes.gd") as Script
		if theme_script != null and theme_script.has_method("decorate_builder_report"):
			report = theme_script.call("decorate_builder_report", root, meta, report)
	RemoteLog.crumb("construido mapa " + map_label)
	return report


static func create_physics_prop(
	parent: Node3D, position: Vector3, kind: String = "barrel_metal", size: float = 0.6,
	material: StandardMaterial3D = null, perf: VrPerformance = null
) -> RigidBody3D:
	var config := WorldMaterialsScript.prop_config(kind)
	var base_height := maxf(0.05, float(config.get("height", 0.8)))
	var ratio := clampf(size / 0.6, 0.4, 3.0)
	var height := base_height * ratio
	var shape := _collision_shape(config, height)
	var shape_height := _shape_height(shape)
	var ground_y := _estimate_ground_y(position)
	var surface := _ground_hit(parent, position + Vector3.UP * 2.0)
	if not surface.is_empty():
		var hit_pos: Vector3 = surface.get("position", position)
		var hit_normal: Vector3 = surface.get("normal", Vector3.UP)
		if hit_normal.y > 0.5:
			ground_y = hit_pos.y

	var body := RigidBody3D.new()
	body.name = "Prop_%s" % str(config.get("kind", kind))
	body.collision_layer = 2
	body.collision_mask = 1
	body.position = Vector3(position.x, ground_y + shape_height * 0.5, position.z)
	body.mass = maxf(0.5, float(config.get("mass", 8.0)) * ratio)
	body.linear_damp = 0.6
	body.angular_damp = 0.9
	body.can_sleep = true
	body.set_meta("surface", str(config.get("surface", "metal")))
	body.set_meta("prop_kind", str(config.get("kind", kind)))

	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var multimesh_instance := _get_or_create_prop_multimesh(parent, str(config.get("kind", kind)), perf)
	if multimesh_instance != null:
		var bounds := BuildingScript.model_bounds(str(config.get("path", "")))
		var fit_transform := BuildingScript.model_transform(
			str(config.get("path", "")), Vector3.ZERO, 0.0, Vector3.ONE, false
		)
		var visual_transform := Transform3D(
			fit_transform.basis,
			Vector3(0, -shape_height * 0.5 + 0.01, 0)
		)
		_add_prop_visual_instance(multimesh_instance, body.transform * visual_transform)

	body.add_to_group("physics_props")
	if parent != null:
		parent.add_child(body)
		body.sleeping = true
	return body


static func populate_physics_props(
	parent: Node3D, meta: Dictionary, bounds: AABB, spawn_points: Array, limit: int,
	material: StandardMaterial3D = null, perf: VrPerformance = null
) -> Array:
	var result: Array = []
	if parent == null or limit <= 0:
		return result

	_prop_multimesh_cache.clear()
	_prop_visual_mesh_cache.clear()
	_prop_visual_material_cache.clear()

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
	var bodies: Array = []
	var kinds: Array = []
	while result.size() < limit and attempts < limit * 40:
		attempts += 1
		var point := Vector3(
			rng.randf_range(min_x, max_x),
			0.7,
			rng.randf_range(min_z, max_z)
		)
		if _too_close_planar(point, spawn_points, 2.8) or _too_close(point, placed, 1.4):
			continue
		var kind: String = WorldMaterialsScript.prop_kind(rng.randi())
		placed.append(point)
		var body := create_physics_prop(parent, point, kind, 0.6, null, perf)
		bodies.append(body)
		kinds.append(kind)
		result.append(body)

	for i in range(bodies.size()):
		var body: RigidBody3D = bodies[i]
		var kind: String = kinds[i]
		var multimesh_instance: MultiMeshInstance3D = _prop_multimesh_cache.get(kind, null)
		if multimesh_instance != null:
			var config := WorldMaterialsScript.prop_config(kind)
			var base_height := maxf(0.05, float(config.get("height", 0.8)))
			var ratio := clampf(0.6 / 0.6, 0.4, 3.0)
			var height := base_height * ratio
			var shape := _collision_shape(config, height)
			var shape_height := _shape_height(shape)
			var bounds_mesh := BuildingScript.model_bounds(str(config.get("path", "")))
			var fit_transform := BuildingScript.model_transform(
				str(config.get("path", "")), Vector3.ZERO, 0.0, Vector3.ONE, false
			)
			var visual_transform := Transform3D(
				fit_transform.basis,
				Vector3(0, -shape_height * 0.5 + 0.01, 0)
			)
			_add_prop_visual_instance(multimesh_instance, body.global_transform * visual_transform)

	return result


static func _collision_shape(config: Dictionary, height: float) -> Shape3D:
	var dims: Array = config.get("collision", [0.6, height, 0.6])
	var base_height := maxf(0.05, float(config.get("height", height)))
	var ratio := height / base_height
	var width := maxf(0.05, float(dims[0]) * ratio)
	var depth := maxf(0.05, float(dims[2]) * ratio)
	var shape_height := maxf(0.05, float(dims[1]) * ratio)
	if str(config.get("shape", "box")) == "cylinder":
		var cylinder := CylinderShape3D.new()
		cylinder.radius = width * 0.5
		cylinder.height = shape_height
		return cylinder
	var box := BoxShape3D.new()
	box.size = Vector3(width, shape_height, depth)
	return box


static func _shape_height(shape: Shape3D) -> float:
	if shape is CylinderShape3D:
		return maxf(0.05, (shape as CylinderShape3D).height)
	if shape is BoxShape3D:
		return maxf(0.05, (shape as BoxShape3D).size.y)
	if shape is CapsuleShape3D:
		return maxf(0.05, (shape as CapsuleShape3D).height)
	return 0.8


static func _ground_hit(parent: Node, from: Vector3) -> Dictionary:
	var world_3d: World3D = parent.get_world_3d() if parent is Node3D else null
	if world_3d == null or world_3d.direct_space_state == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		from, from - Vector3.UP * 4.0
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 1
	return world_3d.direct_space_state.intersect_ray(query)

static func _estimate_ground_y(position: Vector3) -> float:
	return 0.0

static func _get_or_create_prop_multimesh(root: Node3D, kind: String, perf: VrPerformance = null) -> MultiMeshInstance3D:
	if _prop_multimesh_cache.has(kind):
		return _prop_multimesh_cache[kind]
	
	var config := WorldMaterialsScript.prop_config(kind)
	var path: String = str(config.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	
	if not _prop_visual_mesh_cache.has(kind):
		var packed := load(path) as PackedScene
		if packed != null:
			var instance: Node = packed.instantiate()
			if instance != null:
				var mesh_instance: MeshInstance3D = _find_first_mesh_instance(instance)
				if mesh_instance != null and mesh_instance.mesh != null:
					_prop_visual_mesh_cache[kind] = mesh_instance.mesh
					_prop_visual_material_cache[kind] = mesh_instance.material_override
				instance.free()
	
	var mesh: Mesh = _prop_visual_mesh_cache.get(kind, null)
	if mesh == null:
		return null
	
	var multimesh_instance := MultiMeshInstance3D.new()
	multimesh_instance.name = "PropVisuals_%s" % kind
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = 0
	multimesh_instance.multimesh = multimesh
	var material: Material = _prop_visual_material_cache.get(kind, null)
	if material != null:
		multimesh_instance.material_override = material
	multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var cull_dist: float = 80.0
	if perf != null:
		cull_dist = perf.get_culling_distance()
	multimesh_instance.visibility_range_end = cull_dist
	multimesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	root.add_child(multimesh_instance)
	_prop_multimesh_cache[kind] = multimesh_instance
	return multimesh_instance

static func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var result := _find_first_mesh_instance(child)
		if result != null:
			return result
	return null

static func _add_prop_visual_instance(multimesh_instance: MultiMeshInstance3D, transform: Transform3D) -> int:
	var multimesh: MultiMesh = multimesh_instance.multimesh
	if multimesh == null:
		return -1
	var current_count: int = multimesh.instance_count
	multimesh.instance_count = current_count + 1
	multimesh.set_instance_transform(current_count, transform)
	return current_count

static func _fit_visual(visual: Node3D, target_height: float) -> void:
	var bounds := _visual_aabb(visual)
	if bounds.size.y <= 0.0001:
		return
	var scale := clampf(target_height / bounds.size.y, 0.05, 20.0)
	visual.scale = Vector3(scale, scale, scale)
	var bottom_offset := -target_height * 0.5 + 0.01
	visual.position = Vector3(
		-bounds.get_center().x * scale,
		-bounds.position.y * scale + bottom_offset,
		-bounds.get_center().z * scale
	)


static func _visual_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var instance := node as MeshInstance3D
			if instance.mesh != null:
				var box: AABB = instance.mesh.get_aabb()
				var transform: Transform3D = instance.transform
				var cursor: Node = instance.get_parent()
				while cursor != null and cursor != root:
					if cursor is Node3D:
						transform = (cursor as Node3D).transform * transform
					cursor = cursor.get_parent()
				box = transform * box
				if found:
					result = result.merge(box)
				else:
					result = box
					found = true
		for child in node.get_children():
			stack.append(child)
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


static func _build_floor(root: Node3D, bounds: AABB, material: StandardMaterial3D, perf: VrPerformance = null) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", "dirt")
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
	mesh_instance.visible = false
	if perf != null:
		mesh_instance.visibility_range_end = perf.get_culling_distance() * 1.5
		mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	body.add_child(mesh_instance)
	body.position = Vector3(
		bounds.position.x + bounds.size.x * 0.5,
		-FLOOR_THICKNESS * 0.5,
		bounds.position.z + bounds.size.z * 0.5
	)
	root.add_child(body)


static func _build_real_ground(root: Node3D, bounds: AABB, theme: String, perf: VrPerformance = null) -> void:
	var path := MODEL_GROUND_GRASS
	if theme == "urbano" or theme == "industrial":
		path = MODEL_ROAD_TILE
	if not ResourceLoader.exists(path):
		return
	var transforms: Array = []
	var columns: int = maxi(1, int(ceil(bounds.size.x)))
	var rows: int = maxi(1, int(ceil(bounds.size.z)))
	for y in range(rows):
		for x in range(columns):
			var position := Vector3(
				bounds.position.x + float(x) + 0.5,
				0.01,
				bounds.position.z + float(y) + 0.5
			)
			transforms.append(BuildingScript.model_transform(path, position, 0.0, Vector3.ZERO))
	
	var cull_dist: float = 90.0
	if perf != null:
		cull_dist = perf.get_culling_distance() * 1.2
	
	BuildingScript.model_batch(
		root, "GroundTiles", path, transforms, Vector3(1.02, 0.04, 1.02), cull_dist
	)


static func _build_walls(
	root: Node3D, bounds: AABB, material: StandardMaterial3D, surface: String, perf: VrPerformance = null
) -> void:
	var center_x: float = bounds.position.x + bounds.size.x * 0.5
	var center_z: float = bounds.position.z + bounds.size.z * 0.5
	var span_x: float = bounds.size.x + WALL_THICKNESS * 2.0
	var span_z: float = bounds.size.z + WALL_THICKNESS * 2.0
	var center_y: float = WALL_HEIGHT * 0.5
	
	var cull_dist: float = 80.0
	if perf != null:
		cull_dist = perf.get_culling_distance()
	
	_static_box(
		root, "WallNorth",
		Vector3(center_x, center_y, bounds.position.z - WALL_THICKNESS * 0.5),
		Vector3(span_x, WALL_HEIGHT, WALL_THICKNESS), material, surface, cull_dist
	)
	_static_box(
		root, "WallSouth",
		Vector3(center_x, center_y, bounds.end.z + WALL_THICKNESS * 0.5),
		Vector3(span_x, WALL_HEIGHT, WALL_THICKNESS), material, surface, cull_dist
	)
	_static_box(
		root, "WallWest",
		Vector3(bounds.position.x - WALL_THICKNESS * 0.5, center_y, center_z),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, span_z), material, surface, cull_dist
	)
	_static_box(
		root, "WallEast",
		Vector3(bounds.end.x + WALL_THICKNESS * 0.5, center_y, center_z),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, span_z), material, surface, cull_dist
	)


static func _static_box(
	root: Node3D, node_name: String, center: Vector3, size: Vector3,
	material: StandardMaterial3D, surface: String = "concrete", visibility_end: float = 0.0
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", surface)
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
	mesh_instance.visible = false
	if visibility_end > 0.0:
		mesh_instance.visibility_range_end = visibility_end
		mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	body.add_child(mesh_instance)
	body.position = center
	root.add_child(body)
	return body


static func _build_obstacles(
	root: Node3D, points: Array, materials: Array, surfaces: Array, theme: String, perf: VrPerformance = null
) -> void:
	var path := MODEL_CRATE
	var fit := Vector3(0.9, 0.9, 0.9)
	if theme == "urbano":
		path = MODEL_BARREL
		fit = Vector3(0.9, 1.2, 0.9)
	elif theme == "industrial":
		path = MODEL_TANK
		fit = Vector3(1.4, 1.2, 1.4)
	elif theme == "rural":
		path = MODEL_ROCK
		fit = Vector3(1.3, 0.9, 1.3)
	var transforms: Array = []
	for i in range(points.size()):
		var point: Vector3 = points[i]
		var index := i % maxi(1, materials.size())
		_static_box(
			root, "Obstacle_%d" % i,
			Vector3(point.x, point.y + OBSTACLE_HEIGHT * 0.5, point.z),
			Vector3(OBSTACLE_SIZE, OBSTACLE_HEIGHT, OBSTACLE_SIZE),
			materials[index] as StandardMaterial3D,
			str(surfaces[index])
		)
		transforms.append(
			BuildingScript.model_transform(path, point, float(i) * 0.7, fit)
		)
	
	var cull_dist: float = 80.0
	if perf != null:
		cull_dist = perf.get_culling_distance()
	
	BuildingScript.model_batch(root, "ObstacleModels", path, transforms, fit, cull_dist)


static func _build_environment(root: Node3D, time_of_day: String, theme: String) -> void:
	root.set_meta("time_of_day", time_of_day)
	root.set_meta("theme", theme)
	var mobile := WorldMaterialsScript.is_mobile()
	var environment := WorldMaterialsScript.make_environment(mobile)
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var sky: Sky = environment.sky
	if sky == null:
		sky = Sky.new()
		environment.sky = sky
	if not (sky.sky_material is PanoramaSkyMaterial):
		var fallback := ProceduralSkyMaterial.new()
		fallback.sky_top_color = Color(0.16, 0.32, 0.58)
		fallback.sky_horizon_color = Color(0.70, 0.78, 0.86)
		fallback.ground_bottom_color = Color(0.26, 0.25, 0.23)
		sky.sky_material = fallback
	else:
		var panorama := sky.sky_material as PanoramaSkyMaterial
		var panorama_texture: Texture2D = WorldMaterialsScript.sky_texture()
		if panorama_texture != null:
			panorama.panorama = panorama_texture
		else:
			var fallback := ProceduralSkyMaterial.new()
			fallback.sky_top_color = Color(0.16, 0.32, 0.58)
			fallback.sky_horizon_color = Color(0.70, 0.78, 0.86)
			fallback.ground_bottom_color = Color(0.26, 0.25, 0.23)
			sky.sky_material = fallback
	var sun_color := Color(1.0, 0.72, 0.48)
	var sun_energy := 1.2 if not mobile else 1.0
	var sun_rotation := Vector3(-24.0, -38.0, 0.0)
	var fog_color := Color(0.74, 0.78, 0.82)
	var fog_density := 0.0025
	if time_of_day == "dia":
		sun_color = Color(1.0, 0.90, 0.78)
		sun_energy = 1.4 if not mobile else 1.2
		sun_rotation = Vector3(-42.0, -38.0, 0.0)
		fog_color = Color(0.78, 0.84, 0.88)
		fog_density = 0.0012
	elif time_of_day == "noche":
		sun_color = Color(0.80, 0.70, 0.58)
		sun_energy = 0.48 if not mobile else 0.40
		sun_rotation = Vector3(-14.0, -38.0, 0.0)
		fog_color = Color(0.15, 0.19, 0.30)
		fog_density = 0.006 if mobile else 0.008
	environment.fog_enabled = true
	environment.fog_light_color = fog_color
	environment.fog_density = fog_density if not mobile else fog_density * 0.7
	environment.fog_sun_scatter = 0.03 if time_of_day != "noche" else 0.01
	environment.ambient_light_energy = 0.3 if time_of_day == "noche" else (0.55 if mobile else 0.7)
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	root.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.rotation_degrees = sun_rotation
	sun.shadow_enabled = not mobile
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.02
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


static func _too_close_planar(point: Vector3, others: Array, distance: float) -> bool:
	for other in others:
		var other_point: Vector3 = other
		var dx: float = point.x - other_point.x
		var dz: float = point.z - other_point.z
		if dx * dx + dz * dz < distance * distance:
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
