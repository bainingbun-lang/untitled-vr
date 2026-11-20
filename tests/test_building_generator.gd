extends SceneTree

const BuildingScript = preload("res://core/maps/building_generator.gd")
const MapThemesScript = preload("res://core/maps/map_themes.gd")
const BuilderScript = preload("res://core/maps/map_world_builder.gd")

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
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _run() -> void:
	var parents: Array = []

	_case = "determinismo de edificios"
	var params: Dictionary = {
		"cell": Vector2i(4, 4),
		"width": 5,
		"depth": 5,
		"floors": 2,
		"style": "brick",
	}
	var first: Dictionary = BuildingScript.generate(1234, params)
	var second: Dictionary = BuildingScript.generate(1234, params)
	var different: Dictionary = BuildingScript.generate(4321, params)
	_expect(bool(first.get("ok")), "la spec del edificio debe ser valida")
	_expect(str(first) == str(second), "la misma semilla produce el mismo edificio")
	_expect(str(first) != str(different), "semillas distintas producen edificios distintos")
	_expect(str(first.get("doors", [])).find("world_center") >= 0, "el edificio expone puertas")
	_expect((first.get("rooms", []) as Array).size() == 4, "dos plantas generan cuatro habitaciones")
	_expect((first.get("stairs", []) as Array).size() == 1, "dos plantas generan escaleras")

	_case = "puerta atravesable"
	var parent := Node3D.new()
	parent.name = "DoorTest"
	root.add_child(parent)
	parents.append(parent)
	var single_spec: Dictionary = BuildingScript.generate(900, {
		"cell": Vector2i(6, 6),
		"width": 5,
		"depth": 5,
		"floors": 1,
		"style": "concrete",
		"door_side": "south",
	})
	var built: Dictionary = BuildingScript.build(parent, single_spec)
	await process_frame
	for i in range(4):
		await physics_frame
	_expect(bool(built.get("ok")), "el edificio debe construirse")
	_expect((built.get("doors", []) as Array).size() == 1, "debe existir una puerta")
	var door: Dictionary = (built.get("doors", []) as Array)[0]
	var world: World3D = parent.get_world_3d()
	var normal: Vector3 = _door_normal(str(door.get("side", "south")))
	var tangent: Vector3 = _door_tangent(str(door.get("side", "south")))
	var center: Vector3 = door.get("world_center", Vector3.ZERO)
	var door_from: Vector3 = center + normal * 1.6 + Vector3(0.0, 1.1, 0.0)
	var door_to: Vector3 = center - normal * 1.6 + Vector3(0.0, 1.1, 0.0)
	_expect(not _ray_hits(world, door_from, door_to), "un rayo debe cruzar el hueco de la puerta")
	var wall_center: Vector3 = center + tangent * 1.2
	var wall_from: Vector3 = wall_center + normal * 1.6 + Vector3(0.0, 1.1, 0.0)
	var wall_to: Vector3 = wall_center - normal * 1.6 + Vector3(0.0, 1.1, 0.0)
	_expect(_ray_hits(world, wall_from, wall_to), "el muro junto a la puerta debe tener colision")
	var progress: float = await _cross_door(parent, door)
	_expect(progress > 1.5, "un CharacterBody3D debe cruzar la puerta con fisica (avance %f)" % progress)

	_case = "limite de nodos"
	var tall_parent := Node3D.new()
	tall_parent.name = "TallBuilding"
	root.add_child(tall_parent)
	parents.append(tall_parent)
	var tall_spec: Dictionary = BuildingScript.generate(77, {
		"cell": Vector2i(2, 2),
		"width": 6,
		"depth": 6,
		"floors": 3,
		"style": "metal",
	})
	var tall: Dictionary = BuildingScript.build(tall_parent, tall_spec)
	await process_frame
	_expect(bool(tall.get("ok")), "un edificio de tres pisos debe construirse")
	_expect(
		BuildingScript.count_nodes(tall_parent) <= BuildingScript.MAX_BUILDING_NODES,
		"un edificio no debe exceder %d nodos" % BuildingScript.MAX_BUILDING_NODES
	)
	_expect(int(tall.get("collision_count", 0)) >= 20, "las colisiones deben unirse en una forma completa")
	_expect(int(tall.get("visual_count", 0)) <= 5, "las visuales deben agruparse por material")

	_case = "temas con spawn libre y navegacion"
	var themes: Array = ["urbano", "industrial", "rural"]
	for index in range(themes.size()):
		var theme: String = themes[index]
		_case = "tema " + theme
		var meta: Dictionary = MapThemesScript.generate(200 + index, {
			"width": 24,
			"height": 18,
			"obstacle_density": 0.18,
			"spawn_count": 4,
			"theme": theme,
			"theme_density": 0.55,
		})
		_expect(bool(meta.get("ok")), "el tema %s debe generar un mapa valido" % theme)
		_expect(str(meta.get("theme", "")) == theme, "el tema debe quedar en meta['theme']")
		var theme_data: Dictionary = meta.get("theme_data", {})
		var buildings: Array = theme_data.get("buildings", [])
		_expect(buildings.size() > 0, "el tema %s debe colocar edificios" % theme)
		var obstacle_set: Dictionary = {}
		for cell in meta.get("obstacle_cells", []):
			obstacle_set[cell] = true
		var overlap := false
		for spec in buildings:
			var building: Dictionary = spec
			for cell in building.get("footprint", []):
				if obstacle_set.has(cell):
					overlap = true
		_expect(not overlap, "los edificios no deben solaparse con obstaculos")
		var spawn_clear := true
		for spawn in meta.get("spawn_points", []):
			for spec in buildings:
				var building: Dictionary = spec
				if building.get("bounds", AABB()).has_point(spawn):
					spawn_clear = false
		_expect(spawn_clear, "todos los spawns deben quedar fuera de los edificios")
		_expect((theme_data.get("free_spawn_cells", []) as Array).size() > 0, \
			"deben existir celdas de spawn libres")
		var navigation = MapThemesScript.navigation_for(meta)
		var spawn_cells: Array = meta.get("spawn_cells", [])
		if spawn_cells.size() >= 2:
			var path: Dictionary = navigation.find_path(spawn_cells[0], spawn_cells[1])
			_expect(bool(path.get("ok")), "los NPC deben poder ir de un spawn a otro en %s" % theme)
		var themed_parent := Node3D.new()
		themed_parent.name = "Themed_%s" % theme
		root.add_child(themed_parent)
		parents.append(themed_parent)
		var report: Dictionary = BuilderScript.build(meta, themed_parent)
		await process_frame
		for i in range(3):
			await physics_frame
		var theme_report: Dictionary = report.get("theme_report", {})
		_expect(bool(report.get("ok")), "el builder debe aceptar mapas con tema %s" % theme)
		_expect(bool(theme_report.get("built")), "el builder debe anadir geometria del tema %s" % theme)
		_expect((theme_report.get("doors", []) as Array).size() > 0, \
			"el tema %s debe exponer puertas de edificio" % theme)
		_expect(BuilderScript.count_nodes(themed_parent) <= BuilderScript.MAX_NODES, \
			"el mundo tematico debe respetar el limite de nodos movil")

	_case = "mapas antiguos sin tema"
	var legacy: Dictionary = MapThemesScript.generate(7, {
		"width": 16,
		"height": 12,
		"spawn_count": 3,
	})
	_expect(bool(legacy.get("ok")), "un mapa sin tema debe seguir generandose")
	_expect(not legacy.has("theme"), "un mapa sin tema no debe llevar etiqueta de tema")
	var legacy_parent := Node3D.new()
	legacy_parent.name = "LegacyMap"
	root.add_child(legacy_parent)
	parents.append(legacy_parent)
	var legacy_report: Dictionary = BuilderScript.build(legacy, legacy_parent)
	await process_frame
	_expect(bool(legacy_report.get("ok")), "el builder debe seguir validando mapas sin tema")
	_expect(not legacy_report.has("theme_report"), "sin tema no debe aparecer geometria tematica")
	_expect(BuilderScript.count_nodes(legacy_parent) <= BuilderScript.MAX_NODES, \
		"el mapa antiguo debe respetar el limite de nodos")

	for parent_to_free in parents:
		parent_to_free.queue_free()
	await process_frame
	for i in range(8):
		await physics_frame
	_expect(true, "la escena se libera sin errores de fisica")


func _door_normal(side: String) -> Vector3:
	match side:
		"north":
			return Vector3.FORWARD * -1.0
		"east":
			return Vector3.RIGHT
		"west":
			return Vector3.LEFT
		_:
			return Vector3.FORWARD


func _door_tangent(side: String) -> Vector3:
	if side == "east" or side == "west":
		return Vector3.FORWARD
	return Vector3.RIGHT


func _ray_hits(world: World3D, from: Vector3, to: Vector3) -> bool:
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 1
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	return not hit.is_empty()


func _cross_door(parent: Node3D, door: Dictionary) -> float:
	var normal: Vector3 = _door_normal(str(door.get("side", "south")))
	var center: Vector3 = door.get("world_center", Vector3.ZERO)
	var start: Vector3 = center + normal * 1.5 + Vector3(0.0, 0.85, 0.0)
	var direction: Vector3 = -normal
	var body := CharacterBody3D.new()
	body.name = "DoorCrosser"
	body.collision_layer = 4
	body.collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.5
	shape.shape = capsule
	body.add_child(shape)
	parent.add_child(body)
	body.global_position = start
	for i in range(45):
		body.velocity = direction * 2.2
		body.move_and_slide()
		await physics_frame
	var progress: float = (body.global_position - start).dot(direction)
	body.queue_free()
	return progress


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])
