class_name CharacterModel
extends Node3D

const TARGET_HEIGHT: float = 1.75
const MAX_RAGDOLLS: int = 8
const MAX_WOUNDS: int = 12
const MAX_DETACHED_LIMBS: int = 8
const GAME_SESSION_PATH: String = "res://core/game/game_session.gd"
const V2_MANIFEST_PATH: String = "res://assets/models/characters/v2/manifest.json"
const V2_SCALE_MIN: float = 0.95
const V2_SCALE_MAX: float = 1.05

const SKINS: Dictionary = {
	"civil": "res://assets/models/characters/civil_casual_hoodie.gltf",
	"soldier": "res://assets/models/characters/soldier_swat.gltf",
	"enemy": "res://assets/models/characters/enemy_zombie_basic.gltf",
	"robot": "res://assets/models/characters/robot_blocky.glb",
}

const ALIASES: Dictionary = {
	"civilian": "civil",
	"soldado": "soldier",
	"swat": "soldier",
	"enemigo": "enemy",
	"zombie": "enemy",
}

const LOGICAL_ANIMS: Array = ["idle", "walk", "run", "aim", "shoot", "hit", "die"]

const ANIM_CANDIDATES: Dictionary = {
	"idle": ["Idle", "idle", "Idle_Neutral", "Idle_Gun", "Idlecombat"],
	"walk": ["Walk", "walk", "Walking", "Walk_Forward"],
	"run": ["Run", "run", "Sprint", "Run_Forward", "Run_Shoot"],
	"aim": ["Idle_Gun_Pointing", "Idle_Gun", "Aim", "aim", "Idle_Aim", "Idle_Gun_Shoot"],
	"shoot": ["Gun_Shoot", "Idle_Gun_Shoot", "Shoot", "shoot", "Fire", "Punch_Right", "Punch", "punch"],
	"hit": ["HitRecieve", "HitReact", "Hit", "hit", "HitRecieve_2", "Punch_Left", "Punch", "punch"],
	"die": ["Death", "death", "Die", "die", "Death_1"],
	"crouch": ["Idle", "idle", "Idle_Neutral", "Idle_Gun", "Walk", "walk"],
	"cover": ["Idle_Gun_Pointing", "Idle_Gun", "Idle", "idle", "Idle_Gun_Shoot"],
	"reload": ["Idle_Gun", "Interact", "Idle", "idle", "Idle_Gun_Shoot"],
	"melee": ["Punch_Right", "Punch", "punch", "Kick_Right", "Gun_Shoot"],
	"hit_head": ["HitRecieve_2", "HitReact", "HitRecieve", "Hit", "hit", "Punch_Left", "Punch", "punch"],
	"hit_limb": ["HitRecieve_2", "HitReact", "HitRecieve", "Hit", "hit", "Punch_Left", "Punch", "punch"],
	"zombie_idle": ["Idle", "Idle_Attack", "idle", "Walk", "walk"],
	"zombie_walk": ["Walk", "Run_Arms", "walk", "Run", "run"],
	"zombie_run": ["Run_Arms", "Run", "Run_Attack", "run", "Walk"],
	"zombie_attack": ["Punch", "Idle_Attack", "Run_Attack", "punch", "Gun_Shoot"],
}

const ANIM_BLEND: float = 0.16
const HIT_BLEND: float = 0.07
const SHOOT_BLEND: float = 0.05
const LOOK_YAW_LIMIT_DEG: float = 70.0
const LOOK_PITCH_LIMIT_DEG: float = 35.0
const TORSO_YAW_LIMIT_DEG: float = 28.0
const FOOTSTEP_STRIDE: float = 0.85
const RECORDED_SFX_PATH: String = "res://core/game/recorded_sfx.gd"

const BONE_ALIASES: Dictionary = {
	"head": ["Head"],
	"cabeza": ["Head"],
	"neck": ["Neck"],
	"chest": ["Chest"],
	"torso": ["Chest", "Torso"],
	"abdomen": ["Abdomen"],
	"hips": ["Hips", "Pelvis"],
	"pelvis": ["Hips", "Pelvis"],
	"arm.l": ["UpperArm.L", "LeftArm"],
	"arm.r": ["UpperArm.R", "RightArm"],
	"upperarm.l": ["UpperArm.L", "LeftArm"],
	"upperarm.r": ["UpperArm.R", "RightArm"],
	"lowerarm.l": ["LowerArm.L", "LeftForeArm"],
	"lowerarm.r": ["LowerArm.R", "RightForeArm"],
	"leftarm": ["UpperArm.L", "LeftArm"],
	"rightarm": ["UpperArm.R", "RightArm"],
	"forearm.l": ["LowerArm.L", "LeftForeArm"],
	"forearm.r": ["LowerArm.R", "RightForeArm"],
	"hand.l": ["Wrist.L", "LeftHand"],
	"hand.r": ["Wrist.R", "RightHand"],
	"wrist.l": ["Wrist.L", "LeftHand"],
	"wrist.r": ["Wrist.R", "RightHand"],
	"leg.l": ["UpperLeg.L", "LeftUpLeg"],
	"leg.r": ["UpperLeg.R", "RightUpLeg"],
	"upperleg.l": ["UpperLeg.L", "LeftUpLeg"],
	"upperleg.r": ["UpperLeg.R", "RightUpLeg"],
	"lowerleg.l": ["LowerLeg.L", "LeftLeg"],
	"lowerleg.r": ["LowerLeg.R", "RightLeg"],
	"leftleg": ["UpperLeg.L", "LeftUpLeg"],
	"rightleg": ["UpperLeg.R", "RightUpLeg"],
	"foot.l": ["Foot.L", "LeftFoot"],
	"foot.r": ["Foot.R", "RightFoot"],
}

const RAGDOLL_BONES: Array = [
	"Head", "Chest", "Abdomen", "Hips",
	"UpperArm.L", "LowerArm.L", "UpperArm.R", "LowerArm.R",
	"UpperLeg.L", "LowerLeg.L", "UpperLeg.R", "LowerLeg.R",
	"Foot.L", "Foot.R",
]

static var _ragdolls: Array = []
static var _wound_material: StandardMaterial3D = null
static var _logged_skins: Dictionary = {}
static var _v2_manifest: Dictionary = {}
static var _v2_manifest_loaded: bool = false

signal footstep(side: String)
signal animation_changed(logical: String, real: String)
signal hit_reacted(zone: String, point: Vector3)
signal died(logical: String)

var skin_id: String = ""
var model_root: Node3D = null
var skeleton: Skeleton3D = null
var animation_player: AnimationPlayer = null
var v2_entry: Dictionary = {}

var _visual: Node3D = null
var _bounds: AABB = AABB()
var _height: float = TARGET_HEIGHT
var _anim_map: Dictionary = {}
var _current_anim: String = ""
var _wounds: Array = []
var _limbs: Array = []
var _ragdolled: bool = false
var _variation_scale: float = 1.0
var _variation_tint: Color = Color.WHITE

var auto_drive: bool = true
var look_enabled: bool = false
var look_target: Vector3 = Vector3.ZERO
var aim_enabled: bool = false
var aim_target: Vector3 = Vector3.ZERO

var _state: String = "idle"
var _speed_scale: float = 1.0
var _step_phase: float = 0.0
var _step_side: int = 0
var _recoil: float = 0.0
var _stagger: float = 0.0
var _crouch: float = 0.0
var _zombie: bool = false
var _hit_lock: float = 0.0
var _shoot_lock: float = 0.0
var _death_pending: float = -1.0
var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
var _aim_yaw: float = 0.0
var _head_bone: int = -1
var _torso_bone: int = -1
var _hips_bone: int = -1
var _head_offset: Quaternion = Quaternion.IDENTITY
var _torso_offset: Quaternion = Quaternion.IDENTITY
var _hip_offset: Vector3 = Vector3.ZERO
var _has_prev_pose: bool = false
var _host_connected: int = 0


static func skin_ids() -> Array:
	return SKINS.keys()


static func v2_manifest() -> Dictionary:
	if _v2_manifest_loaded:
		return _v2_manifest
	_v2_manifest_loaded = true
	if not FileAccess.file_exists(V2_MANIFEST_PATH):
		return _v2_manifest
	var file := FileAccess.open(V2_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return _v2_manifest
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		_v2_manifest = parsed
	return _v2_manifest


static func v2_skin_ids() -> Array:
	var models: Dictionary = v2_manifest().get("models", {}) as Dictionary
	if typeof(models) != TYPE_DICTIONARY:
		return []
	return (models as Dictionary).keys()


static func v2_roles() -> Array:
	var roles: Dictionary = v2_manifest().get("roles", {}) as Dictionary
	if typeof(roles) != TYPE_DICTIONARY:
		return []
	return (roles as Dictionary).keys()


static func v2_models(role: String) -> Array:
	var aliases: Dictionary = v2_manifest().get("aliases", {}) as Dictionary
	var key := role
	if typeof(aliases) == TYPE_DICTIONARY:
		key = String((aliases as Dictionary).get(role, role))
	var roles: Dictionary = v2_manifest().get("roles", {}) as Dictionary
	if typeof(roles) != TYPE_DICTIONARY:
		return []
	var ids = (roles as Dictionary).get(key, [])
	if typeof(ids) != TYPE_ARRAY:
		return []
	var models: Dictionary = v2_manifest().get("models", {}) as Dictionary
	if typeof(models) != TYPE_DICTIONARY:
		return []
	var result: Array = []
	for id in (ids as Array):
		if (models as Dictionary).has(id):
			result.append((models as Dictionary)[id])
	return result


static func v2_resolve(role: String, seed: int) -> Dictionary:
	var aliases: Dictionary = v2_manifest().get("aliases", {}) as Dictionary
	var key := role
	if typeof(aliases) == TYPE_DICTIONARY:
		key = String((aliases as Dictionary).get(role, role))
	var candidates := v2_models(key)
	if candidates.is_empty():
		return {}
	var h := _stable_hash("%s:%d" % [key, seed])
	var entry: Dictionary = candidates[h % candidates.size()]
	var f1 := float(h & 0xFF) / 255.0
	var f2 := float((h >> 8) & 0xFF) / 255.0
	var f3 := float((h >> 16) & 0xFF) / 255.0
	var f4 := float((h >> 24) & 0xFF) / 255.0
	var scale := V2_SCALE_MIN + (V2_SCALE_MAX - V2_SCALE_MIN) * f1
	var tint := Color(0.85 + 0.30 * f2, 0.85 + 0.30 * f3, 0.85 + 0.30 * f4, 1.0)
	return {
		"role": key,
		"id": str(entry.get("id", "")),
		"entry": entry,
		"scale": scale,
		"tint": tint,
		"seed": seed,
	}


static func _stable_hash(text: String) -> int:
	var h: int = 2166136261
	for i in range(text.length()):
		h = (h ^ text.unicode_at(i)) & 0xFFFFFFFF
		h = (h * 16777619) & 0xFFFFFFFF
	return h


static func ragdoll_count() -> int:
	_prune_ragdolls()
	return _ragdolls.size()


static func clear_ragdolls() -> void:
	_prune_ragdolls()
	while not _ragdolls.is_empty():
		_dispose_ragdoll(_ragdolls.pop_back())


static func spawn(parent: Node, id: String = "civil", seed: int = -1) -> CharacterModel:
	var model := CharacterModel.new()
	model.name = "CharacterModel_%s" % id
	if parent != null:
		parent.add_child(model)
	if seed >= 0 and not v2_models(id).is_empty():
		model.load_v2(id, seed)
	else:
		model.load_model(id)
	return model


static func spawn_v2(parent: Node, role: String, seed: int = 0) -> CharacterModel:
	return spawn(parent, role, seed)


func _ready() -> void:
	if skin_id.is_empty():
		return
	if model_root == null:
		load_model(skin_id)
	_zombie = str(skin_id).to_lower().contains("zombie") or str(skin_id) == "enemy"
	_connect_host_signals()


func _connect_host_signals() -> void:
	if _host_connected != 0:
		return
	var host := get_parent()
	if host == null or host == get_tree().root:
		return
	_host_connected = 1
	if host.has_signal("fired") and not host.is_connected("fired", Callable(self, "_on_host_fired")):
		host.connect("fired", Callable(self, "_on_host_fired"))
	if host.has_signal("damaged") and not host.is_connected("damaged", Callable(self, "_on_host_damaged")):
		host.connect("damaged", Callable(self, "_on_host_damaged"))
	var damageable: Variant = host.get("damageable")
	if damageable is Node and (damageable as Node).has_signal("damaged"):
		var node := damageable as Node
		if not node.is_connected("damaged", Callable(self, "_on_host_damaged")):
			node.connect("damaged", Callable(self, "_on_host_damaged"))


func _on_host_fired(_result: Dictionary) -> void:
	react_shoot()


func _on_host_damaged(amount: float, point: Vector3, normal: Vector3) -> void:
	var zone := "torso"
	if point.length_squared() > 0.0001:
		var relative := point - global_position
		if relative.y > _height * 0.72:
			zone = "head"
		elif absf(relative.x) > _height * 0.16:
			zone = "limb"
	react_hit(zone, point, normal, amount)


func _process(delta: float) -> void:
	if _death_pending > 0.0:
		_death_pending -= delta
	if not auto_drive or _ragdolled or not is_loaded():
		return
	var host := get_parent()
	if host == null or host == get_tree().root:
		return
	var speed := 0.0
	var velocity_value: Variant = host.get("velocity")
	if velocity_value is Vector3:
		speed = (velocity_value as Vector3).length()
	elif host.get("_moving") == true:
		speed = maxf(speed, 2.4)
	var action := ""
	if host.has_method("current_action"):
		action = str(host.call("current_action"))
	var aiming: bool = action == "attack" or action == "aim" or host.get("has_explicit_aim") == true
	var crouching: bool = action == "cover" or host.get("crouching") == true
	if action == "reload" and _state != "reload" and _hit_lock <= 0.0:
		_switch("reload", ANIM_BLEND)
	if action == "melee" and _state != "melee" and _hit_lock <= 0.0:
		_switch("melee", SHOOT_BLEND)
	update_animation(delta, speed, aiming, crouching, action == "cover")
	var aim_value: Variant = host.get("aim_point")
	var target_value: Variant = host.get("target")
	if aim_value is Vector3 and (host.get("has_explicit_aim") == true or action == "attack"):
		set_look_target(aim_value as Vector3)
	elif target_value is Node3D and is_instance_valid(target_value as Node3D):
		set_look_target((target_value as Node3D).global_position)
	else:
		clear_look_target()


func load_model(id: String, seed: int = -1) -> bool:
	if seed >= 0 and not v2_models(id).is_empty():
		return load_v2(id, seed)
	var key := str(ALIASES.get(id, id))
	if not SKINS.has(key):
		return false
	var path := str(SKINS[key])
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var instance := packed.instantiate()
	if not instance is Node3D:
		return false
	if is_instance_valid(_visual):
		_visual.free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	model_root = instance as Node3D
	_visual.add_child(model_root)
	skin_id = key
	skeleton = _find_skeleton(_visual)
	animation_player = _find_animation_player(_visual)
	_normalize_height()
	_map_animations()
	_log_bones()
	return true


func load_v2(role: String, seed: int = 0) -> bool:
	var resolved := v2_resolve(role, seed)
	if resolved.is_empty():
		return false
	var entry: Dictionary = resolved["entry"]
	var path := str(entry.get("file", ""))
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var instance := packed.instantiate()
	if not instance is Node3D:
		return false
	if is_instance_valid(_visual):
		_visual.free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	model_root = instance as Node3D
	_visual.add_child(model_root)
	skin_id = str(entry.get("id", role))
	v2_entry = entry.duplicate()
	skeleton = _find_skeleton(_visual)
	animation_player = _find_animation_player(_visual)
	_normalize_height()
	_map_animations_v2(entry)
	var tint: Color = resolved["tint"]
	_apply_variation(float(resolved["scale"]), tint)
	_log_bones()
	return true


func v2_model_id() -> String:
	return str(v2_entry.get("id", ""))


func v2_role() -> String:
	return str(v2_entry.get("role", ""))


func variation_scale() -> float:
	return _variation_scale


func variation_tint() -> Color:
	return _variation_tint


func height() -> float:
	return _height


func is_loaded() -> bool:
	return model_root != null


func bone_names() -> Array:
	if skeleton == null:
		return []
	var names: Array = []
	for i in range(skeleton.get_bone_count()):
		names.append(String(skeleton.get_bone_name(i)))
	return names


func resolved_animations() -> Dictionary:
	return _anim_map.duplicate()


func current_animation() -> String:
	return _current_anim


func play(anim_name: String, _loop: bool = true) -> bool:
	if animation_player == null or _ragdolled:
		return false
	if not _switch(anim_name, ANIM_BLEND):
		return false
	return true


func stop() -> void:
	if animation_player != null:
		animation_player.stop()
	_current_anim = ""
	_state = ""


func animation_for(logical: String) -> String:
	return str(_anim_map.get(logical, logical))


func state() -> String:
	return _state


func blend_value() -> float:
	return clampf(_speed_scale, 0.0, 2.0)


func set_zombie(enabled: bool) -> void:
	_zombie = enabled


func is_zombie() -> bool:
	return _zombie


func set_look_target(point: Vector3) -> void:
	look_enabled = true
	look_target = point


func clear_look_target() -> void:
	look_enabled = false


func set_aim_target(point: Vector3) -> void:
	aim_enabled = true
	aim_target = point


func clear_aim_target() -> void:
	aim_enabled = false


func look_yaw() -> float:
	return rad_to_deg(_look_yaw)


func look_pitch() -> float:
	return rad_to_deg(_look_pitch)


func aim_yaw() -> float:
	return rad_to_deg(_aim_yaw)


func update_animation(delta: float, speed: float, p_aiming: bool = false, p_crouching: bool = false, p_covering: bool = false) -> void:
	if not is_loaded() or _ragdolled:
		return
	var speed01 := clampf(absf(speed) / 4.2, 0.0, 1.0)
	var moving: bool = absf(speed) > 0.18
	var desired := "idle"
	if moving:
		desired = "run" if speed01 > 0.62 else "walk"
	if _zombie:
		if moving:
			desired = "zombie_run" if speed01 > 0.55 else "zombie_walk"
		else:
			desired = "zombie_idle"
	if p_aiming and not _zombie:
		desired = "aim"
	if p_crouching and not moving:
		desired = "crouch"
	if p_covering:
		desired = "cover"
	if _hit_lock > 0.0:
		_hit_lock = maxf(0.0, _hit_lock - delta)
		desired = _state if not _state.is_empty() else "hit"
	elif _shoot_lock > 0.0:
		_shoot_lock = maxf(0.0, _shoot_lock - delta)
		desired = _state if not _state.is_empty() else "shoot"
	var target_scale := 1.0
	if moving and not _hit_lock > 0.0 and not _shoot_lock > 0.0:
		target_scale = 0.78 + speed01 * 0.52
	_speed_scale = lerpf(_speed_scale, target_scale, clampf(delta * 10.0, 0.0, 1.0))
	if animation_player != null:
		animation_player.speed_scale = _speed_scale
	if desired != _state:
		_switch(desired, ANIM_BLEND)
	_crouch = lerpf(_crouch, 1.0 if (p_crouching or p_covering) else 0.0, clampf(delta * 9.0, 0.0, 1.0))
	if moving:
		var cadence := 1.0 if desired == "walk" else 1.65
		if _zombie:
			cadence = 0.8
		_step_phase += delta * cadence * maxf(speed01, 0.25) / maxf(FOOTSTEP_STRIDE, 0.1)
		if _step_phase >= 1.0:
			_step_phase = fmod(_step_phase, 1.0)
			_step_side = 1 - _step_side
			_emit_footstep("left" if _step_side == 0 else "right")
	_apply_pose_overlays(delta)


func react_shoot() -> void:
	if _ragdolled:
		return
	if _hit_lock > 0.0:
		return
	_switch("shoot", SHOOT_BLEND)
	_shoot_lock = minf(_anim_length("shoot") * 0.8, 0.3)
	_recoil = 1.0


func react_hit(zone: String, point: Vector3 = Vector3.ZERO, normal: Vector3 = Vector3.FORWARD, amount: float = 25.0) -> void:
	if _ragdolled:
		return
	var z := zone.to_lower()
	var anim := "hit"
	if z.contains("head") or z.contains("cabeza"):
		anim = "hit_head"
		_stagger = 0.95
	elif z.contains("arm") or z.contains("hand") or z.contains("limb") or z.contains("brazo"):
		anim = "hit_limb"
		_stagger = 0.45
	else:
		_stagger = 0.6
	if not _switch(anim, HIT_BLEND):
		_switch("hit", HIT_BLEND)
	_hit_lock = minf(_anim_length(anim) * 0.85, 0.45)
	apply_wound(z if not z.is_empty() else "torso", normal, clampf(0.06 + amount * 0.0025, 0.06, 0.28))
	var world_point := point if point.length_squared() > 0.0001 else global_position + Vector3.UP * (_height * 0.6)
	hit_reacted.emit(z, world_point)


func play_die(zone: String = "", point: Vector3 = Vector3.ZERO) -> bool:
	if _ragdolled:
		return false
	var ok := _switch("die", 0.09)
	_death_pending = _anim_length("die")
	_stagger = 0.0
	_recoil = 0.0
	died.emit(zone)
	return ok


# AnimationPlayer no tiene set_animation_loop: sin esto idle/walk suenan una vez y quedan congelados.
func _set_loop(real: String, loop: bool) -> void:
	if animation_player == null or real.is_empty() or not animation_player.has_animation(StringName(real)):
		return
	animation_player.get_animation(StringName(real)).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE


func _switch(logical: String, blend: float) -> bool:
	if animation_player == null or _ragdolled:
		return false
	var real := animation_for(logical)
	if real.is_empty() or not animation_player.has_animation(StringName(real)):
		return false
	if real == animation_for(_current_anim) and _state == logical:
		return true
	_set_loop(real, logical != "shoot" and logical != "hit" and logical != "die" and logical != "melee")
	animation_player.play(StringName(real), clampf(blend, 0.0, 0.5), 1.0, false)
	_state = logical
	_current_anim = logical
	animation_changed.emit(logical, real)
	return true


func _anim_length(logical: String) -> float:
	if animation_player == null:
		return 0.25
	var real := animation_for(logical)
	if real.is_empty() or not animation_player.has_animation(StringName(real)):
		return 0.25
	var anim := animation_player.get_animation(StringName(real))
	if anim == null:
		return 0.25
	return maxf(anim.length, 0.05)


func _emit_footstep(side: String) -> void:
	footstep.emit(side)
	if not ResourceLoader.exists(RECORDED_SFX_PATH):
		return
	var script := load(RECORDED_SFX_PATH) as Script
	if script == null or not script.has_method("play_bank"):
		return
	var bank := "step_concrete"
	var material_value: Variant = get_parent().get("floor_material") if get_parent() != null else null
	if typeof(material_value) == TYPE_STRING:
		var name := String(material_value).to_lower()
		if name.contains("metal"):
			bank = "step_metal"
		elif name.contains("wood"):
			bank = "step_wood"
		elif name.contains("dirt") or name.contains("sand"):
			bank = "step_dirt"
		elif name.contains("grass"):
			bank = "step_grass"
		elif name.contains("water"):
			bank = "step_water"
	script.call("play_bank", bank, self, global_position, null, "", {"volume_db": -12.0, "max_distance": 14.0})


func _apply_pose_overlays(delta: float) -> void:
	if skeleton == null:
		return
	if _head_bone < 0:
		_head_bone = _find_bone("head")
	if _torso_bone < 0:
		_torso_bone = _find_bone("chest")
		if _torso_bone < 0:
			_torso_bone = _find_bone("torso")
	if _hips_bone < 0:
		_hips_bone = _find_bone("hips")

	_recoil = maxf(0.0, _recoil - delta * 5.5)
	_stagger = maxf(0.0, _stagger - delta * 3.0)

	var wanted_yaw := 0.0
	var wanted_pitch := 0.0
	if look_enabled and _head_bone >= 0:
		var origin := skeleton.to_global(skeleton.get_bone_global_pose(_head_bone).origin)
		var to_target := look_target - origin
		if to_target.length_squared() > 0.0001:
			var forward := -global_transform.basis.z.normalized()
			var flat_to := Vector3(to_target.x, 0.0, to_target.z)
			var flat_forward := Vector3(forward.x, 0.0, forward.z)
			if flat_to.length_squared() > 0.0001 and flat_forward.length_squared() > 0.0001:
				wanted_yaw = atan2(flat_forward.cross(flat_to).y, flat_forward.dot(flat_to))
			wanted_pitch = asin(clampf(to_target.normalized().y, -1.0, 1.0))
	var yaw_limit := deg_to_rad(LOOK_YAW_LIMIT_DEG)
	var pitch_limit := deg_to_rad(LOOK_PITCH_LIMIT_DEG)
	wanted_yaw = clampf(wanted_yaw, -yaw_limit, yaw_limit)
	wanted_pitch = clampf(wanted_pitch, -pitch_limit, pitch_limit)
	_look_yaw = lerpf(_look_yaw, wanted_yaw, clampf(delta * 9.0, 0.0, 1.0))
	_look_pitch = lerpf(_look_pitch, wanted_pitch, clampf(delta * 9.0, 0.0, 1.0))
	var wanted_aim_yaw := clampf(_look_yaw * 0.42, -deg_to_rad(TORSO_YAW_LIMIT_DEG), deg_to_rad(TORSO_YAW_LIMIT_DEG))
	_aim_yaw = lerpf(_aim_yaw, wanted_aim_yaw, clampf(delta * 7.0, 0.0, 1.0))

	var recoil_pitch := -_recoil * 0.09
	var stagger_pitch := _stagger * 0.10
	var wanted_head_offset: Quaternion = Quaternion(Vector3.UP, _look_yaw) * Quaternion(Vector3.RIGHT, _look_pitch + recoil_pitch * 0.5 + stagger_pitch * 0.6)
	var wanted_torso_offset: Quaternion = Quaternion(Vector3.UP, _aim_yaw) * Quaternion(Vector3.RIGHT, recoil_pitch + stagger_pitch)
	var wanted_hip_offset := Vector3(0.0, -0.30 * _crouch, 0.0)

	var base_head: Quaternion = skeleton.get_bone_pose_rotation(_head_bone) if _head_bone >= 0 else Quaternion.IDENTITY
	var base_torso: Quaternion = skeleton.get_bone_pose_rotation(_torso_bone) if _torso_bone >= 0 else Quaternion.IDENTITY
	var base_hip: Vector3 = skeleton.get_bone_pose_position(_hips_bone) if _hips_bone >= 0 else Vector3.ZERO
	if _has_prev_pose:
		base_head = base_head * _head_offset.inverse()
		base_torso = base_torso * _torso_offset.inverse()
		base_hip -= _hip_offset

	_head_offset = wanted_head_offset
	_torso_offset = wanted_torso_offset
	_hip_offset = wanted_hip_offset
	if _head_bone >= 0:
		skeleton.set_bone_pose_rotation(_head_bone, (base_head * _head_offset).normalized())
	if _torso_bone >= 0:
		skeleton.set_bone_pose_rotation(_torso_bone, (base_torso * _torso_offset).normalized())
	if _hips_bone >= 0:
		skeleton.set_bone_pose_position(_hips_bone, base_hip + _hip_offset)
	_has_prev_pose = true


func make_ragdoll(impulse: Vector3, hit_point: Vector3) -> Node3D:
	stop()
	_ragdolled = true
	var wrapper := Node3D.new()
	wrapper.name = "CharacterRagdoll_%s" % skin_id
	var host := get_parent()
	if host == null:
		host = self
	host.add_child(wrapper)
	if host == self:
		wrapper.transform = Transform3D.IDENTITY
	else:
		wrapper.global_transform = global_transform

	var physical: Array = []
	var segments: Array = []
	if skeleton != null and skeleton.get_bone_count() > 0:
		physical = _build_physical_bones()
		wrapper.set_meta("physical_bones", physical)
		if skeleton.has_method("physical_bones_start_simulation"):
			skeleton.call("physical_bones_start_simulation")
	else:
		segments = _build_segment_bodies(wrapper)
		wrapper.set_meta("segments", segments)

	var bodies: Array = physical
	if bodies.is_empty():
		bodies = segments
	var nearest: PhysicsBody3D = null
	var best := INF
	for body in bodies:
		if not is_instance_valid(body):
			continue
		var body_pos: Vector3 = (body as Node3D).global_position
		var distance := body_pos.distance_squared_to(hit_point)
		if distance < best:
			best = distance
			nearest = body as PhysicsBody3D
	if nearest != null:
		nearest.apply_impulse(impulse, (nearest as Node3D).global_position)
		for body in bodies:
			if is_instance_valid(body) and body != nearest:
				(body as PhysicsBody3D).apply_impulse(impulse * 0.06, (body as Node3D).global_position)

	_register_ragdoll(wrapper)
	return wrapper


func apply_wound(bone_name: String, normal: Vector3, size: float) -> Node3D:
	if not _gore_enabled():
		return null
	var direction := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var world_pos := global_position + Vector3.UP * (_height * 0.55)
	var idx := _find_bone(bone_name)
	if idx >= 0 and skeleton != null:
		world_pos = skeleton.to_global(skeleton.get_bone_global_pose(idx).origin)
	var decal := MeshInstance3D.new()
	decal.name = "CharacterWound"
	var plane := PlaneMesh.new()
	plane.size = Vector2(clampf(size, 0.03, 0.6), clampf(size, 0.03, 0.6))
	decal.mesh = plane
	decal.material_override = _get_wound_material()
	add_child(decal)
	decal.global_position = world_pos + direction * 0.012
	decal.global_rotation = Quaternion(Vector3.UP, direction).get_euler()
	_wounds.append(decal)
	while _wounds.size() > MAX_WOUNDS:
		var old = _wounds.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	return decal


func detach_limb(bone_name: String) -> Node3D:
	if not _gore_enabled():
		return null
	var idx := _find_bone(bone_name)
	if idx < 0 or skeleton == null:
		return null
	stop()
	var root_name := String(skeleton.get_bone_name(idx))
	for i in range(skeleton.get_bone_count()):
		if i == idx or _is_bone_descendant(i, idx):
			skeleton.set_bone_pose_scale(i, Vector3(0.001, 0.001, 0.001))
	var center := skeleton.to_global(skeleton.get_bone_global_pose(idx).origin)
	var length := _bone_length(idx)
	var body := RigidBody3D.new()
	body.name = "DetachedLimb_%s" % root_name.replace(".", "_")
	body.mass = 1.25
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.14, maxf(length, 0.18), 0.14)
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var fragment := BoxMesh.new()
	fragment.size = box.size
	visual.mesh = fragment
	visual.material_override = _get_wound_material()
	body.add_child(visual)
	var host := get_parent()
	if host == null:
		host = self
	host.add_child(body)
	body.global_position = center
	var outward := center - global_position
	if outward.length_squared() < 0.0001:
		outward = Vector3.RIGHT
	body.apply_impulse((outward.normalized() + Vector3.UP * 0.35).normalized() * 3.0, center)
	_limbs.append(body)
	while _limbs.size() > MAX_DETACHED_LIMBS:
		var old = _limbs.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	return body


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D and (node as Skeleton3D).get_bone_count() > 0:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer and (node as AnimationPlayer).get_animation_list().size() > 0:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)


func _normalize_height() -> void:
	_bounds = AABB()
	if _visual == null:
		return
	var meshes: Array = []
	_collect_meshes(_visual, meshes)
	var valid := false
	var visual_inv := _visual.global_transform.affine_inverse()
	for mesh in meshes:
		var box: AABB = (mesh as MeshInstance3D).get_aabb()
		if box.size.length_squared() <= 0.0001:
			continue
		var xform := visual_inv * (mesh as Node3D).global_transform
		var local_box := _xform_aabb(xform, box)
		if not valid:
			_bounds = local_box
			valid = true
		else:
			_bounds = _bounds.merge(local_box)
	if not valid:
		_height = TARGET_HEIGHT
		return
	var factor := TARGET_HEIGHT / maxf(_bounds.size.y, 0.01)
	_visual.scale = Vector3(factor, factor, factor)
	_visual.position = Vector3(
		-(_bounds.position.x + _bounds.size.x * 0.5) * factor,
		-_bounds.position.y * factor,
		-(_bounds.position.z + _bounds.size.z * 0.5) * factor
	)
	_height = TARGET_HEIGHT


func _xform_aabb(xform: Transform3D, box: AABB) -> AABB:
	var result := AABB()
	var first := true
	for x in [box.position.x, box.position.x + box.size.x]:
		for y in [box.position.y, box.position.y + box.size.y]:
			for z in [box.position.z, box.position.z + box.size.z]:
				var point: Vector3 = xform * Vector3(x, y, z)
				if first:
					result = AABB(point, Vector3.ZERO)
					first = false
				else:
					result = result.expand(point)
	return result


func _map_animations() -> void:
	_anim_map.clear()
	for logical in ANIM_CANDIDATES.keys():
		_anim_map[String(logical)] = _resolve_animation(String(logical))


func _map_animations_v2(entry: Dictionary) -> void:
	_anim_map.clear()
	if animation_player == null:
		return
	var available: Array = []
	for name in animation_player.get_animation_list():
		available.append(String(name))
	var mapping = entry.get("anim_map", {})
	if typeof(mapping) != TYPE_DICTIONARY:
		mapping = {}
	for logical in ANIM_CANDIDATES.keys():
		var real := str((mapping as Dictionary).get(logical, ""))
		if real.is_empty() or not available.has(real):
			real = _resolve_animation(String(logical))
		_anim_map[String(logical)] = real


func _apply_variation(scale: float, tint: Color) -> void:
	_variation_scale = clampf(scale, V2_SCALE_MIN, V2_SCALE_MAX)
	_visual.scale *= _variation_scale
	_visual.position *= _variation_scale
	_height = TARGET_HEIGHT * _variation_scale
	_variation_tint = tint
	var meshes: Array = []
	_collect_meshes(_visual, meshes)
	for mesh in meshes:
		var instance := mesh as MeshInstance3D
		var mesh_res := instance.mesh
		if mesh_res == null:
			continue
		for surface in range(mesh_res.get_surface_count()):
			var mat = null
			if instance.has_method("get_surface_material"):
				mat = instance.call("get_surface_material", surface)
			if mat == null:
				mat = mesh_res.surface_get_material(surface)
			if mat is StandardMaterial3D:
				var cloned := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				var original := cloned.albedo_color
				cloned.albedo_color = Color(
					original.r * tint.r,
					original.g * tint.g,
					original.b * tint.b,
					original.a
				)
				instance.set_surface_override_material(surface, cloned)


func _resolve_animation(logical: String) -> String:
	if animation_player == null:
		return ""
	var available: Array = []
	for name in animation_player.get_animation_list():
		available.append(String(name))
	if available.is_empty():
		return ""
	for candidate in ANIM_CANDIDATES.get(logical, []):
		if available.has(String(candidate)):
			return String(candidate)
	var keyword := ""
	if logical == "die":
		keyword = "death"
	elif logical == "hit":
		keyword = "hit"
	elif logical == "shoot":
		keyword = "punch"
	elif logical == "aim":
		keyword = "idle"
	for name in available:
		if name.to_lower().contains(keyword):
			return name
	available.sort()
	return available[0]


func _log_bones() -> void:
	if String(_logged_skins.get(skin_id, "")) == "loaded":
		return
	_logged_skins[skin_id] = "loaded"
	var names := bone_names()
	print("[CharacterModel] skin=%s huesos=%d anims=%s" % [skin_id, names.size(), str(_anim_map)])
	var joined := ""
	for name in names:
		if not joined.is_empty():
			joined += ", "
		joined += String(name)
	print("[CharacterModel] huesos %s: %s" % [skin_id, joined])


func _find_bone(bone_name: String) -> int:
	if skeleton == null or bone_name.is_empty():
		return -1
	var needle := _strip_bone_prefix(bone_name.strip_edges())
	var wanted: Array = [needle]
	for extra in BONE_ALIASES.get(needle.to_lower(), []):
		wanted.append(String(extra))
	for i in range(skeleton.get_bone_count()):
		var current := _strip_bone_prefix(String(skeleton.get_bone_name(i)))
		for item in wanted:
			if current == String(item):
				return i
	if needle.length() >= 5:
		for i in range(skeleton.get_bone_count()):
			var current := _strip_bone_prefix(String(skeleton.get_bone_name(i))).to_lower()
			if current.contains(needle.to_lower()):
				return i
	return -1


func _strip_bone_prefix(name: String) -> String:
	var stripped := name.trim_prefix("mixamorig:")
	return stripped.trim_prefix("mixamorig_")


func _is_bone_descendant(candidate: int, ancestor: int) -> bool:
	var current := candidate
	var guard := 0
	while current >= 0 and guard < 128:
		if current == ancestor:
			return true
		current = skeleton.get_bone_parent(current)
		guard += 1
	return false


func _bone_length(idx: int) -> float:
	if skeleton.has_method("get_bone_length"):
		var value := float(skeleton.call("get_bone_length", idx))
		if value > 0.01:
			return value
	return 0.25


func _build_physical_bones() -> Array:
	var bodies: Array = []
	for name in RAGDOLL_BONES:
		var idx := _find_bone(String(name))
		if idx < 0:
			continue
		var bone_name := String(skeleton.get_bone_name(idx))
		var pb := PhysicalBone3D.new()
		pb.name = "PB_%s" % bone_name.replace(".", "_").replace(":", "_")
		pb.bone_name = StringName(bone_name)
		pb.mass = 4.0 if bone_name.to_lower().contains("head") else 2.0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.15, maxf(_bone_length(idx), 0.18), 0.15)
		shape.shape = box
		pb.add_child(shape)
		skeleton.add_child(pb)
		bodies.append(pb)
	return bodies


func _build_segment_bodies(wrapper: Node3D) -> Array:
	var segments: Array = []
	var center := global_position + Vector3.UP * (_height * 0.5)
	var definitions: Array = [
		["Head", Vector3(0.0, 0.75, 0.0), Vector3(0.22, 0.22, 0.22)],
		["Torso", Vector3(0.0, 0.3, 0.0), Vector3(0.36, 0.5, 0.22)],
		["ArmL", Vector3(-0.3, 0.3, 0.0), Vector3(0.14, 0.42, 0.14)],
		["ArmR", Vector3(0.3, 0.3, 0.0), Vector3(0.14, 0.42, 0.14)],
		["LegL", Vector3(-0.12, -0.3, 0.0), Vector3(0.16, 0.55, 0.16)],
		["LegR", Vector3(0.12, -0.3, 0.0), Vector3(0.16, 0.55, 0.16)],
	]
	for entry in definitions:
		var data: Array = entry
		var body := RigidBody3D.new()
		body.name = "RagdollSegment_%s" % String(data[0])
		body.mass = 3.0 if data[0] == "Torso" else 1.5
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = data[2]
		shape.shape = box
		body.add_child(shape)
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box.size
		visual.mesh = mesh
		visual.material_override = _get_wound_material()
		body.add_child(visual)
		wrapper.add_child(body)
		body.global_position = center + data[1] * global_transform.basis.get_scale()
		segments.append(body)
	return segments


func _gore_enabled() -> bool:
	if not ClassDB.class_exists("GameSession") and not ResourceLoader.exists(GAME_SESSION_PATH):
		return true
	if not ResourceLoader.exists(GAME_SESSION_PATH):
		return true
	var script := load(GAME_SESSION_PATH) as Script
	if script == null:
		return true
	var value = script.get("gore_enabled")
	if typeof(value) == TYPE_BOOL:
		return value
	return true


func _get_wound_material() -> StandardMaterial3D:
	if _wound_material == null:
		_wound_material = StandardMaterial3D.new()
		_wound_material.albedo_color = Color(0.42, 0.015, 0.015, 1.0)
		_wound_material.roughness = 0.85
	return _wound_material


static func _register_ragdoll(wrapper: Node3D) -> void:
	_prune_ragdolls()
	_ragdolls.append(wrapper)
	while _ragdolls.size() > MAX_RAGDOLLS:
		_dispose_ragdoll(_ragdolls.pop_front())


static func _prune_ragdolls() -> void:
	var alive: Array = []
	for ragdoll in _ragdolls:
		if is_instance_valid(ragdoll):
			alive.append(ragdoll)
	_ragdolls = alive


static func _dispose_ragdoll(wrapper) -> void:
	if not is_instance_valid(wrapper):
		return
	for body in wrapper.get_meta("physical_bones", []):
		if not is_instance_valid(body):
			continue
		var owner := (body as Node).get_parent() as Skeleton3D
		if owner != null and owner.has_method("physical_bones_stop_simulation"):
			owner.call("physical_bones_stop_simulation")
		(body as Node).queue_free()
	for body in wrapper.get_meta("segments", []):
		if is_instance_valid(body):
			(body as Node).queue_free()
	(wrapper as Node).queue_free()
