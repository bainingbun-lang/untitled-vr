extends SceneTree

const VrPerformanceScript = preload("res://core/vr/vr_performance.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")
const VrGameModeScript = preload("res://core/vr/vr_game_mode.gd")
const HarnessScript = preload("res://tests/vr_sim_harness.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

func _initialize() -> void:
	await process_frame
	await _test_frame_budget_adherence()
	await _test_degrade_recovery_thresholds()
	await _test_memory_stability()
	await _test_npc_performance_scaling()
	await _test_particle_system_limits()
	await _test_render_scale_bounds()
	await _test_shadow_distance_bounds()
	await _test_msaa_foveation_bounds()
	await _test_decal_bounds()
	await _test_performance_profile_switching()
	await _test_headless_performance_baseline()
	await _test_static_profile_methods()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])

func _assert_in_range(value: float, min_val: float, max_val: float, message: String) -> void:
	_checks += 1
	if value < min_val or value > max_val:
		_failures.append("[%s] %s: valor=%.3f, rango=[%.3f, %.3f]" % [_case, message, value, min_val, max_val])

func _assert_close(value: float, target: float, tolerance: float, message: String) -> void:
	_checks += 1
	if absf(value - target) > tolerance:
		_failures.append("[%s] %s: valor=%.3f, objetivo=%.3f, tolerancia=%.3f" % [_case, message, value, target, tolerance])

func _test_frame_budget_adherence() -> void:
	_case = "frame_budget_adherence"
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	
	var budget72 = perf.current_profile()["frame_budget_ms"]
	_assert_close(budget72, 13.888, 0.001, "72Hz frame budget es 13.888ms")
	
	# is_below_72fps uses hardcoded 13.888ms threshold (72fps), not current profile budget
	# Frames well under 72fps budget
	var under72 = 7.0
	for i in range(10):
		var result = perf.observe_frame(under72)
		_expect(not result["below_72fps"], "frame %.1fms < 13.888ms NO marca below_72fps" % under72)
	
	# Frames at 72fps budget edge
	var at72 = 13.888
	for i in range(10):
		var result = perf.observe_frame(at72)
		_expect(not result["below_72fps"], "frame en 72fps budget (%.3fms) no marca below_72fps" % at72)
	
	# Frames over 72fps budget
	var over72 = 16.0
	for i in range(10):
		var result = perf.observe_frame(over72)
		_expect(result["below_72fps"], "frame %.1fms > 13.888ms marca below_72fps" % over72)
	
	# 90Hz budget
	perf.set_target_mode("quest_90")
	var budget90 = perf.current_profile()["frame_budget_ms"]
	_assert_close(budget90, 11.111, 0.001, "90Hz frame budget es 11.111ms")
	
	# 90Hz frame at 12.11ms is still UNDER 72fps threshold (13.888), so below_72fps = false
	var over90 = budget90 + 1.0  # 12.111ms
	for i in range(10):
		var result = perf.observe_frame(over90)
		_expect(not result["below_72fps"], "90Hz frame %.3fms < 13.888ms NO marca below_72fps" % over90)
	
	# But a frame at 15ms in 90Hz mode IS over 72fps threshold
	var over72_in_90 = 15.0
	for i in range(10):
		var result = perf.observe_frame(over72_in_90)
		_expect(result["below_72fps"], "90Hz frame %.1fms > 13.888ms marca below_72fps" % over72_in_90)

func _test_degrade_recovery_thresholds() -> void:
	_case = "degrade_recovery_thresholds"
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	
	var base_profile = perf.current_profile()
	var base_render = base_profile["render_scale"]
	var base_shadow = base_profile["shadow_distance"]
	var base_particles = base_profile["particles"]
	var base_npcs = base_profile["npcs"]
	var base_decals = base_profile["decals"]
	
	# Degrade level 1: downshift_frames (8) frames over budget
	_case = "degrade_level_1"
	for i in range(8):
		perf.observe_frame(20.0)
	var p1 = perf.current_profile()
	_expect(p1["degrade_level"] == 1, "degrade_level == 1 tras 8 frames lentos: %d" % p1["degrade_level"])
	_assert_in_range(p1["render_scale"], 0.7, 1.0, "render_scale en rango valido nivel 1")
	_assert_in_range(p1["shadow_distance"], 6.0, 18.0, "shadow_distance en rango valido nivel 1")
	_expect(p1["render_scale"] < base_render, "render_scale reducido nivel 1: %.3f < %.3f" % [p1["render_scale"], base_render])
	_expect(p1["shadow_distance"] < base_shadow, "shadow_distance reducido nivel 1: %.1f < %.1f" % [p1["shadow_distance"], base_shadow])
	
	# Degrade level 2: 8 more frames over budget
	_case = "degrade_level_2"
	for i in range(8):
		perf.observe_frame(20.0)
	var p2 = perf.current_profile()
	_expect(p2["degrade_level"] == 2, "degrade_level == 2: %d" % p2["degrade_level"])
	_expect(p2["render_scale"] < p1["render_scale"], "render_scale sigue bajando: %.3f < %.3f" % [p2["render_scale"], p1["render_scale"]])
	
	# Degrade to max level 4
	_case = "degrade_max_level"
	for i in range(20):
		perf.observe_frame(50.0)
	var pmax = perf.current_profile()
	_expect(pmax["degrade_level"] <= 4, "degrade_level max 4: %d" % pmax["degrade_level"])
	_assert_in_range(pmax["render_scale"], 0.7, 1.0, "render_scale min 0.7: %.3f" % pmax["render_scale"])
	_assert_in_range(pmax["shadow_distance"], 6.0, 24.0, "shadow_distance min 6.0: %.1f" % pmax["shadow_distance"])
	_expect(pmax["particles"] >= 24, "particles min 24: %d" % pmax["particles"])
	_expect(pmax["npcs"] >= 4, "npcs min 4: %d" % pmax["npcs"])
	_expect(pmax["decals"] >= 8, "decals min 8: %d" % pmax["decals"])
	
	# Recovery: upshift_frames (24) frames under budget per level
	_case = "recovery_level_3_to_2"
	for i in range(24):
		perf.observe_frame(5.0)
	var p3 = perf.current_profile()
	_expect(p3["degrade_level"] == 3, "recupera a nivel 3: %d" % p3["degrade_level"])
	
	_case = "recovery_level_2_to_1"
	for i in range(24):
		perf.observe_frame(5.0)
	var p2_rec = perf.current_profile()
	_expect(p2_rec["degrade_level"] == 2, "recupera a nivel 2: %d" % p2_rec["degrade_level"])
	
	_case = "recovery_level_1_to_0"
	for i in range(24):
		perf.observe_frame(5.0)
	var p1_rec = perf.current_profile()
	_expect(p1_rec["degrade_level"] == 1, "recupera a nivel 1: %d" % p1_rec["degrade_level"])
	
	for i in range(24):
		perf.observe_frame(5.0)
	var p0 = perf.current_profile()
	_expect(p0["degrade_level"] == 0, "recupera a nivel 0: %d" % p0["degrade_level"])
	_assert_close(p0["render_scale"], base_render, 0.01, "render_scale vuelve a base: %.3f" % p0["render_scale"])
	_assert_close(p0["shadow_distance"], base_shadow, 0.1, "shadow_distance vuelve a base: %.1f" % p0["shadow_distance"])

func _test_memory_stability() -> void:
	_case = "memory_stability"
	# Create and destroy performance objects repeatedly
	for cycle in range(5):
		var perf = VrPerformanceScript.new("quest_72")
		perf.build()
		
		# Stress observe_frame
		for i in range(100):
			perf.observe_frame(10.0 + (i % 5) * 2.0)
		
		# Switch modes
		perf.set_target_mode("quest_90")
		for i in range(50):
			perf.observe_frame(8.0)
		perf.set_target_mode("quest_72")
		
		perf.free()
	
	# Test with world simulation - just verify no crashes/leaks in basic cycle
	var meta = GeneratorScript.generate(12345, {
		"width": 20, "height": 15, "obstacle_density": 0.15, "spawn_count": 3,
	})
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	world.setup(meta)
	await process_frame
	await physics_frame
	
	# Verify world created successfully
	_expect(world.npcs.size() > 0, "mundo creado con NPCs: %d" % world.npcs.size())
	_expect(is_instance_valid(world), "mundo sigue valido")
	
	world.free()
	await process_frame
	await physics_frame
	_expect(not is_instance_valid(world), "mundo liberado correctamente")

func _test_npc_performance_scaling() -> void:
	_case = "npc_performance_scaling"
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	
	# Base profile NPC limit at level 0
	var base_npcs = perf.current_profile()["npcs"]
	_expect(base_npcs == 12, "72Hz base npcs == 12: %d" % base_npcs)
	
	# At degrade level 4, NPCs should be at minimum
	for i in range(20):
		perf.observe_frame(50.0)
	var max_degraded = perf.current_profile()
	_expect(max_degraded["npcs"] >= 4, "max degrade npcs >= 4: %d" % max_degraded["npcs"])
	_expect(max_degraded["npcs"] <= base_npcs, "max degrade npcs <= base: %d <= %d" % [max_degraded["npcs"], base_npcs])
	
	# Static profile_for_mode for 90Hz at level 0
	var base90 = VrPerformanceScript.profile_for_mode("quest_90", 0)
	_expect(base90["npcs"] == 10, "90Hz base npcs (static) == 10: %d" % base90["npcs"])
	
	# But instance after switching from degraded state keeps degrade_level
	var perf2 = VrPerformanceScript.new("quest_90")
	perf2.build()
	var base90_inst = perf2.current_profile()
	_expect(base90_inst["npcs"] == 10, "90Hz fresh instance npcs == 10: %d" % base90_inst["npcs"])

func _test_particle_system_limits() -> void:
	_case = "particle_system_limits"
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	
	var base_particles = perf.current_profile()["particles"]
	_expect(base_particles == 120, "72Hz base particles == 120: %d" % base_particles)
	
	for i in range(20):
		perf.observe_frame(50.0)
	var max_degraded = perf.current_profile()
	_expect(max_degraded["particles"] >= 24, "max degrade particles >= 24: %d" % max_degraded["particles"])
	_expect(max_degraded["particles"] <= base_particles, "max degrade particles <= base: %d <= %d" % [max_degraded["particles"], base_particles])

func _test_render_scale_bounds() -> void:
	_case = "render_scale_bounds"
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	
	# Base render scale
	_assert_close(perf.current_profile()["render_scale"], 1.0, 0.001, "base render_scale = 1.0")
	
	# Max degrade
	for i in range(20):
		perf.observe_frame(50.0)
	var max_degraded = perf.current_profile()
	_assert_in_range(max_degraded["render_scale"], 0.7, 1.0, "render_scale en [0.7, 1.0]: %.3f" % max_degraded["render_scale"])
	
	# Test static profile_for_mode with degrade levels
	for level in range(5):
		var prof = VrPerformanceScript.profile_for_mode("quest_72", level)
		_assert_in_range(prof["render_scale"], 0.7, 1.0, "profile_for_mode nivel %d render_scale en rango: %.3f" % [level, prof["render_scale"]])
		_assert_in_range(prof["shadow_distance"], 6.0, 18.0, "profile_for_mode nivel %d shadow_distance en rango: %.1f" % [level, prof["shadow_distance"]])
		_assert_in_range(prof["particles"], 24, 160, "profile_for_mode nivel %d particles en rango: %d" % [level, prof["particles"]])
		_assert_in_range(prof["npcs"], 4, 16, "profile_for_mode nivel %d npcs en rango: %d" % [level, prof["npcs"]])
		_assert_in_range(prof["decals"], 8, 64, "profile_for_mode nivel %d decals en rango: %d" % [level, prof["decals"]])

func _test_shadow_distance_bounds() -> void:
	_case = "shadow_distance_bounds"
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	
	_assert_close(perf.current_profile()["shadow_distance"], 18.0, 0.1, "72Hz base shadow_distance = 18.0")
	
	for i in range(20):
		perf.observe_frame(50.0)
	var max_degraded = perf.current_profile()
	_assert_in_range(max_degraded["shadow_distance"], 6.0, 18.0, "shadow_distance en [6.0, 18.0]: %.1f" % max_degraded["shadow_distance"])
	
	# 90Hz base via static method (fresh instance would work too)
	var base90 = VrPerformanceScript.profile_for_mode("quest_90", 0)
	_assert_close(base90["shadow_distance"], 16.0, 0.1, "90Hz base shadow_distance (static) = 16.0")

func _test_msaa_foveation_bounds() -> void:
	_case = "msaa_foveation_bounds"
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	
	_assert_close(perf.current_profile()["msaa"], 2, 0, "72Hz base MSAA = 2")
	_assert_close(perf.current_profile()["foveation"], 1, 0, "72Hz base foveation = 1")
	
	for i in range(20):
		perf.observe_frame(50.0)
	var max_degraded = perf.current_profile()
	_assert_in_range(max_degraded["msaa"], 0, 4, "MSAA en [0, 4]: %d" % max_degraded["msaa"])
	_assert_in_range(max_degraded["foveation"], 0, 4, "foveation en [0, 4]: %d" % max_degraded["foveation"])
	
	# At high degrade, MSAA should drop to 0, foveation should increase
	_expect(max_degraded["msaa"] <= 2, "MSAA no aumenta con degrade: %d" % max_degraded["msaa"])
	_expect(max_degraded["foveation"] >= 1, "foveation no baja de 1: %d" % max_degraded["foveation"])

func _test_decal_bounds() -> void:
	_case = "decal_bounds"
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	
	_assert_close(perf.current_profile()["decals"], 48, 0, "72Hz base decals = 48")
	
	for i in range(20):
		perf.observe_frame(50.0)
	var max_degraded = perf.current_profile()
	_assert_in_range(max_degraded["decals"], 8, 64, "decals en [8, 64]: %d" % max_degraded["decals"])

func _test_performance_profile_switching() -> void:
	_case = "performance_profile_switching"
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	
	# Degrade first
	for i in range(10):
		perf.observe_frame(20.0)
	var degraded = perf.current_profile()
	var degrade_level = degraded["degrade_level"]
	_expect(degrade_level > 0, "degradado antes de switch: %d" % degrade_level)
	
	# Switch mode: set_target_mode keeps current degrade_level, rebuilds profile for new mode at that level
	perf.set_target_mode("quest_90")
	var switched = perf.current_profile()
	_expect(switched["degrade_level"] == degrade_level, "degrade_level SE MANTIENE al cambiar modo: %d" % switched["degrade_level"])
	_expect(switched["mode"] == "quest_90", "modo cambiado a quest_90")
	_assert_close(switched["frame_budget_ms"], 11.111, 0.001, "90Hz budget tras switch")
	# At same degrade_level, 90Hz profile has different values
	_expect(switched["npcs"] != degraded["npcs"], "npcs difiere entre modos en mismo degrade_level")
	
	# Switch back to 72Hz
	perf.set_target_mode("quest_72")
	var back = perf.current_profile()
	_expect(back["degrade_level"] == degrade_level, "degrade_level se mantiene al volver a 72Hz: %d" % back["degrade_level"])
	_expect(back["mode"] == "quest_72", "modo vuelto a quest_72")
	_assert_close(back["frame_budget_ms"], 13.888, 0.001, "72Hz budget tras switch back")

func _test_headless_performance_baseline() -> void:
	_case = "headless_performance_baseline"
	# Test that static methods work correctly in headless
	var xr_avail = VrPerformanceScript.detect_openxr_available()
	_expect(xr_avail == false, "detect_openxr_available = false en headless")
	
	var below = VrPerformanceScript.is_below_72fps(14.0)
	_expect(below, "14ms > 13.888ms -> below 72fps")
	
	var not_below = VrPerformanceScript.is_below_72fps(13.0)
	_expect(not not_below, "13ms < 13.888ms -> NOT below 72fps")
	
	# Test observe_frame with delta_s
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	var result: Dictionary
	for i in range(10):
		result = perf.observe_frame(0.0, 0.02)  # 20ms via delta
	_expect(result["frame_ms"] == 20.0, "frame_ms calculado desde delta_s: %.1f" % result["frame_ms"])
	_expect(result["degrade_level"] == 1, "degrade via delta_s: %d" % result["degrade_level"])
	
	# Test static apply_degrade_level
	var base = VrPerformanceScript.profile_for_mode("quest_72", 0)
	var degraded = VrPerformanceScript.apply_degrade_level(base, 3)
	_expect(degraded["degrade_level"] == 3, "apply_degrade_level(3) -> nivel 3")
	_expect(degraded["render_scale"] < base["render_scale"], "apply_degrade_level reduce render_scale: %.3f < %.3f" % [degraded["render_scale"], base["render_scale"]])
	
	# Test invalid mode falls back
	var perf_invalid = VrPerformanceScript.new("invalid_mode_xyz")
	perf_invalid.build()
	var invalid_profile = perf_invalid.current_profile()
	_expect(invalid_profile["mode"] == "quest_72", "modo invalido cae a quest_72: %s" % invalid_profile["mode"])

func _test_static_profile_methods() -> void:
	_case = "static_profile_methods"
	# Test profile_for_mode with all valid modes and levels
	for mode in ["quest_72", "quest_90"]:
		for level in range(5):
			var prof = VrPerformanceScript.profile_for_mode(mode, level)
			_expect(prof["mode"] == mode, "profile_for_mode modo correcto: %s" % prof["mode"])
			_expect(prof["degrade_level"] == level, "profile_for_mode nivel correcto: %d" % prof["degrade_level"])
			_assert_in_range(prof["render_scale"], 0.7, 1.0, "render_scale en rango")
			_assert_in_range(prof["shadow_distance"], 6.0, 24.0, "shadow_distance en rango")
			_assert_in_range(prof["particles"], 24, 160, "particles en rango")
			_assert_in_range(prof["npcs"], 4, 16, "npcs en rango")
			_assert_in_range(prof["decals"], 8, 64, "decals en rango")
			_assert_in_range(prof["msaa"], 0, 4, "msaa en rango")
			_assert_in_range(prof["foveation"], 0, 4, "foveation en rango")
	
	# Test invalid mode falls back to quest_72
	var invalid = VrPerformanceScript.profile_for_mode("invalid", 0)
	_expect(invalid["mode"] == "quest_72", "modo invalido en static cae a quest_72")
	
	# Test apply_degrade_level monotonicity
	var base72 = VrPerformanceScript.profile_for_mode("quest_72", 0)
	for level in range(1, 5):
		var d = VrPerformanceScript.apply_degrade_level(base72, level)
		_expect(d["degrade_level"] == level, "apply_degrade_level nivel %d" % level)
		_expect(d["render_scale"] <= base72["render_scale"], "render_scale no aumenta con degrade")
		_expect(d["shadow_distance"] <= base72["shadow_distance"], "shadow_distance no aumenta con degrade")
		_expect(d["particles"] <= base72["particles"], "particles no aumenta con degrade")
		_expect(d["npcs"] <= base72["npcs"], "npcs no aumenta con degrade")
		_expect(d["decals"] <= base72["decals"], "decals no aumenta con degrade")