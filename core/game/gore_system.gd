class_name GoreSystem
extends RefCounted

const GAME_SESSION_PATH := "res://core/game/game_session.gd"
const VrPerfScript = preload("res://core/vr/vr_performance.gd")
const WoundDecalsScript = preload("res://core/game/wound_decals.gd")

enum GoreLevel { OFF = 0, NORMAL = 1, EXTREME = 2 }

const MAX_DECALS_NORMAL := 96
const MAX_DECALS_EXTREME := 160
const MAX_PUDDLES_NORMAL := 32
const MAX_PUDDLES_EXTREME := 64
const MAX_PARTS_NORMAL := 16
const MAX_PARTS_EXTREME := 32
const MAX_ACTIVE_PARTICLES_NORMAL := 48
const MAX_ACTIVE_PARTICLES_EXTREME := 96
const MAX_SCREEN_SPLATTERS := 4
const MAX_DISTANCE_DECAL := 25.0
const MAX_DISTANCE_PARTICLE := 30.0
const MAX_DISTANCE_PUDDLE := 20.0
const MAX_DISTANCE_PART := 35.0
const DECAL_FADE_TIME := 30.0
const PUDDLE_GROW_TIME := 5.0
const STUMP_BLEED_TIME := 3.0
const BLOOD_DRIP_INTERVAL := 0.15

static var _decal_pool: Array = []
static var _puddle_pool: Array = []
static var _part_pool: Array = []
static var _active_particles: Array = []
static var _screen_splatters: Array = []
static var _stump_bleeds: Array = []
static var _blood_mesh = null
static var _blood_material = null
static var _decal_material = null
static var _puddle_material = null
static var _part_material = null
static var _stump_cap_material = null
static var _decal_texture = null
static var _stump_cap_mesh = null
static var _forced_level = null
static var _gore_level: int = GoreLevel.NORMAL
static var _limits_applied: bool = false
static var _current_profile: Dictionary = {}

static func initialize() -> void:
	apply_gore_level(_gore_level)

static func apply_gore_level(level: int) -> void:
	_gore_level = clampi(level, GoreLevel.OFF, GoreLevel.EXTREME)
	var vr_perf := VrPerfScript.instance()
	if vr_perf and vr_perf.is_built():
		_current_profile = vr_perf.current_profile()
	else:
		_current_profile = {
			"decals": MAX_DECALS_NORMAL,
			"particles": MAX_ACTIVE_PARTICLES_NORMAL * 8,
			"npcs": 12,
		}
	_apply_limits_for_level()

static func _apply_limits_for_level() -> void:
	match _gore_level:
		GoreLevel.OFF:
			WoundDecalsScript.set_limits(0, 0, 0, 0)
		GoreLevel.NORMAL:
			WoundDecalsScript.set_limits(MAX_DECALS_NORMAL, MAX_PUDDLES_NORMAL, MAX_PARTS_NORMAL, MAX_ACTIVE_PARTICLES_NORMAL)
		GoreLevel.EXTREME:
			WoundDecalsScript.set_limits(MAX_DECALS_EXTREME, MAX_PUDDLES_EXTREME, MAX_PARTS_EXTREME, MAX_ACTIVE_PARTICLES_EXTREME)
	_limits_applied = true

static func get_gore_level() -> int:
	if typeof(_forced_level) == TYPE_INT:
		return _forced_level
	if not ClassDB.class_exists("GameSession") and not ResourceLoader.exists(GAME_SESSION_PATH):
		return _gore_level
	if not ResourceLoader.exists(GAME_SESSION_PATH):
		return _gore_level
	var script := load(GAME_SESSION_PATH) as Script
	if script == null:
		return _gore_level
	var value = script.get("gore_enabled")
	if typeof(value) == TYPE_BOOL:
		return GoreLevel.NORMAL if value else GoreLevel.OFF
	var level_val = script.get("gore_level")
	if typeof(level_val) == TYPE_INT:
		return clampi(int(level_val), GoreLevel.OFF, GoreLevel.EXTREME)
	return _gore_level

static func set_gore_level(level) -> void:
	_forced_level = level if typeof(level) == TYPE_INT else null

static func gore_enabled() -> bool:
	return get_gore_level() > GoreLevel.OFF

static func is_extreme() -> bool:
	return get_gore_level() >= GoreLevel.EXTREME

static func get_limits() -> Dictionary:
	return {
		"decals": WoundDecalsScript.get_decal_limit(),
		"puddles": WoundDecalsScript.get_puddle_limit(),
		"parts": WoundDecalsScript.get_part_limit(),
		"active_particles": WoundDecalsScript.get_active_particle_limit(),
	}

static func log_budgets() -> void:
	var limits := get_limits()
	print("[GoreSystem] Budgets: decals=%d, puddles=%d, parts=%d, active_particles=%d, level=%d" %
		[limits["decals"], limits["puddles"], limits["parts"], limits["active_particles"], get_gore_level()])

static func create_bullet_wound(parent: Node, pos: Vector3, normal: Vector3, is_exit: bool = false, zone: String = "") -> Dictionary:
	if not gore_enabled() or parent == null:
		return {}
	var level := get_gore_level()
	if level == GoreLevel.OFF:
		return {}
	var size := 0.12 if not is_exit else 0.22
	var depth_layers := level == GoreLevel.EXTREME ? 3 : 2
	return WoundDecalsScript.create_wound(parent, pos, normal, size, depth_layers, zone)

static func create_directional_splatter(parent: Node, pos: Vector3, direction: Vector3, force: float, surface_normal: Vector3 = Vector3.UP) -> void:
	if not gore_enabled() or parent == null:
		return
	var level := get_gore_level()
	if level == GoreLevel.OFF:
		return
	var cone_angle := 35.0
	var droplet_count := clampi(int(force * 0.8), 6, level == GoreLevel.EXTREME ? 24 : 16)
	var spread := cone_angle * (1.0 - clampf(force / 100.0, 0.0, 0.5))
	WoundDecalsScript.create_splatter(parent, pos, direction, spread, droplet_count, force)

static func create_blood_trail(parent: Node, from_pos: Vector3, to_pos: Vector3) -> void:
	if not gore_enabled() or parent == null:
		return
	WoundDecalsScript.create_trail(parent, from_pos, to_pos)

static func create_puddle(parent: Node, pos: Vector3, normal: Vector3, initial_size: float = 0.3) -> Node3D:
	if not gore_enabled() or parent == null:
		return null
	return WoundDecalsScript.create_puddle(parent, pos, normal, initial_size)

static func dismember_limb(parent: Node, bone_idx: int, skeleton: Skeleton3D, hit_pos: Vector3, hit_normal: Vector3, cut_type: String = "clean") -> Dictionary:
	if not gore_enabled() or parent == null or skeleton == null:
		return {}
	var level := get_gore_level()
	if level == GoreLevel.OFF:
		return {}
	
	var bone_name := String(skeleton.get_bone_name(bone_idx))
	var bone_pos := skeleton.to_global(skeleton.get_bone_global_pose(bone_idx).origin)
	var bone_length := _get_bone_length(skeleton, bone_idx)
	
	var stump_cap := _create_stump_cap(parent, bone_pos, hit_normal, bone_length * 0.5)
	var detached_limb := _create_detached_limb(parent, bone_idx, skeleton, bone_pos, bone_length, hit_normal)
	
	if detached_limb != null:
		var bleed_node := _create_stump_bleed(parent, bone_pos, -hit_normal)
		_stump_bleeds.append({
			"node": bleed_node,
			"timer": STUMP_BLEED_TIME,
			"position": bone_pos,
			"normal": -hit_normal,
		})
	
	var npc_state_changes := _calculate_npc_consequences(bone_name)
	
	return {
		"stump_cap": stump_cap,
		"detached_limb": detached_limb,
		"bone_name": bone_name,
		"bone_idx": bone_idx,
		"npc_changes": npc_state_changes,
		"bleed_node": _stump_bleeds[-1]["node"] if _stump_bleeds.size() > 0 else null,
	}

static func _create_stump_cap(parent: Node, pos: Vector3, normal: Vector3, radius: float) -> MeshInstance3D:
	var cap := MeshInstance3D.new()
	cap.name = "StumpCap"
	var cylinder := CylinderMesh.new()
	cylinder.radius_top = clampf(radius, 0.05, 0.15)
	cylinder.radius_bottom = clampf(radius * 0.8, 0.04, 0.12)
	cylinder.height = 0.04
	cylinder.radial_segments = 12
	cap.mesh = cylinder
	cap.material_override = _get_stump_cap_material()
	cap.global_position = pos + normal * 0.02
	cap.global_rotation = Quaternion(Vector3.UP, normal).get_euler()
	parent.add_child(cap)
	return cap

static func _create_detached_limb(parent: Node, bone_idx: int, skeleton: Skeleton3D, pos: Vector3, length: float, hit_normal: Vector3) -> RigidBody3D:
	var limb := RigidBody3D.new()
	limb.name = "DetachedLimb_%s" % String(skeleton.get_bone_name(bone_idx)).replace(".", "_")
	limb.mass = clampf(length * 2.5, 0.8, 5.0)
	
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = clampf(length * 0.12, 0.05, 0.15)
	capsule.height = clampf(length * 0.7, 0.15, 0.8)
	shape.shape = capsule
	limb.add_child(shape)
	
	var visual := MeshInstance3D.new()
	var limb_mesh := _create_limb_mesh(length)
	visual.mesh = limb_mesh
	visual.material_override = _get_part_material()
	limb.add_child(visual)
	
	var host := parent
	if host == null:
		host = get_tree().root
	host.add_child(limb)
	limb.global_position = pos
	
	var outward := (pos - (parent.global_position if parent is Node3D else Vector3.ZERO)).normalized()
	if outward.length_squared() < 0.0001:
		outward = hit_normal * -1.0
	limb.apply_impulse((outward + Vector3.UP * 0.4).normalized() * (3.0 + randf() * 4.0), pos)
	limb.apply_torque(Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)))
	
	_part_pool.append(limb)
	_enforce_part_limit()
	return limb

static func _create_limb_mesh(length: float) -> Mesh:
	var cs := CSGCylinder3D.new()
	cs.radius = clampf(length * 0.1, 0.04, 0.12)
	cs.height = clampf(length * 0.8, 0.15, 0.7)
	cs.radial_segments = 10
	var mesh := ArrayMesh.new()
	cs.get_meshes()[0].surface_get_arrays(0)
	return cs.get_meshes()[0]

static func _create_stump_bleed(parent: Node, pos: Vector3, normal: Vector3) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = "StumpBleed"
	anchor.global_position = pos
	parent.add_child(anchor)
	
	var particles := CPUParticles3D.new()
	particles.amount = 12
	particles.lifetime = 0.6
	particles.one_shot = false
	particles.emitting = true
	particles.direction = normal
	particles.spread = 15.0
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 2.0
	particles.gravity = Vector3(0.0, -6.0, 0.0)
	particles.scale_amount_min = 0.015
	particles.scale_amount_max = 0.04
	particles.mesh = _get_blood_mesh()
	particles.material_override = _get_blood_material()
	anchor.add_child(particles)
	
	_active_particles.append(anchor)
	_enforce_active_particle_limit()
	return anchor

static func _calculate_npc_consequences(bone_name: String) -> Dictionary:
	var changes := {}
	var name_lower := bone_name.to_lower()
	if name_lower.contains("leg") or name_lower.contains("foot"):
		changes["mobility"] = "crawl"
		changes["speed_multiplier"] = 0.25
	elif name_lower.contains("arm") or name_lower.contains("hand") or name_lower.contains("upperarm"):
		changes["drops_weapon"] = true
		changes["can_aim"] = false
		changes["melee_only"] = true
	return changes

static func add_screen_splatter(intensity: float) -> void:
	if not gore_enabled():
		return
	var level := get_gore_level()
	if level == GoreLevel.OFF:
		return
	var max_splatters := MAX_SCREEN_SPLATTERS
	if _screen_splatters.size() >= max_splatters:
		var old := _screen_splatters.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	
	var splatter := _create_screen_splatter(intensity)
	_screen_splatters.append(splatter)

static func _create_screen_splatter(intensity: float) -> Control:
	var splatter := TextureRect.new()
	splatter.name = "ScreenSplatter"
	splatter.anchors_preset = Control.PRESET_FULL_RECT
	splatter.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	splatter.texture = _generate_splatter_texture(intensity)
	splatter.modulate = Color(1.0, 1.0, 1.0, clampf(0.3 + intensity * 0.5, 0.3, 0.85))
	get_tree().root.add_child(splatter)
	
	var tween := splatter.create_tween()
	tween.tween_property(splatter, "modulate:a", 0.0, 2.0 + intensity * 1.5)
	tween.tween_callback(Callable(self, "_remove_splatter").bind(splatter))
	return splatter

static func _generate_splatter_texture(intensity: float) -> Texture2D:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = (int(intensity * 1000) ^ 0xFEED) & 0x7FFFFFFF
	var drops := clampi(int(5 + intensity * 15), 5, 30)
	for i in range(drops):
		var cx := rng.randi_range(20, 236)
		var cy := rng.randi_range(20, 236)
		var radius := rng.randi_range(3, 12)
		var alpha := rng.randf_range(0.4, 0.9)
		for y in range(max(0, cy - radius), min(255, cy + radius)):
			for x in range(max(0, cx - radius), min(255, cx + radius)):
				var dist := Vector2(x - cx, y - cy).length()
				if dist <= radius:
					var a := alpha * (1.0 - dist / radius)
					var existing := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(existing.r, existing.g, existing.b, max(existing.a, a)))
	var tex := ImageTexture.create_from_image(img)
	return tex

static func _remove_splatter(splatter: Control) -> void:
	if is_instance_valid(splatter):
		_splatters.erase(splatter)
		splatter.queue_free()

static func update(delta: float) -> void:
	if not gore_enabled():
		return
	_update_stump_bleeds(delta)
	_update_puddles(delta)
	_cleanup_distant()

static func _update_stump_bleeds(delta: float) -> void:
	var i := 0
	while i < _stump_bleeds.size():
		var bleed := _stump_bleeds[i]
		bleed["timer"] -= delta
		if bleed["timer"] <= 0.0:
			if is_instance_valid(bleed["node"]):
				bleed["node"].queue_free()
			_stump_bleeds.remove_at(i)
		else:
			i += 1

static func _update_puddles(delta: float) -> void:
	WoundDecalsScript.update_puddles(delta)

static func _cleanup_distant() -> void:
	var camera_pos := Vector3.ZERO
	var viewport := get_viewport()
	if viewport and viewport.get_camera_3d():
		camera_pos = viewport.get_camera_3d().global_position
	
	_cleanup_array_distant(_decal_pool, camera_pos, MAX_DISTANCE_DECAL)
	_cleanup_array_distant(_active_particles, camera_pos, MAX_DISTANCE_PARTICLE)
	_cleanup_array_distant(_puddle_pool, camera_pos, MAX_DISTANCE_PUDDLE)
	_cleanup_array_distant(_part_pool, camera_pos, MAX_DISTANCE_PART)

static func _cleanup_array_distant(arr: Array, camera_pos: Vector3, max_dist: float) -> void:
	if camera_pos == Vector3.ZERO:
		return
	for node in arr:
		if is_instance_valid(node) and node.global_position.distance_to(camera_pos) > max_dist:
			node.queue_free()

static func _enforce_part_limit() -> void:
	var limit := WoundDecalsScript.get_part_limit()
	while _part_pool.size() > limit:
		var old = _part_pool.pop_front()
		if is_instance_valid(old):
			old.queue_free()

static func _enforce_active_particle_limit() -> void:
	var limit := WoundDecalsScript.get_active_particle_limit()
	while _active_particles.size() > limit:
		var old = _active_particles.pop_front()
		if is_instance_valid(old):
			old.queue_free()

static func clear() -> void:
	WoundDecalsScript.clear()
	for node in _active_particles:
		if is_instance_valid(node):
			node.queue_free()
	for node in _stump_bleeds:
		if is_instance_valid(node["node"]):
			node["node"].queue_free()
	for splatter in _screen_splatters:
		if is_instance_valid(splatter):
			splatter.queue_free()
	_active_particles.clear()
	_stump_bleeds.clear()
	_screen_splatters.clear()

static func shutdown() -> void:
	clear()
	_decal_pool.clear()
	_puddle_pool.clear()
	_part_pool.clear()
	_blood_mesh = null
	_blood_material = null
	_decal_material = null
	_puddle_material = null
	_part_material = null
	_stump_cap_material = null
	_decal_texture = null
	_stump_cap_mesh = null

static func _get_blood_mesh() -> Mesh:
	if _blood_mesh == null:
		var mesh := SphereMesh.new()
		mesh.radius = 0.035
		mesh.height = 0.07
		mesh.radial_segments = 6
		mesh.rings = 3
		_blood_mesh = mesh
	return _blood_mesh

static func _get_blood_material() -> Material:
	if _blood_material == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.52, 0.015, 0.015, 1.0)
		material.roughness = 0.88
		material.metallic = 0.02
		_blood_material = material
	return _blood_material

static func _get_stump_cap_material() -> Material:
	if _stump_cap_material == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.65, 0.05, 0.05, 1.0)
		material.roughness = 0.7
		material.metallic = 0.05
		material.subsurface_scattering_enabled = true
		material.subsurface_scattering_strength = 0.3
		_stump_cap_material = material
	return _stump_cap_material

static func _get_part_material() -> Material:
	if _part_material == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.48, 0.04, 0.04, 1.0)
		material.roughness = 0.8
		_part_material = material
	return _part_material

static func _get_bone_length(skeleton: Skeleton3D, bone_idx: int) -> float:
	if skeleton.has_method("get_bone_length"):
		var value := float(skeleton.call("get_bone_length", bone_idx))
		if value > 0.01:
			return value
	var parent_idx := skeleton.get_bone_parent(bone_idx)
	if parent_idx >= 0:
		var pos := skeleton.get_bone_global_pose(bone_idx).origin
		var parent_pos := skeleton.get_bone_global_pose(parent_idx).origin
		return pos.distance_to(parent_pos)
	return 0.25

static func decal_count() -> int:
	return _decal_pool.size()

static func puddle_count() -> int:
	return _puddle_pool.size()

static func part_count() -> int:
	return _part_pool.size()

static func active_particle_count() -> int:
	return _active_particles.size()

static func stump_bleed_count() -> int:
	return _stump_bleeds.size()

static func screen_splatter_count() -> int:
	return _screen_splatters.size()