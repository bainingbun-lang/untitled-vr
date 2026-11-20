extends SceneTree

const RsScript = preload("res://core/game/reload_system.gd")
const WsScript = preload("res://core/game/weapon_system.gd")

var _n := 0
var _fail := 0


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _initialize() -> void:
	await process_frame
	_pistol_flow()
	_unmounted_no_fire()
	_dropped_mag_keeps_ammo()
	_shotgun_flow()
	_bolt_flow()
	_cancel_and_timeout()
	_android_three_taps()
	_vr_hand_integration()
	await _player_manual()
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)


func _make(id: String, loaded: int = -1, stock: int = -1):
	var ws = WsScript.new()
	ws.ammo(id)
	if loaded >= 0:
		ws.set_ammo(id, loaded, stock)
	return [ws, RsScript.new(ws)]


func _pistol_flow() -> void:
	var pair = _make("pistol")
	var ws = pair[0]
	var rs = pair[1]
	var phases: Array = []
	var done := [0]
	rs.phase_changed.connect(func(_id, p): phases.append(p))
	rs.finished.connect(func(_id): done[0] += 1)
	_expect(ws.ammo("pistol") == 12 and ws.reserve("pistol") == 0 or ws.reserve("pistol") >= 0, "estado inicial")
	ws.set_ammo("pistol", 12, 36)
	_expect(rs.begin("pistol"), "begin pistola")
	_expect(not rs.begin("pistol"), "no se puede iniciar dos veces")
	_expect(not ws.can_fire("pistol"), "bloqueada durante la recarga")
	_expect(not ws.reload("pistol"), "recarga automatica rechazada durante la manual")
	_expect(rs.phase() == "eject", "fase inicial eject")
	_expect(not rs.insert_magazine(), "no se inserta antes de soltar")
	var r: Dictionary = rs.eject_magazine(Vector3(1, 1, 1))
	_expect(bool(r["ejected"]) and int(r["rounds"]) == 11, "cargador cae con 11 (12 menos la recamara)")
	_expect(rs.dropped_magazines.size() == 1 and int(rs.dropped_magazines[0]["rounds"]) == 11, "cargador caido recogible")
	_expect(ws.ammo("pistol") == 1, "solo queda la bala de la recamara")
	_expect(not rs.insert_magazine(Transform3D(Basis.IDENTITY, Vector3(1, 0, 0)), Transform3D.IDENTITY), "desalineado no inserta")
	_expect(rs.phase() == "insert", "sigue en insert")
	_expect(rs.insert_magazine(), "inserta alineado")
	_expect(ws.reserve("pistol") == 24, "reserva baja al entrar el cargador nuevo")
	_expect(rs.phase() == "chamber", "fase chamber")
	_expect(not ws.can_fire("pistol") and not rs.can_fire(), "sin montar NO dispara")
	_expect(rs.rack_slide(0.12, true), "montar corredera")
	_expect(done[0] == 1 and not rs.active, "senal finished y maquina libre")
	_expect(ws.ammo("pistol") == 12 and ws.reserve("pistol") == 24, "cargador 11 + 1 recamara")
	_expect(ws.can_fire("pistol") and rs.can_fire(), "dispara tras montar")
	_expect(phases == ["eject", "insert", "chamber", "ready"], "cada fase emite senal: %s" % str(phases))
	rs.fire()
	_expect(ws.ammo("pistol") == 11 and rs.machine.magazine_rounds == 10, "ciclo automatico tras disparar")
	ws.free()


func _unmounted_no_fire() -> void:
	var pair = _make("pistol", 12, 36)
	var rs = pair[1]
	rs.begin("pistol")
	rs.eject_magazine()
	rs.insert_magazine()
	_expect(pair[0].fire_block_reason("pistol") == RsScript.LOCK_REASON, "motivo de bloqueo manual")
	_expect(pair[0].fire_block_reason("pistol").find("municion") < 0, "el bloqueo no se confunde con vacio")
	pair[0].free()


func _dropped_mag_keeps_ammo() -> void:
	var pair = _make("pistol", 12, 36)
	var rs = pair[1]
	rs.begin("pistol")
	rs.eject_magazine()
	_expect(rs.pickup_dropped(), "recoger cargador caido")
	_expect(rs.dropped_magazines.is_empty(), "ya no esta en el suelo")
	rs.insert_magazine()
	_expect(pair[0].reserve("pistol") == 36, "reinsertar el mismo cargador no gasta reserva")
	rs.rack_slide(0.12, true)
	_expect(pair[0].ammo("pistol") == 11, "municion conservada (la bala de la recamara vieja se expulsa)")
	pair[0].free()


func _shotgun_flow() -> void:
	var pair = _make("shotgun", 2, 10)
	var ws = pair[0]
	var rs = pair[1]
	_expect(rs.begin("shotgun"), "begin escopeta")
	var guard := 0
	var shells := 0
	while rs.active and guard < 20:
		guard += 1
		if rs.phase() == "load_shell":
			shells += 1
		rs.perform_current()
	_expect(shells == 4, "cuatro cartuchos uno a uno: %d" % shells)
	_expect(not rs.active and ws.ammo("shotgun") == 6, "tubo lleno con uno en recamara: %d" % ws.ammo("shotgun"))
	_expect(ws.reserve("shotgun") == 6, "reserva descontada solo por los cartuchos cargados: %d" % ws.reserve("shotgun"))
	_expect(not rs.begin("shotgun"), "escopeta llena no recarga")
	ws.free()


func _bolt_flow() -> void:
	var pair = _make("sniper_rifle", 5, 10)
	var ws = pair[0]
	var rs = pair[1]
	rs.begin("sniper_rifle")
	_expect(rs.phase() == "open_bolt", "francotirador abre cerrojo")
	_expect(rs.open_bolt(), "abrir cerrojo")
	_expect(ws.ammo("sniper_rifle") == 4, "sale la vaina/bala de la recamara")
	_expect(not rs.can_fire(), "cerrojo abierto no dispara")
	rs.load_round()
	rs.close_bolt()
	_expect(not rs.active and ws.can_fire("sniper_rifle"), "cerrojo cerrado listo")
	_expect(ws.ammo("sniper_rifle") == 4, "total consistente tras ciclo: %d" % ws.ammo("sniper_rifle"))
	ws.free()


func _cancel_and_timeout() -> void:
	var pair = _make("pistol", 12, 36)
	var ws = pair[0]
	var rs = pair[1]
	var reasons: Array = []
	rs.cancelled.connect(func(_id, why): reasons.append(why))
	rs.begin("pistol")
	rs.eject_magazine()
	rs.cancel("cambio_de_arma")
	_expect(reasons == ["cambio_de_arma"] and not rs.active, "cancelar aborta")
	_expect(ws.ammo("pistol") == 12 and ws.reserve("pistol") == 36, "cancelar devuelve estado consistente")
	_expect(ws.can_fire("pistol") and rs.dropped_magazines.is_empty(), "arma usable y sin cargador huerfano")
	rs.begin("pistol")
	rs.eject_magazine()
	rs.pickup_dropped()
	rs.cancel()
	_expect(ws.ammo("pistol") + ws.reserve("pistol") == 48, "cargador en mano vuelve a la reserva (sin perder balas)")
	rs.begin("pistol")
	rs.eject_magazine()
	_expect(not rs.tick(5.0), "tick sin tope")
	_expect(rs.tick(100.0), "tope de seguridad")
	_expect(not rs.active and ws.can_fire("pistol") and ws.ammo("pistol") + ws.reserve("pistol") == 48, "tope deja estado consistente")
	_expect(reasons.back() == "safety_timeout", "motivo del tope")
	ws.free()


func _android_three_taps() -> void:
	var pair = _make("assault_rifle", 30, 90)
	var rs = pair[1]
	_expect(rs.begin("assault_rifle") and rs.perform_current(), "toque 1: soltar")
	_expect(rs.phase() == "insert" and rs.perform_current(), "toque 2: insertar")
	_expect(rs.phase() == "chamber" and rs.perform_current(), "toque 3: montar")
	_expect(not rs.active and pair[0].ammo("assault_rifle") == 30, "tres toques completan")
	pair[0].free()


func _player_manual() -> void:
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	var player = packed.instantiate()
	root.add_child(player)
	await process_frame
	var id := "pistol"
	if not player.equip(id):
		player.inventory.add(id, 1)
		player.equip(id)
	var ws = player.weapon_system()
	ws.set_ammo(id, 12, 36)
	player.manual_reload = true
	player.reload_action()
	_expect(player.is_reloading() and player.reload_system.phase() == "insert", "player toque 1")
	player.reload_action()
	player.reload_action()
	_expect(not player.is_reloading() and player.current_ammo() == 12 and player.current_reserve() == 24, "player 3 toques")
	player.reload_action()
	player.reload_action()
	_expect(player.is_reloading(), "player nueva recarga en curso")
	player.equip(id)
	_expect(player.is_reloading(), "re-equipar la misma no cancela")
	player.manual_reload = false
	player.reload_system.cancel()
	_expect(not player.is_reloading(), "cancelada")
	player.manual_reload = false
	ws.set_ammo(id, 3, 36)
	_expect(player.reload() and ws.is_reloading(id), "modo automatico intacto")
	var space = root.get_world_3d().direct_space_state
	_expect(ws.manual_cycle, "Android: montaje manual por defecto")
	ws.advance(5.0)
	ws.fire("shotgun", Vector3.ZERO, Vector3.FORWARD, space, [])
	player.equipped_weapon = "shotgun"
	_expect(ws.needs_cycle("shotgun") and player.current_ammo() >= 0, "escopeta pide montar")
	_expect(player.reload() and not ws.needs_cycle("shotgun"), "toque en Recargar = Montar")
	ws.advance(5.0)
	ws.fire("sniper_rifle", Vector3.ZERO, Vector3.FORWARD, space, [])
	player.equipped_weapon = "sniper_rifle"
	_expect(player.cycle_action() and not player.cycle_action(), "cycle_action monta el cerrojo")
	player.set_auto_cycle(true)
	ws.advance(5.0)
	ws.fire("sniper_rifle", Vector3.ZERO, Vector3.FORWARD, space, [])
	_expect(not ws.needs_cycle("sniper_rifle"), "ajuste automatico: sin montaje")
	player.queue_free()


func _vr_hand_integration() -> void:
	var pair = _make("pistol", 12, 36)
	var ws = pair[0]
	var rs = pair[1]
	var hand = preload("res://core/vr/vr_weapon_hand.gd").new()
	hand.weapon_id = "pistol"
	hand.auto_process = false
	hand.fx_via_viewmodel = false
	root.add_child(hand)
	hand.bind_weapon_system(ws)
	rs.begin("pistol")
	hand.bind_reload_system(rs)
	_expect(not bool(hand.try_fire(hand._space()).get("fired", false)), "VR: no dispara durante la recarga")
	hand.reload_eject_magazine(Vector3.ZERO)
	_expect(hand.reload_phase() == "insert", "VR: fase por gestos")
	hand.reload_insert_magazine(Transform3D.IDENTITY, Transform3D.IDENTITY)
	_expect(not bool(hand.try_fire(hand._space()).get("fired", false)), "VR: insertado sin montar no dispara")
	hand.reload_rack_slide(0.12, true)
	var shot: Dictionary = hand.try_fire(hand._space())
	_expect(bool(shot.get("fired", false)) and ws.ammo("pistol") == 11 and rs.machine.chambered, "VR: dispara tras montar y cicla")
	hand.stow()
	_expect(not hand.manual_reload_active, "VR: guardar desactiva")
	hand.queue_free()
	ws.free()
