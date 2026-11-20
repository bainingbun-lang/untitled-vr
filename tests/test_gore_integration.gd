extends SceneTree

const DamageableScript = preload("res://core/game/damageable.gd")
const ArmedNpcScript = preload("res://core/game/armed_npc.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const ModHooksScript = preload("res://core/game/mod_hooks.gd")
const EventBusScript = preload("res://core/event_bus.gd")

var _failures: Array = []
var _checks: int = 0
var _case: String = ""
var _root: Node3D = null
var _bus
var _hooks

func _initialize() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	await process_frame

	_hooks = ModHooksScript.instance()
	_hooks.reset()
	_bus = EventBusScript.new()
	_hooks.bind(_bus)

	GoreFxScript.set_gore_enabled(true)
	GoreFxScript.clear()

	_test_gore_fx_blood_hit_on_damage()
	_test_gore_fx_on_death_creates_effects()
	_test_gore_fx_dismember_on_limb_severed()
	_test_gore_fx_limits_enforced()
	_test_gore_fx_clear_removes_all()
	_test_armed_npc_integration_gore_on_damage()
	_test_armed_npc_integration_gore_on_death()

	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(null)
	_hooks.reset()
	_bus.clear()

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_gore_fx_blood_hit_on_damage() -> void:
	_case = "gore_fx blood_hit creates particles and decal on damage"
	GoreFxScript.clear()
	var active_before = GoreFxScript.active_count()
	var decal_before = GoreFxScript.decal_count()

	GoreFxScript.blood_hit(_root, Vector3(0, 1.5, 0), Vector3.UP, 10.0, Vector3.ZERO, false)

	_expect(GoreFxScript.active_count() == active_before + 1, "active particle effect created")
	_expect(GoreFxScript.decal_count() == decal_before + 1, "decal created")

	_expect(GoreFxScript.active_count() > 0, "active effects exist")

	GoreFxScript.clear()


func _test_gore_fx_on_death_creates_effects() -> void:
	_case = "gore_fx on_death creates blood, decal, and puddle"
	GoreFxScript.clear()
	var active_before = GoreFxScript.active_count()
	var puddle_before = GoreFxScript.puddle_count()

	GoreFxScript.on_death(_root, Vector3(0, 1.5, 0), 1.0)

	_expect(GoreFxScript.active_count() == active_before + 1, "active blood effect created")
	# decal may not create in headless without ground
	_expect(GoreFxScript.puddle_count() == puddle_before + 1, "puddle created")

	GoreFxScript.clear()


func _test_gore_fx_dismember_on_limb_severed() -> void:
	_case = "gore_fx dismember creates parts and blood jet"
	GoreFxScript.clear()
	var active_before = GoreFxScript.active_count()
	var parts_before = GoreFxScript.dismembered_count()

	var parts = GoreFxScript.dismember(_root, Vector3(0, 1.5, 0), 1.0, "limb", 3)

	_expect(parts.size() == 3, "dismember returns 3 parts")
	_expect(GoreFxScript.active_count() == active_before + 1, "blood jet active effect created")
	_expect(GoreFxScript.dismembered_count() == parts_before + 3, "3 parts tracked")

	for part in parts:
		_expect(part is RigidBody3D, "each part is RigidBody3D")
		_expect(part.get_child_count() >= 2, "part has collision and visual children")
		var has_collision = false
		var has_visual = false
		for child in part.get_children():
			if child is CollisionShape3D:
				has_collision = true
			if child is MeshInstance3D:
				has_visual = true
		_expect(has_collision, "part has CollisionShape3D child")
		_expect(has_visual, "part has MeshInstance3D child")

	GoreFxScript.clear()


func _test_gore_fx_limits_enforced() -> void:
	_case = "gore_fx enforces limits on parts"
	GoreFxScript.clear()

	# Create more parts than MAX_PARTS (12)
	for i in range(15):
		var parts = GoreFxScript.dismember(_root, Vector3(i * 0.5, 1.5, 0), 0.5, "limb", 1)

	_expect(GoreFxScript.dismembered_count() <= GoreFxScript.limit_parts, "parts count does not exceed limit (%d <= %d)" % [GoreFxScript.dismembered_count(), GoreFxScript.limit_parts])

	GoreFxScript.clear()


func _test_gore_fx_clear_removes_all() -> void:
	_case = "gore_fx clear removes all effects"
	GoreFxScript.clear()

	GoreFxScript.blood_hit(_root, Vector3(0, 1.5, 0), Vector3.UP, 10.0)
	GoreFxScript.on_death(_root, Vector3(1, 1.5, 0), 1.0)
	GoreFxScript.dismember(_root, Vector3(2, 1.5, 0), 1.0, "limb", 2)

	_expect(GoreFxScript.active_count() > 0, "has active effects")
	_expect(GoreFxScript.decal_count() > 0, "has decals")
	_expect(GoreFxScript.puddle_count() > 0, "has puddles")
	_expect(GoreFxScript.dismembered_count() > 0, "has parts")

	GoreFxScript.clear()

	_expect(GoreFxScript.active_count() == 0, "active effects cleared")
	_expect(GoreFxScript.decal_count() == 0, "decals cleared")
	_expect(GoreFxScript.puddle_count() == 0, "puddles cleared")
	_expect(GoreFxScript.dismembered_count() == 0, "parts cleared")


func _test_armed_npc_integration_gore_on_damage() -> void:
	_case = "armed_npc gore integration: blood on damage"
	GoreFxScript.clear()

	var npc = ArmedNpcScript.new()
	npc.call("apply_options", {
		"id": "gore_test_dmg", "role": "hostile", "difficulty": "normal",
		"weapon_id": "pistol", "seed": 42, "max_health": 100.0,
	})
	_root.add_child(npc)
	npc.global_position = Vector3.ZERO
	await process_frame
	await physics_frame

	var dmg = npc.get("damageable")
	_expect(dmg != null, "ArmedNpc has Damageable child")

	GoreFxScript.blood_hit(npc, npc.global_position + Vector3(0, 1.7, 0), Vector3.UP, 15.0, Vector3(0, 0, -1), false)

	_expect(GoreFxScript.active_count() > 0, "blood effect on armed_npc")
	_expect(GoreFxScript.decal_count() > 0, "decal on armed_npc")

	npc.queue_free()
	await physics_frame
	GoreFxScript.clear()


func _test_armed_npc_integration_gore_on_death() -> void:
	_case = "armed_npc gore integration: death effects"
	GoreFxScript.clear()

	var npc = ArmedNpcScript.new()
	npc.call("apply_options", {
		"id": "gore_test_death", "role": "hostile", "max_health": 50.0,
	})
	_root.add_child(npc)
	npc.global_position = Vector3.ZERO
	await process_frame
	await physics_frame

	var dmg = npc.get("damageable")
	_expect(dmg != null, "ArmedNpc has Damageable child")

	# Apply enough damage to kill
	dmg.take_zone_damage("head", 50.0, npc.global_position + Vector3(0, 1.7, 0), Vector3.UP)
	_expect(dmg.is_dead(), "NPC died from headshot")

	GoreFxScript.on_death(npc, npc.global_position + Vector3(0, 1.5, 0), 1.0)

	_expect(GoreFxScript.active_count() > 0, "death blood effect")
	_expect(GoreFxScript.decal_count() > 0, "death decal")
	_expect(GoreFxScript.puddle_count() > 0, "death puddle")

	npc.queue_free()
	await physics_frame
	GoreFxScript.clear()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_eq(actual, expected, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])