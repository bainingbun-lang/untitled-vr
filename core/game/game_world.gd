class_name GameWorld
extends Node3D

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const SESSION_SCRIPT: String = "res://core/game/game_session.gd"
const HOTBAR_SCENE: String = "res://scenes/ui/hotbar.tscn"
const HUD_SCRIPT: String = "res://core/game/game_hud.gd"
const DUMMY_SCRIPT: String = "res://core/game/target_dummy.gd"
const PAUSE_MENU_SCRIPT: String = "res://core/game/pause_menu.gd"
const CHARACTER_MODEL_PATH: String = "res://core/game/character_model.gd"
const VOICE_SYSTEM_PATH: String = "res://core/game/voice_system.gd"
const GORE_FX_PATH: String = "res://core/game/gore_fx.gd"
const VR_PERFORMANCE_PATH: String = "res://core/vr/vr_performance.gd"
const RemoteLog = preload("res://core/debug/remote_log.gd")
const VR_GAME_MODE_PATH: String = "res://core/vr/vr_game_mode.gd"
const ARMED_NPC_PATH: String = "res://core/game/armed_npc.gd"
const WORLD_SPAWNER_PATH: String = "res://core/game/world_spawner.gd"
const NAVIGATION_PATH: String = "res://core/npc/npc_navigation.gd"
const FACTIONS_PATH: String = "res://core/npc/npc_factions.gd"
const LOD_PATH: String = "res://core/npc/npc_lod.gd"
const GAME_MODE_PATH: String = "res://core/game/game_mode.gd"
const MODE_SURVIVAL_PATH: String = "res://core/game/mode_survival.gd"
const SPAWN_MENU_SCENE: String = "res://scenes/ui/spawn_menu.tscn"
const CharacterModelScript = preload("res://core/game/character_model.gd")
const VoiceSystemScript = preload("res://core/game/voice_system.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const VrPerformanceScript = preload("res://core/vr/vr_performance.gd")
const VrGameModeScript = preload("res://core/vr/vr_game_mode.gd")
const VrDebugPanelScript = preload("res://core/vr/vr_debug_panel.gd")
const MapWorldBuilderScript = preload("res://core/maps/map_world_builder.gd")
const WorldSpawnerScript = preload("res://core/game/world_spawner.gd")
const NPCNavigationScript = preload("res://core/npc/npc_navigation.gd")
const NPCFactionsScript = preload("res://core/npc/npc_factions.gd")
const NPCLODScript = preload("res://core/npc/npc_lod.gd")
const GameModeScript = preload("res://core/game/game_mode.gd")
const VehicleSpawnerScript = preload("res://core/game/vehicle_spawner.gd")
const VrVehicleInputScript = preload("res://core/vr/vr_vehicle_input.gd")
const ArmedNpcScript = preload("res://core/game/armed_npc.gd")

const DUMMY_COUNT: int = 6
const STATIC_DUMMY_COUNT: int = 2
const NAV_CELL_SIZE: float = 1.0
const PLAYER_CLEARANCE: float = 4.5
const SAFE_RADIUS: float = 8.0
const PARKED_VEHICLE_COUNT: int = 4
const PARKED_VEHICLE_IDS: Array = ["sedan", "pickup", "van", "suv"]
const PARKED_VEHICLE_HEIGHT: float = 1.0

var actor: Node3D = null
var spawn_points: Array = []
var bounds: AABB = AABB()
var world_report: Dictionary = {}
var hud: Control = null
var hotbar: Control = null
var pause_menu: Node = null
var dummies: Array = []
var physics_props: Array = []
var npcs: Array = []
var _nav_blocked: Dictionary = {}
var parked_vehicles: Array = []
var spawn_menu: Control = null

var navigation = null
var factions = null
var npc_lod = null
var _npcs_root: Node3D = null
var _npc_voice_mute: int = 0
var _locomotion: Dictionary = {}
var _locomotion_timer: float = 0.0
var _geometry_root: Node3D = null
var _hud_layer: CanvasLayer = null
var _dummies_root: Node3D = null
var _syncing_hotbar := false
var voice: Node = null
var performance: Node = null
var vr_state: Node = null
var vr_active: bool = false
var vr_result: Dictionary = {}
var debug_panel: VrDebugPanelScript = null
var _models: Dictionary = {}
var _skins: Dictionary = {}
var _impacts: Dictionary = {}
var _wired: Dictionary = {}
var _npc_scan_timer := 0.0

var active_game_mode = null
var _game_mode_type: int = 0


func _ready() -> void:
	var session := _safe_script(SESSION_SCRIPT)
	if session != null and str(session.get("platform")).is_empty() and session.has_method("detect_platform"):
		session.set("platform", session.call("detect_platform"))
	if world_report.is_empty():
		setup(_session_meta())


func setup(meta: Dictionary) -> void:
	RemoteLog.crumb("world.setup inicio")
	_discard(_geometry_root)
	_discard(actor)
	_discard(_hud_layer)
	_discard(_dummies_root)
	_discard(spawn_menu)
	_clear_world_vehicles()
	for old_npc in npcs:
		if old_npc != null and is_instance_valid(old_npc):
			ArmedNpc.unregister(old_npc)
	_discard(_npcs_root)
	for key in vr_result.keys():
		var old_node: Variant = vr_result.get(key)
		if old_node is Node:
			_discard(old_node as Node)
	_geometry_root = null
	actor = null
	hud = null
	hotbar = null
	pause_menu = null
	_dummies_root = null
	_npcs_root = null
	spawn_menu = null
	parked_vehicles = []
	vr_state = null
	vr_active = false
	vr_result = {}
	debug_panel = null
	spawn_points = []
	bounds = AABB()
	dummies = []
	physics_props = []
	npcs = []
	navigation = null
	factions = null
	_models.clear()
	_skins.clear()
	_impacts.clear()
	_wired.clear()
	_locomotion.clear()

	RemoteLog.crumb("world: construyendo mapa")
	world_report = MapWorldBuilderScript.build(meta, self)
	RemoteLog.crumb("world: mapa construido ok=%s" % str(world_report.get("ok", false)))
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
	RemoteLog.crumb("world: jugador creado")
	vr_active = actor != null and actor.has_method("is_active") and bool(actor.call("is_active"))
	if vr_active:
		vr_result = VrGameModeScript.setup(self, actor, meta)
		vr_state = vr_result.get("state", null) as Node

	RemoteLog.crumb("world: vr listo, panel depuracion")
	_setup_debug_panel()
	RemoteLog.crumb("world: panel listo")

	_collect_physics_props()
	_setup_performance()
	_setup_voice()
	RemoteLog.crumb("world: navegacion")
	_build_navigation(meta)
	RemoteLog.crumb("world: npcs")
	_spawn_living_npcs(first_point, meta)
	RemoteLog.crumb("world: dianas")
	_spawn_dummies(first_point, meta)
	RemoteLog.crumb("world: vehiculos")
	_park_vehicles(first_point, meta)
	_block_parked_vehicles()
	_connect_player_signals()
	
	var mode_type: int = int(meta.get("game_mode", 0))
	_setup_game_mode(mode_type, first_point, meta)
	
	if not vr_active:
		_setup_hud()
		_setup_hotbar()
		_setup_spawn_menu()
		_setup_pause_menu()
		_auto_equip()
		if actor != null and actor.has_signal("menu_pressed"):
			var callable := Callable(self, "_on_menu_pressed")
			if not actor.is_connected("menu_pressed", callable):
				actor.connect("menu_pressed", callable)
	RemoteLog.crumb("world: conectando objetivos")
	_wire_targets()
	RemoteLog.crumb("world.setup FIN")


func _process(delta: float) -> void:
	ArmedNpcScript.advance_fx(maxf(delta, 0.0))
	_locomotion_timer -= maxf(delta, 0.0)
	if _locomotion_timer <= 0.0:
		_locomotion_timer = 0.2
		_sync_locomotion()
	if vr_state != null and is_instance_valid(vr_state) and vr_state.has_method("tick"):
		vr_state.call("tick", maxf(delta, 0.0))
	if active_game_mode != null and is_instance_valid(active_game_mode) and active_game_mode.has_method("tick"):
		active_game_mode.call("tick", maxf(delta, 0.0))
	if performance != null and is_instance_valid(performance) and performance.has_method("observe_frame"):
		var report: Variant = performance.call("observe_frame", maxf(delta, 0.0) * 1000.0, delta)
		if report is Dictionary and bool((report as Dictionary).get("changed", false)):
			GoreFxScript.apply_profile((report as Dictionary).get("profile", {}))
	_process_debug_panel_vr(delta)
	_npc_scan_timer -= maxf(delta, 0.0)
	if _npc_scan_timer <= 0.0:
		_npc_scan_timer = 0.5
		_wire_existing_npcs()


func spawn_point_positions() -> Array:
	return spawn_points.duplicate()


func target_dummies() -> Array:
	return dummies.duplicate()


func props() -> Array:
	return physics_props.duplicate()


func get_active_game_mode() -> Object:
	return active_game_mode


func get_game_mode_type() -> int:
	return _game_mode_type


func start_game_mode(mode_type: int, meta: Dictionary = {}) -> void:
	var current_meta: Dictionary = meta.duplicate()
	if current_meta.is_empty():
		current_meta = _session_meta()
	if current_meta.is_empty():
		current_meta = {"seed": 4242}
	
	var start_point: Vector3 = Vector3.ZERO
	if actor != null and is_instance_valid(actor):
		start_point = actor.global_position
	elif not spawn_points.is_empty():
		start_point = spawn_points[0]
	
	_setup_game_mode(mode_type, start_point, current_meta)


func _create_actor(spawn: Vector3) -> Node3D:
	var use_vr: bool = _session_platform() == "vr" and VrGameModeScript.xr_available()
	var result := VrGameModeScript.build(self, use_vr)
	if result == null:
		return null
	result.global_position = spawn
	if not use_vr and result is CollisionObject3D:
		result.collision_layer = 0
	if not use_vr and result is Camera3D:
		result.look_at(spawn + Vector3(0.0, 1.0, 0.0))
	return result


func _session_platform() -> String:
	var session := _safe_script(SESSION_SCRIPT)
	if session == null:
		return ""
	var platform: String = str(session.get("platform"))
	if platform.is_empty() and session.has_method("detect_platform"):
		platform = str(session.call("detect_platform"))
		session.set("platform", platform)
	return platform


func _collect_physics_props() -> void:
	physics_props = []
	for node in get_tree().get_nodes_in_group("physics_props"):
		if node.is_ancestor_of(self) or self.is_ancestor_of(node):
			physics_props.append(node)


func _clear_world_vehicles() -> void:
	for vehicle in VehicleSpawnerScript.alive():
		if vehicle != null and is_instance_valid(vehicle) and vehicle.get_parent() == self:
			vehicle.get_parent().remove_child(vehicle)
			vehicle.queue_free()


func vehicles() -> Array:
	var result: Array = []
	for vehicle in VehicleSpawnerScript.alive():
		if vehicle != null and is_instance_valid(vehicle) and vehicle.get_parent() == self:
			result.append(vehicle)
	return result


func parked_vehicle_list() -> Array:
	return parked_vehicles.duplicate()


func _block_parked_vehicles() -> void:
	if navigation == null:
		return
	var width: int = int(navigation.get("width"))
	var height: int = int(navigation.get("height"))
	var npc_cells: Array = []
	for npc in npcs:
		if npc != null and is_instance_valid(npc):
			npc_cells.append(navigation.call("world_to_cell_2d", Vector2(npc.global_position.x, npc.global_position.z), NAV_CELL_SIZE))
	var accepted: Dictionary = {}
	for vehicle in parked_vehicles:
		if not (vehicle is Node3D) or not is_instance_valid(vehicle):
			continue
		var box: AABB = _collision_box(vehicle as Node3D)
		if box.size.x <= 0.0 or box.size.z <= 0.0:
			continue
		var cells: Dictionary = {}
		_mark_blocked(cells, box, bounds.position, width, height, 0.4)
		# la celda de un NPC ya nacido y su entorno no se bloquean: quedaria atrapado
		for cell in npc_cells:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					cells.erase(cell + Vector2i(dx, dy))
		var trial: Dictionary = _nav_blocked.duplicate()
		trial.merge(accepted)
		trial.merge(cells)
		var open_ok: bool = true
		for cell in npc_cells:
			if _free_area(cell, trial, width, height, 60) < 60:
				open_ok = false
				break
		if open_ok:
			accepted.merge(cells)
	_nav_blocked.merge(accepted)
	navigation.call("set_obstacles", accepted.keys())


func _setup_game_mode(mode_type: int, first_point: Vector3, meta: Dictionary) -> void:
	if active_game_mode != null and is_instance_valid(active_game_mode):
		active_game_mode.call("stop")
		_discard(active_game_mode)
		active_game_mode = null
	
	if mode_type == 0:
		_game_mode_type = 0
		return
	
	var seed: int = int(meta.get("seed", 4242))
	
	match mode_type:
		1: # SURVIVAL
			return # M2 en cuarentena: ver ~/untitled-control/m2_partial
		_:
			return
	
	if active_game_mode != null:
		active_game_mode.call("start")


# Celdas libres alcanzables desde start (con tope): detecta bolsas sin salida.
func _free_area(start: Vector2i, blocked: Dictionary, width: int, height: int, cap: int) -> int:
	var seen: Dictionary = {start: true}
	var queue: Array = [start]
	while not queue.is_empty() and seen.size() < cap:
		var cell: Vector2i = queue.pop_back()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + step
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
				continue
			if seen.has(next) or blocked.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return seen.size()


func _park_vehicles(center: Vector3, meta: Dictionary) -> void:
	parked_vehicles = []
	if not bool(world_report.get("ok", false)):
		return
	var candidates: Array = _all_free_points()
	if candidates.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(meta.get("seed", 4242)) ^ 0xC0FFEE
	candidates.shuffle()
	var placed: Array = []
	var wanted: int = mini(PARKED_VEHICLE_COUNT, PARKED_VEHICLE_IDS.size())
	for i in range(wanted):
		var id: String = str(PARKED_VEHICLE_IDS[i])
		var point: Vector3 = Vector3.ZERO
		var found: bool = false
		for candidate in candidates:
			point = candidate
			if point.distance_to(center) < 6.0:
				continue
			if _too_close_planar(point, spawn_points, 3.2):
				continue
			if _too_close_planar(point, physics_props, 2.4):
				continue
			if _too_close_planar(point, dummies, 2.6):
				continue
			if _too_close_planar(point, npcs, 2.6):
				continue
			if _point_blocked(point, 1.8):
				continue
			if _too_close_planar(point, placed, 4.0):
				continue
			found = true
			break
		if not found:
			break
		placed.append(point)
		var yaw: float = rng.randf_range(-PI, PI)
		var xform := Transform3D(Basis(Vector3.UP, yaw), point + Vector3.UP * PARKED_VEHICLE_HEIGHT)
		var vehicle = VehicleSpawnerScript.spawn(id, xform, self)
		if vehicle == null:
			continue
		vehicle.name = "ParkedCar_%d_%s" % [i, id]
		vehicle.set_meta("parked", true)
		parked_vehicles.append(vehicle)
	world_report["parked_vehicles"] = parked_vehicles.size()
	world_report["parked_positions"] = placed.duplicate()


func _all_free_points() -> Array:
	var result: Array = []
	if navigation == null:
		return result
	var width: int = int(navigation.get("width"))
	var height: int = int(navigation.get("height"))
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			if bool(navigation.call("is_blocked", cell)):
				continue
			var point: Vector3 = navigation.call("cell_to_world", cell, NAV_CELL_SIZE, 0.0)
			point.y = 0.0
			result.append(point)
	return result


func _nearest_free_point(target: Vector3, ignore_vehicles: bool = false) -> Vector3:
	var best: Vector3 = target
	var best_distance: float = INF
	for point in _all_free_points():
		if _point_blocked(point, 1.4):
			continue
		if not ignore_vehicles and _too_close_planar(point, vehicles(), 2.2):
			continue
		var distance: float = point.distance_to(target)
		if distance < best_distance:
			best_distance = distance
			best = point
	best.y = target.y
	return best


func _point_blocked(point: Vector3, radius: float) -> bool:
	if _geometry_root != null:
		for body in _geometry_root.find_children("*", "CollisionObject3D", true, false):
			if str((body as Node).name) == "Ground":
				continue
			var box: AABB = _collision_box(body as Node3D)
			if box.size.x <= 0.0 or box.size.z <= 0.0:
				continue
			var pad := Vector3(radius, radius, radius)
			var expanded := AABB(box.position - pad, box.size + pad * 2.0)
			if expanded.has_point(Vector3(point.x, box.get_center().y, point.z)):
				return true
	for prop in physics_props:
		if not (prop is Node3D) or not is_instance_valid(prop):
			continue
		var box: AABB = _collision_box(prop as Node3D)
		if box.size.x <= 0.0 or box.size.z <= 0.0:
			continue
		var pad := Vector3(radius * 0.5, radius, radius * 0.5)
		var expanded := AABB(box.position - pad, box.size + pad * 2.0)
		if expanded.has_point(Vector3(point.x, box.get_center().y, point.z)):
			return true
	return false


func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _too_close_planar(point: Vector3, others: Array, radius: float) -> bool:
	for other in others:
		var other_point: Vector3 = Vector3.ZERO
		if other is Vector3:
			other_point = other
		elif other is Node3D and is_instance_valid(other):
			other_point = (other as Node3D).global_position
		else:
			continue
		if _planar_distance(point, other_point) < radius:
			return true
	return false


func spawn_vehicle_in_front(vehicle_id: String, distance: float = 4.0) -> Node3D:
	var origin: Vector3 = Vector3.ZERO
	var forward: Vector3 = Vector3.FORWARD
	if actor != null and is_instance_valid(actor):
		origin = actor.global_position
		var camera: Node3D = null
		var xr_camera: Variant = actor.get("xr_camera")
		if xr_camera is Node3D:
			camera = xr_camera as Node3D
		elif actor is Camera3D:
			camera = actor as Node3D
		if camera != null:
			forward = -camera.global_transform.basis.z
		else:
			forward = -actor.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var target: Vector3 = origin + forward * maxf(distance, 1.0)
	target.y = 0.0
	var point: Vector3 = _nearest_free_point(target)
	var yaw: float = atan2(forward.x, forward.z)
	var xform := Transform3D(Basis(Vector3.UP, yaw), point + Vector3.UP * PARKED_VEHICLE_HEIGHT)
	var vehicle = VehicleSpawnerScript.spawn(vehicle_id, xform, self)
	if vehicle != null:
		vehicle.set_meta("spawned_by_menu", true)
		world_report["menu_spawns"] = int(world_report.get("menu_spawns", 0)) + 1
	return vehicle


func _setup_spawn_menu() -> void:
	if not ResourceLoader.exists(SPAWN_MENU_SCENE) or _hud_layer == null:
		return
	var packed := load(SPAWN_MENU_SCENE) as PackedScene
	if packed == null:
		return
	var instance := packed.instantiate()
	if not (instance is Control):
		if instance != null:
			instance.free()
		return
	spawn_menu = instance as Control
	spawn_menu.name = "SpawnMenu"
	_hud_layer.add_child(spawn_menu)
	spawn_menu.visible = false
	if spawn_menu.has_signal("spawn_requested"):
		_connect_once(spawn_menu, "spawn_requested", Callable(self, "_on_spawn_requested"))
	if spawn_menu.has_signal("closed"):
		_connect_once(spawn_menu, "closed", Callable(self, "close_spawn_menu"))


func open_spawn_menu() -> void:
	if spawn_menu != null and is_instance_valid(spawn_menu):
		spawn_menu.visible = true


func close_spawn_menu() -> void:
	if spawn_menu != null and is_instance_valid(spawn_menu):
		spawn_menu.visible = false


func _on_spawn_requested(vehicle_id: String) -> void:
	var vehicle := spawn_vehicle_in_front(vehicle_id)
	if vehicle != null:
		close_spawn_menu()


func _unhandled_input(event: InputEvent) -> void:
	if debug_panel != null and is_instance_valid(debug_panel):
		if debug_panel.handle_pc_input(event):
			return
	if vr_active or spawn_menu == null or not is_instance_valid(spawn_menu):
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_V:
		if spawn_menu.visible:
			close_spawn_menu()
		else:
			open_spawn_menu()


func _nearest_vehicle(point: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_distance: float = radius
	for vehicle in vehicles():
		if not (vehicle is Node3D):
			continue
		var distance: float = (vehicle as Node3D).door_position().distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = vehicle as Node3D
	return best


func _on_player_interact() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var current: Variant = actor.get("vehicle")
	if current != null and is_instance_valid(current) and actor.has_method("exit_vehicle"):
		actor.call("exit_vehicle")
		return
	var nearest: Node3D = _nearest_vehicle(actor.global_position, 2.6)
	if nearest != null and actor.has_method("enter_vehicle"):
		actor.call("enter_vehicle", nearest)


func _spawn_dummies(center: Vector3, meta: Dictionary) -> void:
	_dummies_root = Node3D.new()
	_dummies_root.name = "Dummies"
	add_child(_dummies_root)
	var session := _safe_script(SESSION_SCRIPT)
	var fallback_seed: int = int(session.get("seed")) if session != null else 0
	var seed_value: int = int(meta.get("seed", fallback_seed))
	var count: int = STATIC_DUMMY_COUNT
	if vr_active and performance != null and performance.has_method("current_profile"):
		var profile: Dictionary = performance.call("current_profile")
		count = clampi(int(profile.get("npcs", STATIC_DUMMY_COUNT)), 1, STATIC_DUMMY_COUNT)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5EED
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1)) + rng.randf_range(-0.16, 0.16)
		var radius: float = 5.0 + rng.randf_range(0.0, 1.8)
		var point := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		point = _clamp_to_bounds(point, center)
		dummies.append(_create_dummy(point, i))
	for npc in npcs:
		if dummies.size() >= DUMMY_COUNT:
			break
		if npc != null and is_instance_valid(npc):
			dummies.append(npc)
	world_report["static_dummies"] = count
	world_report["living_npcs_exposed_as_targets"] = dummies.size() - count


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
	var skins: Array = ["enemy", "civil", "soldier", "robot"]
	_attach_character_model(dummy, str(skins[id % skins.size()]), "dummy_%d" % id)
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


func _setup_performance() -> void:
	var node: Node = VrPerformanceScript.new()
	if node == null:
		return
	performance = node
	node.name = "VrPerformance"
	add_child(node)
	if node.has_method("build"):
		node.call("build")
	if node.has_method("set_target_mode"):
		node.call("set_target_mode", VrPerformanceScript.MODE_72)
	var profile: Dictionary = node.call("current_profile") if node.has_method("current_profile") else {}
	GoreFxScript.apply_profile(profile)
	var npc_script := _safe_script(ARMED_NPC_PATH)
	if npc_script != null and profile.has("npcs"):
		var limits: Variant = npc_script.get("limits_override")
		var session := _safe_script(SESSION_SCRIPT)
		var platform: String = str(session.get("platform")) if session != null else "pc"
		if platform.is_empty():
			platform = "pc"
		if limits is Dictionary and platform in ["android", "pc", "vr"]:
			(limits as Dictionary)[platform] = clampi(int(profile["npcs"]), 1, 32)


func _setup_voice() -> void:
	var node: Node = VoiceSystemScript.new()
	if node == null:
		return
	voice = node
	node.name = "VoiceSystem"
	add_child(node)
	if node.has_method("set_subtitles_enabled"):
		node.call("set_subtitles_enabled", true)
	if node.has_signal("subtitle"):
		_connect_once(node, "subtitle", Callable(self, "_on_voice_subtitle"))


func _build_navigation(meta: Dictionary) -> void:
	var origin: Vector3 = bounds.position
	var width: int = maxi(1, ceili(bounds.size.x / NAV_CELL_SIZE))
	var height: int = maxi(1, ceili(bounds.size.z / NAV_CELL_SIZE))
	var blocked: Dictionary = {}
	if _geometry_root != null:
		for body in _geometry_root.find_children("*", "CollisionObject3D", true, false):
			if str((body as Node).name) == "Ground":
				continue
			var box: AABB = _collision_box(body as Node3D)
			if box.size.x > 0.0 and box.size.z > 0.0:
				_mark_blocked(blocked, box, origin, width, height, 0.5)
	for prop in physics_props:
		if not (prop is Node3D) or not is_instance_valid(prop):
			continue
		var box: AABB = _collision_box(prop as Node3D)
		if box.size.x <= 0.0 or box.size.z <= 0.0:
			continue
		_mark_blocked(blocked, box, origin, width, height, 0.45)
	_nav_blocked = blocked
	navigation = NPCNavigationScript.new(width, height, blocked.keys(), {
		"origin": Vector2(origin.x, origin.z),
		"max_expansions": 4096,
	})
	npc_lod = NPCLODScript.new()
	var decision: String = "NpcNavigation con rejilla de 1m derivada de colisiones reales del builder; "
	decision += "celdas marcadas con margen 0.55 (0.45 props) para no atravesar paredes ni obstaculos; "
	decision += "el origen coincide con bounds.position y se guarda como Vector2(x,z) para pasar coordenadas mundo."
	world_report["navigation"] = {
		"decision": decision,
		"width": width, "height": height, "cell_size": NAV_CELL_SIZE,
		"origin": Vector2(origin.x, origin.z), "blocked_cells": blocked.size(),
		"meta_seed": int(meta.get("seed", 0)),
	}


func _collision_box(body: Node3D) -> AABB:
	if body == null or not is_instance_valid(body):
		return AABB()
	for child in body.find_children("*", "CollisionShape3D", true, false):
		var shape_node := child as CollisionShape3D
		if shape_node == null or shape_node.shape == null:
			continue
		if shape_node.shape is BoxShape3D:
			var size: Vector3 = (shape_node.shape as BoxShape3D).size
			var center: Vector3 = body.global_position + shape_node.position
			return AABB(center - size * 0.5, size)
	# formas no-caja (muros de edificios en trimesh/convexas): union de sus cajas envolventes
	var merged := AABB()
	var first: bool = true
	for child in body.find_children("*", "CollisionShape3D", true, false):
		var node := child as CollisionShape3D
		if node == null or node.shape == null or not node.is_inside_tree():
			continue
		var mesh: ArrayMesh = node.shape.get_debug_mesh()
		if mesh == null:
			continue
		var box: AABB = node.global_transform * mesh.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	if not first:
		return merged
	var raw: AABB = body.get_aabb() if body.has_method("get_aabb") else AABB()
	return raw


func _mark_blocked(
	blocked: Dictionary, box: AABB, origin: Vector3,
	width: int, height: int, margin: float
) -> void:
	# la celda es un punto en su coordenada entera: se bloquea solo si queda a menos de `margin` de la caja
	var min_x: int = maxi(0, ceili((box.position.x - margin - origin.x) / NAV_CELL_SIZE))
	var max_x: int = mini(width - 1, floori((box.end.x + margin - origin.x) / NAV_CELL_SIZE))
	var min_y: int = maxi(0, ceili((box.position.z - margin - origin.z) / NAV_CELL_SIZE))
	var max_y: int = mini(height - 1, floori((box.end.z + margin - origin.z) / NAV_CELL_SIZE))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			blocked[Vector2i(x, y)] = true


func _spawn_living_npcs(center: Vector3, meta: Dictionary) -> void:
	_npcs_root = Node3D.new()
	_npcs_root.name = "LivingNPCs"
	add_child(_npcs_root)
	if navigation == null:
		return
	var platform: String = _session_platform()
	if platform.is_empty():
		platform = ArmedNpcScript.detect_platform()
	var capacity: int = ArmedNpcScript.max_active(platform)
	var wanted: int = mini(capacity, 16)
	var meta_limit: int = maxi(0, int(meta.get("max_npcs", 0)))
	if meta_limit > 0:
		wanted = mini(wanted, meta_limit)
	if capacity >= 6:
		wanted = maxi(wanted, 6)
	wanted = mini(wanted, capacity)
	if wanted <= 0:
		return
	var candidates: Array = _free_navigation_points(center)
	var main_area: Dictionary = _largest_nav_component()
	if not main_area.is_empty():
		candidates = candidates.filter(func(p): return main_area.has(navigation.call("world_to_cell_2d", Vector2((p as Vector3).x, (p as Vector3).z), NAV_CELL_SIZE)))
	var outside: Array = candidates.filter(func(p): return (p as Vector3).distance_to(center) >= SAFE_RADIUS)
	if outside.size() >= wanted:
		candidates = outside
	if candidates.is_empty():
		return
	var seed_value: int = int(meta.get("seed", 4242))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0xA11CE
	candidates.shuffle()
	var selected: Array = []
	var min_gap: float = 1.7
	for point in candidates:
		if selected.size() >= wanted:
			break
		var valid: bool = true
		for other in selected:
			if point.distance_to(other as Vector3) < min_gap:
				valid = false
				break
		if valid:
			selected.append(point)
	if selected.size() < wanted:
		for point in candidates:
			if selected.size() >= wanted:
				break
			if not selected.has(point):
				selected.append(point)
	if selected.is_empty():
		return
	# los hostiles nacen lejos: garantiza puntos a >= 14 m del jugador entre los elegidos
	var hostile_wanted: int = clampi(wanted / 3, 1, 3)
	var far: Array = candidates.filter(func(p): return (p as Vector3).distance_to(center) >= 14.0)
	far.shuffle()
	var far_have: int = selected.filter(func(p): return (p as Vector3).distance_to(center) >= 14.0).size()
	for point in far:
		if far_have >= hostile_wanted:
			break
		if selected.has(point):
			continue
		var nearest: int = 0
		for i in range(selected.size()):
			if (selected[i] as Vector3).distance_to(center) < (selected[nearest] as Vector3).distance_to(center):
				nearest = i
		selected[nearest] = point
		far_have += 1
	factions = NPCFactionsScript.new({})
	for id in ["civilian", "criminal", "police", "zombie"]:
		factions.call("register_faction", id, id)
	factions.call("set_relation", "police", "criminal", -85.0)
	factions.call("set_relation", "civilian", "criminal", -70.0)
	factions.call("set_relation", "civilian", "zombie", -90.0)
	factions.call("set_relation", "police", "zombie", -90.0)
	factions.call("set_relation", "criminal", "civilian", -45.0)
	factions.call("set_relation", "zombie", "civilian", -95.0)

	var weapons: Dictionary = {"hostile": "assault_rifle", "civilian": ""}
	var faction_by_role: Dictionary = {"hostile": "criminal", "civilian": "civilian"}
	var roles: Array = []
	for i in range(wanted):
		roles.append("hostile" if i < clampi(wanted / 3, 1, 3) else "civilian")
	var defs: Array = []
	for i in range(wanted):
		var role: String = str(roles[i % roles.size()])
		var personality: Dictionary = {
			"temperament": rng.randf_range(0.2, 0.9),
			"confidence": rng.randf_range(0.2, 0.9),
			"bravery": rng.randf_range(0.2, 0.95),
			"fear": rng.randf_range(0.1, 0.7),
			"curiosity": rng.randf_range(0.2, 0.8),
			"sociability": rng.randf_range(0.1, 0.8),
			"aggressiveness": rng.randf_range(0.2, 0.95) if role != "civilian" else 0.05,
		}
		var needs: Dictionary = {"fatigue": 0.2, "stress": 0.1, "fear": 0.1, "confusion": 0.0, "stun": 0.0, "health": 1.0}
		defs.append({
			"id": "npc_%02d" % i,
			"role": role,
			"faction": faction_by_role[role],
			"weapon": weapons[role],
			"personality": personality,
			"needs": needs,
			"routine": [],
			"state": "idle",
		})
	var spawn_meta: Dictionary = {
		"spawn_points": selected,
		"platforms": [platform],
		"performance_profiles": {platform: {"max_npcs": wanted}},
	}
	var spawner = WorldSpawnerScript.new()
	var report: Dictionary = spawner.call("spawn", spawn_meta, defs, seed_value)
	var ranked: Array = (report.get("spawned", []) as Array).duplicate()
	ranked.sort_custom(func(a, b): return (a["position"] as Vector3).distance_to(center) > (b["position"] as Vector3).distance_to(center))
	var hostile_ids: Dictionary = {}
	for i in range(mini(clampi(wanted / 3, 1, 3), ranked.size())):
		hostile_ids[str((ranked[i] as Dictionary)["id"])] = true
	var pool: Array = candidates.slice(0, 60)
	for entry in report.get("spawned", []):
		var def: Dictionary = defs[int(entry.get("index", 0))]
		var role: String = "hostile" if hostile_ids.has(str(entry["id"])) else "civilian"
		def["role"] = role
		def["faction"] = faction_by_role[role]
		def["weapon"] = weapons[role]
		var npc_id: String = str(entry["id"])
		var point: Vector3 = entry["position"]
		factions.call("set_member", npc_id, str(def["faction"]))
		var options: Dictionary = {
			"id": npc_id, "npc_id": npc_id,
			"role": role, "faction_id": str(def["faction"]),
			"weapon_id": str(def["weapon"]),
			"difficulty": "normal", "seed": seed_value + int(entry.get("index", 0)) * 17,
			"platform": platform, "target": actor, "target_id": "player",
			"navigation": navigation, "observer": self, "fx_parent": self,
			"bounds": bounds, "nav_cell_size": NAV_CELL_SIZE, "lod": npc_lod,
			"factions": factions, "patrol_points": pool,
			"attack_points": pool, "cover_points": pool,
			"tick_rate": 12.0, "vision_range": 18.0,
			"patrol_speed": 1.1 if role == "hostile" else 1.4,
			"run_speed": 3.6 if role == "hostile" else 5.5,
			"realistic": true, "avoid_center": center, "avoid_radius": SAFE_RADIUS,
			"drop_weapon_on_death": role == "hostile",
		}
		var npc: Node3D = ArmedNpcScript.spawn(_npcs_root, point, options) as Node3D
		if npc == null:
			continue
		_attach_character_model(npc, _skin_for_role(role), "npc_%s" % npc_id)
		npcs.append(npc)
	var role_counts: Dictionary = {}
	for npc in npcs:
		var role: String = str(npc.get("role"))
		role_counts[role] = int(role_counts.get(role, 0)) + 1
	world_report["ai"] = {
		"platform": platform, "requested": wanted, "spawned": npcs.size(),
		"rejected": (report.get("rejected", []) as Array).size(),
		"rejection_reason": _first_rejection(report),
		"roles": role_counts, "factions": factions.call("faction_ids"),
		"tick_hz": 12.0, "lod": true, "subtitles_by_default": false,
	}


func _first_rejection(report: Dictionary) -> String:
	var rejected: Array = report.get("rejected", [])
	if rejected.is_empty():
		return ""
	var first: Variant = rejected[0]
	if first is Dictionary:
		return str((first as Dictionary).get("reason", ""))
	return str(first)


# Celdas libres de la mayor zona conectada: los NPC solo nacen donde pueden andar.
func _largest_nav_component() -> Dictionary:
	var best: Dictionary = {}
	var seen: Dictionary = {}
	var width: int = int(navigation.get("width"))
	var height: int = int(navigation.get("height"))
	for y in range(height):
		for x in range(width):
			var start := Vector2i(x, y)
			if seen.has(start) or bool(navigation.call("is_blocked", start)):
				continue
			var area: Dictionary = {start: true}
			var queue: Array = [start]
			seen[start] = true
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var next: Vector2i = cell + step
					if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
						continue
					if seen.has(next) or bool(navigation.call("is_blocked", next)):
						continue
					seen[next] = true
					area[next] = true
					queue.append(next)
			if area.size() > best.size():
				best = area
	return best


func _free_navigation_points(center: Vector3) -> Array:
	var result: Array = []
	if navigation == null:
		return result
	var width: int = int(navigation.get("width"))
	var height: int = int(navigation.get("height"))
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			if bool(navigation.call("is_blocked", cell)):
				continue
			var point: Vector3 = navigation.call("cell_to_world", cell, NAV_CELL_SIZE, 0.0)
			if point.distance_to(center) < PLAYER_CLEARANCE:
				continue
			result.append(point)
	return result


func _skin_for_role(role: String) -> String:
	var manifest: Dictionary = _role_skin_manifest()
	var key: String = role.strip_edges().to_lower()
	if manifest.has(key):
		var entry: Variant = manifest[key]
		if entry is String and not str(entry).is_empty():
			return str(entry)
		if entry is Dictionary:
			for field in ["skin", "model", "id", "character"]:
				if (entry as Dictionary).has(field):
					var value: String = str((entry as Dictionary)[field])
					if not value.is_empty():
						return value
	match key:
		"civilian", "civil", "pacifist":
			return "civil"
		"defender", "police", "guard":
			return "soldier"
		"zombie", "zombi", "infectado":
			return "enemy"
		_:
			return "enemy"


func _role_skin_manifest() -> Dictionary:
	var path: String = "res://assets/models/characters/v2/manifest.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary) if parsed is Dictionary else {}


func _connect_player_signals() -> void:
	if actor == null:
		return
	_connect_once(actor, "fired", Callable(self, "_on_player_fired"))
	_connect_once(actor, "weapon_changed", Callable(self, "_on_player_weapon_changed"))
	_connect_once(actor, "interact_pressed", Callable(self, "_on_player_interact"))


func _on_player_fired(result: Dictionary) -> void:
	if actor == null:
		return
	var position: Variant = result.get("position", null)
	var origin: Vector3 = position if position is Vector3 else actor.global_position
	for npc in npcs:
		if npc != null and is_instance_valid(npc) and npc.has_method("hear_gunshot"):
			npc.call("hear_gunshot", origin, 1.0, str(actor.name))


func _on_player_weapon_changed(_item_id) -> void:
	if actor == null:
		return
	for npc in npcs:
		if npc != null and is_instance_valid(npc) and npc.has_method("notice_weapon"):
			npc.call("notice_weapon", actor.global_position)


func _attach_character_model(target: Node3D, skin: String, voice_id: String) -> Node3D:
	if target == null or not is_instance_valid(target):
		return null
	var model: Node3D = CharacterModelScript.spawn(target, skin) as Node3D
	if model == null or not bool(model.call("is_loaded")):
		if model != null:
			model.queue_free()
		return null
	var weapon_mount: Node = target.get_node_or_null("WeaponMount")
	for mesh in target.find_children("*", "MeshInstance3D", true, false):
		if not model.is_ancestor_of(mesh) and (weapon_mount == null or not weapon_mount.is_ancestor_of(mesh)):
			(mesh as MeshInstance3D).visible = false
	model.call("play", "idle")
	_models[target.get_instance_id()] = model
	_skins[target.get_instance_id()] = skin
	if voice != null and voice.has_method("register_npc"):
		voice.call("register_npc", voice_id, {"seed": absi(voice_id.hash()), "health": 100.0})
	return model


func _model_for(target: Node) -> Node3D:
	if target == null:
		return null
	var node: Variant = _models.get(target.get_instance_id(), null)
	if node is Node3D and is_instance_valid(node):
		return node as Node3D
	return null


func _wire_targets() -> void:
	for dummy in dummies:
		var target := dummy as Node3D
		if target == null or target.is_in_group("armed_npc"):
			continue
		_wire_target(target, "dummy_%d" % int(dummy.get("dummy_id")))
	_wire_existing_npcs()


func _wire_existing_npcs() -> void:
	for raw in get_tree().get_nodes_in_group("armed_npc"):
		var npc := raw as Node3D
		if npc == null or not is_instance_valid(npc):
			continue
		var key: String = "npc_%s" % str(npc.get("npc_id"))
		if _model_for(npc) == null:
			var role: String = str(npc.get("role"))
			_attach_character_model(npc, _skin_for_role(role), key)
		if npc.has_method("apply_options") and not npc.has_meta("gw_wired"):
			npc.set_meta("gw_wired", true)
			npc.call("apply_options", {
				"navigation": navigation,
				"observer": self,
				"fx_parent": self,
				"bounds": bounds,
				"nav_cell_size": NAV_CELL_SIZE,
				"lod": npc_lod,
			})
		_wire_target(npc, key)
		_connect_once(npc, "action_changed", Callable(self, "_on_npc_action_changed").bind(npc, key))
		_connect_once(npc, "fired", Callable(self, "_on_npc_fired").bind(npc, key))


func _wire_target(target: Node3D, voice_id: String) -> void:
	if target == null:
		return
	var key := "%d|%s" % [target.get_instance_id(), voice_id]
	if _wired.has(key):
		return
	_wired[key] = true
	_connect_once(target, "damaged", Callable(self, "_on_target_damaged").bind(target, voice_id))
	_connect_once(target, "died", Callable(self, "_on_dummy_died").bind(target, voice_id))
	_connect_once(target, "respawned", Callable(self, "_on_target_respawned").bind(target, voice_id))
	_connect_once(target, "died_from", Callable(self, "_on_npc_died").bind(target, voice_id))


func _connect_once(target: Node, signal_name: String, callable: Callable) -> void:
	if target != null and target.has_signal(signal_name) and not target.is_connected(signal_name, callable):
		target.connect(signal_name, callable)


func _on_voice_subtitle(text: String, npc: String) -> void:
	if _npc_voice_mute > 0:
		return
	if vr_state != null and is_instance_valid(vr_state) and vr_state.has_method("show_subtitle"):
		vr_state.call("show_subtitle", text, npc)
	elif hud != null and hud.has_method("show_subtitle"):
		hud.call("show_subtitle", text, npc)


func _play_npc_voice(voice_id: String, cue: String, state: Dictionary = {}) -> void:
	if voice == null or not voice.has_method("play_cue"):
		return
	if not state.is_empty() and voice.has_method("set_npc_state"):
		voice.call("set_npc_state", voice_id, state)
	_npc_voice_mute += 1
	voice.call("play_cue", voice_id, cue)
	_npc_voice_mute -= 1


func _on_target_damaged(amount: float, point: Vector3, normal: Vector3, target: Node3D, voice_id: String) -> void:
	_impacts[target.get_instance_id()] = {
		"point": point, "normal": normal, "amount": amount,
	}
	var model := _model_for(target)
	if model != null:
		model.call("play", "hit", false)
		model.call("apply_wound", "torso", normal, clampf(0.05 + amount * 0.002, 0.05, 0.3))
	if voice != null and voice.has_method("play_cue"):
		var hp: float = float(target.call("health")) if target.has_method("health") else 50.0
		if target.is_in_group("armed_npc"):
			_play_npc_voice(voice_id, "pain", {"health": clampf(hp, 0.0, 100.0), "fear": 0.4})
		else:
			voice.call("set_npc_state", voice_id, {"health": clampf(hp, 0.0, 100.0), "fear": 0.4})
			voice.call("play_cue", voice_id, "pain")


func _on_dummy_died(target: Node3D, voice_id: String) -> void:
	_finish_target_death(target, voice_id)


func _on_npc_died(_source: Node, target: Node3D, voice_id: String) -> void:
	_finish_target_death(target, voice_id)


func _finish_target_death(target: Node3D, voice_id: String) -> void:
	if target == null:
		return
	var impact: Dictionary = _impacts.get(target.get_instance_id(), {})
	var point: Vector3 = impact.get("point", target.global_position + Vector3.UP)
	var normal: Vector3 = impact.get("normal", Vector3.FORWARD)
	var amount: float = float(impact.get("amount", 40.0))
	var direction: Vector3 = -normal if normal.length_squared() > 0.0001 else -target.global_transform.basis.z
	var impulse: Vector3 = direction.normalized() * clampf(4.0 + amount * 0.2, 4.0, 24.0)
	var model := _model_for(target)
	if model != null:
		model.call("play", "die", false)
		model.call("make_ragdoll", impulse, point)
		model.call("detach_limb", "arm.r")
	var is_living_npc: bool = target.is_in_group("armed_npc")
	if not is_living_npc:
		GoreFxScript.on_death(self, point, 0.8)
	if voice != null and voice.has_method("play_cue"):
		var previous_cooldown: float = float(voice.get("cooldown"))
		voice.call("set_npc_state", voice_id, {"health": 0.0})
		voice.call("set_cooldown", 0.0)
		if is_living_npc:
			_npc_voice_mute += 1
			voice.call("play_cue", voice_id, "death")
			_npc_voice_mute -= 1
		else:
			voice.call("play_cue", voice_id, "death")
		voice.call("set_cooldown", previous_cooldown)


func _on_target_respawned(target: Node3D, voice_id: String) -> void:
	var old: Variant = _models.get(target.get_instance_id(), null)
	if old is Node3D and is_instance_valid(old):
		_models.erase(target.get_instance_id())
		(old as Node3D).queue_free()
	var skin: String = str(_skins.get(target.get_instance_id(), "enemy"))
	_attach_character_model(target, skin, voice_id)
	_impacts.erase(target.get_instance_id())


func _on_npc_action_changed(action: String, target: Node3D, voice_id: String) -> void:
	var model := _model_for(target)
	var anim := "idle"
	match action:
		"patrol", "move", "walk", "investigate":
			anim = "walk"
		"flee", "run":
			anim = "run"
		"aim", "attack":
			anim = "aim"
		"reload":
			anim = "hit"
	if model != null:
		model.call("play", anim, anim != "aim")
	_locomotion[target.get_instance_id()] = anim
	match action:
		"investigate":
			_play_npc_voice(voice_id, "alert")
		"flee":
			_play_npc_voice(voice_id, "fear")
		"attack":
			_play_npc_voice(voice_id, "effort")


func _on_npc_fired(_result: Dictionary, target: Node3D, _voice_id: String) -> void:
	var model := _model_for(target)
	if model != null:
		model.call("play", "shoot", false)


func _sync_locomotion() -> void:
	for npc in npcs:
		if npc == null or not is_instance_valid(npc) or (npc.has_method("is_dead") and bool(npc.call("is_dead"))):
			continue
		var distance: float = global_position.distance_to(npc.global_position)
		if npc_lod != null and distance > 50.0:
			continue
		var model := _model_for(npc)
		if model == null:
			continue
		var speed: float = Vector2(npc.velocity.x, npc.velocity.z).length()
		var anim: String = "run" if speed > 4.0 else ("walk" if speed > 0.4 else "idle")
		var key: int = npc.get_instance_id()
		if str(_locomotion.get(key, "")) != anim or str(model.call("current_animation")).is_empty():
			_locomotion[key] = anim
			model.call("play", anim, true)


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


func _setup_debug_panel() -> void:
	if debug_panel != null and is_instance_valid(debug_panel):
		return
	debug_panel = VrDebugPanelScript.new()
	debug_panel.name = "DebugPanel"
	add_child(debug_panel)
	if debug_panel.has_method("ready"):
		debug_panel.call("ready")

func _process_debug_panel_vr(delta: float) -> void:
	if not vr_active or debug_panel == null or not is_instance_valid(debug_panel):
		return
	if not debug_panel.is_open:
		return
	if actor == null or not actor.has_method("get_pose"):
		return
	var left_pose: Variant = actor.call("get_pose", "left")
	var right_pose: Variant = actor.call("get_pose", "right")
	if not (left_pose is Transform3D) or not (right_pose is Transform3D):
		return
	var trigger_pressed: bool = false
	if actor.has_method("is_trigger_pressed"):
		trigger_pressed = bool(actor.call("is_trigger_pressed", "right"))
	elif actor.has_method("_trigger_axis"):
		trigger_pressed = float(actor.call("_trigger_axis", "right")) > 0.5
	debug_panel.try_press(right_pose.origin, -right_pose.basis.z, trigger_pressed)

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
	if vr_state != null and is_instance_valid(vr_state) and vr_state.has_method("toggle_menu"):
		vr_state.call("toggle_menu")
		return
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
