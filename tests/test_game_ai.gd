extends SceneTree

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")

var _checks: int = 0
var _failures: Array = []


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


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	SessionScript.platform = "pc"
	SessionScript.seed = 4242
	var meta: Dictionary = GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 5,
	})
	_expect(bool(meta.get("ok", false)), "MapGenerator entrega una meta valida")
	meta["max_npcs"] = 8
	SessionScript.map_meta = meta.duplicate(true)
	ArmedNpc.limits_override.clear()
	ArmedNpc.limits_override["pc"] = 8
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	world.setup(meta)
	await process_frame
	for i in range(5):
		await physics_frame

	_expect(world.npcs.size() >= 6, "hay al menos 6 ArmedNpc vivos en el mundo (%d)" % world.npcs.size())
	_expect(world.target_dummies().size() == 6, "target_dummies mantiene 6 blancos por compatibilidad")
	_expect(int(world.world_report.get("static_dummies", 99)) <= 2, "como maximo 2 maniquies estaticos")
	var roles: Dictionary = {}
	for npc in world.npcs:
		var role: String = str(npc.get("role"))
		roles[role] = int(roles.get(role, 0)) + 1
	_expect(roles.has("hostile") and roles.has("civilian") and roles.has("defender") and roles.has("zombie"),
		"hay civiles, hostiles, policias y zombis")
	_expect(world.navigation != null and int(world.world_report.get("navigation", {}).get("blocked_cells", 0)) > 0,
		"la rejilla de navegacion se construyo desde la geometria real")
	var all_models: bool = true
	for npc in world.npcs:
		if npc.find_children("CharacterModel_*", "Node3D", true, false).is_empty():
			all_models = false
	_expect(all_models, "todos los NPC usan CharacterModel con modelo 3D real")
	var all_armed: bool = true
	for npc in world.npcs:
		if str(npc.get("role")) != "zombie" and str(npc.get("weapon_id")).is_empty():
			all_armed = false
	_expect(all_armed, "losNPC no zombi llevan arma visible")
	var inside_bounds: bool = true
	for npc in world.npcs:
		if not world.bounds.has_point(npc.global_position):
			inside_bounds = false
		if not bool(world.navigation.call("is_walkable_world", npc.global_position, 1.0)):
			inside_bounds = false
	_expect(inside_bounds, "ningun NPC esta fuera de limites o dentro de un obstaculo")

	var before: Array = []
	for npc in world.npcs:
		before.append(npc.global_position)
	for i in range(180):
		await physics_frame
	var moved: int = 0
	for i in range(world.npcs.size()):
		if (world.npcs[i].global_position - (before[i] as Vector3)).length() > 0.75:
			moved += 1
	_expect(moved >= 4, "al menos 4 NPC cambiaron de posicion tras 180 frames (%d)" % moved)

	var actor: Node3D = world.actor
	_expect(actor != null and actor.has_method("take_damage"), "el jugador expone take_damage")
	var hostile: Node3D = _find_role(world, "hostile")
	_expect(hostile != null, "existe un hostil para la prueba de ataque")
	if hostile != null and actor != null:
		_disable_other_npcs(world, hostile)
		hostile.set("patrol_speed", 0.0)
		hostile.set("run_speed", 0.0)
		var spot: Vector3 = _clear_spot(hostile, actor, 4.0, world)
		actor.global_position = spot
		if actor is CollisionObject3D:
			(actor as CollisionObject3D).collision_layer = 1
		if "velocity" in actor:
			actor.set("velocity", Vector3.ZERO)
		hostile.look_at(actor.global_position + Vector3.UP)
		hostile.call("set_target", actor)
		hostile.call("notice_weapon", actor.global_position)
		var initial_health: float = float(actor.get("health"))
		var damaged: bool = false
		for i in range(240):
			await physics_frame
			if float(actor.get("health")) < initial_health - 0.5:
				damaged = true
				break
		_expect(damaged, "el hostil que ve al jugador reduce su salud")
		_expect(str(hostile.call("current_action")) in [
			"attack", "aim", "patrol", "investigate", "cover", "flee", "reload", "help",
		], "el hostil permanece en un estado de combate valido")

	var civilian: Node3D = _find_role(world, "civilian")
	_expect(civilian != null, "existe un civil para la prueba de huida")
	if civilian != null and actor != null:
		_disable_other_npcs(world, civilian)
		var spot: Vector3 = _clear_spot(civilian, actor, 3.0, world)
		actor.global_position = spot
		civilian.call("notice_weapon", actor.global_position)
		var start_position: Vector3 = civilian.global_position
		for i in range(180):
			await physics_frame
		var displacement: float = civilian.global_position.distance_to(start_position)
		_expect(displacement > 1.5 and str(civilian.call("current_action")) == "flee",
			"el civil huye al ver un arma (movimiento %.2f, accion %s)" % [
				displacement, str(civilian.call("current_action")),
			])

	var alerted: Node3D = _find_role(world, "defender")
	if alerted == null:
		alerted = _find_role(world, "hostile")
	_expect(alerted != null, "existe un NPC para la prueba de oido")
	if alerted != null and actor != null:
		var before_alert: float = float(alerted.combat.get("alert_level"))
		actor.fired.emit({
			"fired": true, "position": alerted.global_position + Vector3.UP,
		})
		await physics_frame
		var after_alert: float = float(alerted.combat.get("alert_level"))
		_expect(after_alert > before_alert + 0.1 or float(alerted.get("_threat_memory")) > 0.0,
			"un disparo del jugador alerta a NPC cercanos")

	var victim: Node3D = null
	for npc in world.npcs:
		if str(npc.get("role")) == "hostile" and not bool(npc.call("is_dead")) and not str(npc.get("weapon_id")).is_empty():
			victim = npc
			break
	_expect(victim != null, "existe unNPC armado vivo para morir")
	if victim != null and actor != null:
		victim.take_damage(250.0, victim.global_position + Vector3.UP, Vector3.FORWARD, actor)
		for i in range(3):
			await physics_frame
		var report: Dictionary = victim.get("death_report")
		_expect(bool(victim.call("is_dead")), "elNPC muere al recibir dano letal")
		_expect(report.has("ragdoll") and report["ragdoll"] != null, "la muerte deja ragdoll")
		_expect(report.has("weapon") and report["weapon"] != null, "la muerte suelta el arma")
		_expect(not root.find_children("CharacterRagdoll_*", "Node3D", true, false).is_empty(),
			"CharacterModel genera ragdoll real de la muerte")

	var nodes_before: int = _count_nodes(world)
	for i in range(600):
		await physics_frame
	var nodes_after: int = _count_nodes(world)
	_expect(nodes_after - nodes_before < 220,
		"600 frames sin crecimiento ilimitado de nodos (%d -> %d)" % [nodes_before, nodes_after])
	var hud: Node = world.get_node_or_null("HudLayer/GameHud")
	if hud != null:
		var subtitle: Node = hud.get_node_or_null("SubtitleLabel")
		_expect(subtitle == null or not bool(subtitle.get("visible")),
			"los subtitulos de NPC no se muestran por defecto")


func _find_role(world: Node, role: String) -> Node3D:
	for npc in world.get("npcs"):
		if npc != null and is_instance_valid(npc) and str(npc.get("role")) == role and not bool(npc.call("is_dead")):
			return npc as Node3D
	return null


func _disable_other_npcs(world: Node, active: Node3D) -> void:
	for npc in world.get("npcs"):
		if npc != null and npc != active and npc is CollisionObject3D:
			(npc as CollisionObject3D).collision_layer = 0


func _clear_spot(npc: Node3D, actor: Node3D, distance: float, world: Node) -> Vector3:
	var fallback: Vector3 = npc.global_position + Vector3.FORWARD * distance
	var space: PhysicsDirectSpaceState3D = npc.get_world_3d().direct_space_state if npc.get_world_3d() != null else null
	if space == null:
		return fallback
	var exclude: Array[RID] = []
	if npc is CollisionObject3D:
		exclude.append((npc as CollisionObject3D).get_rid())
	if actor is CollisionObject3D:
		exclude.append((actor as CollisionObject3D).get_rid())
	var nav = world.get("navigation")
	var best: Vector3 = fallback
	var best_score: float = -INF
	for radius in [distance, distance + 1.5, distance + 3.0]:
		for i in range(24):
			var angle: float = TAU * float(i) / 24.0
			var candidate: Vector3 = npc.global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			candidate.y = npc.global_position.y
			if not world.get("bounds").has_point(candidate):
				continue
			if nav != null and not bool(nav.call("is_walkable_world", candidate, 1.0)):
				continue
			var query := PhysicsRayQueryParameters3D.create(
				npc.global_position + Vector3.UP * 1.4,
				candidate + Vector3.UP * 1.2, 1, exclude
			)
			if not space.intersect_ray(query).is_empty():
				continue
			var score: float = 0.0
			if nav != null:
				var width: int = int(nav.get("width"))
				var height: int = int(nav.get("height"))
				for y in range(height):
					for x in range(width):
						var cell := Vector2i(x, y)
						if bool(nav.call("is_blocked", cell)):
							continue
						score = maxf(score, (nav.call("cell_to_world", cell, 1.0, candidate.y) as Vector3).distance_to(candidate))
			if score > best_score:
				best_score = score
				best = candidate
	return best


func _count_nodes(node: Node) -> int:
	var total: int = 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total
