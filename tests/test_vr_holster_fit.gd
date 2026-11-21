extends SceneTree

var CalScript = load("res://core/vr/vr_calibration.gd")
var HolsterScript = load("res://core/vr/vr_holsters.gd")

var _n := 0
var _fail := 0
var _case: String = ""
const PATH := "user://test_vr_holster_fit.json"


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _t(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


func _initialize() -> void:
	await process_frame
	_test_proportional_offsets()
	_test_hip_lower_than_before()
	_test_glow_zones_follow_positions()
	DirAccess.remove_absolute(PATH)
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)


# Prueba 1: offsets proporcionales a eye_height para alturas 1.45, 1.65, 1.85
func _test_proportional_offsets() -> void:
	_case = "offsets proporcionales a eye_height"
	
	# Altura 1.45 m
	var cal_short = CalScript.new()
	cal_short.profile_path = PATH
	cal_short.profile["eye_height"] = 1.45
	cal_short.profile["arm_reach"] = 0.65
	cal_short.profile["dominant_hand"] = "right"
	cal_short.profile["hip"] = [0.18, -0.36, 0.02]
	cal_short.profile["version"] = 1
	var offsets_short = cal_short.slot_offsets()
	
	# Altura 1.65 m (default)
	var cal_mid = CalScript.new()
	cal_mid.profile_path = PATH
	cal_mid.profile["eye_height"] = 1.65
	cal_mid.profile["arm_reach"] = 0.70
	cal_mid.profile["dominant_hand"] = "right"
	cal_mid.profile["hip"] = [0.18, -0.36, 0.02]
	cal_mid.profile["version"] = 1
	var offsets_mid = cal_mid.slot_offsets()
	
	# Altura 1.85 m
	var cal_tall = CalScript.new()
	cal_tall.profile_path = PATH
	cal_tall.profile["eye_height"] = 1.85
	cal_tall.profile["arm_reach"] = 0.75
	cal_tall.profile["dominant_hand"] = "right"
	cal_tall.profile["hip"] = [0.18, -0.36, 0.02]
	cal_tall.profile["version"] = 1
	var offsets_tall = cal_tall.slot_offsets()
	
	# Verificar hip: y = -0.40 * eye_height
	_expect(is_equal_approx(offsets_short["hip"].y, -0.40 * 1.45), "short hip.y = -0.40*1.45 = %s" % (-0.40 * 1.45))
	_expect(is_equal_approx(offsets_mid["hip"].y, -0.40 * 1.65), "mid hip.y = -0.40*1.65 = %s" % (-0.40 * 1.65))
	_expect(is_equal_approx(offsets_tall["hip"].y, -0.40 * 1.85), "tall hip.y = -0.40*1.85 = %s" % (-0.40 * 1.85))
	
	# Verificar hip2: igual que hip en y, opuesto en x
	_expect(is_equal_approx(offsets_short["hip2"].y, -0.40 * 1.45), "short hip2.y = -0.40*1.45")
	_expect(is_equal_approx(offsets_mid["hip2"].y, -0.40 * 1.65), "mid hip2.y = -0.40*1.65")
	_expect(is_equal_approx(offsets_tall["hip2"].y, -0.40 * 1.85), "tall hip2.y = -0.40*1.85")
	_expect(offsets_short["hip2"].x < 0 and offsets_short["hip"].x > 0, "hip2.x negativo, hip.x positivo")
	
	# Verificar chest: y = -0.15 * eye_height
	_expect(is_equal_approx(offsets_short["chest"].y, -0.15 * 1.45), "short chest.y = -0.15*1.45")
	_expect(is_equal_approx(offsets_mid["chest"].y, -0.15 * 1.65), "mid chest.y = -0.15*1.65")
	_expect(is_equal_approx(offsets_tall["chest"].y, -0.15 * 1.85), "tall chest.y = -0.15*1.85")
	
	# Verificar back: y = 0.08 * eye_height (altura cuello/hombro detras)
	_expect(is_equal_approx(offsets_short["back"].y, 0.08 * 1.45), "short back.y = 0.08*1.45")
	_expect(is_equal_approx(offsets_mid["back"].y, 0.08 * 1.65), "mid back.y = 0.08*1.65")
	_expect(is_equal_approx(offsets_tall["back"].y, 0.08 * 1.85), "tall back.y = 0.08*1.85")
	
	# Verificar bag: y = -0.38 * eye_height (cadera trasera)
	_expect(is_equal_approx(offsets_short["bag"].y, -0.38 * 1.45), "short bag.y = -0.38*1.45")
	_expect(is_equal_approx(offsets_mid["bag"].y, -0.38 * 1.65), "mid bag.y = -0.38*1.65")
	_expect(is_equal_approx(offsets_tall["bag"].y, -0.38 * 1.85), "tall bag.y = -0.38*1.85")
	
	# Verificar ancho lateral hip = 0.20 * eye_height
	_expect(is_equal_approx(absf(offsets_short["hip"].x), 0.20 * 1.45), "short hip ancho lateral = 0.20*1.45")
	_expect(is_equal_approx(absf(offsets_mid["hip"].x), 0.20 * 1.65), "mid hip ancho lateral = 0.20*1.65")
	_expect(is_equal_approx(absf(offsets_tall["hip"].x), 0.20 * 1.85), "tall hip ancho lateral = 0.20*1.85")


# Prueba 2: cadera de verdad mas baja que antes (comparar con offsets fijos antiguos)
func _test_hip_lower_than_before() -> void:
	_case = "cadera mas baja que offsets fijos antiguos"
	
	# Offsets fijos antiguos: hip.y = -0.36 (fijo, no escala)
	# Offsets nuevos: hip.y = -0.40 * eye_height
	
	# Para 1.65 m: nuevo = -0.66, antiguo = -0.36 -> nuevo mas bajo (mas negativo)
	var cal = CalScript.new()
	cal.profile["eye_height"] = 1.65
	cal.profile["arm_reach"] = 0.70
	cal.profile["dominant_hand"] = "right"
	cal.profile["hip"] = [0.18, -0.36, 0.02]
	cal.profile["version"] = 1
	var offsets = cal.slot_offsets()
	
	_expect(offsets["hip"].y < -0.36, "nueva cadera (1.65m) y=%s mas baja que antigua fija -0.36" % offsets["hip"].y)
	_expect(is_equal_approx(offsets["hip"].y, -0.40 * 1.65), "nueva cadera = -0.40 * 1.65 = -0.66")
	
	# Para 1.45 m: nuevo = -0.58, antiguo = -0.36 -> nuevo mas bajo
	cal.profile["eye_height"] = 1.45
	offsets = cal.slot_offsets()
	_expect(offsets["hip"].y < -0.36, "nueva cadera (1.45m) y=%s mas baja que antigua fija -0.36" % offsets["hip"].y)
	_expect(is_equal_approx(offsets["hip"].y, -0.40 * 1.45), "nueva cadera = -0.40 * 1.45 = -0.58")
	
	# Para 1.85 m: nuevo = -0.74, antiguo = -0.36 -> nuevo mas bajo
	cal.profile["eye_height"] = 1.85
	offsets = cal.slot_offsets()
	_expect(offsets["hip"].y < -0.36, "nueva cadera (1.85m) y=%s mas baja que antigua fija -0.36" % offsets["hip"].y)
	_expect(is_equal_approx(offsets["hip"].y, -0.40 * 1.85), "nueva cadera = -0.40 * 1.85 = -0.74")


# Prueba 3: siluetas/zonas iluminadas (glow) siguen las posiciones nuevas
func _test_glow_zones_follow_positions() -> void:
	_case = "zonas glow siguen posiciones nuevas"
	
	# Crear holsters calibradas para 1.65m usando VrHolsters directamente
	var holsters = HolsterScript.new()
	holsters.set_head_pose(_t(0, 1.65, 0))
	holsters.set_eye_height(1.65)
	
	# Obtener posicion de hip
	var hip_pos = holsters.slot_position("hip")
	var expected_hip_y = 1.65 + (-0.40 * 1.65)  # head.y + hip_offset.y = 1.65 - 0.66 = 0.99
	
	# Verificar que la posicion mundial de hip coincide con la esperada
	_expect(is_equal_approx(hip_pos.y, expected_hip_y), "hip world y = %s (esperado %s)" % [hip_pos.y, expected_hip_y])
	
	# Verificar glow_info usa las posiciones escaladas
	var glow = holsters.get_glow_info(_t(hip_pos.x, hip_pos.y, hip_pos.z), 0.0)
	_expect(bool(glow["hip"]["visible"]), "glow hip visible cuando la mano esta en la funda")
	_expect(glow["hip"]["distance"] < 0.01, "distancia glow hip ~0 cuando mano en funda")
	
	# Probar con altura 1.45m
	holsters = HolsterScript.new()
	holsters.set_head_pose(_t(0, 1.45, 0))
	holsters.set_eye_height(1.45)
	hip_pos = holsters.slot_position("hip")
	expected_hip_y = 1.45 + (-0.40 * 1.45)  # 1.45 - 0.58 = 0.87
	_expect(is_equal_approx(hip_pos.y, expected_hip_y), "hip world y (1.45m) = %s" % hip_pos.y)
	
	# Probar con altura 1.85m
	holsters = HolsterScript.new()
	holsters.set_head_pose(_t(0, 1.85, 0))
	holsters.set_eye_height(1.85)
	hip_pos = holsters.slot_position("hip")
	expected_hip_y = 1.85 + (-0.40 * 1.85)  # 1.85 - 0.74 = 1.11
	_expect(is_equal_approx(hip_pos.y, expected_hip_y), "hip world y (1.85m) = %s" % hip_pos.y)
	
	# Verificar radio tambien escala con eye_height
	holsters = HolsterScript.new()
	holsters.set_head_pose(_t(0, 1.45, 0))
	holsters.set_eye_height(1.45)
	_expect(is_equal_approx(holsters.slot_radius("hip"), 0.20 * 1.45), "radio hip escala con eye_height (1.45m)")
	
	holsters = HolsterScript.new()
	holsters.set_head_pose(_t(0, 1.85, 0))
	holsters.set_eye_height(1.85)
	_expect(is_equal_approx(holsters.slot_radius("hip"), 0.20 * 1.85), "radio hip escala con eye_height (1.85m)")