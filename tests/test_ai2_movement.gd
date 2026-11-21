extends SceneTree

const HarnessScript = preload("res://tests/vr_sim_harness.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

func _initialize() -> void:
	await process_frame
	await _run_movement_tests()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])

func _run_movement_tests() -> void:
	_case = "movimiento sostenido PC"
	await _test_pc_movement()
	
	_case = "movimiento sostenido VR"
	await _test_vr_movement()

func _test_pc_movement() -> void:
	SessionScript.platform = "pc"
	SessionScript.seed = 12345
	var meta = GeneratorScript.generate(12345, {
		"width": 24, "height": 18, "obstacle_density": 0.15, "spawn_count": 9,
	})
	meta["max_npcs"] = 12
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	world.setup(meta)
	await process_frame
	for i in range(5):
		await physics_frame
	
	_expect(world.npcs.size() >= 8, "hay al menos 8 NPCs (%d)" % world.npcs.size())
	
	var start_positions: Array = []
	for npc in world.npcs:
		if npc != null and is_instance_valid(npc):
			start_positions.append(npc.global_position)
	
	for i in range(240):
		await physics_frame
	
	var advanced: int = 0
	for i in range(min(world.npcs.size(), start_positions.size())):
		var npc = world.npcs[i]
		if npc == null or not is_instance_valid(npc):
			continue
		var dist = npc.global_position.distance_to(start_positions[i] as Vector3)
		if dist > 1.0:
			advanced += 1
	
	_expect(advanced >= 8, "8 de 9 NPCs avanzaron > 1m en PC (%d/%d)" % [advanced, world.npcs.size()])
	
	world.queue_free()
	await process_frame
	SessionScript.platform = ""
	SessionScript.platform_override = ""

func _test_vr_movement() -> void:
	var harness = HarnessScript.new()
	var meta = GeneratorScript.generate(54321, {
		"width": 24, "height": 18, "obstacle_density": 0.15, "spawn_count": 9,
	})
	meta["max_npcs"] = 12
	await harness.start(self, meta)
	var world = harness.world
	await process_frame
	for i in range(5):
		await physics_frame
		harness.step(2)
	
	_expect(world.npcs.size() >= 8, "hay al menos 8 NPCs en VR (%d)" % world.npcs.size())
	
	var start_positions: Array = []
	for npc in world.npcs:
		if npc != null and is_instance_valid(npc):
			start_positions.append(npc.global_position)
	
	for i in range(240):
		await physics_frame
		harness.step(2)
	
	var advanced: int = 0
	for i in range(min(world.npcs.size(), start_positions.size())):
		var npc = world.npcs[i]
		if npc == null or not is_instance_valid(npc):
			continue
		var dist = npc.global_position.distance_to(start_positions[i] as Vector3)
		if dist > 1.0:
			advanced += 1
	
	_expect(advanced >= 8, "8 de 9 NPCs avanzaron > 1m en VR (%d/%d)" % [advanced, world.npcs.size()])
	
	harness.cleanup()
	await process_frame