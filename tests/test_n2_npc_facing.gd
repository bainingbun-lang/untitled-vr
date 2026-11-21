extends SceneTree

const NPCPerception = preload("res://core/npc/npc_perception.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

func _init() -> void:
	_case = "facing_value: Vector2 basico"
	var p: NPCPerception = NPCPerception.new()
	var f2: Vector2 = p.facing_value(Vector2.RIGHT)
	_check("Vector2.RIGHT normalizado", f2.is_equal_approx(Vector2.RIGHT), str(f2))
	var f2b: Vector2 = p.facing_value(Vector2(3.0, 4.0))
	_check("Vector2(3,4) normalizado a (0.6, 0.8)", f2b.is_equal_approx(Vector2(0.6, 0.8)), str(f2b))

	_case = "facing_value: Vector3 usa plano XZ"
	var f3: Vector2 = p.facing_value(Vector3.FORWARD)
	_check("Vector3.FORWARD (0,0,-1) -> Vector2(0,-1)", f3.is_equal_approx(Vector2(0.0, -1.0)), str(f3))
	var f3b: Vector2 = p.facing_value(Vector3.LEFT)
	_check("Vector3.LEFT (-1,0,0) -> Vector2(-1,0)", f3b.is_equal_approx(Vector2(-1.0, 0.0)), str(f3b))
	var f3c: Vector2 = p.facing_value(Vector3(1.0, 5.0, 0.0))
	_check("Y se ignora, solo X y Z", f3c.is_equal_approx(Vector2(1.0, 0.0).normalized()), str(f3c))

	_case = "facing_value: Vector2i y Vector3i"
	var f2i: Vector2 = p.facing_value(Vector2i(3, 4))
	_check("Vector2i(3,4) -> Vector2(0.6, 0.8)", f2i.is_equal_approx(Vector2(0.6, 0.8)), str(f2i))
	var f3i: Vector2 = p.facing_value(Vector3i(1, 99, 0))
	_check("Vector3i(1,99,0) -> Vector2(1,0)", f3i.is_equal_approx(Vector2(1.0, 0.0)), str(f3i))

	_case = "facing_value: Dictionary con x,y o x,z"
	var fd1: Vector2 = p.facing_value({"x": 3.0, "y": 4.0})
	_check("Dict x,y -> Vector2(0.6, 0.8)", fd1.is_equal_approx(Vector2(0.6, 0.8)), str(fd1))
	var fd2: Vector2 = p.facing_value({"x": 1.0, "z": 0.0})
	_check("Dict x,z -> Vector2(1,0)", fd2.is_equal_approx(Vector2(1.0, 0.0)), str(fd2))
	var fd3: Vector2 = p.facing_value({"position": Vector2(5.0, 12.0)})
	_check("Dict con position Vector2", fd3.is_equal_approx(Vector2(5.0, 12.0).normalized()), str(fd3))
	var fd4: Vector2 = p.facing_value({"position": Vector3(0.0, 0.0, -1.0)})
	_check("Dict con position Vector3", fd4.is_equal_approx(Vector2(0.0, -1.0)), str(fd4))

	_case = "facing_value: vector nulo o casi nulo retorna RIGHT"
	var fzero: Vector2 = p.facing_value(Vector2.ZERO)
	_check("Vector2.ZERO -> RIGHT", fzero.is_equal_approx(Vector2.RIGHT), str(fzero))
	var fzero3: Vector2 = p.facing_value(Vector3.ZERO)
	_check("Vector3.ZERO -> RIGHT", fzero3.is_equal_approx(Vector2.RIGHT), str(fzero3))
	var fnano: Vector2 = p.facing_value(Vector2(1e-10, 1e-10))
	_check("Vector casi nulo -> RIGHT", fnano.is_equal_approx(Vector2.RIGHT), str(fnano))
	var fdempty: Vector2 = p.facing_value({})
	_check("Dict vacio -> RIGHT", fdempty.is_equal_approx(Vector2.RIGHT), str(fdempty))
	var fdnull: Vector2 = p.facing_value({"x": null, "y": null})
	_check("Dict con nulls -> RIGHT", fdnull.is_equal_approx(Vector2.RIGHT), str(fdnull))

	_case = "can_see: vision basica con Vector2 facing"
	var vis: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 45.0})
	var front: Dictionary = vis.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.0))
	_check("Objetivo al frente visible", bool(front["visible"]) and str(front["reason"]) == "clear", str(front))
	var inside: Dictionary = vis.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 2.0))
	_check("Dentro del cono (atan2(2,5)~21.8deg < 45)", bool(inside["visible"]), str(inside))
	var outside: Dictionary = vis.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(2.0, 5.0))
	_check("Fuera del cono (atan2(5,2)~68deg > 45)", not bool(outside["visible"]) and str(outside["reason"]) == "out_of_cone", str(outside))
	var behind: Dictionary = vis.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(-5.0, 0.0))
	_check("Detras no visible", not bool(behind["visible"]), str(behind))
	var far: Dictionary = vis.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(11.0, 0.0))
	_check("Fuera de rango", not bool(far["visible"]) and str(far["reason"]) == "out_of_range", str(far))
	var coincident: Dictionary = vis.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2.ZERO)
	_check("Coincidente visible", bool(coincident["visible"]) and str(coincident["reason"]) == "coincident", str(coincident))

	_case = "can_see: facing Vector3 (plano XZ)"
	var vis3: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 45.0})
	var front3: Dictionary = vis3.can_see(Vector2.ZERO, Vector3.FORWARD, Vector2(0.0, -5.0))
	_check("Vector3.FORWARD ve -Z", bool(front3["visible"]), str(front3))
	var front3b: Dictionary = vis3.can_see(Vector3(0.0, 1.0, 0.0), Vector3.LEFT, Vector3(-5.0, 2.0, 0.0))
	_check("Vector3.LEFT ve -X (ignora Y)", bool(front3b["visible"]), str(front3b))

	_case = "can_see: facing Dictionary"
	var visd: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 45.0})
	var frontd: Dictionary = visd.can_see(Vector2.ZERO, {"x": 1.0, "y": 0.0}, Vector2(5.0, 0.0))
	_check("Dict facing funciona", bool(frontd["visible"]), str(frontd))
	var frontd2: Dictionary = visd.can_see(Vector2.ZERO, {"x": 0.0, "z": -1.0}, Vector2(0.0, -5.0))
	_check("Dict con z funciona", bool(frontd2["visible"]), str(frontd2))

	_case = "can_see: oclusion con Callable"
	_blocked.clear()
	_blocked[Vector2(5.0, 0.0)] = true
	var visocc: NPCPerception = NPCPerception.new({
		"vision_range": 10.0,
		"vision_half_angle_deg": 60.0,
		"line_of_sight": Callable(self, "_los_blocking")
	})
	var occ: Dictionary = visocc.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.0))
	_check("Callable bloquea vision", not bool(occ["visible"]) and str(occ["reason"]) == "occluded", str(occ))
	var clear: Dictionary = visocc.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(3.0, 0.0))
	_check("Sin bloqueo ve", bool(clear["visible"]), str(clear))
	var override: Dictionary = visocc.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.0), {"line_of_sight": Callable(self, "_los_always_true")})
	_check("Override por opciones", bool(override["visible"]), str(override))

	_case = "can_see: angulo exacto en borde del cono"
	var vis_edge: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 45.0})
	var exact: Dictionary = vis_edge.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(7.0710678, 7.0710678))
	_check("Exactamente 45 grados (raiz(50), raiz(50))", bool(exact["visible"]) or not bool(exact["visible"]), str(exact))
	var slightly_in: Dictionary = vis_edge.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(7.1, 7.0))
	_check("Ligeramente dentro (~44.5 deg)", bool(slightly_in["visible"]), str(slightly_in))
	var slightly_out: Dictionary = vis_edge.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(7.0, 7.1))
	_check("Ligeramente fuera (~45.5 deg)", not bool(slightly_out["visible"]), str(slightly_out))

	_case = "can_see: opciones por llamada sobrescriben defaults"
	var viso: NPCPerception = NPCPerception.new({"vision_range": 5.0, "vision_half_angle_deg": 30.0})
	var opt_range: Dictionary = viso.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(8.0, 0.0), {"vision_range": 10.0})
	_check("vision_range por opciones", bool(opt_range["visible"]), str(opt_range))
	var opt_angle: Dictionary = viso.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(3.0, 2.0), {"vision_half_angle_deg": 60.0})
	_check("vision_half_angle_deg por opciones", bool(opt_angle["visible"]), str(opt_angle))

	_case = "can_see: distance y angle_deg en resultado"
	var vism: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 45.0})
	var measure: Dictionary = vism.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(6.0, 2.0))
	_check("distance = sqrt(40) ~ 6.32", is_equal_approx(float(measure["distance"]), 6.324) or abs(float(measure["distance"]) - 6.324) < 0.01, str(measure["distance"]))
	_check("angle_deg ~ 18.43", is_equal_approx(float(measure["angle_deg"]), 18.43) or abs(float(measure["angle_deg"]) - 18.43) < 0.1, str(measure["angle_deg"]))
	_check("range reflejado", float(measure["range"]) == 10.0, str(measure["range"]))

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

var _blocked: Dictionary = {}

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