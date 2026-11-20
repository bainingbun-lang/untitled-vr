extends SceneTree

const HandScript = preload("res://core/vr/vr_weapon_hand.gd")
const WsScript = preload("res://core/game/weapon_system.gd")
const FxScript = preload("res://core/game/muzzle_fx.gd")

class FakeProvider extends RefCounted:
	func get_pose(_hand: String) -> Transform3D:
		return Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
	func is_grip_pressed(_hand: String) -> bool:
		return false
	func is_trigger_pressed(_hand: String) -> bool:
		return false

var _n := 0
var _fail := 0
var _pulses: Array = []


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _initialize() -> void:
	await process_frame
	_trigger_step()
	_climb_and_hands()
	_burst_cap()
	_blocked()
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)


func _make(id: String, two: bool = false):
	var ws = WsScript.new()
	var hand = HandScript.new()
	hand.weapon_id = id
	hand.auto_process = false
	hand.fx_via_viewmodel = false
	hand.input_provider = FakeProvider.new()
	root.add_child(hand)
	hand.bind_weapon_system(ws)
	hand._two_hand = two
	return [hand, ws]


func _dispose(pair: Array) -> void:
	pair[0].queue_free()
	pair[1].free()


func _trigger_step() -> void:
	var pair = _make("pistol")
	var hand = pair[0]
	_pulses.clear()
	hand.haptic.connect(func(h, d, f, a): _pulses.append(h))
	var flashes: int = FxScript.flash_count()
	var casings: int = FxScript.casing_count()
	var shot: Dictionary = hand.try_fire(hand._space())
	_expect(bool(shot.get("fired", false)), "el disparo sale")
	var order: Array = []
	var frames: Dictionary = {}
	for e in hand.shot_trace:
		order.append(e["step"])
		frames[e["frame"]] = true
	_expect(order == ["ammo", "recoil", "haptic", "muzzle_fx", "sound", "casing", "fire"], "orden de pasos: %s" % str(order))
	_expect(frames.size() == 1, "todo en el mismo paso de proceso")
	_expect(hand.recoil.pitch() > 0.0, "impulso de VrRecoil aplicado al arma")
	_expect(not _pulses.is_empty() and _pulses[0] == "right", "pulso haptico en la mano principal")
	_expect(FxScript.flash_count() > flashes, "fogonazo creado")
	_expect(FxScript.casing_count() > casings, "vaina expulsada")
	_expect(float(shot["camera_shake"]) == 0.0, "sin sacudida de camara en VR")
	_expect(shot["direction"].is_equal_approx(Vector3.FORWARD), "primer disparo sin climb previo")
	_expect(hand.last_haptic.has("amplitude"), "haptica registrada")
	hand.recoil.step(0.05)
	_expect(hand.recoil.kick().length() > 0.0 and hand.recoil.weapon_offset().origin.z > 0.0, "el arma retrocede respecto a la palma")
	_dispose(pair)


func _angle_after(id: String, two: bool, shots: int) -> Array:
	var pair = _make(id, two)
	var hand = pair[0]
	var ws = pair[1]
	var last: Dictionary = {}
	for i in shots:
		ws.advance(1.0)
		last = hand.try_fire(hand._space())
	var angle: float = rad_to_deg((last["direction"] as Vector3).angle_to(Vector3.FORWARD))
	var pitch: float = hand.recoil.pitch()
	_dispose(pair)
	return [angle, pitch]


func _climb_and_hands() -> void:
	var one: Array = _angle_after("assault_rifle", false, 3)
	var two: Array = _angle_after("assault_rifle", true, 3)
	_expect(one[0] > 0.0, "la siguiente punteria difiere por el climb (%.3f grados)" % one[0])
	_expect(two[1] < one[1], "dos manos reduce el climb (%.4f < %.4f)" % [two[1], one[1]])
	_expect(two[0] < one[0], "dos manos reduce el desvio de la punteria")
	var pair = _make("assault_rifle", true)
	_pulses.clear()
	pair[0].haptic.connect(func(h, d, f, a): _pulses.append(h))
	pair[0].try_fire(pair[0]._space())
	_expect(_pulses.has("left"), "la mano de apoyo recibe una fraccion de haptica")
	_dispose(pair)


func _burst_cap() -> void:
	var pair = _make("assault_rifle")
	var hand = pair[0]
	var ws = pair[1]
	var prev := 0.0
	var grew := true
	for i in 25:
		ws.advance(0.12)
		hand.try_fire(hand._space())
		hand.recoil.step(0.12)
		if i < 3 and hand.recoil.pitch() <= prev:
			grew = false
		prev = hand.recoil.pitch()
	_expect(grew, "la rafaga acumula climb")
	var cap: float = float(hand.recoil.PROFILES["assault_rifle"]["cap"])
	_expect(hand.recoil.pitch() <= cap + 0.000001, "la rafaga tiene tope (%.3f <= %.3f)" % [hand.recoil.pitch(), cap])
	var peak: float = hand.recoil.pitch()
	_expect(peak > 0.0 and ws.ammo("assault_rifle") > 0, "la rafaga sigue activa")
	hand.recoil.end_burst()
	for i in 20:
		hand.recoil.step(0.1)
	_expect(hand.recoil.pitch() < peak * 0.2, "tras soltar el gatillo el arma se recupera")
	_dispose(pair)


func _blocked() -> void:
	var pair = _make("pistol")
	var hand = pair[0]
	pair[1].set_ammo("pistol", 0, 10)
	var shot: Dictionary = hand.try_fire(hand._space())
	_expect(not bool(shot.get("fired", false)), "sin municion no dispara")
	_expect(hand.shot_trace.size() == 1 and hand.shot_trace[0]["step"] == "ammo", "sin municion no hay efectos")
	_expect(hand.recoil.pitch() == 0.0, "sin municion no hay retroceso")
	_dispose(pair)
