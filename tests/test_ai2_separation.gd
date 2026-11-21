extends SceneTree

const ArmedNpcScript = preload("res://core/game/armed_npc.gd")
const NavigationScript = preload("res://core/npc/npc_navigation.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

func _init() -> void:
	_case = "separacion basica entre dos NPCs"
	var nav = NavigationScript.new(10, 10)
	var npc_a = ArmedNpcScript.new()
	var npc_b = ArmedNpcScript.new()
	
	npc_a.global_position = Vector3(0, 0, 0)
	npc_b.global_position = Vector3(0.5, 0, 0)
	
	var separation_a = _calculate_separation(npc_a, [npc_b])
	var separation_b = _calculate_separation(npc_b, [npc_a])
	
	_check("separacion empuja en direccion opuesta A", separation_a.x < 0, "separation_a: %s" % str(separation_a))
	_check("separacion empuja en direccion opuesta B", separation_b.x > 0, "separation_b: %s" % str(separation_b))
	_check("magnitud razonable", separation_a.length() > 0.1 and separation_a.length() < 2.0, "magnitud: %s" % str(separation_a.length()))
	
	_case = "sin separacion cuando lejos"
	npc_a.global_position = Vector3(0, 0, 0)
	npc_b.global_position = Vector3(3.0, 0, 0)
	separation_a = _calculate_separation(npc_a, [npc_b])
	_check("sin fuerza de separacion a distancia > 1.4", separation_a.length() < 0.001, "separation: %s" % str(separation_a))
	
	_case = "multiples vecinos"
	var npcs: Array = []
	for i in range(5):
		var npc = ArmedNpcScript.new()
		npc.global_position = Vector3(0, 0, i * 0.3)
		npcs.append(npc)
	
	var center = npcs[2]
	var others = npcs.duplicate()
	others.remove_at(2)
	var total_separation = _calculate_separation(center, others)
	_check("separacion con multiples vecinos no es cero", total_separation.length() > 0.001, "total: %s" % str(total_separation))
	
	_finish()

func _calculate_separation(self_npc: Node3D, others: Array) -> Vector3:
	var avoidance: Vector3 = Vector3.ZERO
	for other in others:
		if other == self_npc or not is_instance_valid(other):
			continue
		var separation: Vector3 = self_npc.global_position - other.global_position
		separation.y = 0.0
		var distance: float = separation.length()
		if distance > 0.001 and distance < 1.4:
			avoidance += (separation / distance) * ((1.4 - distance) / 1.4)
	return avoidance

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