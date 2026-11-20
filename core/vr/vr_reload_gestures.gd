class_name VrReloadGestures
extends RefCounted

signal phase_changed(phase: String)
signal haptic(hand: String, duration: float, amplitude: float)
signal cancelled(reason: String)

const MAX_RELOAD_TIME: float = 12.0
const MAGAZINE_PULL: float = 0.04
const PUMP_TRAVEL: float = 0.03
const DEFAULT_POSITION_TOLERANCE: float = 0.05
const DEFAULT_ANGLE_TOLERANCE_DEG: float = 20.0

var weapon_id: String = ""
var hand: String = "right"
var capacity: int = 8
var magazine_rounds: int = 0
var reserve: int = 0
var chambered: bool = false
var jammed: bool = false

var _queue: Array = []
var _index: int = 0
var _dropped: Dictionary = {}
var _held_magazine: int = -1
var _loaded_round: bool = false
var _slide_pull: float = 0.0
var _pump_forward: bool = false
var _elapsed: float = 0.0
var _events: Array = []
var _haptics: Array = []


func _init() -> void:
	reset()


static func kind_of(weapon_id: String, tags: Array = []) -> String:
	if weapon_id == "shotgun" or tags.has("shotgun"):
		return "shotgun"
	if weapon_id == "sniper_rifle" or tags.has("sniper"):
		return "bolt"
	return "magazine"


static func phase_queue(weapon_id: String, shells: int = 2, tags: Array = []) -> Array:
	var kind := kind_of(weapon_id, tags)
	if kind == "shotgun":
		var queue: Array = []
		for i in maxi(shells, 1):
			queue.append("load_shell")
		queue.append("pump")
		queue.append("ready")
		return queue
	if kind == "bolt":
		return ["open_bolt", "load_round", "close_bolt", "ready"]
	return ["eject", "insert", "chamber", "ready"]


func begin(id: String, cap: int, reserve_rounds: int, loaded_rounds: int = -1, shells: int = 2) -> void:
	weapon_id = id
	capacity = maxi(cap, 0)
	reserve = maxi(reserve_rounds, 0)
	var initial: int = capacity if loaded_rounds < 0 else clampi(loaded_rounds, 0, capacity)
	magazine_rounds = initial
	chambered = initial > 0 or reserve > 0
	jammed = false
	_queue = phase_queue(id, shells)
	_index = 0
	_dropped.clear()
	_held_magazine = -1
	_loaded_round = false
	_slide_pull = 0.0
	_pump_forward = false
	_elapsed = 0.0
	_events.clear()
	_haptics.clear()
	phase_changed.emit(phase())


func reset() -> void:
	begin(weapon_id, capacity, reserve, -1, 2)


func phase() -> String:
	if _queue.is_empty():
		return "ready"
	return str(_queue[clampi(_index, 0, _queue.size() - 1)])


func set_ready() -> void:
	_queue = ["ready"]
	_index = 0
	phase_changed.emit("ready")


func is_complete() -> bool:
	return phase() == "ready"


func is_magazine_weapon() -> bool:
	return kind_of(weapon_id) == "magazine"


func is_shotgun() -> bool:
	return kind_of(weapon_id) == "shotgun"


func is_bolt_weapon() -> bool:
	return kind_of(weapon_id) == "bolt"


func can_fire() -> bool:
	return is_complete() and chambered and not jammed


func advance(action: String) -> bool:
	if action != phase() or is_complete():
		return false
	_index = mini(_index + 1, maxi(_queue.size() - 1, 0))
	_events.append({"type": "phase", "phase": action, "weapon_id": weapon_id})
	_pulse(0.04, 0.42)
	phase_changed.emit(phase())
	return true


func eject_magazine(drop_position: Vector3 = Vector3.ZERO) -> Dictionary:
	if phase() != "eject":
		return {"ejected": false, "reason": "fase_incorrecta"}
	var rounds: int = magazine_rounds
	magazine_rounds = 0
	_dropped = {"rounds": rounds, "position": drop_position}
	_events.append({
		"type": "magazine_dropped", "rounds": rounds, "position": drop_position,
		"sound": "magazine_drop", "physical": true,
	})
	_slide_pull = 0.0
	advance("eject")
	return {"ejected": true, "rounds": rounds, "position": drop_position}


func dropped_magazine() -> Dictionary:
	return _dropped.duplicate(true)


func pickup_magazine() -> bool:
	if not _dropped.has("rounds"):
		return false
	_held_magazine = maxi(int(_dropped["rounds"]), 0)
	_dropped.clear()
	_events.append({"type": "magazine_picked", "rounds": _held_magazine, "sound": "magazine_pickup"})
	_pulse(0.035, 0.30)
	return true


static func aligned(pose: Transform3D, well_pose: Transform3D, position_tolerance: float, angle_tolerance_deg: float) -> bool:
	var distance: float = pose.origin.distance_to(well_pose.origin)
	var forward: Vector3 = -pose.basis.z
	var well_forward: Vector3 = -well_pose.basis.z
	if forward.length_squared() <= 0.000001 or well_forward.length_squared() <= 0.000001:
		return false
	var angle_deg: float = rad_to_deg(forward.angle_to(well_forward.normalized()))
	return distance <= maxf(position_tolerance, 0.001) and angle_deg <= maxf(angle_tolerance_deg, 0.0)


func insert_magazine(
	pose: Transform3D, well_pose: Transform3D,
	position_tolerance: float = DEFAULT_POSITION_TOLERANCE,
	angle_tolerance_deg: float = DEFAULT_ANGLE_TOLERANCE_DEG
) -> bool:
	if phase() != "insert":
		return false
	if jammed:
		_events.append({"type": "jam", "sound": "magazine_jam"})
		return false
	if not aligned(pose, well_pose, position_tolerance, angle_tolerance_deg):
		_events.append({"type": "magazine_misaligned", "sound": "magazine_error"})
		return false
	var from_reserve: bool = _held_magazine <= 0
	var rounds: int = _held_magazine
	if from_reserve:
		rounds = mini(capacity, reserve)
		reserve = maxi(reserve - rounds, 0)
	magazine_rounds = clampi(rounds, 0, capacity)
	_held_magazine = -1
	_dropped.clear()
	_events.append({"type": "magazine_inserted", "rounds": magazine_rounds, "sound": "magazine_click"})
	_pulse(0.03, 0.55)
	advance("insert")
	return true


func rack_slide(pull: float, released: bool) -> bool:
	if phase() != "chamber" and phase() != "ready":
		return false
	_slide_pull = maxf(_slide_pull, clampf(pull, 0.0, 0.30))
	if not released or _slide_pull < MAGAZINE_PULL:
		return false
	_slide_pull = 0.0
	if chambered:
		_events.append({"type": "casing_ejected", "sound": "casing", "physical": true})
	var fed: bool = false
	if magazine_rounds > 0:
		magazine_rounds -= 1
		fed = true
	elif reserve > 0:
		reserve -= 1
		fed = true
	chambered = fed
	_events.append({"type": "slide_racked", "chambered": chambered, "sound": "slide_rack"})
	_pulse(0.05, 0.48)
	if phase() == "chamber":
		advance("chamber")
	return true


func load_shell() -> bool:
	if phase() != "load_shell":
		return false
	if reserve <= 0 or magazine_rounds >= capacity:
		return false
	reserve -= 1
	magazine_rounds += 1
	_events.append({"type": "shell_loaded", "rounds": magazine_rounds, "sound": "round_insert"})
	_pulse(0.035, 0.36)
	advance("load_shell")
	return true


func pump_action(travel: float, casing_position: Vector3 = Vector3.ZERO) -> bool:
	if phase() != "pump" and phase() != "ready":
		return false
	var amount: float = clampf(travel, -0.30, 0.30)
	if amount <= -PUMP_TRAVEL:
		_pump_forward = true
		return false
	if not _pump_forward or amount < PUMP_TRAVEL:
		return false
	_pump_forward = false
	_events.append({
		"type": "shell_ejected", "position": casing_position,
		"sound": "shell_drop", "physical": true,
	})
	if reserve > 0 and magazine_rounds < capacity:
		reserve -= 1
		magazine_rounds += 1
	_pulse(0.06, 0.62)
	if phase() == "pump":
		advance("pump")
	return true


func open_bolt() -> bool:
	if phase() != "open_bolt":
		return false
	if chambered:
		_events.append({"type": "casing_ejected", "sound": "casing", "physical": true})
	chambered = false
	_events.append({"type": "bolt_opened", "sound": "bolt_open"})
	_pulse(0.04, 0.40)
	advance("open_bolt")
	return true


func load_round() -> bool:
	if phase() != "load_round":
		return false
	var from_magazine: bool = magazine_rounds > 0
	if not from_magazine and reserve <= 0:
		return false
	if from_magazine:
		magazine_rounds -= 1
	else:
		reserve -= 1
	_loaded_round = true
	_events.append({"type": "round_loaded", "sound": "round_insert"})
	_pulse(0.035, 0.36)
	advance("load_round")
	return true


func close_bolt() -> bool:
	if phase() != "close_bolt":
		return false
	chambered = _loaded_round
	_loaded_round = false
	_events.append({"type": "bolt_closed", "sound": "bolt_close"})
	_pulse(0.04, 0.52)
	advance("close_bolt")
	return true


func clear_jam() -> bool:
	if not jammed:
		return false
	jammed = false
	_slide_pull = 0.0
	_pump_forward = false
	_events.append({"type": "jam_cleared", "sound": "slide_rack"})
	_pulse(0.05, 0.55)
	return true


func fire() -> bool:
	if not can_fire():
		return false
	chambered = false
	_events.append({"type": "fired", "weapon_id": weapon_id})
	return true


func cancel(reason: String = "manual") -> void:
	var rounds: int = magazine_rounds
	if _dropped.has("rounds"):
		rounds = maxi(int(_dropped["rounds"]), 0)
	if phase() == "chamber" and not chambered and (rounds > 0 or reserve > 0):
		if rounds > 0:
			rounds -= 1
		else:
			reserve = maxi(reserve - 1, 0)
		chambered = true
	if phase() == "load_round" and _loaded_round and not chambered:
		chambered = true
		_loaded_round = false
	magazine_rounds = clampi(rounds, 0, capacity)
	_queue = ["ready"]
	_index = 0
	_dropped.clear()
	_held_magazine = -1
	_slide_pull = 0.0
	_pump_forward = false
	_elapsed = 0.0
	_events.append({"type": "cancel", "reason": reason, "sound": "holster_clip"})
	cancelled.emit(reason)
	phase_changed.emit("ready")


func safety_tick(delta: float) -> bool:
	if is_complete():
		return false
	_elapsed += clampf(delta, 0.0, MAX_RELOAD_TIME)
	if _elapsed >= MAX_RELOAD_TIME:
		cancel("safety_timeout")
		return true
	return false


func events() -> Array:
	var result: Array = _events.duplicate(true)
	_events.clear()
	return result


func haptic_events() -> Array:
	return _haptics.duplicate(true)


func _pulse(duration: float, amplitude: float) -> void:
	var event: Dictionary = {"hand": hand, "duration": duration, "amplitude": amplitude}
	_haptics.append(event)
	haptic.emit(hand, duration, amplitude)
