extends SceneTree

const SpawnerScript = preload("res://core/game/world_spawner.gd")

var _checks := 0
var _failures: Array = []
var _case := ""


func _init() -> void:
	var spawner = SpawnerScript.new()

	_case = "reparto determinista"
	var map := _map(3)
	var defs := _defs(6)
	var first: Dictionary = spawner.spawn(map, defs, 4242)
	var second: Dictionary = spawner.spawn(map, defs, 4242)
	_expect((first["spawned"] as Array).size() == 6, "se deben crear los 6 NPCs")
	_expect((first["rejected"] as Array).is_empty(), "no debe haber rechazos en datos validos")
	_expect(_assignment(first) == _assignment(second), "el reparto debe ser identico con la misma semilla")
	_expect(_covers_all_points(first, 3), "los spawn_points deben quedar cubiertos")
	_expect(_unique_points(first), "cada NPC debe tener un indice de spawn valido")

	_case = "estado inicial con clases NPC"
	var record: Dictionary = first["spawned"][0]
	var npc = record["npc"]
	_expect(npc.needs is NPCNeeds, "needs debe ser una instancia de NPCNeeds")
	_expect(npc.personality is NPCPersonality, "personality debe ser una instancia de NPCPersonality")
	_expect(npc.routine is NPCRoutine, "routine debe ser una instancia de NPCRoutine")
	_expect(npc.memory is NPCMemory, "memory debe ser una instancia de NPCMemory")
	_expect(npc.state_machine is NPCStateMachine, "state_machine debe ser una instancia de NPCStateMachine")
	_expect(npc.controller is NPCController, "controller debe ser una instancia de NPCController")
	_expect(npc.controller.needs == npc.needs, "el controller debe compartir needs")
	_expect(is_equal_approx(npc.needs.health, 1.0), "la salud inicial debe ser 1.0")
	_expect(is_equal_approx(npc.personality.bravery, 0.9), "la personalidad inicial debe aplicarse")
	_expect((npc.routine.stops as Array).size() == 1, "la rutina inicial debe conservar su parada")
	_expect(NPCStateMachine.VALID_STATES.has(str(record["state"])), "el estado inicial debe ser valido")

	_case = "limite por plataforma"
	var limited_map := {
		"id": "multi",
		"spawn_points": [Vector3(0, 0, 0), Vector3(1, 0, 1)],
		"platforms": ["android", "pc", "vr"],
		"performance_profiles": {
			"android": {"max_npcs": 2},
			"pc": {"max_npcs": 9},
			"vr": {"max_npcs": 4},
		},
	}
	_expect(spawner.get_platform_limit(limited_map, "android") == 2, "el limite de android debe respetar el perfil")
	_expect(spawner.get_platform_limit(limited_map, "pc") == 9, "el limite de pc debe respetar el perfil")
	_expect(spawner.get_platform_limit(limited_map, "vr") == 4, "el limite de vr debe respetar el perfil")
	_expect(spawner.get_platform_limit({}, "android") <= spawner.get_platform_limit({}, "pc"), \
		"el limite movil nunca debe superar el de escritorio")
	var limited: Dictionary = spawner.spawn(limited_map, _defs(6), 11)
	_expect((limited["spawned"] as Array).size() == 2, "el mapa multiplataforma debe limitarse a 2 en android")
	_expect((limited["rejected"] as Array).size() == 4, "el resto debe rechazarse por limite")
	_expect(_reasons_have(limited, "plataforma"), "el rechazo por limite debe mencionar la plataforma")
	var pc_map := _map(2)
	pc_map["platforms"] = ["pc"]
	var pc_result: Dictionary = spawner.spawn(pc_map, _defs(6), 11)
	_expect((pc_result["spawned"] as Array).size() == 6, "un mapa de pc no debe aplicar el limite movil")

	_case = "mapa sin spawn points"
	var empty_points: Dictionary = spawner.spawn({}, _defs(4), 9)
	_expect((empty_points["spawned"] as Array).is_empty(), "sin spawn_points no debe crear NPCs")
	_expect((empty_points["rejected"] as Array).size() == 4, "todas las definiciones deben rechazarse")
	_expect(_reasons_have(empty_points, "spawn"), "el motivo debe indicar que faltan spawn_points")
	var bad_points: Dictionary = spawner.spawn({"spawn_points": "invalido"}, _defs(2), 9)
	_expect((bad_points["spawned"] as Array).is_empty(), "spawn_points no Array debe tratar como mapa sin puntos")
	var null_points: Dictionary = spawner.spawn({"spawn_points": [null, 7, {"x": 1, "y": 0, "z": 2}]}, _defs(2), 9)
	_expect((null_points["spawned"] as Array).size() == 2, "los puntos validos deben aprovecharse")

	_case = "definicion invalida"
	var mixed: Array = [
		"no es un dictionary",
		{},
		{"id": ""},
		{"id": "x", "personality": "no es un dictionary"},
		{"id": "x", "needs": {"fatigue": "abc"}},
		{"id": "bueno"},
		{"id": "bueno"},
		{"id": "otro", "routine": [42]},
		{"id": "tercero", "state": "bogus"},
		{"id": "plataforma", "platform": "desconocida"},
	]
	var invalid: Dictionary = spawner.spawn(_map(2), mixed, 5)
	_expect((invalid["spawned"] as Array).size() == 1, "solo la definicion valida debe generar NPC")
	_expect((invalid["rejected"] as Array).size() == 9, "las definiciones invalidas deben rechazarse")
	_expect(_all_have_reason(invalid), "todo rechazo debe incluir reason y motivo")
	for entry in invalid["rejected"]:
		var rejection: Dictionary = entry
		_expect(not str(rejection["reason"]).is_empty(), "ningun rechazo puede tener motivo vacio")

	_case = "misma semilla igual resultado"
	var repeat_a: Dictionary = spawner.spawn(_map(4), _defs(8), 777)
	var repeat_b: Dictionary = spawner.spawn(_map(4), _defs(8), 777)
	_expect(str(repeat_a) == str(repeat_b), "la misma semilla debe producir el mismo resultado completo")
	var baseline := _assignment(repeat_a)
	var changed := false
	for seed in range(1, 25):
		if _assignment(spawner.spawn(_map(4), _defs(8), seed)) != baseline:
			changed = true
			break
	_expect(changed, "una semilla distinta debe cambiar el reparto")

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _map(points: int) -> Dictionary:
	var positions: Array = []
	for i in range(points):
		positions.append(Vector3(float(i), 0.0, float(i) * 0.5))
	return {
		"id": "mapa_prueba",
		"spawn_points": positions,
		"platforms": ["android", "pc", "vr"],
	}


func _defs(count: int) -> Array:
	var result: Array = []
	for i in range(count):
		result.append({
			"id": "npc_%02d" % i,
			"personality": {"bravery": 0.9, "curiosity": 0.2},
			"needs": {"health": 1.0, "fatigue": 0.1},
			"routine": [{"waypoint_id": "centro", "duration": 2.0}],
		})
	return result


func _assignment(report: Dictionary) -> Array:
	var result: Array = []
	for entry in report.get("spawned", []):
		var record: Dictionary = entry
		result.append("%s@%d" % [str(record["id"]), int(record["spawn_index"])])
	result.sort()
	return result


func _covers_all_points(report: Dictionary, expected: int) -> bool:
	var used := {}
	for entry in report.get("spawned", []):
		var record: Dictionary = entry
		used[int(record["spawn_index"])] = true
	return used.size() == mini(expected, (report["spawned"] as Array).size())


func _unique_points(report: Dictionary) -> bool:
	for entry in report.get("spawned", []):
		var record: Dictionary = entry
		var index := int(record["spawn_index"])
		if index < 0 or index >= 3:
			return false
	return true


func _reasons_have(report: Dictionary, needle: String) -> bool:
	for entry in report.get("rejected", []):
		var rejection: Dictionary = entry
		if not str(rejection["reason"]).contains(needle):
			return false
	return true


func _all_have_reason(report: Dictionary) -> bool:
	for entry in report.get("rejected", []):
		var rejection: Dictionary = entry
		if not rejection.has("reason") or not rejection.has("motivo"):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])
