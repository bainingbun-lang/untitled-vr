extends SceneTree

const NPCPerception = preload("res://core/npc/npc_perception.gd")
const NPCMemory = preload("res://core/npc/npc_memory.gd")
const NPCBehavior = preload("res://core/npc/npc_behavior.gd")
const NPCController = preload("res://core/npc/npc_controller.gd")
const NPCPersonality = preload("res://core/npc/npc_personality.gd")
const NPCNeeds = preload("res://core/npc/npc_needs.gd")
const NPCRoutine = preload("res://core/npc/npc_routine.gd")
const NPCStateMachine = preload("res://core/npc/npc_state_machine.gd")

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
	_case = "vision cone 110 deg 25m"
	_test_vision_cone()
	
	_case = "hearing gunshot"
	_test_hearing_gunshot()
	
	_case = "aggression detection shot impact"
	_test_aggression_shot_impact()
	
	_case = "aggression detection shot nearby"
	_test_aggression_shot_nearby()
	
	_case = "aggression detection melee"
	_test_aggression_melee()
	
	_case = "aggression detection aimed at"
	_test_aggression_aimed_at()
	
	_case = "hostile attacks after aggression"
	_test_hostile_attacks_after_aggression()
	
	_case = "civilian flees after aggression"
	_test_civilian_flees_after_aggression()
	
	_case = "calm after 30s no aggression"
	_test_calm_after_30s()
	
	_case = "perception writes to memory"
	_test_perception_writes_to_memory()
	
	_case = "line of sight occlusion"
	_test_line_of_sight_occlusion()

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

func _make_perception(options: Dictionary = {}) -> NPCPerception:
	var defaults = {
		"vision_range": 25.0,
		"vision_half_angle_deg": 55.0,
		"hearing_range": 25.0,
		"max_stimuli_per_tick": 8,
	}
	for key in options:
		defaults[key] = options[key]
	return NPCPerception.new(defaults)

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

func _test_vision_cone() -> void:
	var perception = _make_perception()
	
	var origin = Vector2(0, 0)
	var facing = Vector2(1, 0)
	
	var result = perception.can_see(origin, facing, Vector2(10, 0))
	_expect(result["visible"] == true, "Objetivo en el centro del cono (0 deg) es visible")
	_expect(result["distance"] == 10.0, "Distancia correcta: 10m")
	_expect(result["angle_deg"] == 0.0, "Angulo 0 grados")
	
	result = perception.can_see(origin, facing, Vector2(10, 5))
	_expect(result["visible"] == true, "Objetivo a 26.5 deg es visible (dentro de 55)")
	_expect(result["angle_deg"] > 26.0 and result["angle_deg"] < 27.0, "Angulo aprox 26.5 deg")
	
	result = perception.can_see(origin, facing, Vector2(10, 15))
	_expect(result["visible"] == false, "Objetivo a 56 deg NO es visible (fuera de 55)")
	_expect(result["reason"] == "out_of_cone", "Razon: out_of_cone")
	
	result = perception.can_see(origin, facing, Vector2(30, 0))
	_expect(result["visible"] == false, "Objetivo a 30m NO es visible (fuera de rango 25m)")
	_expect(result["reason"] == "out_of_range", "Razon: out_of_range")
	
	result = perception.can_see(origin, facing, Vector2(-10, 0))
	_expect(result["visible"] == false, "Objetivo atras (180 deg) NO es visible")
	_expect(result["reason"] == "out_of_cone", "Razon: out_of_cone")

func _test_hearing_gunshot() -> void:
	var perception = _make_perception()
	
	var observer_pos = Vector2(0, 0)
	var observer_facing = Vector2(1, 0)
	
	var stimulus = {
		"id": "player",
		"source_id": "player",
		"kind": "gunshot",
		"type": "gunshot",
		"position": Vector2(20, 0),
		"channel": "gunshot",
	}
	
	var result = perception.evaluate_stimulus(stimulus, observer_pos, observer_facing)
	_expect(result["heard"] == true, "Disparo a 20m es audible (rango 50m por defecto)")
	_expect(result["channel"] == "gunshot", "Canal: gunshot")
	_expect(result["intensity"] > 0.5, "Intensidad alta para disparo cercano")
	_expect(result["priority"] > 1.0, "Prioridad alta (intensidad * 2)")
	
	stimulus.position = Vector2(60, 0)
	result = perception.evaluate_stimulus(stimulus, observer_pos, observer_facing)
	_expect(result["heard"] == false, "Disparo a 60m NO es audible (fuera de 50m)")
	_expect(result["reason"] == "out_of_range", "Razon: out_of_range")

func _test_aggression_shot_impact() -> void:
	var controller = _make_controller("hostile")
	var behavior = _make_behavior(controller)
	var combat = _make_combat("hostile")
	controller.set("combat", combat)
	combat.behavior = behavior
	
	combat.note_gunshot_impact("player", Vector3(5, 0, 0))
	behavior.note_aggression("player")
	
	_expect(combat.under_attack == 2.0, "under_attack = 2.0 tras impacto de disparo")
	_expect(combat.alert_level == 1.0, "alert_level = 1.0 tras impacto")
	
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
		"aggressiveness": 0.7,
		"bravery": 0.6,
		"fear": 0.1,
	}
	
	var result = behavior.select(ctx)
	_expect(str(result["id"]) in ["attack", "hostile_attack", "chase"], "Tras impacto de disparo, hostil ataca o persigue (accion: %s)" % str(result["id"]))
	_expect(behavior.get_behavior_mode() == "hostil", "Modo cambia a hostil tras agresion")

func _test_aggression_shot_nearby() -> void:
	var controller = _make_controller("hostile")
	var behavior = _make_behavior(controller)
	var combat = _make_combat("hostile")
	controller.set("combat", combat)
	combat.behavior = behavior
	
	combat.note_gunshot_nearby("player", 2.5, Vector3(5, 0, 0))
	behavior.note_aggression("player")
	
	_expect(combat.under_attack == 1.5, "under_attack = 1.5 tras disparo cercano (<3m)")
	_expect(combat.alert_level >= 0.7, "alert_level >= 0.7 tras disparo cercano")
	
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
		"aggressiveness": 0.7,
		"bravery": 0.6,
		"fear": 0.1,
	}
	
	var result = behavior.select(ctx)
	_expect(str(result["id"]) in ["attack", "hostile_attack", "chase"], "Tras disparo cercano, hostil ataca o persigue (accion: %s)" % str(result["id"]))

func _test_aggression_melee() -> void:
	var controller = _make_controller("hostile")
	var behavior = _make_behavior(controller)
	var combat = _make_combat("hostile")
	controller.set("combat", combat)
	combat.behavior = behavior
	
	combat.note_melee_attack("player", 0.8, Vector3(1, 0, 0))
	behavior.note_aggression("player")
	
	_expect(combat.under_attack == 2.0, "under_attack = 2.0 tras ataque melee")
	_expect(combat.alert_level == 1.0, "alert_level = 1.0 tras melee")
	
	var ctx = {
		"visible": true,
		"distance": 2.0,
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
	
	var result = behavior.select(ctx)
	_expect(str(result["id"]) in ["attack", "hostile_attack", "chase"], "Tras melee, hostil ataca o persigue (accion: %s)" % str(result["id"]))

func _test_aggression_aimed_at() -> void:
	var controller = _make_controller("hostile")
	var behavior = _make_behavior(controller)
	var combat = _make_combat("hostile")
	controller.set("combat", combat)
	combat.behavior = behavior
	
	for i in range(121):
		combat.note_aimed_at("player", 5.0, true, 1.0/60.0)
	behavior.note_aggression("player")
	
	_expect(combat.under_attack >= 1.0, "under_attack >= 1.0 tras apuntar 2s a <8m con arma cargada (valor: %s)" % str(combat.under_attack))
	_expect(combat.alert_level >= 0.5, "alert_level >= 0.5 tras apuntar prolongado (valor: %s)" % str(combat.alert_level))
	
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
		"aggressiveness": 0.7,
		"bravery": 0.6,
		"fear": 0.1,
	}
	
	var result = behavior.select(ctx)
	_expect(str(result["id"]) in ["attack", "hostile_attack", "chase"], "Tras apuntar prolongado, hostil ataca o persigue (accion: %s)" % str(result["id"]))

func _test_hostile_attacks_after_aggression() -> void:
	var controller = _make_controller("hostile", 0.8)
	var behavior = _make_behavior(controller)
	var combat = _make_combat("hostile")
	controller.set("combat", combat)
	combat.behavior = behavior
	
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
	_expect(str(result["id"]) in ["attack", "hostile_attack", "chase"], "Hostil ataca o persigue tras agresion (accion: %s)" % str(result["id"]))
	_expect(behavior.get_behavior_mode() == "hostil", "Modo es hostil tras agresion")

func _test_civilian_flees_after_aggression() -> void:
	var controller = _make_controller("civilian", 0.1)
	var behavior = _make_behavior(controller)
	var combat = _make_combat("civilian")
	controller.set("combat", combat)
	combat.behavior = behavior
	
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
	_expect(str(result["id"]) in ["civilian_flee", "flee"], "Civil huye tras agresion (accion: %s)" % str(result["id"]))
	_expect(bool(result["movement"]) == true, "Accion de huida tiene movement=true")

func _test_calm_after_30s() -> void:
	var controller = _make_controller("hostile")
	var behavior = _make_behavior(controller, "pacifico", 30.0)
	
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

func _test_perception_writes_to_memory() -> void:
	var perception = _make_perception()
	var memory = NPCMemory.new(50)
	
	var stimuli = [{
		"id": "player",
		"source_id": "player",
		"kind": "gunshot",
		"type": "gunshot",
		"position": Vector2(10, 0),
		"channel": "gunshot",
	}]
	
	var result = perception.perceive(stimuli, Vector2(0, 0), Vector2(1, 0))
	_expect(result["count"] == 1, "Percepcion detecta 1 estimulo relevante")
	
	var written = perception.write_to_memory(memory, result)
	_expect(written == 1, "Escrito 1 evento a memoria")
	
	var events = memory.get_events()
	_expect(events.size() == 1, "Memoria tiene 1 evento")
	_expect(str(events[0]["type"]) == "gunshot", "Tipo de evento: gunshot")
	_expect(str(events[0]["kind"]) == "gunshot", "Canal: gunshot")
	_expect(float(events[0]["severity"]) > 0.5, "Severidad alta")

func _test_line_of_sight_occlusion() -> void:
	var perception = _make_perception()
	
	perception.set_line_of_sight(Callable(self, "_mock_los_blocked"))
	
	var result = perception.can_see(Vector2(0, 0), Vector2(1, 0), Vector2(10, 0))
	_expect(result["visible"] == false, "Objetivo ocluido NO es visible")
	_expect(result["reason"] == "occluded", "Razon: occluded")
	
	perception.set_line_of_sight(Callable(self, "_mock_los_clear"))
	result = perception.can_see(Vector2(0, 0), Vector2(1, 0), Vector2(10, 0))
	_expect(result["visible"] == true, "Objetivo sin oclusion es visible")
	_expect(result["reason"] == "clear", "Razon: clear")

func _mock_los_blocked(from_val, to_val) -> bool:
	return false

func _mock_los_clear(from_val, to_val) -> bool:
	return true