class_name ModeSurvival
extends GameMode

const ArmedNpcScript = preload("res://core/game/armed_npc.gd")
const PickupManagerScript = preload("res://core/game/pickups.gd")
const NPCFactionsScript = preload("res://core/npc/npc_factions.gd")
const NPCLODScript = preload("res://core/npc/npc_lod.gd")

var _wave_timer: float = 0.0
var _wave_interval: float = 10.0
var _enemies_per_wave_base: int = 3
var _enemies_per_wave_multiplier: float = 1.5
var _max_enemies_per_wave: int = 30
var _current_wave_enemies: Array = []
var _spawned_enemies_total: int = 0
var _wave_in_progress: bool = false
var _boss_wave_interval: int = 5
var _difficulty_multiplier: float = 1.0
var _factions = null
var _navigation = null
var _bounds: AABB = AABB()
var _nav_cell_size: float = 1.0
var _player_avoid_center: Vector3 = Vector3.ZERO
var _player_avoid_radius: float = 8.0
var _objective_clear_zone: Dictionary = {}
var _objective_collect_crates: Dictionary = {}
var _objective_eliminate_target: Dictionary = {}
var _crates_collected: int = 0
var _crates_needed: int = 3
var _marked_target: Node3D = null
var _zone_clear_center: Vector3 = Vector3.ZERO
var _zone_clear_radius: float = 15.0
var _zone_clear_done: bool = false

func _init(p_world: Node3D = null, p_player: Node3D = null, p_seed: int = 0) -> void:
	super._init(p_world, p_player, p_seed)
	mode_type = ModeType.SURVIVAL
	_wave = 0
	_setup_factions()

func _setup_factions() -> void:
	_factions = NPCFactionsScript.new({})
	for id in ["civilian", "criminal", "police", "zombie"]:
		_factions.call("register_faction", id, id)
	_factions.call("set_relation", "police", "criminal", -85.0)
	_factions.call("set_relation", "civilian", "criminal", -70.0)
	_factions.call("set_relation", "civilian", "zombie", -90.0)
	_factions.call("set_relation", "police", "zombie", -90.0)
	_factions.call("set_relation", "criminal", "civilian", -45.0)
	_factions.call("set_relation", "zombie", "civilian", -95.0)

func setup(p_world: Node3D, p_player: Node3D, p_seed: int = 0) -> void:
	super.setup(p_world, p_player, p_seed)
	if world and world.has_method("spawn_point_positions"):
		_bounds = world.world_report.get("bounds", AABB())
	if world and world.has_method("navigation"):
		_navigation = world.navigation
	if world and world.has_method("bounds"):
		_bounds = world.bounds
	_setup_objectives()
	_setup_pickup_manager()

func _setup_objectives() -> void:
	_objectives = []
	
	_objective_clear_zone = {
		"id": "clear_zone",
		"name": "Limpiar la zona",
		"description": "Elimina todos los enemigos en el area marcada",
		"type": "clear_zone",
		"completed": false,
		"progress": 0,
		"target": 0,
	}
	_objectives.append(_objective_clear_zone)
	
	_objective_collect_crates = {
		"id": "collect_crates",
		"name": "Recoger suministros",
		"description": "Reunir %d cajas de suministro" % _crates_needed,
		"type": "collect_crates",
		"completed": false,
		"progress": 0,
		"target": _crates_needed,
	}
	_objectives.append(_objective_collect_crates)
	
	_objective_eliminate_target = {
		"id": "eliminate_target",
		"name": "Eliminar objetivo marcado",
		"description": "Derrota al objetivo de alto valor",
		"type": "eliminate_target",
		"completed": false,
		"progress": 0,
		"target": 1,
	}
	_objectives.append(_objective_eliminate_target)

func _setup_pickup_manager() -> void:
	_pickup_manager = PickupManagerScript.new()
	_pickup_manager.name = "PickupManager"
	if world:
		world.add_child(_pickup_manager)
	_pickup_manager.setup(world, player, _seed)
	_pickup_manager.crate_collected.connect(_on_crate_collected)
	_pickup_manager.ammo_picked.connect(_on_ammo_picked)
	_pickup_manager.health_picked.connect(_on_health_picked)
	_pickup_manager.armor_picked.connect(_on_armor_picked)
	_pickup_manager.weapon_picked.connect(_on_weapon_picked)

func start() -> void:
	super.start()
	_wave = 0
	_spawned_enemies_total = 0
	_difficulty_multiplier = 1.0
	_start_next_wave()

func stop() -> void:
	super.stop()
	for enemy in _current_wave_enemies:
		if enemy and is_instance_valid(enemy):
			enemy.queue_free()
	_current_wave_enemies.clear()

func tick(delta: float) -> void:
	if not is_active:
		return
	
	super.tick(delta)
	
	if _pickup_manager:
		_pickup_manager.tick(delta)
	
	if _wave_in_progress:
		_check_wave_completion()
	else:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_start_next_wave()
	
	_check_objectives()

func _start_next_wave() -> void:
	_wave += 1
	_wave_in_progress = true
	_difficulty_multiplier = 1.0 + (_wave - 1) * 0.15
	
	var enemy_count = _calculate_wave_enemy_count()
	var is_boss_wave = (_wave % _boss_wave_interval == 0)
	
	if is_boss_wave:
		enemy_count = maxi(enemy_count, 1)
	
	_spawn_wave_enemies(enemy_count, is_boss_wave)
	
	_wave_interval = 10.0 + _wave * 0.5
	
	wave_started.emit(_wave, enemy_count)
	
	if _wave == 1:
		_objective_clear_zone["target"] = enemy_count
		_objective_clear_zone["progress"] = 0
		objective_updated.emit(_objective_clear_zone)

func _calculate_wave_enemy_count() -> int:
	var base = _enemies_per_wave_base * _wave
	var scaled = int(base * _enemies_per_wave_multiplier)
	return clampi(scaled, 1, _max_enemies_per_wave)

func _spawn_wave_enemies(count: int, is_boss_wave: bool) -> void:
	if not world or not _navigation:
		return
	
	var spawn_points = _pick_multiple_spawns_far_from(_player_avoid_center, count, _player_avoid_radius)
	if spawn_points.is_empty():
		return
	
	var npc_lod = NPCLODScript.new()
	var platform = "pc"
	if world and world.has_method("_session_platform"):
		platform = world.call("_session_platform")
	
	var weapons = ["assault_rifle", "submachine_gun", "shotgun"]
	var rng = RandomNumberGenerator.new()
	rng.seed = _seed + _wave * 777
	
	var is_zombie_wave = (_wave % 3 == 0) or is_boss_wave
	
	for i in range(count):
		if i >= spawn_points.size():
			break
		
		var spawn_pos = spawn_points[i]
		var is_zombie = is_zombie_wave or (rng.randf() < 0.4)
		var role = "hostile"
		var faction = is_zombie ? "zombie" : "criminal"
		var weapon = is_zombie ? "" : weapons[rng.randi_range(0, weapons.size() - 1)]
		
		var personality = {
			"temperament": rng.randf_range(0.3, 0.9),
			"confidence": rng.randf_range(0.3, 0.9),
			"bravery": rng.randf_range(0.4, 0.95),
			"fear": is_zombie ? 0.05 : rng.randf_range(0.1, 0.5),
			"curiosity": rng.randf_range(0.2, 0.7),
			"sociability": rng.randf_range(0.1, 0.6),
			"aggressiveness": rng.randf_range(0.7, 0.98),
		}
		
		var health_mult = _difficulty_multiplier
		var speed_mult = 1.0 + (_wave - 1) * 0.05
		var accuracy_mult = 0.5 + (_wave - 1) * 0.03
		
		var needs = {
			"fatigue": 0.1,
			"stress": 0.1,
			"fear": 0.05,
			"confusion": 0.0,
			"stun": 0.0,
			"health": 1.0 * health_mult,
		}
		
		var def = {
			"id": "survival_npc_%02d_%02d" % [_wave, i],
			"role": role,
			"faction": faction,
			"weapon": weapon,
			"personality": personality,
			"needs": needs,
			"routine": [],
			"state": "idle",
			"is_zombie": is_zombie,
			"health_multiplier": health_mult,
			"speed_multiplier": speed_mult,
			"accuracy_multiplier": accuracy_mult,
		}
		
		if is_boss_wave and i == 0:
			def["is_boss"] = true
			def["health_multiplier"] *= 3.0
			def["speed_multiplier"] *= 1.2
			def["name"] = "JEFE OLEADA %d" % _wave
			_objective_eliminate_target["target_node_id"] = def["id"]
			_objective_eliminate_target["progress"] = 0
			objective_updated.emit(_objective_eliminate_target)
		
		var options = {
			"id": def["id"],
			"npc_id": def["id"],
			"role": role,
			"faction_id": faction,
			"weapon_id": weapon,
			"difficulty": "normal",
			"seed": _seed + _wave * 1000 + i * 17,
			"platform": platform,
			"target": player,
			"target_id": "player",
			"navigation": _navigation,
			"observer": world,
			"fx_parent": world,
			"bounds": _bounds,
			"nav_cell_size": _nav_cell_size,
			"lod": npc_lod,
			"factions": _factions,
			"patrol_points": [],
			"attack_points": [],
			"cover_points": [],
			"tick_rate": 12.0,
			"vision_range": 20.0 + _wave * 1.0,
			"patrol_speed": 1.2 * speed_mult,
			"run_speed": 4.0 * speed_mult,
			"realistic": true,
			"avoid_center": _player_avoid_center,
			"avoid_radius": _player_avoid_radius,
			"drop_weapon_on_death": true,
			"is_zombie": is_zombie,
			"health_multiplier": def["health_multiplier"],
			"speed_multiplier": def["speed_multiplier"],
			"accuracy_multiplier": def["accuracy_multiplier"],
			"is_boss": def.has("is_boss"),
		}
		
		var npc_root = world.get_node_or_null("LivingNPCs")
		if not npc_root:
			npc_root = Node3D.new()
			npc_root.name = "LivingNPCs"
			world.add_child(npc_root)
		
		_factions.call("set_member", def["id"], faction)
		
		var npc = ArmedNpcScript.spawn(npc_root, spawn_pos, options) as Node3D
		if npc:
			if is_zombie:
				world.call("_attach_character_model", npc, "enemy", "npc_%s" % def["id"])
			else:
				world.call("_attach_character_model", npc, "criminal", "npc_%s" % def["id"])
			
			if def.has("is_boss"):
				_marked_target = npc
				npc.set("is_boss", true)
				npc.set("boss_wave", _wave)
			
			_current_wave_enemies.append(npc)
			_spawned_enemies_total += 1
			
			if npc.has_signal("died"):
				npc.connect("died", Callable(self, "_on_enemy_died").bind(npc, def))
			if npc.has_signal("damaged"):
				npc.connect("damaged", Callable(self, "_on_enemy_damaged").bind(npc))
	
	if _pickup_manager:
		_pickup_manager.spawn_supply_crates(_wave, spawn_points)

func _on_enemy_died(npc: Node3D, def: Dictionary) -> void:
	_current_wave_enemies.erase(npc)
	
	if score_board:
		var base_score = 100
		if def.has("is_boss"):
			base_score = 500
		score_board.add_kill(def.has("is_zombie"), def.has("is_boss"))
	
	_update_clear_zone_progress()
	
	if def.has("is_boss") and _marked_target == npc:
		_objective_eliminate_target["completed"] = true
		_objective_eliminate_target["progress"] = 1
		objective_completed.emit(_objective_eliminate_target)
		_marked_target = null

func _on_enemy_damaged(npc: Node3D, amount: float, point: Vector3, normal: Vector3) -> void:
	if score_board:
		score_board.register_hit(point, normal, amount)

func _check_wave_completion() -> void:
	var alive_count = 0
	for enemy in _current_wave_enemies:
		if enemy and is_instance_valid(enemy) and not bool(enemy.call("is_dead")):
			alive_count += 1
	
	if alive_count == 0:
		_wave_in_progress = false
		_wave_timer = _wave_interval
		
		var wave_score = score_board.get_wave_score() if score_board else 0
		wave_completed.emit(_wave, wave_score)
		
		if score_board:
			score_board.end_wave(_wave)

func _check_objectives() -> void:
	if not _zone_clear_done and _objective_clear_zone and not bool(_objective_clear_zone.get("completed", false)):
		if _current_wave_enemies.size() == 0 and _wave > 0:
			_objective_clear_zone["completed"] = true
			_objective_clear_zone["progress"] = _objective_clear_zone.get("target", 0)
			_zone_clear_done = true
			objective_completed.emit(_objective_clear_zone)

func _update_clear_zone_progress() -> void:
	if _objective_clear_zone and not bool(_objective_clear_zone.get("completed", false)):
		var target = int(_objective_clear_zone.get("target", 0))
		var killed = target - _current_wave_enemies.size()
		_objective_clear_zone["progress"] = maxi(0, killed)
		objective_updated.emit(_objective_clear_zone)

func _on_crate_collected(position: Vector3) -> void:
	_crates_collected += 1
	if _objective_collect_crates and not bool(_objective_collect_crates.get("completed", false)):
		_objective_collect_crates["progress"] = _crates_collected
		objective_updated.emit(_objective_collect_crates)
		if _crates_collected >= _crates_needed:
			_objective_collect_crates["completed"] = true
			objective_completed.emit(_objective_collect_crates)

func _on_ammo_picked(ammo_type: String, amount: int) -> void:
	if score_board:
		score_board.add_ammo_pickup(ammo_type, amount)

func _on_health_picked(amount: float) -> void:
	if score_board:
		score_board.add_health_pickup(amount)

func _on_armor_picked(amount: float) -> void:
	if score_board:
		score_board.add_armor_pickup(amount)

func _on_weapon_picked(weapon_id: String) -> void:
	if score_board:
		score_board.add_weapon_pickup(weapon_id)

func get_wave() -> int:
	return _wave

func get_enemies_remaining() -> int:
	return _current_wave_enemies.size()

func is_wave_in_progress() -> bool:
	return _wave_in_progress

func get_time_to_next_wave() -> float:
	return _wave_timer

func get_difficulty_multiplier() -> float:
	return _difficulty_multiplier

func get_objectives() -> Array:
	return _objectives.duplicate()