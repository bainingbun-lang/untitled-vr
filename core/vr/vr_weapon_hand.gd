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
	if not weapon_id.is_empty() and other_grip and secondary_free \
			and is_reload_gesture(primary, secondary, weapon_id):
		try_reload()

	var target := aim_direction(primary, secondary, _two_hand)
	_aim_dir = limit_turn(_aim_dir, target, max_aim_turn_degrees, aim_smoothing)

	var trigger := _button("trigger", hand)
	if trigger and not _was_trigger:
		try_fire(_space())
	_was_trigger = trigger

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
	weapon_taken.emit(weapon_id, hand)
	return true


func stow() -> void:
	if weapon_id.is_empty():
		return
	var stowed_id := weapon_id
	if bag != null:
		bag.stow(hand)
	weapon_id = ""
	_two_hand = false
	_clear_visual()
	weapon_stowed.emit(stowed_id, hand)


func try_fire(space = null) -> Dictionary:
	if weapon_id.is_empty():
		last_shot = {"fired": false, "reason": "empty_hand"}
		return last_shot
	if weapon_system == null or not weapon_system.has_method("fire"):
		last_shot = {"fired": false, "reason": "no_weapon_system"}
		return last_shot
	var primary := _pose(hand)
	var direction := _aim_dir.normalized()
	if direction.length_squared() <= 0.000001:
		direction = aim_direction(primary, Transform3D.IDENTITY, false)
	var origin := _muzzle_origin(primary)
	var result = weapon_system.call("fire", weapon_id, origin, direction, space, exclude.duplicate())
	last_shot = result if result is Dictionary else {"fired": false, "reason": "respuesta_invalida"}
	if bool(last_shot.get("fired", false)):
		_recoil = current_recoil()
		if viewmodel != null and viewmodel.has_method("on_fired"):
			viewmodel.call("on_fired")
		_play_shot_sound(origin)
		pulse(hand, 0.05, 0.75, 0.55)
		fired.emit(last_shot)
	elif str(last_shot.get("error", "")).find("municion") >= 0:
		if viewmodel != null and viewmodel.has_method("on_empty"):
			viewmodel.call("on_empty")
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
	var offset := grip_offset + basis.z * _recoil
	var shake: float = current_shake()
	offset += Vector3(sin(_time * 23.0), cos(_time * 19.0), 0.0) * shake
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
