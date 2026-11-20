extends SceneTree

const ReloadScript = preload("res://core/vr/vr_reload_gestures.gd")
const GrabScript = preload("res://core/vr/vr_grab.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _initialize() -> void:
	await process_frame
	_test_phases()
	_test_magazine_ammo()
	_test_tolerance()
	_test_chamber()
	_test_shotgun()
	_test_bolt()
	_test_cancel_and_safety()
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


func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if str(event.get("type", "")) == event_type:
			return true
	return false


func _test_phases() -> void:
	_case = "maquina de estados compartida"
	var gestures = ReloadScript.new()
	var seen: Array = []
	gestures.phase_changed.connect(func(phase): seen.append(phase))
	gestures.begin("assault_rifle", 30, 90)
	_expect(gestures.phase() == "eject", "fase inicial es soltar cargador")
	_expect(not gestures.insert_magazine(Transform3D.IDENTITY, Transform3D.IDENTITY), "no se puede insertar antes de soltar")
	var drop: Dictionary = gestures.eject_magazine(Vector3(0.1, 0.5, 0.2))
	_expect(bool(drop["ejected"]), "cargador expulsado")
	_expect(gestures.phase() == "insert", "fase siguiente es insertar")
	_expect(not gestures.rack_slide(0.12, true), "no se puede montar antes de insertar")
	var well := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
	var hand := Transform3D(Basis.IDENTITY, Vector3(0.01, 1.0, 0.0))
	_expect(gestures.insert_magazine(hand, well), "cargador insertado alineado")
	_expect(gestures.phase() == "chamber", "fase siguiente es montar")
	_expect(gestures.rack_slide(0.10, true), "cerrojo montado")
	_expect(gestures.phase() == "ready" and gestures.is_complete(), "recarga completa")
	_expect(seen.size() >= 4, "cada fase emite señal")
	_expect(seen[0] == "eject" and seen.back() == "ready", "secuencia de señales correcta")
	_expect(gestures.haptic_events().size() >= 3, "cada fase emite haptica")


func _test_magazine_ammo() -> void:
	_case = "municion realista"
	var gestures = ReloadScript.new()
	gestures.begin("pistol", 8, 23, 3)
	_expect(gestures.magazine_rounds == 3 and gestures.chambered, "cargador con cuenta propia y uno en recamara")
	var drop: Dictionary = gestures.eject_magazine(Vector3(0.2, 0.4, 0.1))
	_expect(int(drop["rounds"]) == 3, "cargador gastado conserva sus 3 balas")
	_expect(gestures.magazine_rounds == 0, "arma sin cargador insertado")
	var dropped: Dictionary = gestures.dropped_magazine()
	_expect(Vector3(dropped["position"]).x > 0.0, "cargador cae como fisica en una posicion")
	_expect(gestures.pickup_magazine(), "se recoge el cargador")
	var well := Transform3D.IDENTITY
	_expect(gestures.insert_magazine(Transform3D.IDENTITY, well), "se inserta el cargador recogido")
	_expect(gestures.magazine_rounds == 3, "se recupera la cuenta del cargador recogido")
	_expect(gestures.reserve == 23, "recoger el mismo cargador no gasta reserva")
	_expect(not gestures.can_fire(), "sin montar no dispara")
	_expect(gestures.rack_slide(0.10, true), "montar arma")
	_expect(gestures.can_fire(), "montada puede disparar")
	_expect(gestures.fire() and not gestures.chambered, "disparo saca cartucho de la recamara")
	_expect(gestures.magazine_rounds == 2, "el disparo no toma del cargador hasta el siguiente montaje")
	_expect(gestures.rack_slide(0.10, true), "recamar siguiente cartucho")
	_expect(gestures.magazine_rounds == 1 and gestures.chambered, "cargador baja al recamar")
	var fresh = ReloadScript.new()
	fresh.begin("pistol", 8, 23, 0)
	fresh.eject_magazine()
	_expect(fresh.pickup_magazine(), "recoger cargador vacio")
	_expect(fresh.insert_magazine(Transform3D.IDENTITY, Transform3D.IDENTITY), "insertar cargador nuevo")
	_expect(fresh.reserve == 15 and fresh.magazine_rounds == 8, "la reserva baja al meter cargador lleno")


func _test_tolerance() -> void:
	_case = "tolerancia de insercion"
	_expect(ReloadScript.aligned(Transform3D.IDENTITY, Transform3D.IDENTITY, 0.05, 20.0), "alineado perfecto")
	var tilted := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(45.0)), Vector3.ZERO)
	_expect(not ReloadScript.aligned(tilted, Transform3D.IDENTITY, 0.05, 20.0), "angulo excesivo rechazado")
	var displaced := Transform3D(Basis.IDENTITY, Vector3(0.2, 0.0, 0.0))
	_expect(not ReloadScript.aligned(displaced, Transform3D.IDENTITY, 0.05, 20.0), "distancia excesiva rechazada")
	var gestures = ReloadScript.new()
	gestures.begin("pistol", 8, 23, 0)
	gestures.eject_magazine()
	_expect(not gestures.insert_magazine(tilted, Transform3D.IDENTITY), "cargador desalineado falla")
	_expect(gestures.phase() == "insert", "fase no avanza con desalineacion")
	var events: Array = gestures.events()
	_expect(_has_event(events, "magazine_misaligned"), "se notifica el fallo de alineacion")
	_expect(gestures.insert_magazine(Transform3D.IDENTITY, Transform3D.IDENTITY), "cargador alineado tras corregir")
	_expect(gestures.phase() == "chamber", "fase avanza al corregir")


func _test_chamber() -> void:
	_case = "recamara y vainas"
	var gestures = ReloadScript.new()
	gestures.begin("pistol", 8, 10, 5)
	gestures.set_ready()
	_expect(gestures.rack_slide(0.12, true), "montar pistola ya cargada")
	var events: Array = gestures.events()
	_expect(_has_event(events, "casing_ejected"), "si habia cartucho se expulsa la vaina")
	_expect(gestures.chambered, "se mete un cartucho nuevo")
	_expect(gestures.magazine_rounds == 4, "el cartucho nuevo sale del cargador")
	_expect(gestures.rack_slide(0.01, true) == false, "tiron corto no monta")
	var empty = ReloadScript.new()
	empty.begin("pistol", 8, 0, 0)
	_expect(not empty.rack_slide(0.12, true), "sin municion no se puede montar")
	_expect(not empty.can_fire(), "sin municion no dispara")


func _test_shotgun() -> void:
	_case = "escopeta cartucho a cartucho"
	var gestures = ReloadScript.new()
	gestures.begin("shotgun", 2, 8, 0, 2)
	_expect(gestures.is_shotgun(), "tipo de arma detectado")
	_expect(not gestures.rack_slide(0.15, true), "escopeta no usa corredera")
	_expect(gestures.load_shell(), "primer cartucho")
	_expect(gestures.reserve == 7, "la reserva baja por cartucho")
	_expect(gestures.load_shell(), "segundo cartucho")
	_expect(gestures.phase() == "pump", "bombeo despues de los cartuchos")
	_expect(not gestures.pump_action(-0.1), "solo ida no completa el bombeo")
	_expect(gestures.pump_action(0.1), "bombeo completo")
	var events: Array = gestures.events()
	_expect(_has_event(events, "shell_ejected"), "vaina expulsada fisicamente al bombear")
	_expect(gestures.is_complete(), "escopeta lista tras bombear")


func _test_bolt() -> void:
	_case = "francotirador de cerrojo"
	var gestures = ReloadScript.new()
	gestures.begin("sniper_rifle", 5, 12, 3)
	_expect(gestures.is_bolt_weapon(), "tipo de cerrojo detectado")
	_expect(gestures.open_bolt(), "abrir cerrojo")
	_expect(not gestures.chambered, "recamara vacia tras abrir")
	_expect(_has_event(gestures.events(), "casing_ejected"), "vaina expulsada al abrir")
	_expect(gestures.load_round(), "meter cartucho")
	_expect(not gestures.can_fire(), "cerrojo abierto no dispara")
	_expect(gestures.close_bolt(), "cerrar cerrojo")
	_expect(gestures.can_fire(), "cerrojo cerrado y recamada dispara")
	_expect(gestures.magazine_rounds == 2, "cartucho tomado del cargador")


func _test_cancel_and_safety() -> void:
	_case = "cancelacion y tope de seguridad"
	var gestures = ReloadScript.new()
	gestures.begin("assault_rifle", 30, 60)
	gestures.eject_magazine()
	_expect(gestures.magazine_rounds == 0, "cargador fuera")
	gestures.cancel("cambio_de_arma")
	_expect(gestures.is_complete(), "cancelar devuelve estado consistente")
	_expect(gestures.magazine_rounds == 30, "cargador restaurado al cancelar")
	_expect(gestures.can_fire(), "arma util tras cancelar")
	var slow = ReloadScript.new()
	slow.begin("pistol", 8, 20, 0)
	var aborted: bool = false
	for i in 14:
		if slow.safety_tick(1.0):
			aborted = true
			break
	_expect(aborted, "tope de seguridad dispara el abortar")
	_expect(slow.is_complete(), "aborto seguro deja fase consistente")
	var extreme = ReloadScript.new()
	extreme.begin("shotgun", 2, 8, 0, 2)
	extreme.safety_tick(1.0e12)
	_expect(extreme.is_complete() or extreme.phase() != "", "delta extremo no corrompe la fase")
	var hand_velocity: Vector3 = GrabScript.throw_velocity(
		Transform3D.IDENTITY, Transform3D(Basis.IDENTITY, Vector3(-1.0, 0.0, 0.0)), NAN
	)
	_expect(not is_nan(hand_velocity.x) and not is_inf(hand_velocity.x), "lanzamiento con delta NaN no propaga NaN")
