extends SceneTree

const ThemesScript = preload("res://core/maps/map_themes.gd")
const BuilderScript = preload("res://core/maps/map_world_builder.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

func _initialize() -> void:
	await _run()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _run() -> void:
	_case = "medicion carga mapa urbano"
	var seed := 12345
	var params: Dictionary = {
		"theme": "urbano",
		"time_of_day": "noche",
		"theme_density": 0.55,
		"width": 24,
		"height": 18,
		"obstacle_density": 0.12,
		"spawn_count": 4,
	}
	
	var meta: Dictionary = ThemesScript.generate(seed, params)
	_expect(bool(meta.get("ok", false)), "meta generada OK")
	
	var root := Node3D.new()
	root.name = "PerfTestRoot"
	self.root.add_child(root)
	
	var start_time := Time.get_ticks_msec()
	var report: Dictionary = BuilderScript.build(meta, root)
	var build_time := Time.get_ticks_msec() - start_time
	
	_expect(bool(report.get("ok", false)), "build OK")
	_expect(int(report.get("node_count", 9999)) <= BuilderScript.MAX_NODES, "nodos dentro del presupuesto: %d" % int(report.get("node_count", 9999)))
	
	print("TIEMPO_BUILD_MS: %d" % build_time)
	print("NODE_COUNT: %d" % int(report.get("node_count", 0)))
	print("OBSTACLE_COUNT: %d" % int(report.get("obstacle_count", 0)))
	print("PROP_COUNT: %d" % (report.get("props", []) as Array).size())
	
	_expect(build_time < 2500, "tiempo de build < 2500ms (actual: %dms)" % build_time)
	
	root.queue_free()
	await process_frame
	
	_case = "medicion carga mapa industrial"
	params["theme"] = "industrial"
	meta = ThemesScript.generate(seed + 1, params)
	root = Node3D.new()
	root.name = "PerfTestRoot2"
	self.root.add_child(root)
	
	start_time = Time.get_ticks_msec()
	report = BuilderScript.build(meta, root)
	build_time = Time.get_ticks_msec() - start_time
	
	_expect(bool(report.get("ok", false)), "build industrial OK")
	print("TIEMPO_BUILD_INDUSTRIAL_MS: %d" % build_time)
	print("NODE_COUNT_INDUSTRIAL: %d" % int(report.get("node_count", 0)))
	
	_expect(build_time < 2500, "tiempo de build industrial < 2500ms (actual: %dms)" % build_time)
	
	root.queue_free()
	await process_frame
	
	_case = "medicion carga mapa rural"
	params["theme"] = "rural"
	meta = ThemesScript.generate(seed + 2, params)
	root = Node3D.new()
	root.name = "PerfTestRoot3"
	self.root.add_child(root)
	
	start_time = Time.get_ticks_msec()
	report = BuilderScript.build(meta, root)
	build_time = Time.get_ticks_msec() - start_time
	
	_expect(bool(report.get("ok", false)), "build rural OK")
	print("TIEMPO_BUILD_RURAL_MS: %d" % build_time)
	print("NODE_COUNT_RURAL: %d" % int(report.get("node_count", 0)))
	
	_expect(build_time < 2500, "tiempo de build rural < 2500ms (actual: %dms)" % build_time)
	
	root.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])