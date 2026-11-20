extends SceneTree

# B1: test que el agarre VR recoge armas del suelo (weapon_pickup) y las equipa

const HarnessScript = preload("res://tests/vr_sim_harness.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")

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

func _stow_if_needed(hand) -> void:
	if not str(hand.weapon_id).is_empty():
		hand.stow()
		await process_frame

func _run() -> void:
	_case = "recoger assault_rifle del suelo con mano izquierda"
	var harness = HarnessScript.new()
	await harness.start(self, GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 1,
	}))
	var world = harness.world
	var rig = harness.rig
	await process_frame
	for i in range(5):
		await physics_frame

	var body := RigidBody3D.new()
	body.name = "DroppedWeapon_test_grab"
	body.add_to_group("weapon_pickup")
	body.set_meta("weapon_id", "assault_rifle")
	body.set_meta("pickable", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.1, 0.1, 0.6)
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.07, 0.6)
	visual.mesh = mesh
	body.add_child(visual)
	world.add_child(body)
	body.global_position = rig.left_controller.global_position + Vector3(0.0, -0.1, -0.3)
	await physics_frame

	var left_hand = rig.left_hand
	_stow_if_needed(left_hand)
	_expect(str(left_hand.weapon_id).is_empty(), "mano izquierda empieza libre")
	_expect(body.is_in_group("weapon_pickup"), "arma en grupo weapon_pickup")

	harness.set_hand_world("left", body.global_position)
	harness.input.grips["left"] = 1.0
	harness.step(6, true)

	_expect(str(left_hand.weapon_id) == "assault_rifle",
		"tras grip, mano equipa assault_rifle (tiene '%s')" % str(left_hand.weapon_id))
	_expect(left_hand.viewmodel != null and bool(left_hand.viewmodel.call("has_model")),
		"viewmodel 3D del arma existe")
	_expect(not is_instance_valid(body) or body.get_parent() == null,
		"cuerpo del arma solta se retira al recogerla")

	harness.cleanup()
	await process_frame

	_case = "recoger shotgun del suelo con mano izquierda"
	harness = HarnessScript.new()
	await harness.start(self, GeneratorScript.generate(4243, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 1,
	}))
	world = harness.world
	rig = harness.rig
	await process_frame
	for i in range(5):
		await physics_frame

	var body2 := RigidBody3D.new()
	body2.name = "DroppedWeapon_test_grab2"
	body2.add_to_group("weapon_pickup")
	body2.set_meta("weapon_id", "shotgun")
	body2.set_meta("pickable", true)
	var shape2 := CollisionShape3D.new()
	var box2 := BoxShape3D.new()
	box2.size = Vector3(0.1, 0.1, 0.7)
	shape2.shape = box2
	body2.add_child(shape2)
	var visual2 := MeshInstance3D.new()
	var mesh2 := BoxMesh.new()
	mesh2.size = Vector3(0.05, 0.07, 0.7)
	visual2.mesh = mesh2
	body2.add_child(visual2)
	world.add_child(body2)
	body2.global_position = rig.left_controller.global_position + Vector3(0.0, -0.1, -0.3)
	await physics_frame

	var left_hand2 = rig.left_hand
	_stow_if_needed(left_hand2)
	_expect(str(left_hand2.weapon_id).is_empty(), "mano izquierda empieza libre")

	harness.set_hand_world("left", body2.global_position)
	harness.input.grips["left"] = 1.0
	harness.step(6, true)

	_expect(str(left_hand2.weapon_id) == "shotgun",
		"tras grip, mano izquierda equipa shotgun (tiene '%s')" % str(left_hand2.weapon_id))
	_expect(left_hand2.viewmodel != null and bool(left_hand2.viewmodel.call("has_model")),
		"viewmodel 3D de shotgun existe")
	_expect(not is_instance_valid(body2) or body2.get_parent() == null,
		"cuerpo de shotgun se retira al recogerla")

	harness.cleanup()
	await process_frame

	_case = "arma sin weapon_id no se equipa"
	harness = HarnessScript.new()
	await harness.start(self, GeneratorScript.generate(4244, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 1,
	}))
	world = harness.world
	rig = harness.rig
	await process_frame
	for i in range(5):
		await physics_frame

	var body3 := RigidBody3D.new()
	body3.name = "DroppedWeapon_no_id"
	body3.add_to_group("weapon_pickup")
	var shape3 := CollisionShape3D.new()
	var box3 := BoxShape3D.new()
	box3.size = Vector3(0.1, 0.1, 0.5)
	shape3.shape = box3
	body3.add_child(shape3)
	world.add_child(body3)
	body3.global_position = rig.left_controller.global_position + Vector3(0.2, -0.1, -0.3)
	await physics_frame

	var left_hand3 = rig.left_hand
	_stow_if_needed(left_hand3)
	_expect(str(left_hand3.weapon_id).is_empty(), "mano izquierda empieza libre")

	harness.set_hand_world("left", body3.global_position)
	harness.input.grips["left"] = 1.0
	harness.step(6, true)

	_expect(str(left_hand3.weapon_id).is_empty(),
		"arma sin weapon_id no se equipa (mano sigue libre)")

	harness.cleanup()
	await process_frame