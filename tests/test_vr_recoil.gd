extends SceneTree

const RecoilScript = preload("res://core/vr/vr_recoil.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _initialize() -> void:
	await process_frame
	_test_single_shot_return()
	_test_climb_recovery()
	_test_burst_cap()
	_test_two_hand_reduction()
	_test_shotgun_stronger_than_pistol()
	_test_seed_determinism()
	_test_haptics()
	_test_aim_deviation()
	_test_extreme_delta()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_single_shot_return() -> void:
	_case = "un disparo desplaza y vuelve al reposo"
	var recoil = RecoilScript.new()
	recoil.set_seed(11)
	recoil.on_fired("pistol")
	for i in 4:
		recoil.step(1.0 / 120.0)
	_expect(recoil.weapon_offset().origin.z > 0.0, "la patada va hacia atras del canon")
	_expect(recoil.kick().z > 0.0, "el desplazamiento trasero es positivo")
	for i in 240:
		recoil.step(1.0 / 60.0)
	_expect(recoil.kick().length() < 0.002, "el amortiguador devuelve el arma al reposo")
	_expect(recoil.weapon_offset().origin.length() < 0.002, "el offset del modelo vuelve a cero")


func _test_climb_recovery() -> void:
	_case = "el climb sube y se recupera"
	var recoil = RecoilScript.new()
	recoil.set_seed(12)
	recoil.on_fired("assault_rifle")
	var peak: float = recoil.pitch()
	_expect(peak > 0.0, "el disparo genera muzzle climb")
	for i in 12:
		recoil.step(1.0 / 120.0)
	_expect(recoil.pitch() > 0.0 and recoil.pitch() < peak, "el climb decae sin anularse de golpe")
	recoil.end_burst()
	for i in 240:
		recoil.step(1.0 / 60.0)
	_expect(recoil.pitch() < 0.001, "el climb vuelve a cero tras soltar")
	_expect(recoil.yaw() < 0.001 and recoil.yaw() > -0.001, "el componente lateral vuelve a cero")


func _test_burst_cap() -> void:
	_case = "rafaga acumula con tope"
	var recoil = RecoilScript.new()
	recoil.set_seed(13)
	recoil.on_fired("assault_rifle")
	var first: float = recoil.pitch()
	for i in 40:
		recoil.on_fired("assault_rifle")
		recoil.step(0.008)
	_expect(recoil.pitch() > first, "la rafaga acumula climb")
	_expect(recoil.pitch() <= 0.160001, "el climb acumulado tiene tope")
	_expect(absf(recoil.yaw()) <= 0.160001, "el lateral acumulado tiene tope")
	recoil.end_burst()
	for i in 120:
		recoil.step(1.0 / 60.0)
	_expect(recoil.pitch() < first * 0.5, "la rafaga se recupera al soltar")


func _test_two_hand_reduction() -> void:
	_case = "dos manos reducen el retroceso"
	var one_hand = RecoilScript.new()
	var two_hands = RecoilScript.new()
	one_hand.set_seed(14)
	two_hands.set_seed(14)
	one_hand.on_fired("assault_rifle", false)
	two_hands.on_fired("assault_rifle", true)
	for i in 5:
		one_hand.step(1.0 / 120.0)
		two_hands.step(1.0 / 120.0)
	_expect(two_hands.pitch() < one_hand.pitch(), "apuntar a dos manos reduce el climb")
	_expect(two_hands.kick().z < one_hand.kick().z, "apuntar a dos manos reduce la patada")
	_expect(two_hands.is_two_handed(), "se registra el apuntado a dos manos")
	var pistol_one = RecoilScript.new()
	var pistol_two = RecoilScript.new()
	pistol_one.on_fired("pistol", false)
	pistol_two.on_fired("pistol", true)
	var rifle_ratio: float = two_hands.pitch() / maxf(one_hand.pitch(), 0.000001)
	var pistol_ratio: float = pistol_two.pitch() / maxf(pistol_one.pitch(), 0.000001)
	_expect(rifle_ratio < pistol_ratio, "la reduccion es mayor en rifle que en pistola")
	for i in 30:
		one_hand.step(1.0 / 60.0)
		two_hands.step(1.0 / 60.0)
	_expect(two_hands.pitch() <= one_hand.pitch() + 0.000001, "la rafaga se corta antes a dos manos")


func _test_shotgun_stronger_than_pistol() -> void:
	_case = "escopeta con mas patada que pistola"
	var shotgun = RecoilScript.new()
	var pistol = RecoilScript.new()
	var shotgun_shot: Dictionary = shotgun.on_fired("shotgun")
	var pistol_shot: Dictionary = pistol.on_fired("pistol")
	_expect(float(shotgun_shot["energy"]) > float(pistol_shot["energy"]), "mas energia por calibre")
	_expect(float(shotgun_shot["caliber"]) > float(pistol_shot["caliber"]), "el calibre escala la fuerza")
	for i in 5:
		shotgun.step(1.0 / 120.0)
		pistol.step(1.0 / 120.0)
	_expect(shotgun.kick().z > pistol.kick().z, "la patada fisica de la escopeta es mayor")


func _test_seed_determinism() -> void:
	_case = "determinismo por semilla"
	var left = RecoilScript.new()
	var right = RecoilScript.new()
	left.set_seed(4242)
	right.set_seed(4242)
	for id in ["assault_rifle", "pistol", "shotgun"]:
		left.on_fired(id)
		right.on_fired(id)
		left.step(0.01)
		right.step(0.01)
	_expect(_vec_close(left.aim_direction(Vector3.FORWARD), right.aim_direction(Vector3.FORWARD)), "misma semilla, misma direccion de punteria")
	_expect(_vec_close(left.kick(), right.kick()), "misma semilla, misma patada")
	_expect(_transform_close(left.weapon_offset(), right.weapon_offset()), "misma semilla, mismo offset del modelo")
	_expect(_events_close(left.haptic_events(), right.haptic_events()), "misma semilla, mismos hapticos")
	var other = RecoilScript.new()
	other.set_seed(99)
	other.on_fired("shotgun")
	_expect(absf(other.yaw() - left.yaw()) > 0.000001 or absf(other.pitch() - left.pitch()) > 0.000001, "semillas distintas producen patrones distintos")


func _test_haptics() -> void:
	_case = "hapticos proporcionales"
	var pistol = RecoilScript.new()
	var shotgun = RecoilScript.new()
	var smg = RecoilScript.new()
	pistol.on_fired("pistol")
	shotgun.on_fired("shotgun")
	smg.on_fired("submachine_gun")
	var pistol_events: Array = pistol.haptic_events()
	var shotgun_events: Array = shotgun.haptic_events()
	var smg_events: Array = smg.haptic_events()
	_expect(pistol_events.size() >= 1, "la pistola genera un pulso")
	_expect(shotgun_events[0]["amplitude"] > pistol_events[0]["amplitude"], "la escopeta vibra mas fuerte")
	_expect(shotgun_events[0]["duration"] < pistol_events[0]["duration"], "la escopeta vibra mas corto")
	_expect(smg_events.size() >= 3, "el subfusil repite pulsos suaves")
	_expect(float(smg_events[0]["amplitude"]) < float(pistol_events[0]["amplitude"]), "el subfusil vibra mas suave")
	_expect(pistol_events[0]["hand"] == "right", "el pulso principal va a la mano que dispara")
	for event in pistol_events + shotgun_events + smg_events:
		_expect(float(event["amplitude"]) > 0.0 and float(event["amplitude"]) <= 1.0, "amplitud valida")
		_expect(float(event["duration"]) > 0.0, "duracion valida")
	var two_hands = RecoilScript.new()
	two_hands.on_fired("pistol", true)
	var events: Array = two_hands.haptic_events()
	_expect(events.size() == 2, "a dos manos hay pulso secundario")
	_expect(events[1]["hand"] == "left", "el pulso secundario va a la mano de apoyo")


func _test_aim_deviation() -> void:
	_case = "direccion de punteria desviada"
	var recoil = RecoilScript.new()
	recoil.set_seed(55)
	var base := Vector3.FORWARD
	_expect(_vec_close(recoil.aim_direction(base), base), "sin disparo no hay desviacion")
	recoil.on_fired("shotgun")
	var aim: Vector3 = recoil.aim_direction(base)
	_expect(aim.y > base.y + 0.01, "el climb eleva el disparo siguiente")
	_expect(aim.distance_to(base) > 0.01, "la direccion sale desviada del cañon")
	_expect(_finite_float(aim.length()), "la direccion es finita")


func _test_extreme_delta() -> void:
	_case = "delta extremo sin NaN"
	var recoil = RecoilScript.new()
	recoil.on_fired("sniper_rifle")
	recoil.step(1000000000.0)
	_expect(_finite_vec(recoil.kick()), "kick finito con delta gigante")
	_expect(_finite_float(recoil.pitch()), "pitch finito con delta gigante")
	_expect(_finite_float(recoil.yaw()), "yaw finito con delta gigante")
	_expect(_finite_vec(recoil.aim_direction(Vector3.FORWARD)), "punteria finita con delta gigante")
	_expect(_finite_transform(recoil.weapon_offset()), "offset finito con delta gigante")
	recoil.step(-1.0)
	recoil.step(0.0)
	_expect(_finite_vec(recoil.kick()), "kick finito con delta negativo")
	_expect(_finite_float(recoil.pitch()), "pitch finito con delta negativo")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _finite_vec(value: Vector3) -> bool:
	return _finite_float(value.x) and _finite_float(value.y) and _finite_float(value.z)


func _finite_transform(value: Transform3D) -> bool:
	return _finite_vec(value.origin) and _finite_vec(value.basis.x) \
		and _finite_vec(value.basis.y) and _finite_vec(value.basis.z)


func _vec_close(a: Vector3, b: Vector3, tolerance: float = 0.000001) -> bool:
	return absf(a.x - b.x) <= tolerance and absf(a.y - b.y) <= tolerance and absf(a.z - b.z) <= tolerance


func _transform_close(a: Transform3D, b: Transform3D) -> bool:
	return _vec_close(a.origin, b.origin) and _vec_close(a.basis.x, b.basis.x) \
		and _vec_close(a.basis.y, b.basis.y) and _vec_close(a.basis.z, b.basis.z)


func _events_close(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var first: Dictionary = a[i]
		var second: Dictionary = b[i]
		if absf(float(first["amplitude"]) - float(second["amplitude"])) > 0.000001:
			return false
		if absf(float(first["duration"]) - float(second["duration"])) > 0.000001:
			return false
		if str(first["hand"]) != str(second["hand"]):
			return false
	return true
