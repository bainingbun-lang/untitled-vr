extends SceneTree

# Con la mano vacia dentro de la zona de una funda, sacan el arma el agarre, el gatillo,
# A/B/X/Y y el clic del stick (el usuario aprieta "el boton de abajo, junto al joystick").
# Fuera de la zona nada debe sacar un arma.

const HarnessScript = preload("res://tests/vr_sim_harness.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")

var _checks: int = 0
var _failures: Array = []


func _initialize() -> void:
	await process_frame
	for via in ["grip", "trigger", "a", "b", "x", "y", "thumbstick_click"]:
		await _case_via(via, true)
	await _case_via("trigger", false)
	await _case_via("a", false)
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


func _tick_hand(harness, hand) -> void:
	harness.apply_poses()
	harness._sync_input_to_vr_input()
	hand.step(1.0 / 72.0)


func _case_via(via: String, in_zone: bool) -> void:
	var harness = HarnessScript.new()
	await harness.start(self, GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 4,
	}))
	var hand = harness.rig.left_hand
	_expect(str(hand.weapon_id).is_empty(), "[%s] la mano izquierda empieza libre" % via)
	var flat: Vector3 = hand.bag.head_forward
	flat.y = 0.0
	flat = flat.normalized() if flat.length_squared() > 0.000001 else Vector3.FORWARD
	hand.holsters.set_head_pose(Transform3D(Basis.looking_at(flat, Vector3.UP), hand.bag.head_position))
	var target: Vector3 = hand.holsters.slot_position("hip")
	if not in_zone:
		target += Vector3(0.0, 1.4, 0.0)
	harness.set_hand_world("left", target)
	for i in 3:
		_tick_hand(harness, hand)
	if via == "grip":
		harness.input.grips["left"] = 1.0
	elif via == "trigger":
		harness.input.triggers["left"] = 1.0
	else:
		harness.input.buttons[via] = true
	for i in 10:
		_tick_hand(harness, hand)
	var equipped: bool = not str(hand.weapon_id).is_empty()
	if in_zone:
		_expect(equipped, "[%s] dentro de la zona de la funda saca el arma (weapon_id='%s')" % [via, str(hand.weapon_id)])
	else:
		_expect(not equipped, "[%s] fuera de la zona NO saca ningun arma (weapon_id='%s')" % [via, str(hand.weapon_id)])
	await harness.cleanup()
	await process_frame
