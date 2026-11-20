extends SceneTree

const CombatScript = preload("res://core/npc/npc_combat.gd")
const ArmedNpcScript = preload("res://core/game/armed_npc.gd")
const DamageableScript = preload("res://core/game/damageable.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const PerceptionScript = preload("res://core/npc/npc_perception.gd")
const NavigationScript = preload("res://core/npc/npc_navigation.gd")
const RelationsScript = preload("res://core/npc/npc_relations.gd")
const FactionsScript = preload("res://core/npc/npc_factions.gd")

var _failures: Array = []
var _checks: int = 0
var _case: String = ""
var _root: Node3D = null
var _shots: Array = []


func _initialize() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	await process_frame
	await process_frame
	await physics_frame

	_decisiones()
	_municion_y_recarga()
	_percepcion_navegacion_y_relaciones()
	_determinismo()
	await _integracion_disparo()
	await _civil_huye()
	await _muerte_y_drop()
	_limite_plataforma()

	GoreFxScript.clear()
	ArmedNpcScript.clear_registry()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _decisiones() -> void:
	_case = "decision segun estado"
	var hostile := CombatScript.new({
		"seed": 7, "role": "hostile", "difficulty": "hard", "mag": 12, "reserve": 36,
	})
	_expect_eq(str(hostile.call("action")), "patrol", "arranca patrullando")
	var visible_ctx: Dictionary = {"visible": true, "distance": 8.0}
	var attack: Dictionary = hostile.call("decide", visible_ctx)
	_expect_eq(str(attack.get("id", "")), "attack", "hostilo con balas ataca al ver al jugador")
	hostile.call("set_health_ratio", 0.1)
	var flee: Dictionary = hostile.call("decide", visible_ctx)
	_expect_eq(str(flee.get("id", "")), "flee", "hostilo con poca vida huye")
	hostile.call("set_health_ratio", 1.0)
	hostile.call("set_ammo", 0, 36)
	var reload: Dictionary = hostile.call("decide", visible_ctx)
	_expect_eq(str(reload.get("id", "")), "reload", "sin balas y con reserva recarga")
	hostile.call("set_ammo", 0, 0)
	var no_ammo: Dictionary = hostile.call("decide", visible_ctx)
	_expect_eq(str(no_ammo.get("id", "")), "flee", "sin balas ni reserva huye")

	var civilian := CombatScript.new({"seed": 7, "role": "civilian", "difficulty": "normal"})
	var civ_decision: Dictionary = civilian.call("decide", visible_ctx)
	_expect_eq(str(civ_decision.get("id", "")), "flee", "civil pacifico huye al ver al jugador")
	var civ_hidden: Dictionary = civilian.call("decide", {"visible": false, "distance": 40.0})
	_expect(str(civ_hidden.get("id", "")) != "attack", "civil sin amenaza no ataca")

	var defender := CombatScript.new({
		"seed": 7, "role": "defender", "difficulty": "normal",
		"entity_id": "guardia_1", "target_id": "intruso",
		"factions_data": {
			"factions": [
				{"id": "guard", "name": "Guardia"},
				{"id": "raider", "name": "Asaltante"},
			],
			"members": {"guardia_1": "guard", "intruso": "raider"},
			"relations": [{"a": "guard", "b": "raider", "value": -80.0}],
		},
		"relations_options": {"faction_weight": 1.0},
	})
	var defend: Dictionary = defender.call("decide", visible_ctx)
	_expect_eq(str(defend.get("id", "")), "attack", "defensor ataca a faccion hostil")
	_expect(str(defender.call("attitude_toward_target")) == "hostil", "actitud hostil por faccion")


func _municion_y_recarga() -> void:
	_case = "municion limitada y recarga"
	var c := CombatScript.new({
		"seed": 11, "mag": 3, "reserve": 4, "reaction_delay": 0.0, "fire_rate": 10.0,
	})
	_expect_eq(int(c.get("ammo")), 3, "cargador inicial completo")
	_expect(bool(c.call("can_fire")), "puede disparar con balas")
	_expect(bool(c.call("consume_shot")), "primer disparo consume bala")
	c.call("advance", 1.0)
	c.call("advance", 1.0)
	_expect_eq(int(c.get("ammo")), 2, "quedan dos balas")
	_expect(bool(c.call("can_fire")), "cadencia restaurada tras esperar")
	_expect(bool(c.call("consume_shot")), "segundo disparo consume bala")
	c.call("advance", 1.0)
	c.call("advance", 1.0)
	_expect_eq(int(c.get("ammo")), 1, "queda una bala")
	_expect(bool(c.call("can_fire")), "puede disparar la ultima bala")
	_expect(bool(c.call("consume_shot")), "tercer disparo consume bala")
	_expect_eq(int(c.get("ammo")), 0, "cargador agotado")
	_expect(not bool(c.call("can_fire")), "sin balas no puede disparar")
	_expect(not bool(c.call("consume_shot")), "sin balas no consume")
	_expect(bool(c.call("start_reload")), "recarga iniciada")
	_expect(bool(c.call("is_reloading")), "estado recargando activo")
	_expect(float(c.call("reload_progress")) == 0.0, "progreso de recarga inicial")
	c.call("advance", 0.5)
	_expect(float(c.call("reload_progress")) > 0.0, "progreso de recarga avanza")
	c.call("advance", 0.8)
	_expect(not bool(c.call("is_reloading")), "recarga terminada")
	_expect_eq(int(c.get("ammo")), 3, "cargador rellenado")
	_expect_eq(int(c.get("reserve")), 1, "reserva descontada")
	_expect(not bool(c.call("start_reload")), "recarga redundante rechazada")


func _percepcion_navegacion_y_relaciones() -> void:
	_case = "percepcion, navegacion y relaciones"
	var perception := PerceptionScript.new({"vision_range": 12.0})
	var sight: Dictionary = perception.call("can_see", Vector3(0.0, 0.0, 0.0), Vector2(0.0, -1.0), Vector3(0.0, 0.0, -5.0))
	_expect(bool(sight.get("visible", false)), "percepcion ve objetivo al frente")
	var behind: Dictionary = perception.call("can_see", Vector3(0.0, 0.0, 0.0), Vector2(0.0, -1.0), Vector3(0.0, 0.0, 5.0))
	_expect(not bool(behind.get("visible", false)), "percepcion no ve objetivo a espaldas")

	var nav := NavigationScript.new(6, 6, [Vector2i(2, 0), Vector2i(2, 1)])
	var c := CombatScript.new({
		"seed": 21, "navigation": nav, "cell_size": 1.0,
		"attack_points": [Vector3(4.0, 0.0, 0.0)],
		"cover_points": [Vector3(-3.0, 0.0, 0.0)],
	})
	c.call("set_health_ratio", 0.9)
	var ctx: Dictionary = {"visible": true, "distance": 9.0, "position": Vector3(0.0, 0.0, 0.0), "target_position": Vector3(8.0, 0.0, 0.0)}
	var cover_goal: Vector3 = c.call("goal_for", "cover", ctx)
	_expect(cover_goal.x < 0.0, "posicion de cobertura alejada del objetivo")
	var path: Array = c.call("path_to", Vector3(5.0, 0.0, 0.0), ctx)
	_expect(path.size() > 0, "navegacion encuentra ruta hacia ataque/cobertura")

	var factions := FactionsScript.new({
		"factions": [{"id": "a", "name": "A"}, {"id": "b", "name": "B"}],
		"members": {"n1": "a", "n2": "b"},
		"relations": [{"a": "a", "b": "b", "value": -70.0}],
	})
	var relations := RelationsScript.new({}, factions)
	relations.call("set_affinity", "n1", "n2", -40.0)
	c.set("factions", factions)
	c.set("relations", relations)
	c.set("entity_id", "n1")
	c.set("target_id", "n2")
	_expect(str(c.call("attitude_toward_target")) == "hostil", "relacion combinada marca hostilidad")
	_expect(float(c.call("faction_relation")) < 0.0, "relacion de faccion hostil disponible")
	relations.call("set_affinity", "n1", "n2", 100.0)
	_expect(str(relations.call("get_attitude", "n1", "n2")) == "amistoso", "afinidad individual puede volverse amistosa")


func _determinismo() -> void:
	_case = "determinismo con semilla"
	var a := CombatScript.new({"seed": 99, "difficulty": "hard", "mag": 20, "reserve": 40})
	var b := CombatScript.new({"seed": 99, "difficulty": "hard", "mag": 20, "reserve": 40})
	for i in range(5):
		a.call("update", 0.1, {"visible": true, "distance": 7.0})
		b.call("update", 0.1, {"visible": true, "distance": 7.0})
	_expect(str(a.call("snapshot")) == str(b.call("snapshot")), "misma semilla produce estado identico")
	var dir_a: Vector3 = a.call("spread_direction", Vector3.FORWARD, 10.0)
	var dir_b: Vector3 = b.call("spread_direction", Vector3.FORWARD, 10.0)
	_expect(dir_a.is_equal_approx(dir_b), "dispersion determinista con la misma semilla")
	var c := CombatScript.new({"seed": 100, "difficulty": "hard"})
	var dir_c: Vector3 = c.call("spread_direction", Vector3.FORWARD, 10.0)
	_expect(not dir_c.is_equal_approx(dir_a), "semilla distinta cambia la dispersion")
	var easy := CombatScript.new({"seed": 99, "difficulty": "easy"})
	var hard := CombatScript.new({"seed": 99, "difficulty": "hard"})
	var easy_settings: Dictionary = easy.call("settings")
	var hard_settings: Dictionary = hard.call("settings")
	_expect(float(easy_settings["reaction"]) > float(hard_settings["reaction"]), "dificultad ajusta tiempo de reaccion")
	_expect(float(easy_settings["spread"]) > float(hard_settings["spread"]), "dificultad ajusta dispersion")


func _integracion_disparo() -> void:
	_case = "disparo contra jugador falso"
	GoreFxScript.set_gore_enabled(false)
	var fake := _make_fake_player(Vector3(0.0, 0.0, -8.0), 1000.0, "FakePlayer")
	await process_frame
	await physics_frame
	var npc: Node3D = ArmedNpcScript.new()
	npc.call("apply_options", {
		"id": "gunner", "role": "hostile", "difficulty": "hard", "weapon_id": "pistol",
		"seed": 5, "spread_scale": 0.0, "max_health": 100.0,
	})
	_root.add_child(npc)
	npc.global_position = Vector3(0.0, 0.0, 0.0)
	npc.set("target", fake)
	npc.set("auto_tick", false)
	npc.look_at(fake.global_position)
	_shots.clear()
	npc.connect("fired", Callable(self, "_on_fired"))
	await process_frame
	await physics_frame
	_expect(npc.get("combat") != null, "NPC armado construye logica de combate")
	_expect(npc.get("damageable") != null, "NPC armado incorpora Damageable")
	_expect(npc.get("weapon_system") != null, "NPC armado equipa WeaponSystem")
	_expect_eq(int(npc.call("current_ammo")), 12, "cargador inicial del NPC")
	var fake_damage: Node = fake.get_node("Damage")
	var health_before: float = float(fake_damage.get("health"))
	var decision: Dictionary = npc.call("tick", 0.3)
	_expect_eq(str(decision.get("id", "")), "attack", "decide atacar al jugador visible")
	npc.call("tick", 0.3)
	_expect(_shots.size() >= 1, "disparo emitido por el NPC")
	if _shots.size() > 0:
		_expect(bool((_shots[0] as Dictionary).get("hit", false)), "raycast del NPC impacta")
	_expect(float(fake_damage.get("health")) < health_before, "disparo del NPC danha al jugador falso")
	_expect_eq(int(npc.call("current_ammo")), 11, "municion del NPC se agota por disparo")
	var blocked: Dictionary = npc.call("fire")
	_expect(not bool(blocked.get("fired", false)), "cadencia bloquea disparo inmediato")
	npc.call("tick", 0.25)
	_expect(_shots.size() >= 2, "tras cadencia puede volver a disparar")
	GoreFxScript.set_gore_enabled(null)


func _civil_huye() -> void:
	_case = "civil pacifico huye"
	var threat := _make_fake_player(Vector3(0.0, 0.0, 8.0), 1000.0, "Threat")
	await physics_frame
	var civ: Node3D = ArmedNpcScript.new()
	civ.call("apply_options", {
		"id": "civil", "role": "civilian", "difficulty": "normal", "weapon_id": "pistol",
		"seed": 3, "max_health": 100.0,
	})
	_root.add_child(civ)
	civ.global_position = Vector3(0.0, 0.0, 0.0)
	civ.set("target", threat)
	civ.look_at(threat.global_position)
	await process_frame
	await physics_frame
	var decision: Dictionary = civ.call("tick", 0.1)
	_expect_eq(str(decision.get("id", "")), "flee", "civil huye en lugar de atacar")
	var start_distance: float = civ.global_position.distance_to(threat.global_position)
	civ.set("auto_tick", true)
	for i in range(6):
		await physics_frame
	_expect(civ.global_position.distance_to(threat.global_position) > start_distance + 0.1, "civil se aleja fisicamente")
	_expect_eq(int(civ.call("current_ammo")), 12, "civil no gasta municion al huir")


func _muerte_y_drop() -> void:
	_case = "muerte, ragdoll y arma recogible"
	var victim: Node3D = ArmedNpcScript.new()
	victim.call("apply_options", {
		"id": "victim", "role": "hostile", "weapon_id": "shotgun", "seed": 9,
		"drop_weapon_on_death": true, "max_health": 100.0,
	})
	_root.add_child(victim)
	victim.global_position = Vector3(14.0, 0.0, 0.0)
	await process_frame
	await physics_frame
	var attacker := Node3D.new()
	attacker.name = "Attacker"
	_root.add_child(attacker)
	victim.call("take_damage", 200.0, victim.global_position + Vector3(0.0, 1.4, 1.0), Vector3.FORWARD, attacker)
	_expect(victim.call("is_dead"), "Damageable marca la muerte del NPC")
	var report: Dictionary = victim.get("death_report")
	_expect(bool(report.get("ok", false)), "informe de muerte generado")
	_expect(report.get("ragdoll") is RigidBody3D, "cuerpo convertido en RigidBody3D ragdoll")
	_expect(report.get("weapon") is RigidBody3D, "arma soltada como RigidBody3D recogible")
	var drop: RigidBody3D = report.get("weapon")
	if drop != null:
		_expect(str(drop.get_meta("weapon_id")) == "shotgun", "arma soltada conserva su id")
		_expect(drop.is_in_group("weapon_pickup"), "arma soltada en grupo de recogida")
		await physics_frame
		await physics_frame
		_expect(drop.linear_velocity.length() > 0.01, "impulso aplicado al arma soltada")
		_expect(str(ArmedNpcScript.pick_up_weapon(drop)) == "shotgun", "arma soltada puede recogerse")
	_expect(victim.current_action() != "attack", "NPC muerto deja de atacar")


func _limite_plataforma() -> void:
	_case = "limite de NPCs activos por plataforma"
	_expect(int(ArmedNpcScript.max_active("android")) < int(ArmedNpcScript.max_active("pc")), "movil tiene menos NPCs que PC")
	_expect(int(ArmedNpcScript.max_active("vr")) <= int(ArmedNpcScript.max_active("pc")), "VR no supera PC")
	ArmedNpcScript.clear_registry()
	ArmedNpcScript.limits_override["pc"] = 1
	var first: Node3D = ArmedNpcScript.spawn(_root, Vector3(30.0, 0.0, 0.0), {"id": "limit_a", "platform": "pc"})
	var second: Node3D = ArmedNpcScript.spawn(_root, Vector3(31.0, 0.0, 0.0), {"id": "limit_b", "platform": "pc"})
	_expect(first != null, "primer NPC dentro del limite")
	_expect(second == null, "segundo NPC rechazado por limite")
	_expect_eq(int(ArmedNpcScript.active_count()), 1, "registro de activos respeta el limite")
	ArmedNpcScript.limits_override.erase("pc")
	ArmedNpcScript.clear_registry()


func _make_fake_player(position: Vector3, p_health: float, id: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = id
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 2.0, 0.8)
	shape.shape = box
	shape.position = Vector3(0.0, 1.0, 0.0)
	body.add_child(shape)
	var damageable = DamageableScript.new()
	damageable.name = "Damage"
	damageable.set("health", p_health)
	damageable.set("max_health", p_health)
	body.add_child(damageable)
	_root.add_child(body)
	return body


func _on_fired(result: Dictionary) -> void:
	_shots.append(result)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_eq(actual, expected, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])
