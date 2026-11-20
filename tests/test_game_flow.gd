extends SceneTree

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")
const WeaponsDbScript = preload("res://core/game/weapon_db.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const MuzzleFxScript = preload("res://core/game/muzzle_fx.gd")
const CharacterModelScript = preload("res://core/game/character_model.gd")
const ArmedNpcScript = preload("res://core/game/armed_npc.gd")
const DummyScript = preload("res://core/game/target_dummy.gd")
const TouchScene = preload("res://scenes/ui/touch_controls.tscn")

var _checks := 0
var _failures: Array = []
var _case := ""
var _fired := 0
var _empty := 0
var _dummy_deaths := 0


func _initialize() -> void:
	await _run()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _run() -> void:
	_case = "flujo main_menu -> GameSession.start"
	var meta: Dictionary = GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.18, "spawn_count": 4,
	})
	_expect(bool(meta.get("ok", false)), "MapGenerator entrega una meta valida")
	var captured: Array = []
	var original_override: Callable = SessionScript.start_override
	SessionScript.start_override = func(received: Dictionary) -> void: captured.append(received.duplicate(true))
	var start_error: int = SessionScript.start(meta, self)
	_expect(start_error == OK, "GameSession.start devuelve OK")
	_expect(captured.size() == 1, "GameSession.start llama una vez al destino")
	_expect(int((captured[0] as Dictionary).get("seed", -1)) == 4242, "la meta conserva la semilla")
	_expect(int(SessionScript.map_meta.get("seed", -1)) == 4242, "GameSession guarda map_meta")
	_expect(SessionScript.platform in ["android", "pc", "vr"], "plataforma detectada")
	SessionScript.start_override = original_override

	_case = "GameWorld con jugador, HUD y dianas"
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	world.setup(meta)
	await process_frame
	for i in range(3):
		await physics_frame

	_expect(bool((world.world_report as Dictionary).get("ok", false)), "GameWorld construye el mapa")
	_expect(world.actor != null and world.actor.name == "Player", "hay jugador en el mundo")
	_expect(world.get_node_or_null("Player") != null, "el jugador esta en la escena")
	_expect(world.spawn_point_positions().size() == 4, "spawns expuestos")
	var player = world.actor
	var ids: Array = WeaponsDbScript.list_ids()
	_expect(ids.size() >= 6, "la base de armas tiene todas las armas")
	_expect(player.inventory != null, "el jugador recibe inventario")
	for id in ids:
		_expect(int(player.inventory.count(str(id))) > 0, "arma en el inventario inicial: %s" % str(id))
	_expect(not str(player.equipped_weapon).is_empty(), "arma inicial equipada")
	_expect(world.hud != null, "GameHud creado")
	_expect(world.get_node_or_null("HudLayer/GameHud/HealthBar") != null, "barra de vida en el HUD")
	_expect(world.get_node_or_null("HudLayer/GameHud/AmmoLabel") != null, "municion en el HUD")
	_expect(world.get_node_or_null("HudLayer/GameHud/WeaponLabel") != null, "nombre del arma en el HUD")
	_expect(world.get_node_or_null("HudLayer/GameHud/Crosshair") != null, "mira en el HUD")
	_expect(world.hud.ui_scale() >= 0.85, "HUD escala con el viewport con minimo")
	_expect((world.get_node("HudLayer/GameHud/HealthLabel") as Label).get_theme_font_size("font_size") >= 28,
		"fuente base legible en el HUD")
	_expect((world.get_node("HudLayer/GameHud/AmmoLabel") as Label).get_theme_font_size("font_size") >= 38,
		"municion destacada en el HUD")
	_expect(world.target_dummies().size() == 6, "seis maniquies colocados")
	_expect(world.props().size() > 0, "props fisicos cerca del spawn")
	_expect(world.get_node_or_null("Dummies") != null, "raiz de maniquies presente")
	_expect(world.performance != null and world.performance.has_method("current_profile"), "perfil de rendimiento activo")
	_expect(GoreFxScript.limit_decals <= GoreFxScript.MAX_DECALS, "topes de gore aplicados para movil/VR")
	_expect(world.target_dummies()[0].find_children("CharacterModel_*", "Node3D", true, false).size() > 0,
		"maniqui usa modelo 3D real")

	_case = "viewmodel y armas visibles"
	_expect(player.viewmodel != null, "WeaponViewmodel colgado del jugador")
	_expect(player.camera.get_node_or_null("WeaponViewmodel") == player.viewmodel, "viewmodel bajo la camara")
	_expect(player.viewmodel != null and player.viewmodel.call("has_model"), "modelo 3D del arma instanciado")
	_expect(player.viewmodel != null and player.viewmodel.call("current_weapon") == str(player.equipped_weapon),
		"viewmodel muestra el arma equipada")
	_expect(player.viewmodel != null and player.viewmodel.call("muzzle_fx") != null,
		"MuzzleFx conectado al arma")

	_case = "disparo, municion y dano"
	player.gravity = 0.0
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0.0, 20.0, 0.0)
	var ws = player.weapon_system()
	_expect(ws != null, "WeaponSystem disponible en el jugador")
	if ws == null:
		return
	ws.spread_scale = 0.0
	player.fired.connect(_on_player_fired)
	player.empty.connect(_on_player_empty)
	player.equip("pistol")
	ws.set_ammo("pistol", 12, 12)
	var dummy = world.target_dummies()[0]
	dummy.configure(60.0, 5.0)
	dummy.global_position = player.global_position + Vector3(0.0, 0.0, -6.0)
	dummy.died.connect(_on_dummy_died)
	await process_frame
	ws.advance(1.0)
	var ammo_before: int = ws.ammo("pistol")
	var health_before: float = dummy.health()
	_fired = 0
	var casings_before: int = MuzzleFxScript.active_casing_count()
	var flashes_before: int = MuzzleFxScript.flash_count()
	var smoke_before: int = MuzzleFxScript.smoke_count()
	var audio_before: int = world.find_children("G12Audio3D", "AudioStreamPlayer3D", true, false).size()
	player.fire()
	_expect(ws.ammo("pistol") == ammo_before - 1, "disparar consume una bala del cargador")
	_expect(dummy.health() < health_before, "el disparo dana al maniqui")
	_expect(_fired == 1, "senal fired emitida")
	player.viewmodel.advance(0.016)
	_expect(player.viewmodel.call("recoil_offset").length() > 0.01, "el disparo genera retroceso real")
	_expect(MuzzleFxScript.active_casing_count() > casings_before, "el disparo suelta un casquillo")
	_expect(MuzzleFxScript.casing_at(0) is RigidBody3D, "el casquillo es un RigidBody3D")
	_expect(MuzzleFxScript.flash_count() > flashes_before, "el disparo crea fogonazo")
	_expect(MuzzleFxScript.smoke_count() > smoke_before, "el disparo crea humo")
	_expect(world.find_children("G12Audio3D", "AudioStreamPlayer3D", true, false).size() > audio_before,
		"la pistola sin muestra grabada usa sonido sintetizado")

	_case = "cargador vacio y recarga"
	ws.set_ammo("pistol", 0, 0)
	ws.advance(1.0)
	_fired = 0
	_empty = 0
	player.fire()
	_expect(_fired == 0, "con el cargador vacio no hay disparo")
	_expect(_empty == 1, "senal empty emitida")
	_expect(ws.ammo("pistol") == 0, "la municion no cambia al fallar el disparo")
	ws.set_ammo("pistol", 0, 6)
	_expect(player.reload(), "recarga iniciada por el jugador")
	_expect(ws.is_reloading("pistol"), "estado recargando activo")
	_expect(player.viewmodel.call("is_reloading"), "animacion de recarga activa en el viewmodel")
	var reload_def: Dictionary = WeaponsDbScript.get_def("pistol")
	player.viewmodel.advance(float(reload_def.get("reload_time", 1.0)) * 0.5)
	_expect(player.viewmodel.call("is_reloading"), "la recarga dura el tiempo real del arma")
	player.viewmodel.advance(float(reload_def.get("reload_time", 1.0)))
	_expect(not bool(ws.fire("pistol", Vector3(0.0, 30.0, 0.0), Vector3.UP, world.get_world_3d().direct_space_state, [])["fired"]), "no se dispara mientras recarga")
	ws.advance(1.2)
	_expect(ws.ammo("pistol") == 6, "la recarga restaura el cargador")
	_expect(ws.reserve("pistol") == 0, "la reserva se descuenta")

	_case = "muerte del maniqui: ragdoll, gore y voz"
	dummy.configure(40.0, 5.0)
	dummy.global_position = player.global_position + Vector3(0.0, 0.0, -6.0)
	_dummy_deaths = 0
	var ragdolls_before: int = CharacterModelScript.ragdoll_count()
	var decals_before_death: int = GoreFxScript.decal_count()
	var puddles_before_death: int = GoreFxScript.puddle_count()
	var subtitles_before: int = world.voice.subtitle_count() if world.voice != null else 0
	ws.set_ammo("pistol", 12, 12)
	ws.advance(1.0)
	player.fire()
	ws.advance(1.0)
	player.fire()
	_expect(dummy.is_dead(), "suficientes disparos matan al maniqui")
	_expect(_dummy_deaths == 1, "senal died del maniqui emitida una vez")
	_expect(CharacterModelScript.ragdoll_count() > ragdolls_before, "la muerte crea un ragdoll del modelo 3D")
	_expect(dummy.find_children("CharacterRagdoll_*", "Node3D", true, false).size() > 0,
		"el ragdoll queda colgado del objetivo")
	_expect(dummy.find_children("DetachedLimb_*", "RigidBody3D", true, false).size() > 0,
		"un miembro se desprende como cuerpo rigido")
	_expect(dummy.find_children("CharacterWound*", "MeshInstance3D", true, false).size() > 0,
		"el impacto deja una herida visible")
	_expect(GoreFxScript.decal_count() > decals_before_death, "la muerte genera sangre/decales")
	_expect(GoreFxScript.puddle_count() > puddles_before_death, "la muerte genera un charco de sangre")
	_expect(world.voice != null and world.voice.subtitle_count() > subtitles_before,
		"VoiceSystem emite un grito con subtitulo")
	_expect(world.get_node("HudLayer/GameHud/SubtitleLabel") is Label
		and (world.get_node("HudLayer/GameHud/SubtitleLabel") as Label).visible,
		"el subtitulo se muestra en el HUD")

	_case = "impulso sobre caja fisica"
	dummy.global_position = Vector3(0.0, 20.0, -40.0)
	var box := RigidBody3D.new()
	box.name = "TestBox"
	box.mass = 1.0
	box.gravity_scale = 0.0
	box.position = player.global_position + Vector3(0.0, 1.0, -6.0)
	var box_shape := CollisionShape3D.new()
	var box_geometry := BoxShape3D.new()
	box_geometry.size = Vector3(1.5, 1.5, 1.5)
	box_shape.shape = box_geometry
	box.add_child(box_shape)
	world.add_child(box)
	await process_frame
	var box_start: Vector3 = box.global_position
	ws.set_ammo("pistol", 12, 12)
	ws.advance(1.0)
	player.fire()
	for i in range(2):
		await physics_frame
	_expect(box.linear_velocity.length() > 0.01 or box.global_position.distance_to(box_start) > 0.01,
		"el impacto mueve la caja rigida")
	box.queue_free()
	await process_frame

	_case = "gore desactivado"
	var original_gore: bool = SessionScript.gore_enabled
	SessionScript.gore_enabled = false
	GoreFxScript.clear()
	var quiet_dummy := DummyScript.spawn(world, player.global_position + Vector3(0.0, 0.0, -6.0), 99)
	quiet_dummy.configure(100.0, 5.0)
	await process_frame
	var decals_before: int = GoreFxScript.decal_count()
	var active_before: int = GoreFxScript.active_count()
	ws.set_ammo("pistol", 12, 12)
	ws.advance(1.0)
	player.fire()
	_expect(GoreFxScript.decal_count() == decals_before, "gore apagado no crea decales")
	_expect(GoreFxScript.active_count() == active_before, "gore apagado no crea particulas")
	var gore_children := 0
	for child in quiet_dummy.get_children():
		if str(child.name).begins_with("Gore"):
			gore_children += 1
	_expect(gore_children == 0, "gore apagado no crea nodos en el objetivo")
	SessionScript.gore_enabled = original_gore

	_case = "HUD por senales"
	var player_hp: float = player.health
	player.take_damage(12.0)
	await process_frame
	_expect(world.hud.health_value() < player_hp, "la barra de vida baja con el dano")
	_expect(world.hud.damage_visible(), "aviso de dano visible")
	_expect(world.hud.ammo_text().find("MUNICION") >= 0, "el HUD muestra municion")
	_expect(world.hud.weapon_text().find("Pistola") >= 0, "el HUD muestra el nombre del arma")

	_case = "controles tactiles conectados"
	var controls = TouchScene.instantiate()
	root.add_child(controls)
	await process_frame
	player.set_touch_controls(controls)
	ws.set_ammo("pistol", 12, 12)
	ws.advance(1.0)
	_fired = 0
	controls.fire_pressed.emit()
	_expect(_fired == 1, "fire_pressed dispara a traves del Player")
	controls.fire_released.emit()
	ws.set_ammo("pistol", 0, 6)
	controls.reload_pressed.emit()
	_expect(ws.is_reloading("pistol"), "reload_pressed recarga a traves del Player")
	ws.advance(1.2)
	var weapon_ids: Array = player.weapon_ids()
	controls.hotbar_select.emit(1)
	_expect(weapon_ids.size() >= 2 and player.equipped_weapon == str(weapon_ids[1]), "hotbar_select equipa por indice")

	_case = "estabilidad"
	for i in range(180):
		await physics_frame
	_expect(true, "180 frames de fisica completados")
	GoreFxScript.clear()
	SessionScript.start_override = original_override
	SessionScript.gore_enabled = original_gore


func _on_player_fired(_result: Dictionary) -> void:
	_fired += 1


func _on_player_empty(_item_id: String) -> void:
	_empty += 1


func _on_dummy_died() -> void:
	_dummy_deaths += 1


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])
