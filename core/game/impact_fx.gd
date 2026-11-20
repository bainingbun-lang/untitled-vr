class_name ImpactFx
extends RefCounted

const MAX_ACTIVE := 24
const MAX_DECALS := 40

const GoreFxScript = preload("res://core/game/gore_fx.gd")
const SurfaceScript = preload("res://core/game/surface_material.gd")

static var _active: Array = []
static var _decals: Array = []
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _decal_texture = null


static func spawn(parent: Node, surface_type: int, pos: Vector3, normal: Vector3, strength: float = 1.0, direction: Vector3 = Vector3.ZERO) -> void:
	if parent == null:
		return
	var surface := surface_type if SurfaceScript.DEFS.has(surface_type) else SurfaceScript.Type.CONCRETE
	var effect := SurfaceScript.effect(surface)
	var outward := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var flow := direction if direction.length_squared() > 0.0001 else outward
	flow = flow.normalized()
	var power := clampf(strength, 0.0, 200.0)
	var tint: Color = SurfaceScript.color(surface)
	match effect:
		"blood":
			GoreFxScript.blood_hit(parent, pos, flow, power, flow, power > 40.0)
			if GoreFxScript.gore_enabled():
				_add_hole(parent, pos, outward, 0.18 + power * 0.003, Color(0.32, 0.01, 0.01))
		"sparks":
			_emit(parent, pos, flow, Color(1.0, 0.72, 0.18), 12, 4.5 + power * 0.06, 28.0, 0.035, 9.0, true, false)
			_add_hole(parent, pos, outward, 0.12 + power * 0.002, Color(0.12, 0.10, 0.09))
		"splinters":
			_emit(parent, pos, outward, tint, 10, 3.0 + power * 0.04, 42.0, 0.05, 6.0, false, true)
			_add_hole(parent, pos, outward, 0.16 + power * 0.003, Color(0.16, 0.09, 0.04))
		"shards":
			_emit(parent, pos, outward, tint, 10, 4.0 + power * 0.04, 50.0, 0.04, 7.0, false, true)
			_add_hole(parent, pos, outward, 0.18 + power * 0.003, Color(0.30, 0.40, 0.45))
		"splash":
			_emit(parent, pos, outward, tint, 16, 3.0 + power * 0.05, 35.0, 0.05, 5.0, false, false)
			GoreFxScript.puddle(parent, pos, Vector3.UP, 0.12 + power * 0.004)
		_:
			_emit(parent, pos, outward, tint, 12, 2.4 + power * 0.03, 55.0, 0.07, 1.5, false, false)
			_add_hole(parent, pos, outward, 0.16 + power * 0.004, Color(0.22, 0.21, 0.19))


static func active_count() -> int:
	return _active.size()


static func decal_count() -> int:
	return _decals.size()


static func clear() -> void:
	for node in _active:
		_retire(node)
	for node in _decals:
		_retire(node)
	_active.clear()
	_decals.clear()


static func shutdown() -> void:
	for node in _active:
		_free_now(node)
	for node in _decals:
		_free_now(node)
	_active.clear()
	_decals.clear()
	_materials.clear()
	_meshes.clear()
	_decal_texture = null


static func _emit(parent: Node, pos: Vector3, direction: Vector3, color: Color, count: int, speed: float, spread: float, size: float, gravity: float, emissive: bool, box_mesh: bool) -> void:
	var anchor := Node3D.new()
	anchor.name = "ImpactFx"
	anchor.position = pos
	parent.add_child(anchor)
	var particles := CPUParticles3D.new()
	particles.amount = clampi(count, 2, 24)
	particles.lifetime = 0.35
	particles.one_shot = true
	particles.emitting = true
	particles.direction = direction.normalized()
	particles.spread = clampf(spread, 0.0, 180.0)
	particles.initial_velocity_min = maxf(speed, 0.0) * 0.35
	particles.initial_velocity_max = maxf(speed, 0.0)
	particles.gravity = Vector3(0.0, -absf(gravity), 0.0)
	particles.scale_amount_min = clampf(size / 0.07, 0.4, 1.0)
	particles.scale_amount_max = clampf(size / 0.045, 0.6, 1.4)
	particles.mesh = _get_mesh(box_mesh)
	particles.material_override = _get_material(color, emissive, false)
	anchor.add_child(particles)
	_active.append(anchor)
	while _active.size() > MAX_ACTIVE:
		_retire(_active.pop_front())


static func _add_hole(parent: Node, pos: Vector3, normal: Vector3, size: float, color: Color) -> void:
	var decal := MeshInstance3D.new()
	decal.name = "ImpactHole"
	var plane := PlaneMesh.new()
	var extent := clampf(size, 0.04, 0.35)
	plane.size = Vector2(extent, extent)
	decal.mesh = plane
	decal.material_override = _get_material(color, false, true)
	var outward := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.FORWARD
	decal.quaternion = Quaternion(Vector3.UP, outward)
	decal.position = pos + outward * 0.012
	parent.add_child(decal)
	_decals.append(decal)
	while _decals.size() > MAX_DECALS:
		_retire(_decals.pop_front())


static func _get_material(color: Color, emissive: bool, decal: bool) -> Material:
	var key := "%s_%s_%s" % [color.to_html(false), str(emissive), str(decal)]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	if decal:
		material.albedo_color = Color(color.r, color.g, color.b, 0.78)
		material.albedo_texture = _get_decal_texture()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	else:
		material.albedo_color = color
		material.roughness = 0.75
		if emissive:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 1.8
	_materials[key] = material
	return material


static func _get_mesh(box_mesh: bool) -> Mesh:
	var key := "box" if box_mesh else "sphere"
	if _meshes.has(key):
		return _meshes[key]
	var mesh: Mesh
	if box_mesh:
		var box := BoxMesh.new()
		box.size = Vector3(0.07, 0.07, 0.07)
		mesh = box
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.04
		sphere.height = 0.08
		sphere.radial_segments = 6
		sphere.rings = 3
		mesh = sphere
	_meshes[key] = mesh
	return mesh


static func _get_decal_texture() -> Texture2D:
	if _decal_texture == null:
		var gradient := Gradient.new()
		gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.add_point(0.55, Color(1.0, 1.0, 1.0, 0.85))
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


static func _retire(node) -> void:
	if is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
		(node as Node).queue_free()


static func _free_now(node) -> void:
	if is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
		(node as Node).free()
