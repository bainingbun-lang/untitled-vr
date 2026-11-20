extends SceneTree

const ThemesScript = preload("res://core/maps/map_themes.gd")
const BuilderScript = preload("res://core/maps/map_world_builder.gd")
const ValidatorScript = preload("res://core/maps/map_validator.gd")
const MenuScene = preload("res://scenes/menu/main_menu.tscn")

const MODEL_PATHS: Array = [
	"res://assets/models/maps/city-roads/road-crossroad.glb",
	"res://assets/models/maps/city-roads/tile-low.glb",
	"res://assets/models/maps/city-commercial/building-a.glb",
	"res://assets/models/maps/city-industrial/building-a.glb",
	"res://assets/models/maps/car/sedan.glb",
	"res://assets/models/maps/furniture/desk.glb",
	"res://assets/models/maps/furniture/wallDoorwayWide.glb",
	"res://assets/models/maps/nature/tree_default.glb",
	"res://assets/models/maps/nature/ground_pathStraight.glb",
	"res://assets/models/maps/city-industrial/detail-tank.glb",
]

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


func _run() -> void:
	var seeds: Dictionary = {"urbano": 1001, "industrial": 2002, "rural": 3003}
	var metas: Dictionary = {}

	_case = "assets CC0 e imports"
	for path in MODEL_PATHS:
		_expect(FileAccess.file_exists(str(path)), "modelo descargado: %s" % str(path))
		_expect(FileAccess.file_exists(str(path) + ".import"), "modelo importado: %s" % str(path))
	_expect(
		FileAccess.file_exists("res://assets/models/maps/LICENSE-CC0-KENNEY.txt"),
		"licencia CC0 local presente"
	)

	_case = "generacion tematica"
	for theme in seeds.keys():
		var meta: Dictionary = _generate(str(theme), int(seeds[theme]), "noche")
		metas[theme] = meta
		var data: Dictionary = meta.get("theme_data", {})
		_expect(bool(meta.get("ok", false)), "tema %s genera" % str(theme))
		_expect(str(meta.get("theme", "")) == str(theme), "tema %s etiquetado" % str(theme))
		_expect(str(meta.get("time_of_day", "")) == "noche", "hora del dia propagada en %s" % str(theme))
		_expect((data.get("buildings", []) as Array).size() > 0, "%s tiene edificios reales" % str(theme))
		_expect((data.get("props", []) as Array).size() > 0, "%s tiene props reales" % str(theme))
		_expect((data.get("landmarks", []) as Array).size() >= 2, "%s tiene puntos de interes" % str(theme))
		_expect(bool(meta.get("has_navigation", false)), "%s conserva navegacion" % str(theme))
		var validation: Dictionary = ValidatorScript.new().validate(meta)
		_expect(
			int(validation.get("status", 99)) <= ValidatorScript.Status.COMPATIBLE_WITH_WARNINGS,
			"meta %s valida: %s" % [str(theme), str(validation.get("errors", []))]
		)

	var city: Dictionary = metas["urbano"]
	var city_data: Dictionary = city.get("theme_data", {})
	var office: Dictionary = city_data.get("office", {})
	_expect(not office.is_empty(), "Ciudad incluye oficina enterable")
	_expect(bool(office.get("is_office", false)), "oficina marcada como tal")
	_expect((office.get("spawns", []) as Array).size() >= 3, "oficina expone spawns interiores")
	_expect(not str(office.get("door_side", "")).is_empty(), "oficina tiene puerta orientada a calle")

	var industrial_props: Array = (metas["industrial"] as Dictionary).get("theme_data", {}).get("props", [])
	var rural_props: Array = (metas["rural"] as Dictionary).get("theme_data", {}).get("props", [])
	_expect(_has_kind(industrial_props, "pipe"), "Zona industrial tiene tanques/tuberias")
	_expect(_has_kind(industrial_props, "fence"), "Zona industrial tiene vallas")
	_expect(not _has_kind(industrial_props, "car"), "Zona industrial sin coches")
	_expect(_has_kind(rural_props, "tree"), "Pueblo rural tiene arboles")
	_expect(_has_kind(rural_props, "rock"), "Pueblo rural tiene rocas")
	_expect(not _has_kind(rural_props, "car"), "Pueblo rural sin coches")

	_case = "determinismo"
	var params: Dictionary = {
		"theme": "urbano", "time_of_day": "atardecer", "theme_density": 0.55,
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 4,
	}
	_expect(
		str(ThemesScript.generate(777, params)) == str(ThemesScript.generate(777, params)),
		"misma semilla produce el mismo mapa tematico"
	)

	_case = "mundos con modelos reales"
	var day_meta: Dictionary = _generate("urbano", 1001, "dia")
	var night_meta: Dictionary = metas["urbano"]
	var day_parent := Node3D.new()
	var night_parent := Node3D.new()
	root.add_child(day_parent)
	root.add_child(night_parent)
	var day_report: Dictionary = await _build(day_parent, day_meta)
	var night_report: Dictionary = await _build(night_parent, night_meta)
	for entry in [[day_report, day_parent], [night_report, night_parent]]:
		var report: Dictionary = entry[0]
		var parent: Node3D = entry[1]
		_expect(bool(report.get("ok", false)), "build tematico correcto")
		_expect(
			int(report.get("node_count", 9999)) <= BuilderScript.MAX_NODES,
			"presupuesto de nodos movil: %d" % int(report.get("node_count", 9999))
		)
		var decoration: Dictionary = report.get("theme_report", {})
		_expect(bool(decoration.get("ok", false)), "decoracion tematica construida")
		_expect((decoration.get("doors", []) as Array).size() > 0, "hay puertas en el mundo")
		var scan: Dictionary = _scan(parent)
		_expect(int(scan.get("models", 0)) > 5, "se usan modelos GLB en el mundo")
		_expect(int(scan.get("visible_primitives", 0)) == 0, "no quedan cajas/esferas visibles")
		_expect((scan.get("paths", []) as Array).size() >= 6, "variedad de kits en el mundo")
	_expect(str(day_report.get("time_of_day", "")) == "dia", "report diurno")
	_expect(str(night_report.get("time_of_day", "")) == "noche", "report nocturno")
	var day_sun := _find_named(day_parent, "Sun") as DirectionalLight3D
	var night_sun := _find_named(night_parent, "Sun") as DirectionalLight3D
	_expect(day_sun != null and night_sun != null, "luz direccional en ambos mapas")
	if day_sun != null and night_sun != null:
		_expect(night_sun.light_energy < day_sun.light_energy, "la noche reduce la luz solar")
		_expect(night_sun.rotation_degrees != day_sun.rotation_degrees, "el sol cambia de angulo")
	var day_lights: Array = _find_all(day_parent, "OfficeLight")
	var night_lights: Array = _find_all(night_parent, "OfficeLight")
	_expect(day_lights.size() > 0 and night_lights.size() > 0, "oficina iluminada de dia y de noche")
	if day_lights.size() > 0 and night_lights.size() > 0:
		_expect(
			(night_lights[0] as OmniLight3D).light_energy > (day_lights[0] as OmniLight3D).light_energy,
			"las luces interiores aumentan de noche"
		)

	_case = "oficina enterable"
	var office_node: Node3D = null
	for node in _find_all(night_parent, ""):
		if bool(node.get_meta("is_office", false)):
			office_node = node
			break
	_expect(office_node != null, "nodo de oficina presente en el mundo")
	if office_node != null:
		var collision: CollisionShape3D = _find_named(office_node, "OfficeCollisionShape") as CollisionShape3D
		_expect(collision != null, "colision simple de oficina")
		if collision != null:
			_expect(collision.shape is ConcavePolygonShape3D, "colision compound sin trimesh de arte")
		_expect(_door_passable(night_parent, office, night_report), "la puerta de oficina es transitable")
		var spawns: Array = (night_report.get("office", {}) as Dictionary).get("spawns", [])
		var free_count: int = 0
		for spawn in spawns:
			if _floor_hit(night_parent, spawn):
				free_count += 1
		_expect(free_count == spawns.size(), "los spawns interiores caen sobre suelo libre")

	_case = "menu con mapas tematicos"
	var menu: Control = MenuScene.instantiate()
	root.add_child(menu)
	await process_frame
	var play: Button = menu.get_node_or_null("Margin/Column/PlayButton") as Button
	_expect(play != null, "boton PLAY en menu")
	if play != null:
		play.pressed.emit()
		await process_frame
	var screen: Control = menu.get_node_or_null("MapSelectScreen") as Control
	_expect(screen != null, "pantalla de mapas disponible")
	if screen != null:
		var defaults: Array = screen.call("default_maps")
		_expect(defaults.size() == 3, "tres mapas por defecto")
		if defaults.size() > 0:
			var first: Dictionary = defaults[0]
			_expect(str(first.get("theme", "")) == "urbano", "el primer mapa es Ciudad")
			_expect(not (first.get("theme_data", {}) as Dictionary).get("office", {}).is_empty(), "Ciudad incluye oficina")
		_expect(screen.get_node_or_null("Margin/Column/GeneratePanel/ThemeOption") != null, "selector de tema")
		_expect(screen.get_node_or_null("Margin/Column/GeneratePanel/TimeOption") != null, "selector de hora")
	menu.queue_free()
	await process_frame


func _generate(theme: String, seed: int, time_of_day: String) -> Dictionary:
	return ThemesScript.generate(seed, {
		"theme": theme,
		"time_of_day": time_of_day,
		"theme_density": 0.55,
		"width": 24,
		"height": 18,
		"obstacle_density": 0.12,
		"spawn_count": 4,
	})


func _build(parent: Node3D, meta: Dictionary) -> Dictionary:
	var report: Dictionary = BuilderScript.build(meta, parent)
	await process_frame
	for i in range(2):
		await physics_frame
	return report


func _scan(node: Node) -> Dictionary:
	var result: Dictionary = {"models": 0, "visible_primitives": 0, "paths": []}
	for child in node.get_children():
		var sub: Dictionary = _scan(child)
		result["models"] = int(result["models"]) + int(sub["models"])
		result["visible_primitives"] = int(result["visible_primitives"]) + int(sub["visible_primitives"])
		for path in (sub["paths"] as Array):
			if not (result["paths"] as Array).has(path):
				(result["paths"] as Array).append(path)
	if node.has_meta("model_path"):
		result["models"] = int(result["models"]) + 1
		var path: String = str(node.get_meta("model_path"))
		if not (result["paths"] as Array).has(path):
			(result["paths"] as Array).append(path)
	if node is MeshInstance3D and (node as MeshInstance3D).visible:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh is BoxMesh or mesh is CylinderMesh or mesh is SphereMesh:
			result["visible_primitives"] = int(result["visible_primitives"]) + 1
	return result


func _find_named(node: Node, node_name: String) -> Node:
	if node_name.is_empty() or node.name == node_name:
		return node
	for child in node.get_children():
		var found: Node = _find_named(child, node_name)
		if found != null:
			return found
	return null


func _find_all(node: Node, node_name: String) -> Array:
	var result: Array = []
	if node_name.is_empty() or node.name == node_name:
		result.append(node)
	for child in node.get_children():
		for found in _find_all(child, node_name):
			result.append(found)
	return result


func _has_kind(props: Array, kind: String) -> bool:
	for value in props:
		if str((value as Dictionary).get("kind", "")) == kind:
			return true
	return false


func _ray_hit(node: Node, from: Vector3, to: Vector3) -> String:
	var world: World3D = node.get_world_3d()
	if world == null:
		return ""
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider", null)
	return collider.name if collider != null else ""


func _floor_hit(node: Node, spawn: Vector3) -> bool:
	return _ray_hit(node, spawn + Vector3.UP * 2.0, spawn - Vector3.UP * 0.4) == "Ground"


func _door_passable(world: Node, office: Dictionary, report: Dictionary) -> bool:
	var doors: Array = (report.get("office", {}) as Dictionary).get("doors", [])
	if doors.is_empty():
		return false
	var door: Node3D = doors[0] as Node3D
	if door == null:
		return false
	var outward := Vector3(0.0, 0.0, -1.0)
	match str(office.get("door_side", "south")):
		"north":
			outward = Vector3(0.0, 0.0, 1.0)
		"east":
			outward = Vector3(1.0, 0.0, 0.0)
		"west":
			outward = Vector3(-1.0, 0.0, 0.0)
	var center: Vector3 = door.position
	var hit: String = _ray_hit(
		world, center + outward * 1.1 + Vector3.UP * 0.3,
		center - outward * 0.7 + Vector3.UP * 0.3
	)
	return hit.is_empty() or (hit != "OfficeCollision" and hit != "BuildingCollision")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])
