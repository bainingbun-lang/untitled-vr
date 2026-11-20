extends SceneTree

var game_world: Node3D = null
var passed: int = 0
var failed: int = 0

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SaveSystem = preload("res://core/game/save_system.gd")

func _initialize() -> void:
	await process_frame
	_run()

func _run() -> void:
	var meta = GeneratorScript.generate(99999, {
		"width": 24, "height": 18, "obstacle_density": 0.1, "spawn_count": 4,
	})
	
	game_world = WorldScene.instantiate()
	root.add_child(game_world)
	await process_frame
	game_world.setup(meta)
	await process_frame
	
	# Ciclo 1: Spawn, matar NPCs, limpiar
	test_spawn_kill_cleanup_cycle(1)
	
	# Ciclo 2: Re-setup world (simula 2do arranque)
	test_world_reinit_cycle(2)
	
	# Ciclo 3: Save/load
	test_save_load_cycle(3)
	
	report()

func test_spawn_kill_cleanup_cycle(cycle: int) -> void:
	print("\n=== Ciclo %d: Spawn/Kill/Cleanup ===" % cycle)
	
	# Contar nodos antes
	var nodes_before = count_nodes_in_tree()
	print("  Nodos antes: %d" % nodes_before)
	
	# Matar 3 NPCs
	var killed = 0
	for npc in game_world.npcs:
		if killed >= 3:
			break
		if is_instance_valid(npc) and npc.has_method("take_damage"):
			npc.take_damage(1000.0, npc.global_position, Vector3.UP, game_world.actor)
			await process_frame
			killed += 1
	
	# Esperar física para que ragdolls se creen
	for i in range(5):
		await physics_frame
	
	var nodes_after_kill = count_nodes_in_tree()
	print("  Nodos tras muertes: %d (diff: %d)" % [nodes_after_kill, nodes_after_kill - nodes_before])
	
	# Limpiar world (simula _discard)
	game_world.call("_discard", game_world)
	await process_frame  # CRÍTICO: await frame para queue_free
	
	var nodes_after_cleanup = count_nodes_in_tree()
	print("  Nodos tras cleanup: %d (diff: %d)" % [nodes_after_cleanup, nodes_after_cleanup - nodes_before])
	
	if nodes_after_cleanup > nodes_before + 5:  # Tolerancia pequeña
		fail("Ciclo %d: LEAK detectado - %d nodos extra tras cleanup" % [cycle, nodes_after_cleanup - nodes_before])
	else:
		pass_test("Ciclo %d: Sin leaks significativos" % cycle)

func test_world_reinit_cycle(cycle: int) -> void:
	print("\n=== Ciclo %d: World Re-init (2do arranque sim) ===" % cycle)
	
	var nodes_before = count_nodes_in_tree()
	
	# Re-setup world
	game_world = WorldScene.instantiate()
	root.add_child(game_world)
	await process_frame
	
	var meta = GeneratorScript.generate(88888 + cycle, {
		"width": 24, "height": 18, "obstacle_density": 0.1, "spawn_count": 4,
	})
	game_world.setup(meta)
	await process_frame
	
	var nodes_after = count_nodes_in_tree()
	print("  Nodos tras re-init: %d (diff: %d)" % [nodes_after, nodes_after - nodes_before])
	
	if nodes_after > nodes_before + 10:
		fail("Ciclo %d: LEAK en re-init - %d nodos extra" % [cycle, nodes_after - nodes_before])
	else:
		pass_test("Ciclo %d: Re-init limpio" % cycle)

func test_save_load_cycle(cycle: int) -> void:
	print("\n=== Ciclo %d: Save/Load ===" % cycle)
	
	var save_sys = SaveSystem.new()
	var slot = "auditor2_leak_test_%d" % cycle
	var data = {
		"player_pos": Vector3(10, 0, 5),
		"weapon": "assault_rifle",
		"ammo": 30,
		"seed": 99999 + cycle,
		"world_report": game_world.world_report
	}
	
	var save_result = save_sys.save(slot, data)
	if not save_result["ok"]:
		fail("Ciclo %d: Save falló: %s" % [cycle, save_result["errors"]])
		return
	
	var save_sys2 = SaveSystem.new()
	var load_result = save_sys2.load_slot(slot)
	if not load_result["ok"]:
		fail("Ciclo %d: Load falló: %s" % [cycle, load_result["errors"]])
		return
	
	pass_test("Ciclo %d: Save/Load OK" % cycle)

func count_nodes_in_tree() -> int:
	var count = 0
	var to_visit = [root]
	while to_visit.size() > 0:
		var node = to_visit.pop_back()
		count += 1
		for child in node.get_children():
			to_visit.append(child)
	return count

func pass_test(msg: String) -> void:
	print("  PASS: %s" % msg)
	passed += 1

func fail(msg: String) -> void:
	print("  FAIL: %s" % msg)
	failed += 1

func report() -> void:
	print("\n=== RESUMEN AUDITOR2 MEMORY LEAKS ===")
	print("Pasados: %d, Fallados: %d" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)