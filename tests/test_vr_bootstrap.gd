extends SceneTree

const BootstrapScript = preload("res://core/vr/vr_bootstrap.gd")
const SessionScript = preload("res://core/game/game_session.gd")
const BootScene = preload("res://scenes/vr/vr_boot.tscn")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""


class MockXR extends RefCounted:
	signal session_begun
	signal session_visible
	signal session_focussed
	signal session_stopping
	signal session_loss_pending
	signal pose_recentered
	signal user_presence_changed(present: bool)

	var init_ok: bool = true
	var stays_uninitialized: bool = false
	var initialized: bool = false
	var init_calls: int = 0
	var rates: Array = []
	var display_refresh_rate: float = 0.0
	var foveation_level: int = 0
	var foveation_dynamic: bool = false

	func initialize() -> bool:
		init_calls += 1
		initialized = init_ok and not stays_uninitialized
		return init_ok

	func is_initialized() -> bool:
		return initialized

	func get_available_display_refresh_rates() -> Array:
		return rates


func _initialize() -> void:
	await process_frame
	var ticks := Engine.physics_ticks_per_second
	_test_success()
	_test_failures()
	_test_real_interface_without_headset()
	await _test_boot_scene_xr()
	await _test_boot_scene_fallback()
	Engine.physics_ticks_per_second = ticks
	paused = false
	BootstrapScript.interface_override = null
	BootstrapScript.active = null
	BootstrapScript.last_result = {"xr_active": false, "reason": "not_run"}
	SessionScript.platform = ""
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_success() -> void:
	_case = "initialize ok"
	var vp := SubViewport.new()
	root.add_child(vp)
	var mock := MockXR.new()
	BootstrapScript.interface_override = mock
	var result: Dictionary = BootstrapScript.boot(vp, self)
	_expect(bool(result["xr_active"]) and result["reason"] == "ok", "resultado xr_active con razon ok: %s" % result)
	_expect(mock.init_calls == 1, "initialize() llamado una vez")
	_expect(vp.use_xr, "use_xr activo en el Viewport")
	_expect(BootstrapScript.is_xr_active(), "is_xr_active con interfaz inicializada")
	_expect(SessionScript.detect_platform() == "vr", "detect_platform = vr con XR real")
	_expect(mock.foveation_level == 1 and mock.foveation_dynamic, "foveacion de VrPerformance (1, dinamica)")
	_expect(mock.display_refresh_rate == 0.0, "sin sesion no se fija refresco")
	var events: Array = []
	BootstrapScript.active.lifecycle.connect(func(e: String) -> void: events.append(e))

	_case = "ciclo de vida"
	mock.rates = [60.0, 72.0, 90.0, 120.0]
	mock.session_begun.emit()
	_expect(is_equal_approx(mock.display_refresh_rate, 72.0), "session_begun fija 72 Hz: %s" % mock.display_refresh_rate)
	_expect(Engine.physics_ticks_per_second == 72, "fisica a 72 Hz")
	mock.session_focussed.emit()
	_expect(not paused, "con foco el juego corre")
	mock.session_visible.emit()
	_expect(paused, "menu del sistema (visible sin foco) pausa")
	mock.session_focussed.emit()
	_expect(not paused, "recuperar foco reanuda")
	mock.user_presence_changed.emit(false)
	_expect(paused, "quitarse el casco pausa")
	mock.user_presence_changed.emit(true)
	_expect(not paused, "ponerse el casco con foco reanuda")
	paused = true
	mock.session_visible.emit()
	mock.session_focussed.emit()
	_expect(paused, "no quita una pausa que puso el juego")
	paused = false
	mock.session_stopping.emit()
	_expect(paused, "session_stopping pausa")
	mock.session_focussed.emit()
	mock.pose_recentered.emit()
	_expect(events.has("recentered") and events.has("stopping") and events.has("begun"), "lifecycle reemite eventos: %s" % [events])

	_case = "helper viewport"
	var other := SubViewport.new()
	root.add_child(other)
	_expect(BootstrapScript.enable_viewport_xr(other) and other.use_xr, "enable_viewport_xr activa use_xr del Viewport")
	other.free()
	vp.free()


func _test_failures() -> void:
	_case = "initialize falla (interfaz sin casco)"
	var vp := SubViewport.new()
	root.add_child(vp)
	var mock := MockXR.new()
	mock.init_ok = false
	BootstrapScript.interface_override = mock
	var result: Dictionary = BootstrapScript.boot(vp, self)
	_expect(not bool(result["xr_active"]) and result["reason"] == "initialize_failed", "fallback: %s" % result)
	_expect(not vp.use_xr, "use_xr sigue apagado")
	_expect(not BootstrapScript.is_xr_active() and BootstrapScript.active == null, "sin bootstrap activo")
	_expect(SessionScript.detect_platform() != "vr", "detect_platform no es vr")

	_case = "initialize true pero no inicializada"
	mock = MockXR.new()
	mock.stays_uninitialized = true
	BootstrapScript.interface_override = mock
	result = BootstrapScript.boot(vp, self)
	_expect(result["reason"] == "not_initialized" and not vp.use_xr, "rechaza interfaz no inicializada: %s" % result)
	_expect(SessionScript.detect_platform() != "vr", "detect_platform no es vr")

	_case = "perdida de sesion sin bootstrap"
	_expect(not paused, "un fallo no pausa el juego")
	vp.free()


func _test_real_interface_without_headset() -> void:
	_case = "interfaz OpenXR real sin casco (headless)"
	BootstrapScript.interface_override = null
	var vp := SubViewport.new()
	root.add_child(vp)
	var result: Dictionary = BootstrapScript.boot(vp, self)
	_expect(not bool(result["xr_active"]), "sin runtime OpenXR no hay XR: %s" % result)
	_expect(not vp.use_xr, "use_xr apagado")
	_expect(SessionScript.detect_platform() in ["pc", "android"], "detect_platform pantalla: %s" % SessionScript.detect_platform())
	vp.free()


func _test_boot_scene_xr() -> void:
	_case = "vr_boot con XR"
	var mock := MockXR.new()
	BootstrapScript.interface_override = mock
	var profile_path := "user://test_boot_profile.json"
	var cal = preload("res://core/vr/vr_calibration.gd").new()
	cal.profile_path = profile_path
	cal.save()
	var boot := BootScene.instantiate()
	boot.get_script().set("calibration_path_override", profile_path)
	root.add_child(boot)
	boot.set("_waited", 3.0)
	await process_frame
	DirAccess.remove_absolute(profile_path)
	_expect(bool(boot.get("result").get("xr_active", false)), "vr_boot activa XR")
	_expect(SessionScript.platform == "vr", "GameSession.platform = vr")
	var host := root.get_node_or_null("VrStartMenu")
	_expect(host != null, "menu VR 3D construido directamente")
	var camera = boot.get("xr_camera")
	_expect(camera != null and (camera as Camera3D).current, "XRCamera3D es la camara actual")
	_expect((boot.get("controllers") as Array).size() == 2, "dos controladores con laser")
	_expect(root.get_node_or_null("MainMenu") == null, "no hay menu plano en VR")
	mock.session_focussed.emit()
	await process_frame
	_expect(bool(boot.get("_placed")), "menu recolocado frente a la cabeza al tener foco")
	root.use_xr = false
	if host != null:
		host.free()
	boot.free()
	await process_frame


func _test_boot_scene_fallback() -> void:
	_case = "vr_boot sin XR"
	var mock := MockXR.new()
	mock.init_ok = false
	BootstrapScript.interface_override = mock
	SessionScript.platform = ""
	var boot := BootScene.instantiate()
	root.add_child(boot)
	current_scene = boot
	await process_frame
	await process_frame
	await process_frame
	_expect(current_scene != null and current_scene.name == "MainMenu", "cambia al menu plano: %s" % current_scene)
	_expect(root.get_node_or_null("VrStartMenu") == null, "sin menu VR")
	_expect(not root.use_xr, "use_xr apagado en pantalla")
	if current_scene != null:
		current_scene.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_case, message])
