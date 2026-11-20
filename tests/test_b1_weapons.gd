extends SceneTree

# B1: armas - una sola por punto de aparicion, bien colocadas, agarrables por codigo y en VR, sin duplicados al reiniciar

const HarnessScript = preload("res://tests/vr_sim_harness.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")
const GrabScript = preload("res://core/vr/vr_grab.gd")
const ArmedNpcScript = preload("res://core/game/armed_npc.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")
const VrGameModeScript = preload("res://core/vr/vr_game_mode.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

func _initialize() -> void:
	await process_frame
	await _run_test_weapon_placement()
	await _run_test_weapon_drop_on_death()
	await _run_test_weapon_grabbable_by_code()
	await _run_test_weapon_grabbable_in_vr()
	await _run_test_no_duplicate_on_restart()
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

func _run_test_weapon_placement() -> void:
	_case = "colocacion de armas al spawnear"
	var harness = HarnessScript.new()
	await harness.start(self, GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 5,
	}))
	var world = harness.world
	await process_frame
	await physics_frame

	# No dropped weapons at start
	var dropped_at_start = []
	for node in world.find_children("DroppedWeapon_*", "Node3D", true, false):
		dropped_at_start.append(node)
	_expect(dropped_at_start.is_empty(), "no hay armas tiradas en el suelo al arrancar (%d)" % dropped_at_start.size())

	# Each NPC has exactly one weapon visual in WeaponMount (if armed)
	for npc in world.npcs:
		var mount: Node = npc.get_node_or_null("WeaponMount")
		_expect(mount != null, "NPC %s tiene WeaponMount" % str(npc.get("npc_id")))
		if mount == null:
			continue
		var models: Array = []
		for child in mount.get_children():
			if str(child.name) != "WeaponVisual":
				models.append(child)
		var weapon_id: String = str(npc.get("weapon_id"))
		if weapon_id.is_empty():
			_expect(models.is_empty(), "NPC %s sin arma no tiene modelo suelto (%d)" % [str(npc.get("npc_id")), models.size()])
		else:
			_expect(models.size() == 1, "NPC %s con arma '%s' tiene exactamente 1 modelo en WeaponMount (%d)" % [
				str(npc.get("npc_id")), weapon_id, models.size()])
			for model in models:
				var box: AABB = _global_aabb(model)
				var dist: float = box.get_center().distance_to(npc.global_position)
				_expect(dist < 2.5, "arma de %s junto al NPC (dist %.2f)" % [str(npc.get("npc_id")), dist])
				var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
				_expect(longest > 0.05 and longest < 5.0, "arma de %s tamano realista (%.2f)" % [str(npc.get("npc_id")), longest])

	# No duplicate NPC positions
	var unique: bool = true
	for i in range(world.npcs.size()):
		for j in range(i + 1, world.npcs.size()):
			if world.npcs[i].global_position.distance_to(world.npcs[j].global_position) < 0.5:
				unique = false
	_expect(unique, "ningun spawn point tiene dos NPCs encima")

	harness.cleanup()
	await process_frame

func _run_test_weapon_drop_on_death() -> void:
	_case = "arma se suelta al morir NPC hostil"
	var harness = HarnessScript.new()
	await harness.start(self, GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 5,
	}))
	var world = harness.world
	await process_frame
	await physics_frame

	# Find a hostile armed NPC
	var victim: Node3D = null
	for npc in world.npcs:
		if str(npc.get("role")) == "hostile" and not str(npc.get("weapon_id")).is_empty() and not bool(npc.call("is_dead")):
			victim = npc
			break
	_expect(victim != null, "existe NPC hostil armado vivo")
	if victim == null:
		harness.cleanup()
		await process_frame
		return

	var weapon_id: String = str(victim.get("weapon_id"))
	victim.take_damage(250.0, victim.global_position + Vector3.UP, Vector3.FORWARD, harness.rig)
	for i in range(5):
		await physics_frame

	_expect(bool(victim.call("is_dead")), "el NPC muere")

	# Check weapon dropped
	var dropped: Array = []
	for node in world.find_children("DroppedWeapon_*", "Node3D", true, false):
		if node.has_meta("weapon_id") and str(node.get_meta("weapon_id")) == weapon_id:
			dropped.append(node)
	_expect(dropped.size() == 1, "se solto exactamente 1 arma (%d)" % dropped.size())
	if dropped.size() == 1:
		var w = dropped[0]
		_expect(w.is_in_group("weapon_pickup"), "arma en grupo weapon_pickup")
		_expect(w.has_meta("pickable") and bool(w.get_meta("pickable")), "arma tiene meta pickable=true")
		_expect(w.is_in_group("grabbable") or w.is_in_group("physics_props"), "arma en grupo grabbable/physics_props")

	harness.cleanup()
	await process_frame

func _run_test_weapon_grabbable_by_code() -> void:
	_case = "agarre por codigo con VrGrab"
	var harness = HarnessScript.new()
	await harness.start(self, GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 5,
	}))
	var world = harness.world
	await process_frame
	await physics_frame

	# Create a test dropped weapon
	var body := RigidBody3D.new()
	body.name = "DroppedWeapon_test"
	body.add_to_group("weapon_pickup")
	body.add_to_group("grabbable")
	body.add_to_group("physics_props")
	body.set_meta("weapon_id", "shotgun")
	body.set_meta("pickable", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.1, 0.1, 0.6)
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	body.global_position = world.npcs[0].global_position + Vector3(0.0, 0.5, 0.0)
	await physics_frame

	var grab = GrabScript.new()
	var pose := Transform3D(Basis.IDENTITY, body.global_position)
	_expect(grab.grab_prop(body, pose, 0.30), "VrGrab.grab_prop agarra el arma")
	_expect(grab.held_prop() == body, "el arma queda agarrada")
	grab.release_prop(Vector3.ZERO)

	# Test pick_up_weapon static method
	var body2 := RigidBody3D.new()
	body2.name = "DroppedWeapon_test2"
	body2.add_to_group("weapon_pickup")
	body2.set_meta("weapon_id", "assault_rifle")
	var shape2 := CollisionShape3D.new()
	var box2 := BoxShape3D.new()
	box2.size = Vector3(0.1, 0.1, 0.6)
	shape2.shape = box2
	body2.add_child(shape2)
	world.add_child(body2)
	body2.global_position = world.npcs[0].global_position + Vector3(1.0, 0.5, 0.0)
	await physics_frame

	var picked: String = ArmedNpcScript.pick_up_weapon(body2)
	_expect(picked == "assault_rifle", "pick_up_weapon devuelve el id")
	await process_frame
	_expect(not is_instance_valid(body2), "pick_up_weapon libera el nodo")

	harness.cleanup()
	await process_frame

func _run_test_weapon_grabbable_in_vr() -> void:
	_case = "agarre en VR con mano"
	var harness = HarnessScript.new()
	await harness.start(self, GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 5,
	}))
	var world = harness.world
	var rig = harness.rig
	await process_frame
	for i in range(5):
		await physics_frame

	# Find hostile armed NPC and kill it
	var victim: Node3D = null
	for npc in world.npcs:
		if str(npc.get("role")) == "hostile" and not str(npc.get("weapon_id")).is_empty() and not bool(npc.call("is_dead")):
			victim = npc
			break
	_expect(victim != null, "existe NPC hostil armado vivo")
	if victim == null:
		harness.cleanup()
		await process_frame
		return

	var weapon_id: String = str(victim.get("weapon_id"))
	victim.take_damage(250.0, victim.global_position + Vector3.UP, Vector3.FORWARD, rig)
	for i in range(5):
		await physics_frame

	_expect(bool(victim.call("is_dead")), "el NPC muere")

	# Find dropped weapon
	var dropped: Node3D = null
	for node in world.find_children("DroppedWeapon_*", "Node3D", true, false):
		if node.has_meta("weapon_id") and str(node.get_meta("weapon_id")) == weapon_id:
			dropped = node
			break
	_expect(dropped != null and is_instance_valid(dropped), "arma soltada existe")

	# Left hand picks up weapon from ground
	var left_hand = rig.left_hand
	_expect(str(left_hand.weapon_id).is_empty(), "mano izquierda libre al inicio")
	harness.set_hand_world("left", dropped.global_position)
	harness.input.grips["left"] = 1.0
	harness.step(6, true)

	# The hand should be able to grab the prop physically (via VrGrab)
	_expect(not str(left_hand.weapon_id).is_empty(), "mano VR recoge y equipa el arma del suelo")

	# Release
	harness.input.grips["left"] = 0.0
	harness.step(2, true)

	harness.cleanup()
	await process_frame

func _run_test_no_duplicate_on_restart() -> void:
	_case = "sin duplicados al reiniciar mundo"
	# First world setup
	var meta = GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 5,
	})
	var world1 = WorldScene.instantiate()
	root.add_child(world1)
	await process_frame
	world1.setup(meta)
	await process_frame
	await physics_frame

	# Count NPCs and weapons in first world
	var npcs1 = world1.npcs.size()
	var dropped1 = 0
	for node in world1.find_children("DroppedWeapon_*", "Node3D", true, false):
		dropped1 += 1
	_expect(dropped1 == 0, "mundo 1: sin armas tiradas al inicio")

	# Kill an NPC to drop a weapon
	var victim: Node3D = null
	for npc in world1.npcs:
		if str(npc.get("role")) == "hostile" and not str(npc.get("weapon_id")).is_empty() and not bool(npc.call("is_dead")):
			victim = npc
			break
	if victim != null:
		victim.take_damage(250.0, victim.global_position + Vector3.UP, Vector3.FORWARD, world1.actor)
		for i in range(5):
			await physics_frame

	var dropped_after_kill = 0
	for node in world1.find_children("DroppedWeapon_*", "Node3D", true, false):
		dropped_after_kill += 1
	_expect(dropped_after_kill >= 1, "mundo 1: arma solta tras muerte")

	# Free first world (simulate restart)
	world1.free()
	await process_frame
	await physics_frame

	# Second world setup (same seed = same layout)
	var world2 = WorldScene.instantiate()
	root.add_child(world2)
	await process_frame
	world2.setup(meta)
	await process_frame
	await physics_frame

	# Check no leftover weapons from first world
	var dropped2 = 0
	for node in world2.find_children("DroppedWeapon_*", "Node3D", true, false):
		dropped2 += 1
	_expect(dropped2 == 0, "mundo 2: sin armas heredadas del mundo anterior (%d)" % dropped2)

	# Check NPC count matches
	_expect(world2.npcs.size() == npcs1, "mismo numero de NPCs en reinicio (%d vs %d)" % [world2.npcs.size(), npcs1])

	world2.free()
	await process_frame

func _global_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	var nodes: Array = [node]
	nodes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for item in nodes:
		if not (item is MeshInstance3D) or (item as MeshInstance3D).mesh == null:
			continue
		var mi := item as MeshInstance3D
		var box: AABB = mi.global_transform * mi.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result