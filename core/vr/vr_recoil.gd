class_name VrRecoil
extends RefCounted

const DbScript = preload("res://core/game/weapon_db.gd")

const DEFAULT_WEAPON: String = "pistol"
const MAX_HAPTIC_EVENTS: int = 6
const MAX_SUBSTEP: float = 1.0 / 60.0
const MAX_STEP_TIME: float = 0.25
const BURST_GAP: float = 0.16
const RELEASE_RECOVERY_BOOST: float = 1.8
const KICK_VELOCITY_SCALE: float = 6.0

const PROFILES: Dictionary = {
	"pistol": {
		"energy": 0.060, "climb": 0.025, "lateral": 0.28, "recovery": 7.0,
		"cap": 0.10, "two_hand_reduction": 0.25, "stiffness": 130.0, "damping": 16.0,
		"pulses": 1, "pulse_amp": 0.50, "pulse_duration": 0.050,
	},
	"submachine_gun": {
		"energy": 0.035, "climb": 0.019, "lateral": 0.38, "recovery": 10.0,
		"cap": 0.09, "two_hand_reduction": 0.35, "stiffness": 150.0, "damping": 19.0,
		"pulses": 3, "pulse_amp": 0.22, "pulse_duration": 0.018,
	},
	"assault_rifle": {
		"energy": 0.050, "climb": 0.030, "lateral": 0.46, "recovery": 6.0,
		"cap": 0.16, "two_hand_reduction": 0.65, "stiffness": 120.0, "damping": 15.0,
		"pulses": 2, "pulse_amp": 0.48, "pulse_duration": 0.035,
	},
	"shotgun": {
		"energy": 0.090, "climb": 0.050, "lateral": 0.80, "recovery": 4.0,
		"cap": 0.22, "two_hand_reduction": 0.50, "stiffness": 110.0, "damping": 13.0,
		"pulses": 1, "pulse_amp": 1.00, "pulse_duration": 0.035,
	},
	"sniper_rifle": {
		"energy": 0.120, "climb": 0.060, "lateral": 0.60, "recovery": 3.0,
		"cap": 0.25, "two_hand_reduction": 0.75, "stiffness": 100.0, "damping": 12.0,
		"pulses": 1, "pulse_amp": 0.90, "pulse_duration": 0.110,
	},
	"bat": {
		"energy": 0.050, "climb": 0.015, "lateral": 0.20, "recovery": 8.0,
		"cap": 0.08, "two_hand_reduction": 0.10, "stiffness": 140.0, "damping": 17.0,
		"pulses": 1, "pulse_amp": 0.30, "pulse_duration": 0.070,
	},
}

var primary_hand: String = "right"
var secondary_hand: String = "left"

var _seed_value: int = 20261120
var _rng_state: int = 0
var _weapon_id: String = DEFAULT_WEAPON
var _profile: Dictionary = PROFILES[DEFAULT_WEAPON]
var _kick: Vector3 = Vector3.ZERO
var _kick_velocity: Vector3 = Vector3.ZERO
var _pitch: float = 0.0
var _yaw: float = 0.0
var _since_shot: float = 10.0
var _burst_released: bool = true
var _two_handed: bool = false
var _haptic_slots: Array = []
var _haptic_out: Array = []


func _init() -> void:
	set_seed(20261120)
	for i in MAX_HAPTIC_EVENTS:
		var event: Dictionary = {"amplitude": 0.0, "duration": 0.0, "hand": primary_hand}
		_haptic_slots.append(event)
		_haptic_out.append(event)
	_haptic_out.clear()


func set_seed(value: int) -> void:
	_seed_value = value
	_rng_state = absi(value) & 0x7FFFFFFF
	if _rng_state == 0:
		_rng_state = 0x45D9F3B


func get_seed() -> int:
	return _seed_value


func set_weapon(weapon_id: String) -> void:
	var id := weapon_id if PROFILES.has(weapon_id) else DEFAULT_WEAPON
	_weapon_id = id
	_profile = PROFILES[id] as Dictionary


func current_weapon() -> String:
	return _weapon_id


func reset() -> void:
	set_seed(_seed_value)
	_kick = Vector3.ZERO
	_kick_velocity = Vector3.ZERO
	_pitch = 0.0
	_yaw = 0.0
	_since_shot = 10.0
	_burst_released = true
	_two_handed = false
	_haptic_out.clear()


func on_fired(weapon_id: String, two_handed: bool = false) -> Dictionary:
	set_weapon(weapon_id)
	_two_handed = two_handed
	var def: Dictionary = DbScript.get_def(_weapon_id)
	var damage: float = maxf(float(def.get("damage", 20.0)), 1.0)
	var pellets: float = maxf(float(def.get("pellets", 1)), 1.0)
	var caliber: float = clampf(damage * pellets / 48.0, 0.25, 2.5)
	var reduction: float = clampf(float(_profile.get("two_hand_reduction", 0.25)), 0.0, 0.95)
	var factor: float = 1.0 - reduction if two_handed else 1.0
	var energy: float = float(_profile.get("energy", 0.06)) * caliber * factor
	var climb_step: float = float(_profile.get("climb", 1.0)) * (0.55 + 0.45 * caliber) * factor
	var lateral_step: float = float(_profile.get("lateral", 0.25)) * factor
	var cap: float = float(_profile.get("cap", 0.10))
	if two_handed:
		cap *= 1.0 - reduction * 0.6
	var lateral_sign: float = _next_random() * 2.0 - 1.0
	_pitch = clampf(_pitch + climb_step, 0.0, cap)
	_yaw = clampf(_yaw + lateral_step * lateral_sign, -cap, cap)
	_kick_velocity.z += energy * KICK_VELOCITY_SCALE
	_kick_velocity.x += energy * KICK_VELOCITY_SCALE * lateral_sign * 0.25
	_since_shot = 0.0
	_burst_released = false
	_emit_haptics(caliber, factor, energy)
	return {
		"weapon_id": _weapon_id,
		"two_handed": two_handed,
		"energy": energy,
		"caliber": caliber,
		"impulse": Vector3(0.0, 0.0, energy),
		"climb": climb_step,
		"lateral": lateral_step * lateral_sign,
		"amplitude": _haptic_amplitude(caliber, factor),
	}


func end_burst() -> void:
	_burst_released = true


func step(delta: float) -> void:
	var total: float = clampf(delta, 0.0, MAX_STEP_TIME)
	if total <= 0.0:
		return
	_since_shot += total
	var ticks: int = int(ceil(total / MAX_SUBSTEP))
	ticks = clampi(ticks, 1, 16)
	var dt: float = total / float(ticks)
	var stiffness: float = float(_profile.get("stiffness", 120.0))
	var damping: float = float(_profile.get("damping", 14.0))
	for i in ticks:
		var accel: Vector3 = -stiffness * _kick - damping * _kick_velocity
		_kick_velocity += accel * dt
		_kick += _kick_velocity * dt
	if _kick.length_squared() < 0.0000000001 and _kick_velocity.length_squared() < 0.0000000001:
		_kick = Vector3.ZERO
		_kick_velocity = Vector3.ZERO
	var recovery: float = float(_profile.get("recovery", 6.0))
	if _two_handed:
		recovery *= 1.0 + float(_profile.get("two_hand_reduction", 0.25)) * 1.5
	if _burst_released or _since_shot >= BURST_GAP:
		recovery *= RELEASE_RECOVERY_BOOST
	var decay: float = exp(-recovery * total)
	_pitch *= decay
	_yaw *= decay
	if absf(_pitch) < 0.000001:
		_pitch = 0.0
	if absf(_yaw) < 0.000001:
		_yaw = 0.0


func aim_direction(base_direction: Vector3) -> Vector3:
	var direction: Vector3 = base_direction
	if direction.length_squared() <= 0.00000001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	if absf(_pitch) <= 0.0000001 and absf(_yaw) <= 0.0000001:
		return direction
	var right: Vector3 = direction.cross(Vector3.UP)
	if right.length_squared() <= 0.00000001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	direction = direction.rotated(right, _pitch)
	direction = direction.rotated(Vector3.UP, _yaw)
	return direction.normalized()


func weapon_offset() -> Transform3D:
	var basis: Basis = Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)
	return Transform3D(basis, _kick)


func haptic_events() -> Array:
	return _haptic_out


func kick() -> Vector3:
	return _kick


func pitch() -> float:
	return _pitch


func yaw() -> float:
	return _yaw


func is_two_handed() -> bool:
	return _two_handed


func _next_random() -> float:
	_rng_state = (1103515245 * _rng_state + 12345) & 0x7FFFFFFF
	return float(_rng_state) / 2147483647.0


func _haptic_amplitude(caliber: float, factor: float) -> float:
	return clampf(float(_profile.get("pulse_amp", 0.5)) * (0.7 + 0.3 * caliber) * factor, 0.05, 1.0)


func _emit_haptics(caliber: float, factor: float, energy: float) -> void:
	var pulses: int = clampi(int(_profile.get("pulses", 1)), 1, MAX_HAPTIC_EVENTS - 1)
	var amplitude: float = _haptic_amplitude(caliber, factor)
	var duration: float = float(_profile.get("pulse_duration", 0.05)) * clampf(1.25 - 0.15 * caliber, 0.7, 1.3)
	duration = clampf(duration, 0.01, 0.2) * (0.9 + 0.1 * clampf(energy / 0.12, 0.0, 2.0))
	var count: int = 0
	for i in pulses:
		var event: Dictionary = _haptic_slots[count]
		event["amplitude"] = clampf(amplitude * (1.0 - 0.12 * float(i)), 0.05, 1.0)
		event["duration"] = duration
		event["hand"] = primary_hand
		count += 1
	if _two_handed:
		var secondary_event: Dictionary = _haptic_slots[count]
		secondary_event["amplitude"] = clampf(amplitude * 0.35, 0.05, 1.0)
		secondary_event["duration"] = duration * 1.25
		secondary_event["hand"] = secondary_hand
		count += 1
	_haptic_out.resize(count)
	for i in count:
		_haptic_out[i] = _haptic_slots[i]
