extends SceneTree

const BuilderScript = preload("res://core/maps/map_world_builder.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")

var _checks := 0
var _failures: Array = []
var _case := ""


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


func _params(width: int, height: int, density: float, spawns: int, theme: String = "") -> Dictionary:
	return {
		"width": width,
		"height": height,
		"obstacle_density": density,
		"spawn_count": spawns,
		"theme": theme,
	}


func _run() -> void:
	var parents: Array = []

	_case = "vallas creadas para temas rurales e industriales"
	for theme in ["rural", "industrial"]:
		var meta: Dictionary = GeneratorScript.generate(4242, _params(20, 16, 0.28, 4, theme))
		_expect(bool(meta.get("ok")), "generador ok para tema '%s'" % theme)
		var parent := Node3D.new()
		parent.name = "FenceParent_%s" % theme
		root.add_child(parent)
		parents.append(parent)
		var report: Dictionary = BuilderScript.build(meta, parent)
		await process_frame
		for i in range(3):
			await physics_frame

		_expect(bool(report.get("ok")), "build ok para tema '%s' (%s)" % [theme, str(report.get("errors", []))])
		_expect(int(report.get("node_count", 9999)) <= BuilderScript.MAX_NODES,
			"nodo limite para tema '%s'" % theme)
		_expect(BuilderScript.count_nodes(parent) <= BuilderScript.MAX_NODES,
			"arbol real respeta limite para tema '%s'" % theme)

		var geometry := parent.get_node_or_null("WorldGeometry")
		_expect(geometry != null, "WorldGeometry existe para tema '%s'" % theme)
		var fences := geometry.get_node_or_null("Fences") if geometry != null else null
		_expect(fences != null, "nodo Fences creado para tema '%s'" % theme)
		if fences != null:
			var fence_instances: int = int(fences.get_meta("model_instances", 0))
			_expect(fence_instances > 0, "al menos una valla para tema '%s' (%d)" % [theme, fence_instances])

	_case = "vallas no creadas para temas sin vallas"
	for theme in ["urbano", ""]:
		var meta: Dictionary = GeneratorScript.generate(4242, _params(20, 16, 0.28, 4, theme))
		_expect(bool(meta.get("ok")), "generador ok para tema '%s'" % theme)
		var parent := Node3D.new()
		parent.name = "NoFenceParent_%s" % theme
		root.add_child(parent)
		parents.append(parent)
		var report: Dictionary = BuilderScript.build(meta, parent)
		await process_frame
		_expect(bool(report.get("ok")), "build ok para tema '%s'" % theme)
		var geometry := parent.get_node_or_null("WorldGeometry")
		var fences := geometry.get_node_or_null("Fences") if geometry != null else null
		_expect(fences == null, "no debe haber nodo Fences para tema '%s'" % theme)

	_case = "determinismo de vallas"
	var first_parent := Node3D.new()
	var second_parent := Node3D.new()
	root.add_child(first_parent)
	root.add_child(second_parent)
	parents.append(first_parent)
	parents.append(second_parent)
	var meta1: Dictionary = GeneratorScript.generate(4242, _params(20, 16, 0.28, 4, "rural"))
	var first_report: Dictionary = BuilderScript.build(meta1, first_parent)
	var second_report: Dictionary = BuilderScript.build(meta1, second_parent)
	await process_frame
	var first_fences := first_parent.get_node("WorldGeometry").get_node_or_null("Fences")
	var second_fences := second_parent.get_node("WorldGeometry").get_node_or_null("Fences")
	var first_count: int = int(first_fences.get_meta("model_instances", 0)) if first_fences != null else -1
	var second_count: int = int(second_fences.get_meta("model_instances", 0)) if second_fences != null else -1
	_expect(first_count == second_count, "misma semilla produce misma cantidad de vallas: %d vs %d" % [first_count, second_count])

	for parent in parents:
		parent.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])
