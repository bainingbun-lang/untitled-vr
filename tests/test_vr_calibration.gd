extends SceneTree

const CalScript = preload("res://core/vr/vr_calibration.gd")
const BagScript = preload("res://core/vr/vr_bag.gd")
const HolsterScript = preload("res://core/vr/vr_holsters.gd")

var _n := 0
var _fail := 0
const PATH := "user://test_vr_calibration_profile.json"


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _t(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


func _initialize() -> void:
	await process_frame
	_defaults()
	_guided()
	_holsters_and_bag()
	_persistence()
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)


func _guided_run(cal, eye: float, reach: float, hip_hand: String = "right") -> void:
	cal.begin_guided()
	cal.record(_t(0, eye, 0), _t(-0.2, eye - 0.7, 0.0), _t(0.2, eye - 0.7, 0.0))
	cal.record(_t(0, eye, 0), _t(-reach, eye - 0.3, 0.0), _t(reach, eye - 0.3, 0.0))
	var side := 0.2 if hip_hand == "right" else -0.2
	var hip := _t(side, eye - 0.9, 0.0)
	cal.record(_t(0, eye, 0), hip, hip, hip_hand)


func _defaults() -> void:
	var cal = CalScript.new()
	_expect(cal.eye_height() == 1.65 and cal.dominant_hand() == "right" and cal.arm_reach() == 0.7, "defaults razonables")
	_expect(CalScript.validate(cal.profile) == "", "el perfil por defecto es valido")
	var offsets: Dictionary = cal.slot_offsets()
	_expect(offsets["hip"].is_equal_approx(HolsterScript.SLOTS["hip"]["offset"]), "defaults = fundas originales")
	var bad: Array = [null, {}, {"version": 1}, _with("eye_height", 5.0), _with("eye_height", NAN), _with("arm_reach", 0.1),
		_with("dominant_hand", "centro"), _with("hip", [0, 0]), _with("hip", [0, 0, 9.0]), _with("version", 2), _with("eye_height", "1.7")]
	var all_rejected := true
	for item in bad:
		if CalScript.validate(item) == "":
			all_rejected = false
	_expect(all_rejected, "validacion estricta rechaza datos malos")
	_expect(not cal.set_profile(_with("eye_height", 9.0)) and cal.eye_height() == 1.65, "set_profile invalido no cambia nada")


func _with(key: String, value) -> Dictionary:
	var d: Dictionary = CalScript.default_profile()
	d[key] = value
	return d


func _guided() -> void:
	var cal = CalScript.new()
	var steps: Array = []
	var done := [0]
	cal.step_changed.connect(func(s): steps.append(s))
	cal.completed.connect(func(_p): done[0] += 1)
	_expect(cal.current_step() == "", "sin calibracion activa")
	_expect(not bool(cal.record(_t(0, 1.7, 0), _t(0, 1, 0), _t(0, 1, 0))["ok"]), "no registra sin iniciar")
	cal.begin_guided()
	_expect(cal.current_step() == "arms_down", "paso 1")
	_expect(not bool(cal.record(_t(0, 1.7, 0), _t(-0.2, 1.6, 0), _t(0.2, 1.6, 0))["ok"]), "brazos arriba rechazados")
	_expect(cal.current_step() == "arms_down", "se queda en el paso 1")
	_expect(bool(cal.record(_t(0, 1.8, 0), _t(-0.2, 1.1, 0), _t(0.2, 1.1, 0))["ok"]), "paso 1 ok")
	_expect(cal.current_step() == "arms_extended", "paso 2")
	_expect(not bool(cal.record(_t(0, 1.8, 0), _t(-0.1, 1.5, 0), _t(0.1, 1.5, 0))["ok"]), "brazos sin extender rechazados")
	_expect(bool(cal.record(_t(0, 1.8, 0), _t(-0.78, 1.5, 0), _t(0.82, 1.5, 0))["ok"]), "paso 2 ok")
	_expect(cal.current_step() == "hand_hip", "paso 3")
	_expect(not bool(cal.record(_t(0, 1.8, 0), _t(0, 1.8, -0.3), _t(0, 1.8, -0.3), "right")["ok"]), "mano lejos de la cadera rechazada")
	_expect(not bool(cal.record(_t(0, 1.8, 0), _t(0, 0.9, 0), _t(0, 0.9, 0), "ambas")["ok"]), "mano invalida")
	_expect(bool(cal.record(_t(0, 1.8, 0), _t(-0.2, 0.95, 0.03), _t(0.2, 0.95, 0.03), "left")["ok"]), "paso 3 ok")
	_expect(done[0] == 1 and cal.current_step() == "", "completado")
	_expect(is_equal_approx(cal.eye_height(), 1.8) and is_equal_approx(cal.arm_reach(), 0.8), "altura y alcance medidos")
	_expect(cal.dominant_hand() == "left", "mano dominante = la de la cadera")
	_expect(steps == ["arms_down", "arms_extended", "hand_hip"], "senales de paso: %s" % str(steps))
	var hip: Vector3 = cal.slot_offsets()["hip"]
	_expect(hip.is_equal_approx(Vector3(-0.2, -0.85, 0.03)), "funda de cadera medida en el cuerpo real: %s" % str(hip))
	cal.begin_guided()
	cal.cancel_guided()
	_expect(cal.current_step() == "" and is_equal_approx(cal.eye_height(), 1.8), "cancelar conserva el perfil")


func _holsters_and_bag() -> void:
	var tall = CalScript.new()
	_guided_run(tall, 1.95, 0.9)
	var short = CalScript.new()
	_guided_run(short, 1.45, 0.6)
	var a: Vector3 = tall.slot_offsets()["chest"]
	var b: Vector3 = short.slot_offsets()["chest"]
	_expect(a.y < b.y and absf(a.z) > absf(b.z), "las fundas escalan con el cuerpo")
	var holsters = tall.make_holsters()
	holsters.set_head_pose(Transform3D(Basis.IDENTITY, Vector3(0, 1.95, 0)))
	var hip_world: Vector3 = holsters.slot_position("hip")
	_expect(hip_world.is_equal_approx(Vector3(0, 1.95, 0) + tall.slot_offsets()["hip"]), "VrHolsters calibradas usan los offsets")
	_expect(holsters.nearest_slot(Transform3D(Basis.IDENTITY, hip_world))["slot"] == "hip", "nearest_slot encuentra la funda calibrada")
	_expect(holsters.slot_radius("hip") > 0.0 and holsters.slot_position("nada") == holsters.head_transform.origin, "compatibilidad con VrHolsters")
	var bag = BagScript.new()
	tall.apply_to_bag(bag)
	_expect(bag.bag_down > 0.40 and bag.bag_side > 0.28, "bolso escala con el cuerpo")
	var lefty = CalScript.new()
	_guided_run(lefty, 1.7, 0.7, "left")
	var bag2 = BagScript.new()
	lefty.apply_to_bag(bag2)
	_expect(bag2.bag_side < 0.0, "zurdo: bolso al lado izquierdo")
	_expect(lefty.slot_offsets()["back"].x <= 0.0, "zurdo: fundas espejadas")


func _persistence() -> void:
	var cal = CalScript.new()
	cal.profile_path = PATH
	_guided_run(cal, 1.72, 0.74)
	_expect(cal.save(), "guardar perfil")
	var other = CalScript.new()
	other.profile_path = PATH
	_expect(other.load_profile() and other.last_status == "ok", "cargar perfil")
	_expect(is_equal_approx(other.eye_height(), 1.72) and other.dominant_hand() == "right", "perfil restaurado")
	_expect(other.slot_offsets()["hip"].is_equal_approx(cal.slot_offsets()["hip"]), "fundas restauradas")
	for text in ["{{no json", "[1,2]", "{\"version\":1,\"eye_height\":99,\"arm_reach\":0.7,\"dominant_hand\":\"right\",\"hip\":[0,0,0]}", ""]:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		var c = CalScript.new()
		c.profile_path = PATH
		_expect(not c.load_profile() and c.eye_height() == 1.65 and c.last_status.begins_with("corrupto"), "corrupto -> defaults: %s" % c.last_status)
	DirAccess.remove_absolute(PATH)
	var missing = CalScript.new()
	missing.profile_path = PATH
	_expect(not missing.load_profile() and missing.last_status == "ausente" and missing.eye_height() == 1.65, "ausente -> defaults")
