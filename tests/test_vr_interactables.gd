extends SceneTree

const HingeScript = preload("res://core/vr/vr_interactable_hinge.gd")
const SliderScript = preload("res://core/vr/vr_interactable_slider.gd")
const JoystickScript = preload("res://core/vr/vr_interactable_joystick.gd")
const HandleScript = preload("res://core/vr/vr_interactable_handle.gd")
const InteractableScript = preload("res://core/vr/vr_interactable.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""
var _world: Node3D

class MockHand extends Node3D:
	var hand_name: String = "right"
	var pose: Transform3D = Transform3D.IDENTITY
	var grip: float = 0.0
	var trigger: float = 0.0
	var tracking: bool = true
	
	func get_hand_pose(hand: String) -> Transform3D:
		return pose
	
	func get_grip_value(hand: String) -> float:
		return grip
	
	func get_trigger_value(hand: String) -> float:
		return trigger
	
	func is_tracking(hand: String) -> bool:
		return tracking
	
	func emit_haptic(hand: String, duration: float, amplitude: float) -> void:
		pass


func _initialize() -> void:
	await process_frame
	_world = Node3D.new()
	root.add_child(_world)
	await _test_hinge()
	await _test_slider()
	await _test_joystick()
	await _test_handle()
	await _test_base_interactable()
	_cleanup()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _cleanup() -> void:
	if _world != null and is_instance_valid(_world):
		_world.free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


# --- Hinge Tests ---
func _test_hinge() -> void:
	_case = "Hinge: basic setup"
	var hinge = HingeScript.new()
	hinge.name = "TestHinge"
	_world.add_child(hinge)
	hinge.global_position = Vector3(0, 1.6, 0)
	await process_frame
	
	_expect(hinge.is_interacting == false, "starts not interacting")
	_expect(hinge.current_angle == 0.0, "initial angle is zero")
	_expect(hinge.min_angle == -1.57, "default min angle")
	_expect(hinge.max_angle == 1.57, "default max angle")
	
	_case = "Hinge: angle limits"
	hinge.min_angle = -1.0
	hinge.max_angle = 1.0
	hinge.set_angle(2.0)
	_expect(hinge.current_angle == 1.0, "clamped to max")
	hinge.set_angle(-2.0)
	_expect(hinge.current_angle == -1.0, "clamped to min")
	hinge.set_angle(0.5)
	_expect(hinge.current_angle == 0.5, "within limits")
	
	_case = "Hinge: interaction with hand"
	var hand = MockHand.new()
	hand.hand_name = "right"
	hand.pose = Transform3D(Basis(Vector3.UP, 0.5), Vector3(0, 1.6, 0))
	hand.grip = 1.0
	_world.add_child(hand)
	await process_frame
	
	_expect(hinge.can_interact(hand, "right"), "can interact when close")
	hand.pose = Transform3D(Basis(Vector3.UP, 0.5), Vector3(10, 1.6, 0))
	_expect(not hinge.can_interact(hand, "right"), "cannot interact when far")
	hand.pose = Transform3D(Basis(Vector3.UP, 0.5), Vector3(0, 1.6, 0))
	
	_expect(hinge.start_interaction(hand, "right"), "starts interaction")
	_expect(hinge.is_interacting, "is interacting after start")
	_expect(hinge.interactor == hand, "interactor is set")
	
	hand.pose = Transform3D(Basis(Vector3.UP, 1.0), Vector3(0, 1.6, 0))
	await process_frame
	_expect(hinge.current_angle != 0.0, "angle changes with hand rotation")
	
	hinge.end_interaction()
	_expect(not hinge.is_interacting, "ends interaction")
	
	hinge.free()
	hand.free()


# --- Slider Tests ---
func _test_slider() -> void:
	_case = "Slider: basic setup"
	var slider = SliderScript.new()
	slider.name = "TestSlider"
	_world.add_child(slider)
	slider.global_position = Vector3(0, 1.6, 0)
	await process_frame
	
	_expect(slider.is_interacting == false, "starts not interacting")
	_expect(slider.current_value == 0.0, "initial value is zero")
	_expect(slider.min_value == 0.0, "default min value")
	_expect(slider.max_value == 1.0, "default max value")
	
	_case = "Slider: value limits"
	slider.min_value = -1.0
	slider.max_value = 1.0
	slider.set_value(2.0)
	_expect(slider.current_value == 1.0, "clamped to max")
	slider.set_value(-2.0)
	_expect(slider.current_value == -1.0, "clamped to min")
	slider.set_value(0.5)
	_expect(slider.current_value == 0.5, "within limits")
	
	_case = "Slider: normalized value"
	slider.min_value = 0.0
	slider.max_value = 10.0
	slider.set_value(5.0)
	_expect(is_equal_approx(slider.get_normalized_value(), 0.5), "normalized value is 0.5")
	
	_case = "Slider: interaction with hand"
	var hand = MockHand.new()
	hand.hand_name = "right"
	hand.pose = Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0))
	hand.grip = 1.0
	_world.add_child(hand)
	await process_frame
	
	_expect(slider.can_interact(hand, "right"), "can interact when close")
	hand.pose = Transform3D(Basis.IDENTITY, Vector3(10, 1.6, 0))
	_expect(not slider.can_interact(hand, "right"), "cannot interact when far")
	hand.pose = Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0))
	
	_expect(slider.start_interaction(hand, "right"), "starts interaction")
	_expect(slider.is_interacting, "is interacting after start")
	
	hand.pose = Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0.5))
	await process_frame
	_expect(slider.current_value != 0.0, "value changes with hand position")
	
	slider.end_interaction()
	_expect(not slider.is_interacting, "ends interaction")
	
	slider.free()
	hand.free()


# --- Joystick Tests ---
func _test_joystick() -> void:
	_case = "Joystick: basic setup"
	var joystick = JoystickScript.new()
	joystick.name = "TestJoystick"
	_world.add_child(joystick)
	joystick.global_position = Vector3(0, 1.6, 0)
	await process_frame
	
	_expect(joystick.is_interacting == false, "starts not interacting")
	_expect(joystick.current_value == Vector2.ZERO, "initial value is zero")
	_expect(joystick.max_angle == 0.5, "default max angle")
	
	_case = "Joystick: value clamping"
	joystick.set_value(Vector2(2.0, 2.0))
	_expect(joystick.current_value.length() <= 1.001, "clamped to circle")
	
	_case = "Joystick: deadzone"
	joystick.deadzone = 0.1
	joystick.set_value(Vector2(0.05, 0.0))
	_expect(joystick.is_centered(), "within deadzone is centered")
	joystick.set_value(Vector2(0.2, 0.0))
	_expect(not joystick.is_centered(), "outside deadzone is not centered")
	
	_case = "Joystick: interaction with hand"
	var hand = MockHand.new()
	hand.hand_name = "right"
	hand.pose = Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0))
	hand.grip = 1.0
	_world.add_child(hand)
	await process_frame
	
	_expect(joystick.can_interact(hand, "right"), "can interact when close")
	hand.pose = Transform3D(Basis.IDENTITY, Vector3(10, 1.6, 0))
	_expect(not joystick.can_interact(hand, "right"), "cannot interact when far")
	hand.pose = Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0))
	
	_expect(joystick.start_interaction(hand, "right"), "starts interaction")
	_expect(joystick.is_interacting, "is interacting after start")
	
	hand.pose = Transform3D(Basis.IDENTITY, Vector3(0.1, 1.6, -0.1))
	await process_frame
	_expect(joystick.current_value != Vector2.ZERO, "value changes with hand position")
	
	joystick.end_interaction()
	_expect(not joystick.is_interacting, "ends interaction")
	
	joystick.free()
	hand.free()


# --- Handle Tests ---
func _test_handle() -> void:
	_case = "Handle: basic setup"
	var handle = HandleScript.new()
	handle.name = "TestHandle"
	_world.add_child(handle)
	handle.global_position = Vector3(0, 1.6, 0)
	await process_frame
	
	_expect(handle.is_interacting == false, "starts not interacting")
	_expect(not handle.is_grabbed(), "not grabbed initially")
	
	_case = "Handle: single hand grab"
	var hand = MockHand.new()
	hand.hand_name = "right"
	hand.pose = Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0))
	hand.grip = 1.0
	_world.add_child(hand)
	await process_frame
	
	_expect(handle.can_interact(hand, "right"), "can interact when close")
	hand.pose = Transform3D(Basis.IDENTITY, Vector3(10, 1.6, 0))
	_expect(not handle.can_interact(hand, "right"), "cannot interact when far")
	hand.pose = Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0))
	
	_expect(handle.start_interaction(hand, "right"), "starts interaction with right hand")
	_expect(handle.is_grabbed(), "is grabbed")
	_expect(handle.primary_hand == "right", "primary hand is right")
	
	hand.pose = Transform3D(Basis(Vector3.UP, 0.5), Vector3(0, 1.6, 0))
	for _i in range(5):
		await process_frame
	_expect(handle.get_angular_velocity() != 0.0, "angular velocity changes with rotation")
	
	handle.end_interaction()
	await process_frame
	_expect(not handle.is_grabbed(), "releases when end_interaction called")
	
	_case = "Handle: two handed grab"
	hand.grip = 1.0
	hand.pose = Transform3D(Basis.IDENTITY, Vector3(-0.15, 1.6, 0))
	_expect(handle.start_interaction(hand, "right"), "starts interaction with right hand")
	hand.pose = Transform3D(Basis.IDENTITY, Vector3(0.15, 1.6, 0))
	_expect(handle.start_interaction(hand, "left"), "starts interaction with left hand")
	_expect(handle.is_two_handed(), "is two handed")
	
	hand.pose = Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.15, 1.6, 0))
	for _i in range(5):
		await process_frame
	_expect(handle.get_angular_velocity() != 0.0, "angular velocity with two hands")
	
	handle.end_interaction()
	await process_frame
	_expect(not handle.is_grabbed(), "releases when end_interaction called")
	
	handle.free()
	hand.free()


# --- Base Interactable Tests ---
func _test_base_interactable() -> void:
	_case = "BaseInteractable: signals"
	var interactable = InteractableScript.new()
	interactable.name = "TestInteractable"
	_world.add_child(interactable)
	interactable.global_position = Vector3(0, 1.6, 0)
	await process_frame
	
	var signals_received: Array = []
	interactable.interaction_started.connect(func(actor): signals_received.append("started"))
	interactable.interaction_ended.connect(func(actor): signals_received.append("ended"))
	interactable.interacted.connect(func(actor, action): signals_received.append("interacted:" + action))
	
	var hand = MockHand.new()
	hand.hand_name = "right"
	hand.pose = Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0))
	hand.grip = 1.0
	_world.add_child(hand)
	await process_frame
	
	interactable.start_interaction(hand, "right")
	await process_frame
	_expect(signals_received.has("started"), "interaction_started signal emitted")
	
	interactable.end_interaction()
	await process_frame
	_expect(signals_received.has("ended"), "interaction_ended signal emitted")
	
	interactable.free()
	hand.free()