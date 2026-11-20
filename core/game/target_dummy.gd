class_name TargetDummy
extends Node3D

signal damaged(amount: float, point: Vector3, normal: Vector3)
signal died
signal respawned

const DAMAGEABLE_SCRIPT: String = "res://core/game/damageable.gd"
const DEFAULT_HEALTH: float = 100.0
const DEFAULT_RESPAWN: float = 5.0
const FLASH_TIME: float = 0.18

@export var respawn_delay: float = DEFAULT_RESPAWN
@export var body_size: float = 0.9

var damageable: Node = null
var body: StaticBody3D = null
var visual: MeshInstance3D = null
var dummy_id: int = -1

var _built := false
var _dead := false
var _timer := 0.0
var _flash := 0.0
var _material: StandardMaterial3D = null
var _base_color := Color(0.72, 0.24, 0.18)


static func spawn(parent: Node3D, position: Vector3, id: int = -1) -> Node3D:
	var script := load("res://core/game/target_dummy.gd") as Script
	if script == null:
		return null
	var dummy := script.new() as Node3D
	if dummy == null:
		return null
	dummy.name = "TargetDummy_%d" % id
	dummy.dummy_id = id
	if parent != null:
		parent.add_child(dummy)
		dummy.global_position = position
	return dummy


func _safe_script(path: String) -> Script:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Script


func _ready() -> void:
	_ensure_built()


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	add_to_group("damageable")

	body = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("hit_zone", "torso")
	add_child(body)

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(body_size, 1.8, body_size)
	shape.shape = box
	shape.position = Vector3(0.0, 0.9, 0.0)
	body.add_child(shape)

	_material = StandardMaterial3D.new()
	_material.albedo_color = _base_color
	_material.roughness = 0.8
	visual = MeshInstance3D.new()
	visual.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = box.size
	visual.mesh = mesh
	visual.material_override = _material
	visual.position = shape.position
	body.add_child(visual)

	var head := MeshInstance3D.new()
	head.name = "HeadVisual"
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	head.mesh = sphere
	head.material_override = _material
	head.position = Vector3(0.0, 1.98, 0.0)
	body.add_child(head)

	var damage_script := _safe_script(DAMAGEABLE_SCRIPT)
	damageable = damage_script.new() if damage_script != null else null
	if damageable == null:
		return
	damageable.name = "Damage"
	damageable.health = DEFAULT_HEALTH
	damageable.max_health = DEFAULT_HEALTH
	add_child(damageable)
	if damageable.has_signal("damaged"):
		damageable.connect("damaged", Callable(self, "_on_damaged"))
	if damageable.has_signal("died"):
		damageable.connect("died", Callable(self, "_on_died"))


func configure(health: float, delay: float = -1.0) -> void:
	_ensure_built()
	if damageable == null:
		return
	var value: float = maxf(health, 1.0)
	damageable.set("max_health", value)
	damageable.call("reset", value)
	if delay >= 0.0:
		respawn_delay = delay
	_dead = false
	_timer = 0.0
	_restore_body()


func apply_damage(amount: float, point: Vector3, normal: Vector3, source: Node = null) -> void:
	_ensure_built()
	if damageable == null or _dead:
		return
	damageable.call("take_damage", amount, point, normal, source)


func take_damage(amount: float, point: Vector3 = Vector3.ZERO, normal: Vector3 = Vector3.UP, source: Node = null) -> void:
	apply_damage(amount, point, normal, source)


func take_zone_damage(zone: String, amount: float, point: Vector3, normal: Vector3, source: Node = null) -> void:
	_ensure_built()
	if damageable == null or _dead:
		return
	if damageable.has_method("take_zone_damage"):
		damageable.call("take_zone_damage", zone, amount, point, normal, source)
	else:
		apply_damage(amount, point, normal, source)


func is_dead() -> bool:
	return _dead


func health() -> float:
	if damageable == null:
		return DEFAULT_HEALTH
	return float(damageable.get("health"))


func respawn() -> void:
	_ensure_built()
	if damageable != null:
		damageable.call("reset")
	_dead = false
	_timer = 0.0
	_flash = 0.0
	_restore_body()
	respawned.emit()


func _head_visual() -> MeshInstance3D:
	if body == null:
		return null
	return body.get_node_or_null("HeadVisual") as MeshInstance3D


func _restore_body() -> void:
	if body != null:
		body.collision_layer = 1
	if visual != null:
		visual.visible = true
	var head_visual := _head_visual()
	if head_visual != null:
		head_visual.visible = true
	if _material != null:
		_material.albedo_color = _base_color


func _on_damaged(amount: float, point: Vector3, normal: Vector3) -> void:
	_flash = FLASH_TIME
	if _material != null:
		_material.albedo_color = Color(1.0, 0.82, 0.35)
	damaged.emit(amount, point, normal)


func _on_died() -> void:
	if _dead:
		return
	_dead = true
	_timer = maxf(respawn_delay, 0.0)
	if body != null:
		body.collision_layer = 0
	if visual != null:
		visual.visible = false
	var head_visual := _head_visual()
	if head_visual != null:
		head_visual.visible = false
	died.emit()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		if _material != null and _flash <= 0.0:
			_material.albedo_color = _base_color
	if not _dead:
		return
	_timer -= delta
	if _timer <= 0.0:
		respawn()
