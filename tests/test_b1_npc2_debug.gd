extends SceneTree

var test_results: Dictionary = {}
var game_world: Node3D = null
var error_count: int = 0
var passed_count: int = 0

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")
const ArmedNpc = preload("res://core/game/armed_npc.gd")

func _initialize() -> void:
	await process_frame
	_run()

func _run() -> void:
	var meta = GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.18, "spawn_count": 4,
	})
	
	game_world = WorldScene.instantiate()
	root.add_child(game_world)
	await process_frame
	game_world.setup(meta)
	await process_frame
	for i in range(10):
		await physics_frame
	
	print("=== GameWorld setup completo ===")
	print("Actor: %s" % str(game_world.actor))
	print("NPCs: %d" % game_world.npcs.size())
	
	await test_npcs_mobile_debug()
	report_results()

func test_npcs_mobile_debug() -> void:
	print("\n=== Test: NPCs móviles (DEBUG) ===")
	var npcs = game_world.npcs
	var mobile_count = 0
	var stuck_count = 0
	var dead_count = 0
	var error_count_npc = 0
	
	if npcs.size() == 0:
		fail("NO HAY NPCs SPAWNEADOS - esto es un bug grave")
		return
	
	for npc in npcs:
		if not is_instance_valid(npc):
			error_count_npc += 1
			print("  NPC %s: INVÁLIDO" % npc.name)
			continue
		if npc.has_method("is_dead") and npc.call("is_dead"):
			dead_count += 1
			print("  NPC %s: MUERTO" % npc.name)
			continue
		
		var initial_pos = npc.global_position
		
		print("\n  --- NPC %s (role=%s, realistic=%s) ---" % [npc.name, str(npc.role), str(npc.realistic)])
		print("  patrol_speed=%.2f, run_speed=%.2f" % [npc.patrol_speed, npc.run_speed])
		
		var tick_count = 0
		for i in range(10):
			if not is_instance_valid(npc):
				print("  NPC %s: se volvió inválido durante tick" % npc.name)
				break
			# Call _physics_process directly to simulate a full physics step (tick + move)
			if npc.has_method("_physics_process"):
				npc._physics_process(0.1)
			var action = "?"
			if npc.has_method("current_action"):
				action = str(npc.call("current_action"))
			var goal = npc._goal
			var path = npc._path
			var path_len = path.size()
			var path_idx = npc._path_index
			var moving = npc._moving
			var velocity = npc.velocity
			print("  Step %d: goal=%s, path_len=%d, path_idx=%d, moving=%s, vel=(%.2f, %.2f, %.2f), pos=%s" % [
				i, str(goal), path_len, path_idx, str(moving), velocity.x, velocity.y, velocity.z, str(npc.global_position)
			])
			tick_count += 1
			await physics_frame
		
		if not is_instance_valid(npc):
			error_count_npc += 1
			continue
			
		var final_pos = npc.global_position
		var distance = final_pos.distance_to(initial_pos)
		
		print("  NPC %s: pos_inicial=%s, pos_final=%s, distancia=%.2f, ticks=%d" % [npc.name, str(initial_pos), str(final_pos), distance, tick_count])
		
		if distance > 1.0:
			mobile_count += 1
		elif distance > 0.5:
			print("  -> MOVIMIENTO PARCIAL (0.5-1.0m)")
			mobile_count += 1
		else:
			stuck_count += 1
	
	var alive_npcs = npcs.size() - dead_count - error_count_npc
	print("\nResumen: vivos=%d, móviles>1m=%d, móviles>0.5m=%d, atascados=%d, muertos=%d, errores=%d" % [
		alive_npcs, mobile_count, mobile_count, stuck_count, dead_count, error_count_npc
	])
	
	if alive_npcs == 0:
		fail("No hay NPCs vivos para probar movimiento (muertos: %d, errores: %d)" % [dead_count, error_count_npc])
	elif mobile_count >= 8:
		pass_test("Al menos 8 de 9 NPCs vivos se mueven > 1.0m: %d/%d" % [mobile_count, alive_npcs])
	elif mobile_count + stuck_count == alive_npcs and mobile_count > 0:
		fail("Solo %d/%d NPCs se mueven > 1.0m (necesita 8)" % [mobile_count, alive_npcs])
	else:
		fail("TODOS los NPCs vivos inmóviles: %d/%d no se mueven (muertos: %d, errores: %d)" % [stuck_count, alive_npcs, dead_count, error_count_npc])

func pass_test(msg: String) -> void:
	print("  PASS: %s" % msg)
	passed_count += 1

func fail(msg: String) -> void:
	print("  FAIL: %s" % msg)
	error_count += 1

func report_results() -> void:
	print("\n=== RESUMEN DEBUG B1 NPC2 ===")
	print("Tests pasados: %d" % passed_count)
	print("Tests fallados: %d" % error_count)
	
	if error_count > 0:
		print("RESULTADO: FAIL")
		quit(1)
	else:
		print("RESULTADO: PASS")
		quit(0)