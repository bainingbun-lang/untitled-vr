extends SceneTree

var used_data = null

func _initialize() -> void:
	await process_frame
	var VrPickupScript = load("res://core/vr/vr_pickup.gd")
	var pickup = VrPickupScript.new()
	pickup.item_id = "health_potion"
	pickup.current_stack = 3
	pickup.use_on_trigger = true
	root.add_child(pickup)
	await physics_frame
	
	pickup.pickup_used.connect(func(data): 
		print("Signal received: ", data)
		used_data = data
	)
	
	var mock_hand = {
		"get_hand_name": func(): return "right",
		"get_trigger_value": func(): return 1.0,
		"get_anchor_transform": func(): return Transform3D.IDENTITY,
		"get_grip_value": func(): return 1.0,
	}
	
	print("Calling on_grabbed...")
	pickup.on_grabbed(mock_hand, "right", Transform3D.IDENTITY)
	await physics_frame
	
	print("Calling on_released...")
	print("use_on_trigger: ", pickup.use_on_trigger)
	print("mock_hand get_trigger_value: ", mock_hand["get_trigger_value"].call())
	print("_get_trigger_value result: ", pickup._get_trigger_value(mock_hand))
	print("condition check: ", pickup.use_on_trigger and pickup._get_trigger_value(mock_hand) > 0.5)
	
	pickup.on_released(mock_hand, "right", Vector3.ZERO)
	await physics_frame
	
	print("used_data: ", used_data)
	if used_data != null:
		print("item_id: ", used_data["item_id"])
		print("PASS")
		quit(0)
	else:
		print("FAIL - signal not emitted")
		quit(1)