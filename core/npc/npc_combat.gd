class_name NPCCombat
extends RefCounted

const BehaviorScript = preload("res://core/npc/npc_behavior.gd")
const PerceptionScript = preload("res://core/npc/npc_perception.gd")
const NavigationScript = preload("res://core/npc/npc_navigation.gd")
const RelationsScript = preload("res://core/npc/npc_relations.gd")
const FactionsScript = preload("res://core/npc/npc_factions.gd")
const StateMachineScript = preload("res://core/npc/npc_state_machine.gd")
const ControllerScript = preload("res://core/npc/npc_controller.gd")
const PersonalityScript = preload("res://core/npc/npc_personality.gd")
const NeedsScript = preload("res://core/npc/npc_needs.gd")
const MemoryScript = preload("res://core/npc/npc_memory.gd")
const RoutineScript = preload("res://core/npc/npc_routine.gd")

const ACTION_ATTACK: String = "attack"
const ACTION_COVER: String = "cover"
const ACTION_FLEE: String = "flee"
const ACTION_RELOAD: String = "reload"
const ACTION_HELP: String = "help"
const ACTION_PATROL: String = "patrol"
const ACTION_INVESTIGATE: String = "investigate"
const ACTION_IDLE: String = "idle"

const ROLE_HOSTILE: String = "hostile"
const ROLE_CIVILIAN: String = "civilian"
const ROLE_DEFENDER: String = "defender"
const ROLE_ZOMBIE: String = "zombie"

const DIFFICULTY_EASY: String = "easy"
const DIFFICULTY_NORMAL: String = "normal"
const DIFFICULTY_HARD: String = "hard"

const ATTITUDE_HOSTILE: String = "hostil"
const ATTITUDE_NEUTRAL: String = "neutral"
const ATTITUDE_FRIENDLY: String = "amistoso"

const DEFAULT_SEED: int = 1337
const DEFAULT_MAG: int = 12
const DEFAULT_RESERVE: int = 36
const DEFAULT_VISION_RANGE: float = 18.0
const DEFAULT_PREFERRED_RANGE: float = 9.0
const DEFAULT_CELL_SIZE: float = 1.0

const DIFFICULTY_SETTINGS: Dictionary = {
	"easy": {"reaction": 0.9, "spread": 3.6, "cooldown_scale": 1.25, "flee_threshold": 0.38},
	"normal": {"reaction": 0.45, "spread": 1.7, "cooldown_scale": 1.0, "flee_threshold": 0.30},
	"hard": {"reaction": 0.16, "spread": 0.45, "cooldown_scale": 0.82, "flee_threshold": 0.22},
}

var role: String = ROLE_HOSTILE
var difficulty: String = DIFFICULTY_NORMAL
var seed_value: int = DEFAULT_SEED
var entity_id: String = "npc"
var target_id: String = "player"
var mag_size: int = DEFAULT_MAG
var ammo: int = DEFAULT_MAG
var reserve: int = DEFAULT_RESERVE
var health_ratio: float = 1.0
var fire_rate: float = 6.0
var vision_range: float = DEFAULT_VISION_RANGE
var preferred_range: float = DEFAULT_PREFERRED_RANGE
var cell_size: float = DEFAULT_CELL_SIZE
var reaction_delay: float = -1.0
var reload_duration: float = 1.1
var reaction_remaining: float = 0.0
var reload_remaining: float = 0.0
var fire_cooldown: float = 0.0
var under_attack: float = 0.0
var alert_level: float = 0.0
var current_action: String = ACTION_PATROL
var last_result: Dictionary = {}
var cover_points: Array = []
var attack_points: Array = []
var patrol_points: Array = []
var flee_points: Array = []
var last_threat_position: Vector3 = Vector3.ZERO
var melee_range: float = 1.6

var personality = null
var relations = null
var factions = null
var perception = null
var navigation = null
var state_machine = null
var controller = null
var behavior = null

var _rng_state: int = 0
var _patrol_index: int = 0
var _seen_target: bool = false
var _last_attitude: String = ATTITUDE_NEUTRAL


func _init(p_options: Dictionary = {}) -> void:
	seed_value = maxi(0, int(p_options.get("seed", DEFAULT_SEED)))
	_reset_rng()
	role = _normalize_role(p_options.get("role", role))
	difficulty = _normalize_difficulty(p_options.get("difficulty", difficulty))
	entity_id = str(p_options.get("entity_id", entity_id))
	target_id = str(p_options.get("target_id", target_id))
	vision_range = maxf(0.0, float(p_options.get("vision_range", vision_range)))
	preferred_range = maxf(1.0, float(p_options.get("preferred_range", preferred_range)))
	cell_size = maxf(0.01, float(p_options.get("cell_size", cell_size)))
	fire_rate = maxf(0.01, float(p_options.get("fire_rate", fire_rate)))
	mag_size = maxi(0, int(p_options.get("mag_size", p_options.get("mag", DEFAULT_MAG))))
	reserve = maxi(0, int(p_options.get("reserve", DEFAULT_RESERVE)))
	ammo = clampi(int(p_options.get("ammo", mag_size)), 0, mag_size)
	health_ratio = clampf(float(p_options.get("health_ratio", p_options.get("health", 1.0))), 0.0, 1.0)
	reload_duration = maxf(0.01, float(p_options.get("reload_duration", 1.1)))
	reaction_delay = maxf(0.0, float(p_options.get("reaction_delay", float(settings()["reaction"]))))

	var pers_data = p_options.get("personality", {})
	if pers_data is Dictionary:
		personality = PersonalityScript.new(pers_data)
	elif pers_data != null:
		personality = pers_data
	if personality == null:
		personality = PersonalityScript.new({})

	relations = p_options.get("relations", null)
	factions = p_options.get("factions", null)
	perception = p_options.get("perception", null)
	navigation = p_options.get("navigation", null)

	var fwd = p_options.get("factions_data", null)
	if factions == null and fwd is Dictionary:
		factions = FactionsScript.new(fwd)
	var rwd = p_options.get("relations_options", null)
	if relations == null and rwd is Dictionary:
		relations = RelationsScript.new(rwd, factions)
	if relations == null and factions != null:
		relations = RelationsScript.new({}, factions)

	cover_points = _vector_array(p_options.get("cover_points", []))
	attack_points = _vector_array(p_options.get("attack_points", []))
	patrol_points = _vector_array(p_options.get("patrol_points", []))

	state_machine = StateMachineScript.new()
	var needs = NeedsScript.new()
	needs.health = health_ratio
	var memory = MemoryScript.new()
	var routine = RoutineScript.new(_stop_array(p_options.get("routine", [])))
	controller = ControllerScript.new(state_machine, personality, needs, memory, routine)
	behavior = BehaviorScript.new(controller, navigation, {
		"seed": seed_value,
		"defaults": false,
		"current_action": current_action,
		"hysteresis": 0.08,
	})
	_install_actions()


func settings() -> Dictionary:
	var raw: Variant = DIFFICULTY_SETTINGS.get(difficulty, DIFFICULTY_SETTINGS[DIFFICULTY_NORMAL])
	return raw if raw is Dictionary else DIFFICULTY_SETTINGS[DIFFICULTY_NORMAL]


func set_seed(value: int) -> void:
	seed_value = maxi(0, int(value))
	_reset_rng()
	if behavior != null and behavior.has_method("set_seed"):
		behavior.set_seed(seed_value)


func reset_seed(value: int = -1) -> void:
	if value >= 0:
		seed_value = value
	_reset_rng()
	_patrol_index = 0
	_reaction_state(false)


func set_difficulty(value: String) -> void:
	difficulty = _normalize_difficulty(value)
	reaction_delay = maxf(0.0, float(settings()["reaction"]))


func set_role(value: String) -> void:
	role = _normalize_role(value)


func set_ammo(loaded: int, p_reserve: int = -1) -> void:
	ammo = clampi(int(loaded), 0, mag_size)
	if p_reserve >= 0:
		reserve = maxi(int(p_reserve), 0)


func set_health_ratio(value: float) -> void:
	health_ratio = clampf(float(value), 0.0, 1.0)
	if controller != null and controller.needs != null:
		controller.needs.health = health_ratio


func can_fire() -> bool:
	return ammo > 0 and reload_remaining <= 0.0 and fire_cooldown <= 0.0 and reaction_remaining <= 0.0 and health_ratio > 0.0


func fire_interval() -> float:
	return 1.0 / maxf(fire_rate, 0.01) * clampf(float(settings()["cooldown_scale"]), 0.1, 4.0)


func consume_shot() -> bool:
	if not can_fire():
		return false
	ammo = maxi(ammo - 1, 0)
	fire_cooldown = fire_interval()
	return true


func start_reload() -> bool:
	if reload_remaining > 0.0 or reserve <= 0 or ammo >= mag_size or mag_size <= 0:
		return false
	reload_remaining = reload_duration
	return true


func is_reloading() -> bool:
	return reload_remaining > 0.0


func reload_progress() -> float:
	if reload_remaining <= 0.0:
		return 0.0
	return clampf(1.0 - reload_remaining / maxf(reload_duration, 0.0001), 0.0, 1.0)


func advance(delta: float) -> void:
	var step: float = maxf(float(delta), 0.0)
	fire_cooldown = maxf(fire_cooldown - step, 0.0)
	reaction_remaining = maxf(reaction_remaining - step, 0.0)
	under_attack = maxf(under_attack - step, 0.0)
	if reload_remaining > 0.0:
		reload_remaining = maxf(reload_remaining - step, 0.0)
		if reload_remaining <= 0.0:
			var needed: int = mag_size - ammo
			var taken: int = mini(needed, reserve)
			ammo += taken
			reserve -= taken


func note_hit(source_id: String = "", danger: float = 0.6, p_position: Vector3 = Vector3.ZERO) -> void:
	under_attack = 1.5
	alert_level = clampf(alert_level + clampf(danger, 0.0, 1.0), 0.0, 1.0)
	if p_position.length_squared() > 0.0001:
		last_threat_position = p_position
	if controller != null and controller.memory != null:
		controller.memory.add_event({"type": "attack", "kind": "hostile", "severity": clampf(danger, 0.0, 1.0), "source_id": source_id})
	if personality != null:
		personality.fear = clampf(personality.fear + 0.08 * clampf(danger, 0.0, 1.0), 0.0, 1.0)


func note_threat(source_id: String = "", danger: float = 0.5, p_position: Vector3 = Vector3.ZERO) -> void:
	alert_level = clampf(alert_level + clampf(danger, 0.0, 1.0) * 0.5, 0.0, 1.0)
	if p_position.length_squared() > 0.0001:
		last_threat_position = p_position
	if controller != null and controller.memory != null:
		controller.memory.add_event({"type": "threat", "kind": "hearing", "severity": clampf(danger, 0.0, 1.0), "source_id": source_id})


# Agresion: disparo del jugador impacta (golpe directo).
func note_gunshot_impact(source_id: String = "", p_position: Vector3 = Vector3.ZERO) -> void:
	under_attack = 2.0
	alert_level = 1.0
	if p_position.length_squared() > 0.0001:
		last_threat_position = p_position
	if controller != null and controller.memory != null:
		controller.memory.add_event({"type": "attack", "kind": "gunshot_impact", "severity": 1.0, "source_id": source_id})
	if personality != null:
		personality.fear = clampf(personality.fear + 0.2, 0.0, 1.0)
	_note_aggression(source_id)


# Agresion: disparo del jugador a menos de 3m (pasada cerca).
func note_gunshot_nearby(source_id: String = "", distance: float = 2.5, p_position: Vector3 = Vector3.ZERO) -> void:
	if distance > 3.0:
		return
	under_attack = 1.5
	alert_level = clampf(alert_level + 0.7, 0.0, 1.0)
	if p_position.length_squared() > 0.0001:
		last_threat_position = p_position
	if controller != null and controller.memory != null:
		controller.memory.add_event({"type": "attack", "kind": "gunshot_nearby", "severity": 0.8, "source_id": source_id})
	if personality != null:
		personality.fear = clampf(personality.fear + 0.15, 0.0, 1.0)
	_note_aggression(source_id)


# Agresion: golpe o cuchillo (melee).
func note_melee_attack(source_id: String = "", danger: float = 0.8, p_position: Vector3 = Vector3.ZERO) -> void:
	under_attack = 2.0
	alert_level = 1.0
	if p_position.length_squared() > 0.0001:
		last_threat_position = p_position
	if controller != null and controller.memory != null:
		controller.memory.add_event({"type": "attack", "kind": "melee", "severity": clampf(danger, 0.0, 1.0), "source_id": source_id})
	if personality != null:
		personality.fear = clampf(personality.fear + 0.25, 0.0, 1.0)
	_note_aggression(source_id)


# Agresion: apuntar con arma cargada a menos de 8m por 2s.
var _aim_tracker: Dictionary = {"source_id": "", "timer": 0.0, "active": false}
func note_aimed_at(source_id: String = "", distance: float = 5.0, armed: bool = true, delta: float = 0.0) -> void:
	if not armed or distance > 8.0:
		_aim_tracker.active = false
		_aim_tracker.timer = 0.0
		return
	if _aim_tracker.source_id != source_id:
		_aim_tracker.source_id = source_id
		_aim_tracker.timer = 0.0
	_aim_tracker.active = true
	_aim_tracker.timer += delta
	if _aim_tracker.timer >= 2.0:
		under_attack = 1.0
		alert_level = clampf(alert_level + 0.5, 0.0, 1.0)
		if controller != null and controller.memory != null:
			controller.memory.add_event({"type": "attack", "kind": "aimed_at", "severity": 0.6, "source_id": source_id})
		if personality != null:
			personality.fear = clampf(personality.fear + 0.1, 0.0, 1.0)
		_note_aggression(source_id)
		_aim_tracker.active = false
		_aim_tracker.timer = 0.0


func _note_aggression(source_id: String) -> void:
	if behavior != null and behavior.has_method("note_aggression"):
		behavior.call("note_aggression", source_id)


func update(delta: float, p_context: Dictionary = {}) -> Dictionary:
	advance(delta)
	return decide(p_context)


func decide(p_context: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = _build_context(p_context)
	if behavior == null:
		last_result = {"ok": false, "id": ACTION_IDLE, "reason": "behavior_unavailable", "context": ctx}
		return last_result.duplicate(true)
	var wanted: String = str(p_context.get("force_action", ""))
	var selected: Dictionary
	if not wanted.is_empty() and behavior.has_action(wanted):
		selected = {
			"ok": true,
			"id": wanted,
			"score": 1000.0,
			"utility": 1000.0,
			"reason": "forced",
			"state": _state_for(wanted),
			"context": ctx,
		}
		behavior.set_current_action(wanted)
		last_result = selected
	else:
		selected = behavior.select(ctx)
		last_result = selected.duplicate(true)
	current_action = str(last_result.get("id", ACTION_IDLE))
	_last_attitude = str(ctx.get("attitude", ATTITUDE_NEUTRAL))
	var visible: bool = bool(ctx.get("visible", false))
	if visible and not _seen_target:
		_reaction_state(true)
	_seen_target = visible
	_apply_state(current_action)
	return last_result.duplicate(true)


func action() -> String:
	return current_action


func flee_threshold() -> float:
	var base: float = float(settings()["flee_threshold"])
	if personality != null:
		base += (0.5 - clampf(float(personality.bravery), 0.0, 1.0)) * 0.12
		base += (clampf(float(personality.fear), 0.0, 1.0) - 0.5) * 0.08
	return clampf(base, 0.05, 0.85)


func attitude_toward_target(p_target_id: String = "") -> String:
	var other: String = p_target_id if not p_target_id.is_empty() else target_id
	if relations != null and relations.has_method("get_attitude"):
		if not other.is_empty() and other != entity_id:
			return str(relations.get_attitude(entity_id, other))
	return _attitude_from_factions(other)


func faction_relation(p_target_id: String = "") -> float:
	var other: String = p_target_id if not p_target_id.is_empty() else target_id
	if factions != null and factions.has_method("relation_between_entities"):
		return clampf(float(factions.relation_between_entities(entity_id, other)), -100.0, 100.0)
	return 0.0


func same_faction(p_target_id: String = "") -> bool:
	var other: String = p_target_id if not p_target_id.is_empty() else target_id
	if factions == null or not factions.has_method("get_faction"):
		return false
	var mine: String = str(factions.get_faction(entity_id))
	var theirs: String = str(factions.get_faction(other))
	return not mine.is_empty() and mine == theirs


func choose_position(kind: String, p_context: Dictionary = {}) -> Variant:
	var ctx: Dictionary = _build_context(p_context)
	var source: Array = _points_for(kind)
	if source.is_empty():
		return null
	var origin: Vector3 = _vector(ctx.get("position", Vector3.ZERO))
	var target: Vector3 = _vector(ctx.get("target_position", origin + Vector3.FORWARD * 10.0))
	var to_target: Vector3 = target - origin
	var away: Vector3 = -to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.FORWARD
	var best: Variant = null
	var best_score: float = -1.0e30
	var best_tie: float = -1.0
	for i in range(source.size()):
		var point: Vector3 = _vector(source[i])
		var offset: Vector3 = point - origin
		var score: float = 0.0
		match kind:
			ACTION_ATTACK:
				score = -absf(point.distance_to(target) - preferred_range) - 0.08 * offset.length()
			ACTION_COVER:
				score = offset.dot(away) * 1.5 - offset.length() * 0.25
				var flank: Vector3 = point - target
				score += clampf(flank.dot(away) * 0.1, -1.0, 1.0)
			ACTION_FLEE:
				score = point.distance_to(target) + offset.dot(away) * 0.5 - offset.length() * 0.1
			_:
				score = -offset.length()
		var tie: float = _hash_float("%s:%d" % [kind, i])
		if score > best_score or (is_equal_approx(score, best_score) and tie > best_tie):
			best = point
			best_score = score
			best_tie = tie
	return best


func goal_for(p_action: String = "", p_context: Dictionary = {}) -> Vector3:
	var action: String = p_action if not p_action.is_empty() else current_action
	var ctx: Dictionary = _build_context(p_context)
	var chosen: Variant = choose_position(action, ctx)
	if chosen != null:
		return _vector(chosen)
	var origin: Vector3 = _vector(ctx.get("position", Vector3.ZERO))
	var target: Vector3 = _vector(ctx.get("target_position", origin + Vector3.FORWARD * 10.0))
	var to_target: Vector3 = target - origin
	var direction: Vector3 = to_target.normalized() if to_target.length_squared() > 0.0001 else -transform_basis_forward()
	match action:
		ACTION_ATTACK:
			var standoff: float = minf(maxf(to_target.length() - preferred_range, 2.0), preferred_range)
			return target - direction * standoff
		ACTION_COVER:
			return origin - direction * 4.0
		ACTION_FLEE:
			return origin - direction * 12.0
		ACTION_PATROL:
			var angle: float = TAU * _hash_float("patrol:%d" % _patrol_index)
			_patrol_index = (_patrol_index + 1) % 8
			return origin + Vector3(cos(angle), 0.0, sin(angle)) * 4.0
		ACTION_INVESTIGATE:
			if last_threat_position.length_squared() > 0.0001:
				return last_threat_position
			return target
		_:
			return origin


func path_to(goal: Vector3, p_context: Dictionary = {}) -> Array:
	if navigation == null or not navigation.has_method("find_path"):
		return []
	var ctx: Dictionary = _build_context(p_context)
	var from: Vector3 = _vector(ctx.get("position", Vector3.ZERO))
	var start_cell: Vector2i = navigation.world_to_cell_2d(Vector2(from.x, from.z), cell_size)
	var goal_cell: Vector2i = navigation.world_to_cell_2d(Vector2(goal.x, goal.z), cell_size)
	var path_result: Dictionary = navigation.find_path(start_cell, goal_cell)
	if not bool(path_result.get("ok", false)):
		return []
	var path: Variant = path_result.get("path", [])
	return path.duplicate() if path is Array else []


func spread_direction(direction: Vector3, distance: float = 0.0, moving: bool = false) -> Vector3:
	var spread: float = float(settings()["spread"])
	spread *= 1.0 + clampf(distance / 60.0, 0.0, 1.0)
	if moving:
		spread *= 1.25
	return spread_direction_with(direction, spread)


func spread_direction_with(direction: Vector3, spread_degrees: float) -> Vector3:
	var base: Vector3 = direction.normalized()
	if base.length_squared() < 0.0001 or spread_degrees <= 0.0:
		return base
	var reference: Vector3 = Vector3.UP if absf(base.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var right: Vector3 = base.cross(reference).normalized()
	var up: Vector3 = right.cross(base).normalized()
	var amount: float = tan(deg_to_rad(spread_degrees) * 0.5)
	var lateral: float = (next_random() * 2.0 - 1.0) * amount
	var vertical: float = (next_random() * 2.0 - 1.0) * amount
	return (base + right * lateral + up * vertical).normalized()


func next_random() -> float:
	return _next_random()


func snapshot() -> Dictionary:
	return {
		"role": role,
		"difficulty": difficulty,
		"seed": seed_value,
		"entity_id": entity_id,
		"target_id": target_id,
		"mag": mag_size,
		"ammo": ammo,
		"reserve": reserve,
		"health": snappedf(health_ratio, 0.0001),
		"action": current_action,
		"reason": str(last_result.get("reason", "")),
		"reaction_remaining": snappedf(reaction_remaining, 0.0001),
		"reload_remaining": snappedf(reload_remaining, 0.0001),
		"fire_cooldown": snappedf(fire_cooldown, 0.0001),
		"rng": _rng_state,
		"patrol_index": _patrol_index,
		"attitude": _last_attitude,
		"last_threat_position": last_threat_position,
	}


func _install_actions() -> void:
	behavior.register_action(ACTION_ATTACK, {
		"score": Callable(self, "_score_attack"),
		"available": Callable(self, "_available_attack"),
		"state": "alert",
	})
	behavior.register_action(ACTION_COVER, {
		"score": Callable(self, "_score_cover"),
		"available": Callable(self, "_available_cover"),
		"state": "walk",
	})
	behavior.register_action(ACTION_FLEE, {
		"score": Callable(self, "_score_flee"),
		"available": Callable(self, "_available_flee"),
		"state": "flee",
		"movement": true,
	})
	behavior.register_action(ACTION_RELOAD, {
		"score": Callable(self, "_score_reload"),
		"available": Callable(self, "_available_reload"),
		"state": "idle",
	})
	behavior.register_action(ACTION_HELP, {
		"score": Callable(self, "_score_help"),
		"available": Callable(self, "_available_help"),
		"state": "need_help",
	})
	behavior.register_action(ACTION_PATROL, {
		"score": Callable(self, "_score_patrol"),
		"available": Callable(self, "_available_patrol"),
		"state": "walk",
	})
	behavior.register_action(ACTION_INVESTIGATE, {
		"score": Callable(self, "_score_investigate"),
		"available": Callable(self, "_available_investigate"),
		"state": "walk",
	})
	behavior.register_action(ACTION_IDLE, {
		"score": 0.01,
		"available": true,
		"state": "idle",
	})


func _build_context(p_context: Dictionary) -> Dictionary:
	var ctx: Dictionary = p_context.duplicate(true)
	var attitude: String = attitude_toward_target()
	var friendly: bool = attitude == ATTITUDE_FRIENDLY or same_faction()
	var danger: float = 0.0
	if attitude == ATTITUDE_HOSTILE:
		danger = 0.65
	elif under_attack > 0.0:
		danger = maxf(danger, under_attack)
	danger = clampf(maxf(danger, alert_level * 0.6), 0.0, 1.0)
	ctx["health"] = health_ratio
	ctx["ammo"] = ammo
	ctx["reserve"] = reserve
	ctx["mag"] = mag_size
	ctx["ammo_ratio"] = float(ammo) / float(maxi(mag_size, 1))
	ctx["visible"] = bool(ctx.get("visible", false))
	ctx["distance"] = maxf(float(ctx.get("distance", 100.0)), 0.0)
	ctx["under_attack"] = under_attack > 0.0
	ctx["attitude"] = attitude
	ctx["friendly"] = friendly
	ctx["same_faction"] = same_faction()
	ctx["faction_relation"] = faction_relation()
	ctx["role"] = role
	ctx["flee_threshold"] = flee_threshold()
	ctx["reloading"] = reload_remaining > 0.0
	ctx["cover_count"] = cover_points.size()
	ctx["danger"] = maxf(float(ctx.get("danger", 0.0)), danger)
	return ctx


func _score_attack(ctx: Dictionary) -> float:
	var is_zombie: bool = str(ctx["role"]) == ROLE_ZOMBIE
	if not bool(ctx["visible"]) or bool(ctx["reloading"]):
		return 0.0
	if not is_zombie and int(ctx["ammo"]) <= 0:
		return 0.0
	var value: float = 0.62 + _ctx_num(ctx, "aggressiveness") * 0.36 + _ctx_num(ctx, "bravery") * 0.18
	if is_zombie:
		value += 0.85
	if str(ctx["role"]) == ROLE_DEFENDER:
		value += 0.34 if float(ctx["faction_relation"]) < -10.0 else 0.1
	if bool(ctx["friendly"]):
		value -= 1.4
	if float(ctx["health"]) < flee_threshold():
		value -= 0.8
	if float(ctx["distance"]) > vision_range:
		value -= 0.4
	return maxf(value, 0.0)


func _score_cover(ctx: Dictionary) -> float:
	if not bool(ctx["visible"]) or int(ctx["cover_count"]) <= 0:
		return 0.0
	var value: float = 0.2
	if bool(ctx["under_attack"]):
		value += 0.55
	value += (1.0 - _ctx_num(ctx, "bravery")) * 0.22
	value += (1.0 - float(ctx["ammo_ratio"])) * 0.2
	value -= _ctx_num(ctx, "aggressiveness") * 0.16
	if bool(ctx["friendly"]):
		value -= 0.1
	return maxf(value, 0.0)


func _score_flee(ctx: Dictionary) -> float:
	var threshold: float = maxf(float(ctx["flee_threshold"]), 0.01)
	var low_health: float = clampf((threshold - float(ctx["health"])) / threshold, 0.0, 1.0)
	var value: float = low_health
	value += (1.0 - _ctx_num(ctx, "bravery")) * 0.22 + _ctx_num(ctx, "fear") * 0.32
	if int(ctx["ammo"]) <= 0 and int(ctx["reserve"]) <= 0:
		value += 0.45
	if bool(ctx["under_attack"]):
		value += 0.18
	if str(ctx["role"]) == ROLE_CIVILIAN:
		value += 1.3 if bool(ctx["visible"]) else 0.1
	if str(ctx["role"]) == ROLE_DEFENDER and bool(ctx["under_attack"]):
		value -= 0.25
	if bool(ctx["friendly"]):
		value -= 0.2
	if str(ctx["role"]) == ROLE_HOSTILE and _ctx_num(ctx, "aggressiveness") > 0.6:
		value -= 0.16 * _ctx_num(ctx, "aggressiveness")
	return maxf(value, 0.0)


func _score_reload(ctx: Dictionary) -> float:
	if int(ctx["ammo"]) <= 0:
		return 1.5 if not bool(ctx["visible"]) else 1.35
	if float(ctx["ammo_ratio"]) < 0.3:
		return 0.7
	return 0.0


func _score_help(ctx: Dictionary) -> float:
	var low_health: float = 1.0 - float(ctx["health"])
	var value: float = low_health * (1.0 - _ctx_num(ctx, "confidence")) * 0.85
	if bool(ctx["friendly"]) and low_health > 0.3:
		value += 0.45
	if str(ctx["role"]) == ROLE_DEFENDER and bool(ctx["under_attack"]):
		value += 0.2
	return maxf(value, 0.0)


func _score_patrol(ctx: Dictionary) -> float:
	if bool(ctx["visible"]):
		return 0.02
	return 0.3 + _ctx_num(ctx, "curiosity") * 0.14 - float(ctx["danger"]) * 0.12


func _score_investigate(ctx: Dictionary) -> float:
	if bool(ctx["visible"]):
		return 0.0
	if last_threat_position.length_squared() <= 0.0001:
		return 0.0
	var value: float = 0.42 + float(ctx["danger"]) * 0.45 + _ctx_num(ctx, "curiosity") * 0.18
	if str(ctx["role"]) == ROLE_CIVILIAN:
		value -= 0.35
	return maxf(value, 0.0)


func _available_attack(ctx: Dictionary) -> bool:
	var is_zombie: bool = str(ctx["role"]) == ROLE_ZOMBIE
	var armed: bool = is_zombie or int(ctx["ammo"]) > 0
	return bool(ctx["visible"]) and armed and not bool(ctx["reloading"]) \
		and str(ctx["role"]) != ROLE_CIVILIAN and not bool(ctx["friendly"])


func _available_cover(ctx: Dictionary) -> bool:
	return bool(ctx["visible"]) and int(ctx["cover_count"]) > 0


func _available_flee(ctx: Dictionary) -> bool:
	var threshold: float = maxf(float(ctx["flee_threshold"]), 0.01)
	return float(ctx["health"]) < threshold \
		or str(ctx["role"]) == ROLE_CIVILIAN \
		or (int(ctx["ammo"]) <= 0 and int(ctx["reserve"]) <= 0) \
		or (_ctx_num(ctx, "fear") > 0.7 and float(ctx["distance"]) < 6.0)


func _available_reload(ctx: Dictionary) -> bool:
	return int(ctx["reserve"]) > 0 and int(ctx["ammo"]) < int(ctx["mag"]) and not bool(ctx["reloading"])


func _available_help(ctx: Dictionary) -> bool:
	return float(ctx["health"]) < flee_threshold() * 1.6 and (_ctx_num(ctx, "confidence") < 0.6 or bool(ctx["friendly"]))


func _available_patrol(ctx: Dictionary) -> bool:
	return not bool(ctx["visible"]) and not bool(ctx["friendly"])


func _available_investigate(ctx: Dictionary) -> bool:
	return not bool(ctx["visible"]) and last_threat_position.length_squared() > 0.0001


func _apply_state(action: String) -> void:
	if controller == null or controller.state_machine == null:
		return
	var wanted: String = _state_for(action)
	var sm = controller.state_machine
	if not sm.has_method("transition_to"):
		return
	if sm.get_state() == wanted:
		return
	if not bool(sm.transition_to(wanted)):
		var current: String = str(sm.get_state())
		if current != "alert":
			sm.transition_to("alert")
		sm.transition_to(wanted)


func _state_for(action: String) -> String:
	match action:
		ACTION_ATTACK:
			return "alert"
		ACTION_COVER, ACTION_PATROL, ACTION_INVESTIGATE:
			return "walk"
		ACTION_FLEE:
			return "flee"
		ACTION_RELOAD:
			return "idle"
		ACTION_HELP:
			return "need_help"
		_:
			return "idle"


func _reaction_state(active: bool) -> void:
	if active:
		reaction_remaining = reaction_delay
		if role == ROLE_HOSTILE and behavior != null and behavior.has_method("note_aggression"):
			behavior.note_aggression(target_id)
	else:
		reaction_remaining = 0.0
	_seen_target = active


func _attitude_from_factions(other: String) -> String:
	if factions == null or other.is_empty() or other == entity_id:
		return ATTITUDE_NEUTRAL
	if same_faction(other):
		return ATTITUDE_FRIENDLY
	var value: float = faction_relation(other)
	if value <= -25.0:
		return ATTITUDE_HOSTILE
	if value >= 50.0:
		return ATTITUDE_FRIENDLY
	if role == ROLE_HOSTILE and value <= 0.0:
		return ATTITUDE_HOSTILE
	return ATTITUDE_NEUTRAL


func _points_for(kind: String) -> Array:
	match kind:
		ACTION_ATTACK:
			return attack_points
		ACTION_COVER:
			return cover_points
		ACTION_PATROL:
			return patrol_points
		_:
			return []


func _ctx_num(ctx: Dictionary, key: String) -> float:
	var value: Variant = ctx.get(key, 0.5)
	if personality != null and personality.get(key) != null:
		value = personality.get(key)
	return clampf(float(value), 0.0, 1.0)


func _normalize_role(value) -> String:
	var text: String = str(value).strip_edges().to_lower()
	match text:
		"civilian", "civil", "pacifista", "pacifist":
			return ROLE_CIVILIAN
		"defender", "guard", "guardia", "defensor", "police", "policia":
			return ROLE_DEFENDER
		"zombie", "zombi", "infectado":
			return ROLE_ZOMBIE
		_:
			return ROLE_HOSTILE


func _normalize_difficulty(value) -> String:
	var text: String = str(value).strip_edges().to_lower()
	match text:
		"easy", "facil", "fácil", "baja":
			return DIFFICULTY_EASY
		"hard", "dificil", "difícil", "alta":
			return DIFFICULTY_HARD
		_:
			return DIFFICULTY_NORMAL


func _reset_rng() -> void:
	_rng_state = (seed_value * 2654435761 + 1013904223) & 0x7FFFFFFF
	if _rng_state <= 0:
		_rng_state = 1


func _next_random() -> float:
	_rng_state = (_rng_state * 1103515245 + 12345) & 0x7FFFFFFF
	return float(_rng_state) / 2147483647.0


func _hash_float(key: String) -> float:
	var h: int = seed_value
	for i in range(key.length()):
		h = ((h & 0x7FFFFFFF) * 1103515245 + 12345 + key.unicode_at(i)) & 0x7FFFFFFF
	h = (h ^ (h >> 13)) & 0x7FFFFFFF
	return float(h) / 2147483647.0


func _vector(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector2:
		var v: Vector2 = value
		return Vector3(v.x, 0.0, v.y)
	if value is Vector3i:
		var v: Vector3i = value
		return Vector3(v)
	if value is Array and (value as Array).size() >= 3:
		var data: Array = value
		return Vector3(float(data[0]), float(data[1]), float(data[2]))
	return Vector3.ZERO


func _vector_array(value) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			result.append(_vector(item))
	return result


func _stop_array(value) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append(item)
			else:
				result.append({"waypoint_id": str(item), "duration": 2.0})
	return result


func transform_basis_forward() -> Vector3:
	return Vector3.FORWARD
