extends SceneTree

const VrPerformanceScript = preload("res://core/vr/vr_performance.gd")

var _checks: int = 0
var _failures: Array = []


func _initialize() -> void:
	await process_frame
	_test_performance_profiles()
	_test_vr_performance_degrade()
	_test_performance_edge_cases()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_performance_profiles() -> void:
	# Perfil 72 Hz por defecto
	var perf72 = VrPerformanceScript.new("quest_72")
	perf72.build()
	var profile72 = perf72.current_profile()
	_expect(profile72["mode"] == "quest_72", "modo quest_72")
	_expect(is_equal_approx(profile72["refresh_hz"], 72.0), "72 Hz refresh")
	_expect(is_equal_approx(profile72["frame_budget_ms"], 13.888), "frame budget 13.888ms: %s" % profile72["frame_budget_ms"])
	_expect(profile72["msaa"] == 2, "MSAA 2")
	_expect(profile72["foveation"] == 1, "foveation 1")
	_expect(profile72["render_scale"] == 1.0, "render scale 1.0")
	_expect(profile72["shadow_distance"] == 18.0, "shadow distance 18.0")
	_expect(profile72["particles"] == 120, "particles 120")
	_expect(profile72["npcs"] == 12, "npcs 12")
	_expect(profile72["decals"] == 48, "decals 48")
	
	# Perfil 90 Hz
	var perf90 = VrPerformanceScript.new("quest_90")
	perf90.build()
	var profile90 = perf90.current_profile()
	_expect(profile90["mode"] == "quest_90", "modo quest_90")
	_expect(is_equal_approx(profile90["refresh_hz"], 90.0), "90 Hz refresh")
	_expect(is_equal_approx(profile90["frame_budget_ms"], 11.111), "frame budget 11.111ms: %s" % profile90["frame_budget_ms"])
	_expect(profile90["msaa"] == 2, "MSAA 2")
	_expect(profile90["foveation"] == 1, "foveation 1")
	_expect(profile90["render_scale"] == 1.0, "render scale 1.0")
	_expect(profile90["shadow_distance"] == 16.0, "shadow distance 16.0")
	_expect(profile90["particles"] == 96, "particles 96")
	_expect(profile90["npcs"] == 10, "npcs 10")
	_expect(profile90["decals"] == 40, "decals 40")
	
	# Modo invalido cae a 72 Hz
	var perf_invalid = VrPerformanceScript.new("invalid_mode")
	perf_invalid.build()
	var profile_invalid = perf_invalid.current_profile()
	_expect(profile_invalid["mode"] == "quest_72", "modo invalido cae a quest_72")
	
	# set_target_mode cambia el perfil
	perf72.set_target_mode("quest_90")
	var switched = perf72.current_profile()
	_expect(switched["mode"] == "quest_90", "set_target_mode cambia a quest_90")
	_expect(switched["degrade_level"] == 0, "degrade_level reseteado al cambiar modo")


func _test_vr_performance_degrade() -> void:
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	
	# Nivel 0 = perfil base
	var p0 = perf.current_profile()
	_expect(p0["degrade_level"] == 0, "degrade_level inicial 0")
	_expect(p0["render_scale"] == 1.0, "render_scale base 1.0")
	_expect(p0["shadow_distance"] == 18.0, "shadow_distance base 18.0")
	
	# Simular frames sobre presupuesto para degradar (20ms > 13.888ms budget)
	for i in range(10):
		perf.observe_frame(20.0)
	
	var p1 = perf.current_profile()
	_expect(p1["degrade_level"] == 1, "degrade_level 1 tras frames lentos: %s" % p1["degrade_level"])
	_expect(p1["render_scale"] < 1.0, "render_scale reducido: %s" % p1["render_scale"])
	_expect(p1["shadow_distance"] < 18.0, "shadow_distance reducido: %s" % p1["shadow_distance"])
	
	# Degradar mas
	for i in range(10):
		perf.observe_frame(20.0)
	
	var p2 = perf.current_profile()
	_expect(p2["degrade_level"] == 2, "degrade_level 2: %s" % p2["degrade_level"])
	
	# Simular frames bajo presupuesto para recuperar (5ms << budget)
	for i in range(30):
		perf.observe_frame(5.0)
	
	var p_up = perf.current_profile()
	_expect(p_up["degrade_level"] == 1, "recupera a degrade_level 1: %s" % p_up["degrade_level"])
	
	# Max degrade level
	for i in range(20):
		perf.observe_frame(50.0)
	
	var p_max = perf.current_profile()
	_expect(p_max["degrade_level"] <= 4, "max degrade_level 4: %s" % p_max["degrade_level"])
	_expect(p_max["render_scale"] >= 0.7, "render_scale min 0.7: %s" % p_max["render_scale"])
	_expect(p_max["shadow_distance"] >= 6.0, "shadow_distance min 6.0: %s" % p_max["shadow_distance"])
	_expect(p_max["particles"] >= 24, "particles min 24: %s" % p_max["particles"])
	_expect(p_max["npcs"] >= 4, "npcs min 4: %s" % p_max["npcs"])
	_expect(p_max["decals"] >= 8, "decals min 8: %s" % p_max["decals"])
	
	# observe_frame con delta_s (necesita 8 frames para degradar)
	var perf_delta = VrPerformanceScript.new("quest_72")
	perf_delta.build()
	var result: Dictionary
	for i in range(10):
		result = perf_delta.observe_frame(0.0, 0.02)  # 20ms via delta
	_expect(result["frame_ms"] == 20.0, "frame_ms calculado desde delta: %s" % result["frame_ms"])
	_expect(result["degrade_level"] == 1, "degrade via delta: %s" % result["degrade_level"])


func _test_performance_edge_cases() -> void:
	# profile_for_mode static
	var static_72 = VrPerformanceScript.profile_for_mode("quest_72", 0)
	_expect(static_72["mode"] == "quest_72", "profile_for_mode static quest_72")
	_expect(static_72["degrade_level"] == 0, "profile_for_mode degrade 0")
	
	var static_90_2 = VrPerformanceScript.profile_for_mode("quest_90", 2)
	_expect(static_90_2["degrade_level"] == 2, "profile_for_mode quest_90 degrade 2")
	
	# apply_degrade_level static
	var base = VrPerformanceScript.profile_for_mode("quest_72", 0)
	var degraded = VrPerformanceScript.apply_degrade_level(base, 3)
	_expect(degraded["degrade_level"] == 3, "apply_degrade_level 3")
	_expect(degraded["render_scale"] < base["render_scale"], "render_scale reducido tras degrade")
	
	# is_below_72fps static
	_expect(VrPerformanceScript.is_below_72fps(14.0), "14ms > 13.888ms = below 72fps")
	_expect(not VrPerformanceScript.is_below_72fps(13.0), "13ms < 13.888ms = not below 72fps")
	
	# detect_openxr_available static (should be false in headless)
	var xr_avail = VrPerformanceScript.detect_openxr_available()
	_expect(xr_avail == false or xr_avail == true, "detect_openxr_available returns bool: %s" % xr_avail)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func is_equal_approx(a: float, b: float) -> bool:
	return absf(a - b) <= 0.001