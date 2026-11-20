extends Node3D

# Escena inicial SOLO de la build VR: con XR real muestra el menu 3D con laser;
# sin XR (telefono) salta al menu plano normal.

const MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const SESSION_PATH := "res://core/game/game_session.gd"
const GAME_MODE_PATH := "res://core/vr/vr_game_mode.gd"
const CALIBRATION_PATH := "res://core/vr/vr_calibration.gd"
const FLOW_PATH := "res://core/vr/vr_calibration_flow.gd"
const BootstrapScript = preload("res://core/vr/vr_bootstrap.gd")

static var calibration_path_override: String = ""
const TRIGGER_ON := 0.6
const TRIGGER_OFF := 0.3

var result: Dictionary = {}
var menu = null
var host: Node = null
var calibration = null
var flow = null
var origin: XROrigin3D = null
var xr_camera: XRCamera3D = null
var controllers: Array = []
var _beams: Dictionary = {}
var _trigger_down: Dictionary = {}
var _placed: bool = false
var _waited: float = 0.0
var _diag_label: Label3D = null
var _diag_lines: Array = []
var _menu_ok: bool = false


func _ready() -> void:
	result = BootstrapScript.boot(get_viewport(), get_tree())
	if not bool(result["xr_active"]) or not ResourceLoader.exists(GAME_MODE_PATH):
		get_tree().call_deferred("change_scene_to_file", MAIN_MENU)
		return
	(load(SESSION_PATH) as Script).set("platform", "vr")
	RenderingServer.set_default_clear_color(Color(0.04, 0.08, 0.2))
	_load_calibration()
	_build_xr_nodes()
	xr_camera.current = true
	_diag("1/4 XR activo, nodos creados")
	BootstrapScript.active.lifecycle.connect(_on_lifecycle)
	# Sin perfil se usan valores por defecto: la calibracion es opcional (RECALIBRAR).
	_start_menu()


func _start_calibration() -> void:
	if not ResourceLoader.exists(FLOW_PATH) or calibration == null:
		_start_menu()
		return
	flow = (load(FLOW_PATH) as Script).new()
	flow.name = "VrCalibrationFlow"
	add_child(flow)
	flow.begin(calibration)
	flow.finished.connect(_on_calibration_finished)
	flow.confirmed.connect(_on_calibration_confirmed)
	_placed = false
	_waited = 0.0


func _on_calibration_confirmed(hand: String) -> void:
	for controller in controllers:
		if str(controller.tracker) == hand + "_hand" and controller.has_method("trigger_haptic_pulse"):
			controller.trigger_haptic_pulse(&"haptic", 0.0, 0.8, 0.12, 0.0)


func _on_calibration_finished(_saved: bool) -> void:
	flow.queue_free()
	flow = null
	_start_menu()


func _start_menu() -> void:
	var mode := load(GAME_MODE_PATH) as Script
	if mode == null:
		_diag("ERROR: vr_game_mode.gd no carga")
		return
	_diag("2/4 modo VR cargado")
	var meta = mode.call("default_map_meta", 4242)
	if typeof(meta) != TYPE_DICTIONARY or (meta as Dictionary).is_empty():
		_diag("AVISO: mapa por defecto vacio, uso generador simple")
		var gen := load("res://core/maps/map_generator.gd") as Script
		meta = gen.call("generate", 4242, {"width": 24, "height": 18, "obstacle_density": 0.18, "spawn_count": 4}) if gen != null else {}
	_diag("3/4 mapa listo (%s)" % str((meta as Dictionary).get("choice_label", "base")))
	menu = mode.call("build_start_menu", meta, get_tree())
	if menu == null:
		_diag("ERROR: el menu VR no se pudo crear")
		return
	host = menu.get_parent()
	xr_camera.current = true
	menu.connect("button_pressed", Callable(self, "_on_menu_button"))
	_placed = false
	_menu_ok = true
	_diag("4/4 menu creado: apunta con el laser")


func _diag(text: String) -> void:
	print("[vr_boot] ", text)
	if xr_camera == null:
		return
	if _diag_label == null:
		_diag_label = Label3D.new()
		_diag_label.name = "BootDiag"
		_diag_label.position = Vector3(0.0, -0.25, -1.3)
		_diag_label.pixel_size = 0.0016
		_diag_label.font_size = 56
		_diag_label.modulate = Color(1.0, 0.95, 0.4)
		_diag_label.no_depth_test = true
		_diag_label.shaded = false
		_diag_label.fixed_size = false
		xr_camera.add_child(_diag_label)
	_diag_lines.append(text)
	_diag_label.text = "\n".join(_diag_lines)


# true si habia un perfil valido (se carga en silencio); si falta o esta corrupto se recalibra.
func _load_calibration() -> bool:
	if not ResourceLoader.exists(CALIBRATION_PATH):
		return true
	var script := load(CALIBRATION_PATH) as Script
	if script == null:
		return true
	calibration = script.new()
	if not calibration_path_override.is_empty():
		calibration.profile_path = calibration_path_override
	var ok: bool = bool(calibration.call("load_profile"))
	return ok and calibration.last_status == "ok"


func _build_xr_nodes() -> void:
	origin = XROrigin3D.new()
	origin.name = "XROrigin3D"
	add_child(origin)
	xr_camera = XRCamera3D.new()
	xr_camera.name = "XRCamera3D"
	origin.add_child(xr_camera)
	for hand in ["right_hand", "left_hand"]:
		var controller := XRController3D.new()
		controller.name = hand
		controller.tracker = StringName(hand)
		controller.pose = &"aim"
		origin.add_child(controller)
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.002
		mesh.bottom_radius = 0.002
		mesh.height = 1.0
		var beam := MeshInstance3D.new()
		beam.mesh = mesh
		beam.rotation.x = PI * 0.5
		controller.add_child(beam)
		controllers.append(controller)
		_beams[hand] = beam
		_trigger_down[hand] = false


func _process(delta: float) -> void:
	if xr_camera == null:
		return
	_waited += delta
	if _diag_label != null and _menu_ok and _waited > 12.0:
		_diag_label.queue_free()
		_diag_label = null
	if flow != null:
		_process_calibration()
		return
	if menu == null:
		return
	if not _placed and _can_place():
		_place_menu()
	for controller in controllers:
		_point(controller)


# Si el evento de foco llego antes de conectar la señal, no se espera para siempre.
func _can_place() -> bool:
	return _waited > 1.5 or (BootstrapScript.active != null and BootstrapScript.active.focused)


func _process_calibration() -> void:
	if not _placed and _can_place():
		flow.place_in_front(xr_camera.global_position, -xr_camera.global_transform.basis.z)
		_placed = true
	var inverse := origin.global_transform.affine_inverse()
	var left: XRController3D = controllers[1]
	var right: XRController3D = controllers[0]
	flow.update_inputs(inverse * xr_camera.global_transform, inverse * left.global_transform,
		inverse * right.global_transform, left.get_float(&"trigger"), right.get_float(&"trigger"))


func _place_menu() -> void:
	var forward := -xr_camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	menu.call("open_in_front", xr_camera.global_position, forward.normalized())
	_placed = true


func _point(controller: XRController3D) -> void:
	var hand := str(controller.tracker)
	var beam: MeshInstance3D = _beams[hand]
	beam.visible = controller.get_is_active()
	if not beam.visible:
		return
	var origin := controller.global_position
	var direction := -controller.global_transform.basis.z
	var hit: Dictionary = menu.call("pointer_hit", origin, direction)
	var length := 2.0
	if bool(hit.get("hit", false)):
		length = clampf(origin.distance_to(hit.get("point", origin)), 0.1, 3.0)
	beam.scale.y = length
	beam.position.z = -length * 0.5
	var value := controller.get_float(&"trigger")
	if not _trigger_down[hand] and value > TRIGGER_ON:
		_trigger_down[hand] = true
		menu.call("try_press", origin, direction, true)
	elif _trigger_down[hand] and value < TRIGGER_OFF:
		_trigger_down[hand] = false


func _on_lifecycle(event: String) -> void:
	if event == "recentered" or event == "focused":
		_placed = false


# El host del menu cuelga de root y sobreviviria al cambio de escena.
func _on_menu_button(button_id: String) -> void:
	if host != null and is_instance_valid(host):
		host.queue_free()
	menu = null
	if button_id == "recalibrate" and calibration != null:
		calibration.delete_saved()
		_start_calibration()
