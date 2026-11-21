extends SceneTree

const GrabScript = preload("res://core/vr/vr_grab.gd")
const PoseScript = preload("res://core/vr/vr_hand_pose.gd")
const HandScript = preload("res://core/vr/vr_weapon_hand.gd")
const TeleportScript = preload("res://core/vr/vr_teleport.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _initialize() -> void:
	await process_frame
	_test_multi_grab()
	_test_mixed_poses()
	_test_impact_haptics()
	_test_teleport_arc()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d assertions fallidas)" % [_failures.size()])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _test_multi_grab() -> void:
	_case = "varios puntos de agarre (dos manos en zonas distintas)"
	var weapon_pose := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
	var grabber = GrabScript.new(1.0)
	var hand_right := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, -0.02))
	var hand_left := Transform3D(Basis.IDENTITY, Vector3(0.12, 1.0, -0.30))

	_expect(grabber.grab(hand_right, weapon_pose, "assault_rifle", 1.0, "grip"), "primera mano agarra zona grip")
	_expect(grabber.is_grabbing(), "primera mano esta agarrando")
	_expect(grabber.held_zone() == "grip", "primera mano en zona grip")
	_expect(not grabber.is_two_hand_grabbing(), "todavia no es agarre a dos manos")

	_expect(grabber.grab_secondary(hand_left, weapon_pose, "assault_rifle", 1.0, "handguard"), "segunda mano agarra zona handguard")
	_expect(grabber.is_two_hand_grabbing(), "ahora es agarre a dos manos")
	_expect(grabber.held_secondary_zone() == "handguard", "segunda mano en zona handguard")
	_expect(grabber.held_secondary_hand() == "left", "segunda mano es la izquierda")

	var step_result := grabber.step(1.0 / 60.0, hand_right, 1.0, hand_left)
	_expect(step_result.origin.distance_to(weapon_pose.origin) < 0.5, "arma se mueve hacia el punto intermedio de las dos manos")

	var zones = GrabScript.grip_zones("assault_rifle")
	_expect(zones.has("grip") and zones.has("handguard"), "zonas grip y handguard existen")

	grabber.release_secondary()
	_expect(not grabber.is_two_hand_grabbing(), "despues de soltar segunda mano ya no es dos manos")
	_expect(grabber.held_secondary_zone().is_empty(), "zona secundaria vacia despues de soltar")

	grabber.release()
	_expect(not grabber.is_grabbing(), "primera mano suelta el arma")
	_expect(not grabber.is_two_hand_grabbing(), "no hay agarre a dos manos despues de soltar todo")


func _test_mixed_poses() -> void:
	_case = "poses mezcladas por zona (mixed poses)"
	var primary_grip := PoseScript.pose(1.0, 0.0, "grip", "right")
	var secondary_handguard := PoseScript.pose(1.0, 0.0, "handguard", "left")
	_expect(primary_grip["zone"] == "grip", "mano primaria zona grip")
	_expect(secondary_handguard["zone"] == "handguard", "mano secundaria zona handguard")
	_expect(primary_grip["hand"] == "right", "mano primaria derecha")
	_expect(secondary_handguard["hand"] == "left", "mano secundaria izquierda")

	var mixed := PoseScript.two_hand_pose("grip", "handguard", 1.0, 1.0, 0.0, 0.0, "right", "left")
	_expect(mixed["primary_zone"] == "grip", "zona primaria registrada")
	_expect(mixed["secondary_zone"] == "handguard", "zona secundaria registrada")
	_expect(bool(mixed["mixed"]), "zonas diferentes = mixed true")
	_expect(mixed["primary"]["hand"] == "right", "primera mano derecha")
	_expect(mixed["secondary"]["hand"] == "left", "segunda mano izquierda")

	var same_zone := PoseScript.two_hand_pose("grip", "grip", 1.0, 1.0, 0.0, 0.0, "right", "left")
	_expect(not bool(same_zone["mixed"]), "zona misma = mixed false")

	var primary_angles: Array = mixed["primary"]["fingers"]["middle"]
	var secondary_angles: Array = mixed["secondary"]["fingers"]["middle"]
	_expect(primary_angles.size() == PoseScript.JOINTS, "tres articulaciones mano primaria")
	_expect(secondary_angles.size() == PoseScript.JOINTS, "tres articulaciones mano secundaria")
	for angle in primary_angles:
		_expect(not is_nan(float(angle)) and float(angle) >= 0.0, "angulo finito mano primaria")
	for angle in secondary_angles:
		_expect(not is_nan(float(angle)) and float(angle) >= 0.0, "angulo finito mano secundaria")

	var loose := PoseScript.pose(0.2, 0.0, "open")
	var tight := PoseScript.pose(1.0, 0.0, "grip")
	_expect(tight["fingers"]["middle"][0] > loose["fingers"]["middle"][0], "mas grip curva mas los dedos")


func _test_impact_haptics() -> void:
	_case = "haptica por impacto basada en masa y velocidad"
	var haptic_light := HandScript.impact_haptic(0.5, 2.0)
	var haptic_heavy := HandScript.impact_haptic(5.0, 10.0)
	_expect(haptic_heavy["strength"] > haptic_light["strength"], "objeto pesado rapido = mas fuerza haptica")
	_expect(haptic_heavy["amplitude"] > haptic_light["amplitude"], "impacto fuerte = mayor amplitud")
	_expect(haptic_heavy["duration"] > haptic_light["duration"], "impacto fuerte = mayor duracion")
	_expect(haptic_heavy["energy"] > haptic_light["energy"], "energia cinetica mayor")
	_expect(haptic_light["strength"] >= 0.0 and haptic_light["strength"] <= 1.0, "fuerza en rango 0-1")
	_expect(haptic_heavy["strength"] >= 0.0 and haptic_heavy["strength"] <= 1.0, "fuerza pesada en rango 0-1")
	_expect(haptic_light["frequency"] > 0.0, "frecuencia positiva")
	_expect(haptic_heavy["frequency"] > 0.0, "frecuencia pesada positiva")
	_expect(haptic_heavy["frequency"] < haptic_light["frequency"], "impacto pesado = frecuencia mas grave")

	var haptic_zero := HandScript.impact_haptic(0.0, 0.0)
	_expect(haptic_zero["strength"] == 0.0, "masa nula = fuerza nula")
	_expect(haptic_zero["energy"] == 0.0, "velocidad nula = energia nula")


func _test_teleport_arc() -> void:
	_case = "arco de teletransporte y validacion de objetivo"
	var origin := Vector3(0.0, 1.6, 0.0)
	var direction := Vector3(0.0, 0.0, -1.0)
	var arc: Array = TeleportScript.compute_arc(origin, direction, 10.0, 9.8, 20, 1.5)
	_expect(arc.size() == 21, "arco tiene 21 puntos (20 segmentos)")
	_expect(arc[0].is_equal_approx(origin), "primer punto del arco es el origen")
	_expect(arc[arc.size() - 1].y < origin.y, "ultimo punto del arco cae por gravedad")
	var peak_found := false
	for i in arc.size():
		if arc[i].y > origin.y + 0.5:
			peak_found = true
			break
	_expect(peak_found, "arco alcanza altura maxima superior al origen")

	var dist_max: float = TeleportScript.max_distance(10.0, 9.8, 1.5)
	_expect(dist_max > 0.0, "distancia maxima positiva")
	var dist_zero: float = TeleportScript.max_distance(0.0, 9.8, 1.5)
	_expect(dist_zero == 0.0, "velocidad cero = distancia cero")

	var point: Vector3 = TeleportScript.parabolic_point(origin, direction, 10.0, 9.8, 0.1)
	_expect(point.z < origin.z, "punto parabola avanza en direccion")
	_expect(point.y >= origin.y - 0.1, "punto inicial cerca del origen en Y")

	_expect(TeleportScript.is_walkable_normal(Vector3(0.0, 1.0, 0.0)), "normal hacia arriba es caminable")
	_expect(not TeleportScript.is_walkable_normal(Vector3(1.0, 0.0, 0.0)), "normal horizontal no es caminable")
	_expect(TeleportScript.is_walkable_normal(Vector3(0.0, 0.7, 0.7)), "normal umbral 0.7 es caminable")
