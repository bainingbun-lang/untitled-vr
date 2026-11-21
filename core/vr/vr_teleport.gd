class_name VrTeleportModule
extends RefCounted

signal teleport_valid(target: Vector3, normal: Vector3, arc: Array)
signal teleport_invalid()

const DEFAULT_GRAVITY: float = 9.8
const DEFAULT_ARC_HEIGHT: float = 1.5
const DEFAULT_MAX_DISTANCE: float = 5.0
const DEFAULT_ARC_SEGMENTS: int = 20
const MIN_VALID_DISTANCE: float = 0.3

static func compute_arc(
	origin: Vector3, direction: Vector3, velocity: float,
	gravity: float = DEFAULT_GRAVITY, segments: int = DEFAULT_ARC_SEGMENTS,
	arc_height: float = DEFAULT_ARC_HEIGHT
) -> Array:
	var points: Array = []
	if direction.length_squared() <= 0.000001:
		direction = Vector3.FORWARD
	var dir: Vector3 = direction.normalized()
	var flat: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() <= 0.000001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	var climb: float = dir.y
	if climb <= 0.0:
		climb = 0.5
	var horizontal_speed: float = velocity * sqrt(maxf(1.0 - climb * climb, 0.0))
	var vertical_speed: float = velocity * climb
	if horizontal_speed <= 0.0001:
		horizontal_speed = 0.1
	var flight_time: float = 2.0 * vertical_speed / gravity if vertical_speed > 0.0 else 0.0
	if flight_time <= 0.0:
		var reach: float = max_distance(velocity, gravity, arc_height)
		flight_time = reach / horizontal_speed if horizontal_speed > 0.0 else 0.0
	flight_time = flight_time * 1.25
	var dt: float = flight_time / maxf(segments, 1)
	for i in segments + 1:
		var t: float = float(i) * dt
		var x: float = flat.x * horizontal_speed * t
		var z: float = flat.z * horizontal_speed * t
		var y: float = vertical_speed * t - 0.5 * gravity * t * t
		points.push_back(origin + Vector3(x, y, z))
	return points


static func max_distance(velocity: float, gravity: float, arc_height: float) -> float:
	if velocity <= 0.0 or gravity <= 0.0:
		return 0.0
	var time_to_peak: float = sqrt(2.0 * arc_height / gravity)
	var peak_velocity_y: float = gravity * time_to_peak
	var total_time: float = 2.0 * time_to_peak
	var horizontal: float = sqrt(maxf(velocity * velocity - peak_velocity_y * peak_velocity_y, 0.0))
	return horizontal * total_time


static func is_walkable_normal(normal: Vector3, min_y: float = 0.7) -> bool:
	return normal.y >= min_y - 0.0001


static func parabolic_point(origin: Vector3, direction: Vector3, velocity: float, gravity: float, t: float) -> Vector3:
	var dir: Vector3 = direction.normalized() if direction.length_squared() > 0.000001 else Vector3.FORWARD
	var flat: Vector3 = Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length_squared() > 0.000001 else Vector3.FORWARD
	var climb: float = dir.y
	var horizontal_speed: float = velocity * sqrt(maxf(1.0 - climb * climb, 0.0))
	var vertical_speed: float = velocity * climb
	var x: float = flat.x * horizontal_speed * t
	var z: float = flat.z * horizontal_speed * t
	var y: float = vertical_speed * t - 0.5 * gravity * t * t
	return origin + Vector3(x, y, z)
