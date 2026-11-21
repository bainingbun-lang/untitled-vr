extends SceneTree

var _world_materials = preload("res://core/maps/world_materials.gd")
var _vr_performance = preload("res://core/vr/vr_performance.gd")

var _checks: int = 0
var _failures: Array = []

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func test_shared_materials() -> void:
	var mat1 := _world_materials.surface_material("concrete")
	var mat2 := _world_materials.surface_material("concrete")
	var mat3 := _world_materials.surface_material("concrete", true)
	var mat4 := _world_materials.surface_material("concrete", true)
	
	var same_ref := mat1 == mat2
	var mobile_same_ref := mat3 == mat4
	var different_from_desktop := mat1 != mat3
	
	print("Desktop material reuse: %s, Mobile material reuse: %s, Desktop != Mobile: %s" % [same_ref, mobile_same_ref, different_from_desktop])
	
	var stats := _world_materials.get_material_stats()
	print("Material stats: %s" % stats)
	
	_expect(same_ref, "Desktop materials should be same reference")
	_expect(mobile_same_ref, "Mobile materials should be same reference")
	_expect(different_from_desktop, "Desktop and mobile materials should be different")
	_expect(stats.material_count >= 2, "Should have at least 2 materials (desktop + mobile)")

func test_vr_performance_profiles() -> void:
	var perf: VrPerformance = _vr_performance.new("quest_72")
	perf.build()
	
	var cull_dist := perf.get_culling_distance()
	var lod_bias := perf.get_lod_bias()
	var max_draw := perf.get_max_draw_calls()
	var max_tri := perf.get_max_triangles()
	
	print("Quest 72: cull=%.1f, lod_bias=%.1f, max_draw=%d, max_tri=%d" % [cull_dist, lod_bias, max_draw, max_tri])
	
	var perf90: VrPerformance = _vr_performance.new("quest_90")
	perf90.build()
	
	var cull_dist90 := perf90.get_culling_distance()
	var lod_bias90 := perf90.get_lod_bias()
	
	print("Quest 90: cull=%.1f, lod_bias=%.1f" % [cull_dist90, lod_bias90])
	
	_expect(cull_dist > 0, "Culling distance should be positive")
	_expect(lod_bias > 0, "LOD bias should be positive")
	_expect(max_draw > 0, "Max draw calls should be positive")
	_expect(max_tri > 0, "Max triangles should be positive")
	_expect(cull_dist90 < cull_dist, "Quest 90 should have lower culling distance than Quest 72")

func test_apply_profile() -> void:
	var perf: VrPerformance = _vr_performance.new("quest_72")
	perf.build()
	
	var root := Node3D.new()
	root.name = "TestRoot"
	
	var mm_instance := MultiMeshInstance3D.new()
	mm_instance.name = "TestMultiMesh"
	var multimesh := MultiMesh.new()
	multimesh.instance_count = 10
	multimesh.mesh = BoxMesh.new()
	mm_instance.multimesh = multimesh
	root.add_child(mm_instance)
	
	var mi := MeshInstance3D.new()
	mi.name = "TestMeshInstance"
	mi.mesh = BoxMesh.new()
	root.add_child(mi)
	
	perf.apply_profile_to_scene(root)
	
	var mm_has_vis := mm_instance.visibility_range_end > 0.0
	var mi_has_vis := mi.visibility_range_end > 0.0
	
	_expect(mm_has_vis, "MultiMesh should have visibility range set")
	_expect(mi_has_vis, "MeshInstance should have visibility range set")

func _initialize() -> void:
	await process_frame
	print("=== R4 Perf B MultiMesh Tests ===")
	
	test_shared_materials()
	test_vr_performance_profiles()
	test_apply_profile()
	
	await process_frame
	
	print("=== Results: %d passed, %d failed ===" % [_checks - _failures.size(), _failures.size()])
	
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: %s" % failure)
		quit(1)