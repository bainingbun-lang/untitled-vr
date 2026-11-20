class_name MuzzleFx
extends Node3D

const MAX_CASINGS := 24
const MAX_FLASHES := 8
const MAX_FLASH_LIGHTS := 8
const MAX_SMOKE := 6
const CASING_LIFE := 2.5
const FLASH_LIFE := 0.12
const SMOKE_LIFE := 0.45

static var _casing_pool: Array = []
static var _casing_active: Array = []
static var _flash_lights: Array = []
static var _flashes: Array = []
static var _smoke: Array = []
static var _mat_flash = null
static var _mat_smoke = null
static var _mat_casing = null
static var _mesh_flash = null
static var _mesh_smoke = null
static var _mesh_casing = null
static var _last_auto_frame := -1

var casing_parent: Node = null


func _process(delta: float) -> void:
	var frame := Engine.get_process_frames()
	if frame != _last_auto_frame:
		_last_auto_frame = frame
		advance(delta)


func fire(scale: float = 1.0, forward_local: Vector3 = Vector3.FORWARD) -> void:
	var dir_local := forward_local.normalized() if forward_local.length_squared() > 0.0001 else Vector3.FORWARD
	spawn_flash(self, Vector3.ZERO, dir_local, scale)
	spawn_smoke(self, Vector3.ZERO, dir_local, scale)
	var world_dir: Vector3 = (global_transform.basis * dir_local).normalized()
	eject_casing(_resolve_casing_parent(), global_position, world_dir)


static func advance(delta: float) -> void:
	var dt: float = maxf(delta, 0.0)
	for node in _flash_lights:
		_retire(node)
	_flash_lights.clear()
	_step_group(_flashes, dt)
	_step_group(_smoke, dt)
	for casing in _casing_active.duplicate():
		var life: float = float(casing.get_meta("life", 0.0)) - dt
		casing.set_meta("life", life)
		if life <= 0.0:
			if casing is RigidBody3D:
				(casing as RigidBody3D).linear_velocity = Vector3.ZERO
				(casing as RigidBody3D).angular_velocity = Vector3.ZERO
				(casing as RigidBody3D).sleeping = true
			casing.hide()
			_casing_active.erase(casing)


static func spawn_flash(parent: Node, pos: Vector3, direction: Vector3, scale: float = 1.0) -> void:
	if parent == null:
		return
	var power: float = clampf(scale, 0.2, 3.0)
	var anchor := Node3D.new()
	anchor.name = "MuzzleFlash"
	anchor.position = pos
	parent.add_child(anchor)
	var light := OmniLight3D.new()
	light.name = "FlashLight"
	light.light_color = Color(1.0, 0.78, 0.36)
	light.light_energy = 7.0 * power
	light.omni_range = 2.4 * power
	light.shadow_enabled = false
	anchor.add_child(light)
	_flash_lights.append(light)
	while _flash_lights.size() > MAX_FLASH_LIGHTS:
		_retire(_flash_lights.pop_front())
	var particles := CPUParticles3D.new()
	particles.name = "FlashSparks"
	particles.amount = 8
	particles.lifetime = FLASH_LIFE
	particles.one_shot = true
	particles.emitting = true
	particles.direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	particles.spread = 20.0
	particles.initial_velocity_min = 0.3 * power
	particles.initial_velocity_max = 1.4 * power
	particles.scale_amount_min = 0.015 * power
	particles.scale_amount_max = 0.055 * power
	particles.gravity = Vector3.ZERO
	particles.mesh = _get_flash_mesh()
	particles.material_override = _get_flash_material()
	anchor.add_child(particles)
	anchor.set_meta("life", FLASH_LIFE)
	_flashes.append(anchor)
	while _flashes.size() > MAX_FLASHES:
		_retire(_flashes.pop_front())


static func spawn_smoke(parent: Node, pos: Vector3, direction: Vector3, scale: float = 1.0) -> void:
	if parent == null:
		return
	var power: float = clampf(scale, 0.2, 3.0)
	var anchor := Node3D.new()
	anchor.name = "MuzzleSmoke"
	anchor.position = pos
	parent.add_child(anchor)
	var drift: Vector3 = Vector3.UP * 0.7
	if direction.length_squared() > 0.0001:
		drift += direction.normalized() * 0.3
	var particles := CPUParticles3D.new()
	particles.name = "SmokePuff"
	particles.amount = 6
	particles.lifetime = SMOKE_LIFE
	particles.one_shot = true
	particles.emitting = true
	particles.direction = drift.normalized()
	particles.spread = 32.0
	particles.initial_velocity_min = 0.12
	particles.initial_velocity_max = 0.45
	particles.scale_amount_min = 0.02 * power
	particles.scale_amount_max = 0.07 * power
	particles.gravity = Vector3(0.0, 0.25, 0.0)
	particles.mesh = _get_smoke_mesh()
	particles.material_override = _get_smoke_material()
	anchor.add_child(particles)
	anchor.set_meta("life", SMOKE_LIFE)
	_smoke.append(anchor)
	while _smoke.size() > MAX_SMOKE:
		_retire(_smoke.pop_front())


static func eject_casing(parent: Node, world_pos: Vector3, world_dir: Vector3) -> RigidBody3D:
	if parent == null:
		return null
	var casing: RigidBody3D
	if _casing_pool.size() < MAX_CASINGS:
		casing = _make_casing()
		_casing_pool.append(casing)
	else:
		casing = _casing_pool.pop_front() as RigidBody3D
		_casing_pool.append(casing)
	if casing.get_parent() != parent:
		var previous := casing.get_parent()
		if previous != null:
			previous.remove_child(casing)
		parent.add_child(casing)
	var side: Vector3 = world_dir.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	casing.global_position = world_pos
	casing.global_rotation = Vector3(side.z * 0.4, randf() * TAU, side.x * 0.4)
	casing.show()
	casing.linear_velocity = side * randf_range(1.1, 2.1) + Vector3.UP * randf_range(1.0, 2.0) - world_dir * 0.25
	casing.angular_velocity = Vector3(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0), randf_range(-14.0, 14.0))
	casing.sleeping = false
	casing.set_meta("life", CASING_LIFE)
	if not _casing_active.has(casing):
		_casing_active.append(casing)
	return casing


static func casing_count() -> int:
	return _casing_pool.size()


static func active_casing_count() -> int:
	return _casing_active.size()


static func flash_count() -> int:
	return _flashes.size()


static func flash_light_count() -> int:
	return _flash_lights.size()


static func smoke_count() -> int:
	return _smoke.size()


static func casing_at(index: int) -> RigidBody3D:
	if index < 0 or index >= _casing_pool.size():
		return null
	return _casing_pool[index] as RigidBody3D


static func clear() -> void:
	for node in _flash_lights:
		_retire(node)
	_flash_lights.clear()
	for node in _flashes:
		_retire(node)
	_flashes.clear()
	for node in _smoke:
		_retire(node)
	_smoke.clear()
	for casing in _casing_active:
		casing.hide()
		if casing is RigidBody3D:
			(casing as RigidBody3D).linear_velocity = Vector3.ZERO
			(casing as RigidBody3D).angular_velocity = Vector3.ZERO
			(casing as RigidBody3D).sleeping = true
	_casing_active.clear()


static func shutdown() -> void:
	for node in _flash_lights:
		_free_now(node)
	_flash_lights.clear()
	for node in _flashes:
		_free_now(node)
	_flashes.clear()
	for node in _smoke:
		_free_now(node)
	_smoke.clear()
	for casing in _casing_pool:
		_free_now(casing)
	_casing_pool.clear()
	_casing_active.clear()
	_mat_flash = null
	_mat_smoke = null
	_mat_casing = null
	_mesh_flash = null
	_mesh_smoke = null
	_mesh_casing = null


func _resolve_casing_parent() -> Node:
	if is_instance_valid(casing_parent):
		return casing_parent
	if get_tree() != null and is_instance_valid(get_tree().current_scene):
		return get_tree().current_scene
	return self


static func _step_group(group: Array, delta: float) -> void:
	for node in group.duplicate():
		var life: float = float(node.get_meta("life", 0.0)) - delta
		node.set_meta("life", life)
		if life <= 0.0:
			_retire(node)
			group.erase(node)


static func _make_casing() -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "MuzzleCasing"
	body.mass = 0.008
	body.gravity_scale = 0.85
	body.linear_damp = 0.05
	body.angular_damp = 0.12
	body.collision_layer = 0
	body.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.008, 0.008, 0.02)
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	visual.name = "Brass"
	visual.mesh = _get_casing_mesh()
	visual.material_override = _get_casing_material()
	body.add_child(visual)
	body.hide()
	return body


static func _get_flash_material() -> Material:
	if _mat_flash == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.82, 0.38)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.68, 0.2)
		material.emission_energy_multiplier = 3.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_mat_flash = material
	return _mat_flash


static func _get_smoke_material() -> Material:
	if _mat_smoke == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.62, 0.62, 0.60, 0.42)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_mat_smoke = material
	return _mat_smoke


static func _get_casing_material() -> Material:
	if _mat_casing == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.82, 0.62, 0.18)
		material.metallic = 0.85
		material.roughness = 0.3
		_mat_casing = material
	return _mat_casing


static func _get_flash_mesh() -> Mesh:
	if _mesh_flash == null:
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		_mesh_flash = quad
	return _mesh_flash


static func _get_smoke_mesh() -> Mesh:
	if _mesh_smoke == null:
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		_mesh_smoke = quad
	return _mesh_smoke


static func _get_casing_mesh() -> Mesh:
	if _mesh_casing == null:
		var box := BoxMesh.new()
		box.size = Vector3(0.008, 0.008, 0.02)
		_mesh_casing = box
	return _mesh_casing


static func _retire(node) -> void:
	if is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
		(node as Node).queue_free()


static func _free_now(node) -> void:
	if is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
		(node as Node).free()
