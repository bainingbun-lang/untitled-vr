class_name VrGrab
extends RefCounted

signal grabbed(zone: String, hand: String)
signal released(mode: String, velocity: Vector3)
signal haptic(hand: String, duration: float, amplitude: float)

const GRAB_RADIUS: float = 0.12
const MAX_DELTA: float = 0.25
const MAX_SUBSTEP: float = 1.0 / 120.0
const MAX_THROW_SPEED: float = 8.0
const LENGTHS: Dictionary = {
	"pistol": 0.22,
	"submachine_gun": 0.40,
	"assault_rifle": 0.60,
	"shotgun": 0.70,
	"sniper_rifle": 0.82,
	"bat": 0.55,
}

var mass: float = 1.0
var stiffness: float = 180.0
var damping: float = 22.0
var grab_radius: float = GRAB_RADIUS

var _grabbed: bool = false
var _hand: String = "right"
var _zone: String = ""
var _grip: float = 0.0
var _hand_offset: Vector3 = Vector3.ZERO
var _hand_basis: Basis = Basis.IDENTITY
var _pose: Transform3D = Transform3D.IDENTITY
var _velocity: Vector3 = Vector3.ZERO
var _prop: Node3D = null
var _prop_frozen: bool = false


func _init(weapon_mass: float = 1.0) -> void:
	mass = maxf(weapon_mass, 0.05)


func is_grabbing() -> bool:
	return _grabbed


func held_zone() -> String:
	return _zone


func held_hand() -> String:
	return _hand


func held_prop() -> Node3D:
	return _prop


func weapon_pose() -> Transform3D:
	return _pose


func linear_velocity() -> Vector3:
	return _velocity


static func weapon_length(weapon_id: String) -> float:
	if LENGTHS.has(weapon_id):
		return float(LENGTHS[weapon_id])
	return 0.40


static func grip_zones(weapon_id: String) -> Dictionary:
	var length := weapon_length(weapon_id)
	var is_sidearm: bool = weapon_id == "pistol" or weapon_id == "bat"
	var handguard: float = length * (0.42 if is_sidearm else 0.55)
	return {
		"grip": Vector3(0.0, -0.05, 0.0),
		"handguard": Vector3(0.0, -0.02, -handguard),
		"stock": Vector3(0.0, 0.01, length * 0.34),
		"magazine": Vector3(0.0, -0.14, 0.02),
		"slide": Vector3(0.0, 0.06, -length * 0.18),
		"bolt": Vector3(0.0, 0.06, -length * 0.06),
		"pump": Vector3(0.0, -0.07, -handguard),
	}


static func zone_point(zone: String, weapon_pose: Transform3D, weapon_id: String) -> Vector3:
	var zones: Dictionary = grip_zones(weapon_id)
	if not zones.has(zone):
		return weapon_pose.origin
	var local: Vector3 = zones[zone]
	return weapon_pose.origin + weapon_pose.basis.x * local.x + weapon_pose.basis.y * local.y + weapon_pose.basis.z * local.z


static func nearest_zone(
	hand_pose: Transform3D, weapon_pose: Transform3D, weapon_id: String, radius: float = GRAB_RADIUS
) -> Dictionary:
	var best := ""
	var best_distance: float = 1.0e9
	var best_point := Vector3.ZERO
	var zones: Dictionary = grip_zones(weapon_id)
	for zone in zones.keys():
		var point := zone_point(str(zone), weapon_pose, weapon_id)
		var distance: float = hand_pose.origin.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = str(zone)
			best_point = point
	var limit: float = maxf(radius, 0.001)
	return {
		"zone": best if best_distance <= limit else "",
		"distance": best_distance,
		"point": best_point,
		"ok": best_distance <= limit,
	}


func grab(
	hand_pose: Transform3D, weapon_pose: Transform3D, weapon_id: String,
	grip_value: float = 1.0, zone: String = ""
) -> bool:
	if _grabbed:
		return false
	var found: Dictionary = nearest_zone(hand_pose, weapon_pose, weapon_id, grab_radius)
	if zone.is_empty():
		if not bool(found["ok"]):
			return false
		zone = str(found["zone"])
	elif not grip_zones(weapon_id).has(zone):
		return false
	_grabbed = true
	_zone = zone
	_grip = clampf(grip_value, 0.0, 1.0)
	_pose = weapon_pose
	_velocity = Vector3.ZERO
	var delta_pose: Vector3 = weapon_pose.origin - hand_pose.origin
	_hand_offset = hand_pose.basis.inverse() * safe_vector(delta_pose)
	_hand_basis = hand_pose.basis.inverse() * weapon_pose.basis
	grabbed.emit(zone, _hand)
	_pulse(0.045, 0.35)
	return true


func set_hand(hand_name: String) -> void:
	_hand = "left" if hand_name == "left" else "right"


func step(delta: float, hand_pose: Transform3D, grip_value: float = 1.0) -> Transform3D:
	if not _grabbed:
		return _pose
	_grip = clampf(grip_value, 0.0, 1.0)
	var total: float = clampf(delta, 0.0, MAX_DELTA)
	if total <= 0.0:
		return _pose
	var target_origin: Vector3 = hand_pose.origin + hand_pose.basis * _hand_offset
	var target_basis: Basis = hand_pose.basis * _hand_basis
	var ticks: int = maxi(1, int(ceil(total / MAX_SUBSTEP)))
	ticks = mini(ticks, 32)
	var dt: float = total / float(ticks)
	var ratio: float = clampf(stiffness / maxf(mass, 0.05), 1.0, 4000.0)
	var drag: float = clampf(damping / sqrt(maxf(mass, 0.05)), 0.0, 200.0)
	var blend: float = 1.0 - exp(-maxf(drag, 0.5) * total * 0.25)
	for i in ticks:
		var accel: Vector3 = (target_origin - _pose.origin) * ratio - _velocity * drag
		_velocity += accel * dt
		_pose.origin += _velocity * dt
	var axis_x: Vector3 = _pose.basis.x.lerp(target_basis.x, blend)
	var axis_y: Vector3 = _pose.basis.y.lerp(target_basis.y, blend)
	if axis_x.length_squared() <= 0.000001:
		axis_x = target_basis.x
	axis_x = axis_x.normalized()
	axis_y = (axis_y - axis_x * axis_x.dot(axis_y)).normalized()
	if axis_y.length_squared() <= 0.000001:
		axis_y = target_basis.y
	_pose.basis = Basis(axis_x, axis_y, axis_x.cross(axis_y))
	_pose.origin = safe_vector(_pose.origin)
	_velocity = safe_vector(_velocity)
	return _pose


func release(mode: String = "fall", velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	if not _grabbed:
		return {"mode": "", "velocity": Vector3.ZERO}
	var result := {"mode": "holster" if mode == "holster" else "fall", "velocity": safe_vector(velocity)}
	_grabbed = false
	_zone = ""
	_grip = 0.0
	_velocity = safe_vector(velocity)
	released.emit(str(result["mode"]), result["velocity"])
	return result


static func throw_velocity(current: Transform3D, previous: Transform3D, delta: float) -> Vector3:
	var dt: float = maxf(delta, 0.0001)
	var raw: Vector3 = (current.origin - previous.origin) / dt
	raw = safe_vector(raw)
	if raw.length() > MAX_THROW_SPEED:
		raw = raw.normalized() * MAX_THROW_SPEED
	return raw


static func safe_vector(value: Vector3) -> Vector3:
	var result := value
	if is_nan(result.x) or is_inf(result.x):
		result.x = 0.0
	if is_nan(result.y) or is_inf(result.y):
		result.y = 0.0
	if is_nan(result.z) or is_inf(result.z):
		result.z = 0.0
	return result


static func aim_line(primary: Transform3D, secondary: Transform3D) -> Vector3:
	var line: Vector3 = secondary.origin - primary.origin
	if line.length_squared() <= 0.000001:
		line = -primary.basis.z
	return safe_vector(line).normalized() if safe_vector(line).length_squared() > 0.000001 else Vector3.FORWARD


static func stock_at_shoulder(stock_pose: Transform3D, head_pose: Transform3D, radius: float = 0.14) -> bool:
	var cheek: Vector3 = head_pose.origin - head_pose.basis.y * 0.06 + head_pose.basis.z * 0.06
	return stock_pose.origin.distance_to(cheek) <= maxf(radius, 0.01)


static func steadiness(two_handed: bool, stock_at_cheek: bool) -> float:
	var factor: float = 1.0
	if two_handed:
		factor *= 0.45
	if stock_at_cheek:
		factor *= 0.45
	return clampf(factor, 0.10, 1.0)


static func sway(base_amplitude: float, two_handed: bool, stock_at_cheek: bool) -> float:
	return maxf(base_amplitude, 0.0) * steadiness(two_handed, stock_at_cheek)


func grab_prop(prop: Node3D, hand_pose: Transform3D, radius: float = GRAB_RADIUS) -> bool:
	if not is_instance_valid(prop) or _prop != null:
		return false
	var in_group: bool = prop.is_in_group("physics_props") or prop.is_in_group("grabbable")
	if not in_group:
		return false
	if prop.global_transform.origin.distance_to(hand_pose.origin) > maxf(radius, 0.01):
		return false
	_prop = prop
	if prop is RigidBody3D and "freeze" in prop:
		_prop_frozen = bool(prop.get("freeze"))
		prop.set("freeze", true)
	_pulse(0.04, 0.30)
	return true


func release_prop(velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	if not is_instance_valid(_prop):
		_prop = null
		return {"released": false, "velocity": Vector3.ZERO}
	var launch: Vector3 = safe_vector(velocity)
	var body: Node3D = _prop
	if body is RigidBody3D:
		if "freeze" in body:
			body.set("freeze", _prop_frozen)
		if "linear_velocity" in body:
			body.set("linear_velocity", launch)
	_prop = null
	_prop_frozen = false
	released.emit("prop", launch)
	return {"released": true, "velocity": launch, "node": body}


func reset() -> void:
	if is_instance_valid(_prop):
		release_prop(Vector3.ZERO)
	_grabbed = false
	_zone = ""
	_grip = 0.0
	_pose = Transform3D.IDENTITY
	_velocity = Vector3.ZERO


func _pulse(duration: float, amplitude: float) -> void:
	haptic.emit(_hand, duration, amplitude)
