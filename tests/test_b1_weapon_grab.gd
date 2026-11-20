extends SceneTree

# B1 (b): las armas soltadas en el mundo deben tener colision/area agarrable
# y el agarre debe funcionar por codigo (mano VR recoge el arma y la equipa).

const HarnessScript = preload("res://tests/vr_sim_harness.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")
const GrabScript = preload("res://core/vr/vr_grab.gd")
const ArmedNpcScript = preload("res://core/game/armed_npc.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _initialize() -> void:
	await process_frame
	await _run()
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


func _run() -> void:
	var harness = HarnessScript.new()
	await harness.start(self, GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 5,
	}))
	var world = harness.world
	var rig = harness.rig
	await process_frame
	for i in range(5):
		await physics_frame

	_case = "arma soltada al morir el NPC"
	var victim: Node3D = null
	for npc in world.npcs:
		if str(npc.get("role")) == "hostile" and not str(npc.get("weapon_id")).is_empty() and not bool(npc.call("is_dead")):
			victim = npc
			break
	_expect(victim != null, "existe un NPC hostil armado vivo")
	if victim != null:
		var weapon_id: String = str(victim.get("weapon_id"))
		victim.take_damage(250.0, victim.global_position + Vector3.UP, Vector3.FORWARD, rig)
		for i in range(5):
			await physics_frame
		var report: Dictionary = victim.get("death_report")
		var dropped: Node3D = report.get("weapon", null) as Node3D
		_expect(bool(victim.call("is_dead")), "el NPC muere")
		_expect(dropped != null and is_instance_valid(dropped), "la muerte suelta el arma en el mundo")
		if dropped != null:
			_case = "el arma soltada es agarrable (colision/area/grupo)"
			_expect(dropped.is_in_group("weapon_pickup"), "el arma soltada esta en el grupo weapon_pickup")
			_expect(dropped.has_meta("weapon_id") and str(dropped.get_meta("weapon_id")) == weapon_id,
				"el arma soltada conserva su weapon_id")
			var has_collision: bool = not dropped.find_children("*", "CollisionShape3D", true, false).is_empty()
			var has_area: bool = not dropped.find_children("*", "Area3D", true, false).is_empty()
			_expect(has_collision or has_area, "el arma soltada tiene colision o area agarrable")
			_expect(dropped.is_in_group("grabbable") or dropped.is_in_group("physics_props") or has_area,
				"el arma soltada es localizable por el sistema de agarre")

			_case = "agarre por codigo con VrGrab"
			var grab = GrabScript.new()
			var pose := Transform3D(Basis.IDENTITY, dropped.global_position)
			_expect(grab.grab_prop(dropped, pose, 0.30), "VrGrab.grab_prop agarra el arma soltada")
			_expect(grab.held_prop() == dropped, "el arma queda agarrada")
			grab.release_prop(Vector3.ZERO)

			_case = "la mano VR recoge el arma del suelo con el grip"
			var left_hand = rig.left_hand
			_expect(str(left_hand.weapon_id).is_empty(), "la mano izquierda empieza libre")
			harness.set_hand_world("left", dropped.global_position)
			harness.input.grips["left"] = 1.0
			harness.step(6, true)
			_expect(str(left_hand.weapon_id) == weapon_id,
				"tras el grip junto al arma, la mano equipa '%s' (tiene '%s')" % [weapon_id, str(left_hand.weapon_id)])
			_expect(left_hand.viewmodel != null and bool(left_hand.viewmodel.call("has_model")),
				"el viewmodel 3D del arma recogida existe")
			_expect(not is_instance_valid(dropped) or dropped.get_parent() == null,
				"el cuerpo del arma soltada se retira al recogerla")

	_case = "pick_up_weapon devuelve el id y libera el nodo"
	var body := RigidBody3D.new()
	body.name = "DroppedWeapon_test"
	body.add_to_group("weapon_pickup")
	body.set_meta("weapon_id", "shotgun")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.1, 0.1, 0.6)
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	body.global_position = world.npcs[0].global_position + Vector3(0.0, 0.5, 0.0)
	await physics_frame
	var picked: String = ArmedNpcScript.pick_up_weapon(body)
	_expect(picked == "shotgun", "pick_up_weapon devuelve el id del arma")
	await process_frame
	_expect(not is_instance_valid(body), "pick_up_weapon libera el nodo")

	harness.cleanup()
	await process_frame
