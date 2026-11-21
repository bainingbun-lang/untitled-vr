extends SceneTree

const NPCPerception = preload("res://core/npc/npc_perception.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

func _init() -> void:
	_case = "Regression: facing_value con Vector3 no crashea y usa XZ"
	var p: NPCPerception = NPCPerception.new()
	var f: Vector2 = p.facing_value(Vector3(1.0, 2.0, 3.0))
	_check("Vector3(1,2,3) -> Vector2(1,3) normalizado", f.is_equal_approx(Vector2(1.0, 3.0).normalized()), str(f))

	_case = "Regression: can_see con Vector3 position y target"
	var v3: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 45.0})
	var r3: Dictionary = v3.can_see(Vector3(0.0, 1.0, 0.0), Vector3.FORWARD, Vector3(0.0, 2.0, -5.0))
	_check("Vector3 position/target usa XZ", bool(r3["visible"]), str(r3))

	_case = "Regression: facing_value Vector2 casi cero no divide por cero"
	var fzero: Vector2 = p.facing_value(Vector2(1e-20, 1e-20))
	_check("Vector casi cero -> RIGHT sin crash", fzero.is_equal_approx(Vector2.RIGHT), str(fzero))

	_case = "Regression: can_see distance == range borde inclusive"
	var vr: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 45.0})
	var at_range: Dictionary = vr.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(10.0, 0.0))
	_check("Distancia == range visible", bool(at_range["visible"]), str(at_range))

	_case = "Regression: can_see angle == half_angle borde inclusive"
	var va: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 45.0})
	var at_angle: Dictionary = va.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(7.0710678118654755, 7.0710678118654755))
	_check("Angulo == half_angle (45 deg) visible", bool(at_angle["visible"]), str(at_angle))

	_case = "Regression: perceive con stimuli vacio no crashea"
	var pe: NPCPerception = NPCPerception.new()
	var empty_res: Dictionary = pe.perceive([], Vector2.ZERO, Vector2.RIGHT)
	_check("Stimuli vacio -> count 0, relevant 0", int(empty_res["count"]) == 0 and int(empty_res["relevant"]) == 0, str(empty_res))

	_case = "Regression: perceive con stimuli no-Dictionary los ignora"
	var pbad: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 180.0})
	var mixed: Array = [{"id": "good", "position": Vector2(1.0, 0.0)}, "not_a_dict", 42, null, {"id": "also_good", "position": Vector2(2.0, 0.0)}]
	var mixed_res: Dictionary = pbad.perceive(mixed, Vector2.ZERO, Vector2.RIGHT)
	_check("Solo 2 validos procesados", int(mixed_res["count"]) == 2 and int(mixed_res["relevant"]) == 2, str([mixed_res["count"], mixed_res["relevant"]]))

	_case = "Regression: evaluate_stimulus sin position usa ZERO"
	var ev: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 180.0})
	var no_pos: Dictionary = ev.evaluate_stimulus({"id": "nopos", "priority": 0.5}, Vector2.ZERO, Vector2.RIGHT)
	_check("Sin position -> distance 0, visible", float(no_pos["distance"]) == 0.0 and bool(no_pos["visible"]), str(no_pos))

	_case = "Regression: evaluate_stimulus kind/type case insensitive"
	var ek: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 180.0})
	var k1: Dictionary = ek.evaluate_stimulus({"id": "k1", "kind": "ATTACK", "position": Vector2(1.0, 0.0)}, Vector2.ZERO, Vector2.RIGHT)
	var k2: Dictionary = ek.evaluate_stimulus({"id": "k2", "type": "attack", "position": Vector2(1.0, 0.0)}, Vector2.ZERO, Vector2.RIGHT)
	_check("kind mayuscula -> lower", str(k1["kind"]) == "attack", str(k1["kind"]))
	_check("type minuscula -> lower", str(k2["type"]) == "attack", str(k2["type"]))

	_case = "Regression: evaluate_stimulus channel/sense fallback"
	var ec: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 180.0, "hearing_range": 10.0})
	var c1: Dictionary = ec.evaluate_stimulus({"id": "c1", "channel": "VISION", "position": Vector2(1.0, 0.0)}, Vector2.ZERO, Vector2.RIGHT)
	var c2: Dictionary = ec.evaluate_stimulus({"id": "c2", "sense": "HEARING", "position": Vector2(-1.0, 0.0), "noise": 0.5}, Vector2.ZERO, Vector2.RIGHT)
	_check("channel VISION -> vision", str(c1["channel"]) == "vision", str(c1["channel"]))
	_check("sense HEARING -> hearing", str(c2["channel"]) == "hearing", str(c2["channel"]))

	_case = "Regression: can_hear loudness <= 0 silent"
	var hl: NPCPerception = NPCPerception.new({"hearing_range": 10.0})
	var h0: Dictionary = hl.can_hear({"position": Vector2(1.0, 0.0), "noise": 0.0}, Vector2.ZERO)
	var hneg: Dictionary = hl.can_hear({"position": Vector2(1.0, 0.0), "noise": -0.5}, Vector2.ZERO)
	_check("noise 0 -> silent", not bool(h0["heard"]) and str(h0["reason"]) == "silent", str(h0))
	_check("noise negativo -> silent", not bool(hneg["heard"]) and str(hneg["reason"]) == "silent", str(hneg))

	_case = "Regression: can_hear radius <= 0 silent"
	var hr: NPCPerception = NPCPerception.new({"hearing_range": 10.0})
	var r0: Dictionary = hr.can_hear({"position": Vector2(1.0, 0.0), "noise": 1.0, "radius": 0.0}, Vector2.ZERO)
	var rneg: Dictionary = hr.can_hear({"position": Vector2(1.0, 0.0), "noise": 1.0, "radius": -5.0}, Vector2.ZERO)
	_check("radius 0 -> silent", not bool(r0["heard"]) and str(r0["reason"]) == "silent", str(r0))
	_check("radius negativo -> silent", not bool(rneg["heard"]) and str(rneg["reason"]) == "silent", str(rneg))

	_case = "Regression: _has_line_of_sight callback con 1 argumento"
	var los1: Dictionary = {Vector2(5.0, 0.0): false}
	var vlos1: NPCPerception = NPCPerception.new({
		"vision_range": 10.0,
		"vision_half_angle_deg": 60.0,
		"line_of_sight": Callable(self, "_los_one_arg")
	})
	var one_arg: Dictionary = vlos1.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.0))
	_check("Callable 1 arg funciona", not bool(one_arg["visible"]), str(one_arg))

	_case = "Regression: _has_line_of_sight callback sin argumentos"
	var vlos0: NPCPerception = NPCPerception.new({
		"vision_range": 10.0,
		"vision_half_angle_deg": 60.0,
		"line_of_sight": Callable(self, "_los_no_args")
	})
	var no_args: Dictionary = vlos0.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.0))
	_check("Callable 0 args funciona", bool(no_args["visible"]), str(no_args))

	_case = "Regression: configure con line_of_sight null no crashea"
	var vcfg: NPCPerception = NPCPerception.new({"vision_range": 10.0, "line_of_sight": Callable(self, "_los_always_true")})
	vcfg.configure({"line_of_sight": null})
	var cfg_null: Dictionary = vcfg.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.0))
	_check("line_of_sight null -> default true", bool(cfg_null["visible"]), str(cfg_null))

	_case = "Regression: write_to_memory sin memory.has_method add_event"
	var NPCMemory = preload("res://core/npc/npc_memory.gd")
	var pmem: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 180.0})
	var write_r: Dictionary = pmem.perceive([{"id": "wm1", "position": Vector2(1.0, 0.0)}], Vector2.ZERO, Vector2.RIGHT)
	_check("Objeto sin add_event -> 0", pmem.write_to_memory({}, write_r) == 0, "")
	_check("Objeto con add_event null -> 0", pmem.write_to_memory({"add_event": null}, write_r) == 0, "")

	_case = "Regression: noise_value Dict anidado intensity"
	var nv: NPCPerception = NPCPerception.new()
	var nested_int: float = nv.noise_value({"noise": {"intensity": 0.75}})
	_check("noise.intensity -> 0.75", is_equal_approx(nested_int, 0.75), str(nested_int))

	_case = "Regression: max_stimuli_per_tick = 0 descarta todo"
	var pzero: NPCPerception = NPCPerception.new({"max_stimuli_per_tick": 0})
	var zero_res: Dictionary = pzero.perceive([{"id": "z1", "position": Vector2(1.0, 0.0)}], Vector2.ZERO, Vector2.RIGHT)
	_check("Limit 0 -> count 0", int(zero_res["count"]) == 0, str(zero_res["count"]))

	_case = "Regression: vision_half_angle_deg clamp 0-180 en configure"
	var vclamp: NPCPerception = NPCPerception.new({"vision_half_angle_deg": 45.0})
	vclamp.configure({"vision_half_angle_deg": -10.0})
	var c_neg: Dictionary = vclamp.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(0.0, 5.0))
	_check("Negativo clamp a 0 -> solo frente", not bool(c_neg["visible"]), str(c_neg))
	vclamp.configure({"vision_half_angle_deg": 200.0})
	var c_big: Dictionary = vclamp.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(-5.0, 0.0))
	_check(">180 clamp a 180 -> todo visible", bool(c_big["visible"]), str(c_big))

	_case = "Regression: vision_range y hearing_range clamp >= 0"
	var vrclamp: NPCPerception = NPCPerception.new({"vision_range": 10.0})
	vrclamp.configure({"vision_range": -5.0})
	var vrneg: Dictionary = vrclamp.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(1.0, 0.0))
	_check("vision_range negativo -> 0, solo coincidente", not bool(vrneg["visible"]), str(vrneg))

	_case = "Regression: perceive orden determinista con mismos datos"
	var pdet: NPCPerception = NPCPerception.new({"vision_range": 20.0, "vision_half_angle_deg": 180.0, "max_stimuli_per_tick": 10})
	var stim_order1: Array = [{"id": "b", "position": Vector2(1.0, 0.0), "priority": 0.5}, {"id": "a", "position": Vector2(1.0, 0.0), "priority": 0.5}]
	var stim_order2: Array = [{"id": "a", "position": Vector2(1.0, 0.0), "priority": 0.5}, {"id": "b", "position": Vector2(1.0, 0.0), "priority": 0.5}]
	var o1: Array = []
	var o2: Array = []
	for item in pdet.perceive(stim_order1, Vector2.ZERO, Vector2.RIGHT)["stimuli"]:
		o1.append(str(item["id"]))
	for item in pdet.perceive(stim_order2, Vector2.ZERO, Vector2.RIGHT)["stimuli"]:
		o2.append(str(item["id"]))
	_check("Mismo resultado orden diferente entrada", o1 == o2, str([o1, o2]))

	_case = "Regression: TIE_EPSILON evita division por cero en angle_to"
	var pte: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 45.0})
	var eps: Dictionary = pte.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(1e-10, 1e-10))
	_check("Target casi en origen -> coincident", bool(eps["visible"]) and str(eps["reason"]) == "coincident", str(eps))

	_finish()

func _los_blocking(from: Variant, to: Variant) -> bool:
	return true

func _los_always_true(from: Variant, to: Variant) -> bool:
	return true

func _los_one_arg(target: Variant) -> bool:
	return true

func _los_no_args() -> bool:
	return true

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