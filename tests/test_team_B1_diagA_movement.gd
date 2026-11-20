extends SceneTree

var game_world: Node3D = null
var passed: int = 0
var failed: int = 0

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const ArmedNpc = preload("res://core/game/armed_npc.gd")
const SessionScript = preload("res://core/game/game_session.gd")

func _initialize() -> void:
	await process_frame
	_run()

func _run() -> void:
	var meta = GeneratorScript.generate(4242, {
		"width": 32, "height": 24, "obstacle_density": 0.15, "spawn_count": 6,
	})
	
	game_world = WorldScene.instantiate()
	root.add_child(game_world)
	await process_frame
	game_world.setup(meta)
	await process_frame
	
	print("\n=== DIAG A: Instrumentando ciclo de movimiento NPC ===")
	
	var actor = game_world.actor
	for npc in game_world.npcs:
		if is_instance_valid(npc) and npc.has_method("tick"):
			var dir = (npc.global_position - actor.global_position).normalized()
			npc.global_position = actor.global_position + dir * 3.0
			if npc.has_method("_remember_threat"):
				npc.call("_remember_threat", actor.global_position, "player", 10.0)
	
	await process_frame
	
	test_movement_cycle("patrol")
	test_movement_cycle("investigate")
	test_movement_cycle("attack")
	test_movement_cycle("flee")
	
	report()

func test_movement_cycle(action_to_test: String) -> void:
	print("\n--- Testando acción: %s ---" % action_to_test)
	
	for npc in game_world.npcs:
		if not is_instance_valid(npc):
			continue
		if npc.has_method("is_dead") and npc.call("is_dead"):
			continue
		
		if npc.has_method("set_action_override"):
			npc.call("set_action_override", action_to_test)
		
		var initial_pos = npc.global_position
		var initial_action = ""
		
		print("  NPC %s: pos_inicial=%s" % [npc.name, str(initial_pos)])
		
		for i in range(30):
			if not is_instance_valid(npc):
				break
			
			var pre_pos = npc.global_position
			var pre_velocity = npc.velocity
			var action = ""
			
			if npc.has_method("tick"):
				var result = npc.tick(0.1)
				action = str(result.get("id", result.get("action", "?")))
				if i == 0:
					initial_action = action
			
			if npc.has_method("_move_toward_goal"):
				npc.call("_move_toward_goal", 0.1)
			
			var post_pos = npc.global_position
			var post_velocity = npc.velocity
			
			var distance_this_tick = post_pos.distance_to(pre_pos)
			
			var goal = npc._goal
			var path = npc._path
			var path_index = npc._path_index
			var moving = npc._moving
			var stuck_time = npc._stuck_time
			var wait_left = npc._wait_left
			var wp_has = npc._wp_has
			var wp = npc._wp
			
			print("  Tick %d: action=%s, goal=%s, vel=%s, moving=%s, path_len=%d, path_idx=%d, stuck=%.2f, wait=%.2f, wp_has=%s, wp=%s, delta_pos=%.4f" % [
				i, action,
				str(goal),
				str(post_velocity),
				str(moving),
				path.size() if path else 0,
				path_index if path_index is int else -1,
				stuck_time,
				wait_left,
				str(wp_has),
				str(wp),
				distance_this_tick
				])
			
			await physics_frame
		
		if not is_instance_valid(npc):
			continue
			
		var final_pos = npc.global_position
		var total_distance = final_pos.distance_to(initial_pos)
		
		print("  NPC %s: action=%s, distancia_total=%.2f" % [npc.name, initial_action, total_distance])
		
		if initial_action == action_to_test or action_to_test == "patrol":
			if total_distance > 1.0:
				passed += 1
				print("  PASS: %s se movió %.2fm" % [npc.name, total_distance])
			else:
				failed += 1
				print("  FAIL: %s NO se mueve (%.2fm)" % [npc.name, total_distance])

func pass_test(msg: String) -> void:
	print("  PASS: %s" % msg)
	passed += 1

func fail(msg: String) -> void:
	print("  FAIL: %s" % msg)
	failed += 1

func report() -> void:
	print("\n=== RESUMEN DIAG A ===")
	print("Pasados: %d, Fallados: %d" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)