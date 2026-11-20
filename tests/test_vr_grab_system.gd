extends SceneTree

const GrabScript = preload("res://core/vr/vr_grab.gd")
const PoseScript = preload("res://core/vr/vr_hand_pose.gd")
const HolsterScript = preload("res://core/vr/vr_holsters.gd")
const ReloadScript = preload("res://core/vr/vr_reload_gestures.gd")
const HandScript = preload("res://core/vr/vr_weapon_hand.gd")

class FakeProvider extends RefCounted:
	var pose: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
	func get_pose(_hand: String) -> Transform3D:
		return pose
	func is_grip_pressed(_hand: String) -> bool:
		return true
	func is_trigger_pressed(_hand: String) -> bool:
		return false

class FakeWeaponSystem extends Node:
	var calls: int = 0
	func fire(_id: String, _origin: Vector3, _direction: Vector3, _space, _exclude) -> Dictionary:
		calls += 1
		return {"fired": true}

var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _initialize() -> void:
	await process_frame
	_test_zones()
	_test_inertia()
	_test_two_hands()
	_test_slide_and_pump()
	_test_holsters()
	_test_release_and_props()
	_test_hand_pose()
	_test_weapon_hand_integration()
	_test_extreme_delta()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _finite(value: Vector3) -> bool:
	return not is_nan(value.x) and not is_inf(value.x) and not is_nan(value.y) and not is_inf(value.y) and not is_nan(value.z) and not is_inf(value.z)


func _test_zones() -> void:
	_case = "zonas de agarre por proximidad"
	var weapon_pose := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
	var zones: Dictionary = GrabScript.grip_zones("assault_rifle")
	for expected in ["grip", "handguard", "stock", "magazine", "slide"]:
		_expect(zones.has(expected), "falta zona " + str(expected))
	var grip_point: Vector3 = GrabScript.zone_point("grip", weapon_pose, "assault_rifle")
	var hand := Transform3D(Basis.IDENTITY, grip_point)
	var found: Dictionary = GrabScript.nearest_zone(hand, weapon_pose, "assault_rifle")
	_expect(bool(found["ok"]), "mano sobre la empuñadura detecta zona")
	_expect(str(found["zone"]) == "grip", "la zona mas cercana es la empuñadura")
	var guard_point: Vector3 = GrabScript.zone_point("handguard", weapon_pose, "assault_rifle")
	hand = Transform3D(Basis.IDENTITY, guard_point)
	found = GrabScript.nearest_zone(hand, weapon_pose, "assault_rifle")
	_expect(str(found["zone"]) == "handguard", "mano en guardamanos detecta esa zona")
	hand = Transform3D(Basis.IDENTITY, Vector3(4.0, 4.0, 4.0))
	found = GrabScript.nearest_zone(hand, weapon_pose, "assault_rifle")
	_expect(not bool(found["ok"]) and str(found["zone"]).is_empty(), "mano lejana no agarra")
	var grabber = GrabScript.new(1.2)
	_expect(grabber.grab(Transform3D(Basis.IDENTITY, grip_point), weapon_pose, "assault_rifle", 0.6), "agarre analogico aceptado")
	_expect(grabber.held_zone() == "grip" and grabber.is_grabbing(), "estado de agarre correcto")
	_expect(not grabber.grab(hand, weapon_pose, "assault_rifle"), "no se pueden agarrar dos armas a la vez")


func _test_inertia() -> void:
	_case = "inercia y enlace blando"
	var hand := Transform3D(Basis.IDENTITY, Vector3(0.2, 1.0, -0.1))
	var weapon := Transform3D(Basis.IDENTITY, Vector3(0.23, 1.0, -0.08))
	var light = GrabScript.new(0.2)
	var heavy = GrabScript.new(6.0)
	_expect(light.grab(hand, weapon, "pistol"), "agarre ligero")
	_expect(heavy.grab(hand, weapon, "pistol"), "agarre pesado")
	var moved := Transform3D(Basis.IDENTITY, Vector3(0.4, 1.0, -0.2))
	var target: Vector3 = moved.origin + (weapon.origin - hand.origin)
	light.step(1.0 / 60.0, moved)
	heavy.step(1.0 / 60.0, moved)
	var light_error: float = light.weapon_pose().origin.distance_to(target)
	var heavy_error: float = heavy.weapon_pose().origin.distance_to(target)
	_expect(light_error > 0.00001, "el arma no queda pegada al instante")
	_expect(heavy_error > light_error, "el arma pesada se retrasa mas")
	for i in 180:
		light.step(1.0 / 60.0, moved)
		heavy.step(1.0 / 60.0, moved)
	_expect(light.weapon_pose().origin.distance_to(target) < 0.002, "arma ligera converge a la mano")
	_expect(heavy.weapon_pose().origin.distance_to(target) < 0.02, "arma pesada converge a la mano")
	var rotated_hand := Transform3D(Basis(Vector3.UP, 0.5), Vector3(0.4, 1.0, -0.2))
	var before: Vector3 = light.weapon_pose().origin
	for i in 120:
		light.step(1.0 / 60.0, rotated_hand)
	_expect(light.weapon_pose().origin.distance_to(before) > 0.001, "la rotacion de la mano mueve el arma alrededor del agarre")


func _test_two_hands() -> void:
	_case = "apuntado a dos manos"
	var primary := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.4, 0.0))
	var secondary := Transform3D(Basis.IDENTITY, Vector3(0.12, 1.4, -0.28))
	var one_hand := -primary.basis.z
	var two_hands: Vector3 = GrabScript.aim_line(primary, secondary)
	_expect(absf(one_hand.angle_to(two_hands)) > 0.1, "la linea entre manos cambia la direccion")
	_expect(two_hands.z < 0.0 and two_hands.x > 0.0, "la linea apunta al guardamanos")
	_expect(GrabScript.steadiness(false, false) > GrabScript.steadiness(true, false), "dos manos estabilizan")
	_expect(GrabScript.steadiness(true, false) > GrabScript.steadiness(true, true), "culata al hombro estabiliza mas")
	_expect(GrabScript.sway(0.01, true, true) < GrabScript.sway(0.01, false, false) * 0.3, "sway reducido con dos manos y culata")
	var shoulder := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.4, 0.06))
	var head := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.6, 0.0))
	_expect(GrabScript.stock_at_shoulder(shoulder, head, 0.15), "culata cerca de la mejilla detectada")
	shoulder.origin = Vector3(2.0, 1.4, 0.06)
	_expect(not GrabScript.stock_at_shoulder(shoulder, head, 0.15), "culata lejana no cuenta")


func _test_slide_and_pump() -> void:
	_case = "corredera y bombeo"
	var gestures = ReloadScript.new()
	gestures.begin("pistol", 8, 24)
	gestures.set_ready()
	_expect(not gestures.rack_slide(0.01, true), "tiron corto no monta")
	_expect(not gestures.rack_slide(0.12, false), "sin soltar no monta")
	_expect(gestures.rack_slide(0.12, true), "tirar y soltar monta la pistola")
	_expect(gestures.can_fire(), "arma montada puede disparar")
	var fired: bool = gestures.fire()
	_expect(fired and not gestures.can_fire(), "disparo consume la recamara")
	gestures.begin("shotgun", 2, 10, 0, 2)
	_expect(gestures.phase() == "load_shell", "escopeta empieza cargando cartuchos")
	_expect(gestures.advance("load_shell") and gestures.phase() == "load_shell", "cartucho uno a uno")
	_expect(gestures.advance("load_shell") and gestures.phase() == "pump", "segundo cartucho y fase de bombeo")
	_expect(not gestures.pump_action(-0.09), "solo ida no completa el bombeo")
	_expect(gestures.pump_action(0.09), "bombeo adelante-atras complete")
	var shell_events: Array = gestures.events()
	var ejected: bool = false
	for event in shell_events:
		if str(event.get("type", "")) == "shell_ejected":
			ejected = true
	_expect(ejected, "el bombeo expulsa la vaina fisicamente")


func _test_holsters() -> void:
	_case = "fundas y bolso"
	var holsters = HolsterScript.new()
	var head := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.7, 0.0))
	holsters.set_head_pose(head)
	var hip: Vector3 = holsters.slot_position("hip")
	_expect(hip.x > 0.0 and hip.y < 1.7, "funda de cadera a la derecha y abajo")
	var back: Vector3 = holsters.slot_position("back")
	_expect(back.z > 0.0, "funda de espalda detras de la cabeza")
	var chest: Vector3 = holsters.slot_position("chest")
	_expect(chest.z < 0.0, "funda de pecho delante de la cabeza")
	var hand := Transform3D(Basis.IDENTITY, hip)
	var nearest: Dictionary = holsters.nearest_slot(hand)
	_expect(str(nearest["slot"]) == "hip" and bool(nearest["ok"]), "mano en cadera encuentra su funda")
	_expect(holsters.preferred_slot("pistol") == "hip", "pistola va a la cadera")
	_expect(holsters.preferred_slot("assault_rifle") == "back", "arma larga va a la espalda")
	_expect(holsters.preferred_slot("assault_rifle_magazine", ["magazine"]) == "chest", "cargadores al pecho")
	_expect(holsters.preferred_slot("rock") == "bag", "objetos al bolso")
	_expect(holsters.stow("pistol", "right"), "guardar pistola en funda")
	_expect(holsters.item_in("hip") == "pistol" and holsters.is_stowed("pistol"), "funda contiene la pistola")
	_expect(not holsters.stow("pistol", "right"), "no se guarda dos veces")
	_expect(holsters.draw("hip", "right") == "pistol", "sacar pistola de la funda")
	_expect(holsters.item_in("hip").is_empty(), "funda vacia tras sacar")


func _test_release_and_props() -> void:
	_case = "soltar armas y objetos"
	var grabber = GrabScript.new(1.0)
	var hand := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
	var weapon := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, -0.02))
	_expect(grabber.grab(hand, weapon, "pistol"), "agarrar para soltar")
	var thrown: Dictionary = grabber.release("fall", Vector3(1.0, 0.0, 0.0))
	_expect(str(thrown["mode"]) == "fall", "sin funda cercana el arma cae")
	_expect(Vector3(thrown["velocity"]).x > 0.9, "velocidad de lanzamiento conservada")
	_expect(not grabber.is_grabbing(), "ya no esta agarrada")
	_expect(grabber.grab(hand, weapon, "pistol"), "segundo agarre")
	thrown = grabber.release("holster", Vector3.ZERO)
	_expect(str(thrown["mode"]) == "holster", "con funda cercana vuelve a la funda")
	var previous := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
	var current := Transform3D(Basis.IDENTITY, Vector3(0.1, 1.0, 0.0))
	var velocity: Vector3 = GrabScript.throw_velocity(current, previous, 0.1)
	_expect(absf(velocity.x - 1.0) < 0.001, "velocidad de mano lineal")
	_expect(GrabScript.throw_velocity(current, previous, 0.0).x <= 8.0, "velocidad tope con delta cero")
	var body := RigidBody3D.new()
	body.add_to_group("physics_props")
	root.add_child(body)
	body.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.05, 1.0, 0.0))
	var prop_grab = GrabScript.new()
	_expect(prop_grab.grab_prop(body, hand, 0.2), "prop fisico agarrado por grupo")
	_expect(bool(body.get("freeze")), "prop congelado mientras se sostiene")
	var launched: Dictionary = prop_grab.release_prop(Vector3(0.0, 0.5, -2.0))
	_expect(bool(launched["released"]), "prop soltado")
	_expect(body.linear_velocity.distance_to(Vector3(0.0, 0.5, -2.0)) < 0.001, "prop lanzado con velocidad de la mano")
	_expect(not bool(body.get("freeze")), "prop vuelve a la fisica")
	body.queue_free()


func _test_hand_pose() -> void:
	_case = "poses procedurales de mano"
	var loose: Dictionary = PoseScript.pose(0.1, 0.0, "grip")
	var tight: Dictionary = PoseScript.pose(1.0, 0.0, "grip")
	var loose_angles: Array = loose["fingers"]["middle"]
	var tight_angles: Array = tight["fingers"]["middle"]
	_expect(tight_angles[0] > loose_angles[0], "mas grip curva mas los dedos")
	var trigger: Dictionary = PoseScript.pose(0.2, 1.0, "grip")
	_expect(trigger["fingers"]["index"][0] > tight["fingers"]["index"][0] * 0.4, "indice sigue el gatillo")
	for finger in PoseScript.FINGERS:
		var angles: Array = tight["fingers"][finger]
		_expect(angles.size() == PoseScript.JOINTS, "tres articulaciones por dedo")
		for angle in angles:
			_expect(not is_nan(float(angle)) and float(angle) >= 0.0, "angulo finito")
	var hand_node := Node3D.new()
	for finger in PoseScript.FINGERS:
		var joint := Node3D.new()
		joint.name = "Finger_%s_01" % finger
		hand_node.add_child(joint)
	_expect(PoseScript.apply_to(hand_node, tight) == PoseScript.FINGERS.size(), "poses aplicadas a la malla de mano")
	hand_node.queue_free()


func _test_weapon_hand_integration() -> void:
	_case = "integracion opt-in en VrWeaponHand"
	var hand_node = HandScript.new()
	hand_node.hand = "right"
	hand_node.weapon_id = "pistol"
	hand_node.use_physical_grab = true
	hand_node.auto_process = false
	hand_node.input_provider = FakeProvider.new()
	root.add_child(hand_node)
	_expect(hand_node.grab_system != null and hand_node.holsters != null, "sistemas de agarre y fundas creados")
	_expect(hand_node.grab_weapon_from_pose(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, -0.03))), "arma ligada a la mano con zona de empuñadura")
	var values: Dictionary = hand_node.hand_pose_values(1.0, 0.3, "grip")
	_expect((values["fingers"] as Dictionary).has("index"), "pose de mano disponible desde el arma")
	var weapon_system = FakeWeaponSystem.new()
	root.add_child(weapon_system)
	hand_node.bind_weapon_system(weapon_system)
	_expect(hand_node.begin_manual_reload(8, 20), "recarga manual iniciada")
	_expect(hand_node.reload_phase() == "eject", "fase inicial de la recarga manual")
	var blocked: Dictionary = hand_node.try_fire()
	_expect(not bool(blocked["fired"]), "arma sin montar no dispara")
	_expect(hand_node.reload_eject_magazine(Vector3.ZERO)["ejected"], "expulsar cargador desde el arma")
	_expect(hand_node.reload_insert_magazine(Transform3D.IDENTITY, Transform3D.IDENTITY), "insertar cargador desde el arma")
	_expect(hand_node.reload_rack_slide(0.12, true), "montar arma desde el arma")
	_expect(hand_node.reload_can_fire(), "arma montada lista")
	var fired: Dictionary = hand_node.try_fire()
	_expect(bool(fired["fired"]) and weapon_system.calls == 1, "disparo real tras montar")
	_expect(not hand_node.reload_can_fire(), "el disparo consume la recamara")
	hand_node.stow()
	_expect(not hand_node.manual_reload_active, "guardar cancela la recarga pendiente")
	hand_node.queue_free()
	weapon_system.queue_free()


func _test_extreme_delta() -> void:
	_case = "delta extremo sin NaN"
	var grabber = GrabScript.new(1.0)
	var hand := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
	grabber.grab(hand, Transform3D(Basis.IDENTITY, Vector3(0.5, 1.2, 0.0)), "pistol")
	grabber.step(1.0e9, hand)
	_expect(_finite(grabber.weapon_pose().origin), "posicion finita con delta gigante")
	_expect(_finite(grabber.linear_velocity()), "velocidad finita con delta gigante")
	grabber.step(-100.0, hand)
	_expect(_finite(grabber.weapon_pose().origin), "posicion finita con delta negativo")
	var gestures = ReloadScript.new()
	gestures.begin("pistol", 8, 20)
	_expect(not gestures.safety_tick(1.0e9) or gestures.is_complete(), "tope de seguridad con delta gigante")
	_expect(gestures.can_fire() or not gestures.is_complete(), "estado consistente tras el tope")
