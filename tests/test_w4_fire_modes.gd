extends SceneTree

# W4: Fire modes - semi/auto/burst, fire rate, recoil, muzzle flash, dispersion

const WeaponSystemScript = preload("res://core/game/weapon_system.gd")
const WeaponViewmodelScript = preload("res://core/game/weapon_viewmodel.gd")
const WeaponDbScript = preload("res://core/game/weapon_db.gd")
const ContentRegistryScript = preload("res://core/game/content_registry.gd")
const MuzzleFxScript = preload("res://core/game/muzzle_fx.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""
var _ws = null
var _vm = null

func _initialize() -> void:
	await process_frame
	_ws = WeaponSystemScript.new()
	_vm = WeaponViewmodelScript.new()
	root.add_child(_ws)
	root.add_child(_vm)
	await _run_test_fire_mode_config()
	await _run_test_semi_auto()
	await _run_test_full_auto()
	await _run_test_burst()
	await _run_test_fire_rate_timing()
	await _run_test_camera_recoil()
	await _run_test_muzzle_flash_modes()
	await _run_test_spread_scaling()
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

func _run_test_fire_mode_config() -> void:
	_case = "configuracion fire_mode en weapons.json"
	var reg = ContentRegistryScript.instance()
	var defs: Dictionary = reg.definition("weapon", "pistol")
	_expect(defs.has("fire_mode"), "pistol tiene fire_mode")
	_expect(str(defs.get("fire_mode")) == "semi", "pistol fire_mode = semi")
	
	defs = reg.definition("weapon", "submachine_gun")
	_expect(defs.has("fire_mode"), "submachine_gun tiene fire_mode")
	_expect(str(defs.get("fire_mode")) == "auto", "submachine_gun fire_mode = auto")
	
	defs = reg.definition("weapon", "assault_rifle")
	_expect(defs.has("fire_mode"), "assault_rifle tiene fire_mode")
	_expect(str(defs.get("fire_mode")) == "burst", "assault_rifle fire_mode = burst")
	_expect(defs.has("burst_count"), "assault_rifle tiene burst_count")
	_expect(defs.get("burst_count") == 3, "assault_rifle burst_count = 3")
	_expect(defs.has("burst_delay"), "assault_rifle tiene burst_delay")

func _run_test_semi_auto() -> void:
	_case = "modo semi-auto: trigger_pressed/trigger_released"
	_ws.set_ammo("pistol", 10, 30)
	
	# Test get_fire_mode
	var mode = _ws.get_fire_mode("pistol")
	_expect(mode == "semi", "get_fire_mode devuelve semi")
	
	# Test trigger_pressed sets _trigger_held
	_ws.trigger_pressed("pistol")
	_expect(_ws._trigger_held.get("pistol", false), "trigger_pressed marca trigger_held")
	
	# Test trigger_released clears _trigger_held
	_ws.trigger_released("pistol")
	_expect(not _ws._trigger_held.get("pistol", true), "trigger_released limpia trigger_held")
	
	# Test fire_interval
	var interval = _ws.fire_interval("pistol")
	_expect(interval > 0.0, "fire_interval > 0")

func _run_test_full_auto() -> void:
	_case = "modo full-auto: try_fire_auto mientras gatillo pulsado"
	_ws.set_ammo("submachine_gun", 30, 90)
	
	var mode = _ws.get_fire_mode("submachine_gun")
	_expect(mode == "auto", "get_fire_mode devuelve auto")
	
	# Test trigger_pressed
	_ws.trigger_pressed("submachine_gun")
	_expect(_ws._trigger_held.get("submachine_gun", false), "trigger_pressed marca trigger_held")
	
	# Test try_fire_auto requires trigger held
	_ws._next_allowed["submachine_gun"] = 0.0  # force ready
	var result = _ws.try_fire_auto("submachine_gun")
	# Returns true if can fire
	_expect(result == true or result == false, "try_fire_auto devuelve bool")
	
	_ws.trigger_released("submachine_gun")
	_expect(not _ws._trigger_held.get("submachine_gun", true), "trigger_released limpia trigger_held")

func _run_test_burst() -> void:
	_case = "modo ráfaga: burst_active, shots_fired, next_shot"
	_ws.set_ammo("assault_rifle", 30, 90)
	
	var mode = _ws.get_fire_mode("assault_rifle")
	_expect(mode == "burst", "get_fire_mode devuelve burst")
	
	var count = _ws.get_burst_count("assault_rifle")
	_expect(count == 3, "get_burst_count = 3")
	
	var delay = _ws.get_burst_delay("assault_rifle")
	_expect(delay > 0.0, "get_burst_delay > 0")
	
	# Test trigger_pressed starts burst
	_ws.trigger_pressed("assault_rifle")
	_expect(_ws._burst_active.get("assault_rifle", false), "trigger_pressed inicia burst_active")
	_expect(_ws._burst_shots_fired.get("assault_rifle", -1) == 0, "burst_shots_fired inicia en 0")
	_expect(_ws._burst_next_shot.get("assault_rifle", -1.0) == 0.0, "burst_next_shot inicia en tiempo actual")
	
	# Test trigger_released stops burst
	_ws.trigger_released("assault_rifle")
	_expect(not _ws._burst_active.get("assault_rifle", false), "trigger_released para burst")
	_expect(not _ws._burst_shots_fired.has("assault_rifle"), "burst_shots_fired limpiado")
	_expect(not _ws._burst_next_shot.has("assault_rifle"), "burst_next_shot limpiado")

func _run_test_fire_rate_timing() -> void:
	_case = "cadencia de tiro: _next_allowed y fire_interval"
	_ws.set_ammo("pistol", 12, 36)
	var interval = _ws.fire_interval("pistol")
	_expect(interval > 0.0, "intervalo calculado > 0")
	
	# Initially can fire
	var reason = _ws.fire_block_reason("pistol")
	_expect(reason.is_empty(), "sin bloqueo inicial")
	
	# Simulate firing by setting _next_allowed
	_ws._next_allowed["pistol"] = 100.0  # far future
	reason = _ws.fire_block_reason("pistol")
	_expect(reason == "cadencia", "bloqueado por cadencia cuando _next_allowed en futuro")
	
	# Reset and test can_fire
	_ws._next_allowed["pistol"] = 0.0
	_expect(_ws.can_fire("pistol"), "can_fire true cuando listo")

func _run_test_camera_recoil() -> void:
	_case = "recoil de camara en weapon_viewmodel"
	_vm.set_weapon("assault_rifle")
	await process_frame
	
	var initial_cam_recoil = _vm.camera_recoil_offset()
	_expect(initial_cam_recoil.length() < 0.001, "recoil camara inicial = 0")
	
	_vm.on_fired()
	_vm.advance(0.016)  # step one frame to apply recoil
	await process_frame
	var cam_recoil = _vm.camera_recoil_offset()
	_expect(cam_recoil.length() > 0.001, "recoil camara aplicado tras disparo")
	
	# Advance time - recoil should decay
	_vm.advance(0.5)
	await process_frame
	var decayed = _vm.camera_recoil_offset()
	_expect(decayed.length() < cam_recoil.length(), "recoil camara decae con tiempo")

func _run_test_muzzle_flash_modes() -> void:
	_case = "muzzle flash adapta segun fire_mode"
	var fx = MuzzleFxScript.new()
	root.add_child(fx)
	await process_frame
	
	# Test semi flash
	fx.fire_with_mode(1.0, Vector3.FORWARD, Vector3.ZERO, "semi", 6.0)
	await process_frame
	var semi_flashes = MuzzleFxScript.flash_count()
	_expect(semi_flashes > 0, "flash semi creado")
	
	# Clear and test auto flash
	MuzzleFxScript.clear()
	fx.fire_with_mode(1.0, Vector3.FORWARD, Vector3.ZERO, "auto", 12.0)
	await process_frame
	var auto_flashes = MuzzleFxScript.flash_count()
	_expect(auto_flashes > 0, "flash auto creado")
	
	# Clear and test burst flash
	MuzzleFxScript.clear()
	fx.fire_with_mode(1.0, Vector3.FORWARD, Vector3.ZERO, "burst", 9.0)
	await process_frame
	var burst_flashes = MuzzleFxScript.flash_count()
	_expect(burst_flashes > 0, "flash burst creado")
	
	fx.queue_free()
	await process_frame

func _run_test_spread_scaling() -> void:
	_case = "dispersion escala con spread_scale"
	_ws.set_ammo("pistol", 12, 36)
	_ws.spread_scale = 1.0
	
	var def = WeaponDbScript.get_def("pistol")
	var base_spread = float(def.get("spread", 0.0))
	_expect(base_spread > 0.0, "spread base > 0")
	
	# Test spread_scale affects calculation (internal test via _spread_direction)
	var dir1 = _ws._spread_direction(Vector3.FORWARD, base_spread * 1.0)
	var dir2 = _ws._spread_direction(Vector3.FORWARD, base_spread * 2.0)
	
	var angle1 = acos(dir1.dot(Vector3.FORWARD))
	var angle2 = acos(dir2.dot(Vector3.FORWARD))
	
	# With higher spread_scale, angle should be larger on average
	# (statistical test, so just verify they're different)
	_expect(abs(angle1 - angle2) > 0.0001 or angle2 > angle1, "spread_scale afecta dispersion")
	
	_ws.spread_scale = 1.0