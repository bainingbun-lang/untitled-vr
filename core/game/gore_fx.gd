class_name GoreFx
extends RefCounted

const MAX_DECALS := 64
const MAX_ACTIVE := 32
const MAX_PUDDLES := 16
const MAX_PARTS := 12
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
static var _forced_gore = null


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
	while _active.size() > MAX_ACTIVE:
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
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = clampf(size, 0.1, 1.5)
	cylinder.bottom_radius = cylinder.top_radius
	cylinder.height = 0.012
	cylinder.radial_segments = 12
	cylinder.rings = 1
	puddle_node.mesh = cylinder
	puddle_node.material_override = _get_puddle_material()
	var up := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	puddle_node.position = pos + up * 0.006
	parent.add_child(puddle_node)
	_puddles.append(puddle_node)
	while _puddles.size() > MAX_PUDDLES:
		_retire(_puddles.pop_front())
	return puddle_node


static func dismember(parent: Node, pos: Vector3, size: float, zone: String = "", count: int = 3) -> Array:
	var created: Array = []
	if not gore_enabled() or parent == null:
		return created
	var pieces: int = clampi(count, 1, 4)
	var scale := clampf(size, 0.2, 3.0)
	for i in range(pieces):
		if _parts.size() >= MAX_PARTS:
			_retire(_parts.pop_front())
		var body := RigidBody3D.new()
		body.name = "GorePart_%s" % (zone if not zone.is_empty() else str(i))
		body.mass = clampf(scale * 1.5, 0.4, 4.0)
		body.position = pos + Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.3), randf_range(-0.2, 0.2)) * scale
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.16, 0.24, 0.16) * scale
		shape.shape = box
		body.add_child(shape)
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box.size
		visual.mesh = mesh
		visual.material_override = _get_part_material()
		body.add_child(visual)
		parent.add_child(body)
		var outward := Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.0), randf_range(-1.0, 1.0)).normalized()
		body.apply_impulse(outward * (1.5 + randf() * 2.0), Vector3(0.0, 0.1 * scale, 0.0))
		_parts.append(body)
		created.append(body)
		if _parts.size() > MAX_PARTS:
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


static func _add_decal(parent: Node, pos: Vector3, normal: Vector3, size: float) -> void:
	if not gore_enabled() or parent == null:
		return
	var decal := MeshInstance3D.new()
	decal.name = "GoreDecal"
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	decal.mesh = plane
	decal.material_override = _get_decal_material()
	var direction := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	decal.quaternion = Quaternion(Vector3.UP, direction)
	decal.position = pos + direction * 0.01
	parent.add_child(decal)
	_decals.append(decal)
	while _decals.size() > MAX_DECALS:
		_retire(_decals.pop_front())


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
		material.albedo_color = Color(0.32, 0.01, 0.01, 1.0)
		material.roughness = 1.0
		_decal_material = material
	return _decal_material


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
