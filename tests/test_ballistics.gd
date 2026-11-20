extends SceneTree

const SurfaceScript = preload("res://core/game/surface_material.gd")
const ImpactFxScript = preload("res://core/game/impact_fx.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const DamageableScript = preload("res://core/game/damageable.gd")
const WeaponSystemScript = preload("res://core/game/weapon_system.gd")

var _failures: Array = []
var _checks := 0
var _case := ""
var _root: Node3D = null
var _sys = null
var _space = null
var _fx_holder: Node3D = null
var _empty_events := 0
var _reload_done := 0


func _initialize() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	_sys = WeaponSystemScript.new()
	_root.add_child(_sys)
	_fx_holder = Node3D.new()
	_root.add_child(_fx_holder)
	await process_frame
	await physics_frame
	await process_frame
	_space = _root.get_world_3d().direct_space_state

	_case = "superficies y metadatos"
	_expect_eq(SurfaceScript.IDS.size(), 7, "siete tipos de superficie")
	for id in ["flesh", "metal", "wood", "concrete", "dirt", "glass", "water"]:
		_expect(SurfaceScript.type_from(id) >= 0, "superficie conocida: %s" % id)
	_expect_eq(SurfaceScript.type_from("hormigon"), SurfaceScript.Type.CONCRETE, "alias español de hormigon")
	_expect_eq(SurfaceScript.type_from("acero"), SurfaceScript.Type.METAL, "alias español de acero")
	_expect_eq(SurfaceScript.type_from("desconocida"), -1, "superficie desconocida rechazada")
	_expect(SurfaceScript.penetration_of(SurfaceScript.Type.GLASS) > SurfaceScript.penetration_of(SurfaceScript.Type.CONCRETE), "vidrio mas penetrable que hormigon")
	_expect(SurfaceScript.bounce_of(SurfaceScript.Type.METAL) > SurfaceScript.bounce_of(SurfaceScript.Type.DIRT), "metal rebota mas que tierra")
	_expect(SurfaceScript.absorption_of(SurfaceScript.Type.CONCRETE) > SurfaceScript.absorption_of(SurfaceScript.Type.GLASS), "hormigon absorbe mas que vidrio")
	var tagged := StaticBody3D.new()
	tagged.set_meta("surface", "metal")
	_root.add_child(tagged)
	_expect_eq(SurfaceScript.from_collider(tagged), SurfaceScript.Type.METAL, "superficie por metadato")
	var grouped := StaticBody3D.new()
	grouped.add_to_group("surface_wood")
	_root.add_child(grouped)
	_expect_eq(SurfaceScript.from_collider(grouped), SurfaceScript.Type.WOOD, "superficie por grupo")
	_expect_eq(SurfaceScript.from_collider(null), SurfaceScript.Type.CONCRETE, "colision sin superficie usa hormigon")

	_case = "caida de dano por distancia"
	var near_target := _make_target(Vector3(-40.0, 0.0, 0.0), "", 1000.0)
	var far_target := _make_target(Vector3(-80.0, 0.0, 0.0), "", 1000.0)
	await physics_frame
	await process_frame
	var near_shot: Dictionary = _sys.fire("pistol", Vector3(-40.0, 0.0, 30.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_sys.advance(0.2)
	var far_shot: Dictionary = _sys.fire("pistol", Vector3(-80.0, 0.0, 55.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_expect(bool(near_shot["hit"]) and bool(far_shot["hit"]), "ambos disparos impactan")
	_expect(float(near_shot["falloff"]) > float(far_shot["falloff"]), "factor de caida menor a larga distancia")
	_expect(float(far_shot["damage"]) < float(near_shot["damage"]), "dano reducido por distancia")
	_expect(float(far_shot["damage"]) > 0.0, "el dano no desaparece por distancia")
	_expect(near_target["damageable"].health < 1000.0, "objetivo cercano danado")
	_expect(far_target["damageable"].health < 1000.0, "objetivo lejano danado")
	_expect(float(far_shot["hits"][0]["distance"]) > float(near_shot["hits"][0]["distance"]), "distancia registrada en el impacto")

	_case = "penetracion en madera y bloqueo en hormigon"
	var wood_board := _make_board(Vector3(-120.0, 0.0, 20.0), Vector3(4.0, 4.0, 0.1), "wood")
	var wood_victim := _make_target(Vector3(-120.0, 0.0, 0.0), "", 1000.0)
	var control_victim := _make_target(Vector3(-125.0, 0.0, 0.0), "", 1000.0)
	var concrete_board := _make_board(Vector3(-160.0, 0.0, 20.0), Vector3(4.0, 4.0, 0.4), "concrete")
	var blocked_victim := _make_target(Vector3(-160.0, 0.0, 0.0), "", 1000.0)
	await physics_frame
	await process_frame
	_sys.advance(1.0)
	var wood_shot: Dictionary = _sys.fire("assault_rifle", Vector3(-120.0, 0.0, 30.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_sys.advance(0.2)
	var control_shot: Dictionary = _sys.fire("assault_rifle", Vector3(-125.0, 0.0, 30.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_sys.advance(0.2)
	var concrete_shot: Dictionary = _sys.fire("assault_rifle", Vector3(-160.0, 0.0, 30.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_expect_eq(int(wood_shot["penetrations"]), 1, "rifle atraviesa tabla de madera")
	_expect(wood_victim["damageable"].health < 1000.0, "objetivo tras madera recibe dano")
	_expect(wood_victim["damageable"].health > control_victim["damageable"].health, "la madera reduce el dano transmitido")
	_expect(float(wood_shot["hits"].size()) >= 2, "impacto en tabla y en objetivo")
	_expect(float(wood_shot["hits"][1]["damage"]) < float(control_shot["hits"][0]["damage"]), "dano atenuado tras penetrar")
	_expect_eq(str(concrete_shot["surface_name"]), "concrete", "superficie de hormigon detectada")
	_expect_eq(int(concrete_shot["penetrations"]), 0, "hormigon no es penetrable por rifle")
	_expect_eq(blocked_victim["damageable"].health, 1000.0, "hormigon bloquea la bala")
	_expect(concrete_board != null and wood_board != null, "tableros creados")

	_case = "rebote metalico"
	var metal_wall := _make_board(Vector3(-200.0, 0.0, 10.0), Vector3(0.1, 4.0, 8.0), "metal")
	var ricochet_victim := _make_target(Vector3(-202.0, 0.0, 0.0), "", 1000.0, 3.0)
	await physics_frame
	await process_frame
	_sys.advance(1.0)
	var bounce_shot: Dictionary = _sys.fire("pistol", Vector3(-203.0, 0.0, 20.0), Vector3(0.25, 0.0, -1.0), _space, [])
	_expect_eq(int(bounce_shot["ricochets"]), 1, "rebote en metal con angulo rasante")
	_expect(ricochet_victim["damageable"].health < 1000.0, "bala rebotada impacta objetivo lateral")
	_expect_eq(str(bounce_shot["surface_name"]), "metal", "primer impacto sobre metal")
	_expect(metal_wall != null, "muro metalico creado")

	_case = "cargador, recarga, vacio e indicadores"
	var cad = WeaponSystemScript.new()
	_root.add_child(cad)
	await process_frame
	cad.empty.connect(_on_empty)
	cad.reload_finished.connect(_on_reload_finished)
	cad.set_ammo("pistol", 1, 5)
	_expect(cad.fire("pistol", Vector3(-300.0, 100.0, 0.0), Vector3.UP, _space, [])["fired"], "unicas bala dispara")
	_expect(not cad.fire("pistol", Vector3(-300.0, 100.0, 0.0), Vector3.UP, _space, [])["fired"], "arma vacia no dispara")
	_expect_eq(_empty_events, 1, "senal empty emitida al quedar vacia")
	var info_empty: Dictionary = cad.ammo_info("pistol")
	_expect_eq(int(info_empty["mag"]), 0, "indicador de cargador")
	_expect_eq(int(info_empty["reserve"]), 5, "indicador de reserva")
	_expect(str(info_empty["block_reason"]).find("municion") >= 0, "motivo de arma vacia consultable")
	_expect(not bool(info_empty["can_fire"]), "indicador can_fire falso")
	_expect(float(info_empty["fire_interval"]) > 0.0, "intervalo de cadencia consultable")
	_expect(cad.reload("pistol"), "recarga iniciada")
	_expect(cad.is_reloading("pistol"), "recarga en curso")
	_expect(cad.cancel_reload("pistol"), "recarga cancelable")
	_expect(not cad.is_reloading("pistol"), "recarga cancelada")
	_expect_eq(cad.ammo("pistol"), 0, "recarga cancelada no rellena")
	_expect(cad.reload("pistol"), "recarga reiniciada")
	_expect(cad.reload_progress("pistol") < 0.5, "progreso de recarga consultable")
	cad.advance(0.6)
	_expect(cad.reload_progress("pistol") >= 0.5, "progreso de recarga avanza")
	cad.advance(0.6)
	_expect(not cad.is_reloading("pistol"), "recarga completada")
	_expect_eq(cad.ammo("pistol"), 5, "cargador rellenado")
	_expect_eq(cad.reserve("pistol"), 0, "reserva descontada")
	_expect_eq(_reload_done, 1, "senal de fin de recarga")

	_case = "topes globales de efectos"
	ImpactFxScript.clear()
	for i in range(120):
		ImpactFxScript.spawn(_fx_holder, SurfaceScript.Type.METAL, Vector3(-350.0, 1.0, 0.0), Vector3.UP, 12.0)
	_expect(ImpactFxScript.decal_count() <= ImpactFxScript.MAX_DECALS, "tope de agujeros/decales")
	_expect(ImpactFxScript.active_count() <= ImpactFxScript.MAX_ACTIVE, "tope de particulas de impacto")
	_expect(ImpactFxScript.decal_count() > 0, "decales creados dentro del tope")
	var before_splash := GoreFxScript.puddle_count()
	ImpactFxScript.spawn(_fx_holder, SurfaceScript.Type.WATER, Vector3(-350.0, 2.0, 0.0), Vector3.UP, 12.0)
	_expect(GoreFxScript.puddle_count() > before_splash, "salpicadura de agua crea charco")
	ImpactFxScript.clear()
	_expect_eq(ImpactFxScript.decal_count(), 0, "limpieza de efectos")

	_case = "impulso proporcional a la masa"
	var light := _make_rigid(Vector3(-240.0, 0.0, 0.0), 1.0)
	var heavy := _make_rigid(Vector3(-245.0, 0.0, 0.0), 8.0)
	await physics_frame
	await process_frame
	_sys.advance(1.0)
	_sys.fire("pistol", Vector3(-240.0, 0.0, 8.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_sys.advance(0.2)
	_sys.fire("pistol", Vector3(-245.0, 0.0, 8.0), Vector3(0.0, 0.0, -1.0), _space, [])
	await physics_frame
	await physics_frame
	var light_speed: float = (light as RigidBody3D).linear_velocity.length()
	var heavy_speed: float = (heavy as RigidBody3D).linear_velocity.length()
	_expect(light_speed > 0.01, "cuerpo ligero recibe impulso")
	_expect(light_speed > heavy_speed * 2.0, "impulso mayor en cuerpo de menor masa")
	_case = "props que se rompen y ruedan"
	var breakable := _make_rigid(Vector3(-250.0, 0.0, 0.0), 1.0)
	breakable.set_meta("breakable", true)
	breakable.set_meta("break_energy", 5.0)
	var roller := _make_rigid(Vector3(-255.0, 0.0, 0.0), 2.0)
	roller.add_to_group("rollable")
	await physics_frame
	await process_frame
	_sys.advance(1.0)
	_sys.fire("pistol", Vector3(-250.0, 0.0, 8.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_sys.advance(0.2)
	_sys.fire("pistol", Vector3(-255.0, 0.0, 8.0), Vector3(0.0, 0.0, -1.0), _space, [])
	await physics_frame
	await physics_frame
	_expect(not is_instance_valid(breakable) or breakable.is_queued_for_deletion() or bool(breakable.get_meta("broken", false)), "prop rompible se rompe")
	_expect(_sys.debris_count() >= 3, "escombros limitados creados")
	_expect((roller as RigidBody3D).angular_velocity.length() > 0.0, "prop rueda por impulso excéntrico")

	_case = "proyectil con gravedad"
	var projectile_target := _make_target(Vector3(-280.0, 0.0, -100.0), "", 1000.0, 4.0)
	await physics_frame
	await process_frame
	_sys.projectile_mode = "always"
	_sys.spread_scale = 0.0
	_sys.clear_projectile_events()
	_sys.advance(1.0)
	var launched: Dictionary = _sys.fire("sniper_rifle", Vector3(-280.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_expect(bool(launched["fired"]), "francotirador dispara en modo proyectil")
	_expect(bool(launched["projectile"]), "disparo usa proyectil real")
	_expect(not bool(launched["hit"]), "proyectil aun no impacta al disparar")
	_expect(_sys.projectile_count() > 0, "proyectil activo")
	for i in range(20):
		_sys.advance(0.02)
	var events: Array = _sys.projectile_events()
	_expect(events.size() > 0, "proyectil registra evento de impacto")
	_expect(projectile_target["damageable"].health < 1000.0, "proyectil con gravedad impacta objetivo lejano")
	if not events.is_empty():
		var first_event: Dictionary = events[0]
		_expect(first_event["position"].y < 0.0, "caida vertical por gravedad")
	_sys.projectile_mode = "auto"
	_sys.spread_scale = 1.0
	_sys.clear_projectile_events()

	_case = "gore desactivado no crea nada"
	GoreFxScript.set_gore_enabled(false)
	GoreFxScript.clear()
	var children_before := _fx_holder.get_child_count()
	var decals_before := GoreFxScript.decal_count()
	var active_before := GoreFxScript.active_count()
	var puddles_before := GoreFxScript.puddle_count()
	var parts_before := GoreFxScript.dismembered_count()
	GoreFxScript.blood_hit(_fx_holder, Vector3(-290.0, 1.0, 0.0), Vector3.UP, 50.0)
	GoreFxScript.on_death(_fx_holder, Vector3(-290.0, 1.0, 0.0), 1.0)
	GoreFxScript.puddle(_fx_holder, Vector3(-290.0, 1.0, 0.0), Vector3.UP, 1.0)
	GoreFxScript.dismember(_fx_holder, Vector3(-290.0, 1.0, 0.0), 1.0, "head", 3)
	_expect_eq(_fx_holder.get_child_count(), children_before, "sin nodos de gore con gore apagado")
	_expect_eq(GoreFxScript.decal_count(), decals_before, "sin decales con gore apagado")
	_expect_eq(GoreFxScript.active_count(), active_before, "sin particulas con gore apagado")
	_expect_eq(GoreFxScript.puddle_count(), puddles_before, "sin charcos con gore apagado")
	_expect_eq(GoreFxScript.dismembered_count(), parts_before, "sin desmembramiento con gore apagado")
	GoreFxScript.set_gore_enabled(null)

	_case = "desmembramiento con tope"
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)
	for i in range(10):
		GoreFxScript.dismember(_fx_holder, Vector3(-295.0, 1.0, 0.0), 1.0, "head", 3)
	_expect(GoreFxScript.dismembered_count() > 0, "partes desmembradas creadas")
	_expect(GoreFxScript.dismembered_count() <= GoreFxScript.MAX_PARTS, "tope global de partes desmembradas")
	_expect(GoreFxScript.part_at(0) is RigidBody3D, "partes son cuerpos rigidos")
	GoreFxScript.clear()
	_sys.dismember_on_kill = true
	var doomed := _make_target(Vector3(-298.0, 0.0, 0.0), "head", 24.0, 2.0)
	await physics_frame
	await process_frame
	_sys.advance(1.0)
	_sys.fire("pistol", Vector3(-298.0, 0.0, 8.0), Vector3(0.0, 0.0, -1.0), _space, [])
	_expect(doomed["damageable"].is_dead(), "objetivo muerto por disparo a la cabeza")
	_expect(GoreFxScript.dismembered_count() > 0, "muerte con gore genera desmembramiento")
	_sys.dismember_on_kill = false

	GoreFxScript.clear()
	ImpactFxScript.clear()
	_sys.clear_effects()
	cad.free()
	await process_frame
	GoreFxScript.shutdown()
	ImpactFxScript.shutdown()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _make_target(pos: Vector3, zone: String, health: float = 100.0, size: float = 2.0) -> Dictionary:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, size, size)
	shape.shape = box
	body.add_child(shape)
	var damageable := DamageableScript.new()
	damageable.health = health
	damageable.max_health = maxf(health, 1.0)
	body.add_child(damageable)
	if not zone.is_empty():
		body.set_meta("hit_zone", zone)
	_root.add_child(body)
	return {"body": body, "damageable": damageable}


func _make_board(pos: Vector3, size: Vector3, surface: String) -> StaticBody3D:
	var board := StaticBody3D.new()
	board.position = pos
	board.set_meta("surface", surface)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	board.add_child(shape)
	_root.add_child(board)
	return board


func _make_rigid(pos: Vector3, mass: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = mass
	body.gravity_scale = 0.0
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 2.0)
	shape.shape = box
	body.add_child(shape)
	_root.add_child(body)
	return body


func _on_empty(weapon_id: String) -> void:
	_empty_events += 1
	_expect(weapon_id == "pistol", "senal empty con id de arma")


func _on_reload_finished(weapon_id: String) -> void:
	_reload_done += 1
	_expect(weapon_id == "pistol", "senal de recarga con id de arma")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_eq(actual, expected, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])
