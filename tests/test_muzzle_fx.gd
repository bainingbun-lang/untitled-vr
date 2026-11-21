extends SceneTree

const MuzzleFxScript = preload("res://core/game/muzzle_fx.gd")

var _failures: Array = []
var _checks := 0
var _case := ""
var _fx: Node3D = null
var _holder: Node3D = null

func _initialize() -> void:
	_holder = Node3D.new()
	root.add_child(_holder)
	await process_frame
	await process_frame
	_fx = MuzzleFxScript.new()
	_holder.add_child(_fx)
	await process_frame
	await process_frame

	_case = "muzzle_fx.disparo_crea_efectos"
	MuzzleFxScript.clear()
	var before_casings := MuzzleFxScript.casing_count()
	var before_smoke := MuzzleFxScript.smoke_count()
	var before_flashes := MuzzleFxScript.flash_count()
	_fx.fire(1.0, Vector3.FORWARD, Vector3.ZERO)
	await process_frame
	await process_frame
	_expect(MuzzleFxScript.casing_count() > before_casings, "se crea al menos una vaina al disparar")
	_expect(MuzzleFxScript.flash_count() > before_flashes, "se crea al menos un destello al disparar")
	_expect(MuzzleFxScript.smoke_count() > before_smoke, "se crea humo al disparar")

	_case = "muzzle_fx.tope_de_vainas"
	MuzzleFxScript.clear()
	for i in range(40):
		_fx.fire(1.0, Vector3.FORWARD, Vector3.ZERO)
		await process_frame
	_expect(MuzzleFxScript.casing_count() <= MuzzleFxScript.MAX_CASINGS, "vainas no exceden MAX_CASINGS (%d)" % MuzzleFxScript.MAX_CASINGS)

	_case = "muzzle_fx.tope_de_destellos"
	MuzzleFxScript.clear()
	for i in range(20):
		_fx.fire(1.0, Vector3.FORWARD, Vector3.ZERO)
		await process_frame
	_expect(MuzzleFxScript.flash_count() <= MuzzleFxScript.MAX_FLASHES, "destellos no exceden MAX_FLASHES (%d)" % MuzzleFxScript.MAX_FLASHES)

	_case = "muzzle_fx.tope_de_humo"
	MuzzleFxScript.clear()
	for i in range(15):
		_fx.fire(1.0, Vector3.FORWARD, Vector3.ZERO)
		await process_frame
	_expect(MuzzleFxScript.smoke_count() <= MuzzleFxScript.MAX_SMOKE, "humo no excede MAX_SMOKE (%d)" % MuzzleFxScript.MAX_SMOKE)

	_case = "muzzle_fx.reciclaje_de_vainas"
	MuzzleFxScript.clear()
	var initial_casings := MuzzleFxScript.casing_count()
	for i in range(50):
		_fx.fire(1.0, Vector3.FORWARD, Vector3.ZERO)
		await process_frame
	_expect(MuzzleFxScript.casing_count() <= MuzzleFxScript.MAX_CASINGS, "vainas recicladas al llenarse el pool")
	var oldest := MuzzleFxScript.casing_at(0)
	_expect(oldest != null, "se puede obtener vaina por indice")

	_case = "muzzle_fx.clear_libera_piscinas"
	MuzzleFxScript.clear()
	_expect(MuzzleFxScript.active_casing_count() == 0, "clear vacia vainas activas")
	_expect(MuzzleFxScript.flash_count() == 0, "clear vacia destellos")
	_expect(MuzzleFxScript.smoke_count() == 0, "clear vacia humo")

	MuzzleFxScript.shutdown()
	_holder.free()
	root.remove_child(_holder)

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for f in _failures:
			print("FAIL: " + f)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _expect(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures.append("[%s] %s" % [_case, msg])
