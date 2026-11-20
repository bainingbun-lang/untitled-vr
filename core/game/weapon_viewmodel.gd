class_name WeaponViewmodel
extends Node3D

const MuzzleFxScript = preload("res://core/game/muzzle_fx.gd")
const WeaponPartsScript = preload("res://core/game/weapon_parts.gd")

const MODEL_DIR := "res://assets/models/weapons/"

const VIEW: Dictionary = {
	"pistol": {
		"model": MODEL_DIR + "pistol.glb",
		"pos": Vector3(0.20, -0.17, -0.28),
		"align_y": 90.0,
		"length": 0.26,
		"muzzle": Vector3(0.0, 0.035, -0.25),
		"eject": Vector3(0.035, 0.025, 0.055),
		"fx": 0.8,
		"kick": Vector3(0.25, 1.6, 2.2),
	},
	"submachine_gun": {
		"model": MODEL_DIR + "submachine_gun.glb",
		"pos": Vector3(0.19, -0.19, -0.26),
		"align_y": 90.0,
		"length": 0.46,
		"muzzle": Vector3(0.0, 0.04, -0.44),
		"eject": Vector3(0.04, 0.025, 0.11),
		"fx": 0.9,
		"kick": Vector3(0.30, 1.4, 2.0),
	},
	"assault_rifle": {
		"model": MODEL_DIR + "assault_rifle.glb",
		"pos": Vector3(0.17, -0.20, -0.24),
		"align_y": 90.0,
		"length": 0.60,
		"muzzle": Vector3(0.0, 0.045, -0.58),
		"eject": Vector3(0.05, 0.03, 0.17),
		"fx": 1.0,
		"kick": Vector3(0.35, 2.1, 2.8),
	},
	"shotgun": {
		"model": MODEL_DIR + "shotgun.glb",
		"pos": Vector3(0.18, -0.21, -0.24),
		"align_y": 90.0,
		"length": 0.64,
		"muzzle": Vector3(0.0, 0.04, -0.62),
		"eject": Vector3(0.045, 0.03, 0.20),
		"fx": 1.3,
		"kick": Vector3(0.45, 3.2, 3.8),
	},
	"sniper_rifle": {
		"model": MODEL_DIR + "sniper_rifle.glb",
		"pos": Vector3(0.16, -0.21, -0.22),
		"align_y": 90.0,
		"length": 0.78,
		"muzzle": Vector3(0.0, 0.05, -0.76),
		"eject": Vector3(0.045, 0.035, 0.22),
		"fx": 1.4,
		"kick": Vector3(0.50, 4.0, 4.6),
	},
	"bat": {
		"model": MODEL_DIR + "bat.glb",
		"pos": Vector3(0.20, -0.26, -0.26),
		"align_y": 180.0,
		"length": 0.62,
		"muzzle": Vector3(0.0, 0.02, -0.58),
		"fx": 0.0,
		"kick": Vector3(0.20, 1.0, 1.4),
	},
}

const RECOIL_STIFFNESS := 120.0
const RECOIL_DAMPING := 14.0
const BOB_FREQ := 9.0
const BOB_AMP := 0.012
const RELOAD_SWING := 0.14
const SWITCH_DURATION := 0.26
const PUMP_DURATION := 0.32
const EMPTY_DURATION := 0.18
const FIRE_STROKE_DURATION := 0.15
const PART_STROKE := 0.11
const PUMP_STROKE := 0.16
const MAG_INSERT_DROP := 0.22

var walk_intensity: float = 0.0

var _motion: Node3D = null
var _rig: Node3D = null
var _model_holder: Node3D = null
var _fx: MuzzleFx = null
var _current_id: String = ""
var _base_pos: Vector3 = Vector3.ZERO
var _in_vr_hand: bool = false

var _recoil_offset: Vector3 = Vector3.ZERO
var _recoil_velocity: Vector3 = Vector3.ZERO
var _bob_phase: float = 0.0
var _bob_offset: Vector3 = Vector3.ZERO

var _reload_active: bool = false
var _reload_elapsed: float = 0.0
var _reload_duration: float = 0.0
var _reload_offset: Vector3 = Vector3.ZERO
var _reload_rotation: Vector3 = Vector3.ZERO

var _switch_active: bool = false
var _switch_elapsed: float = 0.0
var _switch_offset: Vector3 = Vector3.ZERO
var _switch_rotation: Vector3 = Vector3.ZERO

var _pump_active: bool = false
var _pump_elapsed: float = 0.0
var _pump_offset: Vector3 = Vector3.ZERO
var _pump_rotation: Vector3 = Vector3.ZERO

var _empty_active: bool = false
var _empty_elapsed: float = 0.0
var _empty_offset: Vector3 = Vector3.ZERO
var _empty_rotation: Vector3 = Vector3.ZERO

var _parts = null
var _fire_stroke: float = -1.0
var _fire_stroke_role: String = ""
var _slide_locked: bool = false
var _pump_sfx_fired: bool = false
var _pump_sfx_index: int = -1
var _reload_phase: String = ""
var _reload_t: float = 0.0
var _reload_phases: Array = []
var _mag_dropped: bool = false


func _ready() -> void:
	_ensure_setup()


func _process(delta: float) -> void:
	advance(delta)


func _ensure_setup() -> void:
	if is_instance_valid(_motion):
		return
	_motion = Node3D.new()
	_motion.name = "Motion"
	add_child(_motion)
	_rig = Node3D.new()
	_rig.name = "Rig"
	_motion.add_child(_rig)
	_model_holder = Node3D.new()
	_model_holder.name = "ModelHolder"
	_rig.add_child(_model_holder)
	_fx = MuzzleFxScript.new()
	_fx.name = "MuzzleFx"
	_rig.add_child(_fx)


static func model_path_for(id: String) -> String:
	if not VIEW.has(id):
		return ""
	return str((VIEW[id] as Dictionary).get("model", ""))


static func model_ids() -> Array:
	return VIEW.keys()


static func has_model_for(id: String) -> bool:
	var path := model_path_for(id)
	return not path.is_empty() and ResourceLoader.exists(path)


func set_weapon(id: String) -> bool:
	_ensure_setup()
	if not VIEW.has(id):
		push_warning("WeaponViewmodel: arma desconocida '%s'" % id)
		return false
	if id == _current_id and _model_holder.get_child_count() > 0:
		return true
	_swap_model(id)
	_switch_active = true
	_switch_elapsed = 0.0
	return true


func on_fired() -> void:
	_ensure_setup()
	var cfg: Dictionary = VIEW.get(_current_id, {})
	var kick: Vector3 = cfg.get("kick", Vector3(0.3, 1.5, 2.0))
	_recoil_velocity += kick
	if _fx != null and float(cfg.get("fx", 1.0)) > 0.0:
		_fx.fire(float(cfg.get("fx", 1.0)), Vector3.FORWARD, cfg.get("eject", Vector3.ZERO))
	_start_fire_stroke()
	if _current_id == "shotgun":
		_pump_active = true
		_pump_elapsed = 0.0
		_pump_sfx_fired = false


func on_reload_started(duration: float) -> void:
	_ensure_setup()
	_reload_duration = maxf(duration, 0.05)
	_reload_elapsed = 0.0
	_reload_active = true
	_reload_phase = ""
	_reload_t = 0.0
	_reload_phases.clear()
	_mag_dropped = false
	_pump_sfx_index = -1


func on_empty() -> void:
	_ensure_setup()
	_empty_active = true
	_empty_elapsed = 0.0
	if _current_id == "pistol" and _parts != null and _parts.has_role("slide"):
		_slide_locked = true


func set_walk_intensity(value: float) -> void:
	walk_intensity = clampf(value, 0.0, 1.0)
	if _in_vr_hand:
		walk_intensity = 0.0


func attach_to(node: Node) -> void:
	if node == null:
		return
	_ensure_setup()
	if get_parent() != node:
		if get_parent() != null:
			reparent(node, false)
		else:
			node.add_child(self)
	transform = Transform3D.IDENTITY
	_in_vr_hand = true
	walk_intensity = 0.0
	_bob_offset = Vector3.ZERO


func advance(delta: float) -> void:
	_ensure_setup()
	var dt: float = maxf(delta, 0.0)
	_step_recoil(dt)
	_step_bob(dt)
	_step_reload(dt)
	_step_switch(dt)
	_step_pump(dt)
	_step_empty(dt)
	_step_parts(dt)
	_apply_transforms()


func current_weapon() -> String:
	return _current_id


func model_instance() -> Node:
	if not is_instance_valid(_model_holder):
		return null
	if _model_holder.get_child_count() == 0:
		return null
	return _model_holder.get_child(0)


func has_model() -> bool:
	return model_instance() != null


func is_switching() -> bool:
	return _switch_active


func is_reloading() -> bool:
	return _reload_active


func is_pumping() -> bool:
	return _pump_active


func is_in_vr_hand() -> bool:
	return _in_vr_hand


func recoil_offset() -> Vector3:
	return _recoil_offset


func rig_position() -> Vector3:
	return _rig.position if is_instance_valid(_rig) else Vector3.ZERO


func muzzle_fx() -> MuzzleFx:
	return _fx


func parts():
	return _parts


func part_offset(role: String) -> Vector3:
	if _parts == null:
		return Vector3.ZERO
	return _parts.offset(role)


func reload_phase() -> String:
	return _reload_phase


func reload_phases() -> Array:
	return _reload_phases.duplicate()


func is_slide_locked() -> bool:
	return _slide_locked


func is_fire_stroking() -> bool:
	return _fire_stroke >= 0.0


func eject_offset() -> Vector3:
	var cfg: Dictionary = VIEW.get(_current_id, {})
	return cfg.get("eject", Vector3.ZERO)


func _swap_model(id: String) -> void:
	for child in _model_holder.get_children():
		_model_holder.remove_child(child)
		child.queue_free()
	_current_id = id
	var cfg: Dictionary = VIEW[id] as Dictionary
	_base_pos = cfg.get("pos", Vector3.ZERO)
	_pump_active = false
	_pump_offset = Vector3.ZERO
	_pump_rotation = Vector3.ZERO
	_reload_active = false
	_reload_offset = Vector3.ZERO
	_reload_rotation = Vector3.ZERO
	_parts = null
	_fire_stroke = -1.0
	_slide_locked = false
	_reload_phase = ""
	_reload_phases.clear()
	var path: String = str(cfg.get("model", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("WeaponViewmodel: modelo no disponible para '%s'" % id)
		if _fx != null:
			_fx.position = Vector3.ZERO
		return
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("WeaponViewmodel: no se pudo cargar '%s'" % path)
		return
	var instance := packed.instantiate()
	if not (instance is Node3D):
		if instance != null:
			instance.free()
		push_warning("WeaponViewmodel: '%s' no es una escena 3D" % path)
		return
	var node := instance as Node3D
	node.name = "Model_" + id
	_model_holder.add_child(node)
	var box := _compute_aabb(node)
	var length: float = maxf(float(cfg.get("length", 0.5)), 0.05)
	if box.size.length() > 0.0001:
		var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
		var scale_factor: float = length / maxf(longest, 0.0001)
		var align_y: float = float(cfg.get("align_y", 0.0))
		var basis := Basis(Vector3.UP, deg_to_rad(align_y))
		node.rotation_degrees = Vector3(0.0, align_y, 0.0)
		node.scale = Vector3.ONE * scale_factor
		node.position = Vector3(0.0, 0.0, -length * 0.5) - (basis * (box.get_center() * scale_factor))
	else:
		node.scale = Vector3.ONE * (length / maxf(_estimate_node_scale(node), 0.0001))
	if _fx != null:
		_fx.position = cfg.get("muzzle", Vector3.ZERO)
	_parts = WeaponPartsScript.build(node, id)


func _compute_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var inv := root.global_transform.affine_inverse()
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	for item in meshes:
		var mi := item as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var rel := inv * mi.global_transform
		var box := rel * mi.mesh.get_aabb()
		if not found:
			result = box
			found = true
		else:
			result = result.merge(box)
	return result


func _estimate_node_scale(root: Node3D) -> float:
	var max_scale := 0.0
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mi := item as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		max_scale = maxf(max_scale, mi.mesh.get_aabb().size.length() * mi.scale.length())
	return max_scale


func _step_recoil(delta: float) -> void:
	if _recoil_offset.length_squared() < 0.00000001 and _recoil_velocity.length_squared() < 0.00000001:
		_recoil_offset = Vector3.ZERO
		_recoil_velocity = Vector3.ZERO
		return
	var remaining: float = minf(delta, 0.25)
	while remaining > 0.0:
		var step: float = minf(remaining, 1.0 / 90.0)
		var accel := -RECOIL_STIFFNESS * _recoil_offset - RECOIL_DAMPING * _recoil_velocity
		_recoil_velocity += accel * step
		_recoil_offset += _recoil_velocity * step
		remaining -= step
	if _recoil_offset.length() > 1.0:
		_recoil_offset = _recoil_offset.normalized() * 1.0


func _step_bob(delta: float) -> void:
	if walk_intensity <= 0.0 or _in_vr_hand:
		_bob_offset = Vector3.ZERO
		return
	_bob_phase += delta * BOB_FREQ
	var amount: float = BOB_AMP * walk_intensity
	_bob_offset = Vector3(
		sin(_bob_phase) * amount,
		absf(sin(_bob_phase * 2.0)) * amount * 0.65,
		0.0
	)


func _step_reload(delta: float) -> void:
	if not _reload_active:
		_reload_offset = Vector3.ZERO
		_reload_rotation = Vector3.ZERO
		return
	_reload_elapsed += delta
	var t: float = clampf(_reload_elapsed / _reload_duration, 0.0, 1.0)
	var curve: float = sin(t * PI)
	_reload_offset = Vector3(curve * 0.05, -curve * RELOAD_SWING, curve * 0.06)
	_reload_rotation = Vector3(curve * 32.0, curve * 10.0, curve * 20.0)
	_reload_t = t
	var phase: String = _phase_for(t)
	if phase != _reload_phase:
		_reload_phase = phase
		_reload_phases.append(phase)
		_enter_reload_phase(phase)
	if t >= 1.0:
		_reload_active = false
		_reload_phase = ""
		_reload_offset = Vector3.ZERO
		_reload_rotation = Vector3.ZERO
		_slide_locked = false


func _step_switch(delta: float) -> void:
	if not _switch_active:
		_switch_offset = Vector3.ZERO
		_switch_rotation = Vector3.ZERO
		if is_instance_valid(_model_holder):
			_model_holder.visible = true
		return
	_switch_elapsed += delta
	var t: float = clampf(_switch_elapsed / SWITCH_DURATION, 0.0, 1.0)
	var curve: float = sin(t * PI)
	_switch_offset = Vector3(0.0, -curve * 0.22, 0.0)
	_switch_rotation = Vector3(curve * 10.0, 0.0, curve * 24.0)
	if is_instance_valid(_model_holder):
		_model_holder.visible = curve < 0.85
	if t >= 1.0:
		_switch_active = false
		_switch_offset = Vector3.ZERO
		_switch_rotation = Vector3.ZERO
		_model_holder.visible = true


func _step_pump(delta: float) -> void:
	if not _pump_active:
		_pump_offset = Vector3.ZERO
		_pump_rotation = Vector3.ZERO
		return
	_pump_elapsed += delta
	var t: float = clampf(_pump_elapsed / PUMP_DURATION, 0.0, 1.0)
	var curve: float = sin(t * PI)
	_pump_offset = Vector3(0.0, 0.0, curve * 0.09)
	_pump_rotation = Vector3(curve * 8.0, 0.0, 0.0)
	if t >= 1.0:
		_pump_active = false
		_pump_offset = Vector3.ZERO
		_pump_rotation = Vector3.ZERO


func _step_empty(delta: float) -> void:
	if not _empty_active:
		_empty_offset = Vector3.ZERO
		_empty_rotation = Vector3.ZERO
		return
	_empty_elapsed += delta
	var t: float = clampf(_empty_elapsed / EMPTY_DURATION, 0.0, 1.0)
	var curve: float = sin(t * PI)
	_empty_offset = Vector3(0.0, -curve * 0.03, curve * 0.02)
	_empty_rotation = Vector3(-curve * 4.0, 0.0, 0.0)
	if t >= 1.0:
		_empty_active = false
		_empty_offset = Vector3.ZERO
		_empty_rotation = Vector3.ZERO


func _apply_transforms() -> void:
	if not is_instance_valid(_motion) or not is_instance_valid(_rig):
		return
	_motion.position = _recoil_offset
	_rig.position = _base_pos + _bob_offset + _reload_offset + _pump_offset + _switch_offset + _empty_offset
	_rig.rotation_degrees = _reload_rotation + _pump_rotation + _switch_rotation + _empty_rotation


func _start_fire_stroke() -> void:
	if _parts == null:
		return
	var role := ""
	if _parts.has_role("slide"):
		role = "slide"
	elif _parts.has_role("bolt"):
		role = "bolt"
	elif _parts.has_role("pump"):
		role = "pump"
	if role.is_empty():
		return
	_fire_stroke_role = role
	_fire_stroke = 0.0


func _phase_for(t: float) -> String:
	if t < 0.20:
		return "drop_mag"
	if t < 0.58:
		return "insert_mag"
	if t < 0.74:
		return "seat_mag"
	return "charge"


func _enter_reload_phase(phase: String) -> void:
	if phase == "drop_mag":
		if _current_id == "shotgun" or _mag_dropped or _parts == null:
			return
		var magazine: Node3D = _parts.node("magazine")
		if magazine == null or not is_instance_valid(magazine):
			return
		var visual: MeshInstance3D = _first_mesh(magazine)
		if visual == null or visual.mesh == null:
			return
		MuzzleFxScript.drop_magazine(self, magazine.global_transform, visual.mesh, _first_material(visual))
		_mag_dropped = true
		magazine.visible = false
	elif phase == "insert_mag":
		if _parts != null:
			var magazine: Node3D = _parts.node("magazine")
			if magazine != null and is_instance_valid(magazine):
				magazine.visible = true
	elif phase == "charge":
		_slide_locked = false


func _step_parts(delta: float) -> void:
	if _parts == null:
		return
	for role in _parts.roles:
		var pivot: Node3D = _parts.node(str(role))
		if pivot != null and is_instance_valid(pivot) and _parts.homes.has(role):
			pivot.position = _parts.homes[role]

	if _slide_locked and _parts.has_role("slide"):
		_add_part_offset("slide", Vector3(-PART_STROKE, 0.0, 0.0))

	if _fire_stroke >= 0.0:
		_fire_stroke += delta
		var t: float = clampf(_fire_stroke / FIRE_STROKE_DURATION, 0.0, 1.0)
		var curve: float = sin(t * PI)
		_add_part_offset(_fire_stroke_role, Vector3(-PART_STROKE * curve, 0.0, 0.0))
		if _fire_stroke_role == "bolt":
			_add_part_offset("charging_handle", Vector3(-PART_STROKE * curve, 0.0, 0.0))
		if t >= 1.0:
			_fire_stroke = -1.0

	if _pump_active and _parts.has_role("pump"):
		var t: float = clampf(_pump_elapsed / PUMP_DURATION, 0.0, 1.0)
		_add_part_offset("pump", Vector3(-PUMP_STROKE * sin(t * PI), 0.0, 0.0))
		if t >= 0.45 and not _pump_sfx_fired:
			_pump_sfx_fired = true
			_play_pump_sfx(0)

	if not _reload_active:
		return
	match _reload_phase:
		"insert_mag":
			var t: float = clampf((_reload_t - 0.20) / 0.38, 0.0, 1.0)
			var eased: float = 1.0 - (1.0 - t) * (1.0 - t)
			_add_part_offset("magazine", Vector3(0.0, -MAG_INSERT_DROP * (1.0 - eased), 0.0))
			if _current_id == "shotgun":
				var shells: int = mini(int(floor(t * 3.0)), 2)
				if shells != _pump_sfx_index:
					_pump_sfx_index = shells
					_play_pump_sfx(shells)
				var cycle: float = fmod(t * 3.0, 1.0)
				_add_part_offset("pump", Vector3(-PUMP_STROKE * sin(cycle * PI), 0.0, 0.0))
		"seat_mag":
			var t: float = clampf((_reload_t - 0.58) / 0.16, 0.0, 1.0)
			_add_part_offset("magazine", Vector3(0.0, 0.025 * sin(t * PI), 0.0))
		"charge":
			var t: float = clampf((_reload_t - 0.74) / 0.26, 0.0, 1.0)
			if _parts.has_role("slide"):
				_add_part_offset("slide", Vector3(-PART_STROKE * (1.0 - t), 0.0, 0.0))
			var curve: float = sin(t * PI)
			_add_part_offset("bolt", Vector3(-PART_STROKE * curve, 0.0, 0.0))
			_add_part_offset("charging_handle", Vector3(-PART_STROKE * curve, 0.0, 0.0))
			if _current_id == "shotgun":
				_add_part_offset("pump", Vector3(-PUMP_STROKE * curve, 0.0, 0.0))


func _add_part_offset(role: String, offset: Vector3) -> void:
	if _parts == null or not _parts.has_role(role):
		return
	var pivot: Node3D = _parts.node(role)
	if pivot == null or not is_instance_valid(pivot):
		return
	pivot.position += offset


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: MeshInstance3D = _first_mesh(child)
		if found != null:
			return found
	return null


func _first_material(mi: MeshInstance3D) -> Material:
	if mi.material_override != null:
		return mi.material_override
	if mi.mesh == null:
		return null
	for surface in range(mi.mesh.get_surface_count()):
		var material: Material = mi.mesh.surface_get_material(surface)
		if material != null:
			return material
	return null


func _play_pump_sfx(index: int) -> void:
	if not RecordedSfx.has_sample("shotgun", "pump"):
		return
	var host: Node = get_parent() if get_parent() != null else self
	RecordedSfx.play("shotgun", "pump", host, global_position)
