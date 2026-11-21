extends SceneTree

const RigScript = preload("res://core/vr/vr_rig.gd")

class FakeController extends Node3D:
	var values: Dictionary = {}
	func is_button_pressed(_a: StringName) -> bool:
		return false
	func get_vector2(_a: StringName) -> Vector2:
		return Vector2.ZERO
	func get_float(a: StringName) -> float:
		return float(values.get(String(a), 0.0))

var _n := 0
var _fail := 0


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _initialize() -> void:
	await process_frame
	var rig = RigScript.new()
	rig.auto_process = false
	rig.xr_availability_override = func() -> bool: return true
	rig.floor_fix_delay = 1000.0
	root.add_child(rig)
	await process_frame
	_expect(rig.hand_models.size() == 2, "el rig crea 2 manos")
	for hand in ["left", "right"]:
		var model = rig.hand_models[hand]
		_expect(model != null and model.skeleton != null and model.visible_mesh_count() >= 1, "mano %s con malla visible y huesos" % hand)
		_expect(model.get_parent() == rig.controller_for(hand), "mano %s colgada de su XRController3D" % hand)
	var model = rig.hand_models["right"]
	model.set_pose(0.0, 0.0, "open")
	var open_tip: float = model.finger_tip("middle").distance_to(model.palm_center())
	var open_curl: float = model.curl_of("middle")
	model.set_pose(1.0, 0.0, "grip")
	var closed_tip: float = model.finger_tip("middle").distance_to(model.palm_center())
	_expect(model.curl_of("middle") > open_curl + 0.2, "el curvado de dedos aumenta con el grip")
	_expect(closed_tip < open_tip - 0.005, "la punta del dedo se acerca a la palma: %.3f -> %.3f" % [open_tip, closed_tip])
	var fake := FakeController.new()
	rig.controller_for("left").get_parent().add_child(fake)
	rig.left_controller = fake
	rig.left_hand.weapon_id = "pistol"
	fake.values["squeeze"] = 0.0
	fake.values["trigger"] = 0.0
	rig.step(0.016)
	var relaxed: float = rig.hand_models["left"].curl_of("ring")
	fake.values["squeeze"] = 1.0
	rig.step(0.016)
	_expect(rig.hand_models["left"].curl_of("ring") > relaxed + 0.1, "rig.step: los dedos siguen el grip analogico")
	fake.values["trigger"] = 1.0
	rig.step(0.016)
	_expect(rig.hand_models["left"].curl_of("index") > 0.5, "el indice se cierra con el gatillo")
	rig.queue_free()
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)
