class_name VrWeaponHand
extends Node3D

signal weapon_taken(weapon_id: String, hand: String)
signal weapon_stowed(weapon_id: String, hand: String)
signal fired(result: Dictionary)
signal reloaded(weapon_id: String)
signal two_hand_entered(weapon_id: String)
signal two_hand_exited(weapon_id: String)
signal haptic(hand: String, duration: float, frequency: float, amplitude: float)

const DbScript = preload("res://core/game/weapon_db.gd")
const ViewmodelScript = preload("res://core/game/weapon_viewmodel.gd")
const MuzzleFxScript = preload("res://core/game/muzzle_fx.gd")
const SfxBankScript = preload("res://core/game/sfx_bank.gd")
const GrabScript = preload("res://core/vr/vr_grab.gd")
const HandPoseScript = preload("res://core/vr/vr_hand_pose.gd")
const HolsterScript = preload("res://core/vr/vr_holsters.gd")
const ReloadScript = preload("res://core/vr/vr_reload_gestures.gd")
const ReloadSystemScript = preload("res://core/game/reload_system.gd")
const RecoilScript = preload("res://core/vr/vr_recoil.gd")

const HANDGUARD_RADIUS: float = 0.12
const HANDGUARD_OFFSETS: Dictionary = {
	"pistol": 0.08,
	"submachine_gun": 0.16,
	"assault_rifle": 0.24,
	"shotgun": 0.20,
	"sniper_rifle": 0.32,
	"bat": 0.18,
}
const RECOIL_REDUCTIONS: Dictionary = {
	"pistol": 0.25,
	"submachine_gun": 0.35,
	"assault_rifle": 0.65,
	"shotgun": 0.50,
	"sniper_rifle": 0.75,
	"bat": 0.10,
}

@export var hand: String = "right"
@export var muzzle_offset: Vector3 = Vector3(0.0, -0.04, -0.18)
@export var grip_offset: Vector3 = Vector3.ZERO
@export var max_aim_turn_degrees: float = 18.0
@export var aim_smoothing: float = 0.35
@export var base_recoil: float = 0.06
@export var base_shake: float = 0.004
@export var auto_process: bool = true
@export var use_physical_grab: bool = false
@export var fx_via_viewmodel: bool = true
@export var manual_gesture_reload: bool = false

var grab_system = null
var holsters = null
var reload_gestures = null
var reload_system = null
var recoil = RecoilScript.new()
var shot_trace: Array = []
var _rl_armed: bool = false
var _rl_prev_grip: bool = false
var _rl_ref: float = 0.0
var _rl_back: bool = false
var manual_reload_active: bool = false

var bag = null
var weapon_system: Node = null
var input_provider = null
var weapon_id: String = ""
var handguard_offsets: Dictionary = {}
var recoil_overrides: Dictionary = {}
var exclude: Array = []

var holder: Node3D = null
var viewmodel = null
var last_haptic: Dictionary = {}
var last_shot: Dictionary = {}

static var _last_fx_frame: int = -1

var _aim_dir: Vector3 = Vector3.FORWARD
var _two_hand: bool = false
var _was_grip: bool = false
var _was_trigger: bool = false
var _recoil: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	if use_physical_grab:
		configure_handling()
	if not weapon_id.is_empty():
		_build_visual(weapon_id)


func _process(delta: float) -> void:
	if auto_process:
		step(delta)


func reset_buttons() -> void:
	_was_grip = false
	_was_trigger = false


func other_hand() -> String:
	return "left" if hand == "right" else "right"


func is_two_hand_aiming() -> bool:
	return _two_hand


func aim_dir() -> Vector3:
	return _aim_dir.normalized()


func current_recoil() -> float:
	return effective_recoil(weapon_id, _two_hand, base_recoil, recoil_overrides)


func current_shake() -> float:
	return shake_amplitude(weapon_id, _two_hand, base_shake, recoil_overrides)


func bind_weapon_system(node: Node) -> void:
	weapon_system = node
	if node != null and node.has_signal("impact") and not node.is_connected("impact", Callable(self, "on_impact")):
		node.connect("impact", Callable(self, "on_impact"))
	if node != null and node.has_signal("cycled") and not node.is_connected("cycled", Callable(self, "_on_cycled")):
		node.connect("cycled", Callable(self, "_on_cycled"))


func configure_handling(head_pose: Transform3D = Transform3D.IDENTITY) -> void:
	if grab_system == null:
		grab_system = GrabScript.new()
		grab_system.set_hand(hand)
	if holsters == null:
		holsters = HolsterScript.new()
	holsters.set_head_pose(head_pose)


func hand_pose_values(grip_value: float = 1.0, trigger_value: float = 0.0, zone: String = "grip") -> Dictionary:
	return HandPoseScript.pose(grip_value, trigger_value, zone, hand)


func grab_weapon_from_pose(weapon_pose: Transform3D, grip_value: float = 1.0, zone: String = "") -> bool:
	if grab_system == null:
		configure_handling()
	if weapon_id.is_empty():
		return false
	return grab_system.grab(_pose(hand), weapon_pose, weapon_id, grip_value, zone)


func grab_world_prop(prop: Node3D, radius: float = GrabScript.GRAB_RADIUS) -> bool:
	if grab_system == null:
		configure_handling()
	return grab_system.grab_prop(prop, _pose(hand), radius)


func throw_world_prop(velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	if grab_system == null:
		return {"released": false, "velocity": Vector3.ZERO}
	return grab_system.release_prop(velocity)


func release_weapon(velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	if grab_system == null or not grab_system.is_grabbing():
		return {"mode": "", "velocity": Vector3.ZERO}
	var mode := "fall"
	if holsters != null:
		var nearest: Dictionary = holsters.nearest_slot(_pose(hand))
		if bool(nearest["ok"]):
			mode = "holster"
	return grab_system.release(mode, velocity)


func begin_manual_reload(capacity: int, reserve: int, loaded: int = -1, shells: int = 2) -> bool:
	if weapon_id.is_empty():
		return false
	manual_reload_active = true
	reload_gestures = ReloadScript.new()
	reload_gestures.hand = hand
	reload_gestures.begin(weapon_id, capacity, reserve, loaded, shells)
	return true


func bind_reload_system(system) -> void:
	reload_system = system
	system.hand = hand
	reload_gestures = system
	manual_reload_active = true
	if not system.haptic.is_connected(_on_reload_haptic):
		system.haptic.connect(_on_reload_haptic)


func _on_cycled(id: String) -> void:
	if id == weapon_id:
		pulse(other_hand(), 0.06, 0.6, 0.6)


func _ensure_reload_system() -> bool:
	if reload_system != null:
		return true
	if weapon_system == null or not weapon_system.has_method("set_manual_lock"):
		return false
	var system = ReloadSystemScript.new(weapon_system)
	system.hand = hand
	system.haptic.connect(_on_reload_haptic)
	system.finished.connect(func(_id: String) -> void:
		manual_reload_active = false
		reloaded.emit(weapon_id))
	system.cancelled.connect(func(_id: String, _why: String) -> void: manual_reload_active = false)
	system.magazine_dropped.connect(_on_magazine_dropped)
	reload_system = system
	reload_gestures = system
	return true


func _on_magazine_dropped(_rounds: int, position: Vector3) -> void:
	if is_inside_tree() and get_parent() != null:
		MuzzleFxScript.drop_magazine(get_parent(), Transform3D(Basis.IDENTITY, position), BoxMesh.new())


# Recarga por gestos: se inicia con el gesto de recarga y la dirigen las poses de las manos.
func _drive_reload(primary: Transform3D, secondary: Transform3D, other_grip: bool, delta: float) -> void:
	var rs = reload_system
	rs.tick(delta)
	if not rs.active:
		return
	var forward := -primary.basis.z
	var well := Transform3D(primary.basis, primary.origin - Vector3.UP * 0.16 + forward * 0.04)
	var in_zone: bool = secondary.origin.distance_to(well.origin) <= HANDGUARD_RADIUS
	if not other_grip or not in_zone:
		_rl_armed = true
	var along: float = (secondary.origin - primary.origin).dot(forward)
	if other_grip and not _rl_prev_grip:
		_rl_ref = along
		_rl_back = false
	var released: bool = _rl_prev_grip and not other_grip
	_rl_prev_grip = other_grip
	var travel: float = along - _rl_ref
	match rs.phase():
		"insert":
			if _rl_armed and other_grip and in_zone and rs.insert_magazine(secondary, well):
				_rl_armed = false
		"load_shell":
			if _rl_armed and other_grip and in_zone and rs.load_shell():
				_rl_armed = false
		"load_round":
			if _rl_armed and other_grip and in_zone and rs.load_round():
				_rl_armed = false
		"chamber":
			if other_grip:
				rs.rack_slide(maxf(-travel, 0.0), false)
			elif released:
				rs.rack_slide(0.0, true)
		"open_bolt":
			if other_grip and travel <= -0.06:
				rs.open_bolt()
				_rl_back = false
		"pump", "close_bolt":
			if other_grip:
				if travel <= -0.06 and not _rl_back:
					_rl_back = true
					rs.pump_action(-0.1)
				elif _rl_back and travel >= -0.015:
					_rl_back = false
					if rs.phase() == "pump":
						rs.pump_action(0.1)
					else:
						rs.close_bolt()


func _drive_cycle(primary: Transform3D, secondary: Transform3D, other_grip: bool) -> void:
	if not other_grip or not weapon_system.has_method("cycle_stroke"):
		return
	var center := handguard_center(primary, weapon_id, handguard_offsets)
	if secondary.origin.distance_to(center) > HANDGUARD_RADIUS * 1.8:
		return
	var along: float = (secondary.origin - primary.origin).dot((-primary.basis.z).normalized())
	weapon_system.call("cycle_stroke", weapon_id, along - handguard_offset(weapon_id, handguard_offsets))


func _on_reload_haptic(target_hand: String, duration: float, amplitude: float) -> void:
	pulse(target_hand, duration, 0.6, amplitude)


func cancel_manual_reload(reason: String = "cambio_de_arma") -> void:
	manual_reload_active = false
	if reload_gestures != null:
		reload_gestures.cancel(reason)


func reload_phase() -> String:
	return reload_gestures.phase() if reload_gestures != null else ""


func reload_can_fire() -> bool:
	return manual_reload_active and reload_gestures != null and bool(reload_gestures.can_fire())


func reload_events() -> Array:
	return reload_gestures.events() if reload_gestures != null else []


func reload_eject_magazine(position: Vector3 = Vector3.ZERO) -> Dictionary:
	return reload_gestures.eject_magazine(position) if reload_gestures != null else {"ejected": false}


func reload_insert_magazine(pose: Transform3D, well: Transform3D) -> bool:
	return bool(reload_gestures.insert_magazine(pose, well)) if reload_gestures != null else false


func reload_rack_slide(pull: float, released: bool) -> bool:
	return bool(reload_gestures.rack_slide(pull, released)) if reload_gestures != null else false


func reload_pump(travel: float) -> bool:
	return bool(reload_gestures.pump_action(travel)) if reload_gestures != null else false


func reload_open_bolt() -> bool:
	return bool(reload_gestures.open_bolt()) if reload_gestures != null else false


func reload_load_round() -> bool:
	return bool(reload_gestures.load_round()) if reload_gestures != null else false


func reload_close_bolt() -> bool:
	return bool(reload_gestures.close_bolt()) if reload_gestures != null else false


func step(delta: float) -> void:
	_time += maxf(delta, 0.0)
	var primary := _pose(hand)
	var secondary := _pose(other_hand())
	var grip := _button("grip", hand)
	var other_grip := _button("grip", other_hand())

	if grip and not _was_grip:
		if weapon_id.is_empty() and _in_bag_zone(primary):
			try_take()
	elif not grip and _was_grip and not weapon_id.is_empty():
		stow()
	_was_grip = grip

	var secondary_free: bool = bag == null or bag.held_in(other_hand()).is_empty()
	var in_zone: bool = false
	if not weapon_id.is_empty() and other_grip and secondary_free:
		in_zone = is_in_handguard_zone(primary, secondary, weapon_id, handguard_offsets)
	if in_zone != _two_hand:
		_two_hand = in_zone
		if in_zone:
			two_hand_entered.emit(weapon_id)
		else:
			two_hand_exited.emit(weapon_id)
	if reload_system != null and reload_system.active:
		_drive_reload(primary, secondary, other_grip, delta)
	elif not weapon_id.is_empty() and weapon_system != null and weapon_system.has_method("needs_cycle") \
			and bool(weapon_system.call("needs_cycle", weapon_id)) and secondary_free:
		_drive_cycle(primary, secondary, other_grip)
	if not weapon_id.is_empty() and other_grip and secondary_free \
			and is_reload_gesture(primary, secondary, weapon_id):
		try_reload()

	var target := aim_direction(primary, secondary, _two_hand)
	_aim_dir = limit_turn(_aim_dir, target, max_aim_turn_degrees, aim_smoothing)

	var trigger := _button("trigger", hand)
	if trigger and (not _was_trigger or _auto_ready()):
		try_fire(_space())
	elif not trigger and _was_trigger:
		recoil.end_burst()
	_was_trigger = trigger

	recoil.step(delta)
	_recoil = maxf(_recoil - delta * 5.0, 0.0)
	_update_visual(primary, delta)


func try_take(item_id: String = "") -> bool:
	if not weapon_id.is_empty() or bag == null:
		return false
	var pose := _pose(hand)
	if not bag.is_open():
		bag.open(pose.origin)
	var ids: Array = bag.items()
	if ids.is_empty():
		return false
	if item_id.is_empty():
		var taken: bool = false
		for candidate in ids:
			if bag.take(str(candidate), hand):
				taken = true
				break
		if not taken:
			return false
	elif not bag.take(item_id, hand):
		return false
	weapon_id = bag.held_in(hand)
	_aim_dir = aim_direction(pose, Transform3D.IDENTITY, false)
	_two_hand = false
	_build_visual(weapon_id)
	if use_physical_grab:
		configure_handling()
		grab_weapon_from_pose(Transform3D(_aim_basis(pose), pose.origin), 1.0, "grip")
	weapon_taken.emit(weapon_id, hand)
	return true


func stow() -> void:
	if weapon_id.is_empty():
		return
	if manual_reload_active:
		cancel_manual_reload("arma_guardada")
	if grab_system != null and grab_system.is_grabbing():
		release_weapon(Vector3.ZERO)
	var stowed_id := weapon_id
	if bag != null:
		bag.stow(hand)
	weapon_id = ""
	_two_hand = false
	_clear_visual()
	weapon_stowed.emit(stowed_id, hand)


func _auto_ready() -> bool:
	if weapon_id.is_empty() or weapon_system == null or not weapon_system.has_method("fire_block_reason"):
		return false
	return bool(DbScript.get_def(weapon_id).get("auto", false)) \
		and str(weapon_system.call("fire_block_reason", weapon_id)).is_empty()


func _trace(step_name: String) -> void:
	shot_trace.append({"step": step_name, "frame": Engine.get_process_frames()})


func try_fire(space = null) -> Dictionary:
	shot_trace = []
	if weapon_id.is_empty():
		last_shot = {"fired": false, "reason": "empty_hand"}
		return last_shot
	if manual_reload_active and not reload_can_fire():
		last_shot = {"fired": false, "reason": "arma_no_montada"}
		return last_shot
	if weapon_system == null or not weapon_system.has_method("fire"):
		last_shot = {"fired": false, "reason": "no_weapon_system"}
		return last_shot
	var primary := _pose(hand)
	var base := _aim_dir.normalized()
	if base.length_squared() <= 0.000001:
		base = aim_direction(primary, Transform3D.IDENTITY, false)
	# 1) municion/recamara
	var origin := _muzzle_origin(primary)
	var blocked := ""
	if weapon_system.has_method("fire_block_reason"):
		blocked = str(weapon_system.call("fire_block_reason", weapon_id))
	_trace("ammo")
	if not blocked.is_empty():
		var refused = weapon_system.call("fire", weapon_id, origin, base, space, exclude.duplicate())
		last_shot = refused if refused is Dictionary else {"fired": false, "reason": blocked}
		if blocked.find("municion") >= 0 and viewmodel != null and viewmodel.has_method("on_empty"):
			viewmodel.call("on_empty")
		return last_shot
	# la direccion lleva el climb del disparo anterior (se calcula antes del nuevo impulso)
	var direction: Vector3 = recoil.aim_direction(base)
	# 2) impulso de retroceso sobre el arma en la mano
	recoil.primary_hand = hand
	recoil.secondary_hand = other_hand()
	var shot: Dictionary = recoil.on_fired(weapon_id, _two_hand)
	_recoil = current_recoil()
	_trace("recoil")
	# 3) haptica
	for event in recoil.haptic_events():
		pulse(str(event["hand"]), float(event["duration"]), 0.75, float(event["amplitude"]))
	_trace("haptic")
	# 4) fogonazo y humo
	var host: Node = get_parent() if get_parent() != null else self
	var use_model: bool = fx_via_viewmodel and viewmodel != null and viewmodel.has_method("on_fired") \
		and viewmodel.find_child("MuzzleFx", true, false) != null
	if use_model:
		viewmodel.call("on_fired")
	elif is_inside_tree():
		MuzzleFxScript.spawn_flash(host, origin, direction, 1.0)
		MuzzleFxScript.spawn_smoke(host, origin, direction, 1.0)
	_trace("muzzle_fx")
	# 5) sonido en el canon
	_play_shot_sound(origin)
	_trace("sound")
	# 6) vaina por la ventana (con modelo la expulsa su MuzzleFx en el paso 4)
	if not use_model and is_inside_tree():
		var side := _aim_basis(primary)
		MuzzleFxScript.eject_casing(host, origin + side.x * 0.03 - side.z * 0.12, direction)
	_trace("casing")
	# 7) el disparo sale por la direccion con climb
	var result = weapon_system.call("fire", weapon_id, origin, direction, space, exclude.duplicate())
	_trace("fire")
	last_shot = result if result is Dictionary else {"fired": false, "reason": "respuesta_invalida"}
	last_shot["direction"] = direction
	last_shot["recoil"] = shot
	last_shot["camera_shake"] = 0.0
	if bool(last_shot.get("fired", false)):
		if manual_reload_active and reload_gestures != null:
			reload_gestures.fire()
		fired.emit(last_shot)
	return last_shot


func _play_shot_sound(origin: Vector3) -> void:
	var host: Node = get_parent() if get_parent() != null else self
	RecordedSfx.play(weapon_id, "fire", host, origin)
	if not RecordedSfx.has_sample(weapon_id, "fire"):
		var audio_host: Node3D = get_parent() as Node3D
		if audio_host == null:
			audio_host = self
		SfxBankScript.play_synth(audio_host, "shot", weapon_id, origin, "sfx")


func try_reload() -> bool:
	if manual_gesture_reload and not weapon_id.is_empty() and _ensure_reload_system():
		if reload_system.active or not reload_system.begin(weapon_id):
			return false
		manual_reload_active = true
		_rl_armed = false
		_rl_prev_grip = true
		var primary := _pose(hand)
		reload_system.audio_host = get_parent() as Node3D
		reload_system.audio_position = primary.origin
		reload_system.eject_magazine(primary.origin - Vector3.UP * 0.16)
		return true
	if weapon_id.is_empty() or weapon_system == null or not weapon_system.has_method("reload"):
		return false
	var ok := bool(weapon_system.call("reload", weapon_id))
	if ok:
		var def: Dictionary = DbScript.get_def(weapon_id)
		if viewmodel != null and viewmodel.has_method("on_reload_started"):
			viewmodel.call("on_reload_started", maxf(float(def.get("reload_time", 1.0)), 0.05))
		reloaded.emit(weapon_id)
	return ok


func on_impact(info: Dictionary) -> void:
	if weapon_id.is_empty() or str(info.get("weapon_id", "")) != weapon_id:
		return
	var strength: float = clampf(float(info.get("damage", 0.0)) / 50.0, 0.1, 1.0)
	pulse(hand, 0.08, 0.5, strength)


func pulse(target_hand: String, duration: float = 0.05, frequency: float = 0.6, amplitude: float = 0.5) -> void:
	last_haptic = {
		"hand": target_hand,
		"duration": duration,
		"frequency": frequency,
		"amplitude": amplitude,
	}
	haptic.emit(target_hand, duration, frequency, amplitude)
	var controller = null
	var provider = _provider()
	if provider != null and provider.has_method("controller_for"):
		controller = provider.call("controller_for", target_hand)
	if controller != null and controller.has_method("trigger_haptic"):
		controller.call("trigger_haptic", duration, frequency, amplitude)


func _provider():
	return input_provider if input_provider != null else self


func _pose(hand_name: String) -> Transform3D:
	var provider = _provider()
	if provider != null and provider.has_method("get_pose"):
		var value = provider.call("get_pose", hand_name)
		if value is Transform3D:
			return value
	return Transform3D.IDENTITY


func _button(action: String, hand_name: String) -> bool:
	var provider = _provider()
	if provider == null:
		return false
	var method := "is_grip_pressed" if action == "grip" else "is_trigger_pressed"
	if provider.has_method(method):
		return bool(provider.call(method, hand_name))
	if provider.has_method("is_pressed"):
		return bool(provider.call("is_pressed", action))
	return false


func _in_bag_zone(pose: Transform3D) -> bool:
	return bag != null and bag.is_in_bag_zone(pose.origin)


func _space():
	var world := get_world_3d()
	return world.direct_space_state if world != null else null


func _aim_basis(primary: Transform3D) -> Basis:
	var direction := _aim_dir.normalized()
	if direction.length_squared() <= 0.000001:
		direction = Vector3.FORWARD
	var up: Vector3 = primary.basis.y
	if up.length_squared() <= 0.000001:
		up = Vector3.UP
	var z_axis := -direction
	var x_axis := up.cross(z_axis)
	if x_axis.length_squared() <= 0.000001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _muzzle_origin(primary: Transform3D) -> Vector3:
	var basis := _aim_basis(primary)
	return primary.origin + basis.x * muzzle_offset.x + basis.y * muzzle_offset.y + basis.z * muzzle_offset.z


func _update_visual(primary: Transform3D, delta: float = 0.0) -> void:
	if holder == null or weapon_id.is_empty():
		return
	var basis := _aim_basis(primary)
	var kick: Transform3D = recoil.weapon_offset()
	var aim_basis := basis
	var offset := grip_offset + aim_basis * kick.origin
	basis = aim_basis * kick.basis
	var shake: float = current_shake()
	offset += Vector3(sin(_time * 23.0), cos(_time * 19.0), 0.0) * shake
	if use_physical_grab and grab_system != null and grab_system.is_grabbing():
		var linked: Transform3D = grab_system.step(delta, primary, _button("grip", hand))
		holder.global_transform = Transform3D(linked.basis, linked.origin + aim_basis * kick.origin + Vector3(sin(_time * 23.0), cos(_time * 19.0), 0.0) * shake)
	else:
		holder.global_transform = Transform3D(basis, primary.origin + offset)
	if viewmodel != null and is_instance_valid(viewmodel) and viewmodel.has_method("advance"):
		viewmodel.call("advance", maxf(delta, 0.0))
	_advance_fx(delta)


func _advance_fx(delta: float) -> void:
	_detach_fx_anchors()
	var frame := Engine.get_process_frames()
	if frame == _last_fx_frame:
		return
	_last_fx_frame = frame
	MuzzleFxScript.advance(maxf(delta, 0.0))


func _detach_fx_anchors() -> void:
	if viewmodel == null or not is_instance_valid(viewmodel):
		return
	var fx: Node = viewmodel.find_child("MuzzleFx", true, false)
	if fx == null:
		return
	var host: Node = get_tree().root if get_tree() != null else self
	for child in fx.get_children():
		if not (child.name == "MuzzleFlash" or child.name == "MuzzleSmoke" or child.name == "DroppedMagazine"):
			continue
		if child.get_parent() != host:
			var world_transform: Transform3D = child.global_transform if child is Node3D else Transform3D.IDENTITY
			fx.remove_child(child)
			host.add_child(child)
			if child is Node3D:
				child.global_transform = world_transform


func _build_visual(id: String) -> void:
	_clear_visual()
	if id.is_empty():
		return
	holder = Node3D.new()
	holder.name = "WeaponVisual"
	add_child(holder)
	var cfg: Dictionary = ViewmodelScript.VIEW.get(id, {})
	if not cfg.is_empty() and cfg.has("muzzle"):
		muzzle_offset = cfg.get("muzzle", muzzle_offset)
	var model = ViewmodelScript.new()
	model.name = "WeaponViewmodel"
	holder.add_child(model)
	model.set_process(false)
	model.call("set_weapon", id)
	model.call("attach_to", holder)
	var fx: Node = model.find_child("MuzzleFx", true, false)
	if fx != null:
		fx.set("casing_parent", get_tree().root if get_tree() != null else self)
		fx.call("set_process", false)
	viewmodel = model
	if bool(model.call("has_model")):
		return
	var def: Dictionary = DbScript.get_def(id)
	var tags: Array = def.get("tags", [])
	var long_gun: bool = tags.has("rifle") or tags.has("sniper") or tags.has("smg")
	var length: float = 0.44 if long_gun else 0.24
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.18, 0.20)
	material.metallic = 0.3
	material.roughness = 0.65
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.07, length)
	body.mesh = box
	body.material_override = material
	holder.add_child(body)
	if long_gun:
		var barrel := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.012
		cylinder.bottom_radius = 0.012
		cylinder.height = 0.20
		barrel.mesh = cylinder
		barrel.rotation.x = PI * 0.5
		barrel.position.z = -length * 0.5 - 0.08
		barrel.material_override = material
		holder.add_child(barrel)


func _clear_visual() -> void:
	viewmodel = null
	if holder != null and is_instance_valid(holder) and not holder.is_queued_for_deletion():
		holder.queue_free()
	holder = null


static func aim_direction(primary: Transform3D, secondary: Transform3D, use_secondary: bool) -> Vector3:
	if use_secondary:
		var line := secondary.origin - primary.origin
		if line.length_squared() > 0.000001:
			return line.normalized()
	var forward := -primary.basis.z
	return forward.normalized() if forward.length_squared() > 0.000001 else Vector3.FORWARD


static func limit_turn(
	current: Vector3, target: Vector3, max_degrees: float, smoothing: float = 1.0
) -> Vector3:
	var from := current.normalized()
	var to := target.normalized()
	if from.length_squared() <= 0.000001:
		return to
	if to.length_squared() <= 0.000001:
		return from
	var angle: float = from.angle_to(to)
	if angle <= 0.000001:
		return to
	if max_degrees <= 0.0 or smoothing <= 0.0:
		return from
	var step: float = minf(rad_to_deg(angle) * clampf(smoothing, 0.0, 1.0), maxf(max_degrees, 0.0))
	var axis := from.cross(to)
	if axis.length_squared() <= 0.00000001:
		return to
	return from.rotated(axis.normalized(), deg_to_rad(step)).normalized()


static func handguard_offset(weapon_id: String, overrides: Dictionary = {}) -> float:
	if overrides.has(weapon_id):
		return clampf(float(overrides[weapon_id]), 0.02, 1.0)
	if HANDGUARD_OFFSETS.has(weapon_id):
		return float(HANDGUARD_OFFSETS[weapon_id])
	if _has_tag(weapon_id, "sniper"):
		return 0.32
	if _has_tag(weapon_id, "rifle"):
		return 0.24
	if _has_tag(weapon_id, "shotgun"):
		return 0.20
	if _has_tag(weapon_id, "smg"):
		return 0.16
	if _has_tag(weapon_id, "sidearm"):
		return 0.08
	return 0.12


static func handguard_center(primary: Transform3D, weapon_id: String, overrides: Dictionary = {}) -> Vector3:
	var forward := -primary.basis.z
	if forward.length_squared() <= 0.000001:
		forward = Vector3.FORWARD
	return primary.origin + forward.normalized() * handguard_offset(weapon_id, overrides)


static func is_in_handguard_zone(
	primary: Transform3D, secondary: Transform3D, weapon_id: String,
	overrides: Dictionary = {}, radius: float = HANDGUARD_RADIUS
) -> bool:
	if weapon_id.is_empty():
		return false
	return secondary.origin.distance_to(handguard_center(primary, weapon_id, overrides)) <= maxf(radius, 0.01)


static func is_reload_gesture(
	primary: Transform3D, secondary: Transform3D, weapon_id: String,
	radius: float = HANDGUARD_RADIUS
) -> bool:
	if weapon_id.is_empty():
		return false
	var forward := -primary.basis.z
	if forward.length_squared() <= 0.000001:
		forward = Vector3.FORWARD
	var center := primary.origin - Vector3.UP * 0.16 + forward.normalized() * 0.04
	return secondary.origin.distance_to(center) <= maxf(radius, 0.01)


static func recoil_reduction(weapon_id: String, overrides: Dictionary = {}) -> float:
	if overrides.has(weapon_id):
		return clampf(float(overrides[weapon_id]), 0.0, 0.95)
	if RECOIL_REDUCTIONS.has(weapon_id):
		return float(RECOIL_REDUCTIONS[weapon_id])
	if _has_tag(weapon_id, "sniper"):
		return 0.75
	if _has_tag(weapon_id, "rifle"):
		return 0.65
	if _has_tag(weapon_id, "shotgun"):
		return 0.50
	if _has_tag(weapon_id, "smg"):
		return 0.35
	return 0.25


static func effective_recoil(
	weapon_id: String, two_handed: bool, base: float, overrides: Dictionary = {}
) -> float:
	var factor: float = 1.0 - recoil_reduction(weapon_id, overrides) if two_handed else 1.0
	return maxf(base, 0.0) * factor


static func shake_amplitude(
	weapon_id: String, two_handed: bool, base: float, overrides: Dictionary = {}
) -> float:
	var factor: float = 1.0 - recoil_reduction(weapon_id, overrides) * 0.8 if two_handed else 1.0
	return maxf(base, 0.0) * factor


static func _has_tag(weapon_id: String, tag: String) -> bool:
	var def: Dictionary = DbScript.get_def(weapon_id)
	if def.is_empty():
		return false
	var tags = def.get("tags", [])
	if tags is Array:
		return (tags as Array).has(tag)
	return false
