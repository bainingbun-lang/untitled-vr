class_name WoundDecals
extends RefCounted

const GROUND_MASK := 1
const GROUND_PROBE := 8.0
const MAX_DECAL_AGE := 30.0
const PUDDLE_MAX_SIZE_MULT := 3.0

static var _wound_decals: Array = []
static var _surface_decals: Array = []
static var _puddles: Array = []
static var _trails: Array = []
static var _decal_materials: Dictionary = {}
static var _puddle_material = null
static var _decal_texture = null
static var _limb_trail_material = null

static var _decal_limit: int = 96
static var _puddle_limit: int = 32
static var _part_limit: int = 16
static var _active_particle_limit: int = 48

static func set_limits(decals: int, puddles: int, parts: int, active_particles: int) -> void:
	_decal_limit = maxi(decals, 0)
	_puddle_limit = maxi(puddles, 0)
	_part_limit = maxi(parts, 0)
	_active_particle_limit = maxi(active_particles, 0)
	_enforce_limits()

static func get_decal_limit() -> int:
	return _decal_limit

static func get_puddle_limit() -> int:
	return _puddle_limit

static func get_part_limit() -> int:
	return _part_limit

static func get_active_particle_limit() -> int:
	return _active_particle_limit

static func create_wound(parent: Node, pos: Vector3, normal: Vector3, size: float, layers: int, zone: String = "") -> Dictionary:
	if parent == null or _decal_limit <= 0:
		return {}
	
	var wound := Node3D.new()
	wound.name = "Wound_%s" % (zone if not zone.is_empty() else "generic")
	
	var created_layers := []
	for i in range(layers):
		var layer_decal := MeshInstance3D.new()
		layer_decal.name = "WoundLayer_%d" % i
		var plane := PlaneMesh.new()
		var layer_size := size * (1.0 - float(i) * 0.18)
		layer_size = clampf(layer_size, 0.025, size)
		plane.size = Vector2(layer_size, layer_size)
		layer_decal.mesh = plane
		layer_decal.material_override = _get_decal_material_for_layer(i, layers)
		
		var surface := _raycast_ground(parent, pos + Vector3.UP * 0.3)
		var impact_pos: Vector3 = surface.get("position", pos)
		var impact_normal: Vector3 = surface.get("normal", normal)
		if surface.is_empty() or impact_normal.y < 0.3:
			impact_pos = pos
			impact_normal = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
		
		layer_decal.global_position = impact_pos + impact_normal * (0.004 + float(i) * 0.0015)
		layer_decal.global_rotation = Quaternion(Vector3.UP, impact_normal).get_euler()
		wound.add_child(layer_decal)
		created_layers.append({
			"node": layer_decal,
			"layer": i,
			"size": layer_size,
			"age": 0.0,
		})
	
	parent.add_child(wound)
	
	var wound_data := {
		"root": wound,
		"layers": created_layers,
		"position": pos,
		"normal": normal,
		"zone": zone,
		"age": 0.0,
		"is_character": parent is CharacterBody3D or parent.has_method("take_damage"),
	}
	
	if wound_data["is_character"]:
		_wound_decals.append(wound_data)
	else:
		_surface_decals.append(wound_data)
	
	_enforce_limits()
	return wound_data

static func create_splatter(parent: Node, pos: Vector3, direction: Vector3, spread_deg: float, count: int, force: float) -> void:
	if parent == null or _decal_limit <= 0:
		return
	
	var dir := direction.normalized()
	var ref := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var right := dir.cross(ref).normalized()
	var up := right.cross(dir).normalized()
	var half_angle := deg_to_rad(clampf(spread_deg, 1.0, 80.0) * 0.5)
	
	for i in range(count):
		var angle := randf_range(-half_angle, half_angle)
		var tilt := randf_range(-half_angle * 0.5, half_angle * 0.5)
		var droplet_dir := (dir + right * sin(angle) + up * sin(tilt)).normalized()
		var distance := randf_range(0.5, 3.0 + force * 0.05)
		var ray_from := pos + droplet_dir * 0.1
		var ray_to := ray_from + droplet_dir * distance
		
		var space: PhysicsDirectSpaceState3D = parent.get_world_3d().direct_space_state if parent is Node3D else null
		if space == null:
			continue
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.collision_mask = GROUND_MASK | 2 | 4 | 8
		var hit: Dictionary = space.intersect_ray(query)
		
		if not hit.is_empty():
			var hit_pos: Vector3 = hit.get("position", ray_to)
			var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
			if hit_normal.length_squared() > 0.0001:
				hit_normal = hit_normal.normalized()
			var size := clampf(0.04 + force * 0.0008, 0.04, 0.18)
			_add_surface_decal(parent, hit_pos, hit_normal, size, "splatter")
		else:
			var end_pos := ray_to
			var end_normal := Vector3.UP
			var size := clampf(0.03 + force * 0.0005, 0.03, 0.12)
			_add_surface_decal(parent, end_pos, end_normal, size, "splatter_air")

static func _add_surface_decal(parent: Node, pos: Vector3, normal: Vector3, size: float, decal_type: String) -> void:
	var decal := MeshInstance3D.new()
	decal.name = "SurfaceDecal_%s" % decal_type
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	decal.mesh = plane
	decal.material_override = _get_surface_decal_material(decal_type)
	
	var surface := _raycast_ground(parent, pos + Vector3.UP * 0.3)
	var impact_pos: Vector3 = surface.get("position", pos)
	var impact_normal: Vector3 = surface.get("normal", normal)
	if surface.is_empty() or impact_normal.y < 0.2:
		impact_pos = pos
		impact_normal = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	
	decal.global_position = impact_pos + impact_normal * 0.006
	decal.global_rotation = Quaternion(Vector3.UP, impact_normal).get_euler()
	parent.add_child(decal)
	
	_surface_decals.append({
		"root": decal,
		"position": impact_pos,
		"normal": impact_normal,
		"age": 0.0,
		"type": decal_type,
	})
	_enforce_limits()

static func create_trail(parent: Node, from_pos: Vector3, to_pos: Vector3) -> void:
	if parent == null or _decal_limit <= 0:
		return
	var distance := from_pos.distance_to(to_pos)
	if distance < 0.1:
		return
	var steps := clampi(ceili(distance / 0.15), 1, 8)
	for i in range(steps):
		var t := float(i + 1) / float(steps)
		var pos := from_pos.lerp(to_pos, t)
		var size := clampf(0.05 * (1.0 - t * 0.5), 0.02, 0.08)
		_add_surface_decal(parent, pos, Vector3.UP, size, "trail")

static func create_puddle(parent: Node, pos: Vector3, normal: Vector3, initial_size: float) -> Node3D:
	if parent == null or _puddle_limit <= 0:
		return null
	
	var puddle := MeshInstance3D.new()
	puddle.name = "BloodPuddle"
	var disc := _make_irregular_disc(clampf(initial_size, 0.08, 0.5), 16)
	puddle.mesh = disc
	puddle.material_override = _get_puddle_material()
	
	var surface := _raycast_ground(parent, pos + Vector3.UP * 0.5)
	var impact_pos: Vector3 = surface.get("position", pos)
	var impact_normal: Vector3 = surface.get("normal", normal)
	if surface.is_empty() or impact_normal.y < 0.4:
		impact_pos = pos
		impact_normal = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	
	puddle.global_position = impact_pos + impact_normal * 0.003
	puddle.global_rotation = Quaternion(Vector3.UP, impact_normal).get_euler()
	parent.add_child(puddle)
	
	var puddle_data := {
		"node": puddle,
		"position": impact_pos,
		"normal": impact_normal,
		"size": initial_size,
		"max_size": initial_size * PUDDLE_MAX_SIZE_MULT,
		"age": 0.0,
		"growing": true,
	}
	_puddles.append(puddle_data)
	_enforce_limits()
	return puddle

static func update_puddles(delta: float) -> void:
	if delta <= 0.0 or _puddles.is_empty():
		return
	for puddle in _puddles:
		if not is_instance_valid(puddle["node"]):
			continue
		puddle["age"] += delta
		if puddle["growing"] and puddle["age"] < 5.0:
			var grow_factor: float = 1.0 + (puddle["age"] / 5.0) * (PUDDLE_MAX_SIZE_MULT - 1.0)
			var new_size: float = puddle["size"] * grow_factor
			puddle["node"].scale = Vector3(new_size / puddle["size"], 1.0, new_size / puddle["size"])
		elif puddle["age"] >= 5.0:
			puddle["growing"] = false
		if puddle["age"] > MAX_DECAL_AGE * 1.5:
			puddle["node"].modulate = Color(1.0, 1.0, 1.0, max(0.0, 1.0 - (puddle["age"] - MAX_DECAL_AGE * 1.5) / 10.0))

static func _enforce_limits() -> void:
	while _wound_decals.size() + _surface_decals.size() > _decal_limit:
		var target_arr := _surface_decals if _surface_decals.size() > _wound_decals.size() else _wound_decals
		if target_arr.is_empty():
			break
		var old: Dictionary = target_arr.pop_front()
		if is_instance_valid(old["root"]):
			old["root"].queue_free()
	
	while _puddles.size() > _puddle_limit:
		var old: Dictionary = _puddles.pop_front()
		if is_instance_valid(old["node"]):
			old["node"].queue_free()

static func clear() -> void:
	for wound in _wound_decals:
		if is_instance_valid(wound["root"]):
			wound["root"].queue_free()
	for decal in _surface_decals:
		if is_instance_valid(decal["root"]):
			decal["root"].queue_free()
	for puddle in _puddles:
		if is_instance_valid(puddle["node"]):
			puddle["node"].queue_free()
	for trail in _trails:
		if is_instance_valid(trail):
			trail.queue_free()
	_wound_decals.clear()
	_surface_decals.clear()
	_puddles.clear()
	_trails.clear()

static func shutdown() -> void:
	clear()
	_decal_materials.clear()
	_puddle_material = null
	_decal_texture = null
	_limb_trail_material = null

static func _raycast_ground(parent: Node, from: Vector3) -> Dictionary:
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
	rng.seed = (int(radius * 1000.0) ^ 0xD15C) & 0x7FFFFFFF
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	normals.append(Vector3.UP)
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		var offset := radius * rng.randf_range(0.7, 1.0)
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

static func _get_decal_material_for_layer(layer: int, total_layers: int) -> Material:
	var key := "wound_%d_%d" % [layer, total_layers]
	if _decal_materials.has(key):
		return _decal_materials[key]
	var material := StandardMaterial3D.new()
	var depth_factor := float(layer) / float(max(total_layers - 1, 1))
	var r: float = lerp(0.45, 0.15, depth_factor)
	var g: float = lerp(0.02, 0.005, depth_factor)
	var b: float = lerp(0.02, 0.005, depth_factor)
	var a: float = lerp(0.9, 0.6, depth_factor)
	material.albedo_color = Color(r, g, b, a)
	material.albedo_texture = _get_decal_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.95
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	_decal_materials[key] = material
	return material

static func _get_surface_decal_material(decal_type: String) -> Material:
	var key := "surface_%s" % decal_type
	if _decal_materials.has(key):
		return _decal_materials[key]
	var material := StandardMaterial3D.new()
	match decal_type:
		"splatter", "splatter_air":
			material.albedo_color = Color(0.35, 0.01, 0.01, 0.75)
		"trail":
			material.albedo_color = Color(0.28, 0.008, 0.008, 0.65)
		_:
			material.albedo_color = Color(0.3, 0.01, 0.01, 0.7)
	material.albedo_texture = _get_decal_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	_decal_materials[key] = material
	return material

static func _get_puddle_material() -> Material:
	if _puddle_material == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.22, 0.005, 0.005, 0.85)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.15
		material.metallic = 0.05
		material.specular = 0.8
		_puddle_material = material
	return _puddle_material

static func _get_decal_texture() -> Texture2D:
	if _decal_texture == null:
		var gradient := Gradient.new()
		gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.add_point(0.5, Color(1.0, 1.0, 1.0, 0.65))
		gradient.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_decal_texture = texture
	return _decal_texture

static func wound_count() -> int:
	return _wound_decals.size()

static func surface_decal_count() -> int:
	return _surface_decals.size()

static func puddle_count() -> int:
	return _puddles.size()

static func total_decal_count() -> int:
	return _wound_decals.size() + _surface_decals.size()