extends SceneTree

const NPCPerception = preload("res://core/npc/npc_perception.gd")
const NPCMemory = preload("res://core/npc/npc_memory.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""
var _blocked: Dictionary = {}


func _init() -> void:
	_case = "vision: dentro y fuera de cono"
	var p: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 30.0})
	var front: Dictionary = p.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.0))
	_check("objetivo al frente visible", bool(front["visible"]) and str(front["reason"]) == "clear", str(front))
	var inside: Dictionary = p.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 2.0))
	_check("objetivo dentro del cono visible", bool(inside["visible"]), str(inside))
	var outside: Dictionary = p.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(2.0, 5.0))
	_check("objetivo fuera del cono no visible", not bool(outside["visible"]) and str(outside["reason"]) == "out_of_cone", str(outside))
	var behind: Dictionary = p.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(-5.0, 0.0))
	_check("objetivo detras no visible", not bool(behind["visible"]), str(behind))
	var far: Dictionary = p.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(11.0, 0.0))
	_check("objetivo fuera de distancia no visible", not bool(far["visible"]) and str(far["reason"]) == "out_of_range", str(far))
	var edge: Dictionary = p.can_see(Vector2.ZERO, Vector2.RIGHT, Vector3(5.0, 0.0, 2.7))
	_check("3D usa plano XZ para el cono", bool(edge["visible"]), str(edge))
	var back_facing: Dictionary = p.can_see(Vector2.ZERO, Vector3(0.0, 0.0, 1.0), Vector2(0.0, 5.0))
	_check("facing 3D (x,z) funciona", bool(back_facing["visible"]), str(back_facing))

	_case = "oclusion por Callable inyectable"
	_blocked.clear()
	_blocked[Vector2(5.0, 0.0)] = true
	var blocked_p: NPCPerception = NPCPerception.new({
		"vision_range": 10.0,
		"vision_half_angle_deg": 60.0,
		"line_of_sight": Callable(self, "_los_blocking"),
	})
	var occluded: Dictionary = blocked_p.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.0))
	_check("linea de vista bloqueada oculta objetivo", not bool(occluded["visible"]) and str(occluded["reason"]) == "occluded", str(occluded))
	var clear_target: Dictionary = blocked_p.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(3.0, 0.0))
	_check("linea despejada permite ver", bool(clear_target["visible"]), str(clear_target))
	var override: Dictionary = blocked_p.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.0), {"line_of_sight": Callable(self, "_los_always_true")})
	_check("Callable por llamada sobreescribe la global", bool(override["visible"]), str(override))
	blocked_p.set_line_of_sight(Callable(self, "_los_always_true"))
	_check("set_line_of_sight reemplaza la funcion", bool(blocked_p.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.0))["visible"]), "")
	blocked_p.configure({"line_of_sight": Callable(self, "_los_blocking")})
	_check("configure reemplaza la funcion", not bool(blocked_p.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.0))["visible"]), "")

	_case = "oido: ruido cercano y lejano"
	var hear: NPCPerception = NPCPerception.new({"hearing_range": 10.0})
	var near: Dictionary = hear.can_hear({"position": Vector2(2.0, 0.0), "noise": 0.8}, Vector2.ZERO)
	_check("ruido cercano se oye", bool(near["heard"]) and float(near["intensity"]) > 0.0, str(near))
	_check("atenuacion cercana correcta", is_equal_approx(float(near["intensity"]), 0.64), str(near["intensity"]))
	var far_noise: Dictionary = hear.can_hear({"position": Vector2(11.0, 0.0), "noise": 1.0}, Vector2.ZERO)
	_check("ruido fuera de radio no se oye", not bool(far_noise["heard"]) and str(far_noise["reason"]) == "out_of_range", str(far_noise))
	var silent: Dictionary = hear.can_hear({"position": Vector2(1.0, 0.0), "noise": 0.0}, Vector2.ZERO)
	_check("ruido nulo no se oye", not bool(silent["heard"]), str(silent))
	var radius_noise: Dictionary = hear.can_hear({"position": Vector2(4.0, 0.0), "loudness": 0.5, "radius": 5.0}, Vector2.ZERO)
	_check("radio por estimulo se respeta", bool(radius_noise["heard"]) and is_equal_approx(float(radius_noise["intensity"]), 0.1), str(radius_noise))
	var heard_behind: Dictionary = hear.evaluate_stimulus({"id": "paso", "channel": "hearing", "position": Vector2(-3.0, 0.0), "noise": 0.9}, Vector2.ZERO, Vector2.RIGHT)
	_check("oido no depende del cono de vision", bool(heard_behind["heard"]) and str(heard_behind["channel"]) == "hearing", str(heard_behind))

	_case = "orden determinista y limite por tick"
	var limited: NPCPerception = NPCPerception.new({"vision_range": 20.0, "vision_half_angle_deg": 180.0, "max_stimuli_per_tick": 3})
	var stimuli: Array = [
		{"id": "bajo", "position": Vector2(1.0, 0.0), "priority": 0.2, "kind": "item"},
		{"id": "alto", "position": Vector2(1.0, 0.0), "priority": 0.9, "kind": "attack"},
		{"id": "medio", "position": Vector2(1.0, 0.0), "priority": 0.5, "kind": "noise"},
		{"id": "extra", "position": Vector2(1.0, 0.0), "priority": 0.4, "kind": "item"},
	]
	var result: Dictionary = limited.perceive(stimuli, Vector2.ZERO, Vector2.RIGHT)
	var ids: Array = []
	for item in result["stimuli"]:
		ids.append(str(item["id"]))
	_check("respeta limite por tick", int(result["count"]) == 3 and ids.size() == 3, str(ids))
	_check("prioriza mayor prioridad", ids[0] == "alto" and ids[1] == "medio", str(ids))
	_check("descarta excedentes", int(result["dropped"]) == 1 and int(result["relevant"]) == 4, str(result))
	var order_a: Array = []
	var order_b: Array = []
	var p_a: NPCPerception = NPCPerception.new({"vision_range": 20.0, "vision_half_angle_deg": 180.0, "max_stimuli_per_tick": 10})
	var p_b: NPCPerception = NPCPerception.new({"vision_range": 20.0, "vision_half_angle_deg": 180.0, "max_stimuli_per_tick": 10})
	var shuffled: Array = [stimuli[0], stimuli[3], stimuli[2], stimuli[1]]
	for item in p_a.perceive(stimuli, Vector2.ZERO, Vector2.RIGHT)["stimuli"]:
		order_a.append(str(item["id"]))
	for item in p_b.perceive(shuffled, Vector2.ZERO, Vector2.RIGHT)["stimuli"]:
		order_b.append(str(item["id"]))
	_check("determinismo ante distinto orden de entrada", order_a == order_b, str([order_a, order_b]))
	var tie: NPCPerception = NPCPerception.new({"vision_range": 20.0, "vision_half_angle_deg": 180.0})
	var tie_result: Dictionary = tie.perceive([
		{"id": "zeta", "position": Vector2(1.0, 0.0), "priority": 0.5},
		{"id": "alfa", "position": Vector2(1.0, 0.0), "priority": 0.5},
	], Vector2.ZERO, Vector2.RIGHT)
	var tie_ids: Array = []
	for item in tie_result["stimuli"]:
		tie_ids.append(str(item["id"]))
	_check("desempate estable por id", tie_ids[0] == "alfa" and tie_ids[1] == "zeta", str(tie_ids))
	var tick_1: int = int(result["tick"])
	var tick_2: int = int(limited.perceive([], Vector2.ZERO, Vector2.RIGHT)["tick"])
	_check("tick avanza una vez por percepcion", tick_2 == tick_1 + 1, str([tick_1, tick_2]))
	var zero_limit: NPCPerception = NPCPerception.new({"max_stimuli_per_tick": 0})
	_check("limite cero no produce estimulos", int(zero_limit.perceive(stimuli, Vector2.ZERO, Vector2.RIGHT)["count"]) == 0, "")

	_case = "escritura en memoria"
	var memory: NPCMemory = NPCMemory.new(4)
	var write_result: Dictionary = limited.perceive(stimuli, Vector2.ZERO, Vector2.RIGHT)
	var written: int = limited.write_to_memory(memory, write_result)
	_check("adaptador escribe solo relevantes", written == 3 and memory.get_events().size() == 3, str(memory.get_events().size()))
	var first_event: Dictionary = memory.get_events()[0]
	_check("evento compatible con NPCMemory/NPCBehavior", str(first_event["type"]) == "attack" and float(first_event["severity"]) > 0.0, str(first_event))
	_check("evento conserva source y tick", str(first_event["source_id"]) == "alto" and int(first_event["tick"]) == int(write_result["tick"]), str(first_event))
	_check("adaptador sin memoria es seguro", limited.write_to_memory(null, write_result) == 0, "")
	var danger_memory: NPCMemory = NPCMemory.new(8)
	danger_memory.add_event(first_event)
	_check("evento de ataque legible como peligro", str(danger_memory.get_events()[0]["type"]).contains("attack"), str(danger_memory.get_events()[0]))

	_finish()


func _los_blocking(from: Variant, to: Variant) -> bool:
	return not _blocked.has(_key(to))


func _los_always_true(from: Variant, to: Variant) -> bool:
	return true


func _key(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector3:
		var vector: Vector3 = value
		return Vector2(vector.x, vector.z)
	return Vector2.ZERO


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
