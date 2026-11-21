class_name VrBootstrap
extends RefCounted

# Arranque OpenXR separado del motor: la interfaz se inyecta (mock en tests).
# xr_active=true solo si initialize() funciono y is_initialized() lo confirma:
# en un telefono la interfaz OpenXR existe pero initialize() falla (no hay runtime/casco).

signal lifecycle(event: String)

const SELF_PATH := "res://core/vr/vr_bootstrap.gd"
const PERFORMANCE_PATH := "res://core/vr/vr_performance.gd"
const ACTION_MAP_PATH := "res://openxr_action_map.tres"
const MAX_FOVEATION := 3

static var active = null
static var last_result: Dictionary = {"xr_active": false, "reason": "not_run"}
static var interface_override: Object = null

var iface: Object = null
var tree: SceneTree = null
var viewport: Viewport = null
var target_refresh_hz: float = 72.0
var foveation: int = 1
var paused_by_xr: bool = false
var focused: bool = false
var _ever_focused: bool = false


static func boot(p_viewport: Viewport, p_tree: SceneTree = null) -> Dictionary:
	var instance = (load(SELF_PATH) as Script).new()
	var result: Dictionary = instance.start(p_viewport, interface_override, p_tree)
	active = instance if bool(result["xr_active"]) else null
	last_result = result
	return result


static func is_xr_active() -> bool:
	if active == null or active.iface == null or not is_instance_valid(active.iface):
		return false
	return bool(last_result.get("xr_active", false)) and bool(active.iface.call("is_initialized"))


# Helper para quien necesite activar XR en un Viewport (no en la Camera3D).
static func enable_viewport_xr(p_viewport: Viewport) -> bool:
	if p_viewport == null or not is_xr_active():
		return false
	p_viewport.use_xr = true
	return true


func start(p_viewport: Viewport, p_iface: Object = null, p_tree: SceneTree = null) -> Dictionary:
	viewport = p_viewport
	tree = p_tree if p_tree != null else (Engine.get_main_loop() as SceneTree)
	iface = p_iface if p_iface != null else _find_openxr()
	if iface == null:
		return _result(false, "no_openxr_interface")
	if not bool(iface.call("is_initialized")) and not bool(iface.call("initialize")):
		return _result(false, "initialize_failed")
	if not bool(iface.call("is_initialized")):
		return _result(false, "not_initialized")
	if viewport == null:
		return _result(false, "no_viewport")
	if iface is XRInterface:
		XRServer.primary_interface = iface as XRInterface
		# El runtime OpenXR marca el ritmo; vsync propio añade latencia.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_setup_action_map()
	viewport.use_xr = true
	_load_performance()
	_apply_foveation()
	_apply_refresh()
	_connect_lifecycle()
	return _result(true, "ok")


func _find_openxr() -> Object:
	if not ClassDB.class_exists("XRServer") or not ClassDB.class_exists("OpenXRInterface"):
		return null
	return XRServer.find_interface("OpenXR")


func _result(ok: bool, reason: String) -> Dictionary:
	if not ok and viewport != null:
		viewport.use_xr = false
	return {"xr_active": ok, "reason": reason}


func _load_performance() -> void:
	if not ResourceLoader.exists(PERFORMANCE_PATH):
		return
	var script := load(PERFORMANCE_PATH) as Script
	if script == null or not script.has_method("profile_for_mode"):
		return
	var profile: Dictionary = script.call("profile_for_mode", "quest_72", 0)
	target_refresh_hz = float(profile.get("refresh_hz", target_refresh_hz))
	foveation = int(profile.get("foveation", foveation))


func _apply_foveation() -> void:
	if "foveation_level" in iface:
		iface.set("foveation_level", clampi(foveation, 0, MAX_FOVEATION))
	if "foveation_dynamic" in iface:
		iface.set("foveation_dynamic", true)


# Las tasas solo existen con sesion activa: se reintenta en session_begun.
func _apply_refresh() -> bool:
	if not iface.has_method("get_available_display_refresh_rates"):
		return false
	var best := 0.0
	for rate in iface.call("get_available_display_refresh_rates"):
		var hz := float(rate)
		if hz <= target_refresh_hz + 0.5 and hz > best:
			best = hz
	if best <= 0.0:
		return false
	iface.set("display_refresh_rate", best)
	Engine.physics_ticks_per_second = int(roundf(best))
	return true


func _setup_action_map() -> void:
	if not ResourceLoader.exists(ACTION_MAP_PATH):
		return
	var action_map = load(ACTION_MAP_PATH) as OpenXRActionMap
	if action_map != null and iface.has_method("set_action_map"):
		iface.call("set_action_map", action_map)
		if iface.has_method("get_action_set"):
			var action_set = iface.call("get_action_set", "godot")
			if action_set != null and action_set.has_method("activate"):
				action_set.call("activate")


func _connect_lifecycle() -> void:
	for name in ["session_begun", "session_visible", "session_focussed", "session_stopping",
			"session_loss_pending", "pose_recentered", "user_presence_changed"]:
		if iface.has_signal(name) and not iface.is_connected(name, Callable(self, "_on_" + name)):
			iface.connect(name, Callable(self, "_on_" + name))


func _on_session_begun() -> void:
	_apply_refresh()
	lifecycle.emit("begun")


# Visible sin foco = menu del sistema / Guardian: el juego no recibe input.
# No pausar en el "visible" inicial (Guardian al arrancar), solo si ya tuvimos foco antes.
func _on_session_visible() -> void:
	focused = false
	if _ever_focused:
		pause_game()
	lifecycle.emit("visible")


func _on_session_focussed() -> void:
	focused = true
	_ever_focused = true
	resume_game()
	lifecycle.emit("focused")


func _on_session_stopping() -> void:
	focused = false
	pause_game()
	lifecycle.emit("stopping")


func _on_session_loss_pending() -> void:
	focused = false
	pause_game()
	lifecycle.emit("loss_pending")


func _on_pose_recentered() -> void:
	lifecycle.emit("recentered")


# Casco quitado (XR_EXT_user_presence).
func _on_user_presence_changed(present: bool) -> void:
	if present and focused:
		resume_game()
	elif not present:
		pause_game()
	lifecycle.emit("present" if present else "absent")


func pause_game() -> void:
	if tree == null or tree.paused:
		return
	tree.paused = true
	paused_by_xr = true


# Solo deshace la pausa que puso XR, nunca la del menu de pausa del juego.
func resume_game() -> void:
	if tree == null or not paused_by_xr:
		return
	tree.paused = false
	paused_by_xr = false


func shutdown() -> void:
	# Desconectar todas las seniales del ciclo de vida
	if iface != null:
		for name in ["session_begun", "session_visible", "session_focussed", "session_stopping",
				"session_loss_pending", "pose_recentered", "user_presence_changed"]:
			if iface.has_signal(name) and iface.is_connected(name, Callable(self, "_on_" + name)):
				iface.disconnect(name, Callable(self, "_on_" + name))
		# Desinicializar interfaz XR si tiene el metodo
		if iface.has_method("uninitialize"):
			iface.call("uninitialize")
	# Limpiar viewport
	if viewport != null and is_instance_valid(viewport):
		viewport.use_xr = false
	# Limpiar XRServer
	if XRServer.primary_interface != null:
		XRServer.primary_interface = null
	# Restaurar vsync
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	# Limpiar estado estatico
	active = null
	last_result = {"xr_active": false, "reason": "shutdown"}
	iface = null
	tree = null
	viewport = null
	paused_by_xr = false
	focused = false
	_ever_focused = false
