extends SceneTree

const BootstrapScript = preload("res://core/vr/vr_bootstrap.gd")
const SessionScript = preload("res://core/game/game_session.gd")
const BootScene = preload("res://scenes/vr/vr_boot.tscn")
const FlowScript = preload("res://core/vr/vr_calibration_flow.gd")
const CalScript = preload("res://core/vr/vr_calibration.gd")
const PATH := "user://test_boot_calibration.json"

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

var _n := 0
var _fail := 0


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _t(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


func _press(flow, head: Transform3D, left: Transform3D, right: Transform3D, hand: String = "right") -> Dictionary:
	var r: Dictionary = flow.update_inputs(head, left, right, 1.0 if hand == "left" else 0.0, 1.0 if hand == "right" else 0.0)
	flow.update_inputs(head, left, right, 0.0, 0.0)
	return r


func _drive(flow) -> void:
	_press(flow, _t(0, 1.7, 0), _t(-0.2, 1.0, 0), _t(0.2, 1.0, 0))
	_press(flow, _t(0, 1.7, 0), _t(-0.75, 1.4, 0), _t(0.75, 1.4, 0))
	_press(flow, _t(0, 1.7, 0), _t(-0.2, 0.85, 0), _t(0.2, 0.85, 0))


func _initialize() -> void:
	await process_frame
	_flow_alone()
	await _boot_without_profile()
	await _boot_with_profile()
	await _boot_twice_and_recalibrate()
	_calibration_applies_to_rig()
	_corrupt_profile_recalibrates()
	DirAccess.remove_absolute(PATH)
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)


func _flow_alone() -> void:
	DirAccess.remove_absolute(PATH)
	var cal = CalScript.new()
	cal.profile_path = PATH
	var flow = FlowScript.new()
	root.add_child(flow)
	var done: Array = []
	flow.finished.connect(func(saved): done.append(saved))
	var confirmed: Array = []
	flow.confirmed.connect(func(h): confirmed.append(h))
	flow.begin(cal)
	var arm_down: float = absf((flow.silhouette_arms[0]["pivot"] as Node3D).rotation.z)
	_expect(flow.step_number() == 1 and flow.progress.text.begins_with("PASO 1 DE 3") and flow.title.font_size >= 48, "progreso paso 1")
	_expect(flow.update_inputs(_t(0, 1.7, 0), _t(-0.2, 1.0, 0), _t(0.2, 1.0, 0), 0.3, 0.2).is_empty(), "sin gatillo no avanza")
	var bad: Dictionary = _press(flow, _t(0, 1.7, 0), _t(-0.2, 1.6, 0), _t(0.2, 1.6, 0))
	_expect(not bool(bad["ok"]) and flow.step_number() == 1 and flow.hint.text.find("Baja") >= 0, "paso invalido muestra pista")
	var ok: Dictionary = _press(flow, _t(0, 1.7, 0), _t(-0.2, 1.0, 0), _t(0.2, 1.0, 0))
	_expect(bool(ok["ok"]) and flow.progress.text.begins_with("PASO 2 DE 3"), "gatillo confirma y avanza")
	_expect(confirmed == ["right"] and flow.beep_player != null and flow.beep_player.playing, "aviso haptico (señal) y sonoro al confirmar")
	_expect(absf((flow.silhouette_arms[0]["pivot"] as Node3D).rotation.z) > arm_down + 0.5, "la silueta abre los brazos en el paso 2")
	var held: Dictionary = flow.update_inputs(_t(0, 1.7, 0), _t(-0.75, 1.4, 0), _t(0.75, 1.4, 0), 0.0, 1.0)
	_expect(bool(held["ok"]), "paso 2 con gatillo")
	_expect(flow.update_inputs(_t(0, 1.7, 0), _t(-0.2, 0.85, 0), _t(0.2, 0.85, 0), 0.0, 1.0).is_empty(), "gatillo mantenido no repite")
	flow.update_inputs(_t(0, 1.7, 0), _t(-0.2, 0.85, 0), _t(0.2, 0.85, 0), 0.0, 0.0)
	flow.update_inputs(_t(0, 1.7, 0), _t(-0.2, 0.85, 0), _t(0.2, 0.85, 0), 1.0, 0.0)
	_expect(done == [true] and not flow.active, "fin: perfil guardado y senal")
	_expect(cal.dominant_hand() == "left" and FileAccess.file_exists(PATH), "mano del gatillo en la cadera = dominante, guardado en disco")
	flow.place_in_front(Vector3(0, 1.7, 0), Vector3.FORWARD)
	_expect(flow.global_position.z < 0.0, "panel frente a la cabeza")
	flow.free()


func _boot(mock) -> Node:
	BootstrapScript.interface_override = mock
	var boot := BootScene.instantiate()
	boot.get_script().set("calibration_path_override", PATH)
	root.add_child(boot)
	boot.set("_waited", 3.0)
	return boot


func _cleanup(boot: Node) -> void:
	root.use_xr = false
	var host := root.get_node_or_null("VrStartMenu")
	if host != null:
		host.free()
	boot.free()
	BootstrapScript.interface_override = null
	BootstrapScript.active = null
	SessionScript.platform = ""


func _boot_without_profile() -> void:
	DirAccess.remove_absolute(PATH)
	var boot := _boot(MockXR.new())
	await process_frame
	_expect(boot.flow == null and root.get_node_or_null("VrStartMenu") != null, "sin perfil: menu directo, calibracion opcional (defaults)")
	_expect(not FileAccess.file_exists(PATH), "sin perfil no se fuerza calibracion ni se guarda nada")
	_cleanup(boot)
	await process_frame


func _boot_with_profile() -> void:
	var saved = CalScript.new()
	saved.profile_path = PATH
	saved.save()
	var boot := _boot(MockXR.new())
	await process_frame
	_expect(boot.flow == null and root.get_node_or_null("VrStartMenu") != null, "con perfil: carga silenciosa y menu directo")
	_expect(boot.calibration.last_status == "ok", "perfil cargado")
	_cleanup(boot)
	await process_frame


func _boot_twice_and_recalibrate() -> void:
	for round in 2:
		var boot := _boot(MockXR.new())
		await process_frame
		_expect(boot.flow == null and root.get_node_or_null("VrStartMenu") != null, "arranque %d con perfil guardado: menu sin bloqueo" % (round + 1))
		if round == 1:
			var menu = boot.menu
			var ids: Array = []
			for button in menu.buttons:
				ids.append(button["id"])
			_expect(ids.has("recalibrate"), "el menu VR tiene boton Recalibrar")
			boot._on_menu_button("recalibrate")
			await process_frame
			_expect(boot.flow != null and not FileAccess.file_exists(PATH), "Recalibrar borra el perfil y reinicia la calibracion")
			_drive(boot.flow)
			_expect(FileAccess.file_exists(PATH) and root.get_node_or_null("VrStartMenu") != null, "tras recalibrar vuelve al menu con perfil nuevo")
		_cleanup(boot)
		await process_frame


func _calibration_applies_to_rig() -> void:
	var mode = preload("res://core/vr/vr_game_mode.gd")
	var rig = preload("res://core/vr/vr_rig.gd").new()
	rig.auto_process = false
	rig.xr_availability_override = func() -> bool: return true
	root.add_child(rig)
	var cal = CalScript.new()
	cal.profile_path = PATH
	cal.delete_saved()
	var flow = FlowScript.new()
	root.add_child(flow)
	flow.begin(cal)
	_drive(flow)
	flow.free()
	var side_before: float = rig.bag.bag_side
	_expect(mode.apply_calibration(rig, PATH), "perfil valido aplicado al rig")
	_expect(rig.right_hand.holsters != null and rig.right_hand.holsters.offsets.has("hip"), "fundas calibradas en las manos")
	_expect(rig.right_hand.holsters.offsets["hip"].is_equal_approx(cal.slot_offsets()["hip"]), "la funda de cadera usa la medida del cuerpo")
	_expect(not is_equal_approx(rig.bag.bag_down, 0.40) or not is_equal_approx(rig.bag.bag_side, side_before), "el bolso se coloca segun el cuerpo")
	rig.queue_free()


func _corrupt_profile_recalibrates() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{roto")
	f.close()
	var cal = CalScript.new()
	cal.profile_path = PATH
	_expect(not cal.load_profile() and cal.eye_height() == 1.65, "perfil corrupto -> defaults")
