extends SceneTree

var _test_results = []
var _npc_lod
var _vr_performance

func _init():
	_test_results = []
	_npc_lod = preload("res://core/npc/npc_lod.gd")
	_vr_performance = preload("res://core/vr/vr_performance.gd")

func run_test(test_name: String, test_func: Callable):
	var result = test_func.call()
	if result:
		print("[PASS] %s" % test_name)
		_test_results.append({"name": test_name, "passed": true})
	else:
		print("[FAIL] %s" % test_name)
		_test_results.append({"name": test_name, "passed": false})

func test_lod_intervals():
	var lod = _npc_lod.new()
	
	var interval_close = lod.get_update_interval(5.0)
	var interval_med = lod.get_update_interval(20.0)
	var interval_far = lod.get_update_interval(60.0)
	
	print("Intervals - Close: %s, Med: %s, Far: %s" % [interval_close, interval_med, interval_far])
	
	return interval_close == 0.0 and interval_med == 0.5 and interval_far == 5.0

func test_visual_lod_levels():
	var lod = _npc_lod.new()
	
	var lod_near = lod.get_visual_lod(10.0)
	var lod_mid = lod.get_visual_lod(25.0)
	var lod_far = lod.get_visual_lod(50.0)
	var lod_culled = lod.get_visual_lod(90.0)
	var lod_occluded = lod.get_visual_lod(10.0, true)
	
	print("Visual LOD - Near: %d, Mid: %d, Far: %d, Culled: %d, Occluded: %d" % [lod_near, lod_mid, lod_far, lod_culled, lod_occluded])
	
	return lod_near == 0 and lod_mid == 1 and lod_far == 2 and lod_culled == 3 and lod_occluded == 3

func test_anim_lod_levels():
	var lod = _npc_lod.new()
	
	var anim_near = lod.get_anim_lod(15.0)
	var anim_mid = lod.get_anim_lod(35.0)
	var anim_far = lod.get_anim_lod(60.0)
	
	print("Anim LOD - Near: %d, Mid: %d, Far: %d" % [anim_near, anim_mid, anim_far])
	
	return anim_near == 0 and anim_mid == 1 and anim_far == 2

func test_ai_lod_levels():
	var lod = _npc_lod.new()
	
	var ai_near = lod.get_ai_lod(20.0)
	var ai_mid = lod.get_ai_lod(40.0)
	var ai_far = lod.get_ai_lod(70.0)
	
	print("AI LOD - Near: %d, Mid: %d, Far: %d" % [ai_near, ai_mid, ai_far])
	
	return ai_near == 0 and ai_mid == 1 and ai_far == 2

func test_lod_update():
	var lod = _npc_lod.new()
	
	var result1 = lod.update_lods(0.0, 5.0)
	var result2 = lod.update_lods(0.5, 5.0)
	var result3 = lod.update_lods(1.0, 5.0)
	
	print("Update 1: %s" % result1)
	print("Update 2: %s" % result2)
	print("Update 3: %s" % result3)
	
	return result1.visual_lod == 0 and result2.visual_lod == 0 and result3.visual_lod == 0

func test_lod_transitions():
	var lod = _npc_lod.new()
	
	lod.update_lods(0.0, 5.0)
	var state1 = lod.get_lod_state()
	
	lod.update_lods(1.0, 30.0)
	var state2 = lod.get_lod_state()
	
	lod.update_lods(2.0, 60.0)
	var state3 = lod.get_lod_state()
	
	print("State 1 (near): %s" % state1)
	print("State 2 (mid): %s" % state2)
	print("State 3 (far): %s" % state3)
	
	return state1.visual_lod == 0 and state2.visual_lod == 1 and state3.visual_lod == 2

func test_occlusion_check():
	var lod = _npc_lod.new()
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
	
	print("Behind camera occluded: %s, In front occluded: %s" % [occluded1, occluded2])
	
	root.queue_free()
	await process_frame
	
	return occluded1 == true and occluded2 == false

func test_vr_performance_culling():
	var perf = _vr_performance.new("quest_72")
	perf.build()
	
	var camera = Camera3D.new()
	camera.position = Vector3(0, 2, 0)
	camera.rotation = Vector3(0, 0, 0)
	
	var root = Node3D.new()
	root.add_child(camera)
	get_root().add_child(root)
	await process_frame
	
	perf.set_culling_camera(camera)
	
	var visible_aabb = AABB(Vector3(5, 0, 5), Vector3(2, 2, 2))
	var hidden_aabb = AABB(Vector3(-100, 0, -100), Vector3(2, 2, 2))
	
	var vis1 = perf.is_visible(visible_aabb)
	var vis2 = perf.is_visible(hidden_aabb)
	
	print("Visible AABB: %s, Hidden AABB: %s" % [vis1, vis2])
	
	var sphere_vis = perf.is_visible_sphere(Vector3(5, 0, 5), 2.0)
	var sphere_hid = perf.is_visible_sphere(Vector3(-100, 0, -100), 2.0)
	
	print("Visible sphere: %s, Hidden sphere: %s" % [sphere_vis, sphere_hid])
	
	root.queue_free()
	await process_frame
	
	return vis1 == true and vis2 == false and sphere_vis == true and sphere_hid == false

func test_vr_performance_profile_application():
	var perf = _vr_performance.new("quest_72")
	perf.build()
	
	var profile_0 = perf.current_profile()
	perf.set_target_mode("quest_90")
	var profile_90 = perf.current_profile()
	
	print("Profile 72Hz: %s" % profile_0)
	print("Profile 90Hz: %s" % profile_90)
	
	var cull_dist_72 = perf.get_culling_distance()
	var lod_bias_72 = perf.get_lod_bias()
	var max_dc_72 = perf.get_max_draw_calls()
	
	print("Cull dist: %s, LOD bias: %s, Max draw calls: %s" % [cull_dist_72, lod_bias_72, max_dc_72])
	
	return cull_dist_72 > 0 and lod_bias_72 > 0 and max_dc_72 > 0

func test_degrade_level():
	var perf = _vr_performance.new("quest_72")
	perf.build()
	
	var initial_profile = perf.current_profile()
	
	for i in range(20):
		perf.observe_frame(20.0)
	
	var degraded_profile = perf.current_profile()
	
	print("Initial degrade: %d, After degrade: %d" % [initial_profile.degrade_level, degraded_profile.degrade_level])
	print("Initial shadow_dist: %s, Degraded shadow_dist: %s" % [initial_profile.shadow_distance, degraded_profile.shadow_distance])
	
	return degraded_profile.degrade_level > initial_profile.degrade_level

func _initialize() -> void:
	await process_frame
	print("=== R4 Perf B LOD Tests ===")
	
	run_test("LOD Intervals", Callable(self, "test_lod_intervals"))
	run_test("Visual LOD Levels", Callable(self, "test_visual_lod_levels"))
	run_test("Anim LOD Levels", Callable(self, "test_anim_lod_levels"))
	run_test("AI LOD Levels", Callable(self, "test_ai_lod_levels"))
	run_test("LOD Update", Callable(self, "test_lod_update"))
	run_test("LOD Transitions", Callable(self, "test_lod_transitions"))
	run_test("Occlusion Check", Callable(self, "test_occlusion_check"))
	run_test("VR Performance Culling", Callable(self, "test_vr_performance_culling"))
	run_test("VR Performance Profile Application", Callable(self, "test_vr_performance_profile_application"))
	run_test("Degrade Level", Callable(self, "test_degrade_level"))
	
	var passed = 0
	var failed = 0
	for result in _test_results:
		if result.passed:
			passed += 1
		else:
			failed += 1
	
	print("=== Results: %d passed, %d failed ===" % [passed, failed])
	
	if failed > 0:
		quit(1)
	else:
		quit(0)