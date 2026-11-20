extends SceneTree

const BuilderScript = preload("res://core/maps/map_world_builder.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")

var _checks := 0
var _failures: Array = []
var _case := ""


func _params(width: int, height: int, density: float, spawns: int) -> Dictionary:
	return {
		"width": width,
		"height": height,
		"obstacle_density": density,
		"spawn_count": spawns,
	}


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
	var parents: Array = []
	var sample_meta: Dictionary = {}

	_case = "10 semillas generadas"
	for seed in range(1, 11):
		var meta: Dictionary = GeneratorScript.generate(seed, _params(20, 16, 0.28, 4))
		_expect(bool(meta.get("ok")), "semilla %d: el generador debe tener exito" % seed)
		if seed == 1:
			sample_meta = meta

		var parent := Node3D.new()
		parent.name = "Parent_%d" % seed
		root.add_child(parent)
		parents.append(parent)
		var report: Dictionary = BuilderScript.build(meta, parent)
		await process_frame
		for i in range(3):
			await physics_frame

		_expect(bool(report.get("ok")), "semilla %d: build debe tener ok=true (%s)" % [
			seed, str(report.get("errors", [])),
		])
		var spawns: Array = report.get("spawn_points", [])
		var bounds: AABB = report.get("bounds", AABB())
		_expect(spawns.size() == 4, "semilla %d: deben conservarse 4 spawns" % seed)
		_expect(bounds.size.x > 0.0 and bounds.size.z > 0.0, "semilla %d: bounds con area" % seed)
		var inside := true
		for point in spawns:
			if not bounds.has_point(point):
				inside = false
		_expect(inside, "semilla %d: todos los spawns dentro de bounds" % seed)
		_expect(_floor_hit(parent, spawns[0]), "semilla %d: rayo desde spawn debe golpear el suelo" % seed)
		_expect(
			int(report.get("node_count", 9999)) <= BuilderScript.MAX_NODES,
			"semilla %d: limite de nodos movil" % seed
		)
		_expect(BuilderScript.count_nodes(parent) <= BuilderScript.MAX_NODES, \
			"semilla %d: el arbol real no debe exceder el limite" % seed)
		_expect((report.get("props", []) as Array).size() > 0, \
			"semilla %d: debe haber props fisicos" % seed)
		_expect(_all_props_grouped(report), "semilla %d: props en grupo physics_props" % seed)

	_case = "determinismo de props"
	var first_parent := Node3D.new()
	var second_parent := Node3D.new()
	root.add_child(first_parent)
	root.add_child(second_parent)
	parents.append(first_parent)
	parents.append(second_parent)
	var first_report: Dictionary = BuilderScript.build(sample_meta, first_parent)
	var second_report: Dictionary = BuilderScript.build(sample_meta, second_parent)
	await process_frame
	_expect(_prop_positions(first_report) == _prop_positions(second_report), \
		"la misma semilla debe producir la misma distribucion de props")

	_case = "mapa denso 64x64"
	var dense_meta: Dictionary = GeneratorScript.generate(31, _params(64, 64, 0.8, 16))
	_expect(bool(dense_meta.get("ok")), "el mapa denso debe generarse")
	var dense_parent := Node3D.new()
	root.add_child(dense_parent)
	parents.append(dense_parent)
	var dense_report: Dictionary = BuilderScript.build(dense_meta, dense_parent)
	await process_frame
	_expect(bool(dense_report.get("ok")), "el mapa denso debe construirse sin error")
	_expect(BuilderScript.count_nodes(dense_parent) <= BuilderScript.MAX_NODES, \
		"el mapa denso debe respetar el limite de nodos")
	_expect(int(dense_report.get("obstacle_count", 0)) <= BuilderScript.MAX_OBSTACLES, \
		"los obstaculos deben estar acotados")

	_case = "meta invalida"
	var bad_parent := Node3D.new()
	root.add_child(bad_parent)
	parents.append(bad_parent)
	for invalid in [{}, {"spawn_points": "invalido"}, {"spawn_points": []}]:
		var bad: Dictionary = invalid
		var result: Dictionary = BuilderScript.build(bad, bad_parent)
		_expect(not bool(result.get("ok", true)), "meta invalida debe devolver ok=false: %s" % str(bad))
		_expect((result.get("errors", []) as Array).size() > 0, \
			"meta invalida debe explicar el error: %s" % str(bad))
		_expect(bad_parent.get_child_count() == 0, \
			"meta invalida no debe crear geometria: %s" % str(bad))

	_case = "GameWorld"
	var world_scene: PackedScene = load("res://scenes/world/game_world.tscn") as PackedScene
	_expect(world_scene != null, "game_world.tscn debe cargarse")
	var world: Node3D = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	world.setup(sample_meta)
	await process_frame
	for i in range(3):
		await physics_frame

	var report: Dictionary = world.world_report
	_expect(bool(report.get("ok")), "GameWorld.setup debe construir el mundo")
	_expect(world.spawn_point_positions().size() == 4, "GameWorld debe exponer los spawns")
	_expect(world.actor != null, "GameWorld debe anadir jugador o camara de respaldo")
	_expect(world.get_node_or_null("WorldGeometry") != null, "GameWorld debe contener la geometria")
	_expect(world.get_node_or_null("Player") != null or world.get_node_or_null("FallbackCamera") != null, \
		"debe existir Player o FallbackCamera")
	if world.actor != null and world.actor is Camera3D:
		_expect(world.actor.global_position.distance_to(world.spawn_point_positions()[0]) < 6.0, \
			"la camara de respaldo debe estar cerca del primer spawn")
	if world.get_node_or_null("Player") != null:
		_expect(world.actor.global_position.distance_to(world.spawn_point_positions()[0]) < 0.5, \
			"el jugador debe aparecer en el primer spawn")
	_expect(_floor_hit(world, world.spawn_point_positions()[0]), \
		"el mundo de GameWorld debe tener colision de suelo")

	world.setup({})
	await process_frame
	_expect(not bool(world.world_report.get("ok", true)), \
		"GameWorld debe tolerar meta invalida sin crash")
	_expect(world.spawn_point_positions().is_empty(), "meta invalida no debe dejar spawns")
	_expect(world.actor != null and (
		world.actor.name == "Player" or world.actor.name == "FallbackCamera"
	), "sin mapa debe quedar un actor de respaldo")

	world.queue_free()
	for parent in parents:
		parent.queue_free()
	await process_frame


func _floor_hit(parent: Node3D, spawn: Vector3) -> bool:
	var world_3d: World3D = parent.get_world_3d()
	if world_3d == null:
		return false
	var from: Vector3 = spawn + Vector3(0.0, 2.0, 0.0)
	var to: Vector3 = spawn - Vector3(0.0, 2.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = world_3d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Object = hit.get("collider", null)
	return collider is StaticBody3D and str(collider.name) == "Ground"


func _all_props_grouped(report: Dictionary) -> bool:
	for prop in report.get("props", []):
		if not (prop is Node3D) or not prop.is_in_group("physics_props"):
			return false
	return true


func _prop_positions(report: Dictionary) -> Array:
	var result: Array = []
	for prop in report.get("props", []):
		result.append((prop as Node3D).position)
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])
