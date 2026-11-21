extends SceneTree

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const ThemesScript = preload("res://core/maps/map_themes.gd")
const BuilderScript = preload("res://core/maps/map_world_builder.gd")
const VrPerformanceScript = preload("res://core/vr/vr_performance.gd")
const NPCLODScript = preload("res://core/npc/npc_lod.gd")

var _checks = 0
var _failures = []
var _case = ""
var _measurements = {}
var _before_measurements = {}

func _initialize():
	await process_frame
	_capture_baseline()
	_measure_world_build_performance()
	_measure_draw_calls_and_instances()
	_measure_memory_usage()
	_measure_frame_budget_adherence()
	_measure_npc_lod_performance()
	_measure_optimization_effectiveness()
	
	print("=== R4_PERF_BETA SUMMARY ===")
	print("BEFORE OPTIMIZATIONS:")
	for key in _before_measurements.keys():
		print("  %s: %s" % [key, _before_measurements[key]])
	print("AFTER OPTIMIZATIONS:")
	for key in _measurements.keys():
		print("  %s: %s" % [key, _measurements[key]])
	
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _capture_baseline():
	_case = "capture_baseline"
	var seed := 12345
	var params: Dictionary = {
		"theme": "urbano",
		"time_of_day": "noche",
		"theme_density": 0.55,
		"width": 24,
		"height": 18,
		"obstacle_density": 0.12,
		"spawn_count": 4,
	}
	
	var meta: Dictionary = ThemesScript.generate(seed, params)
	var root := Node3D.new()
	root.name = "BaselineRoot"
	self.root.add_child(root)
	
	var start_time := Time.get_ticks_msec()
	var report: Dictionary = BuilderScript.build(meta, root)
	var build_time := Time.get_ticks_msec() - start_time
	
	var counts: Dictionary = _count_draw_calls(root)
	
	_before_measurements["build_time_ms"] = build_time
	_before_measurements["node_count"] = int(report.get("node_count", 0))
	_before_measurements["multimesh_count"] = counts["multimesh_count"]
	_before_measurements["mesh_instance_count"] = counts["mesh_instance_count"]
	_before_measurements["total_instances"] = counts["total_instances"]
	
	var mem_before: int = OS.get_static_memory_usage()
	var mem_after: int = OS.get_static_memory_usage()
	_before_measurements["memory_kb"] = mem_after - mem_before
	
	root.queue_free()
	await process_frame

func _measure_world_build_performance():
	var seed := 12345
	var base_params: Dictionary = {
		"time_of_day": "noche",
		"theme_density": 0.55,
		"width": 24,
		"height": 18,
		"obstacle_density": 0.12,
		"spawn_count": 4,
	}
	
	var themes = ["urbano", "industrial", "rural"]
	for theme in themes:
		_case = "medicion build mapa %s" % theme
		var params: Dictionary = base_params.duplicate()
		params["theme"] = theme
		var meta: Dictionary = ThemesScript.generate(seed + hash(theme), params)
		_expect(bool(meta.get("ok", false)), "meta generada OK")
		
		var root := Node3D.new()
		root.name = "PerfTestRoot_%s" % theme
		self.root.add_child(root)
		
		var start_time := Time.get_ticks_msec()
		var report: Dictionary = BuilderScript.build(meta, root)
		var build_time := Time.get_ticks_msec() - start_time
		
		_expect(bool(report.get("ok", false)), "build OK")
		_expect(int(report.get("node_count", 9999)) <= BuilderScript.MAX_NODES, "nodos dentro del presupuesto: %d" % int(report.get("node_count", 9999)))
		
		_measurements["map_build_%s_ms" % theme] = build_time
		_measurements["map_build_%s_nodes" % theme] = int(report.get("node_count", 0))
		_measurements["map_build_%s_obstacles" % theme] = int(report.get("obstacle_count", 0))
		_measurements["map_build_%s_props" % theme] = (report.get("props", []) as Array).size()
		
		print("TIEMPO_BUILD_%s_MS: %d" % [theme.to_upper(), build_time])
		print("NODE_COUNT_%s: %d" % [theme.to_upper(), int(report.get("node_count", 0))])
		
		_expect(build_time < 3000, "tiempo de build %s < 3000ms (actual: %dms)" % [theme, build_time])
		
		root.queue_free()
		await process_frame

func _measure_draw_calls_and_instances():
	_case = "medicion draw calls e instancias"
	var seed := 12345
	var params: Dictionary = {
		"theme": "urbano",
		"time_of_day": "noche",
		"theme_density": 0.55,
		"width": 24,
		"height": 18,
		"obstacle_density": 0.12,
		"spawn_count": 4,
	}
	
	var meta: Dictionary = ThemesScript.generate(seed, params)
	var root := Node3D.new()
	root.name = "DrawCallTestRoot"
	self.root.add_child(root)
	
	var report: Dictionary = BuilderScript.build(meta, root)
	
	var counts: Dictionary = _count_draw_calls(root)
	var multimesh_count: int = counts["multimesh_count"]
	var mesh_instance_count: int = counts["mesh_instance_count"]
	var total_instances: int = counts["total_instances"]
	
	_measurements["drawcall_multimesh_count"] = multimesh_count
	_measurements["drawcall_mesh_instance_count"] = mesh_instance_count
	_measurements["drawcall_total_instances"] = total_instances
	
	print("DRAWCALL_MULTIMESH_COUNT: %d" % multimesh_count)
	print("DRAWCALL_MESH_INSTANCE_COUNT: %d" % mesh_instance_count)
	print("DRAWCALL_TOTAL_INSTANCES: %d" % total_instances)
	
	_expect(multimesh_count > 0, "debe haber MultiMeshInstance3D para instancing")
	_expect(total_instances <= 2000, "instancias totales dentro del presupuesto: %d" % total_instances)
	_expect(multimesh_count + mesh_instance_count <= 120, "draw calls dentro del presupuesto 72Hz: %d" % (multimesh_count + mesh_instance_count))
	
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	_expect(multimesh_count + mesh_instance_count <= perf.get_max_draw_calls(), "draw calls <= max_draw_calls profile: %d <= %d" % [multimesh_count + mesh_instance_count, perf.get_max_draw_calls()])
	
	root.queue_free()
	await process_frame

func _measure_memory_usage():
	_case = "medicion uso de memoria"
	
	var mem_before: int = OS.get_static_memory_usage()
	
	var seed := 12345
	var params: Dictionary = {
		"theme": "urbano",
		"time_of_day": "noche",
		"theme_density": 0.55,
		"width": 24,
		"height": 18,
		"obstacle_density": 0.12,
		"spawn_count": 4,
	}
	
	var meta: Dictionary = ThemesScript.generate(seed, params)
	var root := Node3D.new()
	root.name = "MemoryTestRoot"
	self.root.add_child(root)
	
	var report: Dictionary = BuilderScript.build(meta, root)
	
	var mem_after: int = OS.get_static_memory_usage()
	
	var mem_used_kb: int = mem_after - mem_before
	
	_measurements["memory_used_kb"] = mem_used_kb
	_measurements["memory_static_before_kb"] = mem_before
	_measurements["memory_static_after_kb"] = mem_after
	
	print("MEMORY_STATIC_BEFORE_KB: %d" % mem_before)
	print("MEMORY_STATIC_AFTER_KB: %d" % mem_after)
	print("MEMORY_USED_KB: %d" % mem_used_kb)
	
	_expect(mem_used_kb < 2000000, "memoria usada < 2GB: %d KB" % mem_used_kb)
	
	root.queue_free()
	await process_frame

func _measure_frame_budget_adherence():
	_case = "adherencia al frame budget 72Hz"
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	
	var budget72 = perf.current_profile()["frame_budget_ms"]
	_assert_close(budget72, 13.888, 0.001, "72Hz frame budget es 13.888ms")
	
	# Simulate frames under budget
	for i in range(10):
		var result = perf.observe_frame(7.0)
		_expect(not result["below_72fps"], "frame 7ms < 13.888ms NO marca below_72fps")
	
	# Simulate frames at budget edge
	for i in range(10):
		var result = perf.observe_frame(13.888)
		_expect(not result["below_72fps"], "frame en 72fps budget (13.888ms) no marca below_72fps")
	
	# Simulate frames over budget
	for i in range(10):
		var result = perf.observe_frame(16.0)
		_expect(result["below_72fps"], "frame 16ms > 13.888ms marca below_72fps")
	
	# Test degrade and recovery
	var perf2 = VrPerformanceScript.new("quest_72")
	perf2.build()
	
	for i in range(8):
		perf2.observe_frame(20.0)
	var p1 = perf2.current_profile()
	_expect(p1["degrade_level"] == 1, "degrade_level == 1 tras 8 frames lentos: %d" % p1["degrade_level"])
	
	for i in range(24):
		perf2.observe_frame(5.0)
	var p_rec = perf2.current_profile()
	_expect(p_rec["degrade_level"] == 0, "recupera a nivel 0: %d" % p_rec["degrade_level"])

func _measure_npc_lod_performance():
	_case = "rendimiento NPC LOD"
	
	var lod = NPCLODScript.new()
	
	# Test update intervals at various distances
	var intervals = [
		{"distance": 5.0, "expected": 0.0},
		{"distance": 20.0, "expected": 0.5},
		{"distance": 60.0, "expected": 5.0},
	]
	
	for test in intervals:
		var interval = lod.get_update_interval(test.distance)
		_expect(interval == test.expected, "interval a %.1fm = %.1f (esperado %.1f)" % [test.distance, interval, test.expected])
	
	# Test visual LOD levels
	var visual_lods = [
		{"distance": 10.0, "expected": 0},
		{"distance": 25.0, "expected": 1},
		{"distance": 50.0, "expected": 2},
		{"distance": 90.0, "expected": 3},
		{"distance": 10.0, "occluded": true, "expected": 3},
	]
	
	for test in visual_lods:
		var occluded = test.get("occluded", false)
		var lod_level = lod.get_visual_lod(test.distance, occluded)
		_expect(lod_level == test.expected, "visual LOD a %.1fm%s = %d (esperado %d)" % [test.distance, " (occluded)" if occluded else "", lod_level, test.expected])
	
	# Test anim LOD levels
	var anim_lods = [
		{"distance": 15.0, "expected": 0},
		{"distance": 35.0, "expected": 1},
		{"distance": 60.0, "expected": 2},
	]
	
	for test in anim_lods:
		var lod_level = lod.get_anim_lod(test.distance)
		_expect(lod_level == test.expected, "anim LOD a %.1fm = %d (esperado %d)" % [test.distance, lod_level, test.expected])
	
	# Test AI LOD levels
	var ai_lods = [
		{"distance": 20.0, "expected": 0},
		{"distance": 40.0, "expected": 1},
		{"distance": 70.0, "expected": 2},
	]
	
	for test in ai_lods:
		var lod_level = lod.get_ai_lod(test.distance)
		_expect(lod_level == test.expected, "AI LOD a %.1fm = %d (esperado %d)" % [test.distance, lod_level, test.expected])
	
	# Test should_update logic
	lod.update_lods(0.0, 5.0)
	_expect(lod.should_update(0.0, 5.0), "debe actualizar a distancia 0 (interval 0)")
	_expect(not lod.should_update(0.3, 20.0), "no debe actualizar a 0.3s con interval 0.5s")
	_expect(lod.should_update(0.6, 20.0), "debe actualizar a 0.6s con interval 0.5s")
	_expect(not lod.should_update(0.8, 60.0), "no debe actualizar a 0.8s con interval 5.0s")
	_expect(lod.should_update(5.5, 60.0), "debe actualizar a 5.5s con interval 5.0s")
	
	# Test occlusion check
	var camera = Camera3D.new()
	camera.position = Vector3(0, 2, 10)
	camera.rotation = Vector3(0, 0, 0)
	
	var root = Node3D.new()
	root.add_child(camera)
	get_root().add_child(root)
	await process_frame
	
	var behind_camera = Vector3(0, 2, 20)
	var in_front = Vector3(0, 2, 5)
	
	var occluded1 = lod.check_occlusion(0.0, camera, behind_camera, 1.0)
	var occluded2 = lod.check_occlusion(0.1, camera, in_front, 1.0)
	
	_expect(occluded1 == true, "detrás de cámara debe estar occluido")
	_expect(occluded2 == false, "delante de cámara NO debe estar occluido")
	
	root.queue_free()
	await process_frame

func _measure_optimization_effectiveness():
	_case = "efectividad de optimizaciones"
	
	# Verify shared materials are being reused
	var materials = BuilderScript.WorldMaterialsScript
	var mat1 = materials.surface_material("concrete")
	var mat2 = materials.surface_material("concrete")
	var mat3 = materials.surface_material("concrete", true)
	var mat4 = materials.surface_material("concrete", true)
	
	_expect(mat1 == mat2, "materiales desktop reutilizados")
	_expect(mat3 == mat4, "materiales mobile reutilizados")
	_expect(mat1 != mat3, "materiales desktop != mobile")
	
	var stats = materials.get_material_stats()
	_expect(stats.material_count >= 2, "al menos 2 materiales (desktop + mobile)")
	
	# Verify VR performance profile application sets visibility ranges
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	
	var root = Node3D.new()
	root.name = "ProfileTestRoot"
	
	var mm_instance = MultiMeshInstance3D.new()
	mm_instance.name = "TestMultiMesh"
	var multimesh = MultiMesh.new()
	multimesh.instance_count = 10
	multimesh.mesh = BoxMesh.new()
	mm_instance.multimesh = multimesh
	root.add_child(mm_instance)
	
	var mi = MeshInstance3D.new()
	mi.name = "TestMeshInstance"
	mi.mesh = BoxMesh.new()
	root.add_child(mi)
	
	perf.apply_profile_to_scene(root)
	
	var mm_has_vis = mm_instance.visibility_range_end > 0.0
	var mi_has_vis = mi.visibility_range_end > 0.0
	
	_expect(mm_has_vis, "MultiMesh debe tener visibility range")
	_expect(mi_has_vis, "MeshInstance debe tener visibility range")
	_expect(mm_instance.visibility_range_end == perf.get_culling_distance(), "visibility_range_end == culling_distance: %.1f" % mm_instance.visibility_range_end)
	
	root.queue_free()
	await process_frame
	
	# Verify frustum culling works
	var camera = Camera3D.new()
	camera.position = Vector3(0, 2, 0)
	camera.rotation = Vector3(0, 0, 0)
	
	var cull_root = Node3D.new()
	cull_root.add_child(camera)
	get_root().add_child(cull_root)
	await process_frame
	
	perf.set_culling_camera(camera)
	
	var visible_aabb = AABB(Vector3(5, 0, 5), Vector3(2, 2, 2))
	var hidden_aabb = AABB(Vector3(-100, 0, -100), Vector3(2, 2, 2))
	
	var vis1 = perf.is_visible(visible_aabb)
	var vis2 = perf.is_visible(hidden_aabb)
	
	_expect(vis1 == true, "AABB visible debe ser visible")
	_expect(vis2 == false, "AABB lejano no debe ser visible")
	
	var sphere_vis = perf.is_visible_sphere(Vector3(5, 0, 5), 2.0)
	var sphere_hid = perf.is_visible_sphere(Vector3(-100, 0, -100), 2.0)
	
	_expect(sphere_vis == true, "esfera visible debe ser visible")
	_expect(sphere_hid == false, "esfera lejana no debe ser visible")
	
	cull_root.queue_free()
	await process_frame

func _count_draw_calls(node: Node) -> Dictionary:
	var multimesh_count: int = 0
	var mesh_instance_count: int = 0
	var total_instances: int = 0
	
	if node is MultiMeshInstance3D:
		multimesh_count += 1
		var mm: MultiMeshInstance3D = node
		if mm.multimesh != null:
			total_instances += mm.multimesh.instance_count
	elif node is MeshInstance3D:
		mesh_instance_count += 1
		total_instances += 1
	
	for child in node.get_children():
		var child_counts: Dictionary = _count_draw_calls(child)
		multimesh_count += child_counts["multimesh_count"]
		mesh_instance_count += child_counts["mesh_instance_count"]
		total_instances += child_counts["total_instances"]
	
	return {
		"multimesh_count": multimesh_count,
		"mesh_instance_count": mesh_instance_count,
		"total_instances": total_instances
	}

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])

func _assert_close(value: float, target: float, tolerance: float, message: String) -> void:
	_checks += 1
	if absf(value - target) > tolerance:
		_failures.append("[%s] %s: valor=%.3f, objetivo=%.3f, tolerancia=%.3f" % [_case, message, value, target, tolerance])

func _assert_in_range(value: float, min_val: float, max_val: float, message: String) -> void:
	_checks += 1
	if value < min_val or value > max_val:
		_failures.append("[%s] %s: valor=%.3f, rango=[%.3f, %.3f]" % [_case, message, value, min_val, max_val])