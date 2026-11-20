extends SceneTree

const WeaponsDbScript = preload("res://core/game/weapon_db.gd")
const ItemDbScript = preload("res://core/game/item_db.gd")
const DamageableScript = preload("res://core/game/damageable.gd")
const WeaponSystemScript = preload("res://core/game/weapon_system.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const GAME_SESSION_PATH := "res://core/game/game_session.gd"

var _failures: Array = []
var _checks := 0
var _case := ""
var _deaths := 0
var _damage_events := 0
var _root: Node3D = null
var _sys = null
var _space = null
var _gore_holder: Node3D = null


func _initialize() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	_sys = WeaponSystemScript.new()
	_root.add_child(_sys)
	_gore_holder = Node3D.new()
	_root.add_child(_gore_holder)
	await process_frame
	await process_frame
	_space = _root.get_world_3d().direct_space_state

	_case = "base de datos de armas"
	var weapons: Dictionary = WeaponsDbScript.all()
	_expect(weapons.size() >= 6, "debe haber al menos 6 armas")
	for required in ["pistol", "submachine_gun", "assault_rifle", "shotgun", "sniper_rifle", "bat"]:
		_expect(weapons.has(required), "arma disponible: %s" % required)
		var def: Dictionary = weapons.get(required, {})
		for key in ["id", "name", "damage", "fire_rate", "range", "mag", "auto", "spread", "pellets", "tags"]:
			_expect(def.has(key), "campo %s en %s" % [key, required])
		_expect(str(def.get("id", "")) == str(required), "id coherente en %s" % required)
	_expect(int(WeaponsDbScript.get_def("shotgun")["pellets"]) >= 4, "escopeta con varios pellets")
	_expect(float(WeaponsDbScript.get_def("sniper_rifle")["damage"]) > float(WeaponsDbScript.get_def("pistol")["damage"]), "francotirador mas potente que pistola")
	_expect(float(WeaponsDbScript.get_def("bat")["range"]) < 5.0, "cuerpo a cuerpo con alcance corto")
	_expect(WeaponsDbScript.get_def("ghost").is_empty(), "arma desconocida sin definicion")
	var editable: Dictionary = WeaponsDbScript.all()
	editable["pistol"]["damage"] = 999.0
	_expect_eq(float(WeaponsDbScript.get_def("pistol")["damage"]), 24.0, "all devuelve copias")

	var item_db := ItemDbScript.new()
	WeaponsDbScript.register_items(item_db)
	for id in WeaponsDbScript.list_ids():
		_expect(item_db.has(id), "arma registrada como item: %s" % id)
		var item_def: Dictionary = item_db.get_def(id)
		_expect((item_def.get("tags", []) as Array).has("weapon"), "tag weapon en %s" % id)
		_expect(not bool(item_def.get("apilable", true)), "arma no apilable: %s" % id)
	_expect_eq(item_db.list().size(), WeaponsDbScript.list_ids().size(), "todas las armas registradas")
	WeaponsDbScript.register_items(null)
	_expect(true, "registro con item_db nulo controlado")

	_case = "dano por disparos y muerte"
	var victim := _make_target(Vector3(-10.0, 0.0, 0.0), "head", 2.0)
	var victim_body: StaticBody3D = victim["body"]
	var victim_dmg = victim["damageable"]
	victim_dmg.died.connect(_on_died)
	victim_dmg.damaged.connect(_on_damaged)
	await process_frame
	await process_frame
	_expect_eq(victim_dmg.multiplier_for("head"), 2.0, "multiplicador de zona cabeza")
	_expect_eq(victim_dmg.multiplier_for("unknown_zone"), 1.0, "zona desconocida sin multiplicador")
	var shot: Dictionary = _sys.fire("pistol", Vector3(-10.0, 0.0, 8.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_expect(bool(shot["hit"]), "raycast impacta al objetivo")
	_expect(shot["collider"] == victim_body, "colision reportada")
	_expect_eq(victim_dmg.health, 52.0, "disparo con multiplicador de cabeza")
	_expect_eq(victim_dmg.last_zone, "head", "zona registrada en el objetivo")
	_expect_eq(_damage_events, 1, "senal damaged emitida")
	_sys.advance(0.2)
	_sys.fire("pistol", Vector3(-10.0, 0.0, 8.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_expect_eq(victim_dmg.health, 4.0, "segundo disparo deja 4 de vida")
	_expect_eq(_deaths, 0, "aun no muere")
	_sys.advance(0.2)
	_sys.fire("pistol", Vector3(-10.0, 0.0, 8.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_expect_eq(victim_dmg.health, 0.0, "salud a cero")
	_expect(victim_dmg.is_dead(), "objetivo muerto")
	_expect_eq(_deaths, 1, "senal died emitida una sola vez")
	_sys.advance(0.2)
	_sys.fire("pistol", Vector3(-10.0, 0.0, 8.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_expect_eq(_deaths, 1, "objetivo muerto no vuelve a emitir died")

	_case = "cadencia"
	var cad = WeaponSystemScript.new()
	var idle_origin := Vector3(0.0, 100.0, 0.0)
	var first: Dictionary = cad.fire("pistol", idle_origin, Vector3.UP, _space, [])
	_expect(bool(first["fired"]), "primer disparo permitido")
	var second: Dictionary = cad.fire("pistol", idle_origin, Vector3.UP, _space, [])
	_expect(not bool(second["fired"]), "segundo disparo bloqueado por cadencia")
	_expect(_mentions(str(second["error"]), "cadencia"), "motivo de cadencia informado")
	cad.advance(0.15)
	_expect(not bool(cad.fire("pistol", idle_origin, Vector3.UP, _space, [])["fired"]), "cadencia respeta intervalo")
	cad.advance(0.05)
	_expect(bool(cad.fire("pistol", idle_origin, Vector3.UP, _space, [])["fired"]), "disparo permitido tras intervalo")
	_expect(cad.fire("submachine_gun", idle_origin, Vector3.UP, _space, [])["fired"], "cadencia es por arma")

	_case = "cargador y recarga"
	cad.advance(1.0)
	cad.set_ammo("pistol", 2, 2)
	_expect_eq(cad.ammo("pistol"), 2, "cargador configurado")
	cad.fire("pistol", idle_origin, Vector3.UP, _space, [])
	cad.advance(0.2)
	cad.fire("pistol", idle_origin, Vector3.UP, _space, [])
	_expect_eq(cad.ammo("pistol"), 0, "cargador vacio")
	var empty: Dictionary = cad.fire("pistol", idle_origin, Vector3.UP, _space, [])
	_expect(not bool(empty["fired"]), "sin municion no dispara")
	_expect(_mentions(str(empty["error"]), "municion"), "motivo de municion informado")
	_expect(cad.reload("pistol"), "recarga iniciada")
	_expect(cad.is_reloading("pistol"), "estado recargando")
	var during: Dictionary = cad.fire("pistol", idle_origin, Vector3.UP, _space, [])
	_expect(not bool(during["fired"]), "no dispara mientras recarga")
	cad.advance(1.2)
	_expect(not cad.is_reloading("pistol"), "recarga terminada")
	_expect_eq(cad.ammo("pistol"), 2, "cargador rellenado")
	_expect_eq(cad.reserve("pistol"), 0, "reserva descontada")
	_expect(not cad.reload("pistol"), "recarga sin reserva rechazada")
	_expect_eq(cad.ammo("bat"), -1, "arma cuerpo a cuerpo no usa municion")
	_expect(cad.fire("bat", idle_origin, Vector3.UP, _space, [])["fired"], "bate dispara sin cargador")

	_case = "escopeta con pellets"
	_sys.spread_scale = 0.0
	var scatter := _make_target(Vector3(10.0, 0.0, 0.0), "", 4.0)
	var scatter_dmg = scatter["damageable"]
	await process_frame
	await process_frame
	_sys.advance(1.0)
	var blast: Dictionary = _sys.fire("shotgun", Vector3(10.0, 0.0, 8.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_expect(bool(blast["fired"]), "escopeta dispara")
	_expect_eq(int(blast["pellets"]), 8, "ocho pellets configurados")
	_expect((blast["hits"] as Array).size() >= 4, "varios pellets impactan")
	_expect_eq(float(blast["damage"]), 96.0, "dano agregado de pellets")
	_expect(scatter_dmg.health < 100.0, "dano acumulado en el objetivo")
	_sys.spread_scale = 1.0

	_case = "impulso sobre cuerpo rigido"
	var box := RigidBody3D.new()
	box.mass = 1.0
	box.gravity_scale = 0.0
	box.position = Vector3(20.0, 0.0, 0.0)
	var rb_shape := CollisionShape3D.new()
	var rb_box := BoxShape3D.new()
	rb_box.size = Vector3(2.0, 2.0, 2.0)
	rb_shape.shape = rb_box
	box.add_child(rb_shape)
	_root.add_child(box)
	await process_frame
	await process_frame
	_sys.advance(1.0)
	var push: Dictionary = _sys.fire("pistol", Vector3(20.0, 0.0, 8.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_expect(bool(push["hit"]), "disparo impacta el cuerpo rigido")
	_expect(push["collider"] == box, "colision contra RigidBody3D")
	await physics_frame
	await physics_frame
	_expect(box.linear_velocity.length() > 0.01, "impulso aplicado tras frames de fisica")

	_case = "tope de decales y efecto de muerte"
	GoreFxScript.clear()
	for i in range(70):
		GoreFxScript.blood_hit(_gore_holder, Vector3(0.0, 1.0, 0.0), Vector3.UP, 10.0)
	_expect_eq(GoreFxScript.decal_count(), 64, "tope global de decales")
	_expect(GoreFxScript.active_count() <= 32, "tope de particulas activas")
	var recycled := GoreFxScript.decal_at(0)
	GoreFxScript.blood_hit(_gore_holder, Vector3(0.0, 1.0, 0.0), Vector3.UP, 10.0)
	GoreFxScript.blood_hit(_gore_holder, Vector3(0.0, 1.0, 0.0), Vector3.UP, 10.0)
	_expect(recycled != null and recycled.is_queued_for_deletion(), "decal mas antiguo reciclado")
	GoreFxScript.clear()
	var active_before := GoreFxScript.active_count()
	GoreFxScript.on_death(_gore_holder, Vector3(0.0, 0.0, 0.0), 1.0)
	_expect(GoreFxScript.active_count() > active_before, "muerte crea particulas de sangre")
	_expect(GoreFxScript.decal_count() >= 2, "muerte crea mancha")

	_case = "gore desactivado no crea nada"
	var session_script = null
	if ResourceLoader.exists(GAME_SESSION_PATH):
		session_script = load(GAME_SESSION_PATH)
	var original_value = null
	if session_script != null:
		original_value = session_script.get("gore_enabled")
	var use_override := typeof(original_value) != TYPE_BOOL
	if use_override:
		GoreFxScript.set_gore_enabled(false)
	else:
		session_script.set("gore_enabled", false)
	GoreFxScript.clear()
	var children_before := _gore_holder.get_child_count()
	var decals_before := GoreFxScript.decal_count()
	var active_before_off := GoreFxScript.active_count()
	GoreFxScript.blood_hit(_gore_holder, Vector3(1.0, 2.0, 3.0), Vector3.UP, 50.0)
	GoreFxScript.on_death(_gore_holder, Vector3(1.0, 2.0, 3.0), 1.0)
	_expect_eq(_gore_holder.get_child_count(), children_before, "sin nodos de gore")
	_expect_eq(GoreFxScript.decal_count(), decals_before, "sin decales")
	_expect_eq(GoreFxScript.active_count(), active_before_off, "sin particulas activas")
	if use_override:
		GoreFxScript.set_gore_enabled(null)
	else:
		session_script.set("gore_enabled", original_value)

	_case = "arma desconocida"
	_sys.advance(1.0)
	var bad: Dictionary = _sys.fire("no_existe", Vector3(0.0, 0.0, 0.0), Vector3.FORWARD, _space, [])
	_expect(not bool(bad["fired"]), "arma desconocida no dispara")
	_expect(not bool(bad["hit"]), "arma desconocida sin impacto")
	_expect(_mentions(str(bad["error"]), "desconocida"), "error controlado informado")
	_expect(_mentions(str(_sys.get_log()), "desconocida"), "error registrado en log")
	_expect(not _sys.can_fire("no_existe"), "arma desconocida no puede disparar")
	_expect(not _sys.reload("no_existe"), "recarga de arma desconocida rechazada")

	GoreFxScript.clear()
	cad.free()
	await process_frame
	GoreFxScript.shutdown()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
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


func _on_died() -> void:
	_deaths += 1


func _on_damaged(amount: float, point: Vector3, normal: Vector3) -> void:
	_damage_events += 1
	_expect(amount > 0.0, "cantidad de dano positiva")


func _mentions(text: String, fragment: String) -> bool:
	return text.find(fragment) >= 0


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_eq(actual, expected, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])
