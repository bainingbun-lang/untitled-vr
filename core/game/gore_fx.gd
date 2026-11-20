class_name GoreFx
extends RefCounted

const MAX_DECALS := 64
const MAX_ACTIVE := 32
const MAX_PUDDLES := 16
const MAX_PARTS := 12
const GROUND_MASK := 1
const GROUND_PROBE := 6.0
const GAME_SESSION_PATH := "res://core/game/game_session.gd"

static var _decals: Array = []
static var _active: Array = []
static var _puddles: Array = []
static var _parts: Array = []
static var _blood_mesh = null
static var _blood_material = null
static var _decal_material = null
static var _puddle_material = null
static var _part_material = null
static var _decal_texture = null
static var _forced_gore = null
static var limit_decals: int = MAX_DECALS
static var limit_active: int = MAX_ACTIVE
static var limit_puddles: int = MAX_PUDDLES
static var limit_parts: int = MAX_PARTS


static func apply_profile(profile: Dictionary) -> void:
	if profile.has("decals"):
		limit_decals = clampi(int(profile["decals"]), 4, MAX_DECALS)
	if profile.has("particles"):
		limit_active = clampi(int(profile["particles"]) / 8, 2, MAX_ACTIVE)
		limit_puddles = clampi(int(profile["particles"]) / 12, 2, MAX_PUDDLES)
	enforce_limits()


static func enforce_limits() -> void:
	while _decals.size() > limit_decals:
		_retire(_decals.pop_front())
	while _active.size() > limit_active:
		_retire(_active.pop_front())
	while _puddles.size() > limit_puddles:
		_retire(_puddles.pop_front())
	while _parts.size() > limit_parts:
		_retire(_parts.pop_front())


static func gore_enabled() -> bool:
	if typeof(_forced_gore) == TYPE_BOOL:
		return _forced_gore
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


static func set_gore_enabled(value) -> void:
	_forced_gore = value if typeof(value) == TYPE_BOOL else null


static func blood_hit(parent: Node, pos: Vector3, normal: Vector3, amount: float, direction: Vector3 = Vector3.ZERO, jet: bool = false) -> void:
	if not gore_enabled() or parent == null:
		return
	var flow := direction if direction.length_squared() > 0.0001 else normal
	flow = flow.normalized() if flow.length_squared() > 0.0001 else Vector3.UP
	var anchor := Node3D.new()
	anchor.name = "GoreBloodJet" if jet else "GoreBlood"
	anchor.position = pos
	parent.add_child(anchor)

	var particles := CPUParticles3D.new()
	particles.amount = clampi(6 + int(amount * 0.3), 6, 20)
	particles.lifetime = 0.4 if not jet else 0.55
	particles.one_shot = true
	particles.emitting = true
	particles.direction = flow
	particles.spread = 8.0 if jet else 25.0
	particles.initial_velocity_min = 2.0 if jet else 1.0
	particles.initial_velocity_max = 5.0 if jet else 3.5
	particles.gravity = Vector3(0.0, -5.0, 0.0)
	particles.scale_amount_min = 0.02
	particles.scale_amount_max = 0.06
	particles.mesh = _get_blood_mesh()
	particles.material_override = _get_blood_material()
	anchor.add_child(particles)

	_active.append(anchor)
	while _active.size() > limit_active:
		_retire(_active.pop_front())
	_add_decal(parent, pos, flow, clampf(0.12 + amount * 0.004, 0.12, 0.4))


static func on_death(parent: Node, pos: Vector3, size: float) -> void:
	if not gore_enabled() or parent == null:
		return
	var scale := clampf(size, 0.2, 4.0)
	blood_hit(parent, pos + Vector3.UP * 0.1, Vector3.UP, 24.0 * scale)
	_add_decal(parent, pos, Vector3.UP, clampf(0.6 * scale, 0.3, 1.6))
	puddle(parent, pos, Vector3.UP, clampf(0.5 * scale, 0.25, 1.2))


static func puddle(parent: Node, pos: Vector3, normal: Vector3, size: float) -> Node3D:
	if not gore_enabled() or parent == null:
		return null
	var puddle_node := MeshInstance3D.new()
	puddle_node.name = "GorePuddle"
	puddle_node.mesh = _make_irregular_disc(clampf(size, 0.1, 1.2), 11)
	puddle_node.material_override = _get_puddle_material()
	parent.add_child(puddle_node)
	var surface := _ground_hit(parent, pos + Vector3.UP * 0.25)
	var impact_pos: Vector3 = surface.get("position", pos)
	var impact_normal: Vector3 = surface.get("normal", Vector3.UP)
	if surface.is_empty() or impact_normal.y < 0.5:
		impact_pos = pos
		impact_normal = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	puddle_node.global_position = impact_pos + impact_normal * 0.004
	puddle_node.quaternion = Quaternion(Vector3.UP, impact_normal)
	_puddles.append(puddle_node)
	while _puddles.size() > limit_puddles:
		_retire(_puddles.pop_front())
	return puddle_node


static func dismember(parent: Node, pos: Vector3, size: float, zone: String = "", count: int = 3) -> Array:
	var created: Array = []
	if not gore_enabled() or parent == null:
		return created
	var pieces: int = clampi(count, 1, 4)
	var scale := clampf(size, 0.2, 3.0)
	for i in range(pieces):
		if _parts.size() >= limit_parts:
			_retire(_parts.pop_front())
		var body := RigidBody3D.new()
		body.name = "GorePart_%s" % (zone if not zone.is_empty() else str(i))
		body.mass = clampf(scale * 1.5, 0.4, 4.0)
		body.position = pos + Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.3), randf_range(-0.2, 0.2)) * scale
		var shape := CollisionShape3D.new()
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = 0.1 * scale
		shape.shape = sphere_shape
		body.add_child(shape)
		var visual := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.075 * scale
		mesh.height = 0.19 * scale
		mesh.radial_segments = 7
		mesh.rings = 4
		visual.mesh = mesh
		visual.scale = Vector3(randf_range(0.85, 1.2), randf_range(0.85, 1.25), randf_range(0.8, 1.1))
		visual.rotation = Vector3(randf_range(-0.5, 0.5), randf() * TAU, randf_range(-0.5, 0.5))
		visual.material_override = _get_part_material()
		body.add_child(visual)
		parent.add_child(body)
		var outward := Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.0), randf_range(-1.0, 1.0)).normalized()
		body.apply_impulse(outward * (1.5 + randf() * 2.0), Vector3(0.0, 0.1 * scale, 0.0))
		_parts.append(body)
		created.append(body)
		if _parts.size() > limit_parts:
			_retire(_parts.pop_front())
	blood_hit(parent, pos, Vector3.UP, 30.0 * scale, Vector3.UP, true)
	return created


static func decal_count() -> int:
	return _decals.size()


static func active_count() -> int:
	return _active.size()


static func puddle_count() -> int:
	return _puddles.size()


static func dismembered_count() -> int:
	return _parts.size()


static func decal_at(index: int) -> Node:
	if index < 0 or index >= _decals.size():
		return null
	return _decals[index]


static func part_at(index: int) -> Node:
	if index < 0 or index >= _parts.size():
		return null
	return _parts[index]


static func clear() -> void:
	for node in _decals:
		_retire(node)
	for node in _active:
		_retire(node)
	for node in _puddles:
		_retire(node)
	for node in _parts:
		_retire(node)
	_decals.clear()
	_active.clear()
	_puddles.clear()
	_parts.clear()


static func shutdown() -> void:
	for node in _decals:
		_free_now(node)
	for node in _active:
		_free_now(node)
	for node in _puddles:
		_free_now(node)
	for node in _parts:
		_free_now(node)
	_decals.clear()
	_active.clear()
	_puddles.clear()
	_parts.clear()
	_blood_mesh = null
	_blood_material = null
	_decal_material = null
	_puddle_material = null
	_part_material = null
	_decal_texture = null


static func _add_decal(parent: Node, pos: Vector3, normal: Vector3, size: float) -> void:
	if not gore_enabled() or parent == null:
		return
	var decal := MeshInstance3D.new()
	decal.name = "GoreDecal"
	var plane := PlaneMesh.new()
	var extent := clampf(size, 0.08, 0.6)
	plane.size = Vector2(extent, extent)
	decal.mesh = plane
	decal.material_override = _get_decal_material()
	parent.add_child(decal)
	var surface := _ground_hit(parent, pos + Vector3.UP * 0.25)
	var impact_pos: Vector3 = surface.get("position", pos)
	var impact_normal: Vector3 = surface.get("normal", Vector3.UP)
	if surface.is_empty() or impact_normal.y < 0.5:
		impact_pos = pos
		impact_normal = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	decal.global_position = impact_pos + impact_normal * 0.006
	decal.quaternion = Quaternion(Vector3.UP, impact_normal)
	_decals.append(decal)
	while _decals.size() > limit_decals:
		_retire(_decals.pop_front())


static func _ground_hit(parent: Node, from: Vector3) -> Dictionary:
	var world_3d: World3D = parent.get_world_3d() if parent is Node3D else null
	if world_3d == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * GROUND_PROBE)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = GROUND_MASK
	return world_3d.direct_space_state.intersect_ray(query)


static func _make_irregular_disc(radius: float, segments: int) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = (int(radius * 1000.0) ^ 0xB100D) & 0x7FFFFFFF
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	normals.append(Vector3.UP)
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		var offset := radius * rng.randf_range(0.72, 1.05)
		vertices.append(Vector3(cos(angle) * offset, 0.0, sin(angle) * offset))
		normals.append(Vector3.UP)
	for i in range(segments):
		indices.append(0)
		indices.append((i + 1) % segments + 1)
		indices.append(i + 1)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _retire(node) -> void:
	if is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
		(node as Node).queue_free()


static func _free_now(node) -> void:
	if is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
		(node as Node).free()


static func _get_blood_mesh() -> Mesh:
	if _blood_mesh == null:
		var mesh := SphereMesh.new()
		mesh.radius = 0.04
		mesh.height = 0.08
		mesh.radial_segments = 6
		mesh.rings = 3
		_blood_mesh = mesh
	return _blood_mesh


static func _get_blood_material() -> Material:
	if _blood_material == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.55, 0.02, 0.02, 1.0)
		material.roughness = 0.9
		_blood_material = material
	return _blood_material


static func _get_decal_material() -> Material:
	if _decal_material == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.32, 0.01, 0.01, 0.85)
		material.albedo_texture = _get_decal_texture()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 1.0
		_decal_material = material
	return _decal_material


static func _get_decal_texture() -> Texture2D:
	if _decal_texture == null:
		var gradient := Gradient.new()
		gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.add_point(0.6, Color(1.0, 1.0, 1.0, 0.7))
		gradient.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 32
		texture.height = 32
		_decal_texture = texture
	return _decal_texture


static func _get_puddle_material() -> Material:
	if _puddle_material == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.28, 0.01, 0.01, 0.8)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.3
		_puddle_material = material
	return _puddle_material


static func _get_part_material() -> Material:
	if _part_material == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.45, 0.05, 0.05, 1.0)
		material.roughness = 0.85
		_part_material = material
	return _part_material
