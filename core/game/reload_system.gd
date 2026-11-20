class_name ReloadSystem
extends RefCounted

# Recarga manual por fases compartida por gestos VR y toques Android.
# Envuelve VrReloadGestures (maquina de fases) y sincroniza WeaponSystem.

signal phase_changed(weapon_id: String, phase: String)
signal finished(weapon_id: String)
signal cancelled(weapon_id: String, reason: String)
signal sound_requested(weapon_id: String, sound: String)
signal haptic(hand: String, duration: float, amplitude: float)
signal magazine_dropped(rounds: int, position: Vector3)

const GesturesScript = preload("res://core/vr/vr_reload_gestures.gd")
const DbScript = preload("res://core/game/weapon_db.gd")
const SFX_BANK_PATH := "res://core/game/sfx_bank.gd"
const LOCK_REASON := "recarga manual"
const MAX_DROPPED := 8

var weapon_system: Node = null
var machine = null
var weapon_id: String = ""
var hand: String = "right":
	set(value):
		hand = value
		if machine != null:
			machine.hand = value
var audio_host: Node3D = null
var audio_position: Vector3 = Vector3.ZERO
var active: bool = false
var dropped_magazines: Array = []


func _init(system: Node = null) -> void:
	weapon_system = system
	machine = GesturesScript.new()
	machine.phase_changed.connect(_on_phase)
	machine.haptic.connect(func(h: String, d: float, a: float) -> void: haptic.emit(h, d, a))


func begin(id: String, shells: int = -1) -> bool:
	if active or weapon_system == null or not weapon_system.has_method("set_manual_lock"):
		return false
	var def: Dictionary = DbScript.get_def(id)
	if def.is_empty() or not bool(def.get("uses_ammo", true)):
		return false
	var cap: int = maxi(int(def.get("mag", 0)), 1)
	var total: int = int(weapon_system.call("ammo", id))
	var stock: int = int(weapon_system.call("reserve", id))
	var kind: String = GesturesScript.kind_of(id, def.get("tags", []))
	var in_mag: int = total if kind == "shotgun" else maxi(total - 1, 0)
	var full: int = cap if kind == "shotgun" else cap + 1
	if stock <= 0 or total >= full:
		return false
	var count: int = shells if shells > 0 else clampi(cap - in_mag, 1, cap)
	machine.hand = hand
	weapon_id = id
	active = true
	weapon_system.call("clear_cycle", id)
	machine.begin(id, cap, stock, in_mag, count)
	machine.chambered = total > 0
	weapon_system.call("set_manual_lock", id, LOCK_REASON)
	_sync()
	return true


func phase() -> String:
	return machine.phase() if active else ""


func can_fire() -> bool:
	return machine.can_fire()


func is_complete() -> bool:
	return machine.is_complete()


func events() -> Array:
	return machine.events()


func haptic_events() -> Array:
	return machine.haptic_events()


func eject_magazine(position: Vector3 = Vector3.ZERO) -> Dictionary:
	var result: Dictionary = machine.eject_magazine(position)
	if bool(result.get("ejected", false)):
		dropped_magazines.append({"rounds": int(result["rounds"]), "position": position})
		if dropped_magazines.size() > MAX_DROPPED:
			dropped_magazines.pop_front()
		magazine_dropped.emit(int(result["rounds"]), position)
	return _after(result)


func pickup_dropped() -> bool:
	var ok: bool = bool(machine.pickup_magazine())
	if ok:
		dropped_magazines.pop_back()
		_notify()
	return ok


func insert_magazine(pose: Transform3D = Transform3D.IDENTITY, well: Transform3D = Transform3D.IDENTITY, position_tolerance: float = 0.05, angle_tolerance_deg: float = 20.0) -> bool:
	return _after(machine.insert_magazine(pose, well, position_tolerance, angle_tolerance_deg))


func rack_slide(pull: float, released: bool) -> bool:
	return _after(machine.rack_slide(pull, released))


func load_shell() -> bool:
	return _after(machine.load_shell())


func pump_action(travel: float, casing_position: Vector3 = Vector3.ZERO) -> bool:
	var rounds: int = machine.magazine_rounds
	var stock: int = machine.reserve
	var was_pump: bool = machine.phase() == "pump"
	var ok: bool = bool(machine.pump_action(travel, casing_position))
	if ok and was_pump:
		# el bombeo mete un cartucho del tubo en la recamara, no toca la reserva
		machine.reserve = stock
		machine.magazine_rounds = rounds
		if rounds > 0:
			machine.magazine_rounds = rounds - 1
			machine.chambered = true
	return _after(ok)


func open_bolt() -> bool:
	return _after(machine.open_bolt())


func load_round() -> bool:
	return _after(machine.load_round())


func close_bolt() -> bool:
	return _after(machine.close_bolt())


# Ejecuta la accion de la fase actual con gestos ideales (toques de Android).
func perform_current(drop_position: Vector3 = Vector3.ZERO) -> bool:
	match phase():
		"eject":
			return bool(eject_magazine(drop_position).get("ejected", false))
		"insert":
			return insert_magazine()
		"chamber":
			return rack_slide(0.12, true)
		"load_shell":
			return load_shell()
		"pump":
			return pump_action(-0.1) == false and pump_action(0.1)
		"open_bolt":
			return open_bolt()
		"load_round":
			return load_round()
		"close_bolt":
			return close_bolt()
	return false


func fire() -> bool:
	var ok: bool = bool(machine.fire())
	if ok:
		# shortcut: ciclo automatico tras disparar (sin bombeo/cerrojo manual entre tiros)
		if machine.magazine_rounds > 0:
			machine.magazine_rounds -= 1
			machine.chambered = true
		_sync()
	return ok


func tick(delta: float) -> bool:
	if not active:
		return false
	var timed_out: bool = bool(machine.safety_tick(delta))
	if timed_out:
		_close("safety_timeout")
	return timed_out


func cancel(reason: String = "cambio_de_arma") -> void:
	if not active:
		return
	if machine._held_magazine > 0:
		machine.reserve += machine._held_magazine
		machine._held_magazine = -1
	if machine.is_complete():
		_close(reason, false)
		return
	machine.cancel(reason)
	dropped_magazines.clear()
	_close(reason)


func _after(result):
	var ok: bool = bool(result.get("ejected", false)) if result is Dictionary else bool(result)
	if ok:
		_sync()
	for event in machine.events():
		var sound: String = str(event.get("sound", ""))
		if not sound.is_empty():
			sound_requested.emit(weapon_id, sound)
	_notify()
	return result


func _notify() -> void:
	if active and machine.is_complete():
		_close("", false)
		finished.emit(weapon_id)


func _close(reason: String, emit_cancel: bool = true) -> void:
	active = false
	_sync()
	if weapon_system != null:
		weapon_system.call("set_manual_lock", weapon_id, "")
	if emit_cancel:
		cancelled.emit(weapon_id, reason)


func _sync() -> void:
	if weapon_system == null or weapon_id.is_empty():
		return
	var loaded: int = machine.magazine_rounds + (1 if machine.chambered else 0)
	weapon_system.call("set_loaded_raw", weapon_id, loaded, machine.reserve)


func _on_phase(phase_name: String) -> void:
	phase_changed.emit(weapon_id, phase_name)
	var bank = load(SFX_BANK_PATH) if ResourceLoader.exists(SFX_BANK_PATH) else null
	if bank != null and audio_host != null and is_instance_valid(audio_host) and audio_host.is_inside_tree() and bank.has_method("play_synth"):
		bank.call("play_synth", audio_host, "reload", weapon_id, audio_position, "sfx")
