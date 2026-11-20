extends SceneTree

const Harness = preload("res://tests/vr_sim_harness.gd")
const VrGameModeScript = preload("res://core/vr/vr_game_mode.gd")
const ArmedNpcScript = preload("res://core/game/armed_npc.gd")
const SessionScript = preload("res://core/game/game_session.gd")

const STEP: float = 1.0 / 60.0

var _checks: int = 0
var _failures: Array = []
var _sim: float = 0.0


class PlayerStub extends CharacterBody3D:
	var health: float = 100.0

	func take_damage(amount: float, _point: Vector3 = Vector3.ZERO, _normal: Vector3 = Vector3.UP, _source = null) -> void:
		health -= amount


func _initialize() -> void:
	await process_frame
	await _test_office_world()
	await _test_passive_start_and_movement()
	await _test_civilian_never_fires()
	await _test_hostile_reaction_and_tokens()
	await _test_no_shots_through_walls()
	_test_menu()
	ArmedNpcScript.clear_registry()
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


func _run(frames: int) -> void:
	for i in frames:
		await physics_frame
		_sim += STEP


func _models_under(node: Node) -> Dictionary:
	var counts: Dictionary = {"instances": 0, "paths": {}}
	for item in node.find_children("*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = (item as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null:
			continue
		var path: String = mm.mesh.resource_path
		if path.begins_with("res://assets/models/maps/"):
			counts["instances"] = int(counts["instances"]) + mm.instance_count
			(counts["paths"] as Dictionary)[path.get_slice("::", 0)] = true
	for item in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (item as MeshInstance3D).mesh
		if mesh != null and mesh.resource_path.begins_with("res://assets/models/maps/"):
			counts["instances"] = int(counts["instances"]) + 1
			(counts["paths"] as Dictionary)[mesh.resource_path.get_slice("::", 0)] = true
	return counts


func _test_office_world() -> void:
	print("-- oficina 3D real en VR")
	var meta: Dictionary = VrGameModeScript.default_map_meta()
	_expect(str(meta.get("choice_label", "")) == "OFICINA", "el mapa por defecto de VR es la oficina")
	_expect(str(meta.get("theme", "")) == "urbano" and bool(meta.get("office_spawn", false)), "tema urbano con la Oficina Central y spawn dentro")
	var office_spec: Dictionary = (meta["theme_data"] as Dictionary).get("office", {})
	_expect(not office_spec.is_empty(), "el mapa trae una oficina")
	var h = Harness.new()
	await h.start(self, meta)
	var office: Node = h.world.find_child("Office_*", true, false)
	_expect(office != null, "el mundo VR contiene el nodo Office")
	if office != null:
		var counts: Dictionary = _models_under(office)
		print("modelos de assets/models/maps en la oficina: %d instancias, %d archivos" % [counts["instances"], (counts["paths"] as Dictionary).size()])
		_expect(int(counts["instances"]) >= 60, "la oficina usa >= 60 instancias de modelos Kenney")
		_expect((counts["paths"] as Dictionary).size() >= 8, "la oficina usa >= 8 modelos distintos (suelo, muros, puerta, escritorio, silla...)")
		for part in ["OfficeFloor", "OfficeWalls", "OfficeFurniture", "OfficeRoof", "OfficeCollision"]:
			_expect(office.get_node_or_null(part) != null, "oficina con " + part)
		_expect(office.find_children("*", "OmniLight3D", true, false).size() >= 1, "oficina con luces")
		for path in (counts["paths"] as Dictionary).keys():
			_expect(FileAccess.file_exists(str(path) + ".import"), "existe .import de " + str(path))
	var presets := ConfigFile.new()
	_expect(presets.load("res://export_presets.cfg") == OK, "export_presets.cfg legible")
	for section in presets.get_sections():
		if presets.has_section_key(section, "exclude_filter"):
			var filter: String = str(presets.get_value(section, "exclude_filter"))
			_expect(not filter.contains("assets") and not filter.contains("models"), "el export no excluye assets/models")

	var bounds: AABB = h.world.bounds
	_expect(bounds.size.x >= 10.0 and bounds.size.x <= 30.0 and bounds.size.z >= 10.0 and bounds.size.z <= 30.0, "tamaño del mapa 10-30 m")
	var cell: Vector2i = office_spec.get("cell", Vector2i.ZERO)
	var size: int = int(office_spec.get("width", 5))
	var spot: Vector3 = h.origin_pos()
	_expect(spot.x > cell.x and spot.x < cell.x + size and spot.z > cell.y and spot.z < cell.y + size, "el jugador nace dentro de la oficina")
	var space: PhysicsDirectSpaceState3D = h.world.get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 1.0, spot + Vector3.DOWN * 3.0, 1)
	var floor_hit: Dictionary = space.intersect_ray(down)
	_expect(not floor_hit.is_empty() and absf(float(floor_hit["position"].y)) < 0.3, "colision de suelo bajo el jugador")
	var walls: int = 0
	for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var ray := PhysicsRayQueryParameters3D.create(spot + Vector3.UP, spot + Vector3.UP + dir * 8.0, 1)
		if not space.intersect_ray(ray).is_empty():
			walls += 1
	_expect(walls >= 3, "colisiones de muros alrededor del jugador (%d/4)" % walls)
	var up := PhysicsRayQueryParameters3D.create(spot + Vector3.UP, spot + Vector3.UP * 6.0, 1)
	print("techo con colision: ", not space.intersect_ray(up).is_empty())
	h.cleanup()
	await process_frame


func _test_passive_start_and_movement() -> void:
	print("-- NPC pasivos al inicio y en movimiento")
	var h = Harness.new()
	await h.start(self, VrGameModeScript.default_map_meta())
	var spawn: Vector3 = h.origin_pos()
	var npcs: Array = h.world.npcs
	var roles: Dictionary = {}
	var hostile_count: int = 0
	var shots: Array = [0]
	var start: Dictionary = {}
	var travelled: Dictionary = {}
	var last: Dictionary = {}
	for npc in npcs:
		roles[npc.role] = int(roles.get(npc.role, 0)) + 1
		npc.fired.connect(func(_r): shots[0] += 1)
		start[npc.npc_id] = npc.global_position
		last[npc.npc_id] = npc.global_position
		travelled[npc.npc_id] = 0.0
		_expect(npc.global_position.distance_to(spawn) >= 7.0, "zona segura 8 m (tolerancia por el paseo tras nacer): %s a %.1f m" % [npc.npc_id, npc.global_position.distance_to(spawn)])
		if npc.role == "hostile":
			hostile_count += 1
			_expect(npc.global_position.distance_to(spawn) >= 12.0, "hostil lejano >= 12 m (%.1f)" % npc.global_position.distance_to(spawn))
		if npc.role == "civilian":
			_expect(str(npc.weapon_id).is_empty(), "civil sin arma")
	print("roles: ", roles)
	_expect(hostile_count >= 2 and hostile_count <= 3, "2-3 hostiles (%d)" % hostile_count)
	_expect(int(roles.get("civilian", 0)) >= 4, "mayoria de civiles pasivos")
	_expect(not roles.has("zombie") and not roles.has("defender"), "sin zombis ni defensores por defecto")
	var health_before: float = float(h.rig.health)
	for second in 5:
		for i in 60:
			await _run(1)
			for npc in npcs:
				var here: Vector3 = npc.global_position
				travelled[npc.npc_id] = float(travelled[npc.npc_id]) + here.distance_to(last[npc.npc_id])
				last[npc.npc_id] = here
	_expect(shots[0] == 0, "tras 5 s sin disparar el jugador, ningun NPC disparo (%d)" % shots[0])
	_expect(float(h.rig.health) == health_before, "el jugador no recibio dano en 5 s")
	for i in 300:
		await _run(1)
		for npc in npcs:
			var here: Vector3 = npc.global_position
			travelled[npc.npc_id] = float(travelled[npc.npc_id]) + here.distance_to(last[npc.npc_id])
			last[npc.npc_id] = here
	_expect(shots[0] == 0, "tras 10 s sin provocar, ningun NPC disparo (%d)" % shots[0])
	h.world._sync_locomotion()
	var moving_models: int = 0
	for npc in npcs:
		var id: String = npc.npc_id
		print("%s %s recorrido %.1f m (neto %.1f)" % [id, npc.role, travelled[id], npc.global_position.distance_to(start[id])])
		if float(travelled[id]) < 2.0:
			print("  lento: wp=%s has=%s wait=%.1f stuck=%.1f goal=%s pos=%s path=%d/%d act=%s" % [npc._wp, npc._wp_has, npc._wait_left, npc._stuck_time, npc._goal, npc.global_position, npc._path_index, npc._path.size(), npc.current_action()])
		_expect(float(travelled[id]) >= 2.0, "%s se movio >= 2 m en 10 s (%.1f)" % [id, travelled[id]])
		var model: Node3D = h.world._model_for(npc)
		_expect(model != null and bool(model.call("is_loaded")), "%s tiene modelo animado" % id)
		if model != null:
			var player: AnimationPlayer = model.get("animation_player") as AnimationPlayer
			var anim: String = str(model.call("current_animation"))
			_expect(player != null and player.is_playing() and not anim.is_empty(), "%s anima (no T-pose): anim=%s player=%s playing=%s skin=%s" % [id, anim, player, player.is_playing() if player != null else "-", npc.role])
			if anim == "walk":
				moving_models += 1
	_expect(moving_models >= 1, "hay NPC con animacion de caminar")
	h.cleanup()
	await process_frame


func _make_stage(wall_between: bool = false) -> Dictionary:
	ArmedNpcScript.clear_registry()
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120.0, 1.0, 120.0)
	floor_shape.shape = box
	floor_shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_shape)
	stage.add_child(floor_body)
	if wall_between:
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		var wall_shape := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(0.4, 4.0, 30.0)
		wall_shape.shape = wall_box
		wall_shape.position = Vector3(7.0, 2.0, 0.0)
		wall.add_child(wall_shape)
		stage.add_child(wall)
	var player := PlayerStub.new()
	player.collision_layer = 1
	var capsule := CollisionShape3D.new()
	var cap_shape := CapsuleShape3D.new()
	cap_shape.radius = 0.35
	cap_shape.height = 1.8
	capsule.shape = cap_shape
	capsule.position = Vector3(0.0, 0.9, 0.0)
	player.add_child(capsule)
	stage.add_child(player)
	player.global_position = Vector3.ZERO
	await physics_frame
	return {"stage": stage, "player": player}


func _spawn_npc(stage: Node3D, player: Node3D, role: String, weapon: String, at: Vector3, index: int) -> Node3D:
	var npc: Node3D = ArmedNpcScript.spawn(stage, at, {
		"id": "t_%s_%d" % [role, index], "role": role, "weapon_id": weapon,
		"target": player, "platform": "pc", "realistic": true, "seed": 100 + index,
		"faction_id": "criminal" if role == "hostile" else "civilian",
		"patrol_speed": 1.1, "run_speed": 3.6,
	}) as Node3D
	var toward: Vector3 = player.global_position - at
	npc.rotation.y = atan2(-toward.x, -toward.z)
	return npc


func _test_civilian_never_fires() -> void:
	print("-- civil jamas dispara")
	var built: Dictionary = await _make_stage()
	var stage: Node3D = built["stage"]
	var player: PlayerStub = built["player"]
	var civilians: Array = []
	var shots: Array = [0]
	for i in 3:
		var npc: Node3D = _spawn_npc(stage, player, "civilian", "pistol", Vector3(4.0 + i, 0.0, 6.0), i)
		npc.fired.connect(func(_r): shots[0] += 1)
		civilians.append(npc)
	await _run(90)
	for npc in civilians:
		npc.hear_gunshot(player.global_position, 1.0, "player")
	await _run(240)
	_expect(shots[0] == 0, "civiles armados, con el jugador a la vista y tiroteo cerca, no disparan (%d)" % shots[0])
	_expect(player.health == 100.0, "el jugador no recibio dano de civiles")
	stage.free()
	await process_frame


func _test_hostile_reaction_and_tokens() -> void:
	print("-- hostil: reaccion >= 12 m, max 2 atacantes, rafagas")
	var built: Dictionary = await _make_stage()
	var stage: Node3D = built["stage"]
	var player: PlayerStub = built["player"]
	var lone: Node3D = _spawn_npc(stage, player, "hostile", "assault_rifle", Vector3(0.0, 0.0, 14.0), 50)
	var first_shot: Array = [-1.0]
	var seen_at: Array = [-1.0]
	lone.fired.connect(func(_r): if first_shot[0] < 0.0: first_shot[0] = _sim)
	var start: float = _sim
	for i in 300:
		await _run(1)
		if seen_at[0] < 0.0 and lone._engaged:
			seen_at[0] = _sim
	_expect(seen_at[0] >= 0.0, "el hostil a 14 m con linea de vision detecta al jugador")
	_expect(first_shot[0] >= 0.0, "el hostil a 14 m reacciona y dispara")
	if first_shot[0] >= 0.0 and seen_at[0] >= 0.0:
		var delay: float = first_shot[0] - seen_at[0]
		print("retardo de reaccion: %.2f s" % delay)
		_expect(delay >= 0.8, "ningun disparo antes de 0.8 s tras verte (%.2f)" % delay)
		_expect(first_shot[0] - start >= 0.8, "primer disparo despues de 0.8 s del inicio")
	_expect(player.health > 60.0, "dano bajo al inicio (%.0f)" % player.health)
	lone.free()
	await physics_frame

	var squad: Array = []
	var log: Array = []
	for i in 6:
		var angle: float = -0.6 + 0.24 * float(i)
		var at := Vector3(sin(angle) * 15.0, 0.0, cos(angle) * 15.0)
		var npc: Node3D = _spawn_npc(stage, player, "hostile", "assault_rifle", at, i)
		var id: String = npc.npc_id
		npc.fired.connect(func(_r): log.append([id, _sim]))
		squad.append(npc)
	player.health = 100.0
	var begin: float = _sim
	var max_simultaneous: int = 0
	for i in 720:
		await _run(1)
		var recent: Dictionary = {}
		for entry in log:
			if _sim - float(entry[1]) <= 1.0:
				recent[entry[0]] = true
		max_simultaneous = maxi(max_simultaneous, recent.size())
	print("disparos: %d, maximo de tiradores en 1 s: %d, vida jugador %.0f" % [log.size(), max_simultaneous, player.health])
	_expect(log.size() > 0, "los 6 hostiles disparan en algun momento")
	_expect(max_simultaneous <= 2, "nunca mas de 2 NPC disparan en el mismo segundo (%d)" % max_simultaneous)
	var first_by: Dictionary = {}
	var longest_burst: int = 0
	var run_len: Dictionary = {}
	var prev: Dictionary = {}
	for entry in log:
		var who: String = entry[0]
		if not first_by.has(who):
			first_by[who] = float(entry[1])
		if float(entry[1]) - float(prev.get(who, -10.0)) < 0.35:
			run_len[who] = int(run_len.get(who, 0)) + 1
		else:
			run_len[who] = 1
		longest_burst = maxi(longest_burst, int(run_len[who]))
		prev[who] = float(entry[1])
	for id in first_by:
		_expect(float(first_by[id]) - begin >= 0.8, "%s no dispara antes de 0.8 s (%.2f)" % [id, float(first_by[id]) - begin])
	_expect(longest_burst <= 5, "rafagas cortas (max %d tiros seguidos)" % longest_burst)
	_expect(player.health > 0.0, "el jugador sobrevive 15 s al ataque inicial")
	stage.free()
	await process_frame


func _test_no_shots_through_walls() -> void:
	print("-- sin balas a traves de paredes")
	var built: Dictionary = await _make_stage(true)
	var stage: Node3D = built["stage"]
	var player: PlayerStub = built["player"]
	var shots: Array = [0]
	for i in 3:
		var npc: Node3D = _spawn_npc(stage, player, "hostile", "assault_rifle", Vector3(12.0 + i, 0.0, -2.0 + 2.0 * i), i)
		npc.fired.connect(func(_r): shots[0] += 1)
	await _run(360)
	_expect(shots[0] == 0, "con una pared entre medias no hay disparos (%d)" % shots[0])
	_expect(player.health == 100.0, "el jugador no recibe dano a traves de la pared")
	stage.free()
	await process_frame


func _test_menu() -> void:
	print("-- menu VR: oficina primera opcion")
	_expect(str((VrGameModeScript.MAP_CHOICES[0] as Dictionary)["label"]) == "OFICINA", "OFICINA es la primera opcion")
	_expect(str((VrGameModeScript.START_BUTTONS[0] as Dictionary)["label"]).contains("OFICINA"), "el boton JUGAR muestra OFICINA")
	var started: Array = []
	SessionScript.start_override = func(meta: Dictionary) -> void: started.append(meta)
	SessionScript.platform_override = "vr"
	SessionScript.vr_menu_confirmed = false
	var menu = VrGameModeScript.build_start_menu(VrGameModeScript.default_map_meta(), self)
	_expect(menu != null, "menu de inicio creado")
	if menu != null:
		var host = menu.get_parent()
		host.on_button("map_next")
		_expect(str(host.chosen_meta.get("choice_label", "")) == "CIUDAD", "OTRO MAPA cambia la seleccion sin arrancar")
		_expect(started.is_empty(), "OTRO MAPA no inicia partida")
		host.on_button("play")
		_expect(started.size() == 1 and str((started[0] as Dictionary).get("choice_label", "")) == "CIUDAD", "JUGAR inicia el mapa elegido")
		host.free()
	SessionScript.start_override = Callable()
	SessionScript.platform_override = ""
	SessionScript.vr_menu_confirmed = false
	VrGameModeScript.last_start_menu = null
