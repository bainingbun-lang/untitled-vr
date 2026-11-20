extends SceneTree

# B1 (c): los NPC spawneados deben moverse con el tiempo y su IA/navegacion debe correr.

const HarnessScript = preload("res://tests/vr_sim_harness.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _initialize() -> void:
	await process_frame
	await _run_pc()
	await _run_vr()
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


func _moved_count(world, before: Array) -> int:
	var moved: int = 0
	for i in range(world.npcs.size()):
		var npc: Node3D = world.npcs[i]
		if npc == null or not is_instance_valid(npc):
			continue
		if npc.global_position.distance_to(before[i] as Vector3) > 0.75:
			moved += 1
	return moved


func _check_navigation(world) -> void:
	_case = "navegacion viva"
	var nav = world.get("navigation")
	_expect(nav != null, "el mundo tiene rejilla de navegacion")
	if nav == null:
		return
	_expect(int(nav.get("width")) > 0 and int(nav.get("height")) > 0, "la rejilla tiene tamano > 0")
	var free: Array = []
	var width: int = int(nav.get("width"))
	var height: int = int(nav.get("height"))
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			if not bool(nav.call("is_blocked", cell)):
				free.append(cell)
	_expect(free.size() > 10, "hay celdas libres para navegar (%d)" % free.size())
	if free.size() >= 2:
		var a: Vector2i = free[0]
		var b: Vector2i = free[free.size() - 1]
		var path: Dictionary = nav.call("find_path", a, b, {"max_expansions": 8192})
		_expect(bool(path.get("ok", false)), "find_path encuentra camino entre celdas libres (%s)" % str(path.get("reason", "")))


func _check_ai_running(world) -> void:
	_case = "IA corriendo"
	var with_combat: int = 0
	var with_action: int = 0
	for npc in world.npcs:
		if npc == null or not is_instance_valid(npc):
			continue
		if npc.get("combat") != null:
			with_combat += 1
		if not str(npc.call("current_action")).is_empty():
			with_action += 1
	_expect(with_combat == world.npcs.size(), "todos los NPC tienen combat activo (%d/%d)" % [with_combat, world.npcs.size()])
	_expect(with_action == world.npcs.size(), "todos los NPC reportan una accion de IA (%d/%d)" % [with_action, world.npcs.size()])


func _run_pc() -> void:
	_case = "mundo PC: NPC se mueven"
	SessionScript.platform = "pc"
	SessionScript.seed = 4242
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
	_expect(world.npcs.size() >= 6, "hay NPCs en el mundo PC (%d)" % world.npcs.size())
	_check_navigation(world)
	_check_ai_running(world)
	var before: Array = []
	for npc in world.npcs:
		before.append((npc as Node3D).global_position)
	for i in range(240):
		await physics_frame
	var moved: int = _moved_count(world, before)
	_expect(moved >= maxi(1, world.npcs.size() / 2),
		"al menos la mitad de los NPC se movieron tras 240 frames (%d/%d)" % [moved, world.npcs.size()])
	world.queue_free()
	await process_frame
	SessionScript.platform = ""
	SessionScript.platform_override = ""


func _run_vr() -> void:
	_case = "mundo VR: NPC se mueven"
	var harness = HarnessScript.new()
	await harness.start(self, GeneratorScript.generate(7777, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 5,
	}))
	var world = harness.world
	await process_frame
	for i in range(5):
		await physics_frame
	_expect(world.npcs.size() >= 4, "hay NPCs en el mundo VR (%d)" % world.npcs.size())
	_check_navigation(world)
	_check_ai_running(world)
	var before: Array = []
	for npc in world.npcs:
		before.append((npc as Node3D).global_position)
	for i in range(240):
		await physics_frame
		harness.step(2)
	var moved: int = _moved_count(world, before)
	_expect(moved >= maxi(1, world.npcs.size() / 2),
		"al menos la mitad de los NPC se movieron en VR tras 240 frames (%d/%d)" % [moved, world.npcs.size()])
	harness.cleanup()
	await process_frame
