extends SceneTree

const BuilderScript = preload("res://core/maps/map_world_builder.gd")
const MaterialsScript = preload("res://core/maps/world_materials.gd")

var _n := 0
var _fail := 0


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _initialize() -> void:
	await process_frame
	var mobile_env: Environment = MaterialsScript.make_environment(true)
	_expect(not mobile_env.glow_enabled, "movil/VR: glow desactivado")
	_expect(mobile_env.tonemap_mode == Environment.TONE_MAPPER_FILMIC or mobile_env.tonemap_mode == Environment.TONE_MAPPER_ACES, "tonemap filmic/ACES")
	_expect(mobile_env.tonemap_exposure <= 1.1 and mobile_env.tonemap_white >= 4.0, "exposicion/white razonables")
	_expect(mobile_env.background_energy_multiplier <= 1.0, "cielo sin sobreenergia")
	for tod in ["dia", "tarde", "noche"]:
		var root := Node3D.new()
		root_add(root)
		BuilderScript._build_environment(root, tod, "ciudad")
		var we := root.get_node("WorldEnvironment") as WorldEnvironment
		var env: Environment = we.environment
		var sun := root.get_node("Sun") as DirectionalLight3D
		_expect(env.ambient_light_energy <= 0.8, "%s: ambiente <= 0.8 (%.2f)" % [tod, env.ambient_light_energy])
		_expect(sun.light_energy >= 0.3 and sun.light_energy <= 1.5, "%s: sol 0.3-1.5 (%.2f)" % [tod, sun.light_energy])
		_expect(env.tonemap_mode != Environment.TONE_MAPPER_LINEAR, "%s: tonemap no lineal" % tod)
		_expect(env.background_energy_multiplier <= 1.0, "%s: cielo <= 1.0" % tod)
		root.queue_free()
	_expect(not ProjectSettings.get_setting("rendering/viewport/hdr_2d", false), "sin hdr_2d")
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)


func root_add(node: Node) -> void:
	root.add_child(node)
