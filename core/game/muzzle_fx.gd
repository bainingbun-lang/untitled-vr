class_name MuzzleFx
extends Node3D

# Adapted from Godot-FPS-Template (https://github.com/AxelReviron/Godot-FPS-Template)
# Original: muzzle flash/smoke effects in WeaponController.gd, ShootingWeaponState.gd
# Adapted from GodotFPS-Template (https://github.com/bukkbeek/GodotFPS-Template)
# Original: common/weapon/weapon.gd (fire effects, casing ejection)
# Adapted from GodotWeapons (https://github.com/JarLowrey/GodotWeapons)
# Original: weapon.gd (muzzle effects patterns)
# License: MIT (c) 2026 Axel Reviron, 2026 bukkbeek, 2017 James Lowrey - see third_party/GODOT_FPS_TEMPLATE_LICENSE.txt, third_party/GODOTFPS_TEMPLATE_LICENSE.txt, third_party/GODOTWEAPONS_LICENSE.txt

const MAX_CASINGS := 24
const MAX_FLASHES := 8
const MAX_FLASH_LIGHTS := 8
const MAX_SMOKE := 6
const MAX_DROPPED_MAGS := 4
const CASING_LIFE := 3.0
const FLASH_LIFE := 0.12
const SMOKE_LIFE := 0.15
const DROPPED_MAG_LIFE := 3.0
const SPRITE_RES := 128

static var _casing_pool: Array = []
static var _casing_active: Array = []
static var _mag_pool: Array = []
static var _mag_active: Array = []
static var _flash_lights: Array = []
static var _flashes: Array = []
static var _smoke: Array = []
static var _mat_flash = null
static var _mat_smoke = null
static var _mat_casing = null
static var _tex_flash = null
static var _tex_smoke = null
static var _mesh_casing = null
static var _last_auto_frame := -1

var casing_parent: Node = null


func _process(delta: float) -> void:
	var frame := Engine.get_process_frames()
	if frame != _last_auto_frame:
		_last_auto_frame = frame
		advance(delta)


func fire(scale: float = 1.0, forward_local: Vector3 = Vector3.FORWARD, eject_local: Vector3 = Vector3.ZERO) -> void:
	var dir_local := forward_local.normalized() if forward_local.length_squared() > 0.0001 else Vector3.FORWARD
	spawn_flash(self, Vector3.ZERO, dir_local, scale)
	spawn_smoke(self, Vector3.ZERO, dir_local, scale)
	var world_dir: Vector3 = (global_transform.basis * dir_local).normalized()
	var port: Vector3 = global_transform * eject_local
	eject_casing(_resolve_casing_parent(), port, world_dir)


func fire_with_mode(scale: float = 1.0, forward_local: Vector3 = Vector3.FORWARD, eject_local: Vector3 = Vector3.ZERO, fire_mode: String = "semi", fire_rate: float = 6.0) -> void:
	var dir_local := forward_local.normalized() if forward_local.length_squared() > 0.0001 else Vector3.FORWARD
	var flash_life := FLASH_LIFE
	if fire_mode == "auto":
		flash_life *= 0.7
	elif fire_mode == "burst":
		flash_life *= 0.85
	spawn_flash(self, Vector3.ZERO, dir_local, scale, flash_life)
	spawn_smoke(self, Vector3.ZERO, dir_local, scale)
	var world_dir: Vector3 = (global_transform.basis * dir_local).normalized()
	var port: Vector3 = global_transform * eject_local
	eject_casing(_resolve_casing_parent(), port, world_dir)


static func advance(delta: float) -> void:
	var dt: float = maxf(delta, 0.0)
	for node in _flash_lights:
		if is_instance_valid(node):
			_retire(node)
	_flash_lights.clear()
	_step_group(_flashes, dt)
	_step_group(_smoke, dt)
	for casing in _casing_active.duplicate():
		if not is_instance_valid(casing):
			_casing_active.erase(casing)
			continue
		var life: float = float(casing.get_meta("life", 0.0)) - dt
		casing.set_meta("life", life)
		if life <= 0.0:
			_park_body(casing as RigidBody3D)
			casing.hide()
			_casing_active.erase(casing)
	for mag in _mag_active.duplicate():
		if not is_instance_valid(mag):
			_mag_active.erase(mag)
			continue
		var life: float = float(mag.get_meta("life", 0.0)) - dt
		mag.set_meta("life", life)
		if life <= 0.0:
			_park_body(mag as RigidBody3D)
			mag.hide()
			_mag_active.erase(mag)


static func spawn_flash(parent: Node, pos: Vector3, direction: Vector3, scale: float = 1.0, flash_life: float = FLASH_LIFE) -> void:
	if parent == null:
		return
	var power: float = clampf(scale, 0.2, 3.0)
	var anchor := Node3D.new()
	anchor.name = "MuzzleFlash"
	anchor.position = pos
	parent.add_child(anchor)
	var light := OmniLight3D.new()
	light.name = "FlashLight"
	light.light_color = Color(1.0, 0.85, 0.4)
	light.light_energy = 12.0 * power
	light.omni_range = 3.5 * power
	light.shadow_enabled = false
	anchor.add_child(light)
	_flash_lights.append(light)
	while _flash_lights.size() > MAX_FLASH_LIGHTS:
		_retire(_flash_lights.pop_front())
	var sprite := Sprite3D.new()
	sprite.name = "FlashSprite"
	sprite.centered = true
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture = _get_flash_texture()
	sprite.material_override = _get_flash_material()
	sprite.pixel_size = clampf(0.22 * power, 0.12, 0.35) / float(SPRITE_RES)
	anchor.add_child(sprite)
	anchor.set_meta("life", flash_life)
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
	drift = drift.normalized()
	for i in range(4):
		var sprite := Sprite3D.new()
		sprite.name = "SmokePuff%d" % i
		sprite.centered = true
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture = _get_smoke_texture()
		sprite.material_override = _get_smoke_material()
		sprite.pixel_size = clampf((0.12 + 0.03 * float(i)) * power, 0.08, 0.25) / float(SPRITE_RES)
		sprite.position = drift * (0.04 * float(i) * power)
		anchor.add_child(sprite)
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
	casing.linear_velocity = side * randf_range(1.5, 2.8) + Vector3.UP * randf_range(1.2, 2.5) - world_dir * 0.3
	casing.angular_velocity = Vector3(randf_range(-18.0, 18.0), randf_range(-12.0, 12.0), randf_range(-18.0, 18.0))
	casing.sleeping = false
	casing.set_meta("life", CASING_LIFE)
	if not _casing_active.has(casing):
		_casing_active.append(casing)
	return casing


static func drop_magazine(parent: Node, world_transform: Transform3D, mesh: Mesh, material: Material = null) -> RigidBody3D:
	if parent == null or mesh == null:
		return null
	var mag: RigidBody3D
	if _mag_pool.size() < MAX_DROPPED_MAGS:
		mag = _make_dropped_mag(mesh, material)
		_mag_pool.append(mag)
	else:
		mag = _mag_pool.pop_front() as RigidBody3D
		_mag_pool.append(mag)
	var visual: MeshInstance3D = mag.get_node_or_null("MagazineMesh") as MeshInstance3D
	if visual != null:
		visual.mesh = mesh
		visual.material_override = material
	var shape: BoxShape3D = mag.get_node_or_null("MagazineShape").shape as BoxShape3D
	if shape != null:
		var box: AABB = mesh.get_aabb()
		shape.size = Vector3(maxf(box.size.x, 0.002), maxf(box.size.y, 0.004), maxf(box.size.z, 0.004))
	if mag.get_parent() != parent:
		var previous := mag.get_parent()
		if previous != null:
			previous.remove_child(mag)
		parent.add_child(mag)
	mag.global_transform = world_transform
	mag.show()
	mag.linear_velocity = Vector3(0.25, -1.3, 0.35)
	mag.angular_velocity = Vector3(3.5, 2.0, 1.5)
	mag.sleeping = false
	mag.set_meta("life", DROPPED_MAG_LIFE)
	if not _mag_active.has(mag):
		_mag_active.append(mag)
	return mag


static func active_casing_at(index: int) -> RigidBody3D:
	if index < 0 or index >= _casing_active.size():
		return null
	return _casing_active[index] as RigidBody3D


static func dropped_magazine_count() -> int:
	return _mag_pool.size()


static func active_dropped_magazine_count() -> int:
	return _mag_active.size()


static func dropped_magazine_at(index: int) -> RigidBody3D:
	if index < 0 or index >= _mag_pool.size():
		return null
	return _mag_pool[index] as RigidBody3D


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
		if is_instance_valid(node):
			_retire(node)
	_flash_lights.clear()
	for node in _flashes:
		if is_instance_valid(node):
			_retire(node)
	_flashes.clear()
	for node in _smoke:
		if is_instance_valid(node):
			_retire(node)
	_smoke.clear()
	for casing in _casing_active:
		if is_instance_valid(casing):
			_park_body(casing as RigidBody3D)
			casing.hide()
	_casing_active.clear()
	for mag in _mag_active:
		if is_instance_valid(mag):
			_park_body(mag as RigidBody3D)
			mag.hide()
	_mag_active.clear()


static func shutdown() -> void:
	for node in _flash_lights:
		if is_instance_valid(node):
			_free_now(node)
	_flash_lights.clear()
	for node in _flashes:
		if is_instance_valid(node):
			_free_now(node)
	_flashes.clear()
	for node in _smoke:
		if is_instance_valid(node):
			_free_now(node)
	_smoke.clear()
	for casing in _casing_pool:
		if is_instance_valid(casing):
			_free_now(casing)
	_casing_pool.clear()
	_casing_active.clear()
	for mag in _mag_pool:
		if is_instance_valid(mag):
			_free_now(mag)
	_mag_pool.clear()
	_mag_active.clear()
	_mat_flash = null
	_mat_smoke = null
	_mat_casing = null
	_tex_flash = null
	_tex_smoke = null
	_mesh_casing = null


func _resolve_casing_parent() -> Node:
	if is_instance_valid(casing_parent):
		return casing_parent
	if get_tree() != null and is_instance_valid(get_tree().current_scene):
		return get_tree().current_scene
	return self


static func _step_group(group: Array, delta: float) -> void:
	for node in group.duplicate():
		if not is_instance_valid(node) or (node as Node).is_queued_for_deletion():
			group.erase(node)
			continue
		var life: float = float(node.get_meta("life", 0.0)) - delta
		node.set_meta("life", life)
		if life <= 0.0:
			_retire(node)
			group.erase(node)


static func _park_body(body: RigidBody3D) -> void:
	if body == null:
		return
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = true


static func _make_dropped_mag(mesh: Mesh, material: Material) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "DroppedMagazine"
	body.mass = 0.02
	body.gravity_scale = 1.0
	body.linear_damp = 0.04
	body.angular_damp = 0.08
	body.collision_layer = 0
	body.collision_mask = 1
	var shape_node := CollisionShape3D.new()
	shape_node.name = "MagazineShape"
	var box := BoxShape3D.new()
	box.size = Vector3(0.01, 0.02, 0.01)
	shape_node.shape = box
	body.add_child(shape_node)
	var visual := MeshInstance3D.new()
	visual.name = "MagazineMesh"
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	body.hide()
	return body


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
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.004
	cylinder.height = 0.02
	shape.shape = cylinder
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
		material.albedo_color = Color(1.0, 0.86, 0.55)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.68, 0.2)
		material.emission_energy_multiplier = 2.5
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		_mat_flash = material
	return _mat_flash


static func _get_smoke_material() -> Material:
	if _mat_smoke == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.72, 0.72, 0.70, 0.42)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_mat_smoke = material
	return _mat_smoke


static func _get_flash_texture() -> Texture2D:
	if _tex_flash == null:
		var gradient := Gradient.new()
		gradient.add_point(0.0, Color(1.0, 0.98, 0.82, 1.0))
		gradient.add_point(0.35, Color(1.0, 0.72, 0.20, 0.85))
		gradient.add_point(1.0, Color(1.0, 0.25, 0.02, 0.0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = SPRITE_RES
		texture.height = SPRITE_RES
		_tex_flash = texture
	return _tex_flash


static func _get_smoke_texture() -> Texture2D:
	if _tex_smoke == null:
		var gradient := Gradient.new()
		gradient.add_point(0.0, Color(0.78, 0.78, 0.75, 0.55))
		gradient.add_point(0.55, Color(0.55, 0.55, 0.53, 0.24))
		gradient.add_point(1.0, Color(0.35, 0.35, 0.34, 0.0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = SPRITE_RES
		texture.height = SPRITE_RES
		_tex_smoke = texture
	return _tex_smoke


static func _get_casing_material() -> Material:
	if _mat_casing == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.82, 0.62, 0.18)
		material.metallic = 0.85
		material.roughness = 0.3
		_mat_casing = material
	return _mat_casing


static func _get_casing_mesh() -> Mesh:
	if _mesh_casing == null:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.0035
		cylinder.bottom_radius = 0.0035
		cylinder.height = 0.02
		cylinder.radial_segments = 8
		cylinder.rings = 1
		_mesh_casing = cylinder
	return _mesh_casing


static func _retire(node) -> void:
	if is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
		(node as Node).queue_free()


static func _free_now(node) -> void:
	if is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
		(node as Node).free()
