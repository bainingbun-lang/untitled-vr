extends SceneTree

const VrGameMode = preload("res://core/vr/vr_game_mode.gd")
const VrRig = preload("res://core/vr/vr_rig.gd")
const VrComfort = preload("res://core/vr/vr_comfort.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

func _initialize() -> void:
	await process_frame
	print("Starting tests...")
	await _test_comfort_profile_validation()
	print("After validation: %d checks" % _checks)
	await _test_apply_comfort_profile_to_rig()
	print("After apply: %d checks" % _checks)
	await _test_get_comfort_profile()
	print("After get: %d checks" % _checks)
	await _test_apply_default_comfort_profile()
	print("After default: %d checks" % _checks)
	await _test_comfort_profile_in_setup()
	print("After setup: %d checks" % _checks)
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_case, message])

func _test_comfort_profile_validation() -> void:
	_case = "comfort profile validation"
	
	var valid_profile = VrComfort.default_profile()
	var result = VrComfort.validate_profile(valid_profile)
	_expect(result["ok"], "Default profile validates OK")
	_expect(not result["profile"].is_empty(), "Returns canonical profile")
	
	var invalid_profile = valid_profile.duplicate(true)
	invalid_profile["turn_mode"] = "invalid_mode"
	result = VrComfort.validate_profile(invalid_profile)
	_expect(not result["ok"], "Invalid turn_mode rejected")
	_expect("turn_mode invalido" in str(result["errors"]), "Error message for invalid turn_mode")
	
	invalid_profile = valid_profile.duplicate(true)
	invalid_profile["stick_deadzone"] = 1.5
	result = VrComfort.validate_profile(invalid_profile)
	_expect(not result["ok"], "stick_deadzone > 1.0 rejected")
	
	invalid_profile = valid_profile.duplicate(true)
	invalid_profile["vignette_intensity"] = 1.5
	result = VrComfort.validate_profile(invalid_profile)
	_expect(not result["ok"], "vignette_intensity > 1.0 rejected")
	
	invalid_profile = valid_profile.duplicate(true)
	invalid_profile["version"] = 999
	result = VrComfort.validate_profile(invalid_profile)
	_expect(not result["ok"], "Wrong version rejected")
	
	invalid_profile = {}
	result = VrComfort.validate_profile(invalid_profile)
	_expect(not result["ok"], "Empty dict rejected")
	_expect("falta clave" in str(result["errors"]), "Missing keys reported")

func _test_apply_comfort_profile_to_rig() -> void:
	print("ENTER _test_apply_comfort_profile_to_rig")
	_case = "apply comfort profile to rig"
	
	var world = Node3D.new()
	root.add_child(world)
	print("world created")
	
	var rig = VrRig.new()
	print("rig created")
	rig.name = "TestRig"
	rig.xr_availability_override = func() -> bool: return true
	rig.auto_process = false
	world.add_child(rig)
	print("rig added to world")
	await process_frame
	print("after process_frame")
	print("Rig is_active: %s, is_built: %s" % [rig.is_active(), rig.is_built()])
	_expect(rig.is_active(), "Rig is active")
	_expect(rig.is_built(), "Rig is built")
	
	var profile = VrComfort.default_profile()
	profile["turn_mode"] = "snap"
	profile["snap_turn_degrees"] = 45.0
	profile["comfort_vignette_enabled"] = false
	profile["move_speed"] = 3.0
	
	var result = VrGameMode.apply_comfort_profile(rig, profile)
	_expect(result["ok"], "apply_comfort_profile returns ok")
	_expect(result["profile"]["turn_mode"] == "snap", "turn_mode applied")
	_expect(result["profile"]["snap_turn_degrees"] == 45.0, "snap_turn_degrees applied")
	_expect(result["profile"]["comfort_vignette_enabled"] == false, "comfort_vignette_enabled applied")
	_expect(result["profile"]["move_speed"] == 3.0, "move_speed applied")
	
	var stored = rig.get_meta("comfort_profile", null)
	_expect(stored != null, "Profile stored in rig meta")
	_expect(stored["turn_mode"] == "snap", "Stored profile has turn_mode")
	_expect(stored["snap_turn_degrees"] == 45.0, "Stored profile has snap_turn_degrees")
	
	rig.queue_free()
	world.queue_free()
	await process_frame

func _test_get_comfort_profile() -> void:
	_case = "get comfort profile"
	
	var world = Node3D.new()
	root.add_child(world)
	
	var rig = VrRig.new()
	rig.name = "TestRig"
	rig.xr_availability_override = func() -> bool: return true
	rig.auto_process = false
	world.add_child(rig)
	await process_frame
	
	var default_profile = VrGameMode.get_comfort_profile(rig)
	_expect(default_profile["turn_mode"] == "smooth", "Default profile returned when none set")
	_expect(default_profile["version"] == VrComfort.VERSION, "Default profile has correct version")
	
	var custom = VrComfort.default_profile()
	custom["turn_mode"] = "off"
	custom["move_speed"] = 1.0
	VrGameMode.apply_comfort_profile(rig, custom)
	
	var retrieved = VrGameMode.get_comfort_profile(rig)
	_expect(retrieved["turn_mode"] == "off", "Custom profile retrieved")
	_expect(retrieved["move_speed"] == 1.0, "Custom move_speed retrieved")
	
	rig.queue_free()
	world.queue_free()
	await process_frame

func _test_apply_default_comfort_profile() -> void:
	_case = "apply default comfort profile"
	
	var world = Node3D.new()
	root.add_child(world)
	
	var rig = VrRig.new()
	rig.name = "TestRig"
	rig.xr_availability_override = func() -> bool: return true
	rig.auto_process = false
	world.add_child(rig)
	await process_frame
	
	var result = VrGameMode.apply_default_comfort_profile(rig)
	_expect(result["ok"], "apply_default_comfort_profile returns ok")
	_expect(result["profile"]["turn_mode"] == "smooth", "Default turn_mode applied")
	_expect(result["profile"]["comfort_vignette_enabled"] == true, "Default vignette enabled")
	
	rig.queue_free()
	world.queue_free()
	await process_frame

func _test_comfort_profile_in_setup() -> void:
	_case = "comfort profile in setup"
	
	var world = Node3D.new()
	root.add_child(world)
	
	var rig = VrRig.new()
	rig.name = "Player"
	rig.xr_availability_override = func() -> bool: return true
	rig.auto_process = false
	world.add_child(rig)
	await process_frame
	
	var meta = VrGameMode.default_map_meta()
	var result = VrGameMode.setup(world, rig, meta)
	
	_expect(result["state"] != null, "Setup returns state")
	
	var stored = rig.get_meta("comfort_profile", null)
	_expect(stored != null, "Comfort profile applied during setup")
	_expect(stored["version"] == VrComfort.VERSION, "Profile has correct version")
	_expect(stored["turn_mode"] == "smooth", "Default turn_mode in setup profile")
	_expect(stored["comfort_vignette_enabled"] == true, "Default vignette in setup profile")
	
	if result["state"] != null and is_instance_valid(result["state"]):
		result["state"].queue_free()
	if result["weapon_system"] != null and is_instance_valid(result["weapon_system"]):
		result["weapon_system"].queue_free()
	if result["hud"] != null and is_instance_valid(result["hud"]):
		result["hud"].queue_free()
	if result["menu"] != null and is_instance_valid(result["menu"]):
		result["menu"].queue_free()
	
	rig.queue_free()
	world.queue_free()
	await process_frame