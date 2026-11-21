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

	_case = "construccion con vegetacion para temas variados"
	for theme in ["", "rural", "industrial", "urbano"]:
		var meta: Dictionary = GeneratorScript.generate(4242, _params(20, 16, 0.28, 4, theme))
		_expect(bool(meta.get("ok")), "generador ok para tema '%s'" % theme)
		var parent := Node3D.new()
		parent.name = "VegParent_%s" % theme
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

		var trees := geometry.get_node_or_null("Trees") if geometry != null else null
		var bushes := geometry.get_node_or_null("Bushes") if geometry != null else null
		_expect(trees != null, "nodo Trees creado para tema '%s'" % theme)
		_expect(bushes != null, "nodo Bushes creado para tema '%s'" % theme)
		if trees != null:
			var tree_instances: int = int(trees.get_meta("model_instances", 0))
			_expect(tree_instances > 0, "al menos un arbol para tema '%s' (%d)" % [theme, tree_instances])
		if bushes != null:
			var bush_instances: int = int(bushes.get_meta("model_instances", 0))
			_expect(bush_instances > 0, "al menos un arbusto para tema '%s' (%d)" % [theme, bush_instances])

	_case = "determinismo de vegetacion"
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
	var first_trees := first_parent.get_node("WorldGeometry").get_node_or_null("Trees")
	var second_trees := second_parent.get_node("WorldGeometry").get_node_or_null("Trees")
	var first_count: int = int(first_trees.get_meta("model_instances", 0)) if first_trees != null else -1
	var second_count: int = int(second_trees.get_meta("model_instances", 0)) if second_trees != null else -1
	_expect(first_count == second_count, "misma semilla produce misma cantidad de arboles: %d vs %d" % [first_count, second_count])
	var first_bushes := first_parent.get_node("WorldGeometry").get_node_or_null("Bushes")
	var second_bushes := second_parent.get_node("WorldGeometry").get_node_or_null("Bushes")
	var first_bcount: int = int(first_bushes.get_meta("model_instances", 0)) if first_bushes != null else -1
	var second_bcount: int = int(second_bushes.get_meta("model_instances", 0)) if second_bushes != null else -1
	_expect(first_bcount == second_bcount, "misma semilla produce misma cantidad de arbustos: %d vs %d" % [first_bcount, second_bcount])

	_case = "vegetacion no se solapa con spawns"
	var meta3: Dictionary = GeneratorScript.generate(4242, _params(20, 16, 0.28, 4, "rural"))
	var parent3 := Node3D.new()
	root.add_child(parent3)
	parents.append(parent3)
	var report3: Dictionary = BuilderScript.build(meta3, parent3)
	await process_frame
	var geometry3 := parent3.get_node("WorldGeometry")
	var spawns: Array = report3.get("spawn_points", [])
	var ok := true
	var trees3 := geometry3.get_node_or_null("Trees")
	if trees3 != null:
		for i in range(int(trees3.get_meta("model_instances", 0))):
			var multimesh := trees3.get_child(0)
			if multimesh is MultiMeshInstance3D:
				var transform: Transform3D = multimesh.multimesh.get_instance_transform(i)
				var point: Vector3 = transform.origin
				for spawn in spawns:
					if Vector2(point.x - spawn.x, point.z - spawn.z).length() < 3.0:
						ok = false
		_expect(ok, "ningun arbol demasiado cerca de un spawn")

	for parent in parents:
		parent.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])
