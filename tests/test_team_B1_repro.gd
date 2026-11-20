extends SceneTree

var test_results: Dictionary = {}
var game_world: Node3D = null
var error_count: int = 0
var passed_count: int = 0
var meta: Dictionary = {}

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")
const SaveSystem = preload("res://core/game/save_system.gd")
const ArmedNpc = preload("res://core/game/armed_npc.gd")

func _initialize() -> void:
	await process_frame
	_run()

func _run() -> void:
	meta = GeneratorScript.generate(4242, {
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
	print("Dummies: %d" % game_world.dummies.size())
	print("Props: %d" % game_world.props().size())
	
	await test_weapons_not_duplicated_or_misplaced()
	await test_weapons_grabbable_after_death()
	await test_npcs_mobile()
	await test_second_launch_no_crash()
	report_results()

func test_weapons_not_duplicated_or_misplaced() -> void:
	print("\n=== Test: Armas no duplicadas ni mal colocadas ===")
	var weapon_nodes = find_weapon_nodes()
	var dropped_weapons = find_dropped_weapons()
	
	print("Armas en NPCs/jugador (visuals): %d" % weapon_nodes.size())
	print("Armas caídas (RigidBody3D weapon_pickup): %d" % dropped_weapons.size())
	
	var duplicated = false
	var misplaced = false
	var positions = []
	
	for weapon in dropped_weapons:
		var pos = weapon.global_position
		print("  Arma caída en: %s" % str(pos))
		if pos.distance_to(Vector3.ZERO) < 0.1:
			misplaced = true
			print("  -> PROBLEMA: Arma en origen (0,0,0)")
		for p in positions:
			if pos.distance_to(p) < 0.5:
				duplicated = true
				print("  -> PROBLEMA: Arma duplicada cerca de %s" % str(p))
		positions.append(pos)
	
	var npc_weapon_visuals = []
	for npc in game_world.npcs:
		var mount = npc.get_node_or_null("WeaponMount")
		if mount:
			for child in mount.get_children():
				if child is MeshInstance3D:
					npc_weapon_visuals.append(child)
	
	print("Visuales de arma en NPCs: %d" % npc_weapon_visuals.size())
	
	if duplicated:
		fail("Armas duplicadas detectadas en posiciones cercanas")
	else:
		pass_test("No hay armas duplicadas en el suelo")
	
	if misplaced:
		fail("Armas mal colocadas en origen (0,0,0)")
	else:
		pass_test("Armas no están en origen")

func test_weapons_grabbable_after_death() -> void:
	print("\n=== Test: Armas agarrables tras muerte de NPC ===")
	# Kill a few NPCs to drop weapons
	var dropped_before = find_dropped_weapons().size()
	print("Armas caídas antes: %d" % dropped_before)
	
	var killed = 0
	for npc in game_world.npcs:
		if killed >= 3:
			break
		if is_instance_valid(npc) and npc.has_method("take_damage"):
			# Kill the NPC
			npc.take_damage(1000.0, npc.global_position, Vector3.UP, game_world.actor)
			await process_frame
			killed += 1
	
	await process_frame
	for i in range(5):
		await physics_frame
	
	var dropped_weapons = find_dropped_weapons()
	print("Armas caídas después de matar %d NPCs: %d" % [killed, dropped_weapons.size()])
	
	var grabbable_count = 0
	var not_grabbable = []
	
	for weapon in dropped_weapons:
		var pickable = weapon.has_meta("pickable")
		var in_group = weapon.is_in_group("weapon_pickup")
		var weapon_id = weapon.get_meta("weapon_id", "") if weapon.has_meta("weapon_id") else "unknown"
		print("  Arma %s (weapon_id=%s): pickable=%s, group=%s" % [weapon.name, weapon_id, str(pickable), str(in_group)])
		if pickable or in_group:
			grabbable_count += 1
		else:
			not_grabbable.append("%s (id=%s)" % [weapon.name, weapon_id])
	
	if dropped_weapons.size() == 0:
		fail("NO se droppearon armas al matar NPCs - drop_weapon_on_death puede estar fallando")
	elif grabbable_count == 0:
		fail("Armas caídas (%d) pero NINGUNA agarrable (falta grupo weapon_pickup o meta pickable)" % dropped_weapons.size())
	elif grabbable_count < dropped_weapons.size():
		fail("Algunas armas no agarrables: %s" % str(not_grabbable))
	else:
		pass_test("Todas las armas caídas son agarrables: %d/%d" % [grabbable_count, dropped_weapons.size()])
	
	# Check for duplicated weapons at same position
	var duplicated = false
	var positions = []
	for weapon in dropped_weapons:
		for pos in positions:
			if weapon.global_position.distance_to(pos) < 0.5:
				duplicated = true
				print("  -> PROBLEMA: Arma duplicada en %s" % str(weapon.global_position))
		positions.append(weapon.global_position)
	
	if duplicated:
		fail("Armas duplicadas detectadas en posiciones cercanas tras muerte")
	else:
		pass_test("No hay armas duplicadas tras muerte de NPCs")

func test_npcs_mobile() -> void:
	print("\n=== Test: NPCs móviles ===")
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
		
		var tick_count = 0
		for i in range(10):
			if not is_instance_valid(npc):
				print("  NPC %s: se volvió inválido durante tick" % npc.name)
				break
			if npc.has_method("tick"):
				var result = npc.tick(0.1)
				var action = str(result.get("id", result.get("action", "?")))
				print("  NPC %s tick %d: action=%s" % [npc.name, i, action])
				tick_count += 1
			await physics_frame
		
		if not is_instance_valid(npc):
			error_count_npc += 1
			continue
			
		var final_pos = npc.global_position
		var distance = final_pos.distance_to(initial_pos)
		
		print("  NPC %s: pos_inicial=%s, pos_final=%s, distancia=%.2f, ticks=%d" % [npc.name, str(initial_pos), str(final_pos), distance, tick_count])
		
		if distance > 0.5:
			mobile_count += 1
		else:
			stuck_count += 1
	
	var alive_npcs = npcs.size() - dead_count - error_count_npc
	if alive_npcs == 0:
		fail("No hay NPCs vivos para probar movimiento (muertos: %d, errores: %d)" % [dead_count, error_count_npc])
	elif stuck_count > 0 and mobile_count == 0:
		fail("TODOS los NPCs vivos inmóviles: %d/%d no se mueven (muertos: %d, errores: %d)" % [stuck_count, alive_npcs, dead_count, error_count_npc])
	elif stuck_count > 0:
		fail("Algunos NPCs inmóviles: %d/%d no se mueven (móviles: %d, muertos: %d)" % [stuck_count, alive_npcs, mobile_count, dead_count])
	else:
		pass_test("Todos los NPCs vivos se mueven: %d/%d" % [mobile_count, alive_npcs])

func test_second_launch_no_crash() -> void:
	print("\n=== Test: Segundo arranque sin crash (user:// sucio) ===")
	var save_system = SaveSystem.new()
	var slot = "test_repro_b1_second_launch"
	
	var test_data = {
		"player_pos": Vector3(10, 0, 5),
		"weapon": "assault_rifle",
		"ammo": 30,
		"seed": 4242,
		"world_report": game_world.world_report
	}
	var save_result = save_system.save(slot, test_data)
	if not save_result["ok"]:
		fail("Falló guardado inicial: %s" % save_result["errors"])
		return
	
	print("Guardado OK")
	
	var save_system2 = SaveSystem.new()
	var load_result = save_system2.load_slot(slot)
	if not load_result["ok"]:
		fail("Falló carga tras reinicio (user:// sucio): %s" % load_result["errors"])
		return
	
	print("Carga OK: source=%s, migrated=%s, repaired=%s" % [load_result.get("source"), str(load_result.get("migrated")), str(load_result.get("repaired"))])
	
	var data = load_result["data"]
	if data.get("weapon") != "assault_rifle":
		fail("Datos corruptos tras reinicio: weapon=%s" % str(data.get("weapon")))
		return
	
	for i in range(3):
		var cycle_slot = "test_repro_b1_cycle_%d" % i
		var cycle_data = {"cycle": i, "timestamp": Time.get_unix_time_from_system()}
		var cycle_save = save_system.save(cycle_slot, cycle_data)
		if not cycle_save["ok"]:
			fail("Ciclo %d: falló guardado: %s" % [i, cycle_save["errors"]])
			return
		var cycle_load = save_system2.load_slot(cycle_slot)
		if not cycle_load["ok"]:
			fail("Ciclo %d: falló carga: %s" % [i, cycle_load["errors"]])
			return
	
	pass_test("Guardado/carga funciona correctamente en múltiples ciclos (simula 2do+ arranque)")

func find_weapon_nodes() -> Array:
	var result = []
	if game_world:
		for child in game_world.find_children("*", "MeshInstance3D", true, false):
			if child.name.contains("Weapon") or child.name.contains("weapon"):
				result.append(child)
	return result

func find_dropped_weapons() -> Array:
	var result = []
	if game_world:
		for child in game_world.find_children("*", "RigidBody3D", true, false):
			if child.has_meta("weapon_id") or child.is_in_group("weapon_pickup"):
				result.append(child)
	return result

func pass_test(msg: String) -> void:
	print("  PASS: %s" % msg)
	passed_count += 1

func fail(msg: String) -> void:
	print("  FAIL: %s" % msg)
	error_count += 1

func report_results() -> void:
	print("\n=== RESUMEN REPRODUCCIÓN B1 ===")
	print("Tests pasados: %d" % passed_count)
	print("Tests fallados: %d" % error_count)
	
	if error_count > 0:
		print("RESULTADO: FAIL - %d problemas REPRODUCIDOS hoy" % error_count)
		quit(1)
	else:
		print("RESULTADO: PASS - Todos los síntomas pasan (no reproducidos hoy)")
		quit(0)