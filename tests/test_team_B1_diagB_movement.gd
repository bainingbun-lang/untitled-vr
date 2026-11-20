extends SceneTree

# B1 Diagnostic: Compare NPC movement in test vs real game scenarios
# Focus: Check if obstacles block straight-line movement

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")
const ArmedNpc = preload("res://core/game/armed_npc.gd")

var _checks: int = 0
var _failures: Array = []

func _initialize() -> void:
	await process_frame
	await _run_diagnostics()
	print("Diagnostics complete. Checks: %d, Failures: %d" % [_checks, _failures.size()])
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
		_failures.append(message)
		print("  ASSERTION FAILED: " + message)
	else:
		print("  OK: " + message)

func _run_diagnostics() -> void:
	print("=== DIAGNOSTIC START ===")
	
	await _check_obstacle_blocking()
	await _check_pathfinding_trigger()
	await _check_sanitize_goal_behavior()

func _check_obstacle_blocking() -> void:
	print("\n--- Test: Obstacle blocking in real game map ---")
	var meta: Dictionary = GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 5,
	})
	meta["max_npcs"] = 8
	SessionScript.map_meta = meta.duplicate(true)
	ArmedNpc.limits_override.clear()
	ArmedNpc.limits_override["pc"] = 8
	
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	world.setup(meta)
	await process_frame
	for i in range(5):
		await physics_frame
	
	# Check what obstacles exist in the world
	var static_bodies: Array = world.get_children()
	print("  World children count: %d" % world.get_child_count())
	
	# Check navigation grid for blocked cells near NPCs
	var nav = world.navigation
	if nav != null:
		var width: int = int(nav.get("width"))
		var height: int = int(nav.get("height"))
		var npcs_with_blocked_neighbors = 0
		for npc in world.npcs:
			var pos: Vector3 = npc.global_position
			var cell: Vector2i = nav.call("world_to_cell_2d", Vector2(pos.x, pos.z), 1.0)
			var blocked_count = 0
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var c: Vector2i = Vector2i(cell.x + dx, cell.y + dz)
					if c.x >= 0 and c.x < width and c.y >= 0 and c.y < height:
						if bool(nav.call("is_blocked", c)):
							blocked_count += 1
			if blocked_count > 0:
				npcs_with_blocked_neighbors += 1
			print("  NPC %s at (%.1f,%.1f) -> cell (%d,%d) blocked neighbors: %d" % [
				npc.name, pos.x, pos.z, cell.x, cell.y, blocked_count
			])
		_expect(npcs_with_blocked_neighbors > 0, "al menos un NPC tiene celdas bloqueadas cerca")
	
	world.queue_free()
	await process_frame
	ArmedNpc.limits_override.clear()

func _check_pathfinding_trigger() -> void:
	print("\n--- Test: Pathfinding trigger conditions ---")
	var meta: Dictionary = GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 5,
	})
	meta["max_npcs"] = 8
	SessionScript.map_meta = meta.duplicate(true)
	ArmedNpc.limits_override.clear()
	ArmedNpc.limits_override["pc"] = 8
	
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	world.setup(meta)
	await process_frame
	for i in range(5):
		await physics_frame
	
	var civilian: Node3D = null
	for npc in world.npcs:
		if str(npc.role) == "civilian":
			civilian = npc
			break
	
	if civilian != null:
		print("  Tracking civilian: %s" % civilian.name)
		var path_updates = 0
		var last_path_size = 0
		for frame in range(240):
			await physics_frame
			if frame % 30 == 0:
				var path: Array = civilian.get("_path") if "_path" in civilian else []
				var path_index: int = int(civilian.get("_path_index")) if "_path_index" in civilian else 0
				var goal: Vector3 = civilian.get("_goal") if "_goal" in civilian else Vector3.ZERO
				var path_goal: Vector3 = civilian.get("_path_goal") if "_path_goal" in civilian else Vector3.ZERO
				var repath_cooldown: float = float(civilian.get("_repath_cooldown")) if "_repath_cooldown" in civilian else 0.0
				var stuck_time: float = float(civilian.get("_stuck_time")) if "_stuck_time" in civilian else 0.0
				var moving: bool = bool(civilian.get("_moving")) if "_moving" in civilian else false
				var action: String = str(civilian.call("current_action")) if civilian.has_method("current_action") else "?"
				var pos: Vector3 = civilian.global_position
				print("    Frame %d: pos=(%.1f,%.1f) action=%s goal=(%.1f,%.1f) path_goal=(%.1f,%.1f) path=%d/%d repath_cd=%.2f stuck=%.2f moving=%s" % [
					frame, pos.x, pos.z, action, goal.x, goal.z, path_goal.x, path_goal.z, path_index, path.size(), repath_cooldown, stuck_time, moving
				])
				if path.size() != last_path_size:
					path_updates += 1
					last_path_size = path.size()
		
		# Check total movement
		var start_pos: Vector3 = civilian.global_position
		for i in range(240):
			await physics_frame
		var end_pos: Vector3 = civilian.global_position
		var moved: float = start_pos.distance_to(end_pos)
		print("  Total movement over 240 frames: %.2f units" % moved)
		_expect(moved > 2.0, "civilian se movio mas de 2 unidades en 240 frames (movio %.2f)" % moved)
		_expect(path_updates > 0, "pathfinding se actualizo al menos una vez (%d actualizaciones)" % path_updates)
	else:
		print("  No civilian NPC found, skipping pathfinding tracking")
	
	world.queue_free()
	await process_frame
	ArmedNpc.limits_override.clear()

func _check_sanitize_goal_behavior() -> void:
	print("\n--- Test: _sanitize_goal behavior for flee ---")
	var meta: Dictionary = GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 5,
	})
	meta["max_npcs"] = 8
	SessionScript.map_meta = meta.duplicate(true)
	ArmedNpc.limits_override.clear()
	ArmedNpc.limits_override["pc"] = 8
	
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	world.setup(meta)
	await process_frame
	for i in range(5):
		await physics_frame
	
	var civilian: Node3D = null
	for npc in world.npcs:
		if str(npc.role) == "civilian":
			civilian = npc
			break
	
	if civilian != null:
		print("  Tracking civilian goal changes: %s" % civilian.name)
		var last_goal: Vector3 = Vector3.ZERO
		var goal_changes: int = 0
		for frame in range(120):
			await physics_frame
			var goal: Vector3 = civilian.get("_goal") if "_goal" in civilian else Vector3.ZERO
			if (goal - last_goal).length() > 0.5:
				goal_changes += 1
				print("    Frame %d: goal changed to (%.1f,%.1f,%.1f) delta=%.2f" % [
					frame, goal.x, goal.y, goal.z, (goal - last_goal).length()
				])
				last_goal = goal
		print("  Total goal changes in 120 frames: %d" % goal_changes)
		_expect(goal_changes > 0, "goal cambio al menos una vez en 120 frames (%d cambios)" % goal_changes)
	else:
		print("  No civilian NPC found, skipping goal tracking")
	
	world.queue_free()
	await process_frame
	ArmedNpc.limits_override.clear()