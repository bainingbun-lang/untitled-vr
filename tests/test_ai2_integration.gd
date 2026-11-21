extends SceneTree

const HarnessScript = preload("res://tests/vr_sim_harness.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")
const BTAlwaysReturn = preload("res://core/npc/bt/bt_always_return.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

func _initialize() -> void:
	await process_frame
	await _run_integration_tests()
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

func _run_integration_tests() -> void:
	_case = "steering + BT integrados avanzan"
	await _test_steering_bt_movement()
	
	_case = "pacific mode no ataca"
	await _test_pacific_mode_no_attack()
	
	_case = "hostile mode ataca cuando ve objetivo"
	await _test_hostile_mode_attacks()

func _test_steering_bt_movement() -> void:
	var harness = HarnessScript.new()
	var meta = GeneratorScript.generate(1111, {
		"width": 24, "height": 18, "obstacle_density": 0.15, "spawn_count": 9,
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

	_expect(advanced_count >= 8, "8 de 9 NPCs avanzaron mas de 1m con steering+BT (%d/%d)" % [advanced_count, world.npcs.size()])

	harness.cleanup()
	await process_frame

func _test_pacific_mode_no_attack() -> void:
	var harness = HarnessScript.new()
	var meta = GeneratorScript.generate(2222, {
		"width": 20, "height": 15, "obstacle_density": 0.1, "spawn_count": 5,
	})
	meta["max_npcs"] = 8
	await harness.start(self, meta)
	var world = harness.world
	await process_frame
	for i in range(5):
		await physics_frame

	var npc_with_steering: int = 0
	var npc_with_bt: int = 0
	for npc in world.npcs:
		if npc == null or not is_instance_valid(npc):
			continue
		if npc.steering_agent != null:
			npc_with_steering += 1
		if npc.behavior_tree != null:
			npc_with_bt += 1
		var action = npc.current_action() if npc.has_method("current_action") else ""
		_expect(action != "attack" and action != "suppress" and action != "chase", "NPC en pacifico no ataca: %s" % action)

	_expect(npc_with_steering >= 3, "NPCs tienen steering agent (%d)" % npc_with_steering)
	_expect(npc_with_bt >= 3, "NPCs tienen behavior tree (%d)" % npc_with_bt)

	harness.cleanup()
	await process_frame

func _test_hostile_mode_attacks() -> void:
	var harness = HarnessScript.new()
	var meta = GeneratorScript.generate(3333, {
		"width": 20, "height": 15, "obstacle_density": 0.1, "spawn_count": 4,
	})
	meta["max_npcs"] = 8
	await harness.start(self, meta)
	var world = harness.world
	await process_frame
	for i in range(5):
		await physics_frame

	var hostile_npcs: Array = []
	for npc in world.npcs:
		if npc == null or not is_instance_valid(npc):
			continue
		if npc.role in ["hostile", "criminal", "soldier", "zombie"]:
			hostile_npcs.append(npc)

	if hostile_npcs.size() == 0:
		harness.cleanup()
		await process_frame
		return

	var provocation_target = hostile_npcs[0].global_position
	for i in range(60):
		await physics_frame
		if i == 10:
			for npc in hostile_npcs:
				if npc == null or not is_instance_valid(npc):
					continue
				if npc.has_method("get_combat"):
					var combat = npc.get_combat()
					if combat != null:
						combat.note_gunshot_impact("player", provocation_target)
				if npc.has_method("get_behavior"):
					var behavior = npc.get_behavior()
					if behavior != null:
						behavior.note_aggression("player")
		harness.step(2)

	var attacked: bool = false
	for npc in hostile_npcs:
		if npc == null or not is_instance_valid(npc):
			continue
		var action = npc.current_action() if npc.has_method("current_action") else ""
		if action in ["attack", "suppress", "chase"]:
			attacked = true
			break

	_expect(attacked, "al menos un NPC hostil intenta atacar tras provocación")

	harness.cleanup()
	await process_frame