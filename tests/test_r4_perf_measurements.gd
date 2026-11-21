extends SceneTree

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const ThemesScript = preload("res://core/maps/map_themes.gd")
const BuilderScript = preload("res://core/maps/map_world_builder.gd")
const BuildingScript = preload("res://core/maps/building_generator.gd")
const VrPerformanceScript = preload("res://core/vr/vr_performance.gd")

var _checks = 0
var _failures = []
var _case = ""
var _measurements = {}

func _initialize():
	await process_frame
	_measure_map_build_performance()
	_measure_building_generation()
	_measure_vr_performance_profiles()
	_measure_draw_calls_and_instances()
	_measure_memory_usage()
	
	print("=== R4_PERF MEASUREMENTS SUMMARY ===")
	for key in _measurements.keys():
		print("%s: %s" % [key, _measurements[key]])
	
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _measure_map_build_performance() -> void:
	var seed := 12345
	var base_params: Dictionary = {
		"time_of_day": "noche",
		"theme_density": 0.55,
		"width": 24,
		"height": 18,
		"obstacle_density": 0.12,
		"spawn_count": 4,
	}
	
	# Urbano
	_case = "medicion build mapa urbano"
	var params_urbano: Dictionary = base_params.duplicate()
	params_urbano["theme"] = "urbano"
	var meta_urbano: Dictionary = ThemesScript.generate(seed, params_urbano)
	_expect(bool(meta_urbano.get("ok", false)), "meta generada OK")
	
	var root_urbano := Node3D.new()
	root_urbano.name = "PerfTestRoot"
	self.root.add_child(root_urbano)
	
	var start_time := Time.get_ticks_msec()
	var report_urbano: Dictionary = BuilderScript.build(meta_urbano, root_urbano)
	var build_time_urbano := Time.get_ticks_msec() - start_time
	
	_expect(bool(report_urbano.get("ok", false)), "build OK")
	_expect(int(report_urbano.get("node_count", 9999)) <= BuilderScript.MAX_NODES, "nodos dentro del presupuesto: %d" % int(report_urbano.get("node_count", 9999)))
	
	_measurements["map_build_urbano_ms"] = build_time_urbano
	_measurements["map_build_urbano_nodes"] = int(report_urbano.get("node_count", 0))
	_measurements["map_build_urbano_obstacles"] = int(report_urbano.get("obstacle_count", 0))
	_measurements["map_build_urbano_props"] = (report_urbano.get("props", []) as Array).size()
	
	print("TIEMPO_BUILD_URBANO_MS: %d" % build_time_urbano)
	print("NODE_COUNT_URBANO: %d" % int(report_urbano.get("node_count", 0)))
	print("OBSTACLE_COUNT_URBANO: %d" % int(report_urbano.get("obstacle_count", 0)))
	print("PROP_COUNT_URBANO: %d" % (report_urbano.get("props", []) as Array).size())
	
	_expect(build_time_urbano < 3000, "tiempo de build urbano < 3000ms (actual: %dms)" % build_time_urbano)
	
	root_urbano.queue_free()
	
	# Industrial
	_case = "medicion build mapa industrial"
	var params_industrial: Dictionary = base_params.duplicate()
	params_industrial["theme"] = "industrial"
	var meta_industrial: Dictionary = ThemesScript.generate(seed + 1, params_industrial)
	_expect(bool(meta_industrial.get("ok", false)), "meta industrial generada OK")
	
	var root_industrial := Node3D.new()
	root_industrial.name = "PerfTestRoot2"
	self.root.add_child(root_industrial)
	
	start_time = Time.get_ticks_msec()
	var report_industrial: Dictionary = BuilderScript.build(meta_industrial, root_industrial)
	var build_time_industrial := Time.get_ticks_msec() - start_time
	
	_expect(bool(report_industrial.get("ok", false)), "build industrial OK")
	
	_measurements["map_build_industrial_ms"] = build_time_industrial
	_measurements["map_build_industrial_nodes"] = int(report_industrial.get("node_count", 0))
	
	print("TIEMPO_BUILD_INDUSTRIAL_MS: %d" % build_time_industrial)
	print("NODE_COUNT_INDUSTRIAL: %d" % int(report_industrial.get("node_count", 0)))
	
	_expect(build_time_industrial < 3000, "tiempo de build industrial < 3000ms (actual: %dms)" % build_time_industrial)
	
	root_industrial.queue_free()
	
	# Rural
	_case = "medicion build mapa rural"
	var params_rural: Dictionary = base_params.duplicate()
	params_rural["theme"] = "rural"
	var meta_rural: Dictionary = ThemesScript.generate(seed + 2, params_rural)
	_expect(bool(meta_rural.get("ok", false)), "meta rural generada OK")
	
	var root_rural := Node3D.new()
	root_rural.name = "PerfTestRoot3"
	self.root.add_child(root_rural)
	
	start_time = Time.get_ticks_msec()
	var report_rural: Dictionary = BuilderScript.build(meta_rural, root_rural)
	var build_time_rural := Time.get_ticks_msec() - start_time
	
	_expect(bool(report_rural.get("ok", false)), "build rural OK")
	
	_measurements["map_build_rural_ms"] = build_time_rural
	_measurements["map_build_rural_nodes"] = int(report_rural.get("node_count", 0))
	
	print("TIEMPO_BUILD_RURAL_MS: %d" % build_time_rural)
	print("NODE_COUNT_RURAL: %d" % int(report_rural.get("node_count", 0)))
	
	_expect(build_time_rural < 3000, "tiempo de build rural < 3000ms (actual: %dms)" % build_time_rural)
	
	root_rural.queue_free()
	await process_frame

func _measure_building_generation() -> void:
	_case = "medicion generacion edificio"
	var seed := 999
	var params: Dictionary = {
		"cell": Vector2i(5, 5),
		"width": 6,
		"depth": 6,
		"floors": 2,
		"style": "brick",
	}
	
	var start_time := Time.get_ticks_msec()
	var spec: Dictionary = BuildingScript.generate(seed, params)
	var gen_time := Time.get_ticks_msec() - start_time
	
	_expect(bool(spec.get("ok", false)), "edificio generado OK")
	
	var root := Node3D.new()
	root.name = "BuildingPerfRoot"
	self.root.add_child(root)
	
	start_time = Time.get_ticks_msec()
	var build_report: Dictionary = BuildingScript.build(root, spec)
	var build_time := Time.get_ticks_msec() - start_time
	
	_expect(bool(build_report.get("ok", false)), "edificio construido OK")
	
	_measurements["building_gen_ms"] = gen_time
	_measurements["building_build_ms"] = build_time
	_measurements["building_node_count"] = int(build_report.get("node_count", 0))
	_measurements["building_visual_count"] = int(build_report.get("visual_count", 0))
	_measurements["building_collision_count"] = int(build_report.get("collision_count", 0))
	
	print("BUILDING_GEN_MS: %d" % gen_time)
	print("BUILDING_BUILD_MS: %d" % build_time)
	print("BUILDING_NODE_COUNT: %d" % int(build_report.get("node_count", 0)))
	print("BUILDING_VISUAL_COUNT: %d" % int(build_report.get("visual_count", 0)))
	
	root.queue_free()
	await process_frame

func _measure_vr_performance_profiles() -> void:
	_case = "perfiles de rendimiento VR"
	
	var perf72 = VrPerformanceScript.new("quest_72")
	perf72.build()
	var profile72 = perf72.current_profile()
	
	_expect(profile72["mode"] == "quest_72", "modo quest_72")
	_expect(is_equal_approx(profile72["refresh_hz"], 72.0), "72 Hz refresh")
	_expect(is_equal_approx(profile72["frame_budget_ms"], 13.888), "frame budget 13.888ms: %s" % profile72["frame_budget_ms"])
	
	_measurements["vr_72hz_budget_ms"] = 13.888
	_measurements["vr_72hz_npcs"] = profile72["npcs"]
	_measurements["vr_72hz_particles"] = profile72["particles"]
	_measurements["vr_72hz_decals"] = profile72["decals"]
	_measurements["vr_72hz_shadow_distance"] = profile72["shadow_distance"]
	_measurements["vr_72hz_render_scale"] = profile72["render_scale"]
	
	print("VR_72HZ_BUDGET_MS: 13.888")
	print("VR_72HZ_NPCS: %d" % profile72["npcs"])
	print("VR_72HZ_PARTICLES: %d" % profile72["particles"])
	print("VR_72HZ_DECALS: %d" % profile72["decals"])
	print("VR_72HZ_SHADOW_DISTANCE: %f" % profile72["shadow_distance"])
	print("VR_72HZ_RENDER_SCALE: %f" % profile72["render_scale"])
	
	var perf90 = VrPerformanceScript.new("quest_90")
	perf90.build()
	var profile90 = perf90.current_profile()
	
	_measurements["vr_90hz_budget_ms"] = 11.111
	_measurements["vr_90hz_npcs"] = profile90["npcs"]
	_measurements["vr_90hz_particles"] = profile90["particles"]
	_measurements["vr_90hz_decals"] = profile90["decals"]
	
	_expect(is_equal_approx(profile90["frame_budget_ms"], 11.111), "frame budget 11.111ms: %s" % profile90["frame_budget_ms"])
	
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	
	for i in range(10):
		perf.observe_frame(20.0)
	
	var p1 = perf.current_profile()
	_measurements["vr_degrade_1_render_scale"] = p1["render_scale"]
	_measurements["vr_degrade_1_shadow_distance"] = p1["shadow_distance"]
	_measurements["vr_degrade_1_particles"] = p1["particles"]
	_measurements["vr_degrade_1_npcs"] = p1["npcs"]
	
	for i in range(10):
		perf.observe_frame(20.0)
	
	var p2 = perf.current_profile()
	_measurements["vr_degrade_2_render_scale"] = p2["render_scale"]
	_measurements["vr_degrade_2_shadow_distance"] = p2["shadow_distance"]
	_measurements["vr_degrade_2_particles"] = p2["particles"]
	_measurements["vr_degrade_2_npcs"] = p2["npcs"]
	
	for i in range(20):
		perf.observe_frame(50.0)
	
	var p_max = perf.current_profile()
	_measurements["vr_max_degrade_level"] = p_max["degrade_level"]
	_measurements["vr_max_degrade_render_scale"] = p_max["render_scale"]
	_measurements["vr_max_degrade_shadow_distance"] = p_max["shadow_distance"]
	_measurements["vr_max_degrade_particles"] = p_max["particles"]
	_measurements["vr_max_degrade_npcs"] = p_max["npcs"]
	
	print("VR_DEGRADE_1: render_scale=%.3f shadow=%.1f particles=%d npcs=%d" % [p1["render_scale"], p1["shadow_distance"], p1["particles"], p1["npcs"]])
	print("VR_DEGRADE_2: render_scale=%.3f shadow=%.1f particles=%d npcs=%d" % [p2["render_scale"], p2["shadow_distance"], p2["particles"], p2["npcs"]])
	print("VR_MAX_DEGRADE: level=%d render_scale=%.3f shadow=%.1f particles=%d npcs=%d" % [p_max["degrade_level"], p_max["render_scale"], p_max["shadow_distance"], p_max["particles"], p_max["npcs"]])

func _measure_draw_calls_and_instances() -> void:
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
	
	root.queue_free()
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

func _measure_memory_usage() -> void:
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

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])

func is_equal_approx(a: float, b: float) -> bool:
	return absf(a - b) <= 0.001