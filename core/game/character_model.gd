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
}

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


func play(anim_name: String, loop: bool = true) -> bool:
	if animation_player == null or _ragdolled:
		return false
	var target := str(_anim_map.get(anim_name, anim_name))
	if target.is_empty() or not animation_player.has_animation(StringName(target)):
		return false
	if animation_player.has_method("set_animation_loop"):
		animation_player.call("set_animation_loop", StringName(target), loop)
	animation_player.play(StringName(target))
	_current_anim = anim_name
	return true


func stop() -> void:
	if animation_player != null:
		animation_player.stop()
	_current_anim = ""


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
	for logical in LOGICAL_ANIMS:
		_anim_map[logical] = _resolve_animation(String(logical))


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
	for logical in LOGICAL_ANIMS:
		var real := str((mapping as Dictionary).get(logical, ""))
		if real.is_empty() or not available.has(real):
			real = _resolve_animation(String(logical))
		_anim_map[logical] = real


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
