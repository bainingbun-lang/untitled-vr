class_name NPCBehavior
extends RefCounted

# Adaptaciones documentadas (interfaces existentes sin modificar):
# - NPCMemory.events no esta tipado: se interpretan entradas Dictionary
#   {type|kind|event, severity|intensity|value} y Strings con palabras de peligro.
# - NPCRoutine.get_current_stop devuelve Dictionary (waypoint_id o id); se usa
#   como señal de rutina y, si trae cell|goal, como objetivo de navegacion.
# - NPCNavigation es un grid pathfinder: el enganche calcula una ruta desde
#   context.from/current_cell hasta goal para acciones marcadas como movement.
# - NPCStateMachine.transition_to se usa tal cual; un rechazo se reporta, no se fuerza.

const DEFAULT_SEED: int = 1337
const DEFAULT_HYSTERESIS: float = 0.08
const TIE_EPSILON: float = 0.000001

var controller: NPCController = null
var navigation: Variant = null
var seed_value: int = DEFAULT_SEED
var hysteresis: float = DEFAULT_HYSTERESIS
var current_action_id: String = ""
var last_result: Dictionary = {}
var last_path: Array = []
var follower = null

var _actions: Dictionary = {}

# AI2: Modo de comportamiento y agresion
var behavior_mode: String = "pacifico"
var _aggression_cooldown: float = 0.0
var _calm_after_seconds: float = 30.0
var _last_aggression_source: String = ""
var _blackboard: Variant = null


func _init(p_controller = null, p_navigation = null, p_options = {}) -> void:
	controller = p_controller
	navigation = p_navigation
	seed_value = int(p_options.get("seed", DEFAULT_SEED))
	hysteresis = clampf(float(p_options.get("hysteresis", DEFAULT_HYSTERESIS)), 0.0, 1.0)
	current_action_id = str(p_options.get("current_action", p_options.get("current_action_id", "")))
	behavior_mode = str(p_options.get("behavior_mode", "pacifico")).to_lower()
	_calm_after_seconds = maxf(0.0, float(p_options.get("calm_after_seconds", 30.0)))
	_blackboard = p_options.get("blackboard", null)
	if bool(p_options.get("defaults", true)):
		_install_default_actions()
	var extra: Variant = p_options.get("actions", [])
	if extra is Array:
		for item in extra:
			if item is Dictionary:
				register_action(str(item.get("id", "")), item)


func set_seed(value: int) -> void:
	seed_value = int(value)


func get_seed() -> int:
	return seed_value


func set_hysteresis(value: float) -> void:
	hysteresis = clampf(float(value), 0.0, 1.0)


func get_hysteresis() -> float:
	return hysteresis


func set_current_action(id: String) -> void:
	current_action_id = str(id)


func get_current_action() -> String:
	return current_action_id


func get_behavior_mode() -> String:
	return behavior_mode


func set_behavior_mode(mode: String) -> void:
	var m: String = str(mode).to_lower()
	if m == "hostil" or m == "pacifico":
		behavior_mode = m
	else:
		behavior_mode = "pacifico"


func update_aggression_cooldown(delta: float) -> void:
	_aggression_cooldown = maxf(0.0, _aggression_cooldown - delta)
	if _aggression_cooldown <= 0.0:
		_aggression_cooldown = 0.0
		_last_aggression_source = ""
		if behavior_mode == "hostil":
			behavior_mode = "pacifico"


func register_action(id: String, config: Dictionary) -> void:
	var key: String = str(id)
	if key.is_empty():
		return
	var entry: Dictionary = config.duplicate(true)
	entry["id"] = key
	_actions[key] = entry


func unregister_action(id: String) -> void:
	_actions.erase(str(id))


func clear_actions() -> void:
	_actions.clear()


func has_action(id: String) -> bool:
	return _actions.has(str(id))


func action_ids() -> Array:
	var ids: Array = _actions.keys()
	ids.sort()
	return ids


func select(p_context: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = _build_context(p_context)
	_apply_behavior_mode(ctx)
	_update_blackboard(ctx)
	var candidates: Array = []
	var aggressiveness: float = float(ctx.get("aggressiveness", 0.5))
	var is_hostile_npc: bool = aggressiveness > 0.6
	var is_civilian_npc: bool = aggressiveness <= 0.4
	for key in _actions.keys():
		var id: String = str(key)
		var config: Dictionary = _actions[key]
		if not _is_available(config, ctx):
			continue
		var utility: float = _score_action(id, config, ctx)
		if id == "hostile_attack" and not is_hostile_npc:
			continue
		if id == "attack" and is_hostile_npc:
			continue
		if id == "civilian_flee" and not is_civilian_npc:
			continue
		if id == "flee" and is_civilian_npc:
			continue
		if (id == "hostile_attack" or id == "attack") and not bool(ctx.get("force_attack", false)) and not (_aggression_cooldown > 0.0 and is_hostile_npc):
			continue
		if (id == "chase") and not bool(ctx.get("force_chase", false)) and not (_aggression_cooldown > 0.0 and is_hostile_npc):
			continue
		if (id == "civilian_flee" or id == "flee") and not bool(ctx.get("force_flee", false)):
			continue
		if id == "witness_alert" and not bool(ctx.get("force_witness", false)):
			continue
		candidates.append({
			"id": id,
			"utility": utility,
			"score": utility,
			"tie": _tie_value(id),
			"config": config,
		})
	if candidates.is_empty():
		last_path = []
		follower = null
		current_action_id = ""
		last_result = {
			"ok": false,
			"reason": "no_actions",
			"id": "",
			"score": 0.0,
			"utility": 0.0,
			"movement": false,
			"goal": null,
			"state": "",
			"path": [],
			"path_ok": false,
			"context": ctx,
		}
		return last_result.duplicate(true)
	for candidate in candidates:
		if str(candidate["id"]) == current_action_id:
			candidate["score"] = float(candidate["score"]) + hysteresis
	candidates.sort_custom(Callable(self, "_compare_candidates"))
	var best: Dictionary = candidates[0]
	var chosen_id: String = str(best["id"])
	current_action_id = chosen_id
	var result: Dictionary = {
		"ok": true,
		"reason": "selected",
		"id": chosen_id,
		"score": float(best["score"]),
		"utility": float(best["utility"]),
		"tie": float(best["tie"]),
		"movement": bool(best["config"].get("movement", false)),
		"goal": best["config"].get("goal", null),
		"state": str(best["config"].get("state", "")),
		"context": ctx,
	}
	_resolve_navigation(result, ctx)
	last_result = result
	return result.duplicate(true)


func apply(result: Dictionary = {}, p_context: Dictionary = {}) -> Dictionary:
	var chosen: Dictionary = result
	if chosen.is_empty():
		chosen = select(p_context)
	var report: Dictionary = {
		"ok": bool(chosen.get("ok", false)),
		"id": str(chosen.get("id", "")),
		"reason": str(chosen.get("reason", "")),
		"state": "",
		"state_before": "",
		"state_changed": false,
		"path_ok": bool(chosen.get("path_ok", false)),
		"moved": false,
	}
	if not report["ok"]:
		return report
	var wanted_state: String = str(chosen.get("state", ""))
	if controller != null and controller.state_machine != null and not wanted_state.is_empty():
		report["state_before"] = controller.state_machine.get_state()
		report["state_changed"] = controller.state_machine.transition_to(wanted_state)
		report["state"] = controller.state_machine.get_state()
	elif not wanted_state.is_empty():
		report["state"] = wanted_state
	if bool(p_context.get("drive", false)) and navigation != null and follower != null:
		var options: Variant = p_context.get("drive_options", {})
		var step: Dictionary = navigation.drive_controller(controller, follower, options if options is Dictionary else {})
		report["moved"] = bool(step.get("moved", false))
		report["step"] = step
	return report


func update(delta: float, p_context: Dictionary = {}) -> Dictionary:
	if controller != null and controller.needs != null:
		controller.needs.tick(delta)
	var ctx: Dictionary = p_context.duplicate(true)
	ctx["delta"] = delta
	return apply(select(ctx), ctx)


func _install_default_actions() -> void:
	register_action("rest", {"score": "rest", "state": "rest"})
	register_action("flee", {"score": "flee", "state": "flee", "movement": true})
	register_action("help", {"score": "help", "state": "need_help"})
	register_action("alert", {"score": "alert", "state": "alert"})
	register_action("converse", {"score": "converse", "state": "converse"})
	register_action("explore", {"score": "explore", "state": "walk", "movement": true})
	register_action("patrol", {"score": "patrol", "state": "walk", "movement": true})
	register_action("idle", {"score": "idle", "state": "idle"})
	register_action("peaceful_patrol", {"score": "patrol", "state": "walk", "movement": true})
	register_action("peaceful_idle", {"score": "idle", "state": "idle"})
	register_action("attack", {"score": "attack", "state": "attack", "movement": true})
	register_action("chase", {"score": "chase", "state": "chase", "movement": true})
	register_action("witness_alert", {"score": "witness_alert", "state": "alert"})
	register_action("hostile_attack", {"score": "attack", "state": "attack", "movement": true})
	register_action("civilian_flee", {"score": "flee", "state": "flee", "movement": true})


func _build_context(p_context: Dictionary) -> Dictionary:
	var ctx: Dictionary = p_context.duplicate(true)
	var needs: NPCNeeds = null
	var pers: NPCPersonality = null
	var mem: NPCMemory = null
	var routine: NPCRoutine = null
	if controller != null:
		needs = controller.needs
		pers = controller.personality
		mem = controller.memory
		routine = controller.routine
	var d_fatigue: float = 0.0
	var d_stress: float = 0.0
	var d_fear: float = 0.0
	var d_confusion: float = 0.0
	var d_stun: float = 0.0
	var d_health: float = 1.0
	if needs != null:
		d_fatigue = needs.fatigue
		d_stress = needs.stress
		d_fear = needs.fear
		d_confusion = needs.confusion
		d_stun = needs.stun
		d_health = needs.health
	ctx["fatigue"] = _ctx_number(ctx, "fatigue", d_fatigue)
	ctx["stress"] = _ctx_number(ctx, "stress", d_stress)
	ctx["fear"] = _ctx_number(ctx, "fear", d_fear)
	ctx["confusion"] = _ctx_number(ctx, "confusion", d_confusion)
	ctx["stun"] = _ctx_number(ctx, "stun", d_stun)
	ctx["health"] = _ctx_number(ctx, "health", d_health)
	var d_bravery: float = 0.5
	var d_confidence: float = 0.5
	var d_curiosity: float = 0.5
	var d_sociability: float = 0.5
	var d_aggressiveness: float = 0.5
	var d_temperament: float = 0.5
	if pers != null:
		d_bravery = pers.bravery
		d_confidence = pers.confidence
		d_curiosity = pers.curiosity
		d_sociability = pers.sociability
		d_aggressiveness = pers.aggressiveness
		d_temperament = pers.temperament
	ctx["bravery"] = _ctx_number(ctx, "bravery", d_bravery)
	ctx["confidence"] = _ctx_number(ctx, "confidence", d_confidence)
	ctx["curiosity"] = _ctx_number(ctx, "curiosity", d_curiosity)
	ctx["sociability"] = _ctx_number(ctx, "sociability", d_sociability)
	ctx["aggressiveness"] = _ctx_number(ctx, "aggressiveness", d_aggressiveness)
	ctx["temperament"] = _ctx_number(ctx, "temperament", d_temperament)
	ctx["danger"] = _ctx_number(ctx, "danger", _memory_danger(mem))
	var sim_hour: float = float(ctx.get("sim_hour", 12.0))
	var fallback_stop: Dictionary = {}
	if routine != null:
		fallback_stop = routine.get_current_stop(sim_hour)
	var stop_value: Variant = ctx.get("routine_stop", fallback_stop)
	var stop: Dictionary = {}
	if stop_value is Dictionary:
		stop = stop_value
	ctx["routine_stop"] = stop
	ctx["routine_active"] = not stop.is_empty()
	ctx["from"] = ctx.get("from", ctx.get("current_cell", Vector2i.ZERO))
	return ctx


func _ctx_number(ctx: Dictionary, key: String, default_value: float) -> float:
	return clampf(float(ctx.get(key, default_value)), 0.0, 1.0)


func _score_action(id: String, config: Dictionary, ctx: Dictionary) -> float:
	var raw: Variant = config.get("score", 0.0)
	var value: float = 0.0
	if raw is Callable:
		value = float((raw as Callable).call(ctx))
	elif raw is String:
		value = _score_builtin(str(raw), ctx)
	else:
		value = float(raw)
	var weight: float = float(config.get("weight", 1.0))
	var bias: float = float(config.get("bias", 0.0))
	return clampf(value * weight + bias, 0.0, 1000.0)


func _score_builtin(kind: String, ctx: Dictionary) -> float:
	var fatigue: float = float(ctx["fatigue"])
	var stress: float = float(ctx["stress"])
	var fear: float = float(ctx["fear"])
	var health: float = float(ctx["health"])
	var stun: float = float(ctx["stun"])
	var confusion: float = float(ctx["confusion"])
	var danger: float = float(ctx["danger"])
	var bravery: float = float(ctx["bravery"])
	var confidence: float = float(ctx["confidence"])
	var curiosity: float = float(ctx["curiosity"])
	var sociability: float = float(ctx["sociability"])
	var aggressiveness: float = float(ctx["aggressiveness"])
	var low_health: float = 1.0 - health
	var threat: float = maxf(fear, danger)
	match kind:
		"rest":
			return fatigue + low_health * 0.6 + stress * 0.2
		"flee":
			return fear * 0.8 + danger + (1.0 - bravery) * 0.3 * threat + (1.0 - confidence) * 0.2 * danger + low_health * 0.3
		"help":
			return low_health * 0.9 * (1.0 - confidence) + stun * 0.6 + confusion * 0.3
		"alert":
			return aggressiveness * (0.4 + 0.4 * danger) + confidence * 0.2 * danger
		"converse":
			return sociability * 0.6 * (1.0 - fear) * (1.0 - danger) * (0.8 + 0.2 * confidence)
		"explore":
			return curiosity * 0.5 * (1.0 - fatigue) * (1.0 - danger)
		"patrol":
			return (0.45 + 0.15 * curiosity) if bool(ctx["routine_active"]) else 0.0
		"idle":
			return 0.05
		"attack":
			return aggressiveness * 0.8 * (1.0 - fear) * (0.5 + 0.5 * danger) + confidence * 0.3
		"chase":
			return aggressiveness * 0.6 * (1.0 - fear) * (0.6 + 0.4 * danger) + confidence * 0.2
		"witness_alert":
			return sociability * 0.7 * (1.0 - fear) * danger * 0.5
		"hostile_attack":
			return aggressiveness * 0.9 * (1.0 - fear) * (0.6 + 0.4 * danger) + confidence * 0.4
		"civilian_flee":
			return fear * 0.9 + danger + (1.0 - bravery) * 0.4 * danger + low_health * 0.4
		"peaceful_patrol":
			return (0.5 + 0.1 * curiosity) if bool(ctx["routine_active"]) else 0.0
		"peaceful_idle":
			return 0.1
		_:
			return 0.0


func _is_available(config: Dictionary, ctx: Dictionary) -> bool:
	var available: Variant = config.get("available", true)
	if available is Callable:
		return bool((available as Callable).call(ctx))
	return bool(available)


func _tie_value(action_id: String) -> float:
	var h: int = seed_value
	for i in range(action_id.length()):
		h = ((h & 0x7FFFFFFF) * 1103515245 + 12345 + action_id.unicode_at(i)) & 0x7FFFFFFF
	h = (h ^ (h >> 13)) & 0x7FFFFFFF
	return float(h) / 2147483647.0


func _compare_candidates(a: Dictionary, b: Dictionary) -> bool:
	var score_a: float = float(a["score"])
	var score_b: float = float(b["score"])
	if not is_equal_approx(score_a, score_b):
		return score_a > score_b
	var tie_a: float = float(a["tie"])
	var tie_b: float = float(b["tie"])
	if not is_equal_approx(tie_a, tie_b):
		return tie_a > tie_b
	return str(a["id"]) < str(b["id"])


func _memory_danger(mem: NPCMemory) -> float:
	if mem == null:
		return 0.0
	var events: Array = mem.get_events()
	if events.is_empty():
		return 0.0
	var best: float = 0.0
	var total: float = float(events.size())
	for i in range(events.size()):
		var event: Variant = events[i]
		var kind: String = ""
		var severity: float = 1.0
		if event is Dictionary:
			var entry: Dictionary = event
			kind = str(entry.get("type", entry.get("kind", entry.get("event", "")))).to_lower()
			severity = clampf(float(entry.get("severity", entry.get("intensity", entry.get("value", 1.0)))), 0.0, 1.0)
		elif event is String:
			kind = (event as String).to_lower()
		else:
			continue
		if _is_danger_kind(kind):
			var recency: float = float(i + 1) / total
			best = maxf(best, severity * (0.5 + 0.5 * recency))
	return clampf(best, 0.0, 1.0)


func _is_danger_kind(kind: String) -> bool:
	return kind.contains("danger") or kind.contains("threat") or kind.contains("attack") or kind.contains("hostile") or kind.contains("peligro")


func note_aggression(source_id: String) -> void:
	_aggression_cooldown = _calm_after_seconds
	_last_aggression_source = source_id
	behavior_mode = "hostil"
	if controller != null:
		var combat: Variant = controller.get("combat")
		if combat != null and combat.has_method("note_aggression"):
			combat.call("note_aggression", source_id)


func _is_hostile() -> bool:
	if controller == null:
		return false
	var personality: NPCPersonality = controller.personality
	if personality != null:
		return float(personality.aggressiveness) > 0.6
	return false


func _is_civilian() -> bool:
	if controller == null:
		return false
	var personality: NPCPersonality = controller.personality
	if personality != null:
		return float(personality.aggressiveness) <= 0.4
	return false


func _is_witness() -> bool:
	if controller == null:
		return false
	var personality: NPCPersonality = controller.personality
	if personality != null:
		return float(personality.sociability) > 0.5 and float(personality.aggressiveness) <= 0.6
	return false


func _update_blackboard(ctx: Dictionary) -> void:
	if _blackboard == null or not _blackboard.has_method("set"):
		return
	_blackboard.call("set", "danger", float(ctx.get("danger", 0.0)))
	_blackboard.call("set", "fear", float(ctx.get("fear", 0.0)))
	_blackboard.call("set", "aggression_cooldown", _aggression_cooldown)
	_blackboard.call("set", "last_aggression_source", _last_aggression_source)
	_blackboard.call("set", "behavior_mode", behavior_mode)
	_blackboard.call("set", "visible", bool(ctx.get("visible", false)))
	_blackboard.call("set", "target_position", ctx.get("target_position", Vector3.ZERO))
	if controller != null:
		var combat: Variant = controller.get("combat")
		if combat != null:
			_blackboard.call("set", "under_attack", float(combat.get("under_attack", 0.0)))
			_blackboard.call("set", "alert_level", float(combat.get("alert_level", 0.0)))


func _apply_behavior_mode(ctx: Dictionary) -> void:
	var delta: float = float(ctx.get("delta", 1.0 / 60.0))
	if _aggression_cooldown > 0.0:
		_aggression_cooldown -= delta
		if _aggression_cooldown <= 0.0:
			_aggression_cooldown = 0.0
			_last_aggression_source = ""
	
	var mem: NPCMemory = controller.memory if controller != null else null
	var danger: float = _memory_danger(mem)
	var aggressiveness: float = float(ctx.get("aggressiveness", 0.5))
	
	if behavior_mode == "hostil" and aggressiveness <= 0.4:
		behavior_mode = "pacifico"
	
	match behavior_mode:
		"hostil":
			if aggressiveness > 0.6:
				ctx["force_attack"] = true
				ctx["force_chase"] = _aggression_cooldown > 0.0
		"pacifico":
			if aggressiveness <= 0.4:
				ctx["force_flee"] = danger > 0.3 or _aggression_cooldown > 0.0
			elif float(ctx.get("sociability", 0.5)) > 0.5 and aggressiveness <= 0.6:
				ctx["force_witness"] = danger > 0.2 and _aggression_cooldown > 0.0


func _resolve_navigation(result: Dictionary, ctx: Dictionary) -> void:
	result["path"] = []
	result["path_ok"] = false
	result["follower"] = null
	result["goal_cell"] = null
	last_path = []
	follower = null
	if not bool(result["movement"]):
		return
	var goal_value: Variant = result.get("goal")
	if goal_value == null:
		var stop: Dictionary = ctx.get("routine_stop", {}) as Dictionary
		if not stop.is_empty():
			goal_value = stop.get("cell", stop.get("goal", stop.get("waypoint_id", stop.get("id", null))))
	var goal: Variant = _to_cell(goal_value)
	var from: Variant = _to_cell(ctx.get("from", Vector2i.ZERO))
	result["goal_cell"] = goal
	if goal == null or from == null:
		result["reason"] = "movement_without_goal"
		return
	if navigation == null:
		result["reason"] = "navigation_unavailable"
		return
	var path_result: Dictionary = navigation.find_path(from, goal)
	var path: Array = path_result.get("path", [])
	result["path_ok"] = bool(path_result.get("ok", false))
	result["path_reason"] = str(path_result.get("reason", ""))
	result["path"] = path.duplicate() if path is Array else []
	last_path = result["path"]
	follower = navigation.create_follower(path_result)
	result["follower"] = follower
	if not result["path_ok"]:
		result["reason"] = "path_failed"


func _to_cell(value: Variant) -> Variant:
	if value is Vector2i:
		return value
	if value is Vector3i:
		return Vector2i(value.x, value.z)
	if value is Vector2:
		return Vector2i(roundi(value.x), roundi(value.y))
	if value is Vector3:
		return Vector2i(roundi(value.x), roundi(value.z))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	if value is Dictionary:
		if value.has("cell"):
			return _to_cell(value["cell"])
		var x_value: Variant = value.get("x", value.get("col", null))
		var y_value: Variant = value.get("y", value.get("z", value.get("row", null)))
		if x_value != null and y_value != null:
			return Vector2i(int(x_value), int(y_value))
	return null
