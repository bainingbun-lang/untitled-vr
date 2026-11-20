extends SceneTree

const GoreSystemScript = preload("res://core/game/gore_system.gd")
const WoundDecalsScript = preload("res://core/game/wound_decals.gd")
const SessionScript = preload("res://core/game/game_session.gd")
const VrPerfScript = preload("res://core/vr/vr_performance.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""
var _root: Node3D = null
var _vr_perf: VrPerfScript = null

func _initialize() -> void:
	await process_frame
	_root = Node3D.new()
	root.add_child(_root)
	_vr_perf = VrPerfScript.new()
	_vr_perf.set_target_mode(VrPerfScript.MODE_72)
	_vr_perf.build()
	GoreSystemScript.initialize()
	
	_test_gore_levels()
	_test_wound_creation()
	_test_directional_splatter()
	_test_puddle_creation_and_growth()
	_test_dismemberment()
	_test_screen_splatter()
	_test_budgets_and_limits()
	_test_gore_disabled()
	_test_distance_cleanup()
	
	GoreSystemScript.shutdown()
	WoundDecalsScript.shutdown()
	if is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_vr_perf = null
	
	paused = false
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _test_gore_levels() -> void:
	_case = "gore level OFF"
	GoreSystemScript.set_gore_level(GoreSystemScript.GoreLevel.OFF)
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.OFF)
	_expect(not GoreSystemScript.gore_enabled(), "gore_enabled es false en OFF")
	_expect(GoreSystemScript.get_gore_level() == GoreSystemScript.GoreLevel.OFF, "nivel OFF")
	
	_case = "gore level NORMAL"
	GoreSystemScript.set_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	_expect(GoreSystemScript.gore_enabled(), "gore_enabled es true en NORMAL")
	_expect(not GoreSystemScript.is_extreme(), "no es extremo en NORMAL")
	_expect(GoreSystemScript.get_gore_level() == GoreSystemScript.GoreLevel.NORMAL, "nivel NORMAL")
	
	_case = "gore level EXTREME"
	GoreSystemScript.set_gore_level(GoreSystemScript.GoreLevel.EXTREME)
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.EXTREME)
	_expect(GoreSystemScript.gore_enabled(), "gore_enabled es true en EXTREME")
	_expect(GoreSystemScript.is_extreme(), "es extremo en EXTREME")
	_expect(GoreSystemScript.get_gore_level() == GoreSystemScript.GoreLevel.EXTREME, "nivel EXTREME")
	
	_case = "GameSession.gore_enabled = false fuerza OFF"
	SessionScript.gore_enabled = false
	GoreSystemScript.set_gore_level(null)
	_expect(not GoreSystemScript.gore_enabled(), "GameSession.gore_enabled=false desactiva gore")
	SessionScript.gore_enabled = true
	
	_case = "GameSession.gore_level override"
	SessionScript.gore_level = GoreSystemScript.GoreLevel.EXTREME
	GoreSystemScript.set_gore_level(null)
	_expect(GoreSystemScript.get_gore_level() == GoreSystemScript.GoreLevel.EXTREME, "GameSession.gore_level=EXTREME")
	SessionScript.gore_level = GoreSystemScript.GoreLevel.NORMAL

func _test_wound_creation() -> void:
	_case = "herida de entrada crea decals en capas"
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	var children_before: int = _root.get_child_count()
	var wound: Dictionary = GoreSystemScript.create_bullet_wound(_root, Vector3(0, 1.5, 0), Vector3.UP, false, "torso")
	_expect(not wound.is_empty(), "retorna datos de herida")
	_expect(wound.has("layers"), "tiene capas")
	_expect(wound["layers"].size() >= 2, "al menos 2 capas en NORMAL")
	_expect(_root.get_child_count() > children_before, "crea nodos en el parent")
	
	_case = "herida de salida mas grande"
	var children_before2: int = _root.get_child_count()
	var exit_wound: Dictionary = GoreSystemScript.create_bullet_wound(_root, Vector3(0, 1.5, 1), Vector3.FORWARD, true, "torso")
	_expect(not exit_wound.is_empty(), "herida de salida creada")
	var exit_layers: Array = exit_wound["layers"]
	var entry_layers: Array = wound["layers"]
	var exit_size: float = 0.0
	var entry_size: float = 0.0
	for l in exit_layers:
		exit_size = max(exit_size, float(l["size"]))
	for l in entry_layers:
		entry_size = max(entry_size, float(l["size"]))
	_expect(exit_size > entry_size, "herida de salida mas grande: %s > %s" % [exit_size, entry_size])
	
	_case = "EXTREME tiene mas capas"
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.EXTREME)
	var extreme_wound: Dictionary = GoreSystemScript.create_bullet_wound(_root, Vector3(1, 1.5, 0), Vector3.UP, false, "head")
	_expect(extreme_wound["layers"].size() >= 3, "EXTREME tiene 3+ capas: %d" % extreme_wound["layers"].size())
	
	_case = "herida en pared/suelo"
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 0.1)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	_root.add_child(wall)
	var wall_wound: Dictionary = GoreSystemScript.create_bullet_wound(wall, Vector3(0, 1.5, -0.05), Vector3.FORWARD, false, "")
	_expect(not wall_wound.is_empty(), "herida en pared creada")
	_expect(wall_wound["is_character"] == false, "marca como no personaje")
	wall.queue_free()

func _test_directional_splatter() -> void:
	_case = "salpicadura direccional en cono"
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	var decals_before: int = WoundDecalsScript.total_decal_count()
	GoreSystemScript.create_directional_splatter(_root, Vector3(0, 1.0, 0), Vector3.FORWARD, 50.0, Vector3.UP)
	await process_frame
	var decals_after: int = WoundDecalsScript.total_decal_count()
	_expect(decals_after > decals_before, "salpicadura crea decals en superfices: %d -> %d" % [decals_before, decals_after])
	
	_case = "fuerza mayor = mas gotas"
	var decals_before2: int = WoundDecalsScript.total_decal_count()
	GoreSystemScript.create_directional_splatter(_root, Vector3(5, 1.0, 0), Vector3.FORWARD, 100.0, Vector3.UP)
	await process_frame
	var decals_after2: int = WoundDecalsScript.total_decal_count()
	_expect(decals_after2 > decals_before2, "fuerza alta crea mas salpicaduras")

func _test_puddle_creation_and_growth() -> void:
	_case = "charco se crea y crece"
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	var puddles_before: int = WoundDecalsScript.puddle_count()
	var puddle: Node3D = GoreSystemScript.create_puddle(_root, Vector3(0, 0.1, 0), Vector3.UP, 0.3)
	_expect(puddle != null, "charco creado")
	_expect(WoundDecalsScript.puddle_count() == puddles_before + 1, "contador incrementado")
	
	var initial_scale: float = puddle.scale.x
	for i in range(10):
		GoreSystemScript.update(0.5)
		await process_frame
	var grown_scale: float = puddle.scale.x
	_expect(grown_scale > initial_scale, "charco crece con el tiempo: %s -> %s" % [initial_scale, grown_scale])
	
	_case = "charco respeta limite"
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	WoundDecalsScript.set_limits(96, 4, 16, 48)
	for i in range(6):
		GoreSystemScript.create_puddle(_root, Vector3(i * 2.0, 0.1, 0), Vector3.UP, 0.3)
	_expect(WoundDecalsScript.puddle_count() <= 4, "limite de charcos respetado: %d" % WoundDecalsScript.puddle_count())

func _test_dismemberment() -> void:
	_case = "desmembramiento crea tapa de muñon y miembro rigido"
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	
	var skeleton := Skeleton3D.new()
	var root_bone := skeleton.add_bone("Root")
	var leg_bone := skeleton.add_bone("Leg_L")
	skeleton.set_bone_parent(leg_bone, root_bone)
	var foot_bone := skeleton.add_bone("Foot_L")
	skeleton.set_bone_parent(foot_bone, leg_bone)
	skeleton.set_bone_global_pose(leg_bone, Transform3D.IDENTITY.translated(Vector3(-0.15, 0.8, 0)))
	skeleton.set_bone_global_pose(foot_bone, Transform3D.IDENTITY.translated(Vector3(-0.15, 0.4, 0)))
	_root.add_child(skeleton)
	
	var result: Dictionary = GoreSystemScript.dismember_limb(_root, leg_bone, skeleton, Vector3(-0.15, 0.8, 0), Vector3.RIGHT, "clean")
	_expect(not result.is_empty(), "retorna resultado de desmembramiento")
	_expect(result.has("stump_cap"), "tiene tapa de muñon")
	_expect(result.has("detached_limb"), "tiene miembro desprendido")
	_expect(is_instance_valid(result["stump_cap"]), "tapa es instancia valida")
	_expect(is_instance_valid(result["detached_limb"]), "miembro es instancia valida")
	_expect(result["detached_limb"] is RigidBody3D, "miembro es RigidBody3D")
	
	_case = "miembro tiene malla organica (no caja)"
	var limb: RigidBody3D = result["detached_limb"]
	var visual: MeshInstance3D = limb.get_node_or_null("MeshInstance3D")
	_expect(visual != null, "tiene visual")
	_expect(not (visual.mesh is BoxMesh), "no usa BoxMesh: %s" % visual.mesh.get_class())
	
	_case = "tapa de muñon usa material de sangre/tejido"
	var cap: MeshInstance3D = result["stump_cap"]
	_expect(cap.material_override != null, "tiene material override")
	_expect(cap.material_override is StandardMaterial3D, "material es StandardMaterial3D")
	
	_case = "consecuencias NPC: pierna -> cojea/arrastra"
	var changes: Dictionary = result["npc_changes"]
	_expect(changes.has("mobility"), "tiene cambio de movilidad")
	_expect(changes["mobility"] == "crawl", "pierna perdida -> crawl")
	_expect(changes["speed_multiplier"] < 1.0, "reductor de velocidad")
	
	_case = "brazo -> suelta arma"
	var arm_bone: int = skeleton.find_bone("UpperArm_L")
	if arm_bone < 0:
		arm_bone = skeleton.add_bone("UpperArm_L")
		skeleton.set_bone_parent(arm_bone, root_bone)
		skeleton.set_bone_global_pose(arm_bone, Transform3D.IDENTITY.translated(Vector3(0.3, 1.4, 0)))
	var arm_result: Dictionary = GoreSystemScript.dismember_limb(_root, arm_bone, skeleton, Vector3(0.3, 1.4, 0), Vector3.LEFT, "clean")
	var arm_changes: Dictionary = arm_result["npc_changes"]
	_expect(arm_changes.has("drops_weapon"), "brazo perdido -> suelta arma")
	_expect(arm_changes["drops_weapon"] == true, "drops_weapon es true")
	
	skeleton.queue_free()

func _test_screen_splatter() -> void:
	_case = "salpicadura en pantalla al recibir daño"
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	var before: int = GoreSystemScript.screen_splatter_count()
	GoreSystemScript.add_screen_splatter(0.8)
	await process_frame
	var after: int = GoreSystemScript.screen_splatter_count()
	_expect(after == before + 1, "splatter añadido: %d -> %d" % [before, after])
	
	_case = "respeta maximo de splatters"
	for i in range(6):
		GoreSystemScript.add_screen_splatter(0.5)
	_expect(GoreSystemScript.screen_splatter_count() <= 4, "maximo 4 splatters: %d" % GoreSystemScript.screen_splatter_count())
	
	_case = "gore OFF no crea splatter"
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.OFF)
	var before_off: int = GoreSystemScript.screen_splatter_count()
	GoreSystemScript.add_screen_splatter(1.0)
	_expect(GoreSystemScript.screen_splatter_count() == before_off, "OFF no crea splatter")

func _test_budgets_and_limits() -> void:
	_case = "limites NORMAL"
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	var limits: Dictionary = GoreSystemScript.get_limits()
	_expect(limits["decals"] == 96, "decals NORMAL: %d" % limits["decals"])
	_expect(limits["puddles"] == 32, "puddles NORMAL: %d" % limits["puddles"])
	_expect(limits["parts"] == 16, "parts NORMAL: %d" % limits["parts"])
	_expect(limits["active_particles"] == 48, "active_particles NORMAL: %d" % limits["active_particles"])
	
	_case = "limites EXTREME"
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.EXTREME)
	limits = GoreSystemScript.get_limits()
	_expect(limits["decals"] == 160, "decals EXTREME: %d" % limits["decals"])
	_expect(limits["puddles"] == 64, "puddles EXTREME: %d" % limits["puddles"])
	_expect(limits["parts"] == 32, "parts EXTREME: %d" % limits["parts"])
	_expect(limits["active_particles"] == 96, "active_particles EXTREME: %d" % limits["active_particles"])
	
	_case = "reciclado de decals (el mas antiguo)"
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	WoundDecalsScript.set_limits(4, 32, 16, 48)
	for i in range(6):
		GoreSystemScript.create_bullet_wound(_root, Vector3(i * 0.5, 1.5, 0), Vector3.UP, false, "test")
	_expect(WoundDecalsScript.total_decal_count() <= 4, "reciclado funciona: %d decals" % WoundDecalsScript.total_decal_count())
	
	_case = "log_budgets no crashea"
	GoreSystemScript.log_budgets()

func _test_gore_disabled() -> void:
	_case = "gore OFF no crea nada"
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.OFF)
	var children_before: int = _root.get_child_count()
	
	GoreSystemScript.create_bullet_wound(_root, Vector3(0, 1.5, 0), Vector3.UP, false, "torso")
	GoreSystemScript.create_directional_splatter(_root, Vector3(0, 1.0, 0), Vector3.FORWARD, 50.0, Vector3.UP)
	GoreSystemScript.create_puddle(_root, Vector3(0, 0.1, 0), Vector3.UP, 0.3)
	GoreSystemScript.add_screen_splatter(0.5)
	
	await process_frame
	_expect(_root.get_child_count() == children_before, "sin nodos creados con gore OFF")
	_expect(WoundDecalsScript.total_decal_count() == 0, "sin decals")
	_expect(WoundDecalsScript.puddle_count() == 0, "sin charcos")
	_expect(GoreSystemScript.screen_splatter_count() == 0, "sin screen splatter")
	
	_case = "cambio dinamico NORMAL -> OFF limpia"
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	GoreSystemScript.create_bullet_wound(_root, Vector3(0, 1.5, 0), Vector3.UP, false, "torso")
	await process_frame
	var with_gore: int = _root.get_child_count()
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.OFF)
	GoreSystemScript.clear()
	await process_frame
	_expect(_root.get_child_count() < with_gore, "clear limpia al desactivar")

func _test_distance_cleanup() -> void:
	_case = "limpieza por distancia"
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	
	var cam_pos: Vector3 = Vector3(0, 1.6, 0)
	var viewport: Viewport = root.get_viewport()
	if viewport and viewport.get_camera_3d():
		cam_pos = viewport.get_camera_3d().global_position
	
	GoreSystemScript.create_bullet_wound(_root, cam_pos + Vector3(0, 0, 50), Vector3.UP, false, "far")
	GoreSystemScript.create_puddle(_root, cam_pos + Vector3(0, 0, 50), Vector3.UP, 0.3)
	await process_frame
	
	GoreSystemScript._cleanup_distant()
	await process_frame
	
	_expect(WoundDecalsScript.total_decal_count() == 0, "decals lejanos limpiados")
	_expect(WoundDecalsScript.puddle_count() == 0, "charcos lejanos limpiados")

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_case, message])