extends SceneTree

const HandScript = preload("res://core/vr/vr_weapon_hand.gd")
const WsScript = preload("res://core/game/weapon_system.gd")
const ModeScript = preload("res://core/vr/vr_game_mode.gd")

class Provider extends RefCounted:
	var poses: Dictionary = {
		"right": Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)),
		"left": Transform3D(Basis.IDENTITY, Vector3(0, 1, -0.2)),
	}
	var grips: Dictionary = {"right": true, "left": false}
	func get_pose(h: String) -> Transform3D:
		return poses[h]
	func is_grip_pressed(h: String) -> bool:
		return grips[h]
	func is_trigger_pressed(_h: String) -> bool:
		return false

var _n := 0
var _fail := 0


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _initialize() -> void:
	await process_frame
	_weapon_system_cycle()
	_hand_cycle_gesture()
	_hand_reload_gestures()
	await _game_mode_defaults()
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)


func _make(id: String):
	var ws = WsScript.new()
	ws.manual_cycle = true
	var hand = HandScript.new()
	hand.weapon_id = id
	hand.auto_process = false
	hand.fx_via_viewmodel = false
	hand.manual_gesture_reload = true
	var prov = Provider.new()
	hand.input_provider = prov
	root.add_child(hand)
	hand.bind_weapon_system(ws)
	return [hand, ws, prov]


func _weapon_system_cycle() -> void:
	var ws = WsScript.new()
	var cycles: Array = []
	ws.cycled.connect(func(id): cycles.append(id))
	for id in ["shotgun", "sniper_rifle"]:
		ws.manual_cycle = true
		ws.advance(5.0)
		_expect(bool(ws.fire(id, Vector3.ZERO, Vector3.FORWARD, null, []).get("fired", false)) == false, "sin espacio no dispara (%s)" % id)
	var space = root.get_world_3d().direct_space_state
	ws.advance(5.0)
	_expect(bool(ws.fire("shotgun", Vector3.ZERO, Vector3.FORWARD, space, []).get("fired", false)), "primer tiro de escopeta")
	ws.advance(5.0)
	_expect(ws.needs_cycle("shotgun") and not ws.can_fire("shotgun"), "escopeta exige bombeo")
	_expect(ws.fire_block_reason("shotgun") == ws.CYCLE_REASON and ws.fire_block_reason("shotgun").find("municion") < 0, "motivo: montar arma")
	_expect(not ws.cycle_stroke("shotgun", 0.0), "sin movimiento no bombea")
	ws.cycle_stroke("shotgun", -0.1)
	_expect(ws.cycle_stroke("shotgun", 0.0) and ws.can_fire("shotgun"), "atras y adelante = bombeo, vuelve a disparar")
	_expect(cycles == ["shotgun"], "senal cycled")
	ws.advance(5.0)
	ws.fire("sniper_rifle", Vector3.ZERO, Vector3.FORWARD, space, [])
	_expect(ws.needs_cycle("sniper_rifle") and ws.cycle("sniper_rifle") and not ws.cycle("sniper_rifle"), "cerrojo por boton/toque")
	ws.advance(5.0)
	ws.fire("pistol", Vector3.ZERO, Vector3.FORWARD, space, [])
	_expect(not ws.needs_cycle("pistol"), "el resto de armas siguen igual")
	ws.manual_cycle = false
	ws.advance(5.0)
	ws.fire("shotgun", Vector3.ZERO, Vector3.FORWARD, space, [])
	_expect(not ws.needs_cycle("shotgun"), "modo automatico: sin bombeo")
	ws.manual_cycle = true
	ws.set_ammo("shotgun", 1, 10)
	ws.advance(5.0)
	ws.fire("shotgun", Vector3.ZERO, Vector3.FORWARD, space, [])
	_expect(not ws.needs_cycle("shotgun"), "ultimo cartucho: nada que montar")
	ws.free()


func _hand_cycle_gesture() -> void:
	var t = _make("shotgun")
	var hand = t[0]
	var ws = t[1]
	var prov = t[2]
	var space = root.get_world_3d().direct_space_state
	ws.advance(5.0)
	_expect(bool(hand.try_fire(space).get("fired", false)), "VR: disparo de escopeta")
	_expect(ws.needs_cycle("shotgun"), "VR: bombeo pendiente")
	prov.grips["left"] = true
	var rest: float = hand.handguard_offset("shotgun")
	prov.poses["left"] = Transform3D(Basis.IDENTITY, Vector3(0, 1, -rest))
	hand.step(0.016)
	prov.poses["left"] = Transform3D(Basis.IDENTITY, Vector3(0, 1, -rest + 0.1))
	hand.step(0.016)
	_expect(ws.needs_cycle("shotgun"), "VR: solo atras no completa")
	prov.poses["left"] = Transform3D(Basis.IDENTITY, Vector3(0, 1, -rest))
	hand.step(0.016)
	_expect(not ws.needs_cycle("shotgun") and hand.last_haptic["hand"] == "left", "VR: mano libre atras y adelante bombea con haptica")
	hand.queue_free()
	ws.free()


func _hand_reload_gestures() -> void:
	var t = _make("pistol")
	var hand = t[0]
	var ws = t[1]
	var prov = t[2]
	ws.set_ammo("pistol", 12, 36)
	var well := Vector3(0, 1 - 0.16, 0.0 - 0.04)
	prov.poses["left"] = Transform3D(Basis.IDENTITY, well)
	prov.grips["left"] = true
	hand.step(0.016)
	_expect(hand.reload_system.active and hand.reload_phase() == "insert", "gesto inicia la recarga y suelta el cargador")
	_expect(not ws.can_fire("pistol") and hand.reload_system.dropped_magazines.size() == 1, "bloqueada y cargador caido")
	hand.step(0.016)
	_expect(hand.reload_phase() == "insert", "mano quieta en la zona no inserta sin soltar antes")
	prov.grips["left"] = false
	prov.poses["left"] = Transform3D(Basis.IDENTITY, Vector3(0.3, 0.8, 0.3))
	hand.step(0.016)
	prov.grips["left"] = true
	prov.poses["left"] = Transform3D(Basis(Vector3.UP, deg_to_rad(80.0)), well)
	hand.step(0.016)
	_expect(hand.reload_phase() == "insert", "cargador desalineado no entra")
	prov.poses["left"] = Transform3D(Basis.IDENTITY, well)
	hand.step(0.016)
	_expect(hand.reload_phase() == "chamber", "cargador alineado entra")
	_expect(not bool(hand.try_fire(root.get_world_3d().direct_space_state).get("fired", false)), "sin montar no dispara")
	prov.grips["left"] = false
	hand.step(0.016)
	prov.grips["left"] = true
	prov.poses["left"] = Transform3D(Basis.IDENTITY, Vector3(0, 1, -0.3))
	hand.step(0.016)
	prov.poses["left"] = Transform3D(Basis.IDENTITY, Vector3(0, 1, -0.15))
	hand.step(0.016)
	prov.grips["left"] = false
	hand.step(0.016)
	_expect(not hand.reload_system.active and not hand.manual_reload_active, "tirar de la corredera y soltar monta")
	ws.advance(5.0)
	_expect(ws.can_fire("pistol") and ws.ammo("pistol") == 12, "arma lista tras recargar: %d" % ws.ammo("pistol"))
	hand.queue_free()
	ws.free()


func _game_mode_defaults() -> void:
	ModeScript.xr_available_override = func() -> bool: return true
	var world := Node3D.new()
	root.add_child(world)
	var rig = ModeScript.build(world, true)
	var result: Dictionary = ModeScript.setup(world, rig, {"seed": 1, "ok": true})
	var ws = result["weapon_system"]
	_expect(ws.manual_cycle, "VrGameMode: ciclo manual por defecto")
	for hand in [rig.left_hand, rig.right_hand]:
		_expect(hand.manual_gesture_reload and hand.reload_system != null and hand.reload_system.weapon_system == ws, "VrGameMode: recarga por gestos activa en la mano")
	world.free()
	ModeScript.xr_available_override = Callable()
	await process_frame
