class_name VrGameMode
extends RefCounted

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const SESSION_PATH: String = "res://core/game/game_session.gd"
const VrRigScript = preload("res://core/vr/vr_rig.gd")
const VrHudScript = preload("res://core/vr/vr_hud.gd")
const VrMenuScript = preload("res://core/vr/vr_menu.gd")
const WeaponSystemScript = preload("res://core/game/weapon_system.gd")
const ItemDbScript = preload("res://core/game/item_db.gd")
const InventoryScript = preload("res://core/game/inventory.gd")
const LoadoutScript = preload("res://core/game/loadout.gd")
const DbScript = preload("res://core/game/weapon_db.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")

const PAUSE_BUTTONS: Array = [
	{"id": "resume", "label": "REANUDAR", "rect": Rect2(-0.13, -0.12, 0.26, 0.07)},
	{"id": "map", "label": "CAMBIAR MAPA", "rect": Rect2(-0.13, -0.03, 0.26, 0.07)},
	{"id": "gore", "label": "GORE ON/OFF", "rect": Rect2(-0.13, 0.06, 0.26, 0.07)},
	{"id": "quit", "label": "SALIR", "rect": Rect2(-0.13, 0.15, 0.26, 0.07)},
]
const START_BUTTONS: Array = [
	{"id": "play", "label": "JUGAR", "rect": Rect2(-0.2, 0.05, 0.4, 0.08)},
	{"id": "map_next", "label": "OTRO MAPA", "rect": Rect2(-0.2, -0.06, 0.4, 0.08)},
]

static var xr_available_override: Callable = Callable()
static var last_start_menu = null


class State extends Node:
	var world: Node3D = null
	var rig: Node3D = null
	var weapon_system: Node = null
	var bag = null
	var hud = null
	var menu = null
	var hands: Dictionary = {}
	var selected_meta: Dictionary = {}
	var current_weapon: String = ""


	func configure(p_world: Node3D, p_rig: Node3D, p_ws: Node, p_meta: Dictionary) -> void:
		world = p_world
		rig = p_rig
		weapon_system = p_ws
		selected_meta = p_meta.duplicate(true)
		bag = rig.get("bag")
		hands["left"] = rig.get("left_hand")
		hands["right"] = rig.get("right_hand")
		_setup_hud()
		_setup_menu()
		_connect_signals()
		refresh_hud()


	func _setup_hud() -> void:
		hud = VrHudScript.new()
		hud.name = "VrHud"
		world.add_child(hud)
		hud.build()
		var left = rig.call("controller_for", "left")
		var right = rig.call("controller_for", "right")
		if left != null:
			hud.mount_health(left)
		if right != null:
			hud.mount_laser(right)
			hud.set_laser_length(1.0)
		hud.set_laser_enabled(false)
		hud.set_health(float(rig.get("health")), float(rig.get("max_health")))


	func _setup_menu() -> void:
		menu = VrMenuScript.new()
		menu.name = "VrMenu"
		world.add_child(menu)
		menu.set_buttons(PAUSE_BUTTONS)
		menu.build()
		_connect_once(rig, "menu_pressed", Callable(self, "toggle_menu"))
		_connect_once(rig, "health_changed", Callable(self, "on_health_changed"))
		_connect_once(menu, "button_pressed", Callable(self, "on_menu_button"))
		_connect_once(menu, "closed", Callable(self, "on_menu_closed"))


	func _connect_signals() -> void:
		if weapon_system != null:
			_connect_once(weapon_system, "empty", Callable(self, "on_empty"))
			_connect_once(weapon_system, "reload_started", Callable(self, "on_reload_started"))
			_connect_once(weapon_system, "reload_finished", Callable(self, "on_reload_finished"))
			_connect_once(weapon_system, "impact", Callable(self, "on_impact"))
		for hand in hands.values():
			if hand == null:
				continue
			_connect_once(hand, "weapon_taken", Callable(self, "on_weapon_taken"))
			_connect_once(hand, "weapon_stowed", Callable(self, "on_weapon_stowed"))
			_connect_once(hand, "fired", Callable(self, "on_fired"))


	func _connect_once(target: Node, signal_name: String, callable: Callable) -> void:
		if target != null and target.has_signal(signal_name) and not target.is_connected(signal_name, callable):
			target.connect(signal_name, callable)


	func tick(delta: float) -> void:
		if rig == null or not is_instance_valid(rig):
			return
		rig.call("step", delta)
		if weapon_system != null and is_instance_valid(weapon_system):
			weapon_system.call("advance", maxf(delta, 0.0))
		refresh_hud()
		_update_pointer()
		if hud != null:
			hud.decay_vignette(delta)


	func refresh_hud() -> void:
		if hud == null:
			return
		if rig != null and is_instance_valid(rig):
			hud.set_health(float(rig.get("health")), float(rig.get("max_health")))
		var held: String = "" if bag == null else str(bag.call("held_item"))
		if held != current_weapon:
			current_weapon = held
			if held.is_empty():
				hud.set_ammo_visible(false)
			else:
				var hand_name: String = "right" if str(bag.call("held_in", "right")) == held else "left"
				_mount_ammo(hand_name)
		if held.is_empty() or weapon_system == null:
			return
		var info: Dictionary = weapon_system.call("ammo_info", held)
		hud.set_ammo(
			int(info.get("mag", 0)), int(info.get("mag_size", 0)),
			int(info.get("reserve", 0)), bool(info.get("infinite", false))
		)
		if bool(info.get("reloading", false)):
			hud.set_reload(true, float(info.get("reload_progress", 0.0)))
		else:
			hud.set_reload(false, 0.0)


	func _mount_ammo(hand_name: String) -> void:
		var hand = hands.get(hand_name, null)
		if hand == null or hud == null:
			return
		var holder = hand.get("holder")
		if holder != null:
			hud.mount_ammo(holder)
			hud.set_ammo_visible(true)


	func _update_pointer() -> void:
		if menu == null or hud == null or rig == null:
			return
		if not bool(menu.get("is_open")):
			hud.set_laser_enabled(false)
			return
		var controller = rig.call("controller_for", "right")
		if controller == null:
			return
		var origin: Vector3 = controller.global_transform.origin
		var direction: Vector3 = -controller.global_transform.basis.z
		var hit: Dictionary = menu.call("pointer_hit", origin, direction)
		var length: float = 2.0
		if bool(hit.get("hit", false)):
			length = clampf(origin.distance_to(hit.get("point", origin)), 0.15, 3.0)
		hud.set_laser_length(length)
		hud.set_laser_enabled(true)
		menu.call("try_press", origin, direction, bool(rig.call("is_trigger_pressed", "right")))


	func toggle_menu() -> void:
		if menu == null:
			return
		if bool(menu.get("is_open")):
			menu.call("close_menu")
			return
		var position := Vector3.ZERO
		var forward := Vector3.FORWARD
		var camera = rig.get("xr_camera") if rig != null else null
		if camera != null:
			position = camera.global_position
			forward = -camera.global_transform.basis.z
		elif rig != null:
			position = rig.global_position + Vector3(0.0, 1.6, 0.0)
		menu.call("open_in_front", position, forward)
		if rig != null:
			rig.call("set_inputs_suspended", true)


	func on_menu_closed() -> void:
		if rig != null:
			rig.call("set_inputs_suspended", false)


	func on_menu_button(button_id: String) -> void:
		match button_id:
			"resume":
				if menu != null:
					menu.call("close_menu")
			"gore":
				GameSession.gore_enabled = not GameSession.gore_enabled
			"map":
				_start_next_map()
			"quit":
				get_tree().quit(0)


	func _start_next_map() -> void:
		var seed_value: int = int(selected_meta.get("seed", 4242)) + 101
		var next_meta: Dictionary = GeneratorScript.generate(seed_value, {
			"width": 24, "height": 18, "obstacle_density": 0.18, "spawn_count": 4,
		})
		if not bool(next_meta.get("ok", false)):
			return
		GameSession.vr_menu_confirmed = true
		GameSession.start(next_meta, get_tree())


	func on_health_changed(current: float, maximum: float) -> void:
		if hud != null:
			hud.set_health(current, maximum)


	func on_weapon_taken(_weapon_id: String, hand_name: String) -> void:
		_mount_ammo(hand_name)
		refresh_hud()


	func on_weapon_stowed(_weapon_id: String, _hand_name: String) -> void:
		current_weapon = ""
		refresh_hud()


	func on_fired(_result: Dictionary) -> void:
		refresh_hud()


	func on_empty(_weapon_id: String) -> void:
		refresh_hud()


	func on_reload_started(_weapon_id: String) -> void:
		if hud != null:
			hud.set_reload(true, 0.0)


	func on_reload_finished(_weapon_id: String) -> void:
		if hud != null:
			hud.set_reload(false, 0.0)
		refresh_hud()


	func show_subtitle(text: String, npc: String) -> void:
		if hud != null:
			hud.call("show_subtitle", text, npc)


	func on_impact(info: Dictionary) -> void:
		if hud == null or rig == null or not bool(info.get("hit", false)):
			return
		var amount: float = float(info.get("damage", 0.0))
		if amount <= 0.0:
			return
		var camera = rig.get("xr_camera")
		if camera == null:
			return
		var point: Vector3 = info.get("position", Vector3.ZERO)
		hud.register_damage(
			-camera.global_transform.basis.z, camera.global_transform.basis.x,
			camera.global_position, point, clampf(amount / 50.0, 0.1, 1.0)
		)


class StartMenuHost extends Node3D:
	var menu = null
	var camera: Camera3D = null
	var chosen_meta: Dictionary = {}
	var beam: MeshInstance3D = null


	func configure(p_menu, p_camera: Camera3D, p_meta: Dictionary, p_beam: MeshInstance3D) -> void:
		menu = p_menu
		camera = p_camera
		chosen_meta = p_meta.duplicate(true)
		beam = p_beam
		if menu != null and menu.has_signal("button_pressed"):
			menu.connect("button_pressed", Callable(self, "on_button"))


	func on_button(button_id: String) -> void:
		var meta: Dictionary = chosen_meta.duplicate(true)
		if button_id == "map_next":
			var seed_value: int = int(chosen_meta.get("seed", 4242)) + 101
			var generated: Dictionary = GeneratorScript.generate(seed_value, {
				"width": 24, "height": 18, "obstacle_density": 0.18, "spawn_count": 4,
			})
			if bool(generated.get("ok", false)):
				meta = generated
		GameSession.vr_menu_confirmed = true
		GameSession.start(meta, get_tree())


	func _unhandled_input(event: InputEvent) -> void:
		if menu == null or camera == null or not bool(menu.get("is_open")):
			return
		if event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			_update_beam(camera.project_ray_origin(motion.position), camera.project_ray_normal(motion.position))
		elif event is InputEventMouseButton:
			var click := event as InputEventMouseButton
			if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
				return
			var origin := camera.project_ray_origin(click.position)
			var direction := camera.project_ray_normal(click.position)
			_update_beam(origin, direction)
			menu.call("try_press", origin, direction, true)


	func _update_beam(origin: Vector3, direction: Vector3) -> void:
		if beam == null or menu == null:
			return
		var hit: Dictionary = menu.call("pointer_hit", origin, direction)
		var length: float = 2.0
		if bool(hit.get("hit", false)):
			length = clampf(origin.distance_to(hit.get("point", origin)), 0.15, 3.0)
		beam.scale.y = length
		beam.position.z = -length * 0.5


static func xr_available() -> bool:
	if xr_available_override.is_valid():
		return bool(xr_available_override.call())
	if not ClassDB.class_exists("XRServer") or not ClassDB.class_exists("OpenXRInterface"):
		return false
	var interface = XRServer.find_interface("OpenXR")
	if interface == null:
		return false
	if interface.has_method("is_initialized") and not bool(interface.call("is_initialized")):
		return false
	return true


static func should_use_vr() -> bool:
	var platform: String = ""
	var session: Script = null
	if ResourceLoader.exists(SESSION_PATH):
		session = load(SESSION_PATH) as Script
	if session != null:
		platform = str(session.get("platform"))
		if platform.is_empty() and session.has_method("detect_platform"):
			platform = str(session.call("detect_platform"))
	return platform == "vr" and xr_available()


static func build(world: Node3D, available: bool) -> Node3D:
	if available:
		var rig = VrRigScript.new()
		rig.name = "Player"
		rig.auto_process = false
		rig.xr_availability_override = func() -> bool: return true
		world.add_child(rig)
		if bool(rig.call("is_active")):
			return rig
		rig.queue_free()
	return _build_player(world)


static func _build_player(world: Node3D) -> Node3D:
	if ResourceLoader.exists(PLAYER_SCENE):
		var packed := load(PLAYER_SCENE) as PackedScene
		if packed != null:
			var instance := packed.instantiate()
			if instance is Node3D:
				var player := instance as Node3D
				player.name = "Player"
				world.add_child(player)
				return player
			if instance != null:
				instance.free()
	var camera := Camera3D.new()
	camera.name = "FallbackCamera"
	world.add_child(camera)
	return camera


static func setup(world: Node3D, rig: Node3D, meta: Dictionary) -> Dictionary:
	var result: Dictionary = {"rig": rig, "state": null, "weapon_system": null, "hud": null, "menu": null}
	if rig == null or not is_instance_valid(rig) or not bool(rig.call("is_active")):
		return result
	var ws := WeaponSystemScript.new()
	ws.name = "VrWeaponSystem"
	ws.set_process(false)
	ws.spread_scale = 0.0
	world.add_child(ws)
	rig.call("set_weapon_system", ws)

	var db = ItemDbScript.new()
	DbScript.register_items(db)
	var inventory = InventoryScript.new(db, 20)
	LoadoutScript.give_starting_kit(inventory, db)
	var bag = rig.get("bag")
	if bag != null:
		bag.call("load_from_inventory", inventory, db)
		if (bag.call("items") as Array).is_empty():
			bag.call("set_items", DbScript.list_ids())

	var state := State.new()
	state.name = "VrGameModeState"
	world.add_child(state)
	state.configure(world, rig, ws, meta)

	result["state"] = state
	result["weapon_system"] = ws
	result["hud"] = state.hud
	result["menu"] = state.menu
	return result


static func build_start_menu(meta: Dictionary, tree: SceneTree):
	if tree == null or tree.root == null:
		return null
	var host := StartMenuHost.new()
	host.name = "VrStartMenu"
	tree.root.add_child(host)

	var camera := Camera3D.new()
	camera.name = "VrStartCamera"
	camera.position = Vector3(0.0, 1.6, 0.0)
	host.add_child(camera)
	camera.current = true
	if "use_xr" in camera:
		camera.set("use_xr", true)

	var menu = VrMenuScript.new()
	menu.name = "VrStartMenuPanel"
	host.add_child(menu)
	menu.set_buttons(START_BUTTONS)
	menu.build()
	menu.open_in_front(Vector3(0.0, 1.6, 0.0), Vector3.FORWARD)

	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.001
	beam_mesh.bottom_radius = 0.001
	beam_mesh.height = 1.0
	var beam := MeshInstance3D.new()
	beam.name = "StartMenuLaser"
	beam.mesh = beam_mesh
	beam.rotation.x = PI * 0.5
	beam.position.z = -1.0
	camera.add_child(beam)

	host.configure(menu, camera, meta, beam)
	last_start_menu = menu
	return menu


static func default_map_meta(seed_value: int = 4242) -> Dictionary:
	var meta: Dictionary = GeneratorScript.generate(seed_value, {
		"width": 24, "height": 18, "obstacle_density": 0.18, "spawn_count": 4,
	})
	return meta if bool(meta.get("ok", false)) else {}
