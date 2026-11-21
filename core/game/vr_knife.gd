class_name VrKnife
extends VrGrabbable

# VR Knife weapon with velocity/direction-based cutting, haptics, cooldown, and gore integration
# MIT License - Adapted from VR weapon systems in this project

signal slashed(cut_info: Dictionary)
signal hit_solid(hit_info: Dictionary)

const DbScript = preload("res://core/game/weapon_db.gd")
const GoreScript = preload("res://core/game/gore_system.gd")
const MeshSlicerScript = preload("res://core/game/mesh_slicer.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const WoundDecalsScript = preload("res://core/game/wound_decals.gd")

@export var weapon_id: String = "untitled.base:knife"
@export var min_slash_speed: float = 2.0
@export var max_slash_speed: float = 12.0
@export var slash_cooldown: float = 0.35
@export var cut_angle_threshold: float = 0.7
@export var cut_depth_mult: float = 1.0

var _cooldown_timer: float = 0.0
var _last_velocity: Vector3 = Vector3.ZERO
var _last_position: Vector3 = Vector3.ZERO
var _is_slashing: bool = false
var _slash_start_pos: Vector3 = Vector3.ZERO
var _slash_start_time: float = 0.0
var _accumulated_velocity: Vector3 = Vector3.ZERO
var _slash_direction: Vector3 = Vector3.ZERO
var _slash_speed: float = 0.0
var _vr_hand_ref: Object = null
var _haptic_light: Dictionary = {}
var _haptic_medium: Dictionary = {}
var _haptic_heavy: Dictionary = {}
var _gore_level_mult: Dictionary = {}

func _ready() -> void:
	grabbable = true
	_load_weapon_config()
	
	if get_parent() != null and get_parent().has_method("bind_vr_hand"):
		_vr_hand_ref = get_parent()

func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	
	if is_grabbed():
		_update_slash_detection(delta)

func _update_slash_detection(delta: float) -> void:
	var current_pos := global_position
	var current_vel := (current_pos - _last_position) / maxf(delta, 0.0001)
	var speed := current_vel.length()
	
	if speed >= min_slash_speed and not _is_slashing:
		_start_slash(current_pos, current_vel, speed)
	elif _is_slashing:
		_accumulated_velocity += current_vel * delta
		if speed < min_slash_speed * 0.5 or _cooldown_timer <= 0.0:
			_end_slash(current_pos)
	
	_last_velocity = current_vel
	_last_position = current_pos

func _start_slash(start_pos: Vector3, velocity: Vector3, speed: float) -> void:
	_is_slashing = true
	_slash_start_pos = start_pos
	_slash_start_time = Time.get_ticks_msec() / 1000.0
	_accumulated_velocity = velocity
	_slash_direction = velocity.normalized()
	_slash_speed = clampf(speed, min_slash_speed, max_slash_speed)

func _end_slash(end_pos: Vector3) -> void:
	if not _is_slashing:
		return
	
	var slash_duration = Time.get_ticks_msec() / 1000.0 - _slash_start_time
	var avg_velocity = _accumulated_velocity / maxf(slash_duration, 0.001)
	var avg_speed = avg_velocity.length()
	var slash_dir = avg_velocity.normalized()
	
	if avg_speed >= min_slash_speed and slash_duration > 0.05:
		_perform_cut(_slash_start_pos, end_pos, slash_dir, avg_speed)
	
	_is_slashing = false
	_cooldown_timer = slash_cooldown
	_accumulated_velocity = Vector3.ZERO

func _perform_cut(start_pos: Vector3, end_pos: Vector3, direction: Vector3, speed: float) -> void:
	var space = get_world_3d().direct_space_state if get_world_3d() != null else null
	if space == null:
		_trigger_haptic("light")
		return
	
	var query = PhysicsRayQueryParameters3D.new()
	query.from = start_pos
	query.to = end_pos + direction * 0.5
	query.exclude = [self, get_parent()] if get_parent() != null else [self]
	query.collision_mask = 0xFFFFFFFF
	query.hit_from_inside = true
	
	var result = space.intersect_ray(query)
	if result.is_empty():
		_trigger_haptic("light")
		return
	
	var collider = result.collider
	var hit_pos = result.position
	var hit_normal = result.normal
	
	var angle_cos = abs(direction.dot(hit_normal))
	if angle_cos > cut_angle_threshold:
		_trigger_haptic("light")
		hit_solid.emit({"position": hit_pos, "normal": hit_normal, "collider": collider})
		return
	
	var gore_level = GoreScript.get_gore_level()
	var gore_mult = _gore_level_mult.get(gore_level, 1.0)
	if gore_mult <= 0.0:
		_trigger_haptic("light")
		return
	
	var damage = _calculate_damage(speed, gore_mult)
	var cut_info = {
		"weapon_id": weapon_id,
		"start_pos": start_pos,
		"end_pos": end_pos,
		"hit_pos": hit_pos,
		"hit_normal": hit_normal,
		"direction": direction,
		"speed": speed,
		"damage": damage,
		"gore_level": gore_level,
		"gore_mult": gore_mult,
		"collider": collider
	}
	
	_apply_cut(cut_info)
	_trigger_haptic_for_speed(speed)
	slashed.emit(cut_info)

func _calculate_damage(speed: float, gore_mult: float) -> float:
	var def = DbScript.get_def(weapon_id)
	var base_damage = float(def.get("damage", 40.0))
	var speed_mult = lerpf(0.5, 1.5, clampf((speed - min_slash_speed) / (max_slash_speed - min_slash_speed), 0.0, 1.0))
	return base_damage * speed_mult * gore_mult * cut_depth_mult

func _apply_cut(cut_info: Dictionary) -> void:
	var collider = cut_info["collider"]
	if not is_instance_valid(collider):
		return
	
	var hit_pos = cut_info["hit_pos"]
	var direction = cut_info["direction"]
	var damage = cut_info["damage"]
	var gore_level = cut_info["gore_level"]
	var gore_mult = cut_info["gore_mult"]
	
	if collider.has_method("take_damage"):
		collider.call("take_damage", damage, hit_pos, direction, weapon_id)
	
	if gore_level != GoreScript.GoreLevel.OFF:
		MeshSlicerScript.slice_mesh(Transform3D(Basis.looking_at(direction, Vector3.UP), hit_pos), collider.get("mesh", null) if collider.has("mesh") else null)
		GoreFxScript.blood_hit(collider.get_parent() if collider.get_parent() != null else collider, hit_pos, cut_info["hit_normal"], damage * 0.1, direction)
		WoundDecalsScript.create_wound(collider.get_parent() if collider.get_parent() != null else collider, hit_pos, cut_info["hit_normal"], damage * 0.05, 2, "", -1, Vector2(0.5, 0.5), 0.5)

func _trigger_haptic(intensity: String) -> void:
	var haptic_data = _haptic_light
	match intensity:
		"light": haptic_data = _haptic_light
		"medium": haptic_data = _haptic_medium
		"Heavy": haptic_data = _haptic_heavy
	
	if _vr_hand_ref != null and _vr_hand_ref.has_method("pulse"):
		var parent = get_parent()
		var hand = "right"
		if parent != null and parent.has("hand"):
			hand = parent.get("hand")
		_vr_hand_ref.call("pulse", hand, haptic_data.duration, haptic_data.frequency, haptic_data.amplitude)

func _trigger_haptic_for_speed(speed: float) -> void:
	var t = clampf((speed - min_slash_speed) / (max_slash_speed - min_slash_speed), 0.0, 1.0)
	if t < 0.33:
		_trigger_haptic("light")
	elif t < 0.66:
		_trigger_haptic("medium")
	else:
		_trigger_haptic("Heavy")

func _load_weapon_config() -> void:
	var def = DbScript.get_def(weapon_id)
	if def.is_empty():
		return
	
	var vr_knife_cfg = def.get("vr_knife", {})
	if not vr_knife_cfg.is_empty():
		min_slash_speed = float(vr_knife_cfg.get("min_slash_speed", min_slash_speed))
		max_slash_speed = float(vr_knife_cfg.get("max_slash_speed", max_slash_speed))
		slash_cooldown = float(vr_knife_cfg.get("slash_cooldown", slash_cooldown))
		cut_angle_threshold = float(vr_knife_cfg.get("cut_angle_threshold", cut_angle_threshold))
		cut_depth_mult = float(vr_knife_cfg.get("cut_depth_mult", cut_depth_mult))
		_haptic_light = vr_knife_cfg.get("haptic_light", _haptic_light)
		_haptic_medium = vr_knife_cfg.get("haptic_medium", _haptic_medium)
		_haptic_heavy = vr_knife_cfg.get("haptic_heavy", _haptic_heavy)
		_gore_level_mult = vr_knife_cfg.get("gore_level_mult", _gore_level_mult)
	
	_last_position = global_position

func can_slash() -> bool:
	return _cooldown_timer <= 0.0 and is_grabbed()

func get_cooldown_remaining() -> float:
	return maxf(_cooldown_timer, 0.0)

func force_end_slash() -> void:
	if _is_slashing:
		_end_slash(global_position)