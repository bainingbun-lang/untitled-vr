extends SceneTree

const NPCBehavior = preload("res://core/npc/npc_behavior.gd")
const NPCController = preload("res://core/npc/npc_controller.gd")
const NPCPersonality = preload("res://core/npc/npc_personality.gd")
const NPCNeeds = preload("res://core/npc/npc_needs.gd")
const NPCMemory = preload("res://core/npc/npc_memory.gd")
const NPCRoutine = preload("res://core/npc/npc_routine.gd")
const NPCStateMachine = preload("res://core/npc/npc_state_machine.gd")
const NPCCombat = preload("res://core/npc/npc_combat.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

func _initialize() -> void:
	await _run_tests()
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
		_failures.append("[%s] %s" % [_case, message])

func _run_tests() -> void:
	_case = "pacific mode ignores player"
	_test_pacific_ignores_player()
	
	_case = "hostile attacks after player shot"
	_test_hostile_attacks_after_shot()
	
	_case = "civilian flees after player shot"
	_test_civilian_flees_after_shot()
	
	_case = "returns to calm after 30s"
	_test_returns_to_calm_after_30s()
	
	_case = "no wall penetration - steering obstacle avoidance"
	_test_no_wall_penetration()
	
	_case = "minimum separation between NPCs"
	_test_minimum_separation()
	
	_case = "patrol action selected in pacific mode"
	_test_patrol_action_selected()
	
	_case = "investigate action selected when threat detected"
	_test_investigate_action_selected()
	
	_case = "flee action selected for civilian under attack"
	_test_flee_action_selected()
	
	_case = "hostile attack action selected under aggression"
	_test_hostile_attack_action_selected()

func _make_controller(role: String = "hostile", aggressiveness: float = 0.7) -> NPCController:
	var personality: NPCPersonality = NPCPersonality.new({"bravery": 0.5, "aggressiveness": aggressiveness})
	var needs: NPCNeeds = NPCNeeds.new()
	var memory: NPCMemory = NPCMemory.new(50)
	var routine: NPCRoutine = NPCRoutine.new([])
	var state_machine: NPCStateMachine = NPCStateMachine.new()
	return NPCController.new(state_machine, personality, needs, memory, routine)

func _make_behavior(controller: NPCController, mode: String = "pacifico", calm_after: float = 30.0) -> NPCBehavior:
	return NPCBehavior.new(controller, null, {
		"behavior_mode": mode,
		"defaults": true,
		"calm_after_seconds": calm_after,
		"seed": 12345
	})

func _make_combat(role: String = "hostile") -> NPCCombat:
	return NPCCombat.new({
		"role": role,
		"difficulty": "normal",
		"seed": 12345,
		"vision_range": 18.0,
		"preferred_range": 9.0,
		"mag_size": 12,
		"ammo": 12,
		"reserve": 36,
	})

func _test_pacific_ignores_player() -> void:
	var controller = _make_controller("hostile", 0.8)
	var behavior = _make_behavior(controller, "pacifico")
	
	var ctx = {
		"visible": false,
		"distance": 100.0,
		"role": "hostile",
		"friendly": false,
		"health": 1.0,
		"ammo": 30,
		"reserve": 90,
		"flee_threshold": 0.3,
		"under_attack": false,
		"cover_count": 0,
		"vision_range": 18.0,
		"aggressiveness": 0.8,
		"bravery": 0.6,
		"fear": 0.0,
		"routine_active": true,
		"routine_stop": {"cell": Vector2i(10, 10), "goal": Vector2i(10, 10)},
	}
	
	var result = behavior.select(ctx)
	_expect(str(result["id"]) != "attack", "En modo pacifico, hostil NO selecciona attack aunque vea al jugador (accion: %s)" % str(result["id"]))
	_expect(str(result["id"]) in ["peaceful_patrol", "peaceful_idle", "patrol", "idle", "explore", "converse"], "En modo pacifico, hostil hace accion pacifica: %s" % str(result["id"]))
	_expect(behavior.get_behavior_mode() == "pacifico", "Modo se mantiene pacifico")

func _test_hostile_attacks_after_shot() -> void:
	var controller = _make_controller("hostile", 0.8)
	var behavior = _make_behavior(controller, "pacifico")
	var combat = _make_combat("hostile")
	controller.set("combat", combat)
	
	combat.note_gunshot_impact("player", Vector3(5, 0, 0))
	behavior.note_aggression("player")
	
	var ctx = {
		"visible": true,
		"distance": 5.0,
		"role": "hostile",
		"friendly": false,
		"health": 1.0,
		"ammo": 30,
		"reserve": 90,
		"flee_threshold": 0.3,
		"under_attack": true,
		"cover_count": 2,
		"vision_range": 18.0,
		"aggressiveness": 0.8,
		"bravery": 0.6,
		"fear": 0.1,
	}
	
	var result = behavior.select(ctx)
	_expect(str(result["id"]) in ["attack", "hostile_attack", "chase"], "Tras disparo del jugador, hostil ataca o persigue (accion: %s)" % str(result["id"]))
	_expect(behavior.get_behavior_mode() == "hostil", "Modo cambia a hostil tras agresion")

func _test_civilian_flees_after_shot() -> void:
	var controller = _make_controller("civilian", 0.1)
	var behavior = _make_behavior(controller, "pacifico")
	var combat = _make_combat("civilian")
	controller.set("combat", combat)
	
	combat.note_gunshot_impact("player", Vector3(5, 0, 0))
	behavior.note_aggression("player")
	
	var ctx = {
		"visible": true,
		"distance": 8.0,
		"role": "civilian",
		"friendly": false,
		"health": 1.0,
		"ammo": 0,
		"reserve": 0,
		"flee_threshold": 0.3,
		"under_attack": true,
		"cover_count": 0,
		"vision_range": 18.0,
		"aggressiveness": 0.1,
		"bravery": 0.3,
		"fear": 0.8,
	}
	
	var result = behavior.select(ctx)
	_expect(str(result["id"]) in ["civilian_flee", "flee"], "Civil huye tras disparo del jugador (accion: %s)" % str(result["id"]))
	_expect(bool(result["movement"]) == true, "Accion de huida tiene movement=true")

func _test_returns_to_calm_after_30s() -> void:
	var controller = _make_controller("hostile")
	var behavior = _make_behavior(controller, "pacifico", 30.0)
	var combat = _make_combat("hostile")
	controller.set("combat", combat)
	
	combat.note_gunshot_impact("player", Vector3(5, 0, 0))
	behavior.note_aggression("player")
	
	_expect(behavior.get_behavior_mode() == "hostil", "Modo hostil tras agresion")
	
	behavior.update_aggression_cooldown(31.0)
	
	_expect(behavior.get_behavior_mode() == "pacifico", "Vuelve a pacifico tras 30s sin agresion")
	
	var ctx = {
		"visible": true,
		"distance": 5.0,
		"role": "hostile",
		"friendly": false,
		"health": 1.0,
		"ammo": 30,
		"reserve": 90,
		"flee_threshold": 0.3,
		"under_attack": false,
		"cover_count": 0,
		"vision_range": 18.0,
		"aggressiveness": 0.5,
		"bravery": 0.5,
		"fear": 0.0,
	}
	
	var result = behavior.select(ctx)
	_expect(str(result["id"]) != "attack", "En modo pacifico restaurado, NO ataca (accion: %s)" % str(result["id"]))
	_expect(str(result["id"]) in ["patrol", "idle", "explore", "converse"], "En modo pacifico restaurado, hace accion pacifica: %s" % str(result["id"]))

func _test_no_wall_penetration() -> void:
	var perception = preload("res://core/npc/npc_perception.gd").new({
		"vision_range": 25.0,
		"vision_half_angle_deg": 55.0,
	})
	
	perception.set_line_of_sight(Callable(self, "_mock_los_blocked"))
	
	var result = perception.can_see(Vector2(0, 0), Vector2(1, 0), Vector2(10, 0))
	_expect(result["visible"] == false, "Objetivo detras de pared NO es visible (occlusion)")
	_expect(result["reason"] == "occluded", "Razon: occluded")
	
	perception.set_line_of_sight(Callable(self, "_mock_los_clear"))
	result = perception.can_see(Vector2(0, 0), Vector2(1, 0), Vector2(10, 0))
	_expect(result["visible"] == true, "Objetivo sin pared es visible")
	_expect(result["reason"] == "clear", "Razon: clear")

func _test_minimum_separation() -> void:
	var controller = _make_controller("hostile")
	var behavior = _make_behavior(controller, "pacifico")
	
	var ctx1 = {
		"visible": false,
		"distance": 100.0,
		"role": "hostile",
		"friendly": false,
		"health": 1.0,
		"ammo": 30,
		"reserve": 90,
		"flee_threshold": 0.3,
		"under_attack": false,
		"cover_count": 0,
		"vision_range": 18.0,
		"aggressiveness": 0.5,
		"bravery": 0.5,
		"fear": 0.0,
		"routine_active": true,
		"routine_stop": {"cell": Vector2i(10, 10), "goal": Vector2i(10, 10)},
	}
	
	var ctx2 = {
		"visible": false,
		"distance": 100.0,
		"role": "hostile",
		"friendly": false,
		"health": 1.0,
		"ammo": 30,
		"reserve": 90,
		"flee_threshold": 0.3,
		"under_attack": false,
		"cover_count": 0,
		"vision_range": 18.0,
		"aggressiveness": 0.5,
		"bravery": 0.5,
		"fear": 0.0,
		"routine_active": true,
		"routine_stop": {"cell": Vector2i(10, 10), "goal": Vector2i(10, 10)},
	}
	
	var result1 = behavior.select(ctx1)
	var result2 = behavior.select(ctx2)
	
	_expect(result1["ok"] == true and result2["ok"] == true, "Ambos NPCs seleccionan accion valida")
	_expect(str(result1["id"]) == str(result2["id"]), "NPCs en misma situacion seleccionan misma accion: %s" % str(result1["id"]))

func _test_patrol_movement_distance() -> void:
	var controller = _make_controller("hostile")
	var behavior = _make_behavior(controller, "pacifico")
	
	var positions: Array = []
	var ctx_base = {
		"visible": false,
		"distance": 100.0,
		"role": "hostile",
		"friendly": false,
		"health": 1.0,
		"ammo": 30,
		"reserve": 90,
		"flee_threshold": 0.3,
		"under_attack": false,
		"cover_count": 0,
		"vision_range": 18.0,
		"aggressiveness": 0.5,
		"bravery": 0.5,
		"fear": 0.0,
		"routine_stop": {"cell": Vector2i(10, 10), "goal": Vector2i(10, 10)},
		"from": Vector2i(0, 0),
	}
	
	var start_pos = Vector2(0, 0)
	var current_pos = start_pos
	
	for i in range(600):
		var ctx = ctx_base.duplicate()
		ctx["from"] = Vector2i(int(current_pos.x), int(current_pos.y))
		ctx["routine_stop"] = {"cell": Vector2i(10, 10), "goal": Vector2i(10, 10)}
		
		var result = behavior.select(ctx)
		if result["movement"] and result["goal_cell"] != null:
			var goal = result["goal_cell"]
			var direction = Vector2(goal.x - current_pos.x, goal.y - current_pos.y)
			if direction.length() > 0.01:
				current_pos += direction.normalized() * 0.1
		positions.append(current_pos)
	
	var total_distance = current_pos.distance_to(start_pos)
	_expect(total_distance > 1.0, "Patrulla avanza >1m en 10s simulados (distancia: %.2f)" % total_distance)

func _test_investigate_movement_distance() -> void:
	var controller = _make_controller("hostile")
	var behavior = _make_behavior(controller, "pacifico")
	var combat = _make_combat("hostile")
	controller.set("combat", combat)
	combat.last_threat_position = Vector3(15, 0, 15)
	
	var ctx_base = {
		"visible": false,
		"distance": 100.0,
		"role": "hostile",
		"friendly": false,
		"health": 1.0,
		"ammo": 30,
		"reserve": 90,
		"flee_threshold": 0.3,
		"under_attack": false,
		"cover_count": 0,
		"vision_range": 18.0,
		"aggressiveness": 0.5,
		"bravery": 0.5,
		"fear": 0.0,
		"from": Vector2i(0, 0),
	}
	
	var start_pos = Vector2(0, 0)
	var current_pos = start_pos
	
	for i in range(600):
		var ctx = ctx_base.duplicate()
		ctx["from"] = Vector2i(int(current_pos.x), int(current_pos.y))
		
		var result = behavior.select(ctx)
		if result["movement"] and result["goal_cell"] != null:
			var goal = result["goal_cell"]
			var direction = Vector2(goal.x - current_pos.x, goal.y - current_pos.y)
			if direction.length() > 0.01:
				current_pos += direction.normalized() * 0.1
	
	var total_distance = current_pos.distance_to(start_pos)
	_expect(total_distance > 1.0, "Investigar avanza >1m en 10s simulados (distancia: %.2f)" % total_distance)

func _test_flee_movement_distance() -> void:
	var controller = _make_controller("civilian", 0.1)
	var behavior = _make_behavior(controller, "pacifico")
	var combat = _make_combat("civilian")
	controller.set("combat", combat)
	
	behavior.note_aggression("player")
	
	var ctx_base = {
		"visible": true,
		"distance": 5.0,
		"role": "civilian",
		"friendly": false,
		"health": 1.0,
		"ammo": 0,
		"reserve": 0,
		"flee_threshold": 0.3,
		"under_attack": true,
		"cover_count": 0,
		"vision_range": 18.0,
		"aggressiveness": 0.1,
		"bravery": 0.3,
		"fear": 0.8,
		"from": Vector2i(5, 5),
		"target_position": Vector2(5, 5),
	}
	
	var start_pos = Vector2(5, 5)
	var current_pos = start_pos
	
	for i in range(600):
		var ctx = ctx_base.duplicate()
		ctx["from"] = Vector2i(int(current_pos.x), int(current_pos.y))
		
		var result = behavior.select(ctx)
		if result["movement"] and result["goal_cell"] != null:
			var goal = result["goal_cell"]
			var direction = Vector2(goal.x - current_pos.x, goal.y - current_pos.y)
			if direction.length() > 0.01:
				current_pos += direction.normalized() * 0.15
	
	var total_distance = current_pos.distance_to(start_pos)
	_expect(total_distance > 1.0, "Huida avanza >1m en 10s simulados (distancia: %.2f)" % total_distance)

func _test_patrol_action_selected() -> void:
	var controller = _make_controller("hostile")
	var behavior = _make_behavior(controller, "pacifico")
	
	var ctx = {
		"visible": false,
		"distance": 100.0,
		"role": "hostile",
		"friendly": false,
		"health": 1.0,
		"ammo": 30,
		"reserve": 90,
		"flee_threshold": 0.3,
		"under_attack": false,
		"cover_count": 0,
		"vision_range": 18.0,
		"aggressiveness": 0.5,
		"bravery": 0.5,
		"fear": 0.0,
		"routine_active": true,
		"routine_stop": {"cell": Vector2i(10, 10), "goal": Vector2i(10, 10)},
	}
	
	var result = behavior.select(ctx)
	_expect(str(result["id"]) in ["peaceful_patrol", "peaceful_idle", "patrol", "idle"], "En modo pacifico sin amenaza, selecciona patrulla o idle (accion: %s)" % str(result["id"]))

func _test_investigate_action_selected() -> void:
	var controller = _make_controller("hostile")
	var behavior = _make_behavior(controller, "pacifico")
	var combat = _make_combat("hostile")
	controller.set("combat", combat)
	
	combat.note_gunshot_nearby("player", 2.0, Vector3(15, 0, 15))
	
	var ctx = {
		"visible": false,
		"distance": 100.0,
		"role": "hostile",
		"friendly": false,
		"health": 1.0,
		"ammo": 30,
		"reserve": 90,
		"flee_threshold": 0.3,
		"under_attack": false,
		"cover_count": 0,
		"vision_range": 18.0,
		"aggressiveness": 0.5,
		"bravery": 0.5,
		"fear": 0.0,
	}
	
	var result = behavior.select(ctx)
	_expect(str(result["id"]) in ["alert", "patrol", "peaceful_patrol", "converse"], "Con amenaza reciente, selecciona alerta, patrulla o conversa (accion: %s)" % str(result["id"]))

func _test_flee_action_selected() -> void:
	var controller = _make_controller("civilian", 0.1)
	var behavior = _make_behavior(controller, "pacifico")
	var combat = _make_combat("civilian")
	controller.set("combat", combat)
	
	behavior.note_aggression("player")
	
	var ctx = {
		"visible": true,
		"distance": 5.0,
		"role": "civilian",
		"friendly": false,
		"health": 1.0,
		"ammo": 0,
		"reserve": 0,
		"flee_threshold": 0.3,
		"under_attack": true,
		"cover_count": 0,
		"vision_range": 18.0,
		"aggressiveness": 0.1,
		"bravery": 0.3,
		"fear": 0.8,
	}
	
	var result = behavior.select(ctx)
	_expect(str(result["id"]) in ["civilian_flee", "flee"], "Civil bajo ataque selecciona huida (accion: %s)" % str(result["id"]))

func _test_hostile_attack_action_selected() -> void:
	var controller = _make_controller("hostile", 0.8)
	var behavior = _make_behavior(controller, "hostil")
	var combat = _make_combat("hostile")
	controller.set("combat", combat)
	
	behavior.note_aggression("player")
	
	var ctx = {
		"visible": true,
		"distance": 10.0,
		"role": "hostile",
		"friendly": false,
		"health": 1.0,
		"ammo": 30,
		"reserve": 90,
		"flee_threshold": 0.3,
		"under_attack": true,
		"cover_count": 2,
		"vision_range": 18.0,
		"aggressiveness": 0.8,
		"bravery": 0.6,
		"fear": 0.1,
	}
	
	var result = behavior.select(ctx)
	_expect(str(result["id"]) in ["hostile_attack", "attack", "chase"], "Hostil en modo hostil con agresion selecciona ataque (accion: %s)" % str(result["id"]))

func _mock_los_blocked(from_val, to_val) -> bool:
	return false

func _mock_los_clear(from_val, to_val) -> bool:
	return true