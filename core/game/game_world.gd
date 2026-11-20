class_name GameWorld
extends Node3D

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const SESSION_SCRIPT: String = "res://core/game/game_session.gd"
const HOTBAR_SCENE: String = "res://scenes/ui/hotbar.tscn"
const HUD_SCRIPT: String = "res://core/game/game_hud.gd"
const DUMMY_SCRIPT: String = "res://core/game/target_dummy.gd"
const PAUSE_MENU_SCRIPT: String = "res://core/game/pause_menu.gd"
const MapWorldBuilderScript = preload("res://core/maps/map_world_builder.gd")

const DUMMY_COUNT: int = 6

var actor: Node3D = null
var spawn_points: Array = []
var bounds: AABB = AABB()
var world_report: Dictionary = {}
var hud: Control = null
var hotbar: Control = null
var pause_menu: Node = null
var dummies: Array = []
var physics_props: Array = []

var _geometry_root: Node3D = null
var _hud_layer: CanvasLayer = null
var _dummies_root: Node3D = null
var _syncing_hotbar := false


func _ready() -> void:
	var session := _safe_script(SESSION_SCRIPT)
	if session != null and str(session.get("platform")).is_empty() and session.has_method("detect_platform"):
		session.set("platform", session.call("detect_platform"))
	if world_report.is_empty():
		setup(_session_meta())


func setup(meta: Dictionary) -> void:
	_discard(_geometry_root)
	_discard(actor)
	_discard(_hud_layer)
	_discard(_dummies_root)
	_geometry_root = null
	actor = null
	hud = null
	hotbar = null
	pause_menu = null
	_dummies_root = null
	spawn_points = []
	bounds = AABB()
	dummies = []
	physics_props = []

	world_report = MapWorldBuilderScript.build(meta, self)
	var first_point: Vector3 = Vector3.ZERO
	if not bool(world_report.get("ok", false)):
		actor = _create_actor(first_point)
	else:
		spawn_points = (world_report.get("spawn_points", []) as Array).duplicate()
		bounds = world_report.get("bounds", AABB())
		_geometry_root = get_node_or_null("WorldGeometry") as Node3D
		if not spawn_points.is_empty():
			first_point = spawn_points[0]
		actor = _create_actor(first_point)

	_collect_physics_props()
	_spawn_dummies(first_point, meta)
	_setup_hud()
	_setup_hotbar()
	_setup_pause_menu()
	_auto_equip()
	if actor != null and actor.has_signal("menu_pressed"):
		var callable := Callable(self, "_on_menu_pressed")
		if not actor.is_connected("menu_pressed", callable):
			actor.connect("menu_pressed", callable)


func spawn_point_positions() -> Array:
	return spawn_points.duplicate()


func target_dummies() -> Array:
	return dummies.duplicate()


func props() -> Array:
	return physics_props.duplicate()


func _create_actor(spawn: Vector3) -> Node3D:
	if ResourceLoader.exists(PLAYER_SCENE):
		var packed: PackedScene = load(PLAYER_SCENE) as PackedScene
		if packed != null:
			var instance: Node = packed.instantiate()
			if instance is Node3D:
				var player: Node3D = instance
				player.name = "Player"
				add_child(player)
				player.global_position = spawn
				return player
			instance.queue_free()

	var camera := Camera3D.new()
	camera.name = "FallbackCamera"
	camera.position = spawn + Vector3(0.0, 1.6, 4.0)
	add_child(camera)
	camera.look_at(spawn + Vector3(0.0, 1.0, 0.0))
	return camera


func _collect_physics_props() -> void:
	physics_props = []
	for node in get_tree().get_nodes_in_group("physics_props"):
		if node.is_ancestor_of(self) or self.is_ancestor_of(node):
			physics_props.append(node)


func _spawn_dummies(center: Vector3, meta: Dictionary) -> void:
	_dummies_root = Node3D.new()
	_dummies_root.name = "Dummies"
	add_child(_dummies_root)
	var session := _safe_script(SESSION_SCRIPT)
	var fallback_seed: int = int(session.get("seed")) if session != null else 0
	var seed_value: int = int(meta.get("seed", fallback_seed))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5EED
	for i in range(DUMMY_COUNT):
		var angle := TAU * float(i) / float(DUMMY_COUNT) + rng.randf_range(-0.16, 0.16)
		var radius: float = 5.0 + rng.randf_range(0.0, 1.8)
		var point := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		point = _clamp_to_bounds(point, center)
		dummies.append(_create_dummy(point, i))


func _create_dummy(point: Vector3, id: int) -> Node3D:
	var script := _safe_script(DUMMY_SCRIPT)
	var dummy: Node3D
	if script != null:
		dummy = script.new() as Node3D
	if dummy == null:
		dummy = Node3D.new()
	dummy.name = "TargetDummy_%d" % id
	if "dummy_id" in dummy:
		dummy.set("dummy_id", id)
	_dummies_root.add_child(dummy)
	dummy.global_position = point
	return dummy


func _clamp_to_bounds(point: Vector3, fallback_center: Vector3) -> Vector3:
	var result := point
	if bounds.size.x > 0.0 and bounds.size.z > 0.0:
		var inset_x: float = mini(1.5, bounds.size.x * 0.25)
		var inset_z: float = mini(1.5, bounds.size.z * 0.25)
		result.x = clampf(result.x, bounds.position.x + inset_x, bounds.end.x - inset_x)
		result.z = clampf(result.z, bounds.position.z + inset_z, bounds.end.z - inset_z)
	if result.distance_to(fallback_center) < 3.0:
		var direction: Vector3 = result - fallback_center
		if direction.length_squared() < 0.0001:
			direction = Vector3.FORWARD
		result = fallback_center + direction.normalized() * 4.0
	result.y = fallback_center.y
	return result


func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HudLayer"
	_hud_layer.layer = 10
	add_child(_hud_layer)
	var script := _safe_script(HUD_SCRIPT)
	hud = script.new() as Control if script != null else null
	if hud == null:
		hud = Control.new()
	hud.name = "GameHud"
	_hud_layer.add_child(hud)
	hud.setup(actor)


func _setup_hotbar() -> void:
	if not ResourceLoader.exists(HOTBAR_SCENE):
		return
	var packed := load(HOTBAR_SCENE) as PackedScene
	if packed == null:
		return
	var instance := packed.instantiate()
	if not (instance is Control):
		if instance != null:
			instance.queue_free()
		return
	hotbar = instance as Control
	hotbar.name = "Hotbar"
	_hud_layer.add_child(hotbar)
	if hotbar.has_method("setup") and actor != null:
		hotbar.call("setup", actor.get("inventory"), actor.get("item_db"))
	if hotbar.has_signal("selected"):
		var callable := Callable(self, "_on_hotbar_selected")
		if not hotbar.is_connected("selected", callable):
			hotbar.connect("selected", callable)
	if actor != null and actor.has_signal("weapon_changed") and hotbar.has_method("select_id"):
		var to_hotbar := Callable(self, "_on_actor_weapon_changed")
		if not actor.is_connected("weapon_changed", to_hotbar):
			actor.connect("weapon_changed", to_hotbar)
	if hotbar.has_method("select") and hotbar.has_method("weapon_ids"):
		var ids: Array = hotbar.call("weapon_ids")
		if not ids.is_empty():
			hotbar.call("select", 0)


func _setup_pause_menu() -> void:
	if not ResourceLoader.exists(PAUSE_MENU_SCRIPT):
		return
	var script := load(PAUSE_MENU_SCRIPT) as Script
	if script == null:
		return
	var instance = script.new()
	if not (instance is Node):
		return
	pause_menu = instance as Node
	pause_menu.name = "PauseMenu"
	_hud_layer.add_child(pause_menu)
	if pause_menu.has_method("setup"):
		pause_menu.call("setup", self, actor)


func _auto_equip() -> void:
	if actor == null or not actor.has_method("weapon_ids") or not actor.has_method("equip"):
		return
	var ids: Array = actor.call("weapon_ids")
	if not ids.is_empty():
		actor.call("equip", str(ids[0]))


func _on_menu_pressed() -> void:
	if pause_menu == null or not is_instance_valid(pause_menu):
		return
	if pause_menu.has_method("open"):
		pause_menu.call("open")
	elif pause_menu.has_method("show_menu"):
		pause_menu.call("show_menu")
	elif "visible" in pause_menu:
		pause_menu.set("visible", true)


func _on_hotbar_selected(item_id: String) -> void:
	if _syncing_hotbar or actor == null or not actor.has_method("equip"):
		return
	actor.call("equip", item_id)


func _on_actor_weapon_changed(item_id) -> void:
	if hotbar == null or not hotbar.has_method("select_id"):
		return
	_syncing_hotbar = true
	hotbar.call("select_id", str(item_id))
	_syncing_hotbar = false


func _discard(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


func _safe_script(path: String) -> Script:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Script


func _session_meta() -> Dictionary:
	if not ResourceLoader.exists(SESSION_SCRIPT):
		return {}
	var script: Script = load(SESSION_SCRIPT) as Script
	if script == null:
		return {}
	var value: Variant = script.get("map_meta")
	if value is Dictionary:
		return (value as Dictionary).duplicate()
	return {}
