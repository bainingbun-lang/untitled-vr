extends SceneTree

const ThemesScript = preload("res://core/maps/map_themes.gd")
const BuilderScript = preload("res://core/maps/map_world_builder.gd")
const ValidatorScript = preload("res://core/maps/map_validator.gd")
const MapCatalogScript = preload("res://core/maps/map_catalog.gd")
const MapRegistryScript = preload("res://core/maps/map_registry.gd")

var _checks := 0
var _failures: Array = []
var _case := ""
var _results: Dictionary = {}

const MAP_THEMES: Array = ["urbano", "industrial", "rural"]
const MAX_BUILD_TIME_MS: float = 2500.0
const MAX_NODES: int = 800
const MAX_DRAW_CALLS: int = 150
const MAX_TRIANGLES_PER_SCENE: int = 50000
const MIN_SPAWN_POINTS: int = 4

func _initialize() -> void:
	await _run()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _run() -> void:
	_results = {"themes": {}}
	var seeds: Dictionary = {"urbano": 1001, "industrial": 2002, "rural": 3003}

	_case = "validacion catalogo mapas"
	_validate_catalog()

	_case = "generacion y validacion por tema"
	for theme in MAP_THEMES:
		_test_theme(theme, seeds[theme])

	_case = "tiempos de construccion"
	_test_build_times()

	_case = "puntos de spawn validos"
	_test_spawn_points()

	_case = "vegetacion sin interseccion"
	_test_vegetation_no_interpenetration()

	_case = "cercas sin interseccion"
	_test_fences_no_interpenetration()

	_case = "coches aparcados sin interseccion"
	_test_parked_cars_no_interpenetration()

	_case = "navegacion y malla"
	_test_navigation()

	_case = "colisiones y fisica"
	_test_collisions()

	_case = "presupuesto movil"
	_test_mobile_budget()

	_case = "draw calls razonables"
	_test_draw_calls()

func _validate_catalog() -> void:
	var registry = MapRegistryScript.new()
	for theme in MAP_THEMES:
		var meta = _make_test_map_meta(theme)
		registry.register(meta)
	var catalog: MapCatalogScript = MapCatalogScript.new(registry)
	var maps: Array = catalog.get_available_maps()
	_expect(maps.size() >= 3, "catalogo tiene al menos 3 mapas")
	for theme in MAP_THEMES:
		var found: bool = false
		for map_info in maps:
			if str(map_info.get("theme", "")) == theme:
				found = true
				break
		_expect(found, "catalogo contiene mapa: %s" % theme)

func _make_test_map_meta(theme: String) -> Dictionary:
	return {
		"id": "test_map_" + theme,
		"theme": theme,
		"license": "MIT",
		"has_collisions": true,
		"has_navigation": true,
		"spawn_points": [Vector3(0, 0, 0)],
	}

func _test_theme(theme: String, seed: int) -> void:
	var meta: Dictionary = ThemesScript.generate(seed, {
		"theme": theme,
		"time_of_day": "dia",
		"theme_density": 0.55,
		"width": 24,
		"height": 18,
		"obstacle_density": 0.12,
		"spawn_count": 4,
	})
	_results.themes[theme] = {"meta": meta}

	_expect(bool(meta.get("ok", false)), "%s: generacion OK" % theme)
	_expect(str(meta.get("theme", "")) == theme, "%s: tema etiquetado" % theme)

	var validation: Dictionary = ValidatorScript.new().validate(meta)
	var status: int = int(validation.get("status", 99))
	_expect(status <= ValidatorScript.Status.COMPATIBLE_WITH_WARNINGS, "%s: meta valida (status=%d)" % [theme, status])
	if validation.has("errors"):
		for err in validation.errors:
			_expect(false, "%s: error validacion: %s" % [theme, str(err)])

	var data: Dictionary = meta.get("theme_data", {})
	_expect((data.get("buildings", []) as Array).size() > 0, "%s: tiene edificios" % theme)
	_expect((data.get("props", []) as Array).size() > 0, "%s: tiene props" % theme)
	_expect(bool(meta.get("has_navigation", false)), "%s: tiene navegacion" % theme)

	var spawns: Array = meta.get("spawn_points", [])
	_expect(spawns.size() >= MIN_SPAWN_POINTS, "%s: al menos %d spawn points (%d)" % [theme, MIN_SPAWN_POINTS, spawns.size()])

func _test_build_times() -> void:
	for theme in MAP_THEMES:
		var theme_data: Dictionary = _results.themes[theme]
		var meta: Dictionary = theme_data.meta
		var parent := Node3D.new()
		root.add_child(parent)

		var start_time: float = Time.get_ticks_msec()
		var report: Dictionary = BuilderScript.build(meta, parent)
		var elapsed_ms: float = Time.get_ticks_msec() - start_time

		theme_data.report = report
		theme_data.build_time_ms = elapsed_ms
		theme_data["parent"] = parent

		_expect(bool(report.get("ok", false)), "%s: build OK" % theme)
		_expect(elapsed_ms <= MAX_BUILD_TIME_MS, "%s: build time %.1fms <= %.1fms" % [theme, elapsed_ms, MAX_BUILD_TIME_MS])

		var node_count: int = int(report.get("node_count", 9999))
		_expect(node_count <= MAX_NODES, "%s: node count %d <= %d" % [theme, node_count, MAX_NODES])

	await process_frame
	for i in range(2):
		await physics_frame

func _test_spawn_points() -> void:
	for theme in MAP_THEMES:
		var theme_data: Dictionary = _results.themes[theme]
		var meta: Dictionary = theme_data.meta
		var parent: Node3D = theme_data.get("parent", null)
		if parent == null:
			_failures.append("[puntos de spawn validos] %s: parent no disponible" % theme)
			continue
		var spawns: Array = meta.get("spawn_points", [])

		await process_frame
		for i in range(3):
			await physics_frame

		var valid_count: int = 0
		var on_navmesh: int = 0
		var free_fall: int = 0
		var colliding: int = 0

		for spawn in spawns:
			var pos: Vector3 = Vector3(spawn.x, spawn.y, spawn.z)
			
			if _is_on_navmesh(parent, pos):
				on_navmesh += 1
			
			if _has_clearance(parent, pos, 1.5):
				valid_count += 1
			
			if _floor_hit(parent, pos):
				free_fall += 1
			else:
				colliding += 1

		theme_data.spawn_stats = {
			"total": spawns.size(),
			"valid": valid_count,
			"on_navmesh": on_navmesh,
			"free_fall": free_fall,
			"colliding": colliding
		}

		_expect(valid_count == spawns.size(), "%s: todos spawns validos (%d/%d)" % [theme, valid_count, spawns.size()])
		_expect(on_navmesh == spawns.size(), "%s: todos spawns en navmesh (%d/%d)" % [theme, on_navmesh, spawns.size()])
		_expect(free_fall == spawns.size(), "%s: todos spawns con suelo libre (%d/%d)" % [theme, free_fall, spawns.size()])
		_expect(colliding == 0, "%s: ningun spawn en colision (%d)" % [theme, colliding])

func _test_vegetation_no_interpenetration() -> void:
	for theme in MAP_THEMES:
		var theme_data: Dictionary = _results.themes[theme]
		var parent: Node3D = theme_data.get("parent", null)
		if parent == null:
			_failures.append("[vegetacion sin interseccion] %s: parent no disponible" % theme)
			continue

		await process_frame
		for i in range(2):
			await physics_frame

		var vegetation_nodes: Array = _find_nodes_by_group(parent, "vegetation")
		var interpenetrations: int = 0
		
		for i in range(vegetation_nodes.size()):
			var node_a: Node3D = vegetation_nodes[i]
			for j in range(i + 1, vegetation_nodes.size()):
				var node_b: Node3D = vegetation_nodes[j]
				if _check_interpenetration(node_a, node_b):
					interpenetrations += 1

		_expect(interpenetrations == 0, "%s: vegetacion sin intersecciones (%d)" % [theme, interpenetrations])

func _test_fences_no_interpenetration() -> void:
	for theme in MAP_THEMES:
		var theme_data: Dictionary = _results.themes[theme]
		var parent: Node3D = theme_data.get("parent", null)
		if parent == null:
			_failures.append("[cercas sin interseccion] %s: parent no disponible" % theme)
			continue

		await process_frame
		for i in range(2):
			await physics_frame

		var fence_nodes: Array = _find_nodes_by_group(parent, "fence")
		var interpenetrations: int = 0
		
		for i in range(fence_nodes.size()):
			var node_a: Node3D = fence_nodes[i]
			for j in range(i + 1, fence_nodes.size()):
				var node_b: Node3D = fence_nodes[j]
				if _check_interpenetration(node_a, node_b):
					interpenetrations += 1

		_expect(interpenetrations == 0, "%s: cercas sin intersecciones (%d)" % [theme, interpenetrations])

func _test_parked_cars_no_interpenetration() -> void:
	for theme in MAP_THEMES:
		var theme_data: Dictionary = _results.themes[theme]
		var parent: Node3D = theme_data.get("parent", null)
		if parent == null:
			_failures.append("[coches aparcados sin interseccion] %s: parent no disponible" % theme)
			continue

		await process_frame
		for i in range(2):
			await physics_frame

		var car_nodes: Array = _find_nodes_by_group(parent, "parked_car")
		var interpenetrations: int = 0
		
		for i in range(car_nodes.size()):
			var node_a: Node3D = car_nodes[i]
			for j in range(i + 1, car_nodes.size()):
				var node_b: Node3D = car_nodes[j]
				if _check_interpenetration(node_a, node_b):
					interpenetrations += 1

		_expect(interpenetrations == 0, "%s: coches aparcados sin intersecciones (%d)" % [theme, interpenetrations])

func _test_navigation() -> void:
	for theme in MAP_THEMES:
		var theme_data: Dictionary = _results.themes[theme]
		var parent: Node3D = theme_data.get("parent", null)
		if parent == null:
			_failures.append("[navegacion y malla] %s: parent no disponible" % theme)
			continue
		var meta: Dictionary = theme_data.meta

		await process_frame
		for i in range(2):
			await physics_frame

		var nav_region: NavigationRegion3D = _find_named(parent, "NavigationRegion") as NavigationRegion3D
		_expect(nav_region != null, "%s: NavigationRegion presente" % theme)

		if nav_region != null:
			var nav_mesh: NavigationMesh = nav_region.navigation_mesh
			_expect(nav_mesh != null, "%s: NavigationMesh asignado" % theme)
			
			if nav_mesh != null:
				var polygons: int = nav_mesh.get_polygons().size()
				_expect(polygons > 10, "%s: navmesh tiene poligonos (%d)" % [theme, polygons])

			var agent: NavigationAgent3D = NavigationAgent3D.new()
			parent.add_child(agent)
			var spawns: Array = meta.get("spawn_points", [])
			
			if spawns.size() >= 2:
				var start: Vector3 = Vector3(spawns[0].x, spawns[0].y, spawns[0].z)
				var end: Vector3 = Vector3(spawns[1].x, spawns[1].y, spawns[1].z)
				agent.target_position = end
				agent.avoidance_enabled = true
				await process_frame
				var path: Array = agent.get_final_path()
				_expect(path.size() >= 2, "%s: pathfinding entre spawns (%d puntos)" % [theme, path.size()])
			agent.queue_free()

func _test_collisions() -> void:
	for theme in MAP_THEMES:
		var theme_data: Dictionary = _results.themes[theme]
		var parent: Node3D = theme_data.get("parent", null)
		if parent == null:
			_failures.append("[colisiones y fisica] %s: parent no disponible" % theme)
			continue

		var collision_stats: Dictionary = _scan_collisions(parent)

		theme_data.collision_stats = collision_stats

		_expect(collision_stats.trimesh == 0, "%s: sin TrimeshCollisionShape3D (%d)" % [theme, collision_stats.trimesh])
		_expect(collision_stats.concave <= 10, "%s: ConcavePolygonShape3D razonable (%d)" % [theme, collision_stats.concave])
		_expect(collision_stats.primitive == 0, "%s: sin primitivas visibles (Box/Sphere/Cylinder) (%d)" % [theme, collision_stats.primitive])

func _test_mobile_budget() -> void:
	for theme in MAP_THEMES:
		var theme_data: Dictionary = _results.themes[theme]
		var parent: Node3D = theme_data.get("parent", null)
		if parent == null:
			_failures.append("[presupuesto movil] %s: parent no disponible" % theme)
			continue
		var report: Dictionary = theme_data.report

		var scan: Dictionary = _scan(parent)
		var models: int = int(scan.get("models", 0))
		var visible_primitives: int = int(scan.get("visible_primitives", 0))
		var paths: Array = scan.get("paths", [])

		var node_count: int = int(report.get("node_count", 9999))
		var mesh_instances: int = scan.get("mesh_instances", 0)

		theme_data.budget = {
			"nodes": node_count,
			"models": models,
			"mesh_instances": mesh_instances,
			"visible_primitives": visible_primitives,
			"unique_kits": paths.size()
		}

		_expect(node_count <= MAX_NODES, "%s: nodos %d <= %d" % [theme, node_count, MAX_NODES])
		_expect(visible_primitives == 0, "%s: sin primitivas visibles (%d)" % [theme, visible_primitives])
		_expect(models > 5, "%s: usa modelos GLB (%d)" % [theme, models])
		_expect(paths.size() >= 4, "%s: variedad kits (%d)" % [theme, paths.size()])

		var texture_sizes: Dictionary = _check_texture_sizes(parent)
		for tex_path in texture_sizes:
			var size: int = texture_sizes[tex_path]
			_expect(size <= 1024, "%s: textura %s <= 1024px (%d)" % [theme, tex_path, size])

func _test_draw_calls() -> void:
	for theme in MAP_THEMES:
		var theme_data: Dictionary = _results.themes[theme]
		var parent: Node3D = theme_data.get("parent", null)
		if parent == null:
			_failures.append("[draw calls razonables] %s: parent no disponible" % theme)
			continue

		var draw_calls: int = _estimate_draw_calls(parent)
		theme_data.draw_calls = draw_calls
		
		_expect(draw_calls <= MAX_DRAW_CALLS, "%s: draw calls %d <= %d" % [theme, draw_calls, MAX_DRAW_CALLS])

func _find_nodes_by_group(parent: Node, group: String) -> Array:
	var result: Array = []
	for child in parent.get_children():
		result.append_array(_find_nodes_by_group_recursive(child, group))
	return result

func _find_nodes_by_group_recursive(node: Node, group: String) -> Array:
	var result: Array = []
	if node is Node3D and node.is_in_group(group):
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_nodes_by_group_recursive(child, group))
	return result

func _check_interpenetration(node_a: Node3D, node_b: Node3D) -> bool:
	if node_a == null or node_b == null:
		return false
	
	var aabb_a: AABB = node_a.get_aabb()
	var aabb_b: AABB = node_b.get_aabb()
	
	var global_aabb_a: AABB = node_a.global_transform * aabb_a
	var global_aabb_b: AABB = node_b.global_transform * aabb_b
	
	return global_aabb_a.intersects(global_aabb_b)

func _scan_collisions(node: Node) -> Dictionary:
	var result: Dictionary = {"trimesh": 0, "concave": 0, "convex": 0, "primitive": 0}
	for child in node.get_children():
		var sub: Dictionary = _scan_collisions(child)
		result["trimesh"] = int(result["trimesh"]) + int(sub["trimesh"])
		result["concave"] = int(result["concave"]) + int(sub["concave"])
		result["convex"] = int(result["convex"]) + int(sub["convex"])
		result["primitive"] = int(result["primitive"]) + int(sub["primitive"])
		
		if child is CollisionShape3D:
			var shape: Shape3D = child.shape
			if shape != null:
				match shape.get_class():
					"ConcavePolygonShape3D":
						result["concave"] = int(result["concave"]) + 1
					"BoxShape3D", "SphereShape3D", "CapsuleShape3D", "CylinderShape3D":
						result["convex"] = int(result["convex"]) + 1
					_:
						result["trimesh"] = int(result["trimesh"]) + 1

		if child is MeshInstance3D and child.visible:
			var mesh: Mesh = child.mesh
			if mesh is BoxMesh or mesh is SphereMesh or mesh is CylinderMesh:
				result["primitive"] = int(result["primitive"]) + 1
	
	return result

func _scan(node: Node) -> Dictionary:
	var result: Dictionary = {"models": 0, "visible_primitives": 0, "paths": [], "mesh_instances": 0}
	for child in node.get_children():
		var sub: Dictionary = _scan(child)
		result["models"] = int(result["models"]) + int(sub["models"])
		result["visible_primitives"] = int(result["visible_primitives"]) + int(sub["visible_primitives"])
		result["mesh_instances"] = int(result["mesh_instances"]) + int(sub["mesh_instances"])
		for path in (sub["paths"] as Array):
			if not (result["paths"] as Array).has(path):
				(result["paths"] as Array).append(path)
	
	if node.has_meta("model_path"):
		result["models"] = int(result["models"]) + 1
		var path: String = str(node.get_meta("model_path"))
		if not (result["paths"] as Array).has(path):
			(result["paths"] as Array).append(path)
	
	if node is MeshInstance3D:
		result["mesh_instances"] = int(result["mesh_instances"]) + 1
		var mesh: Mesh = node.mesh
		if mesh != null and mesh is PrimitiveMesh and node.visible:
			result["visible_primitives"] = int(result["visible_primitives"]) + 1
	
	return result

func _find_named(node: Node, node_name: String) -> Node:
	if node_name.is_empty() or node.name == node_name:
		return node
	for child in node.get_children():
		var found: Node = _find_named(child, node_name)
		if found != null:
			return found
	return null

func _is_on_navmesh(node: Node, pos: Vector3) -> bool:
	var world: World3D = node.get_world_3d()
	if world == null:
		return false
	var nav_map: RID = world.get_navigation_map()
	if not nav_map.is_valid():
		return false
	var point: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, pos)
	return pos.distance_to(point) < 0.5

func _has_clearance(node: Node, pos: Vector3, radius: float) -> bool:
	var world: World3D = node.get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 2.0, pos - Vector3.UP * 0.5)
	query.collide_with_bodies = true
	query.exclude = [node.get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	return hit.is_empty()

func _floor_hit(node: Node, spawn: Vector3) -> bool:
	var world: World3D = node.get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(spawn + Vector3.UP * 2.0, spawn - Vector3.UP * 0.4)
	query.collide_with_bodies = true
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider", null)
	return collider != null and (collider.name == "Ground" or collider.name.begins_with("Building"))

func _check_texture_sizes(node: Node) -> Dictionary:
	var result: Dictionary = {}
	for child in node.get_children():
		var sub: Dictionary = _check_texture_sizes(child)
		for k in sub:
			result[k] = sub[k]
		
		if child is MeshInstance3D:
			var mesh: Mesh = child.mesh
			if mesh != null and not mesh is PrimitiveMesh:
				for i in range(mesh.get_surface_count()):
					var mat: Material = mesh.get_surface_material(i)
					if mat is StandardMaterial3D:
						var tex: Texture2D = mat.get_texture(StandardMaterial3D.TEXTURE_ALBEDO)
						if tex != null and tex is ImageTexture:
							var image: Image = (tex as ImageTexture).get_image()
							if image != null:
								var w: int = image.get_width()
								var h: int = image.get_height()
								var max_dim: int = max(w, h)
								var path: String = tex.get_path()
								if not result.has(path) or result[path] < max_dim:
									result[path] = max_dim
	
	return result

func _estimate_draw_calls(node: Node) -> int:
	var draw_calls: int = 0
	for child in node.get_children():
		draw_calls += _estimate_draw_calls(child)
	
	if node is MeshInstance3D and node.visible:
		var mesh: Mesh = node.mesh
		if mesh != null:
			draw_calls += 1
	
	return draw_calls

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])