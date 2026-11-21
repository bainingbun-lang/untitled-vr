extends SceneTree

const WeaponSystemScript = preload("res://core/game/weapon_system.gd")
const DamageableScript = preload("res://core/game/damageable.gd")

var _failures: Array = []
var _checks := 0
var _case := ""
var _root: Node3D = null
var _space = null

func _initialize() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	await process_frame
	await process_frame
	_space = _root.get_world_3d().direct_space_state

	_case = "weapon_system.modo_disparo_y_impacto"
	var ws = WeaponSystemScript.new()
	_root.add_child(ws)
	await process_frame
	await process_frame
	var body = _make_target(Vector3(0.0, 0.0, 0.0), "chest", 1.0)
	await process_frame
	await process_frame
	ws.advance(1.0)
	var shot = ws.fire("pistol", Vector3(0.0, 0.0, 5.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_expect(bool(shot.get("hit", false)), "pistol impacta objetivo estatico")
	_expect(shot.get("collider") == body["body"], "colision con cuerpo esperado")
	_expect(float(body["damageable"].health) < 100.0, "dano aplicado al objetivo")

	_case = "weapon_system.cadencia_por_arma"
	var ws2 = WeaponSystemScript.new()
	_root.add_child(ws2)
	await process_frame
	await process_frame
	var origin := Vector3(0.0, 100.0, 0.0)
	var f1 = ws2.fire("pistol", origin, Vector3.UP, _space, [])
	_expect(bool(f1.get("fired", false)), "primer disparo permitido")
	var f2 = ws2.fire("pistol", origin, Vector3.UP, _space, [])
	_expect(not bool(f2.get("fired", false)), "segundo disparo bloqueado por cadencia")
	var err2 := str(f2.get("error", ""))
	_expect(err2.find("cadencia") >= 0 or err2.find("cooldown") >= 0, "motivo de cadencia informado")
	ws2.advance(0.5)
	var f4 = ws2.fire("pistol", origin, Vector3.UP, _space, [])
	_expect(bool(f4.get("fired", false)), "disparo permitido tras intervalo suficiente")

	_case = "weapon_system.cargador_y_recarga"
	var ws3 = WeaponSystemScript.new()
	_root.add_child(ws3)
	await process_frame
	await process_frame
	ws3.set_ammo("pistol", 2, 5)
	_expect(int(ws3.ammo("pistol")) == 2, "cargador configurado a 2")
	ws3.fire("pistol", origin, Vector3.UP, _space, [])
	ws3.advance(0.2)
	ws3.fire("pistol", origin, Vector3.UP, _space, [])
	_expect(int(ws3.ammo("pistol")) == 0, "cargador vacio tras dos disparos")
	var empty = ws3.fire("pistol", origin, Vector3.UP, _space, [])
	_expect(not bool(empty.get("fired", false)), "sin municion no dispara")
	var err_empty := str(empty.get("error", ""))
	_expect(err_empty.find("municion") >= 0 or err_empty.find("ammo") >= 0, "motivo de municion informado")
	var reloaded = ws3.reload("pistol")
	_expect(bool(reloaded), "recarga iniciada cuando hay reserva")
	_expect(bool(ws3.is_reloading("pistol")), "estado recargando despues de iniciar")
	ws3.advance(1.2)
	_expect(not bool(ws3.is_reloading("pistol")), "recarga terminada despues de avance")
	_expect(int(ws3.ammo("pistol")) > 0, "cargador rellenado despues de recarga")
	_expect(int(ws3.reserve("pistol")) == 0, "reserva consumida por recarga")

	_case = "weapon_system.arma_desconocida"
	var ws4 = WeaponSystemScript.new()
	_root.add_child(ws4)
	await process_frame
	await process_frame
	var bad = ws4.fire("no_existe_arma", origin, Vector3.UP, _space, [])
	_expect(not bool(bad.get("fired", false)), "arma desconocida no dispara")
	_expect(not bool(bad.get("hit", false)), "arma desconocida sin impacto")
	var err_bad := str(bad.get("error", ""))
	_expect(err_bad.find("no_existe") >= 0 or err_bad.find("desconoc") >= 0, "error de arma desconocida informado")
	_expect(not bool(ws4.can_fire("no_existe_arma")), "no puede disparar arma desconocida")
	_expect(not bool(ws4.reload("no_existe_arma")), "no puede recargar arma desconocida")

	_case = "weapon_system.arma_cuerpo_a_cuerpo_sin_municion"
	var ws5 = WeaponSystemScript.new()
	_root.add_child(ws5)
	await process_frame
	await process_frame
	_expect(int(ws5.ammo("bat")) == -1, "arma cuerpo a cuerpo reporta -1 de municion")
	_expect(bool(ws5.fire("bat", origin, Vector3.UP, _space, []).get("fired", false)), "bate dispara sin cargador")

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for f in _failures:
			print("FAIL: " + f)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _make_target(pos: Vector3, zone: String, size: float) -> Dictionary:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, size, size)
	shape.shape = box
	body.add_child(shape)
	var damageable := DamageableScript.new()
	damageable.health = 100.0
	damageable.max_health = 100.0
	body.add_child(damageable)
	if not zone.is_empty():
		body.set_meta("hit_zone", zone)
	_root.add_child(body)
	return {"body": body, "damageable": damageable}

func _expect(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures.append("[%s] %s" % [_case, msg])
