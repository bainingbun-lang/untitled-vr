extends SceneTree

const WorldMaterialsScript = preload("res://core/maps/world_materials.gd")
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
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _run() -> void:
	_case = "texturas PBR 1K"
	for surface in WorldMaterialsScript.SURFACE_TEXTURES.keys():
		var paths: Dictionary = WorldMaterialsScript.SURFACE_TEXTURES[surface]
		for map_name in ["albedo", "normal", "roughness"]:
			var texture := WorldMaterialsScript.texture_for(str(surface), map_name)
			_expect(texture != null, "%s.%s cargada" % [surface, map_name])
			if texture != null:
				_expect(
					texture.get_width() == 1024 and texture.get_height() == 1024,
					"%s.%s es 1024x1024" % [surface, map_name]
				)
	_expect(
		WorldMaterialsScript.texture_for("metal", "metalness") != null,
		"mapa metalness disponible"
	)
	var sky := WorldMaterialsScript.sky_texture()
	_expect(sky != null, "HDRI EXR cargado como textura")
	if sky != null:
		_expect(sky.get_width() == 1024, "HDRI a 1k")

	_case = "materiales PBR triplanar"
	for surface in ["ground", "asphalt", "concrete", "metal", "wood", "brick"]:
		var material := WorldMaterialsScript.surface_material(surface)
		_expect(material is StandardMaterial3D, "material de %s" % surface)
		_expect(material.albedo_texture != null, "albedo asignado en %s" % surface)
		_expect(material.normal_texture != null, "normal asignado en %s" % surface)
		_expect(material.roughness_texture != null, "roughness asignado en %s" % surface)
		_expect(material.uv1_triplanar, "triplanar activo en %s" % surface)
		_expect(material.uv1_world_triplanar, "triplanar mundo en %s" % surface)
		_expect(
			material.uv1_scale.x > 0.0 and material.uv1_scale.x < 1.0,
			"escala de mosaico en %s" % surface
		)
	_expect(
		WorldMaterialsScript.surface_material("metal").metallic > 0.5,
		"metal tiene metallic alto"
	)
	_expect(
		WorldMaterialsScript.surface_material("wood").metallic < 0.1,
		"madera no es metalica"
	)
	_expect(
		WorldMaterialsScript.surface_material("ground") ==
			WorldMaterialsScript.surface_material("ground"),
		"los materiales se cachean"
	)

	_case = "entorno atardecer"
	var environment := WorldMaterialsScript.make_environment(false)
	_expect(environment.background_mode == Environment.BG_SKY, "fondo PanoramaSky")
	_expect(environment.sky != null, "sky presente")
	_expect(environment.sky.sky_material is PanoramaSkyMaterial, "material panoramico")
	var panorama := environment.sky.sky_material as PanoramaSkyMaterial
	_expect(panorama != null and panorama.panorama != null, "HDRI asignado al sky")
	_expect(environment.fog_enabled, "niebla ligera activada")
	_expect(environment.fog_density < 0.01, "niebla no espesa")
	_expect(environment.glow_enabled and environment.glow_intensity < 0.4, "glow suave")
	_expect(not environment.ssao_enabled, "SSAO desactivado")

	_case = "modelos props reales"
	for kind in WorldMaterialsScript.PROP_KINDS:
		var scene := WorldMaterialsScript.prop_scene(kind)
		_expect(scene != null, "modelo glTF cargado: %s" % str(kind))
		if scene != null:
			var instance: Node = scene.instantiate()
			_expect(_count_meshes(instance) > 0, "malla real en %s" % str(kind))
			instance.free()
	_expect(WorldMaterialsScript.PROP_KINDS.size() >= 6, "al menos 6 props CC0")

	_case = "builder con materiales y meta"
	var meta: Dictionary = GeneratorScript.generate(1207, {
		"width": 24, "height": 18, "obstacle_density": 0.25, "spawn_count": 4,
	})
	var parent := Node3D.new()
	parent.name = "Parent"
	root.add_child(parent)
	var report: Dictionary = BuilderScript.build(meta, parent)
	await process_frame
	for i in range(2):
		await physics_frame

	_expect(bool(report.get("ok")), "build correcto: %s" % str(report.get("errors", [])))
	_expect(
		int(report.get("node_count", 9999)) <= BuilderScript.MAX_NODES,
		"limite de nodos movil"
	)
	var world := parent.get_node_or_null("WorldGeometry") as Node3D
	_expect(world != null, "raiz WorldGeometry")
	if world == null:
		return

	var ground := world.get_node_or_null("Ground") as StaticBody3D
	_expect(
		ground != null and str(ground.get_meta("surface", "")) == "dirt",
		"suelo etiquetado como tierra"
	)
	if ground != null:
		_expect(_material_triplanar(ground), "suelo con material PBR triplanar")
	var wall := world.get_node_or_null("WallNorth") as StaticBody3D
	_expect(
		wall != null and str(wall.get_meta("surface", "")) == "brick",
		"muros etiquetados como ladrillo"
	)
	if wall != null:
		_expect(_material_triplanar(wall), "muro con material PBR triplanar")

	var obstacle_surfaces := ["concrete", "wood", "metal"]
	var labelled := 0
	for child in world.get_children():
		if str(child.name).begins_with("Obstacle_"):
			labelled += 1 if obstacle_surfaces.has(str(child.get_meta("surface", ""))) else 0
			_expect(_material_triplanar(child), "obstaculo con material PBR: %s" % child.name)
	_expect(labelled > 0, "obstaculos con meta de superficie")
	_expect(labelled == _count_obstacles(world), "todos los obstaculos etiquetados")

	_case = "props con colision y masa"
	var props: Array = report.get("props", [])
	_expect(props.size() > 0, "hay props fisicos")
	for prop in props:
		var body := prop as RigidBody3D
		_expect(body != null, "prop es RigidBody3D")
		if body == null:
			continue
		_expect(body.mass > 0.0, "masa razonable en %s" % body.name)
		_expect(body.has_meta("surface"), "meta de superficie en %s" % body.name)
		_expect(body.is_in_group("physics_props"), "prop en grupo physics_props")
		var shape := _collision_shape(body)
		_expect(shape != null, "colision en %s" % body.name)
		_expect(not (shape is ConcavePolygonShape3D), "colision no trimesh en %s" % body.name)
		_expect(_count_meshes(body) > 0, "modelo visual real en %s" % body.name)

	var world_environment := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_expect(world_environment != null, "WorldEnvironment en el mapa")
	if world_environment != null:
		_expect(
			world_environment.environment.sky.sky_material is PanoramaSkyMaterial,
			"sky panoramico en el mapa"
		)
	var sun := world.get_node_or_null("Sun") as DirectionalLight3D
	_expect(sun != null, "luz direccional")
	if sun != null:
		_expect(sun.shadow_enabled, "sombras activadas")
		_expect(sun.light_color.r > sun.light_color.b, "luz cálida de atardecer")

	parent.queue_free()
	await process_frame


func _count_meshes(node: Node) -> int:
	if node == null:
		return 0
	var total := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		total += 1
	for child in node.get_children():
		total += _count_meshes(child)
	return total


func _material_triplanar(node: Node3D) -> bool:
	for child in node.get_children():
		if child is MeshInstance3D:
			var material := (child as MeshInstance3D).material_override as StandardMaterial3D
			return material != null and material.uv1_triplanar and material.uv1_world_triplanar
	return false


func _collision_shape(body: Node3D) -> Shape3D:
	for child in body.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).shape
	return null


func _count_obstacles(world: Node3D) -> int:
	var total := 0
	for child in world.get_children():
		if str(child.name).begins_with("Obstacle_"):
			total += 1
	return total


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])
