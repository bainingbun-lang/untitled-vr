extends SceneTree

# B1 Diagnostic: Compare NPC movement in test vs real game scenarios
# Investigates why NPCs don't move in real game but do in tests

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")
const NPCNavigationScript = preload("res://core/npc/npc_navigation.gd")

var _checks: int = 0
var _failures: Array = []

func _initialize() -> void:
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
	
	# Test 1: Check navigation grid from test map (GeneratorScript)
	print("\n--- Test 1: Test map navigation ---")
	_check_test_map_navigation()
	
	# Test 2: Check navigation grid from real game map (MapWorldBuilder)
	print("\n--- Test 2: Real game map navigation ---")
	_check_real_game_navigation()
	
	# Test 3: Check NPC internal state after spawn
	print("\n--- Test 3: NPC internal state ---")
	_check_npc_state()
	
	# Test 4: Check waypoint/goal system
	print("\n--- Test 4: Waypoint/goal system ---")
	_check_waypoint_system()

func _check_test_map_navigation() -> void:
	SessionScript.platform = "pc"
	SessionScript.seed = 4242
	var meta: Dictionary = GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 5,
	})
	_expect(bool(meta.get("ok", false)), "MapGenerator meta ok")
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
	
	_expect(world.npcs.size() >= 6, "Test map: hay NPCs (%d)" % world.npcs.size())
	_expect(world.navigation != null, "Test map: navegacion existe")
	if world.navigation:
		var width: int = int(world.navigation.get("width"))
		var height: int = int(world.navigation.get("height"))
		var blocked_count: int = 0
		var free_cells: Array = []
		for y in range(height):
			for x in range(width):
				var cell := Vector2i(x, y)
				if bool(world.navigation.call("is_blocked", cell)):
					blocked_count += 1
				else:
					free_cells.append(cell)
		_expect(free_cells.size() > 10, "Test map: celdas libres (%d)" % free_cells.size())
		print("  Navigation: %dx%d, blocked: %d, free: %d" % [width, height, blocked_count, free_cells.size()])
		
		if free_cells.size() >= 2:
			var a: Vector2i = free_cells[0]
			var b: Vector2i = free_cells[free_cells.size() - 1]
			var path: Dictionary = world.navigation.call("find_path", a, b, {"max_expansions": 8192})
			_expect(bool(path.get("ok", false)), "Test map: find_path ok (%s)" % str(path.get("reason", "")))
			if bool(path.get("ok", false)):
				print("  Path length: %d" % path.get("path", []).size())
	
	world.queue_free()
	await process_frame
	ArmedNpc.limits_override.clear()

func _check_real_game_navigation() -> void:
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
	
	_expect(world.npcs.size() >= 6, "Real game: hay NPCs (%d)" % world.npcs.size())
	_expect(world.navigation != null, "Real game: navegacion existe")
	if world.navigation:
		var width: int = int(world.navigation.get("width"))
		var height: int = int(world.navigation.get("height"))
		var blocked_count: int = 0
		var free_cells: Array = []
		for y in range(height):
			for x in range(width):
				var cell := Vector2i(x, y)
				if bool(world.navigation.call("is_blocked", cell)):
					blocked_count += 1
				else:
					free_cells.append(cell)
		_expect(free_cells.size() > 10, "Real game: celdas libres (%d)" % free_cells.size())
		print("  Navigation: %dx%d, blocked: %d, free: %d" % [width, height, blocked_count, free_cells.size()])
		
		if free_cells.size() >= 2:
			var a: Vector2i = free_cells[0]
			var b: Vector2i = free_cells[free_cells.size() - 1]
			var path: Dictionary = world.navigation.call("find_path", a, b, {"max_expansions": 8192})
			_expect(bool(path.get("ok", false)), "Real game: find_path ok (%s)" % str(path.get("reason", "")))
			if bool(path.get("ok", false)):
				print("  Path length: %d" % path.get("path", []).size())
	
	# Check navigation grid source
	var nav = world.navigation
	if nav != null:
		var source: String = str(nav.get("source", "unknown"))
		var cell_size: float = float(nav.get("cell_size", 0))
		print("  Nav source: %s, cell_size: %.2f" % [source, cell_size])
	
	world.queue_free()
	await process_frame
	ArmedNpc.limits_override.clear()

func _check_npc_state() -> void:
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
	
	for npc in world.npcs:
		var role: String = str(npc.get("role"))
		var has_combat: bool = npc.get("combat") != null
		var action: String = str(npc.call("current_action"))
		var wait_left: float = float(npc.get("_wait_left"))
		var wp_has: bool = bool(npc.get("_wp_has"))
		var wp: Vector3 = npc.get("_wp")
		var goal: Vector3 = npc.get("_goal")
		var path: Array = npc.get("_path") if npc.has_method("_path") else []
		var path_index: int = int(npc.get("_path_index")) if npc.has_method("_path_index") else 0
		
		print("  NPC %s (role=%s): action=%s wait=%.2f wp_has=%s wp=%s goal=%s path=%d idx=%d combat=%s" % [
			npc.name, role, action, wait_left, wp_has, wp, goal, path.size(), path_index, has_combat
		])
		
		# Check _pending_options
		if npc.has_method("_pending_options"):
			var opts: Dictionary = npc.get("_pending_options")
			var realistic: bool = bool(opts.get("realistic", false))
			var patrol_pts: Array = opts.get("patrol_points", [])
			var attack_pts: Array = opts.get("attack_points", [])
			var cover_pts: Array = opts.get("cover_points", [])
			var tick_rate: float = float(opts.get("tick_rate", 0))
			var nav_cell_size: float = float(opts.get("nav_cell_size", 0))
			var has_bounds: bool = opts.has("bounds")
			var has_nav: bool = opts.has("navigation")
			print("    options: realistic=%s patrol=%d attack=%d cover=%d tick=%.2f nav_cell=%.2f bounds=%s nav=%s" % [
				realistic, patrol_pts.size(), attack_pts.size(), cover_pts.size(), tick_rate, nav_cell_size, has_bounds, has_nav
			])
	
	world.queue_free()
	await process_frame
	ArmedNpc.limits_override.clear()

func _check_waypoint_system() -> void:
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
	
	# Find a civilian NPC
	var civilian: Node3D = null
	for npc in world.npcs:
		if str(npc.get("role")) == "civilian":
			civilian = npc
			break
	
	if civilian != null:
		print("  Tracking civilian: %s" % civilian.name)
		# Run for some frames and track state
		for frame in range(120):
			await physics_frame
			if frame % 30 == 0:
				var action: String = str(civilian.call("current_action"))
				var pos: Vector3 = civilian.global_position
				var goal: Vector3 = civilian.get("_goal")
				var wp_has: bool = bool(civilian.get("_wp_has"))
				var wp: Vector3 = civilian.get("_wp")
				var wait_left: float = float(civilian.get("_wait_left"))
				var path: Array = civilian.get("_path") if civilian.has_method("_path") else []
				var path_index: int = int(civilian.get("_path_index")) if civilian.has_method("_path_index") else 0
				var tick_timer: float = float(civilian.get("_tick_timer")) if civilian.has_method("_tick_timer") else 0
				print("    Frame %d: pos=(%.1f,%.1f,%.1f) action=%s goal=(%.1f,%.1f,%.1f) wp_has=%s wp=(%.1f,%.1f,%.1f) wait=%.2f path=%d/%d tick=%.2f" % [
					frame, pos.x, pos.y, pos.z, action, goal.x, goal.y, goal.z, wp_has, wp.x, wp.y, wp.z, wait_left, path_index, path.size(), tick_timer
				])
		
		# Check movement
		var start_pos: Vector3 = civilian.global_position
		for i in range(120):
			await physics_frame
		var end_pos: Vector3 = civilian.global_position
		var moved: float = start_pos.distance_to(end_pos)
		_expect(moved > 1.0, "Civilian moved %.2f units" % moved)
		print("  Civilian moved: %.2f units" % moved)
	
	world.queue_free()
	await process_frame
	ArmedNpc.limits_override.clear()