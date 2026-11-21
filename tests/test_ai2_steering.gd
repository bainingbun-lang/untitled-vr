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
	await _run_steering_tests()
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

func _run_steering_tests() -> void:
	_case = "steering evita obstaculos"
	await _test_obstacle_avoidance()
	
	_case = "separacion entre NPCs"
	await _test_separation()
	
	_case = "8 de 9 NPCs avanzan mas de 1m"
	await _test_movement_distance()

func _test_obstacle_avoidance() -> void:
	var harness = HarnessScript.new()
	var meta = GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.25, "spawn_count": 3,
	})
	meta["max_npcs"] = 8
	await harness.start(self, meta)
	var world = harness.world
	await process_frame
	for i in range(5):
		await physics_frame
	
	_expect(world.npcs.size() >= 2, "hay NPCs en el mundo (%d)" % world.npcs.size())
	
	var before: Array = []
	for npc in world.npcs:
		if npc != null and is_instance_valid(npc):
			before.append(npc.global_position)
	
	for i in range(120):
		await physics_frame
		harness.step(2)
	
	var moved_count: int = 0
	var avoided_obstacles: int = 0
	for i in range(world.npcs.size()):
		var npc = world.npcs[i]
		if npc == null or not is_instance_valid(npc):
			continue
		var dist = npc.global_position.distance_to(before[i] as Vector3)
		if dist > 0.5:
			moved_count += 1
		var nav = world.get("navigation")
		if nav != null:
			var cell = nav.call("world_to_cell_2d", Vector2(npc.global_position.x, npc.global_position.z), 1.0)
			if not bool(nav.call("is_blocked", cell)):
				avoided_obstacles += 1
	
	_expect(moved_count >= 2, "al menos 2 NPCs se movieron (%d)" % moved_count)
	_expect(avoided_obstacles == world.npcs.size(), "todos los NPCs evitan obstaculos (%d/%d)" % [avoided_obstacles, world.npcs.size()])
	
	harness.cleanup()
	await process_frame

func _test_separation() -> void:
	var harness = HarnessScript.new()
	var meta = GeneratorScript.generate(7777, {
		"width": 20, "height": 15, "obstacle_density": 0.1, "spawn_count": 5,
	})
	meta["max_npcs"] = 8
	await harness.start(self, meta)
	var world = harness.world
	await process_frame
	for i in range(5):
		await physics_frame
	
	_expect(world.npcs.size() >= 3, "hay NPCs para probar separacion (%d)" % world.npcs.size())
	
	var min_distances: Array = []
	for i in range(60):
		await physics_frame
		harness.step(2)
		
		for j in range(world.npcs.size()):
			var npc_a = world.npcs[j]
			if npc_a == null or not is_instance_valid(npc_a):
				continue
			for k in range(j + 1, world.npcs.size()):
				var npc_b = world.npcs[k]
				if npc_b == null or not is_instance_valid(npc_b):
					continue
				var dist = npc_a.global_position.distance_to(npc_b.global_position)
				min_distances.append(dist)
	
	var min_sep: float = INF
	if min_distances.size() > 0:
		for d in min_distances:
			if d < min_sep:
				min_sep = d
	
	_expect(min_sep >= 0.8, "separacion minima entre NPCs >= 0.8m (actual: %.2f)" % min_sep)
	_expect(min_sep < 5.0, "NPCs no estan demasiado separados (%.2f)" % min_sep)
	
	harness.cleanup()
	await process_frame

func _test_movement_distance() -> void:
	var harness = HarnessScript.new()
	var meta = GeneratorScript.generate(9999, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 9,
	})
	meta["max_npcs"] = 12
	await harness.start(self, meta)
	var world = harness.world
	await process_frame
	for i in range(5):
		await physics_frame
	
	_expect(world.npcs.size() >= 8, "hay al menos 8 NPCs (%d)" % world.npcs.size())
	
	var start_positions: Array = []
	for npc in world.npcs:
		if npc != null and is_instance_valid(npc):
			start_positions.append(npc.global_position)
	
	for i in range(300):
		await physics_frame
		harness.step(2)
	
	var advanced_count: int = 0
	for i in range(min(world.npcs.size(), start_positions.size())):
		var npc = world.npcs[i]
		if npc == null or not is_instance_valid(npc):
			continue
		var dist = npc.global_position.distance_to(start_positions[i] as Vector3)
		if dist > 1.0:
			advanced_count += 1
	
	_expect(advanced_count >= 8, "8 de 9 NPCs avanzaron mas de 1m (%d/%d)" % [advanced_count, world.npcs.size()])
	
	harness.cleanup()
	await process_frame