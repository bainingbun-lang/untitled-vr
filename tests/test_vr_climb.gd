extends SceneTree

# Test VrClimb and VrClimbable integration

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")
const VrGameModeScript = preload("res://core/vr/vr_game_mode.gd")
const VrClimbScript = preload("res://core/vr/vr_climb.gd")
const VrClimbableScript = preload("res://core/vr/vr_climbable.gd")

class MockXR extends RefCounted:
	signal session_begun
	signal session_visible
	signal session_focussed
	signal session_stopping
	signal session_loss_pending
	signal pose_recentered
	signal user_presence_changed(present: bool)
	var initialized: bool = false
	var display_refresh_rate: float = 0.0
	var foveation_level: int = 0
	var foveation_dynamic: bool = false

	func initialize() -> bool:
		initialized = true
		return true

	func is_initialized() -> bool:
		return initialized

	func get_available_display_refresh_rates() -> Array:
		return []

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

func _initialize() -> void:
	await process_frame
	_test_climbable_script()
	_test_climb_script()
	await _test_climb_in_vr_rig()
	_reset_state()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _test_climbable_script() -> void:
	_case = "VrClimbable script basic functionality"
	var climbable = VrClimbableScript.new()
	root.add_child(climbable)
	await process_frame
	
	_expect(climbable.can_pick_up(null), "can_pick_up returns true by default")
	_expect(not climbable.is_picked_up(), "is_picked_up returns false initially")
	
	var handle := climbable.get_grab_handle(null)
	_expect(handle == null, "get_grab_handle returns null when not picked up")
	
	# Test pick_up
	var mock_controller = Node3D.new()
	mock_controller.global_transform = Transform3D.IDENTITY
	climbable.pick_up(mock_controller)
	await process_frame
	
	_expect(climbable.is_picked_up(), "is_picked_up returns true after pick_up")
	handle = climbable.get_grab_handle(mock_controller)
	_expect(handle != null, "get_grab_handle returns handle after pick_up")
	
	# Test let_go
	climbable.let_go(mock_controller, Vector3.ZERO, Vector3.ZERO)
	await process_frame
	
	_expect(not climbable.is_picked_up(), "is_picked_up returns false after let_go")
	
	climbable.free()
	await process_frame

func _test_climb_script() -> void:
	_case = "VrClimb script basic functionality"
	var climb = VrClimbScript.new()
	root.add_child(climb)
	await process_frame
	
	_expect(not climb.is_climbing(), "is_climbing returns false initially")
	_expect(climb.get_dominant_hand() == "", "get_dominant_hand returns empty initially")
	
	# Test setup with mock rig
	var mock_rig = Node3D.new()
	mock_rig.name = "MockRig"
	var left_ctrl = XRController3D.new()
	left_ctrl.name = "LeftController"
	mock_rig.add_child(left_ctrl)
	var right_ctrl = XRController3D.new()
	right_ctrl.name = "RightController"
	mock_rig.add_child(right_ctrl)
	
	climb.setup(mock_rig)
	await process_frame
	
	_expect(climb._left_controller != null, "left_controller set after setup")
	_expect(climb._right_controller != null, "right_controller set after setup")
	
	climb.free()
	await process_frame

func _test_climb_in_vr_rig() -> void:
	_case = "VrClimb integrated in VrRig"
	SessionScript.platform_override = "vr"
	SessionScript.platform = "vr"
	SessionScript.vr_menu_confirmed = true
	VrGameModeScript.xr_available_override = func() -> bool: return true
	
	var meta: Dictionary = GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.18, "spawn_count": 1,
	})
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	world.setup(meta)
	await process_frame
	
	var rig = world.actor
	_expect(rig != null and rig.has_method("is_active"), "VrRig created")
	
	# Check climb is initialized
	_expect(rig.has_method("climb_enabled"), "VrRig has climb_enabled property")
	_expect(rig.climb_enabled == true, "climb_enabled defaults to true")
	
	# Test climbable object in world
	var climbable_body = StaticBody3D.new()
	climbable_body.name = "TestClimbableWall"
	climbable_body.global_position = Vector3(0, 1, -2)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2, 3, 0.5)
	shape.shape = box
	climbable_body.add_child(shape)
	
	var climbable_script = VrClimbableScript.new()
	climbable_body.add_child(climbable_script)
	
	# Add a grab point
	var grab_point = Node3D.new()
	grab_point.name = "grab_point_1"
	grab_point.global_position = Vector3(0, 1.5, -1.75)
	climbable_body.add_child(grab_point)
	
	world.add_child(climbable_body)
	await process_frame
	
	# Verify climbable is in tree
	_expect(is_instance_valid(climbable_body), "climbable body in tree")
	_expect(climbable_script.is_picked_up() == false, "climbable not picked up initially")
	
	world.free()
	await process_frame

func _reset_state() -> void:
	SessionScript.platform_override = ""
	SessionScript.platform = ""
	SessionScript.vr_menu_confirmed = false
	VrGameModeScript.xr_available_override = Callable()

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])