class_name VrVehicleInput
extends RefCounted

# Conduccion en VR sin XRServer: volante que se agarra y gira con la muñeca, gatillos,
# entrada/salida, marcha, comodidad (viñeta, giro de vista limitado) y menu de aparicion.

signal entered(vehicle: Node3D)
signal exited(vehicle: Node3D)
signal gear_changed(gear: String)
signal spawn_requested(vehicle_id: String)
signal haptic(hand: String, duration: float, amplitude: float)

const DbScript = preload("res://core/game/vehicle_db.gd")
const MenuScript = preload("res://core/vr/vr_menu.gd")
const WHEEL_RADIUS := 0.19
const GRAB_TOLERANCE := 0.12
const MAX_WHEEL_ANGLE := 2.1
const WHEEL_SPEED := 5.0
const CENTER_SPEED := 3.0
const THROTTLE_RATE := 3.0
const DOOR_RADIUS := 0.45
const LEVER_RADIUS := 0.12
const GEAR_MAX_SPEED := 1.5
const EXIT_MAX_SPEED := 4.0
const VIGNETTE_YAW := 1.2
const MAX_VIEW_YAW_RATE := 1.6
const SPAWN_PREFIX := "spawn:"

var vehicle: Node3D = null
var driver: Node3D = null
var driving: bool = false
var gear: String = "D"
var steer: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0
var wheel_angle: float = 0.0
var vignette: float = 0.0
var hands_on_wheel: Dictionary = {"left": false, "right": false}

var _ref_roll: Dictionary = {}
var _ref_wheel: Dictionary = {}
var _lever_down: Dictionary = {"left": false, "right": false}


static func wrap_angle(value: float) -> float:
	return wrapf(value, -PI, PI)


# Giro de la muñeca (cw visto desde el conductor = positivo) respecto al marco del volante.
static func wrist_roll(hand: Transform3D, wheel: Transform3D) -> float:
	var up: Vector3 = wheel.basis.orthonormalized().inverse() * hand.basis.y
	return atan2(-up.x, up.y)


func can_enter(hand_position: Vector3, target: Node3D) -> bool:
	return target != null and is_instance_valid(target) and target.has_method("door_position") \
		and hand_position.distance_to(target.call("door_position")) <= DOOR_RADIUS


# Entrar agarrando la puerta (mano cerca + agarre) o con el boton de interaccion.
func try_enter(hand_position: Vector3, target: Node3D, who: Node3D, pressed: bool = true) -> bool:
	if driving or not pressed or who == null or not can_enter(hand_position, target):
		return false
	if not bool(target.call("enter", who)):
		return false
	vehicle = target
	driver = who
	driving = true
	_reset_controls()
	entered.emit(target)
	return true


func exit(force: bool = false) -> bool:
	if not driving or vehicle == null or not is_instance_valid(vehicle):
		driving = false
		return false
	if not force and float(vehicle.call("speed")) > EXIT_MAX_SPEED:
		return false
	var left_vehicle := vehicle
	vehicle.call("set_drive_input", 0.0, 0.0, 1.0)
	vehicle.call("exit")
	vehicle = null
	driver = null
	driving = false
	_reset_controls()
	exited.emit(left_vehicle)
	return true


func _reset_controls() -> void:
	steer = 0.0
	throttle = 0.0
	brake = 0.0
	wheel_angle = 0.0
	vignette = 0.0
	hands_on_wheel = {"left": false, "right": false}
	_ref_roll.clear()
	_ref_wheel.clear()


func shift(new_gear: String) -> bool:
	if not ["D", "R", "N"].has(new_gear) or new_gear == gear:
		return false
	if vehicle != null and absf(float(vehicle.call("forward_speed"))) > GEAR_MAX_SPEED:
		return false
	gear = new_gear
	gear_changed.emit(gear)
	return true


func lever_position() -> Vector3:
	return vehicle.to_global(Vector3(0.0, 0.45, 0.25)) if vehicle != null else Vector3.ZERO


# poses: Dictionary hand -> Transform3D; grips/triggers: Dictionary hand -> float.
func update(delta: float, poses: Dictionary, grips: Dictionary, triggers: Dictionary, yaw_rate: float = 0.0) -> Dictionary:
	if not driving or vehicle == null or not is_instance_valid(vehicle):
		return {}
	var dt: float = clampf(delta, 0.0, 0.1)
	var wheel: Transform3D = (vehicle.get("steering_wheel") as Node3D).global_transform
	var targets: Array = []
	for hand in ["left", "right"]:
		var pose: Transform3D = poses[hand]
		var grip: float = float(grips.get(hand, 0.0))
		var near: bool = pose.origin.distance_to(wheel.origin) <= WHEEL_RADIUS + GRAB_TOLERANCE
		var held: bool = bool(hands_on_wheel[hand])
		if not held and grip > 0.6 and near:
			hands_on_wheel[hand] = true
			_ref_roll[hand] = wrist_roll(pose, wheel)
			_ref_wheel[hand] = wheel_angle
			haptic.emit(hand, 0.04, 0.4)
		elif held and grip < 0.3:
			hands_on_wheel[hand] = false
		if bool(hands_on_wheel[hand]):
			var turned: float = wrap_angle(wrist_roll(pose, wheel) - float(_ref_roll[hand]))
			targets.append(float(_ref_wheel[hand]) + turned)
		_gear_lever(hand, pose, grip, bool(hands_on_wheel[hand]))
	if targets.is_empty():
		wheel_angle = move_toward(wheel_angle, 0.0, CENTER_SPEED * dt)
	else:
		var sum := 0.0
		for t in targets:
			sum += float(t)
		var goal: float = clampf(sum / targets.size(), -MAX_WHEEL_ANGLE, MAX_WHEEL_ANGLE)
		wheel_angle = move_toward(wheel_angle, goal, WHEEL_SPEED * dt)
	steer = clampf(wheel_angle / MAX_WHEEL_ANGLE, -1.0, 1.0)
	var want: float = clampf(float(triggers.get("right", 0.0)), 0.0, 1.0)
	throttle = want if want < throttle else move_toward(throttle, want, THROTTLE_RATE * dt)
	brake = clampf(float(triggers.get("left", 0.0)), 0.0, 1.0)
	var sign := 1.0 if gear == "D" else (-1.0 if gear == "R" else 0.0)
	var drive := Vector3(throttle * sign, steer, brake)
	vehicle.call("set_drive_input", drive.x, drive.y, drive.z)
	var target_vignette: float = clampf(absf(yaw_rate) / VIGNETTE_YAW, 0.0, 1.0) * 0.8
	vignette = move_toward(vignette, target_vignette, (4.0 if target_vignette > vignette else 1.5) * dt)
	return {"drive": drive, "wheel_angle": wheel_angle, "vignette": vignette, "gear": gear}


func _gear_lever(hand: String, pose: Transform3D, grip: float, on_wheel: bool) -> void:
	var down: bool = grip > 0.6 and not on_wheel and pose.origin.distance_to(lever_position()) <= LEVER_RADIUS
	if down and not bool(_lever_down[hand]):
		if shift("R" if gear == "D" else "D"):
			haptic.emit(hand, 0.05, 0.6)
	_lever_down[hand] = down


# Vista desde el asiento: el giro de la camara sigue al coche con velocidad limitada.
func seat_eye(target: Node3D) -> Vector3:
	return target.to_global(Vector3(0.3, 1.05, -0.1))


static func limit_view_yaw(current: float, target: float, delta: float) -> float:
	var diff: float = wrap_angle(target - current)
	var step: float = clampf(diff, -MAX_VIEW_YAW_RATE * maxf(delta, 0.0), MAX_VIEW_YAW_RATE * maxf(delta, 0.0))
	return wrap_angle(current + step)


# --- menu de aparicion con VrMenu ---

static func spawn_buttons() -> Array:
	var buttons: Array = []
	var all := DbScript.all()
	var index := 0
	for id in DbScript.list_ids():
		var col: int = index % 2
		var row: int = index / 2
		buttons.append({
			"id": SPAWN_PREFIX + str(id), "label": str((all[id] as Dictionary)["name"]),
			"rect": Rect2(-0.43 + col * 0.44, 0.16 - row * 0.1, 0.42, 0.08),
		})
		index += 1
	return buttons


static func vehicle_id_from_button(button_id: String) -> String:
	return button_id.substr(SPAWN_PREFIX.length()) if button_id.begins_with(SPAWN_PREFIX) else ""


func build_spawn_menu(parent: Node3D):
	var menu = MenuScript.new()
	menu.name = "VrSpawnMenu"
	menu.panel_size = Vector2(0.9, 0.5)
	parent.add_child(menu)
	menu.set_buttons(spawn_buttons())
	menu.build()
	menu.button_pressed.connect(func(button_id: String) -> void:
		var id := vehicle_id_from_button(button_id)
		if not id.is_empty():
			spawn_requested.emit(id))
	return menu
