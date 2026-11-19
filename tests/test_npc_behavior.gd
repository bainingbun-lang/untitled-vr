extends SceneTree

const NPCBehavior = preload("res://core/npc/npc_behavior.gd")
const NPCNavigation = preload("res://core/npc/npc_navigation.gd")
const NPCStateMachine = preload("res://core/npc/npc_state_machine.gd")
const NPCPersonality = preload("res://core/npc/npc_personality.gd")
const NPCNeeds = preload("res://core/npc/npc_needs.gd")
const NPCMemory = preload("res://core/npc/npc_memory.gd")
const NPCRoutine = preload("res://core/npc/npc_routine.gd")
const NPCController = preload("res://core/npc/npc_controller.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _init() -> void:
	_case = "necesidad urgente gana"
	var tired_controller: NPCController = _controller({}, {"fatigue": 0.95}, [{"waypoint_id": "work", "duration": 8.0}])
	var tired: Dictionary = NPCBehavior.new(tired_controller, null, {"hysteresis": 0.0}).select()
	_check("fatiga urgente gana a la rutina", tired["id"] == "rest", str(tired["id"]) + " util=" + str(tired["utility"]))
	_check("descanso supera utilidad de rutina", float(tired["utility"]) > 0.9, str(tired["utility"]))
	var scared_controller: NPCController = _controller(
		{"bravery": 0.0, "confidence": 0.0, "curiosity": 1.0, "sociability": 1.0},
		{"fatigue": 0.95, "fear": 1.0},
		[{"waypoint_id": "work", "duration": 8.0}],
		[{"type": "danger", "severity": 1.0}]
	)
	var scared: Dictionary = NPCBehavior.new(scared_controller, null, {"hysteresis": 0.0}).select()
	_check("miedo urgente gana aunque haya fatiga y rutina", scared["id"] == "flee", str(scared["id"]) + " util=" + str(scared["utility"]))

	_case = "rutina"
	var work_stop: Dictionary = {"waypoint_id": "work", "duration": 8.0, "cell": Vector2i(4, 4)}
	var routine_controller: NPCController = _controller({}, {}, [work_stop])
	var routine_nav: NPCNavigation = NPCNavigation.new(6, 6)
	var routine_behavior = NPCBehavior.new(routine_controller, routine_nav, {"hysteresis": 0.0})
	var routine_result: Dictionary = routine_behavior.select({"from": Vector2i(0, 0)})
	_check("rutina activa elige patrullar", routine_result["id"] == "patrol", str(routine_result["id"]))
	_check("rutina aporta objetivo de navegacion", routine_result["goal_cell"] == Vector2i(4, 4), str(routine_result["goal_cell"]))
	_check("rutina genera ruta valida", routine_result["path_ok"] == true and (routine_result["path"] as Array).size() > 1, str(routine_result["path"]))
	var idle_controller: NPCController = _controller({}, {}, [])
	var idle_result: Dictionary = NPCBehavior.new(idle_controller, null, {"hysteresis": 0.0}).select()
	_check("sin rutina no patrulla", idle_result["id"] != "patrol", str(idle_result["id"]))

	_case = "personalidad cambia el resultado"
	var social_controller: NPCController = _controller({"sociability": 1.0, "curiosity": 0.0, "aggressiveness": 0.0}, {}, [])
	var social: Dictionary = NPCBehavior.new(social_controller, null, {"hysteresis": 0.0}).select()
	_check("alta sociabilidad conversa", social["id"] == "converse", str(social["id"]))
	var curious_controller: NPCController = _controller({"sociability": 0.0, "curiosity": 1.0, "aggressiveness": 0.0}, {}, [])
	var curious: Dictionary = NPCBehavior.new(curious_controller, null, {"hysteresis": 0.0}).select()
	_check("alta curiosidad explora", curious["id"] == "explore", str(curious["id"]))
	_check("la personalidad cambia la accion", social["id"] != curious["id"], str([social["id"], curious["id"]]))

	_case = "memoria de peligro"
	var danger_controller: NPCController = _controller({}, {}, [], [{"kind": "threat", "intensity": 0.9}])
	var danger_result: Dictionary = NPCBehavior.new(danger_controller, null, {"hysteresis": 0.0}).select()
	_check("evento de amenaza dispara huida", danger_result["id"] == "flee", str(danger_result["id"]))
	var safe_controller: NPCController = _controller({}, {}, [], [{"type": "item_picked", "severity": 0.9}])
	var safe_result: Dictionary = NPCBehavior.new(safe_controller, null, {"hysteresis": 0.0}).select()
	_check("evento neutral no dispara huida", safe_result["id"] != "flee", str(safe_result["id"]))
	var text_controller: NPCController = _controller({}, {}, [], ["Attacked by a hostile creature"])
	var text_result: Dictionary = NPCBehavior.new(text_controller, null, {"hysteresis": 0.0}).select()
	_check("evento textual de peligro se interpreta", text_result["id"] == "flee", str(text_result["id"]))

	_case = "histeresis"
	var sticky = NPCBehavior.new(null, null, {"defaults": false, "hysteresis": 0.10})
	sticky.register_action("alpha", {"score": 0.50})
	sticky.register_action("beta", {"score": 0.52})
	var first: Dictionary = sticky.select()
	_check("sin inercia gana la mejor accion", first["id"] == "beta", str(first["id"]))
	sticky.set_current_action("alpha")
	var held: Dictionary = sticky.select()
	_check("histeresis conserva la accion actual", held["id"] == "alpha", str([held["id"], held["score"]]))
	sticky.register_action("beta", {"score": 0.70})
	var overtaken: Dictionary = sticky.select()
	_check("una mejora clara rompe la histeresis", overtaken["id"] == "beta", str([overtaken["id"], overtaken["score"]]))
	sticky.set_hysteresis(0.0)
	sticky.set_current_action("alpha")
	var no_hold: Dictionary = sticky.select()
	_check("sin histeresis no hay retencion", no_hold["id"] == "beta", str(no_hold["id"]))

	_case = "determinismo con misma semilla"
	var seeded_a = NPCBehavior.new(null, null, {"defaults": false, "hysteresis": 0.0, "seed": 4242})
	var seeded_b = NPCBehavior.new(null, null, {"defaults": false, "hysteresis": 0.0, "seed": 4242})
	for behavior in [seeded_a, seeded_b]:
		behavior.register_action("alfa", {"score": 0.4})
		behavior.register_action("zulu", {"score": 0.4})
	var picked_a: String = str(seeded_a.select()["id"])
	var picked_b: String = str(seeded_b.select()["id"])
	_check("misma semilla elige la misma accion", picked_a == picked_b, str([picked_a, picked_b]))
	_check("el desempate elige una accion real", picked_a in ["alfa", "zulu"], picked_a)
	var stable: bool = true
	for i in range(5):
		stable = stable and str(seeded_a.select()["id"]) == picked_a
	_check("selecciones repetidas son estables", stable, picked_a)
	_check("la semilla se conserva", seeded_a.get_seed() == 4242, str(seeded_a.get_seed()))

	_case = "sin acciones disponibles"
	var empty_behavior = NPCBehavior.new(null, null, {"defaults": false})
	var empty_result: Dictionary = empty_behavior.select()
	_check("sin acciones reporta fallo controlado", empty_result["ok"] == false and empty_result["reason"] == "no_actions" and str(empty_result["id"]).is_empty(), str(empty_result))
	empty_behavior.register_action("off", {"score": 0.9, "available": false})
	var disabled_result: Dictionary = empty_behavior.select()
	_check("acciones deshabilitadas cuentan como vacio", disabled_result["ok"] == false and disabled_result["reason"] == "no_actions", str(disabled_result))
	var empty_apply: Dictionary = empty_behavior.apply(disabled_result)
	_check("apply sin accion no inventa estado", empty_apply["ok"] == false and empty_apply["state"] == "", str(empty_apply))

	_case = "enganche opcional a navegacion"
	var move_controller: NPCController = _controller({}, {}, [{"waypoint_id": "home", "duration": 8.0, "cell": Vector2i(3, 2)}])
	var move_behavior = NPCBehavior.new(move_controller, NPCNavigation.new(6, 6), {"hysteresis": 0.0})
	var move_result: Dictionary = move_behavior.select({"from": Vector2i(0, 0)})
	_check("accion de desplazamiento calcula ruta", move_result["id"] == "patrol" and move_result["path_ok"] == true, str(move_result["path_reason"]))
	var state_report: Dictionary = move_behavior.apply(move_result)
	_check("apply transiciona al estado de la accion", state_report["state"] == "walk" and state_report["state_changed"] == true, str(state_report))
	var driven: Dictionary = move_behavior.apply(move_behavior.select({"from": Vector2i(0, 0)}), {"from": Vector2i(0, 0), "drive": true})
	_check("drive avanza el seguidor de ruta", driven["moved"] == true, str(driven))
	var no_nav_behavior = NPCBehavior.new(move_controller, null, {"hysteresis": 0.0})
	var no_nav_result: Dictionary = no_nav_behavior.select({"from": Vector2i(0, 0)})
	_check("sin navegador la seleccion sigue funcionando", no_nav_result["ok"] == true and no_nav_result["path_ok"] == false and no_nav_result["reason"] == "navigation_unavailable", str(no_nav_result))

	_finish()


func _controller(pers: Dictionary, needs_values: Dictionary, stops: Array, events: Array = []) -> NPCController:
	var needs: NPCNeeds = NPCNeeds.new()
	for key in needs_values.keys():
		needs.set(key, float(needs_values[key]))
	var memory: NPCMemory = NPCMemory.new()
	for event in events:
		memory.add_event(event)
	return NPCController.new(
		NPCStateMachine.new(),
		NPCPersonality.new(pers),
		needs,
		memory,
		NPCRoutine.new(stops)
	)


func _check(name: String, condition: bool, detail: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s -> %s" % [_case, name, detail])


func _finish() -> void:
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)
