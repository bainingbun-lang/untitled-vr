class_name VrInput extends RefCounted

const ACTION_MAP_PATH := "res://openxr_action_map.tres"

var _action_map: OpenXRActionMap = null
var _interface: Object = null
var _input_provider = null
var _grip_values: Dictionary = {"left": 0.0, "right": 0.0}
var _trigger_values: Dictionary = {"left": 0.0, "right": 0.0}
var _stick_values: Dictionary = {"left": Vector2.ZERO, "right": Vector2.ZERO}
var _button_states: Dictionary = {}
var _is_simulated: bool = false

signal haptic(hand: String, duration: float, frequency: float, amplitude: float)

func _init(input_provider = null) -> void:
	_input_provider = input_provider

func initialize(iface: Object = null) -> bool:
	if iface != null:
		_interface = iface
	else:
		if not ClassDB.class_exists("XRServer") or not ClassDB.class_exists("OpenXRInterface"):
			return false
		_interface = XRServer.find_interface("OpenXR")
	
	if _interface == null:
		return false
	
	if not bool(_interface.call("is_initialized")):
		if not bool(_interface.call("initialize")):
			return false
	
	if ResourceLoader.exists(ACTION_MAP_PATH):
		_action_map = load(ACTION_MAP_PATH) as OpenXRActionMap
		if _action_map != null and _interface.has_method("set_action_map"):
			_interface.call("set_action_map", _action_map)
			if _interface.has_method("get_action_set"):
				var set_ = _interface.call("get_action_set", "godot")
				if set_ != null and set_.has_method("activate"):
					set_.call("activate")
	
	return bool(_interface.call("is_initialized"))

func set_simulated(simulated: bool) -> void:
	_is_simulated = simulated

func set_input_provider(provider) -> void:
	_input_provider = provider

func _get_controller(hand: String) -> Object:
	if _input_provider != null and _input_provider.has_method("controller_for"):
		return _input_provider.call("controller_for", hand)
	if _interface != null and _interface.has_method("get_controller"):
		return _interface.call("get_controller", hand)
	return null

func get_pose(hand: String) -> Transform3D:
	# No delegar en get_pose del proveedor: el proveedor es VrRig, que delega de vuelta aqui (recursion infinita).
	var controller = _get_controller(hand)
	if controller != null:
		return controller.global_transform
	return Transform3D.IDENTITY

func is_grip_pressed(hand: String) -> bool:
	if _is_simulated:
		return _grip_values.get(hand, 0.0) > 0.5
	return _read_action_value(hand, "grip") > 0.5

func is_trigger_pressed(hand: String) -> bool:
	if _is_simulated:
		return _trigger_values.get(hand, 0.0) > 0.5
	return _read_action_value(hand, "trigger") > 0.5

func get_grip_value(hand: String) -> float:
	if _is_simulated:
		return _grip_values.get(hand, 0.0)
	return _read_action_value(hand, "grip")

func get_trigger_value(hand: String) -> float:
	if _is_simulated:
		return _trigger_values.get(hand, 0.0)
	return _read_action_value(hand, "trigger")

func get_stick(hand: String) -> Vector2:
	if _is_simulated:
		return _stick_values.get(hand, Vector2.ZERO)
	if _input_provider != null and _input_provider.has_method("get_stick"):
		return _input_provider.get_stick(hand)
	var controller = _get_controller(hand)
	if controller != null:
		if controller.has_method("get_vector2"):
			return controller.call("get_vector2", &"thumbstick")
		if controller.has_method("get_axis"):
			var x = controller.call("get_axis", &"thumbstick_x")
			var y = controller.call("get_axis", &"thumbstick_y")
			return Vector2(float(x), float(y))
	return Vector2.ZERO

func is_button_pressed(hand: String, action: String) -> bool:
	if _is_simulated:
		return bool(_button_states.get("%s/%s" % [hand, action], false))
	var controller = _get_controller(hand)
	if controller != null and controller.has_method("is_button_pressed"):
		return bool(controller.call("is_button_pressed", StringName(action)))
	return false

func set_grip_value(hand: String, value: float) -> void:
	_grip_values[hand] = clampf(value, 0.0, 1.0)

func set_trigger_value(hand: String, value: float) -> void:
	_trigger_values[hand] = clampf(value, 0.0, 1.0)

func set_stick(hand: String, value: Vector2) -> void:
	_stick_values[hand] = value

func set_button(hand: String, action: String, pressed: bool) -> void:
	_button_states["%s/%s" % [hand, action]] = pressed

func wants_to_grab(hand: String) -> bool:
	return is_grip_pressed(hand)

func wants_to_trigger(hand: String) -> bool:
	return is_trigger_pressed(hand)

func wants_to_reload(hand: String) -> bool:
	return is_button_pressed(hand, "a") or is_button_pressed(hand, "x")

func wants_menu(hand: String = "left") -> bool:
	return is_button_pressed(hand, "menu")

func trigger_haptic(hand: String, duration: float, frequency: float, amplitude: float) -> void:
	haptic.emit(hand, duration, frequency, amplitude)
	var controller = _get_controller(hand)
	if controller != null and controller.has_method("trigger_haptic"):
		controller.call("trigger_haptic", duration, frequency, amplitude)

func _controller_value(hand: String, input_name: String) -> float:
	# Lectura directa del XRController3D (igual que godot-xr-tools); la via get_action_state no existe en Godot.
	var c = null
	if _input_provider != null:
		c = _input_provider.get(hand + "_controller")
	if c == null or not (c is XRController3D):
		return -1.0
	return c.get_float(input_name)

func _read_action_value(hand: String, action_name: String) -> float:
	var direct := _controller_value(hand, action_name)
	if direct >= 0.0:
		return direct
	if _interface == null or not _interface.has_method("get_action_state"):
		return 0.0
	var state = _interface.call("get_action_state", "godot", action_name, hand)
	if state is Dictionary:
		if state.has("value"):
			return float(state["value"])
		if state.has("pressed") and bool(state["pressed"]):
			return 1.0
	if state is float or state is int:
		return float(state)
	return 0.0

func shutdown() -> void:
	_interface = null
	_action_map = null
	_input_provider = null