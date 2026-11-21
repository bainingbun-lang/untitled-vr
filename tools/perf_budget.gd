class_name PerfBudget
extends RefCounted

const QUEST_72_FPS_BUDGET_MS: float = 13.888
const QUEST_90_FPS_BUDGET_MS: float = 11.111
const MAX_VISIBLE_TRIS: int = 150000
const MAX_DRAW_CALLS: int = 120
const MAX_SHADOW_LIGHTS: int = 2
const MAX_TEXTURE_SIZE: int = 1024
const MAX_RAGDOLLS: int = 8
const MAX_SHELLS: int = 24
const MAX_DECALS: int = 128
const MAX_NODES: int = 200

const MapWorldBuilder = preload("res://core/maps/map_world_builder.gd")
const BuildingGenerator = preload("res://core/maps/building_generator.gd")
const VrPerformance = preload("res://core/vr/vr_performance.gd")
const WorldMaterialsScript = preload("res://core/maps/world_materials.gd")

static var _budget_results: Dictionary = {}

static func analyze_theme(theme_name: String, meta: Dictionary, parent: Node3D = null) -> Dictionary:
	var errors: Array = []
	var perf: VrPerformance = VrPerformance.new()
	perf.set_target_mode(VrPerformance.MODE_72)
	
	var root: Node3D
	if parent == null:
		root = Node3D.new()
		root.name = "PerfBudgetRoot"
	else:
		root = parent
	
	var start_time: float = Time.get_ticks_msec()
	var report: Dictionary = MapWorldBuilder.build(meta, root, perf)
	var build_time_ms: float = Time.get_ticks_msec() - start_time
	
	if not bool(report.get("ok", false)):
		errors.append("Map build failed: " + str(report.get("errors", [])))
		return _failure(theme_name, errors, build_time_ms)
	
	var node_count: int = int(report.get("node_count", 0))
	var obstacle_count: int = int(report.get("obstacle_count", 0))
	var props: Array = report.get("props", [])
	var spawn_points: Array = report.get("spawn_points", [])
	var bounds: AABB = report.get("bounds", AABB())
	
	var tri_estimate: int = _estimate_triangles(root)
	var draw_calls: int = _estimate_draw_calls(root)
	var unique_materials: int = _count_unique_materials(root)
	var unique_textures: int = _count_unique_textures(root)
	var texture_sizes: Array = _get_texture_sizes(root)
	var shadow_lights: int = _count_shadow_lights(root)
	var physics_bodies: int = _count_physics_bodies(root)
	var particle_systems: int = _count_particle_systems(root)
	var ragdolls: int = 0
	var shells: int = 0
	var decals: int = 0
	
	var budget_pass: bool = true
	var budget_failures: Array = []
	
	if node_count > MAX_NODES:
		budget_pass = false
		budget_failures.append("Nodes: %d > %d" % [node_count, MAX_NODES])
	
	if tri_estimate > MAX_VISIBLE_TRIS:
		budget_pass = false
		budget_failures.append("Triangles: %d > %d" % [tri_estimate, MAX_VISIBLE_TRIS])
	
	if draw_calls > MAX_DRAW_CALLS:
		budget_pass = false
		budget_failures.append("Draw calls: %d > %d" % [draw_calls, MAX_DRAW_CALLS])
	
	if shadow_lights > MAX_SHADOW_LIGHTS:
		budget_pass = false
		budget_failures.append("Shadow lights: %d > %d" % [shadow_lights, MAX_SHADOW_LIGHTS])
	
	for size in texture_sizes:
		if size > MAX_TEXTURE_SIZE:
			budget_pass = false
			budget_failures.append("Texture size: %d > %d" % [size, MAX_TEXTURE_SIZE])
	
	if ragdolls > MAX_RAGDOLLS:
		budget_pass = false
		budget_failures.append("Ragdolls: %d > %d" % [ragdolls, MAX_RAGDOLLS])
	
	if shells > MAX_SHELLS:
		budget_pass = false
		budget_failures.append("Shells: %d > %d" % [shells, MAX_SHELLS])
	
	if decals > MAX_DECALS:
		budget_pass = false
		budget_failures.append("Decals: %d > %d" % [decals, MAX_DECALS])
	
	if build_time_ms > 3000:
		budget_pass = false
		budget_failures.append("Build time: %.1fms > 3000ms" % build_time_ms)
	
	if parent == null and root.get_parent() != null:
		root.queue_free()
	
	var result: Dictionary = {
		"theme": theme_name,
		"build_time_ms": build_time_ms,
		"node_count": node_count,
		"obstacle_count": obstacle_count,
		"prop_count": props.size(),
		"spawn_count": spawn_points.size(),
		"bounds_size": Vector2(bounds.size.x, bounds.size.z),
		"tri_estimate": tri_estimate,
		"draw_calls": draw_calls,
		"unique_materials": unique_materials,
		"unique_textures": unique_textures,
		"texture_sizes": texture_sizes,
		"shadow_lights": shadow_lights,
		"physics_bodies": physics_bodies,
		"particle_systems": particle_systems,
		"ragdolls": ragdolls,
		"shells": shells,
		"decals": decals,
		"budget_pass": budget_pass,
		"budget_failures": budget_failures,
		"errors": errors,
	}
	
	_budget_results[theme_name] = result
	return result


static func analyze_all_themes() -> Dictionary:
	var themes: Dictionary = {
		"urbano": {
			"theme": "urbano",
			"scale": 1.0,
			"time_of_day": "atardecer",
			"seed": 42,
			"boundaries": {"min": Vector2(0, 0), "max": Vector2(20, 20)},
			"spawn_points": [Vector2(5, 5), Vector2(15, 15), Vector2(10, 10)],
			"obstacles": [Vector2(3, 3), Vector2(7, 7), Vector2(12, 8), Vector2(16, 12)],
			"grid": [
				"####################",
				"#..................#",
				"#..................#",
				"#....##...........#",
				"#....##...........#",
				"#..................#",
				"#..................#",
				"#........##........#",
				"#........##........#",
				"#..................#",
				"#..................#",
				"#........##........#",
				"#........##........#",
				"#..................#",
				"#..................#",
				"#..................#",
				"#..................#",
				"#..................#",
				"#..................#",
				"####################",
			],
		},
		"industrial": {
			"theme": "industrial",
			"scale": 1.0,
			"time_of_day": "dia",
			"seed": 123,
			"boundaries": {"min": Vector2(0, 0), "max": Vector2(24, 16)},
			"spawn_points": [Vector2(4, 4), Vector2(20, 12)],
			"obstacles": [Vector2(6, 3), Vector2(18, 8), Vector2(10, 12)],
			"grid": [],
		},
		"rural": {
			"theme": "rural",
			"scale": 1.0,
			"time_of_day": "noche",
			"seed": 456,
			"boundaries": {"min": Vector2(0, 0), "max": Vector2(30, 30)},
			"spawn_points": [Vector2(5, 5), Vector2(25, 25), Vector2(15, 10)],
			"obstacles": [Vector2(8, 8), Vector2(20, 20), Vector2(12, 15), Vector2(18, 5)],
			"grid": [],
		},
	}
	
	var results: Dictionary = {}
	for theme_name in themes:
		results[theme_name] = analyze_theme(theme_name, themes[theme_name])
	
	return results


static func analyze_building(building_spec: Dictionary, parent: Node3D = null) -> Dictionary:
	var errors: Array = []
	var perf: VrPerformance = VrPerformance.new()
	perf.set_target_mode(VrPerformance.MODE_72)
	
	var root: Node3D
	if parent == null:
		root = Node3D.new()
		root.name = "PerfBudgetBuildingRoot"
	else:
		root = parent
	
	var start_time: float = Time.get_ticks_msec()
	var result: Dictionary = BuildingGenerator.build(root, building_spec)
	var build_time_ms: float = Time.get_ticks_msec() - start_time
	
	if not bool(result.get("ok", false)):
		errors.append("Building build failed: " + str(result.get("errors", [])))
		return _failure("building", errors, build_time_ms)
	
	var node_count: int = int(result.get("node_count", 0))
	var visual_count: int = int(result.get("visual_count", 0))
	var collision_count: int = int(result.get("collision_count", 0))
	var doors: Array = result.get("doors", [])
	
	var tri_estimate: int = _estimate_triangles(root)
	var draw_calls: int = _estimate_draw_calls(root)
	var unique_materials: int = _count_unique_materials(root)
	
	var budget_pass: bool = true
	var budget_failures: Array = []
	
	if node_count > MAX_NODES:
		budget_pass = false
		budget_failures.append("Nodes: %d > %d" % [node_count, MAX_NODES])
	
	if tri_estimate > MAX_VISIBLE_TRIS:
		budget_pass = false
		budget_failures.append("Triangles: %d > %d" % [tri_estimate, MAX_VISIBLE_TRIS])
	
	if draw_calls > MAX_DRAW_CALLS:
		budget_pass = false
		budget_failures.append("Draw calls: %d > %d" % [draw_calls, MAX_DRAW_CALLS])
	
	if parent == null and root.get_parent() != null:
		root.queue_free()
	
	var budget_result: Dictionary = {
		"type": "building",
		"build_time_ms": build_time_ms,
		"node_count": node_count,
		"visual_count": visual_count,
		"collision_count": collision_count,
		"door_count": doors.size(),
		"tri_estimate": tri_estimate,
		"draw_calls": draw_calls,
		"unique_materials": unique_materials,
		"budget_pass": budget_pass,
		"budget_failures": budget_failures,
		"errors": errors,
	}
	
	_budget_results["building_%d" % building_spec.get("seed", 0)] = budget_result
	return budget_result


static func _estimate_triangles(node: Node) -> int:
	var total: int = 0
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			total += _mesh_triangle_count(mesh)
	elif node is MultiMeshInstance3D:
		var multimesh: MultiMesh = (node as MultiMeshInstance3D).multimesh
		if multimesh != null and multimesh.mesh != null:
			total += _mesh_triangle_count(multimesh.mesh) * multimesh.instance_count
	
	for child in node.get_children():
		total += _estimate_triangles(child)
	
	return total


static func _mesh_triangle_count(mesh: Mesh) -> int:
	if mesh is ArrayMesh:
		var count: int = 0
		for i in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(i)
			if arrays.size() > RenderingServer.ARRAY_INDEX:
				var indices: PackedInt32Array = arrays[RenderingServer.ARRAY_INDEX]
				if indices.size() > 0:
					count += indices.size() / 3
				else:
					var vertices: PackedVector3Array = arrays[RenderingServer.ARRAY_VERTEX]
					count += vertices.size() / 3
			else:
				var vertices: PackedVector3Array = arrays[RenderingServer.ARRAY_VERTEX]
				count += vertices.size() / 3
		return count
	elif mesh is PrimitiveMesh:
		return _primitive_triangle_count(mesh)
	return 0


static func _primitive_triangle_count(mesh: PrimitiveMesh) -> int:
	if mesh is BoxMesh:
		return 12
	elif mesh is SphereMesh:
		return int(mesh.rings * mesh.radial_segments * 2)
	elif mesh is CylinderMesh:
		return int(mesh.rings * mesh.radial_segments * 2 + mesh.radial_segments * 2)
	elif mesh is CapsuleMesh:
		return int(mesh.rings * mesh.radial_segments * 4 + mesh.radial_segments * 4)
	elif mesh is PlaneMesh:
		return int(mesh.subdivide_depth * mesh.subdivide_width * 2)
	elif mesh is QuadMesh:
		return 2
	return 0


static func _estimate_draw_calls(node: Node) -> int:
	var total: int = 0
	if node is MeshInstance3D:
		total += 1
	elif node is MultiMeshInstance3D:
		total += 1
	
	for child in node.get_children():
		total += _estimate_draw_calls(child)
	
	return total


static func _count_unique_materials(node: Node) -> int:
	var materials: Array = []
	_collect_materials(node, materials)
	var unique: Array = []
	for m in materials:
		if not unique.has(m):
			unique.append(m)
	return unique.size()


static func _collect_materials(node: Node, materials: Array) -> void:
	if node is MeshInstance3D:
		var mat: Material = (node as MeshInstance3D).material_override
		if mat != null:
			materials.append(mat)
	elif node is MultiMeshInstance3D:
		var mat: Material = (node as MultiMeshInstance3D).material_override
		if mat != null:
			materials.append(mat)
	
	for child in node.get_children():
		_collect_materials(child, materials)


static func _count_unique_textures(node: Node) -> int:
	var textures: Array = []
	_collect_textures(node, textures)
	var unique: Array = []
	for t in textures:
		if not unique.has(t):
			unique.append(t)
	return unique.size()


static func _collect_textures(node: Node, textures: Array) -> void:
	if node is MeshInstance3D:
		var mat: Material = (node as MeshInstance3D).material_override
		if mat is StandardMaterial3D:
			_add_material_textures(mat as StandardMaterial3D, textures)
	elif node is MultiMeshInstance3D:
		var mat: Material = (node as MultiMeshInstance3D).material_override
		if mat is StandardMaterial3D:
			_add_material_textures(mat as StandardMaterial3D, textures)
	
	for child in node.get_children():
		_collect_textures(child, textures)


static func _add_material_textures(mat: StandardMaterial3D, textures: Array) -> void:
	var texture_props = [
		"albedo_texture", "orm_texture", "normal_texture", "emission_texture",
		"clearcoat_texture", "flowmap_texture", "heightmap_texture",
		"subsurface_scattering_texture", "refraction_texture"
	]
	for prop in texture_props:
		if mat.has_method("get_" + prop):
			var tex: Texture = mat.get(prop)
			if tex != null and not textures.has(tex):
				textures.append(tex)


static func _get_texture_sizes(node: Node) -> Array:
	var sizes: Array = []
	_collect_texture_sizes(node, sizes)
	return sizes


static func _collect_texture_sizes(node: Node, sizes: Array) -> void:
	if node is MeshInstance3D:
		var mat: Material = (node as MeshInstance3D).material_override
		if mat is StandardMaterial3D:
			_add_material_texture_sizes(mat as StandardMaterial3D, sizes)
	elif node is MultiMeshInstance3D:
		var mat: Material = (node as MultiMeshInstance3D).material_override
		if mat is StandardMaterial3D:
			_add_material_texture_sizes(mat as StandardMaterial3D, sizes)
	
	for child in node.get_children():
		_collect_texture_sizes(child, sizes)


static func _add_material_texture_sizes(mat: StandardMaterial3D, sizes: Array) -> void:
	var texture_props = [
		"albedo_texture", "orm_texture", "normal_texture", "emission_texture",
		"clearcoat_texture", "flowmap_texture", "heightmap_texture",
		"subsurface_scattering_texture", "refraction_texture"
	]
	for prop in texture_props:
		if mat.has_method("get_" + prop):
			var tex: Texture = mat.get(prop)
			if tex != null:
				var width: int = tex.get_width()
				var height: int = tex.get_height()
				sizes.append(maxi(width, height))


static func _count_shadow_lights(node: Node) -> int:
	var count: int = 0
	if node is Light3D:
		if (node as Light3D).shadow_enabled:
			count += 1
	
	for child in node.get_children():
		count += _count_shadow_lights(child)
	
	return count


static func _count_physics_bodies(node: Node) -> int:
	var count: int = 0
	if node is PhysicsBody3D:
		count += 1
	
	for child in node.get_children():
		count += _count_physics_bodies(child)
	
	return count


static func _count_particle_systems(node: Node) -> int:
	var count: int = 0
	if node is GPUParticles3D or node is CPUParticles3D:
		count += 1
	
	for child in node.get_children():
		count += _count_particle_systems(child)
	
	return count


static func _failure(name: String, errors: Array, build_time: float) -> Dictionary:
	return {
		"theme": name,
		"build_time_ms": build_time,
		"node_count": 0,
		"obstacle_count": 0,
		"prop_count": 0,
		"spawn_count": 0,
		"bounds_size": Vector2.ZERO,
		"tri_estimate": 0,
		"draw_calls": 0,
		"unique_materials": 0,
		"unique_textures": 0,
		"texture_sizes": [],
		"shadow_lights": 0,
		"physics_bodies": 0,
		"particle_systems": 0,
		"ragdolls": 0,
		"shells": 0,
		"decals": 0,
		"budget_pass": false,
		"budget_failures": errors,
		"errors": errors,
	}


static func print_budget_report(results: Dictionary) -> void:
	print("=== PERFORMANCE BUDGET REPORT ===")
	print("Quest 72 FPS Budget: %.3fms" % QUEST_72_FPS_BUDGET_MS)
	print("Quest 90 FPS Budget: %.3fms" % QUEST_90_FPS_BUDGET_MS)
	print("Max Visible Tris: %d" % MAX_VISIBLE_TRIS)
	print("Max Draw Calls: %d" % MAX_DRAW_CALLS)
	print("Max Shadow Lights: %d" % MAX_SHADOW_LIGHTS)
	print("Max Texture Size: %d" % MAX_TEXTURE_SIZE)
	print("Max Nodes: %d" % MAX_NODES)
	print("")
	
	for theme_name in results:
		var result: Dictionary = results[theme_name]
		print("--- %s ---" % theme_name)
		print("  Build Time: %.1fms" % result.build_time_ms)
		print("  Nodes: %d / %d" % [result.node_count, MAX_NODES])
		print("  Obstacles: %d" % result.obstacle_count)
		print("  Props: %d" % result.prop_count)
		print("  Spawns: %d" % result.spawn_count)
		print("  Bounds: %.1fx%.1f" % [result.bounds_size.x, result.bounds_size.y])
		print("  Tri Estimate: %d / %d" % [result.tri_estimate, MAX_VISIBLE_TRIS])
		print("  Draw Calls: %d / %d" % [result.draw_calls, MAX_DRAW_CALLS])
		print("  Unique Materials: %d" % result.unique_materials)
		print("  Unique Textures: %d" % result.unique_textures)
		print("  Texture Sizes: %s" % str(result.texture_sizes))
		print("  Shadow Lights: %d / %d" % [result.shadow_lights, MAX_SHADOW_LIGHTS])
		print("  Physics Bodies: %d" % result.physics_bodies)
		print("  Particle Systems: %d" % result.particle_systems)
		print("  BUDGET PASS: %s" % ("YES" if result.budget_pass else "NO"))
		if not result.budget_pass:
			for failure in result.budget_failures:
				print("    FAIL: %s" % failure)
		print("")


static func check_budget_compliance(results: Dictionary) -> bool:
	for theme_name in results:
		if not bool(results[theme_name].get("budget_pass", false)):
			return false
	return true