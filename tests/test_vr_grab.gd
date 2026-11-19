extends SceneTree

class SimulatedInputSource extends RefCounted:
	var pose = Transform3D.IDENTITY
	var pressed = false
	var tracking = true
	
	func get_pose(hand): return pose
	func is_pressed(action): return pressed
	func is_tracking(hand): return tracking
	func get_joint(hand, joint): return Transform3D.IDENTITY

func _init():
	run_tests()

func run_tests():
	_run_tests_async()

func _run_tests_async():
	var results = []
	
	# Case 1: Scene Loads
	results.append(["Scene Load", await test_scene_load()])
	
	# Case 2: Grab and Release
	results.append(["Grab/Release", await test_grab_release()])
	
	# Case 3: Tracking Loss
	results.append(["Tracking Loss", await test_tracking_loss()])
	
	for r in results:
		print("%s: %s" % [r[0], "PASS" if r[1] else "FAIL"])
	
	var all_passed = true
	for r in results:
		if not r[1]: all_passed = false
	
	if all_passed:
		print("ALL_TESTS_PASSED")
		quit(0)
	else:
		print("SOME_TESTS_FAILED")
		quit(1)

func test_scene_load():
	var scene = load("res://scenes/vr/vr_test_scene.tscn").instantiate()
	if root:
		root.add_child(scene)
	else:
		return false
	await process_frame
	# XROrigin3D is created in _ready() of vr_test_scene.gd, it's a child of the scene root
	var origin = scene.find_child("XROrigin3D", true, false)
	if not origin:
		# Search by type if name differs
		for child in scene.get_children():
			if child is XROrigin3D:
				origin = child
				break
	scene.queue_free()
	return origin != null

func test_grab_release():
	var grabber = load("res://core/vr/grab_controller.gd").new()
	var sim = SimulatedInputSource.new()
	grabber.input_source = sim
	
	var obj = Node3D.new()
	obj.add_to_group("grabbable")
	
	if root:
		root.add_child(grabber)
		root.add_child(obj)
	else:
		return false
	
	await process_frame
	
	sim.pose = Transform3D.IDENTITY
	obj.global_transform = Transform3D(Basis(), Vector3(0.1, 0, 0))
	sim.pressed = true
	grabber._process(0.1)
	var grabbed = (grabber.grabbed_object == obj)
	
	sim.pressed = false
	grabber._process(0.1)
	var released = (grabber.grabbed_object == null)
	
	obj.global_transform = Transform3D(Basis(), Vector3(1.0, 0, 0))
	sim.pressed = true
	grabber._process(0.1)
	var not_grabbed = (grabber.grabbed_object == null)
	
	grabber.queue_free()
	obj.queue_free()
	
	return grabbed and released and not_grabbed

func test_tracking_loss():
	var grabber = load("res://core/vr/grab_controller.gd").new()
	var sim = SimulatedInputSource.new()
	grabber.input_source = sim
	
	var obj = Node3D.new()
	obj.add_to_group("grabbable")
	if root:
		root.add_child(grabber)
		root.add_child(obj)
	else:
		return false
	
	await process_frame
	
	sim.pose = Transform3D.IDENTITY
	obj.global_transform = Transform3D(Basis(), Vector3(0.1, 0, 0))
	sim.pressed = true
	grabber._process(0.1)
	
	var grabbed_initially = (grabber.grabbed_object == obj)
	if not grabbed_initially:
		grabber.queue_free()
		obj.queue_free()
		return false
	
	sim.tracking = false
	# threshold is 0.5. 
	# Process 1: delta=0.1, total=0.1. still_grabbed should be true.
	grabber._process(0.1)
	var still_grabbed = (grabber.grabbed_object != null)
	
	# Process 2: delta=0.6, total=0.7. 
	# IMPORTANT: We must ensure input_source.is_pressed("grip") returns true.
	# In SimulatedInputSource, is_pressed(action) simply returns the 'pressed' variable.
	sim.pressed = true 
	grabber._process(0.6)
	var released = (grabber.grabbed_object == null)
	
	grabber.queue_free()
	obj.queue_free()
	
	return still_grabbed and released
