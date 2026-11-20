extends SceneTree

var game_world: Node3D = null
var passed: int = 0
var failed: int = 0

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const ArmedNpc = preload("res://core/game/armed_npc.gd")

func _initialize() -> void:
	await process_frame
	_run()

func _run() -> void:
	var meta = GeneratorScript.generate(12345, {
		"width": 32, "height": 24, "obstacle_density": 0.15, "spawn_count": 6,
	})
	
	game_world = WorldScene.instantiate()
	root.add_child(game_world)
	await process_frame
	game_world.setup(meta)
	await process_frame
	
	# Forzar algunos NPCs a estado "flee" poniéndolos cerca del jugador
	var actor = game_world.actor
	for npc in game_world.npcs:
		if is_instance_valid(npc) and npc.has_method("tick"):
			# Mover NPC cerca del actor para que lo vea y huya
			var dir = (npc.global_position - actor.global_position).normalized()
			npc.global_position = actor.global_position + dir * 3.0
			# Forzar threat memory alto
			if npc.has_method("_remember_threat"):
				npc.call("_remember_threat", actor.global_position, "player", 10.0)
	
	await process_frame
	
	# Test movimiento flee
	test_flee_movement()
	report()

func test_flee_movement() -> void:
	print("\n=== Test Auditor2: NPC Flee Movement ===")
	var stuck_count = 0
	var moved_count = 0
	
	for npc in game_world.npcs:
		if not is_instance_valid(npc):
			continue
		if npc.has_method("is_dead") and npc.call("is_dead"):
			continue
			
		var initial_pos = npc.global_position
		var initial_action = ""
		
		# Run 15 ticks
		for i in range(15):
			if not is_instance_valid(npc):
				break
			if npc.has_method("tick"):
				var result = npc.tick(0.1)
				var action = str(result.get("id", result.get("action", "?")))
				if i == 0:
					initial_action = action
				print("  %s tick %d: action=%s, pos=%s" % [npc.name, i, action, str(npc.global_position)])
			await physics_frame
		
		if not is_instance_valid(npc):
			continue
			
		var distance = npc.global_position.distance_to(initial_pos)
		print("  %s: action=%s, distancia=%.2f" % [npc.name, initial_action, distance])
		
		if initial_action == "flee" or initial_action == "run":
			if distance > 1.0:
				moved_count += 1
				pass_test("%s huyó correctamente (%.2fm)" % [npc.name, distance])
			else:
				stuck_count += 1
				fail("%s NO huye: distance=%.2f (action=%s)" % [npc.name, distance, initial_action])
	
	if stuck_count > 0:
		fail("TOTAL: %d NPCs en flee inmóviles de %d probados" % [stuck_count, stuck_count + moved_count])
	else:
		pass_test("Todos los NPCs en flee se mueven correctamente")

func pass_test(msg: String) -> void:
	print("  PASS: %s" % msg)
	passed += 1

func fail(msg: String) -> void:
	print("  FAIL: %s" % msg)
	failed += 1

func report() -> void:
	print("\n=== RESUMEN AUDITOR2 NPC FLEE ===")
	print("Pasados: %d, Fallados: %d" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)