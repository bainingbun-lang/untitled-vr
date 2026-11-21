extends SceneTree

const NPCBehavior = preload("res://core/npc/npc_behavior.gd")
const NPCController = preload("res://core/npc/npc_controller.gd")
const NPCPersonality = preload("res://core/npc/npc_personality.gd")
const NPCNeeds = preload("res://core/npc/npc_needs.gd")
const NPCMemory = preload("res://core/npc/npc_memory.gd")
const NPCRoutine = preload("res://core/npc/npc_routine.gd")
const NPCStateMachine = preload("res://core/npc/npc_state_machine.gd")

var _checks: int = 0
var _failures: Array = []


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
		_failures.append(message)


func _run_tests() -> void:
	_test_peaceful_mode_ignores_player()
	_test_hostile_attacks_after_aggression()
	_test_civilian_flees_after_aggression()
	_test_returns_to_calm_after_30s()
	_test_behavior_mode_switching()


func _make_controller(role: String = "hostile") -> NPCController:
	var personality: NPCPersonality = NPCPersonality.new({"bravery": 0.5, "aggressiveness": 0.5})
	var needs: NPCNeeds = NPCNeeds.new()
	var memory: NPCMemory = NPCMemory.new(50)
	var routine: NPCRoutine = NPCRoutine.new([])
	var state_machine: NPCStateMachine = NPCStateMachine.new()
	return NPCController.new(state_machine, personality, needs, memory, routine)


func _test_peaceful_mode_ignores_player() -> void:
	var controller: NPCController = _make_controller("hostile")
	var behavior: NPCBehavior = NPCBehavior.new(controller, null, {
		"behavior_mode": "pacifico",
		"defaults": true,
		"seed": 12345
	})
	
	var ctx: Dictionary = {
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
	
	var result: Dictionary = behavior.select(ctx)
	
	_expect(str(result["id"]) != "hostile_attack", "En modo pacifico, hostil NO selecciona attack aunque vea al jugador (accion: %s)" % str(result["id"]))
	_expect(str(result["id"]) in ["peaceful_patrol", "peaceful_idle", "patrol", "idle", "explore", "converse"], "En modo pacifico, hostil hace accion pacifica: %s" % str(result["id"]))


func _test_hostile_attacks_after_aggression() -> void:
	var controller: NPCController = _make_controller("hostile")
	var behavior: NPCBehavior = NPCBehavior.new(controller, null, {
		"behavior_mode": "pacifico",
		"defaults": true,
		"seed": 12345
	})
	
	behavior.note_aggression("player")
	
	var ctx: Dictionary = {
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
		"aggressiveness": 0.7,
		"bravery": 0.6,
		"fear": 0.1,
	}
	
	var result: Dictionary = behavior.select(ctx)
	
	_expect(str(result["id"]) == "hostile_attack", "Tras agresion, hostil selecciona attack (accion: %s)" % str(result["id"]))
	_expect(behavior.get_behavior_mode() == "hostil", "Modo cambia a hostil tras agresion")


func _test_civilian_flees_after_aggression() -> void:
	var controller: NPCController = _make_controller("civilian")
	var behavior: NPCBehavior = NPCBehavior.new(controller, null, {
		"behavior_mode": "pacifico",
		"defaults": true,
		"seed": 12345
	})
	
	behavior.note_aggression("player")
	
	var ctx: Dictionary = {
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
	
	var result: Dictionary = behavior.select(ctx)
	
	_expect(str(result["id"]) == "civilian_flee", "Civil huye tras agresion (accion: %s)" % str(result["id"]))
	_expect(bool(result["movement"]), "Accion de huida tiene movement=true")


func _test_returns_to_calm_after_30s() -> void:
	var controller: NPCController = _make_controller("hostile")
	var behavior: NPCBehavior = NPCBehavior.new(controller, null, {
		"behavior_mode": "pacifico",
		"defaults": true,
		"calm_after_seconds": 30.0,
		"seed": 12345
	})
	
	behavior.note_aggression("player")
	
	behavior.update_aggression_cooldown(31.0)
	
	_expect(behavior.get_behavior_mode() == "pacifico", "Vuelve a pacifico tras 30s sin agresion")
	_expect(str(behavior.get_current_action()) == "", "Accion actual reseteada")
	
	var ctx: Dictionary = {
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
	
	var result: Dictionary = behavior.select(ctx)
	
	_expect(str(result["id"]) != "hostile_attack", "En modo pacifico restaurado, NO ataca (accion: %s)" % str(result["id"]))
	_expect(str(result["id"]) in ["peaceful_patrol", "peaceful_idle", "patrol", "idle", "converse", "explore"], "En modo pacifico restaurado, hace accion pacifica: %s" % str(result["id"]))


func _test_behavior_mode_switching() -> void:
	var controller: NPCController = _make_controller("hostile")
	var behavior: NPCBehavior = NPCBehavior.new(controller, null, {
		"behavior_mode": "hostil",
		"defaults": true,
		"seed": 12345
	})
	
	_expect(behavior.get_behavior_mode() == "hostil", "Inicia en modo hostil")
	
	behavior.set_behavior_mode("pacifico")
	_expect(behavior.get_behavior_mode() == "pacifico", "Cambia a pacifico via set_behavior_mode")
	
	behavior.set_behavior_mode("hostil")
	_expect(behavior.get_behavior_mode() == "hostil", "Cambia a hostil via set_behavior_mode")
	
	behavior.set_behavior_mode("invalid")
	_expect(behavior.get_behavior_mode() == "pacifico", "Modo invalido default a pacifico")