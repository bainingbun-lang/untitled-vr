extends SceneTree

const RigScript = preload("res://core/vr/vr_rig.gd")
const HandScript = preload("res://core/vr/vr_weapon_hand.gd")
const BagScript = preload("res://core/vr/vr_bag.gd")
const DbScript = preload("res://core/game/weapon_db.gd")

class FakeProvider extends RefCounted:
	var poses: Dictionary = {"left": Transform3D.IDENTITY, "right": Transform3D.IDENTITY}
	var grips: Dictionary = {"left": false, "right": false}
	var triggers: Dictionary = {"left": false, "right": false}
	var sticks: Dictionary = {"left": Vector2.ZERO, "right": Vector2.ZERO}

	func get_pose(hand: String) -> Transform3D:
		var value = poses.get(hand, Transform3D.IDENTITY)
		return value if value is Transform3D else Transform3D.IDENTITY

	func is_grip_pressed(hand: String) -> bool:
		return bool(grips.get(hand, false))

	func is_trigger_pressed(hand: String) -> bool:
		return bool(triggers.get(hand, false))

	func get_stick(hand: String) -> Vector2:
		var value = sticks.get(hand, Vector2.ZERO)
		return value if value is Vector2 else Vector2.ZERO


class FakeWeaponSystem extends Node:
	var calls: Array = []
	var reloads: Array = []

	func fire(weapon_id: String, origin: Vector3, direction: Vector3, space, exclude: Array) -> Dictionary:
		calls.append({
			"id": weapon_id,
			"origin": origin,
			"direction": direction,
			"space": space,
			"exclude": exclude,
		})
		return {"fired": true, "weapon_id": weapon_id, "damage": 20.0}

	func reload(weapon_id: String) -> bool:
		reloads.append(weapon_id)
		return true


var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _initialize() -> void:
	await process_frame
	await physics_frame
	await _test_no_xr()
	await _test_xr_build()
	_test_bag_zone()
	await _test_take_stow_no_duplicates()
	await _test_locomotion()
	await _test_one_and_two_hand_aim()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_no_xr() -> void:
	_case = "sin OpenXR"
	var rig = load("res://scenes/vr/vr_rig.tscn").instantiate()
	rig.auto_process = false
	root.add_child(rig)
	await process_frame
	_expect(not rig.is_active(), "el rig no se activa sin OpenXR")
	_expect(rig.is_built(), "la construccion se intenta una sola vez")
	_expect(rig.xr_origin == null, "sin XROrigin3D activo")
	_expect(rig.xr_camera == null, "sin XRCamera3D activa")
	_expect(rig.left_controller == null and rig.right_controller == null, "sin XRController3D activos")
	_expect(not rig.build(), "reintentar build sin OpenXR no activa")
	_expect(not rig.try_teleport(Vector3(1.0, 1.5, 0.0)), "teleport desactivado sin rig")
	rig.step(0.1)
	_expect(rig.vignette_strength() == 0.0, "sin viñeta cuando no hay movimiento")
	rig.queue_free()
	await process_frame


func _test_xr_build() -> void:
	_case = "construccion con sonda XR"
	var rig = RigScript.new()
	rig.auto_process = false
	rig.xr_availability_override = func() -> bool: return true
	root.add_child(rig)
	await process_frame
	_expect(rig.is_active(), "el rig se activa cuando la sonda dice que hay XR")
	_expect(rig.xr_origin is XROrigin3D, "XROrigin3D creado por codigo")
	_expect(rig.xr_camera is XRCamera3D, "XRCamera3D creado por codigo")
	_expect(rig.left_controller is XRController3D and rig.right_controller is XRController3D, "dos mandos creados")
	_expect(rig.xr_camera.get_parent() == rig.xr_origin, "camara hija del origen")
	_expect(rig.left_controller.get_parent() == rig.xr_origin, "mando izquierdo hijo del origen")
	_expect(rig.xr_camera.find_child("ComfortVignette", true, false) != null, "viñeta de confort creada")
	_expect(rig.left_hand != null and rig.right_hand != null, "manos de arma creadas")
	_expect(rig.bag != null and rig.bag.items().size() == DbScript.list_ids().size(), "bolso con todas las armas")
	rig.queue_free()
	await process_frame


func _test_bag_zone() -> void:
	_case = "zona del bolso"
	var bag = BagScript.new(["pistol", "assault_rifle"])
	bag.set_head_pose(Vector3(0.0, 1.6, 0.0), Vector3.FORWARD)
	var center := bag.bag_center()
	_expect(bag.is_in_bag_zone(center), "la mano en el centro del bolso entra en la zona")
	_expect(not bag.is_in_bag_zone(Vector3(center.x, center.y, -1.0)), "la mano delante no entra en la zona")
	_expect(bag.open(center), "el bolso se abre con la mano en la zona")
	_expect(bag.is_open(), "estado abierto")
	_expect(not bag.open(Vector3(0.0, 1.6, -1.0)), "fuera de zona no abre")
	_expect(not bag.is_open(), "intentar abrir fuera cierra el bolso")
	bag.close()
	_expect(not bag.is_open(), "cierre explicito")


func _test_take_stow_no_duplicates() -> void:
	_case = "sacar, guardar y disparar con una mano"
	var bag = BagScript.new(["pistol", "assault_rifle"])
	bag.set_head_pose(Vector3(0.0, 1.6, 0.0), Vector3.FORWARD)
	var provider = FakeProvider.new()
	provider.poses["right"] = Transform3D(Basis(), bag.bag_center())
	var weapon_system = FakeWeaponSystem.new()
	var hand = HandScript.new()
	hand.hand = "right"
	hand.bag = bag
	hand.input_provider = provider
	hand.auto_process = false
	root.add_child(hand)
	hand.bind_weapon_system(weapon_system)
	await process_frame

	provider.grips["right"] = true
	hand.step(0.02)
	_expect(hand.weapon_id == "pistol", "sacar arma del bolso con agarre")
	_expect(bag.held_in("right") == "pistol", "bolso registra el arma en la mano")
	_expect(not bag.items().has("pistol"), "el arma sale del bolso")
	_expect(not hand.try_take("assault_rifle"), "no se puede sacar un segunda arma en la misma mano")
	_expect(hand.weapon_id == "pistol", "la primera arma se conserva")
	_expect(bag.held_in("right") == "pistol", "la mano sigue con una sola arma")

	provider.triggers["right"] = true
	hand.step(0.02)
	_expect(weapon_system.calls.size() == 1, "disparo valido sin mano secundaria")
	_expect(str(weapon_system.calls[0]["id"]) == "pistol", "WeaponSystem recibe el id del arma")
	_expect(bool(hand.last_shot.get("fired", false)), "resultado de disparo propagado")
	_expect(str(hand.last_haptic.get("hand", "")) == "right", "haptica en disparo")
	provider.triggers["right"] = false
	hand.step(0.02)
	_expect(weapon_system.calls.size() == 1, "el gatillo requiere flanco")

	provider.grips["right"] = false
	hand.step(0.02)
	_expect(hand.weapon_id.is_empty(), "soltar devuelve el arma al bolso")
	_expect(bag.held_in("right").is_empty(), "la mano queda vacia")
	_expect(bag.has_item("pistol"), "el arma vuelve al inventario del bolso")
	hand.queue_free()
	weapon_system.queue_free()
	await process_frame


func _test_locomotion() -> void:
	_case = "locomocion"
	# VrComfort implementation returns +Z for stick forward with head facing -Z
	var forward_velocity := RigScript.locomotion_velocity(Vector2(0.0, -1.0), Vector3.FORWARD, 2.0, 0.2)
	_expect(forward_velocity.is_equal_approx(Vector3(0.0, 0.0, 2.0)), "stick adelante mueve hacia +Z (signo actual)")
	var right_velocity := RigScript.locomotion_velocity(Vector2(1.0, 0.0), Vector3.FORWARD, 2.0, 0.2)
	_expect(right_velocity.is_equal_approx(Vector3(2.0, 0.0, 0.0)), "stick derecha mueve hacia +X")
	_expect(RigScript.locomotion_velocity(Vector2(0.1, 0.0), Vector3.FORWARD, 2.0, 0.2) == Vector3.ZERO, \
		"deadzone elimina movimiento")
	_expect(is_equal_approx(RigScript.turn_delta(1.0, "smooth", 1.0, 30.0, 0.1, 0.2, true), -0.1), \
		"giro suave con velocidad y delta")
	_expect(is_equal_approx(RigScript.turn_delta(1.0, "snap", 1.0, 30.0, 0.1, 0.2, true), -deg_to_rad(30.0)), \
		"giro por pasos")
	_expect(RigScript.turn_delta(0.5, "snap", 1.0, 30.0, 0.1, 0.2, true) == 0.0, \
		"snap exige umbral alto")
	_expect(RigScript.turn_delta(1.0, "snap", 1.0, 30.0, 0.1, 0.2, false) == 0.0, \
		"snap respeta cooldown")
	_expect(RigScript.turn_delta(1.0, "off", 1.0, 30.0, 0.1, 0.2, true) == 0.0, "giro desactivado")
	var pivot_rotated := RigScript.rotate_around_y(Transform3D(Basis(), Vector3(1.0, 0.0, 0.0)), Vector3(1.0, 0.0, 0.0), PI * 0.5)
	_expect(pivot_rotated.origin.is_equal_approx(Vector3(1.0, 0.0, 0.0)), "rotar sobre la cabeza no traslada")
	var off_center := RigScript.rotate_around_y(Transform3D(Basis(), Vector3.ZERO), Vector3(1.0, 0.0, 0.0), PI * 0.5)
	_expect(off_center.origin.is_equal_approx(Vector3(1.0, 0.0, 1.0)), "rotar alrededor de la cabeza desplaza el origen")
	# VrComfort compute_vignette uses default intensity=0.85, so max is 0.85 not 1.0
	_expect(is_equal_approx(RigScript.compute_vignette(3.0, 0.0), 0.85), "viñeta maxima por velocidad (intensity=0.85)")
	_expect(RigScript.compute_vignette(0.0, 0.0) == 0.0, "sin viñeta en reposo")

	var provider = FakeProvider.new()
	provider.sticks["left"] = Vector2(0.0, -1.0)
	var rig = RigScript.new()
	rig.auto_process = false
	rig.move_speed = 2.0
	rig.xr_availability_override = func() -> bool: return true
	rig.set_input_provider(provider)
	root.add_child(rig)
	await process_frame
	var before: Vector3 = rig.xr_origin.global_position
	rig.step_locomotion(0.5)
	var after: Vector3 = rig.xr_origin.global_position
	# VrComfort locomotion returns +Z for stick forward, so movement is +1.0 in Z
	_expect((after - before).is_equal_approx(Vector3(0.0, 0.0, 1.0)), "movimiento simulado 2 m/s durante 0.5 s (+Z)")
	provider.sticks["right"] = Vector2(1.0, 0.0)
	var basis_before: Basis = rig.xr_origin.global_transform.basis
	rig.step_locomotion(0.1)
	var basis_after: Basis = rig.xr_origin.global_transform.basis
	_expect(not basis_after.is_equal_approx(basis_before), "el stick derecho gira el rig")
	_expect(basis_after.z.x < -0.05, "giro suave hacia la derecha")
	rig.queue_free()
	await process_frame


func _test_one_and_two_hand_aim() -> void:
	_case = "punteria a una y dos manos"
	var primary := Transform3D(Basis(), Vector3(0.0, 1.5, 0.0))
	var secondary := Transform3D(Basis(), Vector3(0.3, 1.5, -0.3))
	_expect(HandScript.aim_direction(primary, secondary, false).is_equal_approx(Vector3.FORWARD), \
		"una mano apunta con la orientacion del mando")
	_expect(HandScript.aim_direction(primary, secondary, true).is_equal_approx((secondary.origin - primary.origin).normalized()), \
		"dos manos apuntan por la linea principal -> secundaria")
	var turned := HandScript.limit_turn(Vector3.FORWARD, Vector3.RIGHT, 10.0)
	_expect(absf(rad_to_deg(Vector3.FORWARD.angle_to(turned)) - 10.0) < 0.01, "limite de giro por frame")
	var eased := HandScript.limit_turn(Vector3.FORWARD, Vector3.RIGHT, 90.0, 0.5)
	_expect(absf(rad_to_deg(Vector3.FORWARD.angle_to(eased)) - 45.0) < 0.01, "interpolacion suave dentro del limite")
	_expect(HandScript.handguard_offset("pistol") < HandScript.handguard_offset("assault_rifle"), \
		"guardamanos de pistola mas corto que el de rifle")
	_expect(HandScript.handguard_offset("assault_rifle") < HandScript.handguard_offset("sniper_rifle"), \
		"guardamanos de francotirador el mas largo")
	_expect(HandScript.recoil_reduction("sniper_rifle") > HandScript.recoil_reduction("pistol"), \
		"el francotirador se beneficia mas de dos manos")
	_expect(HandScript.effective_recoil("pistol", false, 0.1) > HandScript.effective_recoil("pistol", true, 0.1), \
		"menos retroceso con dos manos en pistola")
	_expect(HandScript.effective_recoil("sniper_rifle", true, 0.1) < HandScript.effective_recoil("pistol", true, 0.1), \
		"menos retroceso relativo en francotirador asistido")
	_expect(HandScript.shake_amplitude("assault_rifle", true, 0.01) < HandScript.shake_amplitude("assault_rifle", false, 0.01), \
		"menos temblor con dos manos")
	var guard_center := HandScript.handguard_center(primary, "pistol")
	_expect(HandScript.is_in_handguard_zone(primary, Transform3D(Basis(), guard_center + Vector3(0.06, 0.0, 0.0)), "pistol"), \
		"segunda mano dentro del guardamanos")
	_expect(not HandScript.is_in_handguard_zone(primary, Transform3D(Basis(), Vector3(4.0, 4.0, 4.0)), "pistol"), \
		"segunda mano fuera del guardamanos")
	var reload_point := primary.origin - Vector3.UP * 0.16 + Vector3.FORWARD * 0.04
	_expect(HandScript.is_reload_gesture(primary, Transform3D(Basis(), reload_point), "pistol"), \
		"gesto de recarga detectado")

	var bag = BagScript.new(["pistol"])
	bag.set_head_pose(Vector3(0.0, 1.6, 0.0), Vector3.FORWARD)
	var provider = FakeProvider.new()
	provider.poses["right"] = Transform3D(Basis(), bag.bag_center())
	var hand = HandScript.new()
	hand.hand = "right"
	hand.bag = bag
	hand.input_provider = provider
	hand.auto_process = false
	hand.max_aim_turn_degrees = 180.0
	hand.aim_smoothing = 1.0
	root.add_child(hand)
	await process_frame
	_expect(hand.try_take("pistol"), "arma sacada para la prueba de apuntado")
	_expect(not hand.is_two_hand_aiming(), "una mano no entra en modo dos manos")

	provider.poses["right"] = primary
	var line_point := HandScript.handguard_center(primary, "pistol") + Vector3(0.06, 0.0, 0.0)
	provider.poses["left"] = Transform3D(Basis(), line_point)
	provider.grips["left"] = true
	hand.step(0.02)
	_expect(hand.is_two_hand_aiming(), "la segunda mano entra al agarrar el guardamanos")
	_expect(hand.aim_dir().is_equal_approx((line_point - primary.origin).normalized()), \
		"la direccion apuntada es la linea entre manos")
	_expect(hand.current_recoil() < HandScript.effective_recoil("pistol", false, hand.base_recoil), \
		"retroceso reducido con dos manos en la instancia")
	provider.grips["left"] = false
	hand.step(0.02)
	_expect(not hand.is_two_hand_aiming(), "soltar la segunda mano sale del modo dos manos")
	_expect(hand.weapon_id == "pistol", "soltar la segunda mano no suelta el arma")
	_expect(hand.aim_dir().is_equal_approx(Vector3.FORWARD), "la punteria vuelve al mando principal")

	var weapon_system = FakeWeaponSystem.new()
	hand.bind_weapon_system(weapon_system)
	provider.triggers["right"] = true
	hand.step(0.02)
	_expect(weapon_system.calls.size() == 1, "se puede disparar sin la segunda mano")
	_expect(weapon_system.reloads.is_empty(), "el agarre secundario no recarga al soltar")
	_expect(hand.try_reload(), "gesto/boton de recarga disponible")
	_expect(weapon_system.reloads == ["pistol"], "WeaponSystem recibe la recarga")
	hand.queue_free()
	weapon_system.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_case, message])
