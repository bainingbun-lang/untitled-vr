extends SceneTree

const NPCPerception = preload("res://core/npc/npc_perception.gd")
const NPCMemory = preload("res://core/npc/npc_memory.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

func _approx(a: float, b: float, eps: float = 0.001) -> bool:
	return abs(a - b) < eps

func _approx_v2(a: Vector2, b: Vector2, eps: float = 0.001) -> bool:
	return abs(a.x - b.x) < eps and abs(a.y - b.y) < eps

func _init() -> void:
	_case = "facing_value: valores extremos y edge cases"
	var p: NPCPerception = NPCPerception.new()
	var finf: Vector2 = p.facing_value(Vector2(INF, INF))
	_check("INF,INF -> (0,0) (Godot normalize INF falla)", finf.is_equal_approx(Vector2.ZERO), str(finf))
	var fninf: Vector2 = p.facing_value(Vector2(-INF, INF))
	_check("-INF,INF -> (0,0) (Godot normalize INF falla)", fninf.is_equal_approx(Vector2.ZERO), str(fninf))
	var fnan: Vector2 = p.facing_value(Vector2(NAN, 1.0))
	_check("NAN -> (0,0) (Godot normalize NaN falla)", fnan.is_equal_approx(Vector2.ZERO), str(fnan))
	var fneg: Vector2 = p.facing_value(Vector2(-0.0, -0.0))
	_check("-0.0, -0.0 -> RIGHT", fneg.is_equal_approx(Vector2.RIGHT), str(fneg))

	_case = "facing_value: tipos invalidos caen a RIGHT"
	var finv1: Vector2 = p.facing_value("string")
	_check("String -> RIGHT", finv1.is_equal_approx(Vector2.RIGHT), str(finv1))
	var finv2: Vector2 = p.facing_value(42)
	_check("Int -> RIGHT", finv2.is_equal_approx(Vector2.RIGHT), str(finv2))
	var finv3: Vector2 = p.facing_value([])
	_check("Array -> RIGHT", finv3.is_equal_approx(Vector2.RIGHT), str(finv3))

	_case = "can_see: vision_range = 0"
	var v0: NPCPerception = NPCPerception.new({"vision_range": 0.0, "vision_half_angle_deg": 45.0})
	var at_zero: Dictionary = v0.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2.ZERO)
	_check("Coincidente con range 0 visible", bool(at_zero["visible"]) and str(at_zero["reason"]) == "coincident", str(at_zero))
	var near_zero: Dictionary = v0.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(0.001, 0.0))
	_check("Cercano con range 0 no visible", not bool(near_zero["visible"]) and str(near_zero["reason"]) == "out_of_range", str(near_zero))

	_case = "can_see: vision_half_angle_deg = 0 (solo frente exacto)"
	var v0a: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 0.0})
	var exact_front: Dictionary = v0a.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.0))
	_check("Exactamente al frente visible", bool(exact_front["visible"]), str(exact_front))
	var slight_off: Dictionary = v0a.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.001))
	_check("Ligeramente fuera no visible", not bool(slight_off["visible"]), str(slight_off))

	_case = "can_see: vision_half_angle_deg = 180 (vision completa)"
	var v180: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 180.0})
	var behind180: Dictionary = v180.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(-5.0, 0.0))
	_check("Detras visible con 180 deg", bool(behind180["visible"]), str(behind180))
	var side180: Dictionary = v180.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(0.0, 5.0))
	_check("Lado visible con 180 deg", bool(side180["visible"]), str(side180))

	_case = "can_see: configure actualiza parametros en vivo"
	var vc: NPCPerception = NPCPerception.new({"vision_range": 5.0, "vision_half_angle_deg": 30.0})
	var before: Dictionary = vc.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(8.0, 0.0))
	_check("Antes: fuera de rango", not bool(before["visible"]), str(before))
	vc.configure({"vision_range": 10.0})
	var after: Dictionary = vc.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(8.0, 0.0))
	_check("Despues configure: visible", bool(after["visible"]), str(after))
	vc.configure({"vision_half_angle_deg": 10.0})
	var narrow: Dictionary = vc.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 2.0))
	_check("Cono estrecho: fuera", not bool(narrow["visible"]), str(narrow))

	_case = "can_see: set_line_of_sight reemplaza callback"
	_blocked.clear()
	_blocked[Vector2(5.0, 0.0)] = true
	var vlos: NPCPerception = NPCPerception.new({
		"vision_range": 10.0,
		"vision_half_angle_deg": 60.0,
		"line_of_sight": Callable(self, "_los_blocking")
	})
	var occ1: Dictionary = vlos.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.0))
	_check("Con bloqueo inicial", not bool(occ1["visible"]), str(occ1))
	vlos.set_line_of_sight(Callable(self, "_los_always_true"))
	var occ2: Dictionary = vlos.can_see(Vector2.ZERO, Vector2.RIGHT, Vector2(5.0, 0.0))
	_check("Despues set_line_of_sight always_true", bool(occ2["visible"]), str(occ2))

	_case = "can_see: hearing_range = 0"
	var h0: NPCPerception = NPCPerception.new({"hearing_range": 0.0})
	var hear_zero: Dictionary = h0.can_hear({"position": Vector2.ZERO, "noise": 1.0}, Vector2.ZERO)
	_check("Con range 0, radius=0 -> silent", not bool(hear_zero["heard"]) and str(hear_zero["reason"]) == "silent", str(hear_zero))
	var hear_near: Dictionary = h0.can_hear({"position": Vector2(0.1, 0.0), "noise": 1.0}, Vector2.ZERO)
	_check("Cercano con range 0 no oido", not bool(hear_near["heard"]), str(hear_near))
	var hear_explicit: Dictionary = h0.can_hear({"position": Vector2.ZERO, "noise": 1.0, "radius": 5.0}, Vector2.ZERO)
	_check("Radius explicito > 0 se oye", bool(hear_explicit["heard"]), str(hear_explicit))

	_case = "can_hear: loudness y radius del estimulo"
	var h: NPCPerception = NPCPerception.new({"hearing_range": 10.0})
	var stim_loud: Dictionary = h.can_hear({"position": Vector2(5.0, 0.0), "noise": 1.0, "radius": 10.0}, Vector2.ZERO)
	_check("loudness=1, radius=10, dist=5 -> intensity=0.5", _approx(float(stim_loud["intensity"]), 0.5), str(stim_loud["intensity"]))
	var stim_quiet: Dictionary = h.can_hear({"position": Vector2(5.0, 0.0), "noise": 0.5, "radius": 10.0}, Vector2.ZERO)
	_check("loudness=0.5, radius=10, dist=5 -> intensity=0.25", _approx(float(stim_quiet["intensity"]), 0.25), str(stim_quiet["intensity"]))
	var stim_edge: Dictionary = h.can_hear({"position": Vector2(10.0, 0.0), "noise": 1.0, "radius": 10.0}, Vector2.ZERO)
	_check("En borde radius (dist=10) -> intensity=0", _approx(float(stim_edge["intensity"]), 0.0), str(stim_edge["intensity"]))

	_case = "evaluate_stimulus: canal vision vs hearing"
	var ev: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 45.0, "hearing_range": 10.0})
	var vis_stim: Dictionary = ev.evaluate_stimulus({"id": "v1", "channel": "vision", "position": Vector2(5.0, 0.0), "priority": 0.8}, Vector2.ZERO, Vector2.RIGHT)
	_check("Stimulus vision canal vision", bool(vis_stim["visible"]) and str(vis_stim["channel"]) == "vision", str(vis_stim))
	var hear_stim: Dictionary = ev.evaluate_stimulus({"id": "h1", "channel": "hearing", "position": Vector2(-5.0, 0.0), "noise": 0.8}, Vector2.ZERO, Vector2.RIGHT)
	_check("Stimulus hearing canal hearing", bool(hear_stim["heard"]) and str(hear_stim["channel"]) == "hearing", str(hear_stim))
	var auto_vis: Dictionary = ev.evaluate_stimulus({"id": "a1", "position": Vector2(5.0, 0.0), "priority": 0.8}, Vector2.ZERO, Vector2.RIGHT)
	_check("Sin canal: auto vision si visible", bool(auto_vis["visible"]) and str(auto_vis["channel"]) == "vision", str(auto_vis))
	var auto_hear: Dictionary = ev.evaluate_stimulus({"id": "a2", "position": Vector2(-5.0, 0.0), "noise": 0.8}, Vector2.ZERO, Vector2.RIGHT)
	_check("Sin canal: auto hearing si ruido", bool(auto_hear["heard"]) and str(auto_hear["channel"]) == "hearing", str(auto_hear))

	_case = "evaluate_stimulus: explicitly_visible fuerza vision"
	var ev2: NPCPerception = NPCPerception.new({"vision_range": 10.0, "vision_half_angle_deg": 10.0})
	var forced: Dictionary = ev2.evaluate_stimulus({"id": "f1", "channel": "vision", "position": Vector2(5.0, 5.0), "priority": 0.8, "visible": true}, Vector2.ZERO, Vector2.RIGHT)
	_check("visible=true fuerza visible aunque fuera de cono", bool(forced["visible"]) and str(forced["channel"]) == "vision", str(forced))

	_case = "perceive: max_stimuli_per_tick limite"
	var pl: NPCPerception = NPCPerception.new({"vision_range": 20.0, "vision_half_angle_deg": 180.0, "max_stimuli_per_tick": 2})
	var many: Array = []
	for i in range(5):
		many.append({"id": "s%d" % i, "position": Vector2(float(i), 0.0), "priority": 0.5})
	var res: Dictionary = pl.perceive(many, Vector2.ZERO, Vector2.RIGHT)
	_check("Limite 2 respeta", int(res["count"]) == 2 and int(res["dropped"]) == 3, str([res["count"], res["dropped"]]))

	_case = "perceive: prioridad intensidad desempate id"
	var pp: NPCPerception = NPCPerception.new({"vision_range": 20.0, "vision_half_angle_deg": 180.0, "max_stimuli_per_tick": 10})
	var tie_stim: Array = [
		{"id": "zeta", "position": Vector2(1.0, 0.0), "priority": 0.5},
		{"id": "alfa", "position": Vector2(1.0, 0.0), "priority": 0.5},
	]
	var tie_res: Dictionary = pp.perceive(tie_stim, Vector2.ZERO, Vector2.RIGHT)
	var ids: Array = []
	for item in tie_res["stimuli"]:
		ids.append(str(item["id"]))
	_check("Desempate alfabetico por id", ids[0] == "alfa" and ids[1] == "zeta", str(ids))

	_case = "perceive: tick incrementa"
	var pt: NPCPerception = NPCPerception.new()
	var t1: int = int(pt.perceive([], Vector2.ZERO, Vector2.RIGHT)["tick"])
	var t2: int = int(pt.perceive([], Vector2.ZERO, Vector2.RIGHT)["tick"])
	var t3: int = int(pt.perceive([], Vector2.ZERO, Vector2.RIGHT)["tick"])
	_check("Tick avanza 1,2,3", t1 == 1 and t2 == 2 and t3 == 3, str([t1, t2, t3]))

	_case = "write_to_memory: adaptador escribe campos correctos"
	var mem = NPCMemory.new(10)
	var pw: NPCPerception = NPCPerception.new({"vision_range": 20.0, "vision_half_angle_deg": 180.0})
	var write_res: Dictionary = pw.perceive([{"id": "w1", "position": Vector2(5.0, 0.0), "priority": 0.7, "kind": "attack"}], Vector2.ZERO, Vector2.RIGHT)
	var written: int = pw.write_to_memory(mem, write_res)
	_check("Escribe 1 evento", written == 1, str(written))
	var evt: Dictionary = mem.get_events()[0]
	_check("type = kind", str(evt["type"]) == "attack", str(evt["type"]))
	_check("kind = channel", str(evt["kind"]) == "vision", str(evt["kind"]))
	_check("source_id conservado", str(evt["source_id"]) == "w1", str(evt["source_id"]))
	_check("intensity = severity", _approx(float(evt["intensity"]), float(evt["severity"])), str([evt["intensity"], evt["severity"]]))
	_check("distance y position", float(evt["distance"]) > 0.0 and evt["position"] is Vector2, str([evt["distance"], evt["position"]]))
	_check("tick coincidente", int(evt["tick"]) == int(write_res["tick"]), str([evt["tick"], write_res["tick"]]))

	_case = "write_to_memory: memory null seguro"
	var pwn: NPCPerception = NPCPerception.new()
	_check("null memory retorna 0", pwn.write_to_memory(null, {"stimuli": [], "tick": 1}) == 0, "")
	_check("sin add_event retorna 0", pwn.write_to_memory({}, {"stimuli": [{"id": "x"}]}) == 0, "")

	_case = "noise_value: prioridad de claves y max_loudness"
	var nv: NPCPerception = NPCPerception.new()
	_check("noise key", _approx(nv.noise_value({"noise": 0.5}), 0.5), "")
	_check("loudness key", _approx(nv.noise_value({"loudness": 0.6}), 0.6), "")
	_check("volume key", _approx(nv.noise_value({"volume": 0.7}), 0.7), "")
	_check("intensity key", _approx(nv.noise_value({"intensity": 0.8}), 0.8), "")
	_check("noise Dict anidado", _approx(nv.noise_value({"noise": {"value": 0.9}}), 0.9), "")
	_check("max_loudness clamp", _approx(nv.noise_value({"noise": 2.0}, {"max_loudness": 1.0}), 1.0), "")

	_case = "noise_radius: prioridad claves y fallback hearing_range"
	var nr: NPCPerception = NPCPerception.new({"hearing_range": 7.0})
	_check("radius key", _approx(nr.noise_radius({"radius": 5.0}), 5.0), "")
	_check("noise_radius key", _approx(nr.noise_radius({"noise_radius": 6.0}), 6.0), "")
	_check("noise_range key", _approx(nr.noise_radius({"noise_range": 8.0}), 8.0), "")
	_check("fallback hearing_range", _approx(nr.noise_radius({}), 7.0), "")

	_case = "_as_2d: todos los tipos soportados"
	var as2d: NPCPerception = NPCPerception.new()
	_check("Vector2", _approx_v2(as2d._as_2d(Vector2(1.0, 2.0)), Vector2(1.0, 2.0)), "")
	_check("Vector3", _approx_v2(as2d._as_2d(Vector3(3.0, 99.0, 4.0)), Vector2(3.0, 4.0)), "")
	_check("Vector2i", _approx_v2(as2d._as_2d(Vector2i(5, 6)), Vector2(5.0, 6.0)), "")
	_check("Vector3i", _approx_v2(as2d._as_2d(Vector3i(7, 88, 8)), Vector2(7.0, 8.0)), "")
	_check("Dict x,y", _approx_v2(as2d._as_2d({"x": 9.0, "y": 10.0}), Vector2(9.0, 10.0)), "")
	_check("Dict x,z", _approx_v2(as2d._as_2d({"x": 11.0, "z": 12.0}), Vector2(11.0, 12.0)), "")
	_check("Dict position Vector2", _approx_v2(as2d._as_2d({"position": Vector2(13.0, 14.0)}), Vector2(13.0, 14.0)), "")
	_check("Dict position Vector3", _approx_v2(as2d._as_2d({"position": Vector3(15.0, 0.0, 16.0)}), Vector2(15.0, 16.0)), "")
	_check("Invalido -> ZERO", as2d._as_2d("bad").is_equal_approx(Vector2.ZERO), "")
	_check("Invalido Dict -> ZERO", as2d._as_2d({}).is_equal_approx(Vector2.ZERO), "")

	_case = "_distance_attenuation: edge cases"
	var da: NPCPerception = NPCPerception.new()
	_check("range 0, dist 0 -> 1.0", _approx(da._distance_attenuation(0.0, 0.0), 1.0), "")
	_check("range 0, dist > 0 -> 0.0", _approx(da._distance_attenuation(1.0, 0.0), 0.0), "")
	_check("range 10, dist 0 -> 1.0", _approx(da._distance_attenuation(0.0, 10.0), 1.0), "")
	_check("range 10, dist 5 -> 0.5", _approx(da._distance_attenuation(5.0, 10.0), 0.5), "")
	_check("range 10, dist 10 -> 0.0", _approx(da._distance_attenuation(10.0, 10.0), 0.0), "")
	_check("range 10, dist 15 -> 0.0 (clamp)", _approx(da._distance_attenuation(15.0, 10.0), 0.0), "")

	_finish()

var _blocked: Dictionary = {}

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