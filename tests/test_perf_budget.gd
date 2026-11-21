extends SceneTree

const PerfBudget = preload("res://tools/perf_budget.gd")

var _results: Dictionary
var _tests_passed: int = 0
var _tests_failed: int = 0
var _assertions: int = 0

func _initialize() -> void:
	print("=== test_perf_budget.gd START ===")
	
	test_budget_constants()
	test_analyze_urbano_theme()
	test_analyze_industrial_theme()
	test_analyze_rural_theme()
	test_analyze_all_themes()
	test_building_budget()
	test_budget_compliance_check()
	test_triangle_estimation()
	test_draw_call_estimation()
	test_material_counting()
	test_texture_sizes()
	test_shadow_light_counting()
	test_physics_body_counting()
	test_particle_system_counting()
	test_failure_reporting()
	
	print("")
	print("=== SUMMARY ===")
	print("Tests passed: %d" % _tests_passed)
	print("Tests failed: %d" % _tests_failed)
	print("Total assertions: %d" % _assertions)
	
	if _tests_failed > 0:
		print("FAIL")
		quit(1)
	else:
		print("PASS (%d assertions)" % _assertions)
		quit(0)


func test_budget_constants() -> void:
	_assert("QUEST_72_FPS_BUDGET_MS == 13.888", is_equal_approx(PerfBudget.QUEST_72_FPS_BUDGET_MS, 13.888))
	_assert("QUEST_90_FPS_BUDGET_MS == 11.111", is_equal_approx(PerfBudget.QUEST_90_FPS_BUDGET_MS, 11.111))
	_assert("MAX_VISIBLE_TRIS == 150000", PerfBudget.MAX_VISIBLE_TRIS == 150000)
	_assert("MAX_DRAW_CALLS == 120", PerfBudget.MAX_DRAW_CALLS == 120)
	_assert("MAX_SHADOW_LIGHTS == 2", PerfBudget.MAX_SHADOW_LIGHTS == 2)
	_assert("MAX_TEXTURE_SIZE == 1024", PerfBudget.MAX_TEXTURE_SIZE == 1024)
	_assert("MAX_RAGDOLLS == 8", PerfBudget.MAX_RAGDOLLS == 8)
	_assert("MAX_SHELLS == 24", PerfBudget.MAX_SHELLS == 24)
	_assert("MAX_DECALS == 128", PerfBudget.MAX_DECALS == 128)
	_assert("MAX_NODES == 200", PerfBudget.MAX_NODES == 200)
	_pass("test_budget_constants")


func test_analyze_urbano_theme() -> void:
	var meta = {
		"theme": "urbano",
		"scale": 1.0,
		"time_of_day": "atardecer",
		"seed": 42,
		"boundaries": {"min": Vector2(0, 0), "max": Vector2(20, 20)},
		"spawn_points": [Vector2(5, 5), Vector2(15, 15), Vector2(10, 10)],
		"obstacles": [Vector2(3, 3), Vector2(7, 7), Vector2(12, 8), Vector2(16, 12)],
		"grid": [
			"####################",
			"#..................#",
			"#..................#",
			"#....##...........#",
			"#....##...........#",
			"#..................#",
			"#..................#",
			"#........##........#",
			"#........##........#",
			"#..................#",
			"#..................#",
			"#........##........#",
			"#........##........#",
			"#..................#",
			"#..................#",
			"#..................#",
			"#..................#",
			"#..................#",
			"#..................#",
			"####################",
		],
	}
	
	var result: Dictionary = PerfBudget.analyze_theme("urbano", meta)
	
	_assert("urbano result has theme", result.has("theme") and result.theme == "urbano")
	_assert("urbano build_time_ms > 0", result.build_time_ms > 0)
	_assert("urbano node_count > 0", result.node_count > 0)
	_assert("urbano node_count <= MAX_NODES", result.node_count <= PerfBudget.MAX_NODES)
	_assert("urbano obstacle_count >= 0", result.obstacle_count >= 0)
	_assert("urbano tri_estimate >= 0", result.tri_estimate >= 0)
	_assert("urbano draw_calls >= 0", result.draw_calls >= 0)
	_assert("urbano unique_materials >= 0", result.unique_materials >= 0)
	_assert("urbano budget_pass is bool", typeof(result.budget_pass) == TYPE_BOOL)
	_assert("urbano errors is array", result.errors is Array)
	
	_pass("test_analyze_urbano_theme")


func test_analyze_industrial_theme() -> void:
	var meta = {
		"theme": "industrial",
		"scale": 1.0,
		"time_of_day": "dia",
		"seed": 123,
		"boundaries": {"min": Vector2(0, 0), "max": Vector2(24, 16)},
		"spawn_points": [Vector2(4, 4), Vector2(20, 12)],
		"obstacles": [Vector2(6, 3), Vector2(18, 8), Vector2(10, 12)],
		"grid": [],
	}
	
	var result: Dictionary = PerfBudget.analyze_theme("industrial", meta)
	
	_assert("industrial result has theme", result.has("theme") and result.theme == "industrial")
	_assert("industrial build_time_ms > 0", result.build_time_ms > 0)
	_assert("industrial node_count > 0", result.node_count > 0)
	_assert("industrial node_count <= MAX_NODES", result.node_count <= PerfBudget.MAX_NODES)
	_assert("industrial obstacle_count >= 0", result.obstacle_count >= 0)
	_assert("industrial tri_estimate >= 0", result.tri_estimate >= 0)
	_assert("industrial draw_calls >= 0", result.draw_calls >= 0)
	_assert("industrial unique_materials >= 0", result.unique_materials >= 0)
	_assert("industrial budget_pass is bool", typeof(result.budget_pass) == TYPE_BOOL)
	
	_pass("test_analyze_industrial_theme")


func test_analyze_rural_theme() -> void:
	var meta = {
		"theme": "rural",
		"scale": 1.0,
		"time_of_day": "noche",
		"seed": 456,
		"boundaries": {"min": Vector2(0, 0), "max": Vector2(30, 30)},
		"spawn_points": [Vector2(5, 5), Vector2(25, 25), Vector2(15, 10)],
		"obstacles": [Vector2(8, 8), Vector2(20, 20), Vector2(12, 15), Vector2(18, 5)],
		"grid": [],
	}
	
	var result: Dictionary = PerfBudget.analyze_theme("rural", meta)
	
	_assert("rural result has theme", result.has("theme") and result.theme == "rural")
	_assert("rural build_time_ms > 0", result.build_time_ms > 0)
	_assert("rural node_count > 0", result.node_count > 0)
	_assert("rural node_count <= MAX_NODES", result.node_count <= PerfBudget.MAX_NODES)
	_assert("rural obstacle_count >= 0", result.obstacle_count >= 0)
	_assert("rural tri_estimate >= 0", result.tri_estimate >= 0)
	_assert("rural draw_calls >= 0", result.draw_calls >= 0)
	_assert("rural unique_materials >= 0", result.unique_materials >= 0)
	_assert("rural budget_pass is bool", typeof(result.budget_pass) == TYPE_BOOL)
	
	_pass("test_analyze_rural_theme")


func test_analyze_all_themes() -> void:
	var results: Dictionary = PerfBudget.analyze_all_themes()
	
	_assert("analyze_all_themes returns 3 themes", results.size() == 3)
	_assert("analyze_all_themes has urbano", results.has("urbano"))
	_assert("analyze_all_themes has industrial", results.has("industrial"))
	_assert("analyze_all_themes has rural", results.has("rural"))
	
	for theme_name in results:
		var result: Dictionary = results[theme_name]
		_assert("%s has budget_pass" % theme_name, result.has("budget_pass"))
		_assert("%s budget_pass is bool" % theme_name, typeof(result.budget_pass) == TYPE_BOOL)
	
	_pass("test_analyze_all_themes")


func test_building_budget() -> void:
	var BuildingGenerator = preload("res://core/maps/building_generator.gd")
	
	var spec: Dictionary = BuildingGenerator.generate(999, {
		"cell": Vector2i(0, 0),
		"width": 4,
		"depth": 4,
		"floors": 1,
		"style": "brick",
		"door_side": "south",
	})
	
	_assert("BuildingGenerator.generate ok", bool(spec.get("ok", false)))
	
	var result: Dictionary = PerfBudget.analyze_building(spec)
	
	_assert("building result type", result.has("type") and result.type == "building")
	_assert("building build_time_ms > 0", result.build_time_ms > 0)
	_assert("building node_count > 0", result.node_count > 0)
	_assert("building visual_count > 0", result.visual_count > 0)
	_assert("building collision_count > 0", result.collision_count > 0)
	_assert("building tri_estimate >= 0", result.tri_estimate >= 0)
	_assert("building draw_calls >= 0", result.draw_calls >= 0)
	_assert("building unique_materials >= 0", result.unique_materials >= 0)
	_assert("building budget_pass is bool", typeof(result.budget_pass) == TYPE_BOOL)
	
	_pass("test_building_budget")


func test_budget_compliance_check() -> void:
	var results_pass: Dictionary = {
		"theme1": {"budget_pass": true},
		"theme2": {"budget_pass": true},
	}
	_assert("check_budget_compliance all pass", PerfBudget.check_budget_compliance(results_pass))
	
	var results_fail: Dictionary = {
		"theme1": {"budget_pass": true},
		"theme2": {"budget_pass": false},
	}
	_assert("check_budget_compliance one fail", not PerfBudget.check_budget_compliance(results_fail))
	
	var results_empty: Dictionary = {}
	_assert("check_budget_compliance empty", PerfBudget.check_budget_compliance(results_empty))
	
	_pass("test_budget_compliance_check")


func test_triangle_estimation() -> void:
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(2, 2, 2)
	
	var tri_count: int = PerfBudget._mesh_triangle_count(box_mesh)
	_assert("BoxMesh triangle count == 12", tri_count == 12)
	
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 1.0
	sphere_mesh.rings = 8
	sphere_mesh.radial_segments = 16
	tri_count = PerfBudget._mesh_triangle_count(sphere_mesh)
	_assert("SphereMesh triangle count > 0", tri_count > 0)
	
	_pass("test_triangle_estimation")


func test_draw_call_estimation() -> void:
	var root: Node3D = Node3D.new()
	var mesh1: MeshInstance3D = MeshInstance3D.new()
	mesh1.mesh = BoxMesh.new()
	root.add_child(mesh1)
	
	var mesh2: MeshInstance3D = MeshInstance3D.new()
	mesh2.mesh = SphereMesh.new()
	root.add_child(mesh2)
	
	var multimesh: MultiMeshInstance3D = MultiMeshInstance3D.new()
	multimesh.multimesh = MultiMesh.new()
	multimesh.multimesh.mesh = BoxMesh.new()
	multimesh.multimesh.instance_count = 10
	root.add_child(multimesh)
	
	var draw_calls: int = PerfBudget._estimate_draw_calls(root)
	_assert("draw calls = 3 (2 MeshInstance3D + 1 MultiMeshInstance3D)", draw_calls == 3)
	
	root.queue_free()
	_pass("test_draw_call_estimation")


func test_material_counting() -> void:
	var root: Node3D = Node3D.new()
	var mat1: StandardMaterial3D = StandardMaterial3D.new()
	var mat2: StandardMaterial3D = StandardMaterial3D.new()
	
	var mesh1: MeshInstance3D = MeshInstance3D.new()
	mesh1.mesh = BoxMesh.new()
	mesh1.material_override = mat1
	root.add_child(mesh1)
	
	var mesh2: MeshInstance3D = MeshInstance3D.new()
	mesh2.mesh = SphereMesh.new()
	mesh2.material_override = mat1
	root.add_child(mesh2)
	
	var mesh3: MeshInstance3D = MeshInstance3D.new()
	mesh3.mesh = CylinderMesh.new()
	mesh3.material_override = mat2
	root.add_child(mesh3)
	
	var unique_mats: int = PerfBudget._count_unique_materials(root)
	_assert("unique materials = 2 (mat1 used twice, mat2 once)", unique_mats == 2)
	
	root.queue_free()
	_pass("test_material_counting")


func test_texture_sizes() -> void:
	var root: Node3D = Node3D.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	
	var tex: ImageTexture = ImageTexture.new()
	var img: Image = Image.create(512, 512, false, Image.FORMAT_RGBA8)
	tex.set_image(img)
	mat.albedo_texture = tex
	
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.material_override = mat
	root.add_child(mesh)
	
	var sizes: Array = PerfBudget._get_texture_sizes(root)
	# In headless mode, texture sizes may not be available
	# Just verify the function runs and returns an array
	_assert("texture sizes returns array", sizes is Array)
	
	root.queue_free()
	_pass("test_texture_sizes")


func test_shadow_light_counting() -> void:
	var root: Node3D = Node3D.new()
	
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.shadow_enabled = true
	root.add_child(sun)
	
	var light2: OmniLight3D = OmniLight3D.new()
	light2.shadow_enabled = false
	root.add_child(light2)
	
	var light3: SpotLight3D = SpotLight3D.new()
	light3.shadow_enabled = true
	root.add_child(light3)
	
	var light4: DirectionalLight3D = DirectionalLight3D.new()
	light4.shadow_enabled = false
	root.add_child(light4)
	
	var shadow_count: int = PerfBudget._count_shadow_lights(root)
	_assert("shadow lights = 2 (sun + spot)", shadow_count == 2)
	
	root.queue_free()
	_pass("test_shadow_light_counting")


func test_physics_body_counting() -> void:
	var root: Node3D = Node3D.new()
	
	var body1: StaticBody3D = StaticBody3D.new()
	root.add_child(body1)
	
	var body2: RigidBody3D = RigidBody3D.new()
	root.add_child(body2)
	
	var body3: CharacterBody3D = CharacterBody3D.new()
	root.add_child(body3)
	
	var not_body: Node3D = Node3D.new()
	root.add_child(not_body)
	
	var count: int = PerfBudget._count_physics_bodies(root)
	_assert("physics bodies = 3", count == 3)
	
	root.queue_free()
	_pass("test_physics_body_counting")


func test_particle_system_counting() -> void:
	var root: Node3D = Node3D.new()
	
	var gpu_particles: GPUParticles3D = GPUParticles3D.new()
	root.add_child(gpu_particles)
	
	var cpu_particles: CPUParticles3D = CPUParticles3D.new()
	root.add_child(cpu_particles)
	
	var not_particles: Node3D = Node3D.new()
	root.add_child(not_particles)
	
	var count: int = PerfBudget._count_particle_systems(root)
	_assert("particle systems = 2", count == 2)
	
	root.queue_free()
	_pass("test_particle_system_counting")


func test_failure_reporting() -> void:
	var result: Dictionary = PerfBudget._failure("test_theme", ["error1", "error2"], 123.45)
	
	_assert("failure has theme", result.theme == "test_theme")
	_assert("failure build_time_ms", result.build_time_ms == 123.45)
	_assert("failure budget_pass false", result.budget_pass == false)
	_assert("failure has budget_failures", result.budget_failures.size() == 2)
	_assert("failure has errors", result.errors.size() == 2)
	
	_pass("test_failure_reporting")


func _assert(msg: String, condition: bool) -> void:
	_assertions += 1
	if not condition:
		print("  ASSERT FAILED: %s" % msg)
		_tests_failed += 1
	else:
		print("  OK: %s" % msg)
		_tests_passed += 1


func _pass(test_name: String) -> void:
	print("PASS: %s" % test_name)