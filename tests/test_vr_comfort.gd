extends SceneTree

const VrComfort = preload("res://core/vr/vr_comfort.gd")
const VrSettingsPanel = preload("res://core/vr/vr_settings_panel.gd")
const GameSettings = preload("res://core/game/game_settings.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _initialize() -> void:
	await process_frame
	_test_vr_comfort_edge_cases()
	_test_vr_settings_panel()
	_test_profile_persistence()
	_test_presets()
	_test_vignette_computation()
	_test_turn_delta()
	_test_locomotion_velocity()
	_test_teleport_and_seated()
	_test_rotation_helpers()
	
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_vr_comfort_edge_cases() -> void:
	_case = "PROFILE_KEYS constant has all keys"
	var def := VrComfort.PROFILE_KEYS
	_expect(def.size() == 16, "PROFILE_KEYS tiene 16 claves")
	var expected_keys = ["version", "turn_mode", "smooth_turn_speed", "snap_turn_degrees", "snap_cooldown", "stick_deadzone", "snap_threshold", "move_speed", "comfort_vignette_enabled", "vignette_intensity", "vignette_speed_ref", "vignette_angular_ref", "teleport_enabled", "teleport_max_distance", "seated_mode", "height_offset"]
	for key in expected_keys:
		_expect(def.has(key), "falta clave en PROFILE_KEYS: %s" % key)
	
	_case = "VERSION constant"
	_expect(VrComfort.VERSION == 1, "VERSION == 1")
	
	_case = "default_profile returns correct structure"
	var profile = VrComfort.default_profile()
	_expect(profile.size() == 16, "default_profile tiene 16 claves")
	for key in VrComfort.PROFILE_KEYS:
		_expect(profile.has(key), "falta clave en default_profile: %s" % key)
	
	_case = "validate empty dict"
	var r := VrComfort.validate_profile({})
	_expect(not r["ok"], "dict vacio falla")
	_expect(r["errors"].size() > 0, "tiene errores")
	
	_case = "validate non-dict (skipped - GDScript static typing prevents)"
	_expect(true, "GDScript static typing prevents passing Array to Dictionary param at compile time")
	
	_case = "validate missing keys"
	var incomplete = VrComfort.default_profile().duplicate(true)
	incomplete.erase("turn_mode")
	r = VrComfort.validate_profile(incomplete)
	_expect(not r["ok"], "falta turn_mode falla")
	_expect(r["errors"].has("falta clave: turn_mode"), "error clave faltante")
	
	_case = "validate wrong version"
	var wrong_ver = VrComfort.default_profile().duplicate(true)
	wrong_ver["version"] = 999
	r = VrComfort.validate_profile(wrong_ver)
	_expect(not r["ok"], "version incorrecta falla")
	_expect(r["errors"].has("version de perfil no soportada"), "error version")
	
	_case = "validate wrong turn_mode"
	var bad_turn = VrComfort.default_profile().duplicate(true)
	bad_turn["turn_mode"] = "invalid"
	r = VrComfort.validate_profile(bad_turn)
	_expect(not r["ok"], "turn_mode invalido falla")
	_expect(r["errors"].has("turn_mode invalido"), "error turn_mode")
	
	_case = "validate negative numbers (except height_offset)"
	for key in ["smooth_turn_speed", "snap_turn_degrees", "snap_cooldown", "stick_deadzone", "snap_threshold", "move_speed", "vignette_intensity", "vignette_speed_ref", "vignette_angular_ref", "teleport_max_distance"]:
		var bad_num = VrComfort.default_profile().duplicate(true)
		bad_num[key] = -1.0
		r = VrComfort.validate_profile(bad_num)
		_expect(not r["ok"], "%s negativo falla" % key)
		_expect(r["errors"].has(key + " fuera de rango (negativo)"), "error negativo: %s" % key)
	
	_case = "validate height_offset allows negative"
	var neg_offset = VrComfort.default_profile().duplicate(true)
	neg_offset["height_offset"] = -0.5
	r = VrComfort.validate_profile(neg_offset)
	_expect(r["ok"], "height_offset negativo permitido: " + str(r["errors"]))
	
	_case = "validate stick_deadzone > 1.0"
	var bad_dz = VrComfort.default_profile().duplicate(true)
	bad_dz["stick_deadzone"] = 1.5
	r = VrComfort.validate_profile(bad_dz)
	_expect(not r["ok"], "deadzone > 1 falla")
	_expect(r["errors"].has("stick_deadzone > 1.0"), "error deadzone")
	
	_case = "validate vignette_intensity > 1.0"
	var bad_vi = VrComfort.default_profile().duplicate(true)
	bad_vi["vignette_intensity"] = 1.5
	r = VrComfort.validate_profile(bad_vi)
	_expect(not r["ok"], "vignette_intensity > 1 falla")
	_expect(r["errors"].has("vignette_intensity > 1.0"), "error vignette_intensity")
	
	_case = "validate bool fields"
	for key in ["comfort_vignette_enabled", "teleport_enabled", "seated_mode"]:
		var bad_bool = VrComfort.default_profile().duplicate(true)
		bad_bool[key] = "no es bool"
		r = VrComfort.validate_profile(bad_bool)
		_expect(not r["ok"], "%s no bool falla" % key)
		_expect(r["errors"].has(key + " no es bool"), "error bool: %s" % key)
	
	_case = "validate int numbers accepted"
	var int_profile = VrComfort.default_profile().duplicate(true)
	int_profile["smooth_turn_speed"] = 2
	int_profile["vignette_intensity"] = 1
	r = VrComfort.validate_profile(int_profile)
	_expect(r["ok"], "enteros aceptados: " + str(r["errors"]))
	
	_case = "canonical copy preserves structure"
	var canon = VrComfort.validate_profile(VrComfort.default_profile())
	_expect(canon["ok"], "canonical ok")
	_expect(canon["profile"].size() == VrComfort.PROFILE_KEYS.size(), "canonical tamaño")
	var orig = VrComfort.default_profile()
	for key in VrComfort.PROFILE_KEYS:
		_expect(canon["profile"][key] == orig[key], "canonical valor %s: %s vs %s" % [key, canon["profile"][key], orig[key]])


func _test_vr_settings_panel() -> void:
	_case = "VrSettingsPanel init without rig/settings"
	var panel = VrSettingsPanel.new()
	panel.init()
	_expect(panel.get_profile().size() == VrComfort.PROFILE_KEYS.size(), "perfil default cargado")
	
	_case = "set_value invalid key"
	_expect(not panel.set_value("no_existe", 1.0), "clave inexistente rechaza")
	
	_case = "set_value invalid value triggers default"
	var before = panel.get_profile().duplicate(true)
	_expect(not panel.set_value("turn_mode", "invalido"), "valor invalido rechaza")
	var after = panel.get_profile()
	_expect(after["turn_mode"] == "smooth", "revierte a default smooth")
	
	_case = "set_value valid updates and emits"
	var emitted = []
	panel.settings_changed.connect(func(k, v): emitted.append([k, v]))
	_expect(panel.set_value("smooth_turn_speed", 2.5), "set valido ok")
	_expect(panel.get_value("smooth_turn_speed") == 2.5, "valor actualizado")
	_expect(emitted.size() == 1, "signal emitido una vez")
	_expect(emitted[0][0] == "smooth_turn_speed" and emitted[0][1] == 2.5, "signal params correctos")
	
	_case = "get_value missing key"
	_expect(panel.get_value("no_existe") == null, "clave inexistente retorna null")
	
	_case = "apply_comfort_profile invalid"
	_expect(not panel.apply_comfort_profile("no_existe"), "preset inexistente falla")
	
	_case = "apply_comfort_profile valid"
	emitted = []
	panel.settings_changed.connect(func(k, v): emitted.append([k, v]))
	_expect(panel.apply_comfort_profile("comfort"), "preset comfort ok")
	_expect(panel.get_value("turn_mode") == "snap", "turn_mode snap")
	_expect(panel.get_value("snap_turn_degrees") == 45.0, "snap_turn_degrees 45")
	_expect(panel.get_value("teleport_enabled") == true, "teleport habilitado")
	_expect(emitted.size() == VrComfort.PROFILE_KEYS.size(), "emite todas las claves: %d" % emitted.size())
	
	_case = "presets have correct structure"
	var presets = panel._get_presets()
	for name in ["default", "comfort", "performance", "seated"]:
		_expect(presets.has(name), "tiene preset %s" % name)
		var p = presets[name]
		_expect(p["version"] == VrComfort.VERSION, "preset %s version" % name)
		var vr = VrComfort.validate_profile(p)
		_expect(vr["ok"], "preset %s valido: %s" % [name, vr["errors"]])


func _test_profile_persistence() -> void:
	_case = "GameSettings load/save cycle"
	var settings = GameSettings.new()
	settings.set_value("test_key", "test_value")
	settings.save()
	var settings2 = GameSettings.new()
	_expect(settings2.get_value("test_key") == "test_value", "persistencia basica")
	
	_case = "VrSettingsPanel loads from GameSettings"
	var settings3 = GameSettings.new()
	var vr_comfort_data = {"version": VrComfort.VERSION, "turn_mode": "snap", "snap_turn_degrees": 90.0}
	for key in VrComfort.PROFILE_KEYS:
		if not vr_comfort_data.has(key):
			vr_comfort_data[key] = VrComfort.default_profile()[key]
	settings3.set_value("vr_comfort", vr_comfort_data)
	settings3.save()
	
	var panel = VrSettingsPanel.new()
	panel.init(null, settings3)
	_expect(panel.get_value("turn_mode") == "snap", "carga turn_mode snap")
	_expect(panel.get_value("snap_turn_degrees") == 90.0, "carga snap_turn_degrees")
	
	_case = "VrSettingsPanel saves to GameSettings"
	panel.set_value("move_speed", 3.0)
	var saved = settings3.get_value("vr_comfort")
	_expect(saved["move_speed"] == 3.0, "guarda move_speed")
	
	_case = "VrSettingsPanel rejects invalid and restores"
	var bad_data = {"version": VrComfort.VERSION, "turn_mode": "bad"}
	for key in VrComfort.PROFILE_KEYS:
		if not bad_data.has(key):
			bad_data[key] = VrComfort.default_profile()[key]
	settings3.set_value("vr_comfort", bad_data)
	settings3.save()
	
	var panel2 = VrSettingsPanel.new()
	panel2.init(null, settings3)
	_expect(panel2.get_value("turn_mode") == "smooth", "restaura default ante invalido")


func _test_presets() -> void:
	_case = "default preset equals default_profile"
	var panel = VrSettingsPanel.new()
	panel.init()
	panel.apply_comfort_profile("default")
	var prof = panel.get_profile()
	var def = VrComfort.default_profile()
	for key in VrComfort.PROFILE_KEYS:
		_expect(prof[key] == def[key], "default preset %s: %s vs %s" % [key, prof[key], def[key]])
	
	_case = "comfort preset values"
	panel.apply_comfort_profile("comfort")
	_expect(panel.get_value("turn_mode") == "snap", "comfort turn_mode")
	_expect(panel.get_value("snap_turn_degrees") == 45.0, "comfort snap_degrees")
	_expect(panel.get_value("vignette_intensity") == 1.0, "comfort vignette max")
	_expect(panel.get_value("teleport_enabled") == true, "comfort teleport")
	
	_case = "performance preset values"
	panel.apply_comfort_profile("performance")
	_expect(panel.get_value("turn_mode") == "smooth", "perf turn_mode")
	_expect(panel.get_value("comfort_vignette_enabled") == false, "perf vignette off")
	_expect(panel.get_value("move_speed") == 2.5, "perf move_speed")
	
	_case = "seated preset values"
	panel.apply_comfort_profile("seated")
	_expect(panel.get_value("seated_mode") == true, "seated mode on")
	_expect(panel.get_value("height_offset") == -0.3, "seated height_offset")
	_expect(panel.get_value("teleport_enabled") == true, "seated teleport")


func _test_vignette_computation() -> void:
	_case = "compute_vignette zero speeds"
	var v = VrComfort.compute_vignette(0.0, 0.0)
	_expect(is_equal_approx(v, 0.0), "velocidad cero => 0")
	
	_case = "compute_vignette linear only"
	v = VrComfort.compute_vignette(3.0, 0.0, 3.0, 2.0, 1.0)
	_expect(is_equal_approx(v, 1.0), "velocidad lineal = ref => 1.0")
	
	v = VrComfort.compute_vignette(1.5, 0.0, 3.0, 2.0, 1.0)
	_expect(is_equal_approx(v, 0.5), "velocidad lineal = ref/2 => 0.5")
	
	_case = "compute_vignette angular only"
	v = VrComfort.compute_vignette(0.0, 2.0, 3.0, 2.0, 1.0)
	_expect(is_equal_approx(v, 1.0), "velocidad angular = ref => 1.0")
	
	v = VrComfort.compute_vignette(0.0, 1.0, 3.0, 2.0, 1.0)
	_expect(is_equal_approx(v, 0.5), "velocidad angular = ref/2 => 0.5")
	
	_case = "compute_vignette both speeds max"
	v = VrComfort.compute_vignette(3.0, 2.0, 3.0, 2.0, 1.0)
	_expect(is_equal_approx(v, 1.0), "ambas en ref => 1.0")
	
	_case = "compute_vignette intensity scales"
	v = VrComfort.compute_vignette(3.0, 0.0, 3.0, 2.0, 0.5)
	_expect(is_equal_approx(v, 0.5), "intensity 0.5 escala resultado")
	
	_case = "compute_vignette clamps at 1.0"
	v = VrComfort.compute_vignette(100.0, 100.0, 3.0, 2.0, 1.0)
	_expect(is_equal_approx(v, 1.0), "sobrepasa ref => clampeado a 1.0")
	
	_case = "compute_vignette zero ref protection"
	v = VrComfort.compute_vignette(1.0, 1.0, 0.0, 0.0, 1.0)
	_expect(is_equal_approx(v, 1.0), "ref cero protegido => 1.0")


func _test_turn_delta() -> void:
	_case = "turn_delta mode off"
	var d = VrComfort.turn_delta(1.0, "off", 1.0, 30.0, 0.016)
	_expect(is_equal_approx(d, 0.0), "mode off => 0")
	
	_case = "turn_delta zero delta"
	d = VrComfort.turn_delta(1.0, "smooth", 1.0, 30.0, 0.0)
	_expect(is_equal_approx(d, 0.0), "delta 0 => 0")
	
	_case = "turn_delta deadzone"
	d = VrComfort.turn_delta(0.1, "smooth", 1.0, 30.0, 0.016, 0.2)
	_expect(is_equal_approx(d, 0.0), "dentro deadzone => 0")
	
	_case = "turn_delta snap mode"
	d = VrComfort.turn_delta(0.8, "snap", 1.0, 30.0, 0.016, 0.2, true, 0.7)
	_expect(d < 0.0, "snap derecha => negativo")
	_expect(is_equal_approx(abs(d), deg_to_rad(30.0)), "snap grados exactos: %s" % rad_to_deg(abs(d)))
	
	d = VrComfort.turn_delta(-0.8, "snap", 1.0, 30.0, 0.016, 0.2, true, 0.7)
	_expect(d > 0.0, "snap izquierda => positivo")
	_expect(is_equal_approx(abs(d), deg_to_rad(30.0)), "snap grados exactos izq")
	
	_case = "turn_delta snap below threshold"
	d = VrComfort.turn_delta(0.5, "snap", 1.0, 30.0, 0.016, 0.2, true, 0.7)
	_expect(is_equal_approx(d, 0.0), "bajo threshold => 0")
	
	_case = "turn_delta snap can_step false"
	d = VrComfort.turn_delta(0.8, "snap", 1.0, 30.0, 0.016, 0.2, false, 0.7)
	_expect(is_equal_approx(d, 0.0), "can_step false => 0")
	
	_case = "turn_delta smooth mode"
	d = VrComfort.turn_delta(1.0, "smooth", 1.0, 30.0, 0.016, 0.2)
	_expect(d < 0.0, "smooth derecha => negativo")
	var expected = (1.0 - 0.2) / (1.0 - 0.2) * 1.0 * 0.016
	_expect(is_equal_approx(abs(d), expected), "smooth calculo: %s vs %s" % [abs(d), expected])
	
	_case = "turn_delta smooth partial stick"
	d = VrComfort.turn_delta(0.6, "smooth", 1.0, 30.0, 0.016, 0.2)
	var span = 1.0 - 0.2
	var amount = (0.6 - 0.2) / span
	expected = amount * 1.0 * 0.016
	_expect(is_equal_approx(abs(d), expected), "smooth parcial: %s vs %s" % [abs(d), expected])
	
	_case = "turn_delta smooth deadzone 1.0"
	d = VrComfort.turn_delta(0.9, "smooth", 1.0, 30.0, 0.016, 1.0)
	_expect(is_equal_approx(d, 0.0), "deadzone 1.0 => 0")
	
	_case = "turn_delta smooth deadzone 0.0"
	d = VrComfort.turn_delta(0.5, "smooth", 2.0, 30.0, 0.016, 0.0)
	expected = 0.5 * 2.0 * 0.016
	_expect(is_equal_approx(abs(d), expected), "deadzone 0 => escala completa: %s vs %s" % [abs(d), expected])


func _test_locomotion_velocity() -> void:
	_case = "locomotion_velocity zero stick"
	var v = VrComfort.locomotion_velocity(Vector2.ZERO, Vector3.FORWARD, 2.0)
	_expect(v == Vector3.ZERO, "stick cero => Vector3.ZERO")
	
	_case = "locomotion_velocity deadzone"
	v = VrComfort.locomotion_velocity(Vector2(0.1, 0.0), Vector3.FORWARD, 2.0, 0.2)
	_expect(v == Vector3.ZERO, "dentro deadzone => Vector3.ZERO")
	
	_case = "locomotion_velocity zero forward"
	v = VrComfort.locomotion_velocity(Vector2(0.5, 0.0), Vector3.ZERO, 2.0)
	_expect(v == Vector3.ZERO, "forward cero => Vector3.ZERO")
	
	_case = "locomotion_velocity forward only"
	var forward = Vector3(0.0, 0.0, -1.0)
	v = VrComfort.locomotion_velocity(Vector2(0.0, 1.0), forward, 2.0)
	_expect(v.z < 0.0, "stick Y positivo => avanza -Z (forward vector)")
	_expect(is_equal_approx(abs(v.z), 2.0), "velocidad completa: %s" % abs(v.z))
	
	_case = "locomotion_velocity right only"
	v = VrComfort.locomotion_velocity(Vector2(1.0, 0.0), forward, 2.0)
	_expect(v.x > 0.0, "stick X positivo => derecha +X")
	_expect(is_equal_approx(v.x, 2.0), "velocidad completa X: %s" % v.x)
	
	_case = "locomotion_velocity diagonal"
	v = VrComfort.locomotion_velocity(Vector2(1.0, 1.0), forward, 2.0)
	var expected_len = sqrt(2.0) * 2.0
	_expect(is_equal_approx(v.length(), expected_len), "diagonal longitud: %s vs %s" % [v.length(), expected_len])
	
	_case = "locomotion_velocity angled forward"
	var angled = Vector3(sqrt(2.0)/2.0, 0.0, -sqrt(2.0)/2.0).normalized()
	v = VrComfort.locomotion_velocity(Vector2(0.0, 1.0), angled, 2.0)
	_expect(v.length() > 0.0, "forward inclinado produce movimiento")
	
	_case = "locomotion_velocity negative speed"
	v = VrComfort.locomotion_velocity(Vector2(0.0, 1.0), forward, -2.0)
	_expect(v == Vector3.ZERO, "velocidad negativa => Vector3.ZERO (maxf)")


func _test_teleport_and_seated() -> void:
	_case = "translation_for_teleport horizontal only"
	var xform = Transform3D.IDENTITY.translated(Vector3(0.0, 1.65, 0.0))
	var head = Vector3(0.0, 1.65, 0.0)
	var target = Vector3(2.0, 1.65, 3.0)
	var result = VrComfort.translation_for_teleport(xform, head, target)
	_expect(result.origin.x == 2.0, "teleport X aplicado: %s" % result.origin.x)
	_expect(is_equal_approx(result.origin.y, 1.65), "teleport Y preservado: %s" % result.origin.y)
	_expect(result.origin.z == 3.0, "teleport Z aplicado: %s" % result.origin.z)
	
	_case = "translation_for_teleport ignores vertical"
	target = Vector3(1.0, 5.0, 1.0)
	result = VrComfort.translation_for_teleport(xform, head, target)
	_expect(result.origin.x == 1.0, "teleport X: %s" % result.origin.x)
	_expect(is_equal_approx(result.origin.y, 1.65), "teleport ignora Y del target: %s" % result.origin.y)
	_expect(result.origin.z == 1.0, "teleport Z: %s" % result.origin.z)
	
	_case = "apply_seated_height zero offset"
	var pos = Vector3(1.0, 1.65, 2.0)
	var result_pos = VrComfort.apply_seated_height(pos, 0.0)
	_expect(result_pos == pos, "offset cero sin cambio")
	
	_case = "apply_seated_height positive offset"
	result_pos = VrComfort.apply_seated_height(pos, 0.2)
	_expect(is_equal_approx(result_pos.y, 1.85), "offset positivo: %s" % result_pos.y)
	_expect(result_pos.x == pos.x and result_pos.z == pos.z, "XZ preservados")
	
	_case = "apply_seated_height negative offset"
	result_pos = VrComfort.apply_seated_height(pos, -0.3)
	_expect(is_equal_approx(result_pos.y, 1.35), "offset negativo: %s" % result_pos.y)


func _test_rotation_helpers() -> void:
	_case = "rotate_around_y zero yaw"
	var xform = Transform3D.IDENTITY.translated(Vector3(1.0, 2.0, 3.0))
	var pivot = Vector3(0.0, 0.0, 0.0)
	var result = VrComfort.rotate_around_y(xform, pivot, 0.0)
	_expect(result == xform, "yaw cero sin cambio")
	
	_case = "rotate_around_y 90 deg (Godot: +Y rotates X->Z, Z->-X)"
	var yaw = deg_to_rad(90.0)
	result = VrComfort.rotate_around_y(xform, pivot, yaw)
	_expect(is_equal_approx(result.origin.x, 3.0), "rotado 90 X: %s (X'=Z)" % result.origin.x)
	_expect(is_equal_approx(result.origin.z, -1.0), "rotado 90 Z: %s (Z'=-X)" % result.origin.z)
	
	_case = "rotate_around_y non-zero pivot"
	pivot = Vector3(1.0, 0.0, 1.0)
	xform = Transform3D.IDENTITY.translated(Vector3(2.0, 0.0, 2.0))
	result = VrComfort.rotate_around_y(xform, pivot, yaw)
	_expect(is_equal_approx(result.origin.x, 2.0), "pivot rotado X: %s" % result.origin.x)
	_expect(is_equal_approx(result.origin.z, 0.0), "pivot rotado Z: %s" % result.origin.z)
	
	_case = "rotate_around_y preserves basis rotation"
	var basis = Basis().rotated(Vector3.UP, deg_to_rad(45.0))
	xform = Transform3D(basis, Vector3(1.0, 0.0, 0.0))
	result = VrComfort.rotate_around_y(xform, pivot, yaw)
	var expected_basis = Basis().rotated(Vector3.UP, yaw + deg_to_rad(45.0))
	_expect(is_equal_approx(result.basis.get_euler().y, expected_basis.get_euler().y), "basis acumula rotacion: %s vs %s" % [result.basis.get_euler().y, expected_basis.get_euler().y])


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_case, message])