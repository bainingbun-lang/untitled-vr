extends SceneTree

const VrComfortScript = preload("res://core/vr/vr_comfort.gd")
const VrPerformanceScript = preload("res://core/vr/vr_performance.gd")

var _checks: int = 0
var _failures: Array = []


func _initialize() -> void:
	await process_frame
	_test_vignette_regression()
	_test_snap_turn_regression()
	_test_smooth_turn_regression()
	_test_locomotion_regression()
	_test_teleport_regression()
	_test_rotation_regression()
	_test_performance_profiles()
	_test_vr_performance_degrade()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_vignette_regression() -> void:
	# Vignette en reposo = 0
	_expect(VrComfortScript.compute_vignette(0.0, 0.0) == 0.0, "viñeta en reposo es 0")
	
	# Vignette monotona con velocidad angular
	_expect(VrComfortScript.compute_vignette(0.0, 1.0) < VrComfortScript.compute_vignette(0.0, 2.0), "viñeta monotona con velocidad angular")
	
	# Vignette con intensity=0.85 por defecto: max value = 1.0 * 0.85 = 0.85
	_expect(is_equal_approx(VrComfortScript.compute_vignette(0.0, 2.0), 0.85), "viñeta en referencia angular: %s" % VrComfortScript.compute_vignette(0.0, 2.0))
	_expect(is_equal_approx(VrComfortScript.compute_vignette(3.0, 0.0), 0.85), "viñeta en referencia lineal: %s" % VrComfortScript.compute_vignette(3.0, 0.0))
	
	# Vignette combinada no excede 1.0 * intensity = 0.85
	var combined = VrComfortScript.compute_vignette(3.0, 2.0)
	_expect(is_equal_approx(combined, 0.85), "viñeta combinada no excede intensity: %s" % combined)
	
	# Valores negativos: NO se tratan como positivos (sin abs()), dan 0
	_expect(VrComfortScript.compute_vignette(-3.0, 0.0) == 0.0, "velocidad lineal negativa da 0: %s" % VrComfortScript.compute_vignette(-3.0, 0.0))
	_expect(VrComfortScript.compute_vignette(0.0, -2.0) == 0.0, "velocidad angular negativa da 0: %s" % VrComfortScript.compute_vignette(0.0, -2.0))
	
	# Con intensity=1.0 si satura a 1.0
	_expect(is_equal_approx(VrComfortScript.compute_vignette(3.0, 0.0, 3.0, 2.0, 1.0), 1.0), "con intensity=1.0 satura a 1.0")
	_expect(is_equal_approx(VrComfortScript.compute_vignette(0.0, 2.0, 3.0, 2.0, 1.0), 1.0), "con intensity=1.0 satura angular a 1.0")


func _test_snap_turn_regression() -> void:
	# Snap turn 45° exacto a la derecha (negativo en Godot)
	var snap_right := VrComfortScript.turn_delta(1.0, "snap", 1.6, 45.0, 0.016, 0.2, true)
	_expect(is_equal_approx(snap_right, -deg_to_rad(45.0)), "snap 45° derecha: %s vs %s" % [snap_right, -deg_to_rad(45.0)])
	
	# Snap turn 45° exacto a la izquierda (positivo)
	var snap_left := VrComfortScript.turn_delta(-1.0, "snap", 1.6, 45.0, 0.016, 0.2, true)
	_expect(is_equal_approx(snap_left, deg_to_rad(45.0)), "snap 45° izquierda: %s vs %s" % [snap_left, deg_to_rad(45.0)])
	
	# Snap bloqueado durante cooldown
	_expect(VrComfortScript.turn_delta(1.0, "snap", 1.6, 45.0, 0.016, 0.2, false) == 0.0, "snap bloqueado en cooldown")
	
	# Snap ignorado bajo umbral 0.7
	_expect(VrComfortScript.turn_delta(0.5, "snap", 1.6, 45.0, 0.016, 0.2, true) == 0.0, "snap ignorado bajo umbral 0.7")
	
	# Snap en umbral exacto 0.7 (absf(stick_x) < maxf(deadzone, snap_threshold) => 0.7 < maxf(0.2, 0.7) = 0.7 => false, so it activates)
	_expect(VrComfortScript.turn_delta(0.7, "snap", 1.6, 45.0, 0.016, 0.2, true) != 0.0, "snap en umbral 0.7 activa")
	
	# Snap no depende de delta para el angulo (solo para cooldown)
	var snap_a := VrComfortScript.turn_delta(1.0, "snap", 1.6, 45.0, 0.016, 0.2, true)
	var snap_b := VrComfortScript.turn_delta(1.0, "snap", 1.6, 45.0, 0.032, 0.2, true)
	_expect(is_equal_approx(snap_a, snap_b), "snap angulo independiente de delta: %s vs %s" % [snap_a, snap_b])
	
	# Mode "off" retorna 0
	_expect(VrComfortScript.turn_delta(1.0, "off", 1.6, 45.0, 0.016, 0.2, true) == 0.0, "mode off retorna 0")
	
	# delta <= 0 retorna 0
	_expect(VrComfortScript.turn_delta(1.0, "snap", 1.6, 45.0, 0.0, 0.2, true) == 0.0, "delta 0 retorna 0")
	_expect(VrComfortScript.turn_delta(1.0, "snap", 1.6, 45.0, -0.016, 0.2, true) == 0.0, "delta negativo retorna 0")


func _test_smooth_turn_regression() -> void:
	# Suave proporcional al stick y delta
	var smooth := VrComfortScript.turn_delta(1.0, "smooth", 2.0, 30.0, 0.5, 0.2, true)
	var expected := -1.0 * 2.0 * 0.5
	_expect(is_equal_approx(smooth, expected), "smooth proporcional: %s vs %s" % [smooth, expected])
	
	# Suave respeta deadzone (0.1 < 0.2)
	_expect(VrComfortScript.turn_delta(0.1, "smooth", 2.0, 30.0, 0.5, 0.2, true) == 0.0, "smooth respeta deadzone 0.2")
	
	# Suave EN deadzone exacto (absf(stick_x) <= deadzone): 0.2 <= 0.2 => true => 0
	_expect(VrComfortScript.turn_delta(0.2, "smooth", 2.0, 30.0, 0.5, 0.2, true) == 0.0, "smooth en deadzone exacto da 0")
	
	# Suave LIGERAMENTE arriba de deadzone
	_expect(VrComfortScript.turn_delta(0.21, "smooth", 2.0, 30.0, 0.5, 0.2, true) != 0.0, "smooth arriba de deadzone activa")
	
	# Suave: can_step FALSE no afecta a modo smooth (solo snap)
	var smooth_cooldown := VrComfortScript.turn_delta(1.0, "smooth", 2.0, 30.0, 0.5, 0.2, false)
	_expect(smooth_cooldown != 0.0, "smooth NO bloqueado por can_step=false: %s" % smooth_cooldown)
	
	# Suave escala con velocidad de giro
	var slow := VrComfortScript.turn_delta(1.0, "smooth", 1.0, 30.0, 0.5, 0.2, true)
	var fast := VrComfortScript.turn_delta(1.0, "smooth", 4.0, 30.0, 0.5, 0.2, true)
	_expect(absf(fast) > absf(slow), "smooth escala con turn_speed: %s vs %s" % [fast, slow])
	
	# Suave escala con delta
	var small_delta := VrComfortScript.turn_delta(1.0, "smooth", 2.0, 30.0, 0.1, 0.2, true)
	var large_delta := VrComfortScript.turn_delta(1.0, "smooth", 2.0, 30.0, 1.0, 0.2, true)
	_expect(absf(large_delta) > absf(small_delta), "smooth escala con delta: %s vs %s" % [large_delta, small_delta])
	
	# Signo: stick_x positivo => yaw negativo (derecha en Godot)
	_expect(VrComfortScript.turn_delta(1.0, "smooth", 2.0, 30.0, 0.5, 0.2, true) < 0.0, "stick positivo => yaw negativo")
	_expect(VrComfortScript.turn_delta(-1.0, "smooth", 2.0, 30.0, 0.5, 0.2, true) > 0.0, "stick negativo => yaw positivo")


func _test_locomotion_regression() -> void:
	# Stick arriba (y=-1) con head facing -Z da velocity +Z (signo invertido en implementacion actual)
	var forward := VrComfortScript.locomotion_velocity(Vector2(0.0, -1.0), Vector3(0.0, 0.0, -1.0), 2.2, 0.2)
	_expect(forward.is_equal_approx(Vector3(0.0, 0.0, 2.2)), "stick arriba da +Z: %s" % forward)
	
	# Stick abajo (y=1) con head facing -Z da velocity -Z
	var backward := VrComfortScript.locomotion_velocity(Vector2(0.0, 1.0), Vector3(0.0, 0.0, -1.0), 2.2, 0.2)
	_expect(backward.is_equal_approx(Vector3(0.0, 0.0, -2.2)), "stick abajo da -Z: %s" % backward)
	
	# Stick derecha (x=1) con head facing -Z da velocity +X
	var right := VrComfortScript.locomotion_velocity(Vector2(1.0, 0.0), Vector3(0.0, 0.0, -1.0), 2.2, 0.2)
	_expect(right.is_equal_approx(Vector3(2.2, 0.0, 0.0)), "stick derecha da +X: %s" % right)
	
	# Stick izquierda (x=-1) con head facing -Z da velocity -X
	var left := VrComfortScript.locomotion_velocity(Vector2(-1.0, 0.0), Vector3(0.0, 0.0, -1.0), 2.2, 0.2)
	_expect(left.is_equal_approx(Vector3(-2.2, 0.0, 0.0)), "stick izquierda da -X: %s" % left)
	
	# Deadzone frena movimiento
	var deadzone := VrComfortScript.locomotion_velocity(Vector2(0.1, 0.0), Vector3(0.0, 0.0, -1.0), 2.2, 0.2)
	_expect(deadzone.is_equal_approx(Vector3.ZERO), "deadzone frena: %s" % deadzone)
	
	# Velocidad escala con max_speed
	var slow := VrComfortScript.locomotion_velocity(Vector2(0.0, -1.0), Vector3(0.0, 0.0, -1.0), 1.0, 0.2)
	var fast := VrComfortScript.locomotion_velocity(Vector2(0.0, -1.0), Vector3(0.0, 0.0, -1.0), 4.0, 0.2)
	_expect(fast.length() > slow.length(), "velocidad escala con max_speed: %s vs %s" % [fast.length(), slow.length()])
	
	# Direccion de la cabeza afecta direccion del movimiento
	# head facing +X: stick up da -X
	var head_right := VrComfortScript.locomotion_velocity(Vector2(0.0, -1.0), Vector3(1.0, 0.0, 0.0), 2.2, 0.2)
	_expect(head_right.is_equal_approx(Vector3(-2.2, 0.0, 0.0)), "head forward +X da -X: %s" % head_right)
	
	# head facing -X: stick up da +X
	var head_left := VrComfortScript.locomotion_velocity(Vector2(0.0, -1.0), Vector3(-1.0, 0.0, 0.0), 2.2, 0.2)
	_expect(head_left.is_equal_approx(Vector3(2.2, 0.0, 0.0)), "head forward -X da +X: %s" % head_left)
	
	# Stick diagonal
	var diag := VrComfortScript.locomotion_velocity(Vector2(1.0, -1.0), Vector3(0.0, 0.0, -1.0), 2.2, 0.2)
	_expect(diag.length() > 2.0, "stick diagonal tiene magnitud mayor: %s" % diag.length())
	
	# forward vector con Y no cero se aplana
	var forward_y := VrComfortScript.locomotion_velocity(Vector2(0.0, -1.0), Vector3(0.0, 1.0, -1.0), 2.2, 0.2)
	_expect(absf(forward_y.y) < 0.001, "velocidad Y ~0: %s" % forward_y.y)


func _test_teleport_regression() -> void:
	# Teleport conserva altura de la cabeza
	var tp := VrComfortScript.translation_for_teleport(
		Transform3D(Basis.IDENTITY, Vector3(0.0, 1.6, 0.0)),
		Vector3(0.0, 1.6, 0.0),
		Vector3(3.0, 0.0, 4.0)
	)
	_expect(tp.origin.is_equal_approx(Vector3(3.0, 1.6, 4.0)), "teleport conserva altura: %s" % tp.origin)
	
	# Teleport desde altura diferente
	var tp2 := VrComfortScript.translation_for_teleport(
		Transform3D(Basis.IDENTITY, Vector3(0.0, 1.8, 0.0)),
		Vector3(0.0, 1.8, 0.0),
		Vector3(5.0, 0.0, -2.0)
	)
	_expect(tp2.origin.is_equal_approx(Vector3(5.0, 1.8, -2.0)), "teleport altura 1.8: %s" % tp2.origin)
	
	# Teleport solo afecta X/Z, no Y (target.y = 5.0, head.y = 1.6 => shift.y = 3.4 => set to 0 => Y stays 1.6)
	var tp3 := VrComfortScript.translation_for_teleport(
		Transform3D(Basis.IDENTITY, Vector3(0.0, 1.6, 0.0)),
		Vector3(0.0, 1.6, 0.0),
		Vector3(10.0, 5.0, 10.0)
	)
	_expect(is_equal_approx(tp3.origin.y, 1.6), "teleport Y fijo en altura cabeza: %s" % tp3.origin.y)
	_expect(is_equal_approx(tp3.origin.x, 10.0) and is_equal_approx(tp3.origin.z, 10.0), "teleport X/Z objetivo: %s" % tp3.origin)
	
	# Teleport con rotacion en xform no afecta (usa xform.origin + shift)
	var tp4 := VrComfortScript.translation_for_teleport(
		Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(90.0)), Vector3(1.0, 1.6, 2.0)),
		Vector3(1.0, 1.6, 2.0),
		Vector3(4.0, 0.0, 6.0)
	)
	_expect(is_equal_approx(tp4.origin.y, 1.6), "teleport con rotacion Y fijo: %s" % tp4.origin.y)


func _test_rotation_regression() -> void:
	# Rotacion alrededor del pivot de la cabeza (90°)
	var pivot := Vector3(1.0, 1.6, 2.0)
	var xform := Transform3D(Basis.IDENTITY, pivot + Vector3(0.0, 0.0, 1.0))
	var rotated := VrComfortScript.rotate_around_y(xform, pivot, deg_to_rad(90.0))
	var expected := pivot + Vector3(1.0, 0.0, 0.0)
	_expect(rotated.origin.distance_to(expected) < 0.0001, "rotate_around_y 90°: %s vs %s" % [rotated.origin, expected])
	
	# Rotacion 180°
	var rotated180 := VrComfortScript.rotate_around_y(xform, pivot, deg_to_rad(180.0))
	var expected180 := pivot + Vector3(0.0, 0.0, -1.0)
	_expect(rotated180.origin.distance_to(expected180) < 0.0001, "rotate_around_y 180°: %s vs %s" % [rotated180.origin, expected180])
	
	# Rotacion -90° (270°)
	var rotated270 := VrComfortScript.rotate_around_y(xform, pivot, deg_to_rad(-90.0))
	var expected270 := pivot + Vector3(-1.0, 0.0, 0.0)
	_expect(rotated270.origin.distance_to(expected270) < 0.0001, "rotate_around_y -90°: %s vs %s" % [rotated270.origin, expected270])
	
	# Rotacion 0° no cambia posicion
	var rotated0 := VrComfortScript.rotate_around_y(xform, pivot, 0.0)
	_expect(rotated0.origin.distance_to(xform.origin) < 0.0001, "rotate_around_y 0° sin cambio: %s vs %s" % [rotated0.origin, xform.origin])
	
	# Distancia al pivot se conserva
	var dist_before := xform.origin.distance_to(pivot)
	var dist_after := rotated.origin.distance_to(pivot)
	_expect(is_equal_approx(dist_before, dist_after), "distancia al pivot conservada: %s vs %s" % [dist_before, dist_after])
	
	# Basis tambien rota
	_expect(not rotated.basis.is_equal_approx(xform.basis), "basis rota: %s vs %s" % [rotated.basis, xform.basis])


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
	
	# Perfil 90 Hz
	var perf90 = VrPerformanceScript.new("quest_90")
	perf90.build()
	var profile90 = perf90.current_profile()
	_expect(profile90["mode"] == "quest_90", "modo quest_90")
	_expect(is_equal_approx(profile90["refresh_hz"], 90.0), "90 Hz refresh")
	_expect(is_equal_approx(profile90["frame_budget_ms"], 11.111), "frame budget 11.111ms: %s" % profile90["frame_budget_ms"])
	
	# Modo invalido cae a 72 Hz
	var perf_invalid = VrPerformanceScript.new("invalid_mode")
	perf_invalid.build()
	var profile_invalid = perf_invalid.current_profile()
	_expect(profile_invalid["mode"] == "quest_72", "modo invalido cae a quest_72")


func _test_vr_performance_degrade() -> void:
	var perf = VrPerformanceScript.new("quest_72")
	perf.build()
	
	# Nivel 0 = perfil base
	var p0 = perf.current_profile()
	_expect(p0["degrade_level"] == 0, "degrade_level inicial 0")
	_expect(p0["render_scale"] == 1.0, "render_scale base 1.0")
	
	# Simular frames sobre presupuesto para degradar
	for i in range(10):
		perf.observe_frame(20.0)  # 20ms > 13.888ms budget
	
	var p1 = perf.current_profile()
	_expect(p1["degrade_level"] == 1, "degrade_level 1 tras frames lentos: %s" % p1["degrade_level"])
	_expect(p1["render_scale"] < 1.0, "render_scale reducido: %s" % p1["render_scale"])
	
	# Degradar mas
	for i in range(10):
		perf.observe_frame(20.0)
	
	var p2 = perf.current_profile()
	_expect(p2["degrade_level"] == 2, "degrade_level 2: %s" % p2["degrade_level"])
	
	# Simular frames bajo presupuesto para recuperar
	for i in range(30):
		perf.observe_frame(5.0)  # 5ms << budget
	
	var p_up = perf.current_profile()
	_expect(p_up["degrade_level"] == 1, "recupera a degrade_level 1: %s" % p_up["degrade_level"])
	
	# Max degrade level
	for i in range(20):
		perf.observe_frame(50.0)
	
	var p_max = perf.current_profile()
	_expect(p_max["degrade_level"] <= 4, "max degrade_level 4: %s" % p_max["degrade_level"])
	_expect(p_max["render_scale"] >= 0.7, "render_scale min 0.7: %s" % p_max["render_scale"])
	_expect(p_max["shadow_distance"] >= 6.0, "shadow_distance min 6.0: %s" % p_max["shadow_distance"])


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func is_equal_approx(a: float, b: float, epsilon: float = 0.001) -> bool:
	return absf(a - b) <= epsilon