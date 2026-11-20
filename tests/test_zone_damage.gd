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

	GoreFxScript.set_gore_enabled(false)

	_test_damageable_zone_multipliers()
	_test_damageable_take_zone_damage()
	_test_damageable_wound_hooks()
	_test_damageable_dismember_hooks()
	_test_armed_npc_zone_damage_integration()
	_test_armed_npc_hit_zones_on_collision()
	_test_gore_fx_dismember_called()
	_test_mod_hooks_damage_dealt_payload()

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


func _test_damageable_zone_multipliers() -> void:
	_case = "damageable zone multipliers"
	var dmg = DamageableScript.new()
	dmg.max_health = 100.0
	dmg.health = 100.0

	_expect_eq(dmg.multiplier_for("head"), 2.0, "head multiplier = 2.0")
	_expect_eq(dmg.multiplier_for("neck"), 2.0, "neck multiplier = 2.0")
	_expect_eq(dmg.multiplier_for("torso"), 1.0, "torso multiplier = 1.0")
	_expect_eq(dmg.multiplier_for("body"), 1.0, "body multiplier = 1.0")
	_expect_eq(dmg.multiplier_for("limb"), 0.55, "limb multiplier = 0.55")
	_expect_eq(dmg.multiplier_for("leg"), 0.55, "leg multiplier = 0.55")
	_expect_eq(dmg.multiplier_for("arm"), 0.55, "arm multiplier = 0.55")
	_expect_eq(dmg.multiplier_for("hand"), 0.45, "hand multiplier = 0.45")
	_expect_eq(dmg.multiplier_for("foot"), 0.45, "foot multiplier = 0.45")
	_expect_eq(dmg.multiplier_for("unknown"), 1.0, "unknown zone defaults to 1.0")
	_expect_eq(dmg.multiplier_for(" HEAD "), 2.0, "zone name trimmed and lowercased")

	dmg.free()


func _test_damageable_take_zone_damage() -> void:
	_case = "damageable take_zone_damage applies multiplier"
	var dmg = DamageableScript.new()
	dmg.max_health = 100.0
	dmg.health = 100.0

	dmg.take_zone_damage("head", 10.0, Vector3.ZERO, Vector3.UP)
	_expect(is_equal_approx(dmg.health, 80.0), "head shot 10 * 2.0 = 20 damage, health = 80")

	dmg.take_zone_damage("limb", 10.0, Vector3.ZERO, Vector3.UP)
	_expect(is_equal_approx(dmg.health, 74.5), "limb shot 10 * 0.55 = 5.5 damage, health = 74.5")

	dmg.take_zone_damage("torso", 10.0, Vector3.ZERO, Vector3.UP)
	_expect(is_equal_approx(dmg.health, 64.5), "torso shot 10 * 1.0 = 10 damage, health = 64.5")

	dmg.take_zone_damage("hand", 10.0, Vector3.ZERO, Vector3.UP)
	_expect(is_equal_approx(dmg.health, 60.0), "hand shot 10 * 0.45 = 4.5 damage, health = 60.0")

	dmg.free()


func _test_damageable_wound_hooks() -> void:
	_case = "damageable wound_created hook emitted"
	var seen: Array = [0, {}]
	var handler := func(payload):
		seen[0] = int(seen[0]) + 1
		seen[1] = payload.duplicate(true)
	var sub_id: int = _bus.subscribe("wound_created", handler, "test.wound")

	var dmg = DamageableScript.new()
	dmg.max_health = 100.0
	dmg.health = 100.0

	dmg.take_zone_damage("limb", 20.0, Vector3.ZERO, Vector3.UP)
	_expect(int(seen[0]) == 1, "wound_created emitted once")
	_expect((seen[1] as Dictionary).has("zone"), "payload has zone")
	_expect(str((seen[1] as Dictionary).get("zone")) == "limb", "payload zone = limb")
	_expect((seen[1] as Dictionary).has("severity"), "payload has severity")
	_expect((seen[1] as Dictionary).get("severity") > 0.0, "severity > 0")

	_bus.unsubscribe(sub_id)
	dmg.free()


func _test_damageable_dismember_hooks() -> void:
	_case = "damageable limb_severed hook on death with limb zone"
	var seen: Array = [0, {}]
	var handler := func(payload):
		seen[0] = int(seen[0]) + 1
		seen[1] = payload.duplicate(true)
	var sub_id: int = _bus.subscribe("limb_severed", handler, "test.dismember")

	var dmg = DamageableScript.new()
	dmg.max_health = 100.0
	dmg.health = 100.0
	dmg.set_meta("dismemberable", true)

	dmg.take_zone_damage("limb", 200.0, Vector3.ZERO, Vector3.UP)
	_expect(int(seen[0]) == 1, "limb_severed emitted once on death")
	_expect(str((seen[1] as Dictionary).get("limb")) == "limb", "payload limb = limb")
	_expect(dmg.is_dead(), "damageable marked dead")

	_bus.unsubscribe(sub_id)
	dmg.free()


func _test_armed_npc_zone_damage_integration() -> void:
	_case = "armed_npc take_zone_damage forwards to damageable"
	var npc = ArmedNpcScript.new()
	npc.call("apply_options", {
		"id": "zone_test", "role": "hostile", "difficulty": "normal",
		"weapon_id": "pistol", "seed": 42, "max_health": 100.0,
	})
	_root.add_child(npc)
	npc.global_position = Vector3.ZERO
	await process_frame
	await physics_frame

	var dmg = npc.get("damageable")
	_expect(dmg != null, "ArmedNpc has Damageable child")

	var health_before = float(dmg.get("health"))
	npc.call("take_zone_damage", "head", 10.0, npc.global_position + Vector3(0, 1.7, 0), Vector3.UP)
	var health_after = float(dmg.get("health"))
	_expect(is_equal_approx(health_after, health_before - 20.0), "head zone damage applied with 2.0 multiplier")

	var health_before2 = float(dmg.get("health"))
	npc.call("take_zone_damage", "leg", 10.0, npc.global_position + Vector3(0, 0.5, 0), Vector3.UP)
	var health_after2 = float(dmg.get("health"))
	_expect(is_equal_approx(health_after2, health_before2 - 5.5), "leg zone damage applied with 0.55 multiplier")

	_expect(npc.call("health_ratio") < 1.0, "health_ratio reflects zone damage")

	npc.queue_free()
	await physics_frame


func _test_armed_npc_hit_zones_on_collision() -> void:
	_case = "armed_npc collision shapes have hit_zone meta"
	var npc = ArmedNpcScript.new()
	npc.call("apply_options", {
		"id": "hitzone_test", "role": "hostile", "max_health": 100.0,
	})
	_root.add_child(npc)
	npc.global_position = Vector3.ZERO
	await process_frame
	await physics_frame

	var collision = npc.get_node("Collision")
	_expect(collision != null, "Collision node exists")
	_expect(collision.has_meta("hit_zone"), "Collision has hit_zone meta")
	_expect(str(collision.get_meta("hit_zone")) == "torso", "Collision hit_zone = torso")

	var head_visual = npc.get_node("HeadVisual")
	_expect(head_visual != null, "HeadVisual node exists")
	_expect(head_visual.has_meta("hit_zone"), "HeadVisual has hit_zone meta")
	_expect(str(head_visual.get_meta("hit_zone")) == "head", "HeadVisual hit_zone = head")

	npc.queue_free()
	await physics_frame


func _test_gore_fx_dismember_called() -> void:
	_case = "gore_fx dismember can be called and returns parts"
	GoreFxScript.set_gore_enabled(true)
	var parts: Array = GoreFxScript.dismember(_root, Vector3(0, 1.5, 0), 1.0, "limb", 3)
	_expect(parts.size() == 3, "dismember returns 3 parts")
	for part in parts:
		_expect(part is RigidBody3D, "each part is RigidBody3D")
		_expect(part.get_child_count() >= 2, "part has collision and visual children")

	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(false)


func _test_mod_hooks_damage_dealt_payload() -> void:
	_case = "mod_hooks damage_dealt payload includes zone and multiplied amount"
	var seen: Array = [0, {}]
	var handler := func(payload):
		seen[0] = int(seen[0]) + 1
		seen[1] = payload.duplicate(true)
	_bus.subscribe("damage_dealt", handler, "test.damage_dealt")

	var dmg = DamageableScript.new()
	dmg.max_health = 100.0
	dmg.health = 100.0

	dmg.take_zone_damage("head", 10.0, Vector3.ZERO, Vector3.UP)

	_expect(int(seen[0]) == 1, "damage_dealt event emitted")
	_expect(is_equal_approx(float((seen[1] as Dictionary).get("amount")), 20.0), "payload amount = multiplied damage (20)")
	_expect(str((seen[1] as Dictionary).get("zone")) == "head", "payload zone = head")

	_bus.unsubscribe_owner("test.damage_dealt")
	dmg.free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_eq(actual, expected, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])