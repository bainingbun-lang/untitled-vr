extends SceneTree

func _init():
	var registry_script = load("res://core/maps/map_registry.gd")
	var registry = registry_script.new()
	var passed = true
	
	# Case 1: Valid Map
	var valid_map = {
		"id": "map_01",
		"license": "MIT",
		"spawn_points": [Vector3(0,0,0)],
		"has_navigation": true,
		"has_collisions": true
	}
	if not registry.register(valid_map):
		print("FAIL: Valid map registration")
		passed = false
	
	# Case 2: Invalid Map (Missing license)
	var invalid_map = {
		"id": "map_02",
		"spawn_points": [Vector3(0,0,0)],
		"has_navigation": true,
		"has_collisions": true
	}
	if registry.register(invalid_map):
		print("FAIL: Invalid map should be rejected")
		passed = false
		
	# Case 3: Duplicate ID
	if registry.register(valid_map):
		print("FAIL: Duplicate ID should be rejected")
		passed = false
		
	# Case 4: Get and List
	if registry.get_map("map_01").get("id") != "map_01":
		print("FAIL: Get map failed")
		passed = false
	
	if registry.list().size() != 1:
		print("FAIL: List size mismatch")
		passed = false
		
	# Case 5: Unregister
	if not registry.unregister("map_01"):
		print("FAIL: Unregister failed")
		passed = false
	
	if registry.list().size() != 0:
		print("FAIL: List should be empty after unregister")
		passed = false
		
	if passed:
		print("PASS")
		quit(0)
	else:
		quit(1)
